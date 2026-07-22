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
    # TODO: services.mattermost / oci-container / dedicated microVM.
    # Auth: local accounts until Dex → GitHub. Do not invent a second IdP here.
    assertions = [
      {
        assertion = false;
        message = "mothership.deck.mattermost: not implemented yet — leave enable = false";
      }
    ];
  };
}
