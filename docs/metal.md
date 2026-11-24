# The server

> **Source of truth:** `hosts/mothership/default.nix` · `hardware-configuration.nix` · `disko.nix`

Everything here was measured on the live box on 2026-10-29.

## Specs

| | |
|---|---|
| Model | Dell PowerEdge R730xd (2U rack server, 2016 era) |
| CPU | 2× Intel Xeon E5-2699 v4: 44 cores, 88 threads |
| RAM | 62 GB |
| Network | 4× Broadcom BCM57800 ports (`eno1`–`eno4`). The cable is in **`eno3`** |
| Disk controller | Dell PERC H730 Mini |
| Disks | 6× 1 TB 2.5" SAS hard drives |
| Storage | one RAID5 array, 4.5 TB, seen by Linux as `/dev/sda` |
| Remote control | iDRAC8, not cabled yet |

## The disks, honestly

The server runs on the ext4 filesystem from the original NixOS install.
`disko.nix` describes a nicer ZFS layout, but **it isn't active**
(`useDisko = false`). Switching it on over this install breaks boot, and
that has already happened once.

The RAID5 array is **degraded**: the disk in slot 6 has failed, so the other
five carry everything, with no safety margin. We've left it like this on
purpose. Nothing on the server is precious. See [why-this-exist](../why-this-exist).

Check it yourself:

```bash
NIXPKGS_ALLOW_UNFREE=1 sudo -E nix shell --impure nixpkgs#storcli -c storcli /c0 show
```

## Power

```bash
sudo nix shell nixpkgs#ipmitool -c ipmitool dcmi power reading
```

| State | Watts |
|---|---|
| Idle | 151 |
| Rebuilding the whole config (average / peak) | 187 / 334 |
| Published benchmark idle, same CPUs, R730 | ~45 ([SPEC](https://spec.cs.miami.edu/power_ssj2008/results/res2016q2/power_ssj2008-20160328-00719.html)) |

That's about 110 kWh a month just idling. We probably draw 3× the
benchmark because of six spinning disks and the default BIOS power
settings. Air goes in at 29 °C and comes out at 35 °C.

## Boot

```
firmware 11m48s + loader 8s + kernel 1s + initrd 22s + userspace 1m16s = 13m36s
```

Linux itself is quick. **The Dell's power-on checks (POST) take almost 12
minutes.** Likely causes: the RAID card pausing on the degraded-array
warning, network-boot checks on four ports, and Dell's hardware inventory
scan. Turning those off is [drill #1](drills.md#drills-to-run).

## Memory budget

All enabled members together are assigned **94 GB of RAM** (2026-10-29) on
a 62 GB server. It works because idle VMs use far less than they're given.
If many get busy at once, the server runs out of memory and starts killing
VMs. The safety check (`maxTotalMemMiB`) is set to 100 GB, so it doesn't
catch this. Lowering it to the real 62 GB is one line.
