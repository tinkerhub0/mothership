# copy to user-vms/<name>.nix — name must match ^[a-z][a-z0-9-]{1,15}$
# this file is NOT loaded (template.nix is ignored).
#
# after merge:
#   ssh you@you.tharavad.xyz
#   http://you.tharavad.xyz  (if publish set — run a server on that port)
#
# mesh/Headscale is internal only — you do not join a VPN.
{
  # github = "akshaypradheep";
  tier = "large"; # small | medium | large
  enabled = true;

  # paste from https://github.com/<you>.keys — must be non-empty
  keys = [
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBRaDm4HFeu2WrrEofD9oL5c7cAfjd3c+dB1kXkxijvw"
  ];

  # optional public HTTP (DNS wildcard already points at edge)
   publish = [
     { port = 9090; }                          # → http://you.tharavad.xyz
     { subdomain = "apj"; port = 9080; }      # → http://blog.tharavad.xyz
   ];
}

