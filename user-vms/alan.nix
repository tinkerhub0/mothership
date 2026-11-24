# member: alan
#   ssh alan@alan.tharavad.xyz
{
  github = "shadowe1ite";
  tier = "large";
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIISphsrkjAO6UwgKDVyiLJcyZU+Ar/6ZC2bd+IFp2TLP"
  ];
  publish = [
    { port = 3000; }                       # alan.tharavad.xyz → personal
    { subdomain = "labs"; port = 5000; }   # labs.tharavad.xyz → lab catalog
    { subdomain = "run"; port = 5001; }    # run.tharavad.xyz  → lab instances
  ];
}
