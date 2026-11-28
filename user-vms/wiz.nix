# user-vms/you.nix
{
  tier = "small";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICs4Vt7ksesrsnDOpwCIiu4rVmslij4+g4ynGagkUQ7L wiz@server"
  ];
  # optional:
  publish = [ { port = 3000; } ];
}
