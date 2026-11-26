# Shared chat, reached from the edge over WireGuard.
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.deck.mattermost;
  frontDoor = config.mothership.mesh.frontDoor;
in
{
  options.mothership.deck.mattermost = {
    enable = lib.mkEnableOption "Mattermost on the deck (shared team chat)";
  };

  config = lib.mkIf cfg.enable {
    services.mattermost = {
      enable = true;
      siteUrl = "https://chat.tharavad.xyz";
      host = frontDoor.homeTunnelIP;
      port = 8065;
    };

    networking.firewall.interfaces.${frontDoor.interface}.allowedTCPPorts = [ config.services.mattermost.port ];

    systemd.services.mattermost = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };
}
