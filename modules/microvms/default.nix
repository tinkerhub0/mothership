# microvms — user-vms/<name>.nix → isolated guests (microvm.nix + cloud-hypervisor).
# scripts/signup only writes the file. git merge + rebuild provisions.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.microvms;
  mesh = config.mothership.mesh;

  memberDir = ../../user-vms;
  dirEntries = if builtins.pathExists memberDir then builtins.readDir memberDir else { };

  memberFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "template.nix"
  ) dirEntries;

  rawMembers = lib.mapAttrs' (
    file: _:
    let
      name = lib.removeSuffix ".nix" file;
    in
    {
      inherit name;
      value = import (memberDir + "/${file}");
    }
  ) memberFiles;

  members = lib.mapAttrs (
    name: member:
    import ../../lib/mkMemberVM.nix {
      inherit lib;
      memberName = name;
      inherit member;
      mesh = {
        mothershipIPv4 = mesh.mothershipIPv4 or "100.64.0.1";
        baseDomain = mesh.baseDomain or "mothership";
        # public front door — guests NAT out br-members and join like any peer
        serverUrl = mesh.serverUrl or "http://178.105.120.5:8080";
        bridgeAddress = cfg.bridgeAddress;
      };
    }
  ) rawMembers;

  enabledMembers = lib.filterAttrs (_: m: m.enabled) members;

  totalMem = lib.foldl' (a: m: a + m.tier.mem) 0 (lib.attrValues enabledMembers);

  memberAssertions = lib.flatten (lib.mapAttrsToList (_: m: m.assertions or [ ]) members);

  policy = import ../../lib/memberPolicy.nix { inherit lib; };
  reservedHits = lib.filter (n: policy.isReserved n) (lib.attrNames members);
  githubDupMsgs = policy.duplicateGithubs members;
in
{
  imports = [
    ./isolation.nix
    ./activity.nix
  ];

  options.mothership.microvms = {
    enable = lib.mkEnableOption "per-member microVMs from user-vms/";

    # read by isolation.nix; not for hosts to set
    enabledMembers = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = enabledMembers;
    };

    maxTotalMemMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100 * 1024;
      description = "sum of guest RAM (MiB) hard cap";
    };

    bridgeAddress = lib.mkOption {
      type = lib.types.str;
      # NOT 10.42.0.0/16 — that is br-deck (club services)
      default = "10.43.0.1";
      description = "host IP on br-members; guests DHCP off this";
    };

    bridgePrefix = lib.mkOption {
      type = lib.types.int;
      default = 16;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = memberAssertions ++ [
      {
        assertion = totalMem <= cfg.maxTotalMemMiB;
        message = "mothership.microvms: total guest mem ${toString totalMem} MiB > max ${toString cfg.maxTotalMemMiB} MiB";
      }
      {
        assertion = lib.all (name: policy.validName name) (lib.attrNames members);
        message = "mothership.microvms: names must match ${policy.nameRegex} (one file = one seat)";
      }
      {
        # filesystem already unique; this rejects reserved house/system names
        assertion = reservedHits == [ ];
        message = "mothership.microvms: name(s) reserved, pick another: ${lib.concatStringsSep ", " reservedHits}";
      }
      {
        # two members cannot claim the same github handle
        assertion = policy.githubsUnique members;
        message = "mothership.microvms: duplicate github handle(s), reject: ${lib.concatStringsSep "; " githubDupMsgs}";
      }
    ];

    # --- host fabric for guests (cloud-hypervisor = tap only) ---
    systemd.network.enable = true;
    systemd.network.netdevs."10-br-members" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br-members";
      };
    };
    systemd.network.networks."10-br-members" = {
      matchConfig.Name = "br-members";
      address = [ "${cfg.bridgeAddress}/${toString cfg.bridgePrefix}" ];
      networkConfig = {
        DHCPServer = "yes";
        IPMasquerade = "ipv4";
        ConfigureWithoutCarrier = true;
      };
      dhcpServerConfig = {
        PoolOffset = 10;
        PoolSize = 200;
        EmitDNS = true;
        DNS = [ cfg.bridgeAddress ];
      };
      # one fixed address per member (lib/mkMemberVM.nix ip)
      dhcpServerStaticLeases = lib.mapAttrsToList (_: m: {
        MACAddress = m.mac;
        Address = m.ip;
      }) enabledMembers;
    };

    networking.firewall.trustedInterfaces = [
      "br-members"
      "tailscale0"
    ];
    networking.firewall.interfaces.br-members.allowedTCPPorts = [
      22
      8080 # optional local headscale; guests primarily use public serverUrl via NAT
    ];
    networking.nat = {
      enable = true;
      enableIPv6 = false;
      internalInterfaces = [ "br-members" ];
      externalInterface = lib.mkDefault "eno1";
    };
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # ZFS dataset per member (mkdir fallback without tank)
    system.activationScripts.mothership-user-datasets = lib.stringAfter [ "users" ] ''
      mkdir -p /var/lib/mothership/users /var/lib/mothership/mesh
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: m:
          let
            ds = "tank/users/${name}";
            mnt = "/var/lib/mothership/users/${name}";
          in
          ''
            if command -v zfs >/dev/null 2>&1 && zfs list -H -o name tank >/dev/null 2>&1; then
              if ! zfs list -H -o name ${ds} >/dev/null 2>&1; then
                zfs create -o mountpoint=${mnt} -o refquota=${m.tier.refquota} ${ds} || true
              else
                zfs set refquota=${m.tier.refquota} ${ds} || true
                zfs set mountpoint=${mnt} ${ds} || true
              fi
            else
              mkdir -p ${mnt}
            fi
            chmod 755 ${mnt} || true
          ''
        ) enabledMembers
      )}
    '';

    # preauth + tap enslavement
    systemd.services = {
      mothership-mesh-preauth = {
        description = "provision member mesh preauth keys for microVMs";
        after = [ "headscale.service" ];
        requires = [ "headscale.service" ];
        wantedBy = [ "multi-user.target" ];
        before = map (n: "microvm@${n}.service") (lib.attrNames enabledMembers);
        path = [
          config.services.headscale.package
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.su
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail
          mkdir -p /var/lib/mothership/mesh
          KEYFILE=/var/lib/mothership/mesh/member.preauth
          hs() { su -s ${pkgs.runtimeShell} headscale -c "headscale $*"; }
          if [ ! -s "$KEYFILE" ]; then
            if ! hs users list 2>/dev/null | grep -q tinkerhub; then
              hs users create tinkerhub || true
            fi
            key=$(hs preauthkeys create --user tinkerhub --reusable --expiration 8760h 2>/dev/null \
              || hs preauthkeys create -u 1 --reusable --expiration 8760h)
            # strip any non-key noise; key is one token
            key=$(printf '%s\n' "$key" | tr -d '\r' | tail -n1)
            printf '%s\n' "$key" > "$KEYFILE"
            chmod 600 "$KEYFILE"
            echo "created member preauth"
          fi
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: _: ''
              mkdir -p /var/lib/mothership/users/${name}
              cp -f "$KEYFILE" /var/lib/mothership/users/${name}/tailscale.authkey
              chmod 644 /var/lib/mothership/users/${name}/tailscale.authkey
            '') enabledMembers
          )}
        '';
      };
    }
    // lib.mapAttrs' (
      name: m:
      lib.nameValuePair "microvm-br-${name}" {
        description = "enslave ${m.tapId} → br-members";
        after = [
          "systemd-networkd.service"
          "microvm-tap-interfaces@${name}.service"
        ];
        requires = [ "microvm-tap-interfaces@${name}.service" ];
        before = [ "microvm@${name}.service" ];
        wantedBy = [ "microvm@${name}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.iproute2}/bin/ip link set dev ${m.tapId} master br-members";
        };
      }
    ) enabledMembers;

    microvm.vms = lib.mapAttrs (_name: m: {
      config = m.guest;
      autostart = true;
    }) enabledMembers;

    environment.etc."mothership/members.txt".text =
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: m:
          "${name}\ttier=${m.tierName}\tmem=${toString m.tier.mem}M\tvcpu=${toString m.tier.vcpu}\tquota=${m.tier.refquota}\ttap=${m.tapId}\tmac=${m.mac}\tip=${m.ip}\tenabled=${
            if m.enabled then "yes" else "no"
          }${lib.optionalString (m.github != null) "\tgithub=${m.github}"}"
        ) members
      )
      + "\n# mesh: ssh ${lib.concatMapStringsSep " | " (n: "${n}@${n}") (lib.attrNames enabledMembers)}\n"
      + "# local DHCP: ${cfg.bridgeAddress}/${toString cfg.bridgePrefix} via br-members\n";
  };
}
