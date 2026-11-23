Source of truth: `../default.nix` and the JSON files in this directory.

`node-exporter-full.json` is Node Exporter Full, Grafana dashboard 1860,
revision 42, downloaded on 2026-11-24 from:
https://grafana.com/api/dashboards/1860/revisions/42/download

Upstream: https://github.com/rfmoz/grafana-dashboards (Apache-2.0).
The database ID is cleared and the datasource variable defaults to the
provisioned Prometheus UID. Other dashboard content is unchanged.

`cadvisor.json` is maintained here. It selects leaf service cgroups by `id`
for both `microvm@…` and `microvm-virtiofsd@…`, rather than Docker labels.
Parent slices are excluded to avoid double counting.
