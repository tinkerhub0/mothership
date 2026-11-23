Source of truth: [`modules/monitoring/default.nix`](../modules/monitoring/default.nix), [`modules/monitoring/dashboards/`](../modules/monitoring/dashboards/) and [`hosts/mothership/default.nix`](../hosts/mothership/default.nix).

# Host monitoring

Uptime Kuma checks whether a service answers. This stack helps explain why
mothership is slow. Prometheus stores measurements over time; node_exporter
reports host CPU, memory, disks, network and systemd service states. cAdvisor
reports resource use by **cgroup**, the Linux accounting group for a service.
Grafana turns those measurements into charts. See the [glossary](glossary.md)
for VM, mesh and SSH.

The host enables this with `mothership.monitoring.enable = true`. Disabling
that option stops the stack without removing its stored data.

## Open the dashboards

All listeners use `127.0.0.1`: Grafana on port `3000`, Prometheus on `9090`,
node_exporter on `9100`, and cAdvisor on `8081`. No firewall ports or public
routes are added. From an admin laptop, keep this SSH tunnel open:

```bash
ssh -N -J root@178.105.120.5 -L 3000:127.0.0.1:3000 root@10.99.0.2
```

Open http://localhost:3000 and browse the dashboards. SSH checks your admin
key through the existing edge route. The `mothership@tharavad.xyz` shell
shortcut cannot forward ports, so use the explicit jump above. Grafana grants
anonymous **Viewer** access on loopback: anyone who can reach the host's loopback can read the
measurements. There is no initial admin account, login form or signup.
Dashboard and datasource changes belong in git.

Node Exporter Full (Grafana ID 1860) shows the host. The Mothership microVMs
and virtiofsd dashboard shows separate CPU and memory lines for each VM
service and each VM's virtiofsd service (the process sharing host files with
the VM). The dashboard files and Prometheus datasource are provisioned on
startup; no browser import is needed. The dashboard directory records the
upstream revision and local adjustments.

cAdvisor explicitly uses `--docker_only=false` so it collects raw systemd
cgroups, including `microvm@…service` and `microvm-virtiofsd@…service`.
The charts group by the `id` cgroup path, not Docker container names.
CPU is measured in cores used. Parent slices are excluded to avoid counting
the same work twice. Disk charts depend on kernel I/O accounting. These are
host measurements; they do not show processes inside guests, and tap network
traffic is not attributed per VM by this dashboard.

## Storage and checking a deploy

Configured on 2026-11-24: Prometheus scrapes every `30s` and keeps `15d` of
history. This is a time limit, not a disk quota. Watch host free space in
Node Exporter Full before increasing retention. Prometheus stores data under
`/var/lib/prometheus2`; Grafana stores its database under `/var/lib/grafana`.
Grafana generates its private database encryption key at first start in
`/var/lib/grafana/secret-key`, readable only by the Grafana user. The file
provider loads it at runtime; no key value enters git or the Nix store. Keep
it with the database if backing up or restoring Grafana.
Monitoring data survives service restarts. There is no metrics backup in this
change.

On the host after git-sync deploys:

```bash
systemctl status prometheus prometheus-node-exporter cadvisor grafana
curl -fsS http://127.0.0.1:9090/api/v1/targets
curl -fsS http://127.0.0.1:8081/metrics | grep 'id=".*microvm'
systemctl show microvm@omnibox.service -p ControlGroup
journalctl -u cadvisor -u prometheus -u grafana -n 100
```

Both scrape targets should have `health: up`. The metrics should include
leaf cgroup paths for VM and virtiofsd services. If the host charts work but
VM charts are empty, compare those paths with the dashboard's `id` filter
and check cAdvisor logs. Do not remove the raw cgroup flag to hide the issue.

## Alerting follow-up

Alertmanager and notification delivery are not configured. An operator still
needs to choose useful thresholds and a destination for alerts. Add any
required credentials using sops-encrypted files in `secrets/`, with the
human recipients from `lib/adminKeys.nix` and `.sops.yaml`; load decrypted
credentials at runtime. Never put SMTP passwords or webhook tokens in Nix,
dashboard JSON or a PR. Until then, use Kuma for existing availability checks
and these dashboards for investigation.
