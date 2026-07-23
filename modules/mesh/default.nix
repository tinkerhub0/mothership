# mesh — Headscale control plane + host tailscaled + optional CF tunnel.
# data plane for later member SSH. not deck auth. not the IdP (git is).
{
  imports = [
    ./headscale.nix
    ./tailscale.nix
    ./cloudflare.nix
  ];
}
