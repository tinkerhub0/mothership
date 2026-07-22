# hosts/mothership — identity of this metal.
# capabilities live under ../../modules. do not dump service logic here.
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
    ../../modules/microvms
  ];

  # frozen at first ZFS pool create. change later = import pain.
  networking.hostId = "a7c3e91b";
  networking.hostName = "mothership";

  # LAN for install/bootstrap. mesh addressing is Headscale's job (100.64.0.1).
  networking.useDHCP = lib.mkDefault true;

  mothership.mesh = {
    enable = true;
    baseDomain = "mesh.tinkerhub";
    mothershipIPv4 = "100.64.0.1";
  };

  # members: drop files in user-vms/ (see scripts/signup). empty = no guests yet.
  mothership.microvms.enable = true;

  # frozen hardware scan — generate ON THE BOX, commit the JSON:
  #   ./scripts/capture-hardware.sh
  # pin if autodetect is wrong:
  #   mothership.diskDevice = "/dev/disk/by-id/nvme-...";
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPgJj9GEaxD16KIwrB0M9qxeaFy33iCuCo99Jm/dxbkO terminal-shop"
  ];

  system.stateVersion = "25.05";
}
