# git sync — path-aware pull + nixos-rebuild (mothership and/or edge)
#
# mothership: rebuilds metal; on edge-relevant diffs SSHs to edge to start edge-git-sync
# edge: own timer + oneshot (bastion keys, publish, landing)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.gitSync;
  role = cfg.role;
  unit = if role == "edge" then "edge-git-sync" else "mothership-git-sync";
  binName = unit;

  syncBin = pkgs.writeShellScriptBin binName ''
    export PATH="${
      lib.makeBinPath (
        [
          pkgs.bash
          pkgs.coreutils
          pkgs.curl
          pkgs.git
          pkgs.jq
          pkgs.util-linux
          pkgs.gawk
          pkgs.gnugrep
          pkgs.nix
          pkgs.nixos-rebuild
          pkgs.systemd
        ]
        ++ lib.optionals (role == "mothership" && cfg.triggerEdge.enable) [ pkgs.openssh ]
      )
    }:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
    export SYNC_ROLE="${role}"
    export SYNC_SRC="${cfg.srcDir}"
    export SYNC_REMOTE="${cfg.remote}"
    export SYNC_BRANCH="${cfg.branch}"
    export SYNC_FLAKE="${cfg.flakeHost}"
    export SYNC_STATE="${cfg.stateDir}"
    export SYNC_TRIGGER_EDGE="${if cfg.triggerEdge.enable then "1" else "0"}"
    export SYNC_NOTIFY="${../scripts/deploy-notify}"
    export SYNC_NOTIFY_TOKEN_FILE="${cfg.notify.tokenFile}"
    export SYNC_EDGE_HOST="${cfg.triggerEdge.host}"
    ${lib.optionalString (cfg.triggerEdge.identityFile != null) ''
      export SYNC_EDGE_IDENTITY="${cfg.triggerEdge.identityFile}"
    ''}
    # legacy env
    export MOTHERSHIP_SRC="$SYNC_SRC"
    export MOTHERSHIP_REMOTE="$SYNC_REMOTE"
    export MOTHERSHIP_BRANCH="$SYNC_BRANCH"
    export MOTHERSHIP_FLAKE="$SYNC_FLAKE"
    exec ${pkgs.bash}/bin/bash ${../scripts/host-git-sync} "$@"
  '';
in
{
  options.mothership.gitSync = {
    enable = lib.mkEnableOption "path-aware git pull + activate on a timer";

    role = lib.mkOption {
      type = lib.types.enum [
        "mothership"
        "edge"
      ];
      default = "mothership";
      description = "which host flake + path rules to use";
    };

    remote = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/tinkerhub0/mothership.git";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
    };

    srcDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mothership/src";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mothership/git-sync";
    };

    flakeHost = lib.mkOption {
      type = lib.types.str;
      default = "mothership";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "2min";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "30s";
    };

    # deploy results → github (commit status, PR comments, a "deploy broken"
    # issue). no token file = no notifications; deploys work either way.
    # install: scripts/install-github-token
    notify.tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.stateDir}/github-token";
      defaultText = lib.literalExpression ''"''${config.mothership.gitSync.stateDir}/github-token"'';
      description = "github token for scripts/deploy-notify (root 0600, not in git)";
    };

    triggerEdge = {
      enable = lib.mkEnableOption "after mothership sync, SSH-start edge-git-sync when edge paths changed";

      host = lib.mkOption {
        type = lib.types.str;
        default = "root@10.99.0.1";
        description = "SSH target for edge (WG tunnel IP preferred)";
      };

      identityFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "optional private key path for mothership → edge";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.flakeHost != "";
        message = "mothership.gitSync.flakeHost must be set";
      }
      {
        assertion = !(cfg.triggerEdge.enable && role == "edge");
        message = "mothership.gitSync.triggerEdge only valid on mothership role";
      }
    ];

    environment.systemPackages = [
      syncBin
      pkgs.git
    ]
    ++ lib.optionals (role == "mothership" && cfg.triggerEdge.enable) [ pkgs.openssh ];

    systemd.tmpfiles.rules = [
      "d /var/lib/mothership 0755 root root -"
      "d ${cfg.stateDir} 0755 root root -"
    ];

    systemd.services.${unit} = {
      description = "${role} path-aware git sync + activate";
      after = [
        "network-online.target"
        "nix-daemon.service"
      ];
      wants = [ "network-online.target" ];
      # this unit runs the switch. if a switch restarts it, the run that
      # started the switch dies, never records success, and the next run
      # collides with the switch still in flight.
      restartIfChanged = false;
      stopIfChanged = false;
      path = with pkgs; [
        bash
        coreutils
        curl
        git
        jq
        util-linux
        gawk
        gnugrep
        nix
        nixos-rebuild
        systemd
      ]
      ++ lib.optionals (role == "mothership" && cfg.triggerEdge.enable) [ pkgs.openssh ];
      environment = {
        NIX_CONFIG = "experimental-features = nix-command flakes";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncBin}/bin/${binName}";
        TimeoutStartSec = "2h";
        Nice = 10;
      };
    };

    systemd.timers.${unit} = {
      description = "${role} git sync timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.interval;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = false;
        Unit = "${unit}.service";
      };
    };

    environment.etc."mothership/git-sync.txt".text = ''
      git sync: on  role=${role}
      remote:   ${cfg.remote}
      branch:   ${cfg.branch}
      src:      ${cfg.srcDir}
      flake:    .#${cfg.flakeHost}
      interval: ${cfg.interval}
      unit:     ${unit}.timer
      ${lib.optionalString (role == "mothership") ''
        triggerEdge: ${if cfg.triggerEdge.enable then "yes → ${cfg.triggerEdge.host}" else "no"}
      ''}

      mothership: user-vms + hosts/mothership + modules → rebuild
      edge:       user-vms + bastion/publish/landing/front-door/sites → rebuild
      mothership may SSH-start edge-git-sync when edge paths change

      notify:   ${cfg.notify.tokenFile} (github token; missing = quiet)
      journal: journalctl -u ${unit} -f
      manual:  ${binName}
    '';
  };
}
