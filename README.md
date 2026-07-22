# mothership

git is the IdP. nix compiles reality. one box.

read **[why-this-exist](why-this-exist)** before you touch anything.

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
modules/microvms    user-vms/* → guests
modules/deck        shared services (stubs)
user-vms/           members (one .nix each) — git is the IdP
lib/mkMemberVM.nix  one file → guest
scripts/signup      writes a member file for a PR (not a control plane)
why-this-exist      the only prose we keep
```

unique IP per member: tailscale inside the guest → headscale (`100.64.0.0/10`).
there is no docs/ folder on purpose. the config is the map.
