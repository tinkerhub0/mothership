# activity — who actually uses their seat, and a polite way out for who doesn't.
#
#   member-activity (hourly)  first-seen / last ssh / last real VM work per member
#                             → /var/lib/mothership/activity/activity.json
#   prune-inactive  (daily)   warn at warnDays, PR to park at parkDays,
#                             PR to delete deleteDays after parking. humans merge.
#
# inactive = no ssh login AND the VM stayed under the cpu + network floor.
# prune.enable = false (default) still runs it in dry-run, so the journal shows
# what it would do: journalctl -u prune-inactive
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.microvms.activity;
  vms = config.mothership.microvms;
  sync = config.mothership.gitSync;
  stateDir = "/var/lib/mothership/activity";
in
{
  options.mothership.microvms.activity = {
    enable = lib.mkEnableOption "per-member activity tracking" // {
      default = true;
    };

    sshHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "root@10.99.0.1";
      description = "host whose sshd logs show bastion logins. null = this host's journal.";
    };

    sshIdentity = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    cpuSecondsPerHour = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "guest cpu seconds per hour that count as use";
    };

    netKiBPerHour = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2048;
      description = "guest network KiB (in+out) per hour that count as use";
    };

    prune = {
      enable = lib.mkEnableOption "open warn/park/delete issues and PRs (otherwise dry-run)";
      warnDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7;
      };
      parkDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
      };
      deleteDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "days after parking before the delete PR";
      };
      exempt = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "seats never pruned (house and service seats)";
      };
    };
  };

  config = lib.mkIf (vms.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.prune.warnDays < cfg.prune.parkDays;
        message = "mothership.microvms.activity: warnDays must be < parkDays";
      }
    ];

    systemd.tmpfiles.rules = [ "d ${stateDir} 0750 root root -" ];

    systemd.services.member-activity = {
      description = "sample member VM use and bastion logins";
      path = with pkgs; [
        bash
        coreutils
        gnugrep
        gnused
        systemd
        openssh
      ];
      environment = {
        ACTIVITY_STATE = stateDir;
        ACTIVITY_CPU_SECONDS = toString cfg.cpuSecondsPerHour;
        ACTIVITY_NET_KIB = toString cfg.netKiBPerHour;
      }
      // lib.optionalAttrs (cfg.sshHost != null) { ACTIVITY_SSH_HOST = cfg.sshHost; }
      // lib.optionalAttrs (cfg.sshIdentity != null) { ACTIVITY_SSH_IDENTITY = cfg.sshIdentity; };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${../../scripts/member-activity}";
        Nice = 15;
      };
    };
    systemd.timers.member-activity = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1h";
      };
    };

    systemd.services.prune-inactive = {
      description = "warn, park, delete inactive seats (as PRs)";
      after = [ "member-activity.service" ];
      path = with pkgs; [ git ];
      environment = {
        PRUNE_STATE = stateDir;
        PRUNE_ACTIVITY = "${stateDir}/activity.json";
        PRUNE_SRC = sync.srcDir;
        PRUNE_TOKEN_FILE = sync.notify.tokenFile; # same token as deploy-notify
        PRUNE_WARN_DAYS = toString cfg.prune.warnDays;
        PRUNE_PARK_DAYS = toString cfg.prune.parkDays;
        PRUNE_DELETE_DAYS = toString cfg.prune.deleteDays;
        PRUNE_EXEMPT = lib.concatStringsSep " " cfg.prune.exempt;
      }
      // lib.optionalAttrs (!cfg.prune.enable) { PRUNE_DRY_RUN = "1"; };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 -I ${../../scripts/prune-inactive}";
      };
    };
    systemd.timers.prune-inactive = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 05:30:00"; # 11:00 IST
        Persistent = true;
      };
    };
  };
}
