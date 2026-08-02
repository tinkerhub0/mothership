# uptime-kuma — deck shared monitoring service.
# native host service (nixpkgs services.uptime-kuma), not a microVM:
# a fleet monitor needs eyes on every network (public, mesh, br-deck),
# and the host is the only node on all of them.
# web login stays local until Dex → GitHub.
#
# path:
#   internet :443 → edge nginx (status.tharavad.xyz, ACME)
#     → WG 10.99.0.2:9081 → mothership nginx → 127.0.0.1:3001
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.deck.uptimeKuma;
  dataDir = "/var/lib/mothership/deck/uptime-kuma";
  routerPort = cfg.routerPort;
in
{
  options.mothership.deck.uptimeKuma = {
    enable = lib.mkEnableOption "Uptime Kuma fleet monitoring (public via status.tharavad.xyz)";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "status.tharavad.xyz";
      description = "Public hostname; edge reverse-proxies here over WG.";
    };

    tunnelIP = lib.mkOption {
      type = lib.types.str;
      default = "10.99.0.2";
      description = "mothership address on wg-front (edge proxies here)";
    };

    routerPort = lib.mkOption {
      type = lib.types.port;
      default = 9081;
      description = "HTTP router port on mothership (WG-facing) → local Uptime Kuma";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Uptime Kuma bind address port (127.0.0.1 only).";
    };
  };

  config = lib.mkIf cfg.enable {
    # static service user (mirrors landa in landa-proxy.nix): the upstream
    # unit defaults to DynamicUser + /var/lib/private, but we want the repo
    # data dir (/var/lib/mothership/deck/…) to be the writable StateDirectory.
    users.groups.uptime-kuma = { };
    users.users.uptime-kuma = {
      isSystemUser = true;
      group = "uptime-kuma";
      description = "Uptime Kuma fleet monitor";
    };

    services.uptime-kuma = {
      enable = true;
      settings = {
        # upstream sets DATA_DIR plainly (not mkDefault) → mkForce to override
        DATA_DIR = lib.mkForce "${dataDir}/";
        # HOST defaults to 127.0.0.1 upstream — localhost only, nginx fronts it
        PORT = toString cfg.listenPort;
      };
    };

    # keep the upstream hardening (ProtectSystem=strict, PrivateTmp, …);
    # swap DynamicUser for the static user and point StateDirectory at the
    # repo data dir so it stays writable under ProtectSystem=strict.
    systemd.services.uptime-kuma.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "uptime-kuma";
      Group = "uptime-kuma";
      StateDirectory = lib.mkForce "mothership/deck/uptime-kuma";
    };

    # local router: edge → WG → mothership:9081 → 127.0.0.1:3001
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      virtualHosts."uptime-kuma-router" = {
        serverName = cfg.domain;
        listen = [
          {
            addr = cfg.tunnelIP;
            port = routerPort;
          }
          {
            addr = "127.0.0.1";
            port = routerPort;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.listenPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 10s;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };
    };

    # only reachable from edge via WG (not public WAN)
    networking.firewall.interfaces."wg-front".allowedTCPPorts = [ routerPort ];

    environment.etc."mothership/uptime-kuma.txt".text = ''
      Uptime Kuma (deck shared monitoring service)
      local:    http://127.0.0.1:${toString cfg.listenPort}
      public:   https://${cfg.domain}
      data:     ${dataDir}
      unit:     uptime-kuma.service
      upstream: nixpkgs services.uptime-kuma (hardened systemd unit)

      first login: open the URL, create the admin account (no secrets in git).
    '';
  };
}
