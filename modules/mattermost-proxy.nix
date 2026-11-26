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
        proxyPass = "http://${config.mothership.mesh.frontDoor.homeTunnelIP}:8065";
        recommendedProxySettings = true;
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 300s;
        '';
      };
    };
  };
}
