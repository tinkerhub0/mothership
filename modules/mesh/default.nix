# Mesh plane: Headscale control + host Tailscale client.
# Outside git-as-IdP for web apps; *is* the data plane for member SSH later.
{
  imports = [
    ./headscale.nix
    ./tailscale.nix
  ];
}
