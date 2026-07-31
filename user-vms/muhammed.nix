{
  tier = "large";
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFejXFHUhDZjZ4c+MoydyyGUunnhrwy+AyNui2gyWiPp muhammed2.althaf@gmail.com"
  ];
  publish = [
    { port = 3000; }
    { subdomain = "api"; port = 8080; }
  ];
}
