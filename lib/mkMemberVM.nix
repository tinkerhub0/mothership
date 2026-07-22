# one member file → guest module for microvm.vms.<name>.config
#
# unique IP: tailscaled in guest → headscale CGNAT + MagicDNS.
# local path: tap on br-members (cloud-hypervisor has no slirp/user net).
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

  keys = member.keys or (throw "user-vms/${memberName}: set keys = [ \"ssh-ed25519 …\" ];");

  enabled = member.enabled or true;
  github = member.github or null;
  emptyKeys = keys == [ ] || keys == null;

  # IFNAMSIZ=15; keep tap names short + stable
  tapId =
    let
      h = builtins.hashString "sha256" memberName;
    in
    "m${builtins.substring 0 14 h}";

  mac =
    let
      h = builtins.hashString "sha256" memberName;
      b = i: builtins.substring i 2 h;
    in
    "02:${b 0}:${b 2}:${b 4}:${b 6}:${b 8}";
in
{
  inherit
    enabled
    tierName
    tier
    keys
    github
    tapId
    mac
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
      lib,
      ...
    }:
    {
      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = tier.vcpu;
        mem = tier.mem;
        # readiness notify over vsock (cloud-hypervisor)
        vsock.cid =
          let
            # stable 3..10002 from name hash
            h = builtins.hashString "sha256" memberName;
            n = lib.fromHexString (builtins.substring 0 4 h);
          in
          3 + (lib.mod n 10000);

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

        interfaces = [
          {
            type = "tap";
            id = tapId;
            inherit mac;
          }
        ];
      };

      networking.hostName = memberName;
      networking.useNetworkd = true;
      systemd.network.enable = true;

      # DHCP from host br-members (10.42.0.1)
      systemd.network.networks."10-eth" = {
        matchConfig.MACAddress = mac;
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = false;
        };
        dhcpV4Config.RouteMetric = 100;
      };

      networking.firewall.allowedTCPPorts = [ 22 ];
      networking.firewall.allowedUDPPorts = [ 41641 ]; # tailscale

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

      # unique IP lives on the mesh after join
      services.tailscale = {
        enable = true;
        openFirewall = true;
        extraUpFlags = [
          # must match services.headscale.settings.server_url
          # guest reaches it via default gw (br-members) → host local 100.64.0.1
          # (mothership must already own .1 on the mesh)
          "--login-server=http://${mesh.mothershipIPv4}:8080"
          "--hostname=${memberName}"
          "--accept-dns=true"
        ];
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
