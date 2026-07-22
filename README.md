# mothership

```
git is the IdP · Nix is the compiler · ZFS is the quota · Headscale is the map
```

Bare-metal NixOS control plane for tinkerhub0. One host. One repo. Per-member
microVMs later. Not Authentik. Not Proxmox. Not a signup form.

| read | when |
|---|---|
| **[docs/MAIN.md](docs/MAIN.md)** | architecture, trust chain, threat model, phase map |
| **[docs/SETUP.md](docs/SETUP.md)** | metal → ZFS → mesh → `100.64.0.1` runbook |

```bash
nix develop
nix flake check
nix eval .#nixosConfigurations.mothership.config.mothership.mesh.mothershipIPv4
```

```
hosts/mothership/   this metal
modules/base        policy
modules/tools       operator surface
modules/mesh        headscale + tailscale serve
modules/deck        shared services (stubs)
docs/               the map and the runbook
```

**if you know you know.**
