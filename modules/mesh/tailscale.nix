# tailscale — host client joins local headscale, pins hostname, serves control plane.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.mesh;
  hsPort = cfg.listenPort;
  loginLocal = "http://127.0.0.1:${toString hsPort}";
in
{
  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "server";
      # authKeyFile later via sops
      extraUpFlags = [
        # host can always hit local headscale; remote clients use serverUrl
        "--login-server=${loginLocal}"
        "--hostname=${config.networking.hostName}"
        "--accept-dns=true"
        "--advertise-exit-node" # optional: phone/laptop can exit via mothership
      ];
    };

    # serve only works after this node has joined the mesh.
    # must not fail switch — exit 0 if not logged in yet.
    systemd.services.tailscale-serve-headscale = {
      description = "tailscale serve → local Headscale (after mesh join)";
      after = [
        "tailscaled.service"
        "headscale.service"
        "network-online.target"
      ];
      wants = [
        "tailscaled.service"
        "headscale.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.tailscale
        pkgs.coreutils
        pkgs.gnugrep
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # never fail activation before first join
        SuccessExitStatus = "0 1";
        ExecStart = pkgs.writeShellScript "tailscale-serve-headscale" ''
          set -u
          for i in $(seq 1 30); do
            if tailscale status --json 2>/dev/null | grep -q '"BackendState": "Running"'; then
              tailscale serve reset || true
              tailscale serve --bg --https=443 http://127.0.0.1:${toString hsPort} && exit 0
              exit 0
            fi
            sleep 1
          done
          echo "tailscale not joined yet — skip serve (run mesh bootstrap, then: systemctl restart tailscale-serve-headscale)"
          exit 0
        '';
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
      };
    };

    environment.systemPackages = [ pkgs.tailscale ];

    environment.etc."mothership/mesh-bootstrap.md".text = ''
      # mesh bootstrap // mothership
      # first node only — sequential alloc, this box must own .1

      headscale: 0.0.0.0:${toString hsPort}
      reserved:  ${cfg.mothershipIPv4}
      MagicDNS:  ${cfg.baseDomain}
      login:     http://${cfg.mothershipIPv4}:${toString hsPort}

      ## once headscale is active (v0.29+: -u is numeric user ID)

      ```
      sudo -u headscale headscale users create tinkerhub   # once
      sudo -u headscale headscale users list                 # note ID column
      KEY=$(sudo -u headscale headscale preauthkeys create -u 1 --reusable --expiration 24h)
      echo "$KEY"
      sudo tailscale up \
        --login-server=${loginLocal} \
        --authkey="$KEY" \
        --hostname=${config.networking.hostName} \
        --accept-dns=true \
        --reset
      tailscale ip -4   # expect ${cfg.mothershipIPv4}
      sudo systemctl restart tailscale-serve-headscale
      tailscale serve status
      ```
    '';
  };
}
