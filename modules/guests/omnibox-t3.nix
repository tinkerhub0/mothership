# Attached only to Omnibox by hosts/mothership/default.nix. Authentication stays in /persist/home.
{ config, pkgs, ... }:
let
  t3 = pkgs.callPackage ../../pkgs/t3code.nix { };
  tailscale = pkgs.callPackage ../../pkgs/omnibox-tailscale.nix { };
  home = "/home/omnibox";
  state = "${home}/.local/share/omnibox-tailscale";
  socket = "${state}/tailscaled.sock";
  personalTailscale = pkgs.writeShellScriptBin "tailscale-omnibox" ''
    exec ${tailscale}/bin/tailscale --socket=${socket} "$@"
  '';
  migrate = pkgs.writeShellScript "migrate-omnibox-t3-units" ''
    set -eu
    home="''${1:?persistent home required}"
    umask 077
    backup="$home/.local/state/omnibox-t3/legacy-units"
    for unit in t3code omnibox-tailscale; do
      source="$home/.config/systemd/user/$unit.service"
      if [ -e "$source" ] || [ -L "$source" ]; then
        mkdir -p "$backup"
        mv --backup=numbered "$source" "$backup/$unit.service"
      fi
      rm -f "$home/.config/systemd/user/default.target.wants/$unit.service"
    done
    override="$home/.config/systemd/user/t3code.service.d/cli-path.conf"
    if [ -e "$override" ] || [ -L "$override" ]; then
      mkdir -p "$backup"
      mv --backup=numbered "$override" "$backup/cli-path.conf"
    fi
    # Keep the familiar command, while the executable and its libraries live in Nix.
    mkdir -p "$home/.local/bin"
    ln -sfn ${t3}/bin/t3 "$home/.local/bin/t3"
  '';
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "omnibox";
      message = "omnibox-t3 is only for the Omnibox VM";
    }
  ];
  users.users.omnibox.uid = 1000;
  environment.systemPackages = [
    t3
    personalTailscale
  ];

  systemd.tmpfiles.rules = [
    "d /persist/home/.local 0755 omnibox users -"
    "d /persist/home/.local/bin 0755 omnibox users -"
    "d /persist/home/.local/state 0755 omnibox users -"
    "d /persist/home/.local/state/omnibox-t3 0700 omnibox users -"
    "d /persist/home/.local/state/omnibox-t3/legacy-units 0700 omnibox users -"
    "d /persist/home/.t3 0700 omnibox users -"
    "d /persist/home/.t3/userdata 0700 omnibox users -"
    "d /persist/home/.t3/userdata/logs 0700 omnibox users -"
  ];

  # Home unit files override /etc/systemd/user; retire them before lingering starts.
  # This runs after the persistent share mounts, including on a fresh VM boot.
  systemd.services.omnibox-t3-prepare = {
    description = "Adopt legacy Omnibox T3 services into Nix";
    requires = [
      "persist.mount"
      "systemd-tmpfiles-setup.service"
    ];
    after = [
      "persist.mount"
      "systemd-tmpfiles-setup.service"
    ];
    before = [ "user@1000.service" ];
    requiredBy = [ "user@1000.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${migrate} /persist/home";
    };
  };

  systemd.user.services.t3code = {
    description = "T3 Code server";
    wantedBy = [ "default.target" ];
    unitConfig = {
      ConditionUser = "omnibox";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "simple";
      WorkingDirectory = home;
      Environment = [
        "T3CODE_HOME=${home}/.t3"
        "T3_BOOT_SERVICE_UNIT=t3code.service"
        "T3CODE_HOST=127.0.0.1"
        "T3CODE_PORT=3773"
        "PATH=${home}/.grok/bin:${home}/.local/bin:/run/wrappers/bin:${home}/.nix-profile/bin:/nix/profile/bin:${home}/.local/state/nix/profile/bin:/etc/profiles/per-user/omnibox/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      ];
      # The installer launcher selects downloaded home-directory runtimes.
      # Run the Nix package directly, retaining the existing local settings file.
      EnvironmentFile = "-${home}/.t3/service.env";
      ExecStart = "${t3}/bin/t3 serve";
      KillMode = "mixed";
      OOMPolicy = "continue";
      Restart = "always";
      RestartSec = 5;
      CPUWeight = 1000;
      IOWeight = 1000;
      ManagedOOMPreference = "avoid";
      StandardOutput = "append:${home}/.t3/userdata/logs/boot-service.log";
      StandardError = "append:${home}/.t3/userdata/logs/boot-service.log";
    };
  };

  # Independent from the guest's infrastructure Headscale daemon.
  systemd.user.services.omnibox-tailscale = {
    description = "Omnibox personal Tailscale connection";
    after = [ "network-online.target" ];
    unitConfig.ConditionUser = "omnibox";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${tailscale}/bin/tailscaled --tun=userspace-networking --statedir=${state} --state=${state}/tailscaled.state --socket=${socket} --port=0";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
