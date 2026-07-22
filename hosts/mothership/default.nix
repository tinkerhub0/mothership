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

  # Hardware inventory snapshot (drivers + disk autodetect for disko).
  # Generate ON THE SERVER, commit the file into this repo:
  #   sudo nix run github:nix-community/nixos-facter -- -o hosts/mothership/facter.json
  # Optional override if autodetect picks the wrong disk:
  #   mothership.diskDevice = "/dev/disk/by-id/nvme-...";
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPgJj9GEaxD16KIwrB0M9qxeaFy33iCuCo99Jm/dxbkO terminal-shop"
  ];

  system.stateVersion = "25.05";
}
