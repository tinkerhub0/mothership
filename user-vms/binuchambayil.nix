# user-vms/binuchambayil.nix
{
  tier = "small";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWBHeLsOMqMK5h9Q1TP15205/wSf0bFdJK0EJE9tftP hbinu"
  ];
extraPackages = [ pkgs.tailscale ];
}
