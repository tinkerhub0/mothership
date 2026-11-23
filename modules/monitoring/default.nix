{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.monitoring;
in
{
  options.mothership.monitoring.enable = lib.mkEnableOption "private host and microVM monitoring";

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9090;
      retentionTime = "15d";
      globalConfig.scrape_interval = "30s";
      exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9100;
        openFirewall = false;
        enabledCollectors = [
          "systemd"
          "processes"
        ];
      };
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
        {
          job_name = "cadvisor";
          static_configs = [ { targets = [ "127.0.0.1:8081" ]; } ];
        }
      ];
    };

    services.cadvisor = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8081;
      # Raw systemd cgroups include microvm@ and microvm-virtiofsd@ units.
      extraOptions = [ "--docker_only=false" ];
    };

    # Runs as grafana, before startup, and preserves the key across rebuilds.
    systemd.services.grafana.preStart = lib.mkBefore ''
      if [ ! -s /var/lib/grafana/secret-key ]; then
        umask 077
        ${pkgs.openssl}/bin/openssl rand -hex 32 > /var/lib/grafana/secret-key.tmp
        mv /var/lib/grafana/secret-key.tmp /var/lib/grafana/secret-key
      fi
    '';

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = "localhost";
        };
        # SSH authenticates operators. No default admin account or password.
        security = {
          disable_initial_admin_creation = true;
          secret_key = "$__file{/var/lib/grafana/secret-key}";
        };
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
        auth.disable_login_form = true;
        users.allow_sign_up = false;
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
            editable = false;
          }
        ];
        dashboards.settings.providers = [
          {
            name = "mothership";
            options.path = ./dashboards;
            disableDeletion = true;
            allowUiUpdates = false;
          }
        ];
      };
    };
  };
}
