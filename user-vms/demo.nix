# smoke-test member — proves the pipeline evals a real guest.
# disable or delete once you have real humans.
{
  github = "demo";
  tier = "small";
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPgJj9GEaxD16KIwrB0M9qxeaFy33iCuCo99Jm/dxbkO terminal-shop"
  ];
}
