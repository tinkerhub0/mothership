# How traffic reaches your VM

> **Source of truth:** `modules/mesh/*` · `modules/bastion.nix` · `modules/member-publish.nix` · `modules/microvms/default.nix` · `modules/deck/network.nix` · `hosts/edge/default.nix`

New to these words? [Glossary](glossary.md).

## The big picture (2026-10-29)

```
                    internet
                       │
        *.tharavad.xyz │ points at 178.105.120.5
                       ▼
     ┌────────────── edge (rented VPS) ──────────────┐
     │  :22 SSH bastion · :443 HTTPS · :8080 mesh    │
     └──────────────────────┬────────────────────────┘
                            │ WireGuard tunnel (UDP 51820)
                            │ edge 10.99.0.1 ⇄ mothership 10.99.0.2
                            ▼
     ┌────────────── mothership (in the space) ──────┐
     │  internet via Airtel (eno3, 192.168.1.52)     │
     │  mesh coordinator, VMs on 100.64.0.0/10       │
     │  br-members 10.43.0.1/16 → one tap per VM     │
     │  br-deck    10.42.0.1/16 → shared services    │
     └───────────────────────────────────────────────┘
```

**The key trick:** mothership opens no ports to the internet. It *dials out*
to the edge and keeps the tunnel open. That's why it works behind Airtel's
router, the space's firewall, or both, without needing a static IP.

## SSH

```
your laptop → edge :22 (checks your key) → tunnel → mothership → your VM
```

`ssh you@you.tharavad.xyz` takes you straight to your VM. The part before
the `@` picks the destination.

## Public HTTPS

```
browser → edge :443 (HTTPS certificate here)
        → tunnel → mothership :9080
        → http://you.mothership:<port>   (your VM, by mesh name)
```

The certificate lives on the edge, so your app only has to speak HTTP.

A VM's name only serves a website after its member file adds a `publish`
entry (see [Put a website online](join.md#put-a-website-online)). For a name
without a web route, the edge returns "No website configured for this
hostname" over HTTP. It rejects the HTTPS connection because it has no
certificate for that name. It does not serve another member's site or the
landa console. SSH access works independently of website publishing.

## The mesh

Every VM runs Tailscale and joins our Headscale server on mothership, so
VMs can reach each other by name, e.g. `ssh alvin.mothership` from inside
another VM. You don't install anything on your laptop. The mesh is internal
plumbing.

## Inside mothership

Each VM plugs into a virtual switch (`br-members`) and reaches the internet
through mothership (NAT). Shared services like monitoring sit on a separate
switch (`br-deck`).

## What's next

These are plans, not current state:

- **Move the cables** (in progress, 2026-10-30): Airtel on firewall Port 9 (WAN_D), mothership on Port 2 (SERVERS, `10.20.0.10`). See [The space's network](house-network.md).
- **Drop the edge:** with the Airtel static IP, everything the edge does moves onto mothership and DNS points home (`lib/site.nix`). We need to confirm Airtel isn't putting us behind its own NAT (CGNAT) first.
- **IPv6:** Airtel already gives us IPv6. Turn it on for the LAN, then go IPv6-mostly like the [CCC congress](https://events.ccc.de/congress/2025/infos/network.html).
- **Wi-Fi logins from git:** with a VLAN-capable switch, WPA-Enterprise accounts generated from `user-vms/`. One PR, a VM *and* Wi-Fi.
- **VM isolation** ([#92](https://github.com/tinkerhub0/mothership/pull/92)): each VM may only send from its own MAC and IP, outbound email (port 25) is blocked, and connections are capped per VM. All of it is generated from `user-vms/`, the same idea as Hetzner Cloud's per-VM network rules.

The firewall side: [house-firewall.md](house-firewall.md).
