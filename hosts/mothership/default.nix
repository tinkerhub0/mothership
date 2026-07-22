# Machine identity only. Capabilities live under ../../modules.
{
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
    ../../modules/base.nix
    ../../modules/tools.nix
    ../../modules/deck
  ];

  # Stable 8-hex hostId required by ZFS. Do not change after first pool create.
  networking.hostId = "a7c3e91b";
  networking.hostName = "mothership";

  # Phase 1: get on the wire. Mesh MagicDNS lands with Headscale later.
  networking.useDHCP = lib.mkDefault true;

  # On the server (once), then commit:
  #   nix run github:nix-community/nixos-facter -- -o hosts/mothership/facter.json
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- FILL BEFORE FIRST BOOT / SWITCH ---
  users.users.root.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 AAAA... you@admin"
  ];

  system.stateVersion = "25.05";
}
