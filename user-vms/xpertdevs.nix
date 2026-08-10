# user-vms/xpertdevs.nix
{
  tier = "small";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHgiID6S+TVBVVtz0YIXe+joglSxbYgm6yFQqBOyKyZx nk@xd.in"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhO7uTB0WJ0X85N2k5if8FUUyhL9b0/WUhbQcxLVVxW kk@xd.in"
  ];
  # optional:
  # publish = [ { port = 3000; } ];
}
