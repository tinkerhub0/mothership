# Documentation

**New here?** Start with [Getting a machine](join.md). Then read the rest in
order. Each page takes about five minutes.

| | Page | You'll learn |
|---|---|---|
| 1 | [Getting a machine](join.md) | sign up, SSH in, put a website online |
| 2 | [Keeping your seat](seats.md) | what counts as using your VM, and what happens if you don't |
| 3 | [Glossary](glossary.md) | VM, Nix, mesh, WireGuard and the rest, in plain words |
| 4 | [How traffic reaches your VM](network.md) | every hop from the internet to your machine |
| 5 | [The server](metal.md) | the hardware: CPUs, disks, power, boot |
| 6 | [How deploys work](deploy.md) | what happens between "merge" and "running" |
| 7 | [Operating it](ops.md) | for admins: getting in, logs, undoing a bad change |
| 8 | [The space's firewall](house-firewall.md) | the XGS firewall, configured from git |
| 9 | [DNS](dns.md) | every public name, managed from git |
| 10 | [Running NixOS on Hetzner](hetzner.md) | our front door VPS, reusable for your own project |
| 11 | [Drills](drills.md) | breaking it on purpose and timing the comeback |

## The one rule

The docs explain, the code decides. Every page starts with a **Source of
truth** line naming the files it describes. If a doc and the code disagree,
the code is right and the doc has a bug. Please fix it in your PR.

Numbers carry the date they were measured. If one looks stale, measure it
again rather than deleting it.
