# Host Tailscale client: joins local Headscale, pins hostname, serves control plane.
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

    # Operator helper: print mesh identity + how to join.
    environment.etc."mothership/mesh-bootstrap.md".text = ''
      # Mesh bootstrap (mothership)

      Headscale listens on 0.0.0.0:${toString hsPort} (firewall: lo + tailscale0).
      Reserved mothership IP: ${cfg.mothershipIPv4}
      MagicDNS base: ${cfg.baseDomain}
      Canonical login-server: http://${cfg.mothershipIPv4}:${toString hsPort}
      Serve (after node up): https://${config.networking.hostName}.${cfg.baseDomain}

      ## Once on the box

      ```
      # 1. Create the headscale user (namespace for nodes)
      sudo -u headscale headscale users create tinkerhub

      # 2. Preauth key for this host (reusable=false, ephemeral=false)
      sudo -u headscale headscale preauthkeys create -u tinkerhub --reusable --expiration 24h

      # 3. Join (or rely on authKeyFile + extraUpFlags once sops lands)
      sudo tailscale up \
        --login-server=${loginLocal} \
        --authkey=<key> \
        --hostname=${config.networking.hostName} \
        --accept-dns=true \
        --advertise-tags=tag:mothership

      # 4. Confirm static-ish address (sequential → first node = ${cfg.mothershipIPv4})
      tailscale ip -4
      sudo -u headscale headscale nodes list

      # 5. Serve status
      tailscale serve status
      ```

      ## Other machines

      ```
      tailscale up --login-server=http://${cfg.mothershipIPv4}:${toString hsPort} --authkey=<key>
      # or, once on mesh and DNS works:
      # tailscale up --login-server=https://${config.networking.hostName}.${cfg.baseDomain} --authkey=<key>
      ```
    '';
  };
}
