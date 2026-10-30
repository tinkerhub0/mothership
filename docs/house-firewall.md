# The space's firewall

> **Source of truth:** `hosts/tharavadmathil/default.nix` · `lib/opnsense.nix` · `scripts/opnsense-*`

`tharavadmathil` is the router and firewall for the whole space: a Sophos
XGS 126 running [OPNsense](https://opnsense.org). OPNsense isn't NixOS, so
its config lives in git as **data**. `nix flake check` validates it, and a
script sends it to the firewall over OPNsense's API.

## Ports

| Port | Role |
|---|---|
| LAN bridge (Port 3–8, F1, F2) | MEMBERS `192.168.12.1/23`; DHCP hands out `.12.10`–`.13.250` |
| Port 2 | SERVERS `10.20.0.1/24`, mothership reserved at `.10` |
| Port 9 | WAN_D, Airtel static, servers only |
| Port 11 | internet line A |
| Port 12 | internet line B |
| Port 10 | internet line C (Jio) |
| Port 3 | → Netgear JGS516 switch → Wi-Fi access points, desks |

How the networks are split and what may talk to what:
[The space's network](house-network.md).

The three shared internet lines form a failover group: if A goes down, traffic
moves to B, then C.

## Making a change

```bash
source scripts/opnsense-env          # loads API credentials (encrypted with sops)
scripts/opnsense-apply               # dry run: shows what would change
scripts/opnsense-apply --apply       # actually change it
scripts/opnsense-backup              # save the full config, encrypted, to secrets/
```

`opnsense-apply` **never deletes anything**. Settings on the firewall that
git doesn't mention get listed, not removed.

## Not in git

Secrets (API key, root password, certificates) and the XGS-specific
hardware plugin settings.

## Lessons learned the hard way

- Pulling ports out of the LAN bridge while it was running made two
  internet lines swap addresses. Change one cable at a time, and dry-run first.
- Serial console: `/dev/cuau3`, 115200 baud.
- An API key passed as a `curl` argument showed up in output. Feed it on
  stdin (`curl -K -`) instead.
