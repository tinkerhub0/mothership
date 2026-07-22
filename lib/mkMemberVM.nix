# one member file → guest nixos config for microvm.vms.<name>.config
#
# unique IP strategy:
#   guest runs tailscaled → headscale assigns 100.64.x.x + MagicDNS
#   <name>.mesh.tinkerhub. that is the address members use for "do whatever".
#   host-local path is slirp (type=user) for outbound/bootstrap only.
{
  lib,
  memberName,
  member,
  mesh,
}:
let
  tiers = import ./tiers.nix;
  tierName = member.tier or "small";
  tier =
    tiers.${tierName}
      or (throw "user-vms/${memberName}: unknown tier '${tierName}' (small|medium|large)");

  keys =
    member.keys or (throw "user-vms/${memberName}: set keys = [ \"ssh-ed25519 …\" ];");

  enabled = member.enabled or true;
  github = member.github or null;

  emptyKeys = keys == [ ] || keys == null;
in
{
  inherit
    enabled
    tierName
    tier
    keys
    github
    ;

  assertions = [
    {
      assertion = !enabled || !emptyKeys;
      message = "user-vms/${memberName}: enabled member needs non-empty keys";
    }
  ];

  guest =
    {
      pkgs,
      ...
    }:
    {
      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = tier.vcpu;
        mem = tier.mem;

        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
          {
            proto = "virtiofs";
            tag = "persist";
            source = "/var/lib/mothership/users/${memberName}";
            mountPoint = "/persist";
          }
        ];

        # slirp outbound for bootstrap; real identity/IP is mesh (below)
        interfaces = [
          {
            type = "user";
            id = "vm-${memberName}";
          }
        ];
      };

      networking.hostName = memberName;
      networking.firewall.allowedTCPPorts = [ 22 ];

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };
      };

      users.users.${memberName} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = keys;
      };
      users.users.root.openssh.authorizedKeys.keys = keys;
      security.sudo.wheelNeedsPassword = false;

      # --- unique IP ---
      # headscale hands out CGNAT when this node joins.
      # after join: tailscale ip -4 · ssh you@you · ssh you@you.mesh.tinkerhub
      services.tailscale = {
        enable = true;
        openFirewall = true;
        extraUpFlags = [
          "--login-server=http://${mesh.mothershipIPv4}:8080"
          "--hostname=${memberName}"
          "--accept-dns=true"
        ];
        # authKeyFile via sops later — first join can be operator-assisted
      };

      environment.systemPackages = with pkgs; [
        curl
        git
        htop
        vim
      ];

      systemd.tmpfiles.rules = [
        "d /persist/home 0755 ${memberName} users -"
        "L+ /home/${memberName} - - - - /persist/home"
      ];

      system.stateVersion = "25.05";
    };
}
