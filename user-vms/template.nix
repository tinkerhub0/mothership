# copy to user-vms/<name>.nix — name must match ^[a-z][a-z0-9-]{1,15}$
# this file is NOT loaded (template.nix is ignored).
#
# unique IP: guest runs tailscale → headscale assigns 100.64.x.x
# and MagicDNS <name>.mesh.tinkerhub after join.
{
  # github = "yourhandle";  # optional, for humans reading the pr
  tier = "small"; # small | medium | large
  enabled = true;

  # paste from https://github.com/<you>.keys — must be non-empty
  keys = [
    # "ssh-ed25519 AAAA… comment"
  ];
}
