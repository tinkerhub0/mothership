{
  config,
  lib,
  pkgs,
  ...
}:

let
  nixStateImport = "${config.microvm.writableStoreOverlay}/nix-state-import";
in
{
  microvm.volumes = lib.mkAfter [
    {
      image = "nix-state.img";
      label = "nix-state";
      mountPoint = "/nix/var/nix";
      size = 1024;
    }
  ];

  # Mount before MicroVM registers the system closure during boot.
  fileSystems."/nix/var/nix".neededForBoot = true;
  systemd.tmpfiles.rules = [ "z /nix/var/nix 0755 root root -" ];
  boot.postBootCommands = lib.mkAfter ''
    if [ -f ${nixStateImport}/registration ]; then
      if ${config.nix.package}/bin/nix-store --load-db < ${nixStateImport}/registration &&
        ${pkgs.findutils}/bin/find ${nixStateImport}/links -mindepth 1 -maxdepth 1 \
          -exec ${pkgs.coreutils}/bin/cp -a --update=none -t /nix/var/nix -- {} +; then
        ${pkgs.coreutils}/bin/mv ${nixStateImport}/registration ${nixStateImport}/registration.imported
      else
        echo "Could not import saved Nix state from ${nixStateImport}" >&2
      fi
    fi
  '';
}
