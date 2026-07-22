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
modules/deck        shared services (stubs)
why-this-exist      the only prose we keep
```

there is no docs/ folder on purpose. the config is the map.
