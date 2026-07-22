# Single disk: ESP + ZFS root (pool tank).
#
# Device resolution order:
#   1. mothership.diskDevice  (explicit pin in default.nix)
#   2. first whole disk in ./facter.json  (autodetect)
#   3. PENDING placeholder — system build asserts until 1 or 2 exists
#
# facter.json is produced ON THE SERVER (not your laptop):
#   ./scripts/capture-hardware.sh
#   # or: sudo nix run github:nix-community/nixos-facter -- -o hosts/mothership/facter.json
{
  config,
  lib,
  ...
}:
let
  facterFile = ./facter.json;

  isWholeDisk =
    name:
    (builtins.match "/dev/nvme[0-9]+n[0-9]+" name != null)
    || (builtins.match "/dev/sd[a-z]+" name != null)
    || (builtins.match "/dev/vd[a-z]+" name != null)
    || (builtins.match "/dev/disk/by-id/.+" name != null);

  fromFacter =
    if !builtins.pathExists facterFile then
      null
    else
      let
        report = builtins.fromJSON (builtins.readFile facterFile);
        disks = report.hardware.disk or [ ];
        candidates = builtins.filter (
          d: isWholeDisk (d.unix_device_name or "")
        ) disks;
      in
      if candidates == [ ] then
        null
      else
        (builtins.head candidates).unix_device_name;

  pending = "/dev/disk/by-id/PENDING-run-scripts-capture-hardware";

  resolved =
    if config.mothership.diskDevice != null then
      config.mothership.diskDevice
    else if fromFacter != null then
      fromFacter
    else
      pending;
in
{
  options.mothership.diskDevice = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/dev/disk/by-id/nvme-Samsung_...";
    description = ''
      Install target disk. null = autodetect from facter.json (first whole disk).
      Prefer /dev/disk/by-id/... when setting explicitly.
    '';
  };

  config = {
    assertions = [
      {
        assertion = resolved != pending;
        message = ''
          mothership: no disk device resolved.

          On the server (once):
            ./scripts/capture-hardware.sh
          then commit hosts/mothership/facter.json

          Or pin explicitly in hosts/mothership/default.nix:
            mothership.diskDevice = "/dev/disk/by-id/nvme-...";
        '';
      }
    ];

    disko.devices = {
      disk.main = {
        type = "disk";
        device = resolved;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      };

      zpool.tank = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          acltype = "posixacl";
          atime = "off";
          compression = "zstd";
          xattr = "sa";
          mountpoint = "none";
          "com.sun:auto-snapshot" = "false";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options.mountpoint = "legacy";
          };
          # Parent only. Per-member tank/users/<name> + refquota comes from mkMemberVM later.
          users = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
        };
      };
    };
  };
}
