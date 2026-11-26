{
  github = "muhammedshibilm";
  tier = "small";
  enabled = true;
  keys = [
       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2RXsEXistFty449PjjsgAHekHiLfa8COv4R8hEwhla muhammedshibilm321@gmail.com"
  ];
 publish = [
  { subdomain = "shibil"; port = 3000; }        # site
  { subdomain = "api-shibil"; port = 8431; }    # API
  ];
}
