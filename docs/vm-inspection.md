# Inspecting member VMs

> **Source of truth:** `modules/microvmctl.nix` · `hosts/mothership/default.nix` · `flake.lock`

When a member says their [VM](glossary.md) is slow, start here. `microvmctl`
is a small command on mothership that shows every member VM in one screen,
without logging in to any of them. It reads the same systemd services and
cgroups that the host uses to run the VMs.

## Getting it

The tool comes from a pinned input in `flake.lock`, so a rebuild always gets
the same version. `modules/microvmctl.nix` installs it on mothership only;
the edge host does not carry it. There is nothing to install by hand.

Log in to the server first:

```bash
ssh mothership@tharavad.xyz
```

## The commands

```bash
microvmctl                       # live, interactive view — start here
microvmctl list                  # name, state, uptime, memory, guest address
microvmctl top                   # live CPU and memory use
microvmctl status NAME           # running system generation and pending update
microvmctl logs NAME -f          # follow one VM's log
```

Replace `NAME` with a name from `microvmctl list`. The interactive view is
the quickest answer to "is anything broken right now?". It marks a VM that is
running an old system as outdated, which usually means its owner has not
rebuilt after a repo change.

## When you need sudo

The read-only commands above work as your normal user. A few details live
behind a private socket that only root can open. For those, use `sudo`:

```bash
sudo microvmctl top              # adds disk and network rates
sudo microvmctl status NAME      # adds disks, shares and paused state
sudo microvmctl pause NAME       # freeze a VM's CPUs
sudo microvmctl resume NAME      # thaw them again
```

The `console` and `ssh` commands also need extra guest settings. `console`
attaches to a text console; `ssh` goes over vsock, a direct host-to-guest
connection that does not need the VM on the network. For ordinary SSH into a
VM, see [Getting a machine](join.md).

## What it does not do

It does not change who owns a VM, and it is not the guest list — git is. It
only observes and, with root, pauses or resumes. For longer-term CPU and
memory graphs, ask an admin about the host's metrics.
