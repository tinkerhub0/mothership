# Glossary

The words you'll see around this repo, in plain language.

**VM (virtual machine)**: a computer that runs as a program on another
computer. Yours has its own operating system, its own root user and its
own disk, all inside mothership. We use **microVMs**: small, fast-booting VMs
built with [microvm.nix](https://github.com/microvm-nix/microvm.nix).

**Nix / NixOS**: [Nix](https://nixos.org) builds software from a written
recipe, the same way every time. NixOS is a Linux distribution where the
*whole system* is one such recipe. Change the recipe, rebuild, and the
machine matches it. That's why this repo can describe a full server.

**Flake**: the entry point of a Nix project (`flake.nix`). It pins the exact
versions of everything, so a build today and a build next month match.

**Pull request (PR)**: a proposed change on GitHub. Here, PRs are also how
people get access.

**git-sync**: a small service on the server that pulls `main` every two
minutes and rebuilds itself when something changed.

**SSH**: how you log in to a remote machine from a terminal. SSH **keys**
are a pair: a public half you share (it goes in your member file) and a
private half that never leaves your laptop.

**Bastion**: a gatekeeper SSH server. You connect to it, and it forwards
you to your VM.

**Edge**: our small rented server with a public address. It's the front
door, so mothership doesn't need to be reachable from the internet itself.

**WireGuard**: a simple, fast VPN. mothership keeps a WireGuard tunnel open
to the edge, and that's how traffic gets in.

**Mesh / Tailscale / Headscale**: [Tailscale](https://tailscale.com) connects
machines into one private network wherever they are.
[Headscale](https://github.com/juanfont/headscale) is the open-source server
that coordinates it, and ours runs on mothership. Every VM joins, so VMs can
reach each other by name (`alvin.mothership`).

**MagicDNS**: the mesh's built-in naming. `<name>.mothership` finds that VM.

**Bridge / tap**: a virtual network switch (`br-members`) and the virtual
cables (taps) that plug each VM into it.

**NAT**: sharing one public address among many machines. Your VM reaches the
internet through mothership's address.

**RAID**: combining several disks into one. Ours is RAID5: six disks, and it
survives losing one. It has already lost one.

**PERC / iDRAC**: Dell parts. The PERC is the disk controller card. The
iDRAC is a tiny computer inside the server that lets you power it on, see
its screen and read its power use over the network, even when the server
itself is broken.

**POST**: the checks a server runs when you switch it on, before the
operating system starts. Ours takes almost 12 minutes. See [drills](drills.md).

**OPNsense**: open-source firewall software. Ours runs on a Sophos XGS box.

**sops**: a tool for keeping secrets in git *encrypted*, so only admins can
read them.

**Drill**: breaking something on purpose and timing how long it takes to
bring it back from git.
