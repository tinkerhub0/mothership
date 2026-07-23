# Cloudflare Tunnel → Headscale control plane (no router port-forward).
# Dashboard owns ingress: public hostname → http://127.0.0.1:8080
# Token lives on disk (not in git). See scripts/cloudflare-tunnel-setup.md flow in shell output.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.mesh.cloudflare;
  mesh = config.mothership.mesh;
in
{
  options.mothership.mesh.cloudflare = {
    enable = lib.mkEnableOption "Cloudflare Tunnel for Headscale";

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "tinkerhub-mesh.uk";
      description = "Public hostname in a Cloudflare zone (cheap throwaway domain; apex is fine).";
    };

    # file contents: single line token from Zero Trust → Tunnels → Install connector
    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/cloudflared/tunnel.token";
      description = "Path to tunnel token (mode 0400, root-owned). Not in git.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Prefer CF URL as the control-plane address clients use everywhere.
    mothership.mesh.serverUrl = lib.mkDefault "https://${cfg.hostname}";

    users.groups.cloudflared = { };
    users.users.cloudflared = {
      isSystemUser = true;
      group = "cloudflared";
      description = "Cloudflare Tunnel";
    };

    systemd.services.cloudflared-mothership = {
      description = "Cloudflare Tunnel (Headscale)";
      after = [
        "network-online.target"
        "headscale.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "cloudflared";
        Group = "cloudflared";
        Restart = "always";
        RestartSec = "5s";
        StateDirectory = "cloudflared";
        # token file must be readable by this user
        ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file ${cfg.tokenFile}";
        # older cloudflared: fall back via Environment if token-file unsupported — token-file exists in recent builds
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadOnlyPaths = [ cfg.tokenFile ];
      };
      unitConfig = {
        # skip until token is installed (switch must not fail)
        ConditionPathExists = cfg.tokenFile;
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };
    };

    environment.systemPackages = [ pkgs.cloudflared ];

    environment.etc."mothership/cloudflare-tunnel.txt".text = ''
      Cloudflare Tunnel → Headscale
      public:  https://${cfg.hostname}
      origin:  http://127.0.0.1:${toString mesh.listenPort}
      token:   ${cfg.tokenFile}

      Dashboard (once):
        1. https://one.dash.cloudflare.com → Zero Trust → Networks → Tunnels
        2. Create tunnel (Cloudflared), copy token
        3. Public hostname: ${cfg.hostname}
           Service: http://127.0.0.1:${toString mesh.listenPort}
           (DNS: Cloudflare proxy ON / orange cloud)
        4. On mothership:
             sudo mkdir -p /var/lib/cloudflared
             echo 'eyJ...token...' | sudo tee ${cfg.tokenFile}
             sudo chown cloudflared:cloudflared ${cfg.tokenFile}
             sudo chmod 0400 ${cfg.tokenFile}
             sudo systemctl restart cloudflared-mothership
        5. Clients:
             tailscale up --login-server=https://${cfg.hostname} --authkey=... --reset
    '';
  };
}
