# status-proxy — public edge for the deck monitor (Uptime Kuma).
# edge side only; the service itself lives in modules/deck/uptime-kuma.nix.
#
#   internet :443 → edge nginx (status.tharavad.xyz, ACME)
#     → WG 10.99.0.2:9081 → mothership nginx → 127.0.0.1:3001
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.statusProxy;
in
{
  options.mothership.statusProxy = {
    enable = lib.mkEnableOption "public status.tharavad.xyz → deck Uptime Kuma (edge)";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "status.tharavad.xyz";
    };

    routerHost = lib.mkOption {
      type = lib.types.str;
      default = "10.99.0.2";
      description = "mothership address on wg-front (edge proxies here)";
    };

    routerPort = lib.mkOption {
      type = lib.types.port;
      default = 9081;
      description = "HTTP router port on mothership (keep in sync with mothership.deck.uptimeKuma.routerPort)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      virtualHosts."${cfg.domain}" = {
        serverName = cfg.domain;
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://${cfg.routerHost}:${toString cfg.routerPort}";
          # recommendedProxySettings injects Host= again → double Host → upstream 400
          recommendedProxySettings = false;
          # websockets: sets proxy_http_version + Upgrade/Connection map (do not re-set)
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

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    environment.etc."mothership/status-proxy.txt".text = ''
      status proxy (edge)
      public:  https://${cfg.domain}
      router:  http://${cfg.routerHost}:${toString cfg.routerPort} (WG → mothership)
      service: modules/deck/uptime-kuma.nix (mothership)
    '';
  };
}
