# user-vms/hisham.nix
{
  tier = "medium";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2xt1NkuyRFI/e3f1Bmv/Y+lOhddRcQgSFX9Yz2OXZZ hisham222111@gmail.com"
  ];
  # optional:
  # publish = [ { port = 3000; } ];
}
