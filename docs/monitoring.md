# Metrics and dashboards

> **Source of truth:** `modules/deck/metrics.nix` · `modules/deck/dashboards/mothership.json` · `hosts/mothership/default.nix`

Uptime Kuma tells you whether a service answers. It cannot tell you why a
member's [VM](glossary.md) is slow. This page explains the numbers we keep on
the host, and how to look at them.

## What runs where

Four native services run on mothership itself, not inside a member VM:

- **Prometheus** asks the other three for numbers every few seconds and keeps
  them for 15 days. It is the one place you can ask "what was the CPU doing
  last Tuesday?".
- **node_exporter** reports machine-wide CPU, memory, disks, network and
  systemd unit state.
- **cAdvisor** reads Linux **cgroups** — the accounting buckets the kernel
  keeps for each group of processes. Every microVM is a systemd service with
  its own cgroup, so cAdvisor can tell you which member is using the CPU. The
  `--docker_only=false` flag is what makes it look at all cgroups instead of
  only containers.
- **Grafana** draws the graphs. Prometheus is already set up as its default
  data source, and the "Mothership — host and microVMs" dashboard is installed
  from this repo.

All four listen on `127.0.0.1` only. They are not reachable from the internet
or from the mesh, so there is no new public port and no login to manage.

Grafana needs a signing key, but it is **not in git**. A small oneshot service
generates it on the first boot and keeps it in
`/var/lib/mothership/grafana/secret_key`, outside the world-readable Nix
store. It survives rebuilds, so saved Grafana settings keep working. Deleting
that file makes Grafana generate a new key on the next boot.

## Looking at it

As an admin, forward the port through the server:

```bash
ssh -L 3000:127.0.0.1:3000 mothership
```

Then open <http://localhost:3000> in your browser. The dashboard is under
**Dashboards → Mothership — host and microVMs**. It shows CPU idle, memory
available, load average, and the busiest cgroups. A cgroup named after a
member's VM is that member's VM.

The same numbers are available as plain text on the host:

```bash
curl -s http://127.0.0.1:9090/metrics | head     # Prometheus
curl -s http://127.0.0.1:9100/metrics | head     # node_exporter
curl -s http://127.0.0.1:3022/metrics | head     # cAdvisor
cat /etc/mothership/metrics.txt                  # ports and tunnel command
```

## Reading the graphs

**Load average** is not a percentage. It counts processes that are running or
waiting. As of 2026-11-23 the host had 88 logical CPUs and a load around 2.4,
so it was nearly idle. Compare load with the CPU count, not with 100.

**Memory available** is a better measure of free RAM than "free". Memory used
for disk cache can be handed back to programs, so the kernel counts it as
available. On 2026-11-23 the host had 62 GiB total and about 8 GiB available;
almost all of the rest was cache backing the VMs.

**Busiest cgroups** points at a member only when that member's virtual
machine is doing the work. Raw cgroups have no `name` label, so the graph
shows the `id` label — the cgroup path, which contains the systemd service
name. A `virtiofsd` cgroup is the host sharing files with a VM, so a big
number there is still caused by a VM.

## Adding a panel

Change `modules/deck/dashboards/mothership.json` in a PR. Grafana reloads the
file from the Nix store after deploy, so there is nothing to click in the UI.
If you add a service that should be watched, add a scrape job in
`modules/deck/metrics.nix` in the same PR, and update this page.

## What this does not do

It does not page anyone. There are no alert rules or credentials in git —
that keeps the repo free of secrets. Uptime Kuma remains the service that
tells you something is down. This stack is for figuring out why.
