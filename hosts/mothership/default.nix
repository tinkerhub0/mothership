# hosts/mothership — identity of this metal.
# capabilities live under ../../modules.
{
  lib,
  ...
}:
let
  # ═══════════════════════════════════════════════════════════
  # STORAGE MODE — read this before every switch
  #
  # false (default): use hardware-configuration.nix
  #   = installer layout (ext4/btrfs). SAFE for switch on a
  #     normal NixOS install. Replace hardware-configuration.nix
  #     with the copy from /etc/nixos/ on the box.
  #
  # true: use disko.nix (ESP + ZFS tank)
  #   = ONLY after a clean install that was formatted with disko.
  #   Switching this on over an installer root = boot.mount dies.
  #   That is what bricked us last time.
  # ═══════════════════════════════════════════════════════════
  useDisko = false;
in
{
  imports = [
    ../../modules/base.nix
    ../../modules/admins.nix
    ../../modules/tools.nix
    ../../modules/deck
    ../../modules/mesh
    ../../modules/microvms
  ]
  ++ (
    if useDisko then
      [ ./disko.nix ]
    else
      [ ./hardware-configuration.nix ]
  );

  # frozen at first ZFS pool create (only matters when useDisko = true).
  networking.hostId = "a7c3e91b";
  networking.hostName = "mothership";

  # keep NetworkManager — live install uses it for eno1 DHCP.
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  mothership.mesh = {
    enable = true;
    baseDomain = "mesh.tinkerhub";
    mothershipIPv4 = "100.64.0.1";
    # public control plane via Cloudflare Tunnel (see cloudflare.nix)
    # serverUrl overridden to https://hs.tharavad.xyz when tunnel enable = true
    cloudflare = {
      enable = true;
      hostname = "hs.tharavad.xyz";
      tokenFile = "/var/lib/cloudflared/tunnel.token";
    };
  };

  # guests after host is stable
  mothership.microvms.enable = false;

  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # match install (NixOS 26.05 Yarara)
  system.stateVersion = "26.05";
}
