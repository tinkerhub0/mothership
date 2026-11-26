{ config, lib, ... }:
let
  cfg = config.mothership.mattermostProxy;
in
{
  options.mothership.mattermostProxy = {
    enable = lib.mkEnableOption "Mattermost public proxy";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "chat.tharavad.xyz";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        # Forward to the WireGuard IP of the Mothership, port 8065 (Mattermost default)
        proxyPass = "http://10.99.0.2:8065"; 
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}