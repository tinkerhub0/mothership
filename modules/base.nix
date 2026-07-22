# base — server policy on top of srvos.
# not disks. not deck. not mesh. just "how we run boxes".
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

  # previous gens stay bootable — mitigates "evals fine, host is toast".
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
