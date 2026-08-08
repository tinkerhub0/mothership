{
  tier = "medium";
  enabled = true;

  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQLWAS1EX32NHQTTvBQ3s7gPyGn6pMzHXtwN8jREC9f adeldevs87@gmail.com"
  ];

  publish = [
    { port = 3000; }
    { port = 3001; }
    { port = 3002; }
    { port = 3003; }
    { port = 5678; }
    { port = 4000; }
    { port = 8080; }
  ];
}
