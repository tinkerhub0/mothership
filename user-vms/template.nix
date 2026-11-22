# copy to user-vms/<name>.nix — name must match ^[a-z][a-z0-9-]{1,15}$
# name is unique (one file = one seat). taken or reserved → reject.
# this file is NOT loaded (template.nix is ignored).
#
# after merge:
#   ssh you@you.tharavad.xyz
#   https://you.tharavad.xyz  (if publish set — run a server on that port)
#
# mesh/Headscale is internal only — you do not join a VPN.
{
  # github = "yourhandle";
  tier = "small"; # small | medium | large
  enabled = true;

  # Keep Nix user profiles and store registrations across VM reboots.
  # persistNixState = true;

  # paste from https://github.com/<you>.keys — must be non-empty
  keys = [
    # "ssh-ed25519 AAAA… comment"
  ];

  # optional public HTTPS (DNS wildcard already points at edge; TLS on edge)
  # publish = [
  #   { port = 3000; }                          # → https://you.tharavad.xyz
  #   { subdomain = "blog"; port = 8080; }      # → https://blog.tharavad.xyz
  # ];
}

