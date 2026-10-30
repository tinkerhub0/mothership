# DNS

> **Source of truth:** `lib/site.nix` · `dns/tharavad.xyz.nix` · `.github/workflows/dns.yml`

Every public name under `tharavad.xyz` is a line of Nix in this repo.
[octoDNS](https://github.com/octodns/octodns) pushes it to Hetzner DNS.

## How a change goes live

```
edit dns/tharavad.xyz.nix ── PR ──► CI renders the zone and shows the plan
                                    (what would be added, changed, deleted)
                          ── merge ─► CI applies it to Hetzner
```

The server itself never rebuilds for a DNS change.

**Read the plan before you merge.** octoDNS makes Hetzner match git
exactly, so a record someone added by hand in the Hetzner console shows up
as a **Delete**. That's how we found the email records (`resend._domainkey`,
`send` MX + SPF): they'd been added by hand, and the first plan wanted to
remove them. So don't edit DNS in the console. Add it here.

## Why one wildcard is enough for members

```nix
"*" = a site.publicIPv4;
```

`*.tharavad.xyz` already points every name at the front door, so
`you.tharavad.xyz` works the moment your VM exists. Adding a member never
touches DNS.

## Records

| Name | Points to | For |
|---|---|---|
| `tharavad.xyz` | front door IP | landing page, operator SSH |
| `*.tharavad.xyz` | front door IP | every member's SSH and HTTPS |
| `status`, `headscale`, `chat`, `auth`, `monitor`, `wiki`, `landa`, `landa-back` | → `tharavad.xyz` | shared services |
| `resend._domainkey`, `send` | Resend / Amazon SES | outgoing email (DKIM, MX, SPF) |

## Changing the front door IP

The domain and the public IP live in **one file**, `lib/site.nix`.
`publicIPv4` is the Airtel static IP on WAN_D. It's `null` until that line
has its lease, and while it's `null` the zone refuses to render: the DNS
workflow fails instead of pointing names at nothing. The zone also refuses
the retired Hetzner edge (`retiredIPv4`). Set the IP, merge, and DNS
follows. The cutover order is in [The space's network](house-network.md#cutover-checklist).
Some host config still hardcodes the edge; that goes away with the edge
(`grep -r 178.105.120.5`).

## Try it locally

```bash
nix eval --json '.#dns.zones."tharavad.xyz"'    # exactly what octoDNS receives
```

## Certificates

Today the edge gets certificates with ACME **HTTP-01** (nginx answers a
challenge on port 80), one name at a time. For a real wildcard certificate
you need **DNS-01**: prove you own the domain by writing a TXT record. We
wrote [caddy-dns-hetzner-cloud](https://github.com/tinkerhub0/caddy-dns-hetzner-cloud),
a Caddy plugin that does this through Hetzner's new Cloud DNS API.
