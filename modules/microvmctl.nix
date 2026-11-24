# microvmctl — a live view of the member VMs, for operators on the host.
# opt-in so it can be removed without touching the rest of the host fabric.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.microvmctl;
in
{
  options.mothership.microvmctl = {
    enable = lib.mkEnableOption "microvmctl, a live inspector for member VMs";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.microvmctl ];

    environment.etc."mothership/microvmctl.txt".text = ''
      microvmctl — inspect member VMs on this host

      microvmctl          live, interactive view (like top for VMs)
      microvmctl list     name, state, uptime, memory, guest address
      microvmctl top      live CPU and memory use
      microvmctl status NAME   system generation and pending updates

      Read-only commands work as your normal user. Details that talk to
      cloud-hypervisor (disk/network rates, pause, resume, console and
      ssh over vsock) need sudo. See docs/vm-inspection.md.
    '';
  };
}
