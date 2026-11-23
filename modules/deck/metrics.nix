# metrics — white-box monitoring on the host.
# uptime-kuma answers "is it up?"; this answers "why is it slow?".
# everything binds to 127.0.0.1: reach Grafana over an SSH tunnel, never a port.
# per-VM numbers come from cAdvisor reading cgroups: --docker_only=false makes
# it count every cgroup, not just containers. each microVM is a systemd
# service with its own cgroup, so it shows up as a scrape target.
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.deck.metrics;
in
{
  options.mothership.deck.metrics = {
    enable = lib.mkEnableOption "Prometheus metrics and Grafana dashboards on the host";

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Prometheus bind port (127.0.0.1 only).";
    };

    nodeExporterPort = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "node_exporter bind port (127.0.0.1 only).";
    };

    cadvisorPort = lib.mkOption {
      type = lib.types.port;
      default = 3022;
      description = "cAdvisor bind port (127.0.0.1 only).";
    };

    grafanaPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Grafana bind port (127.0.0.1 only).";
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "15d";
      description = "How long Prometheus keeps samples before dropping old ones.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = cfg.prometheusPort;
      retentionTime = cfg.retentionTime;
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.nodeExporterPort}" ];
              labels = { instance = "mothership"; };
            }
          ];
        }
        {
          job_name = "cgroups";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.cadvisorPort}" ];
              labels = { instance = "mothership"; };
            }
          ];
        }
      ];
    };

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = cfg.nodeExporterPort;
      # unit state is the cheapest early warning that a VM service died.
      enabledCollectors = [ "systemd" ];
    };

    services.cadvisor = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = cfg.cadvisorPort;
      extraOptions = [ "--docker_only=false" ];
    };

    services.grafana = {
      enable = true;
      settings.server = {
        http_addr = "127.0.0.1";
        http_port = cfg.grafanaPort;
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.prometheusPort}";
            isDefault = true;
          }
        ];
        dashboards.settings.providers = [
          {
            name = "mothership";
            options.path = "/etc/mothership/grafana-dashboards";
          }
        ];
      };
    };

    environment.etc."mothership/grafana-dashboards/mothership.json".source =
      ./dashboards/mothership.json;

    environment.etc."mothership/metrics.txt".text = ''
      Host metrics (deck service, not a member VM)

      Prometheus:  http://127.0.0.1:${toString cfg.prometheusPort}
      node_export: http://127.0.0.1:${toString cfg.nodeExporterPort}
      cAdvisor:    http://127.0.0.1:${toString cfg.cadvisorPort}
      Grafana:     http://127.0.0.1:${toString cfg.grafanaPort}
      retention:   ${cfg.retentionTime}

      Reach the UI from your laptop:
        ssh -L ${toString cfg.grafanaPort}:127.0.0.1:${toString cfg.grafanaPort} mothership

      Nothing here listens on a public or mesh address. Uptime Kuma remains
      the "is it up?" monitor; these numbers explain "why is it slow?".
    '';
  };
}
