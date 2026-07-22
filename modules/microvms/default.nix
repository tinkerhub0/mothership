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
        baseDomain = mesh.baseDomain or "mesh.tinkerhub";
        bridgeAddress = cfg.bridgeAddress;
      };
    }
  ) rawMembers;

  enabledMembers = lib.filterAttrs (_: m: m.enabled) members;

  totalMem = lib.foldl' (a: m: a + m.tier.mem) 0 (lib.attrValues enabledMembers);

  memberAssertions = lib.flatten (lib.mapAttrsToList (_: m: m.assertions or [ ]) members);
in
{
  options.mothership.microvms = {
    enable = lib.mkEnableOption "per-member microVMs from user-vms/";

    maxTotalMemMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100 * 1024;
      description = "sum of guest RAM (MiB) hard cap";
    };

    bridgeAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.1";
      description = "host IP on br-members; guests DHCP off this; headscale open here too";
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
        assertion = lib.all (
          name: builtins.match "^[a-z][a-z0-9-]{1,15}$" name != null
        ) (lib.attrNames members);
        message = "mothership.microvms: names must match ^[a-z][a-z0-9-]{1,15}$";
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
    };

    # enslave each guest tap into the bridge after microvm creates it
    systemd.services = lib.mapAttrs' (
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

    networking.firewall.trustedInterfaces = [
      "br-members"
      "tailscale0"
    ];
    # guests reach headscale on the bridge IP before they have mesh
    networking.firewall.interfaces.br-members.allowedTCPPorts = [
      8080
      22
    ];
    networking.nat = {
      enable = true;
      enableIPv6 = false;
      internalInterfaces = [ "br-members" ];
      # externalInterface left unset → NAT still works via default route on many setups;
      # pin on metal if needed: networking.nat.externalInterface = "eno1";
    };
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # also advertise headscale on bridge IP for guest bootstrap
    # (host mesh module already binds 0.0.0.0:8080)

    # ZFS dataset per member
    system.activationScripts.mothership-user-datasets = lib.stringAfter [ "users" ] ''
      mkdir -p /var/lib/mothership/users
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: m:
          let
            ds = "tank/users/${name}";
            mnt = "/var/lib/mothership/users/${name}";
          in
          ''
            if command -v zfs >/dev/null 2>&1; then
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

    # host module already puts each vms.*.autostart=true into microvm.autostart
    microvm.vms = lib.mapAttrs (_name: m: {
      config = m.guest;
      autostart = true;
    }) enabledMembers;

    # microvm CLI comes from microvm.nixosModules.host — do not pkgs.microvm

    environment.etc."mothership/members.txt".text =
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: m:
          "${name}\ttier=${m.tierName}\tmem=${toString m.tier.mem}M\tvcpu=${toString m.tier.vcpu}\tquota=${m.tier.refquota}\ttap=${m.tapId}\tmac=${m.mac}\tenabled=${
            if m.enabled then "yes" else "no"
          }${lib.optionalString (m.github != null) "\tgithub=${m.github}"}"
        ) members
      )
      + "\n# mesh IP: inside guest → tailscale ip -4\n# local: 10.42.0.0/${toString cfg.bridgePrefix} via br-members\n";
  };
}
