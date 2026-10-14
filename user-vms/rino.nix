{
  github = "rinogodson";
  tier = "large";
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEtmW2WEWDDhSoxERs5/PIEOjIayMDh4QbLgavIAmLk rinogodson@Rinos-Laptop-2390.local"
  ]
  publish = [
    {
      port = 3000;
    }
    # {
    #   subdomain = "tack";
    #   port = 8080;
    # }
  ];
}
