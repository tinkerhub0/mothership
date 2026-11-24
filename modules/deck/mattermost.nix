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
      # This must be the final public HTTPS address
      siteUrl = "https://chat.tharavad.xyz";
      # Default port 8065, keep default unless there is a conflict
    };

    # 2. Nginx reverse proxy subdomain
    services.nginx.virtualHosts."chat.tharavad.xyz" = {
      forceSSL = true;
      # If Mothership already has a wildcard certificate for *.tharavad.xyz,
      # change enableACME to useACMEHost = "tharavad.xyz";
      enableACME = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8065";
        # Mattermost real-time messaging depends on WebSocket, must be enabled
        proxyWebsockets = true;
      };
    };
  };
}
