# Single disk: ESP + ZFS root (pool tank).
# Replace device with the real by-id path from the server before format:
#   ls -l /dev/disk/by-id/
{
  disko.devices = {
    disk.main = {
      type = "disk";
      # TODO: pin by-id (stable across reboots). Never leave as /dev/sdX long-term.
      device = "/dev/disk/by-id/CHANGE-ME";
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
}
