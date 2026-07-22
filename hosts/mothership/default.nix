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
    ../../modules/mesh
  ];

  # Stable 8-hex hostId required by ZFS. Do not change after first pool create.
  networking.hostId = "a7c3e91b";
  networking.hostName = "mothership";

  # LAN for install/bootstrap. Mesh addresses come from Headscale (100.64.0.1).
  networking.useDHCP = lib.mkDefault true;

  mothership.mesh = {
    enable = true;
    baseDomain = "mesh.tinkerhub";
    mothershipIPv4 = "100.64.0.1";
  };

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
