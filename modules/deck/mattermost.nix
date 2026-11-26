# mattermost — deck stub. off by default. local accounts until Dex.
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.deck.mattermost;
in
{
  options.mothership.deck.mattermost = {
    enable = lib.mkEnableOption "Mattermost on the deck (shared team chat)";
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable Mattermost service
    services.mattermost = {
      enable = true;
      siteUrl = "https://chat.tharavad.xyz";
      host = "0.0.0.0"; # Keep this so Mattermost accepts connections
      port = 8065;
    };

    # 2. CRITICAL: Open the firewall so the Edge server can reach us over WireGuard
    networking.firewall.interfaces."wg-front".allowedTCPPorts = [ 8065 ];

    # 3. Local router on Mothership: Catch WG traffic on 8065 and forward to Mattermost
    services.nginx.virtualHosts."mattermost-wg-router" = {
      listen = [
        { addr = "10.99.0.2"; port = 8065; }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8065";
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