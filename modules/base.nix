# Shared server policy on top of srvos. Not host disks, not deck services.
{ lib, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Keep previous generations bootable (mitigates "evals fine, bricks host").
  boot.loader.systemd-boot.configurationLimit = 10;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = lib.mkDefault "prohibit-password";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
}
