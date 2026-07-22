# Stub: wire service package/OCI/microVM in a later phase. Off by default.
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
