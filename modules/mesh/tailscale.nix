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
      # Server-ish: may advertise routes later (exit node / subnet).
      useRoutingFeatures = "server";
      # Optional: path to a preauth key (sops later). When set, autoconnect runs.
      # authKeyFile = config.sops.secrets."tailscale/preauth".path;
      extraUpFlags = [
        "--login-server=${loginLocal}"
        "--hostname=${config.networking.hostName}"
        "--accept-dns=true"
        "--advertise-tags=tag:mothership"
      ];
    };

    # Front Headscale on the node's MagicDNS name (HTTPS, cert via tailscaled).
    # Canonical login for automation remains http://100.64.0.1:8080 (static IP).
    systemd.services.tailscale-serve-headscale = {
      description = "tailscale serve → local Headscale";
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
      requires = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.tailscale
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "tailscale-serve-headscale" ''
          set -euo pipefail
          for i in $(seq 1 60); do
            if tailscale status --json 2>/dev/null | grep -q '"BackendState": "Running"'; then
              break
            fi
            sleep 1
          done
          tailscale serve reset || true
          # https://<hostname>.<baseDomain>/ → Headscale
          tailscale serve --bg --https=443 http://127.0.0.1:${toString hsPort}
        '';
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
      };
    };

    environment.systemPackages = [ pkgs.tailscale ];

    # on-box cheat sheet — read the nix + why-this-exist, not a wiki
    environment.etc."mothership/mesh-bootstrap.md".text = ''
      # mesh bootstrap // mothership
      # first node only — sequential alloc, this box must own .1

      headscale: 0.0.0.0:${toString hsPort} (fw: lo + tailscale0)
      reserved:  ${cfg.mothershipIPv4}
      MagicDNS:  ${cfg.baseDomain}
      login:     http://${cfg.mothershipIPv4}:${toString hsPort}
      serve:     https://${config.networking.hostName}.${cfg.baseDomain}

      ## first node (this box) — must own .1

      ```
      sudo -u headscale headscale users create tinkerhub
      sudo -u headscale headscale preauthkeys create -u tinkerhub --reusable --expiration 24h
      sudo tailscale up \
        --login-server=${loginLocal} \
        --authkey=<key> \
        --hostname=${config.networking.hostName} \
        --accept-dns=true \
        --advertise-tags=tag:mothership
      tailscale ip -4   # expect ${cfg.mothershipIPv4}
      tailscale serve status
      ```

      ## everyone else (after .1 is taken)

      ```
      tailscale up --login-server=http://${cfg.mothershipIPv4}:${toString hsPort} --authkey=<key>
      ```
    '';
  };
}
