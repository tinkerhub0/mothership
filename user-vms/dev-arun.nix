# user-vms/you.nix
{
  tier = "small";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBmTpm/aOFtResQjr2VCejJJwjzA8UvCmLPqNzhLcSaU 123arunbalakrishnan@gmail.com"
  ];
  # optional:
  publish = [ { port = 3000; } ];
}

