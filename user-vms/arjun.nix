{
  github = "decoded-cipher";
  tier = "large";
  enabled = true;

  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHYPYu7eGEg6b4LrRrAa8V7qe7beBW9WY0FP3nKX6sXx arjun@tharavad"
  ];

  publish = [
    { port = 3000; }
  ];
}
