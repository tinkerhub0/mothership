# The space's network

> **Source of truth:** `hosts/tharavadmathil/default.nix` · `lib/opnsense.nix` · `lib/site.nix` · `dns/tharavad.xyz.nix`

One firewall, separate rooms. Servers, members and management each get
their own network, and the firewall decides who can talk to whom. Nothing
is bridged together "just because".

## The rooms

| Network | Port | Subnet | Who's in it | Internet via |
|---|---|---|---|---|
| **SERVERS** | Port 2 | `10.20.0.0/24`, gateway `.1` | mothership at `10.20.0.10` (reserved by MAC) | WAN_D only |
| **MEMBERS** (LAN) | Port 3 → Netgear | `192.168.12.0/23` | Wi-Fi, desks, laptops | FAILOVER (A → B → C) |
| **MGMT** (planned) | Port 4 | `10.30.0.0/24` | iDRAC, switch admin | none |
| **WAN_D** | Port 9 | DHCP from Airtel's router | Airtel static IP | n/a, it *is* the uplink |
| WAN_A / B / C | Ports 11 / 12 / 10 | DHCP | the three shared lines | n/a |

```
 airtel static ──► Port 9  WAN_D ──┐
 line A/B/C   ──► Ports 10–12 ─────┤
                                   │  tharavadmathil (OPNsense)
                                   ├──► Port 2  SERVERS 10.20.0.0/24 ─► mothership .10
                                   ├──► Port 3  MEMBERS 192.168.12.0/23 ─► netgear ─► APs
                                   └──► Port 4  MGMT 10.30.0.0/24 (planned) ─► iDRAC
```

## The rules, in words

- **Members → servers:** only the public services: TCP 22, 80, 443, 8080
  (`ServerPortsTCP`) and UDP 41641 (Tailscale). Everything else is blocked.
  Members get to mothership the same way the internet does.
- **Servers → members / private nets:** blocked. A compromised VM can't
  scan your laptop.
- **Servers → internet:** out WAN_D, the static line, with **no fallback**.
  If Airtel is down, the servers are down. That's on purpose: a fallback
  would send server traffic out of an IP that DNS doesn't point at.
- **WAN_D guard:** anything leaving Port 9 that isn't from WAN_D's own
  address gets blocked. Members can never end up on the static IP, even
  when a rule is wrong.
- **Inbound:** Airtel's router forwards (or DMZs) to WAN_D, and the
  firewall maps 22, 80, 443, 8080 and UDP 41641 1:1 to `10.20.0.10`.

## DNS follows the static IP

`*.tharavad.xyz` and the apex point at `site.publicIPv4` in `lib/site.nix`.
That value is the Airtel static IP. It stays `null` until WAN_D has a lease
and the IP has been checked from outside. While it's `null`, the zone
**refuses to render**, so the DNS workflow can't apply a half-done change.
It also refuses the old Hetzner edge address. Nothing in DNS points at a
Hetzner machine. The zone itself is still *hosted* on Hetzner DNS; moving
that means changing nameservers at the registrar, which is a separate step.

## Cutover checklist

Do these in order. Each one is safe to stop after.

1. ✅ Port 9 out of the LAN bridge → WAN_D.
2. ✅ Port 2 out of the bridge → SERVERS, with mothership reserved at `.10`.
3. ⬜ WAN_D gets a lease from Airtel. Check that it's a public IP and not
   CGNAT (`100.64.0.0/10`) or a private `192.168.x`, unless the router is
   in bridge/DMZ mode.
4. ⬜ SERVERS → internet rule: gateway `FAILOVER` → `WAN_D_DHCP`.
5. ⬜ Outbound NAT for SERVERS on WAN_D; 1:1 / port-forwards to `.10`.
6. ⬜ Move the edge's jobs onto mothership: bastion `:22`, nginx + ACME
   `:80/:443`, Headscale `:8080`, the landing page.
7. ⬜ `lib/site.nix`: set `publicIPv4`. Merge, DNS follows. Watch it for a day.
8. ⬜ Switch off the Hetzner VPS.

Until step 7, the edge still works: mothership dials out to it over
WireGuard, from whichever network it's on.

## Lessons learned the hard way

- **dnsmasq only answers DHCP on interfaces in its list.** A DHCP range on
  SERVERS did nothing until SERVERS was added to dnsmasq's interfaces.
  mothership sat there asking for an address and got no answer. Now
  `lib/opnsense.nix` builds that list from every interface that has a
  range, so this can't drift again.
- **Pull one port out of the bridge at a time.** Pulling several while it
  was running made two internet lines swap addresses.
- **A port with nothing answering looks exactly like a broken config.**
  When WAN_D first came up, it saw a couple hundred packets and then
  silence: no DHCP offer, no ARP reply. Check the far end (the router's
  LAN port and mode) before you debug your own side.
- **Have the console ready** (`/dev/cuau3`, 115200) for anything that
  touches interfaces. The API you're using can disappear mid-change.
