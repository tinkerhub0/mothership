# user-vms/you.nix
{
  tier = "medium";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEIYNF4lI4v+efxt7yGQTtrqpQeMcTpdOXyDCrppGPC shahal3153@gmail.com"
  ];
  # optional:
  # publish = [ { port = 3000; } ];
}
