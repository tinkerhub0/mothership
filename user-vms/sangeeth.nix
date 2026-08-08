# member: sangeeth
#   ssh  sangeeth@sangeeth.tharavad.xyz
#   XMO Messenger - Decentralized Web3 messaging platform
#   Website: https://xmo.dpdns.org/
{
  github = "TheCyperpunk";
  tier = "large"; # Production testing environment for XMO messaging platform
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK4GpidrPZuZGKBarF1pOx8XzmZiiou25SYluHsg3qOB sangeethkarunakaran@tharavad"
  ];
  # XMO platform services
  publish = [
    { port = 8008; }  # Matrix Synapse homeserver
    { subdomain = "otp"; port = 3000; }  # Email OTP authentication service
  ];
}