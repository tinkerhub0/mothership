{
  github = "ashishshaiju";
  tier = "large";
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDGNzwrI5VTERQLF7GXXSb8wEfZNXbNEB3OS9ZpuTmH ashishshaiju@tharavad"
  ];
  publish = [
    { port = 3000; }
    { subdomain = "app-ashishshaiju"; port = 3005; }
    { subdomain = "api-ashishshaiju"; port = 5000; }
  ];
}
