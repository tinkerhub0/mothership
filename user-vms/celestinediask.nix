# user-vms/you.nix
{
  tier = "small";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICH28zSgHDjkr9WdIOcfBDdvL4pxyQFG04ppL9TkRv1H user@dev"
  ];
  # optional:
  publish = [ { port = 3000; } ];
}
