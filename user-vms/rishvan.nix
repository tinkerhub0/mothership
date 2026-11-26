{
  tier = "small";   # small | medium | large
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDQ4m/+6IB1Ku/QoZSpJxzAeEzfXcK5ZlBHEoIheF+u rishvanrv7@gmail.com"
  ];

  publish = [
    { port = 3000; }                              # → https://rishvan.tharavad.xyz
    { subdomain = "api-rishvan"; port = 8000; }   # → https://api-rishvan.tharavad.xyz (API)
    { subdomain = "bot-rishvan"; port = 8001; }   # → https://bot-rishvan.tharavad.xyz (Discord bot)
  ];
}
