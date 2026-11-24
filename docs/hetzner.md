# Running NixOS on Hetzner

> **Source of truth:** `hosts/edge/` · `scripts/install-edge.md` · `dns/` · [caddy-dns-hetzner-cloud](https://github.com/tinkerhub0/caddy-dns-hetzner-cloud)

Our front door (`edge`) is a Hetzner Cloud VPS running NixOS, and our DNS is
Hetzner DNS. Everything we learned doing that is written down here, so you
can copy it for your own project.

## What we run there

| | |
|---|---|
| Server | Hetzner Cloud VPS, public IPv4 `178.105.120.5` |
| OS | NixOS from this flake (`.#edge`), base hardening from [srvos](https://github.com/nix-community/srvos) |
| Disk | one disk: EFI partition + ext4 (`hosts/edge/disko.nix`). No ZFS, on purpose: the edge stays dumb |
| Network | DHCP on `eth0`, gateway `172.31.1.1`, Hetzner resolvers `185.12.64.1` / `.2` |
| Job | WireGuard to mothership, SSH bastion, nginx + Let's Encrypt, the landing page |

## Install NixOS on a Hetzner VPS

Hetzner doesn't offer a NixOS image, so we create the server with Ubuntu
and replace it over SSH with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere):

```bash
# 1. create the VPS with Ubuntu 24.04 and your SSH key, then from this repo:
nix run github:nix-community/nixos-anywhere -- --flake .#edge --build-on remote root@<ip>
```

This **wipes the disk**. Full steps, including checking the disk name
(`sda` vs `nvme0n1`) and the post-install checks: [scripts/install-edge.md](../scripts/install-edge.md).

Gotchas we hit:

- Keep the interface named `eth0` (`networking.usePredictableInterfaceNames = false`)
  so the config matches the rescue system.
- Hetzner Cloud's default gateway is `172.31.1.1`, which isn't inside your
  subnet. Set it explicitly with the interface (`hosts/edge/default.nix`).
- Rebuilding in place keeps your IPv4. Deleting and recreating the server doesn't.

## DNS as code

Hetzner DNS now lives in the Cloud console and API. The old DNS Console API
(`dns.hetzner.com`) **shut down in May 2026**. Use a Cloud API token. How we
manage the zone from git: [dns.md](dns.md).

## Wildcard certificates

[caddy-dns-hetzner-cloud](https://github.com/tinkerhub0/caddy-dns-hetzner-cloud)
is our Caddy plugin for ACME DNS-01 on the new Cloud API:

```
tls {
  dns hetzner_cloud {env.HETZNER_TOKEN}
}
```

## Copy this

Want the same setup for your project? Take `hosts/edge/`, `modules/base.nix`,
`modules/acme.nix` and `dns/`, change `lib/site.nix`, and run the install
above. If something here is wrong or out of date, open an issue. This page
is meant to be the one you'd want to find.
