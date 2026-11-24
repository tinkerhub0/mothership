# Drills

Nothing on mothership is precious, so we break it on purpose. **The score
is how long it takes to go from wiped to working, using only git.** Each
drill gets measured and published, and the number should keep shrinking.

## Scoreboard

| Date | What | Result |
|---|---|---|
| 2026-10-29 | Build the whole server config from a fresh clone | 5 min 23 s · 873 steps · 6.1 GB |
| 2026-10-29 | Energy used by that build | ~17 Wh (average 187 W) |
| 2026-10-29 | Power at idle | 151 W |
| 2026-10-29 | Power on → logged in | 13 min 36 s (11 min 48 s of that is POST) |
| — | Bare metal → every member back | not measured yet |

Add a row for every drill. Never edit an old row, because the history is the point.

## How to measure

```bash
# power, sampled every 3 s while something runs (Ctrl-C to stop)
while sleep 3; do sudo nix shell nixpkgs#ipmitool -c ipmitool dcmi power reading \
  | awk '/Instantaneous/{print $4}'; done > watts.txt

# build time, without changing the running server
d=$(mktemp -d) && git clone -q --depth 1 https://github.com/tinkerhub0/mothership "$d/r"
time nix build --no-link "$d/r#nixosConfigurations.mothership.config.system.build.toplevel"

# where boot time goes
systemd-analyze
```

## Drills to run

Pick one up and open an issue to claim it.

1. **Faster boot.** Switch off network boot on unused ports, Dell's
   inventory scan and the memory test. Goal: POST under 3 minutes.
2. **Lower power.** Try the BIOS "Performance Per Watt (OS)" profile and
   `powertop`. Goal: get idle closer to the ~45 W benchmark.
3. **The big one.** Set the RAID card to pass-through (HBA) mode, reinstall
   with ZFS (`useDisko = true`, `nixos-anywhere`), and let every member VM
   come back from `user-vms/`. Time it from power-off to the last working
   `ssh`.
4. **Retire the edge.** Move to an Airtel static IP and run the front door
   on mothership. Measure the downtime.
5. **Netboot.** Any spare PC boots NixOS over the network from mothership
   and joins the mesh. Time it from power button to `tailscale status`.
6. **Fork guide.** Make it easy for another hackerspace to run their own
   mothership.

## Why we do this

[comma.ai runs its own data center](https://blog.comma.ai/datacenter/). By
their estimate it cost about $5M, against $25M+ for the same in the cloud,
and the post making that case is mostly numbers. This is the one-server
version of the same habit: own it, measure it, publish it.
