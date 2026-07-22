# microvms — members defined in user-vms/<name>.nix become isolated guests.
# git is the control plane. scripts/signup only writes a file for a PR.
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
      };
    }
  ) rawMembers;

  enabledMembers = lib.filterAttrs (_: m: m.enabled) members;

  totalMem = lib.foldl' (a: m: a + m.tier.mem) 0 (lib.attrValues enabledMembers);

  memberAssertions = lib.flatten (
    lib.mapAttrsToList (_: m: m.assertions or [ ]) members
  );
in
{
  options.mothership.microvms = {
    enable = lib.mkEnableOption "per-member microVMs from user-vms/";

    maxTotalMemMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100 * 1024;
      description = "sum of guest RAM (MiB) must stay under this";
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

    # ZFS dataset per member under tank/users (parent from disko)
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

    microvm.autostart = lib.attrNames enabledMembers;

    microvm.vms = lib.mapAttrs (_name: m: {
      config = m.guest;
    }) enabledMembers;

    environment.systemPackages = [ pkgs.microvm ];

    environment.etc."mothership/members.txt".text =
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: m:
          "${name}\ttier=${m.tierName}\tmem=${toString m.tier.mem}M\tvcpu=${toString m.tier.vcpu}\tquota=${m.tier.refquota}\tenabled=${
            if m.enabled then "yes" else "no"
          }${lib.optionalString (m.github != null) "\tgithub=${m.github}"}"
        ) members
      )
      + "\n# unique IP: inside guest → tailscale ip -4 (headscale / 100.64.0.0/10)\n";
  };
}
