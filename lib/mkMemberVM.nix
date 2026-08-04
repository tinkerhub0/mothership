# one member file → guest module for microvm.vms.<name>.config
#
# internal: tailscale mesh IP + MagicDNS (ops / VM↔VM).
# public UX: ssh you@you.<domain> via edge bastion (no member mesh client).
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
      or (throw "user-vms/${memberName}: unknown tier '${tierName}' (small|medium|large|god)");

  memberKeys = member.keys or (throw "user-vms/${memberName}: set keys = [ \"ssh-ed25519 …\" ];");
  bastionPub = import ./bastionPubKey.nix;
  # member keys + edge bastion (so public ssh you@you.domain can land)
  keys = memberKeys ++ [ bastionPub ];

  enabled = member.enabled or true;
  github = member.github or null;
  emptyKeys = memberKeys == [ ] || memberKeys == null;

  # public HTTP: [ { subdomain ? memberName; port = 3000; } ]
  publish = member.publish or [ ];
  publishPorts = map (p: p.port) publish;

  serverUrl = mesh.serverUrl or "http://178.105.120.5:8080";

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
    publish
    publishPorts
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
        vsock.cid =
          let
            h = builtins.hashString "sha256" memberName;
            n = lib.fromHexString (builtins.substring 0 4 h);
          in
          3 + (lib.mod n 10000);

        # host /nix/store is virtiofs RO — without overlay, nix shell/install fails
        # (Read-only file system on /nix/store/*.lock)
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = "nix-store-overlay.img";
            mountPoint = "/nix/.rw-store";
            # MiB; members install tools here (nix shell / profile)
            size =
              if tierName == "god" then
                65536
              else if tierName == "large" then
                32768
              else if tierName == "medium" then
                16384
              else
                8192;
          }
        ];

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

      # members can: nix shell nixpkgs#neofetch / nix profile install …
      # microvm guests often mask nix-daemon → non-root hits big-lock Permission denied
      nix.enable = true;
      nix.channel.enable = true;
      systemd.services.nix-daemon.enable = lib.mkForce true;
      systemd.sockets.nix-daemon.enable = lib.mkForce true;
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "root"
          "@wheel"
          memberName
        ];
        allowed-users = [ "*" ];
      };
      # DHCP from host br-members
      systemd.network.networks."10-eth" = {
        matchConfig.MACAddress = mac;
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = false;
        };
        dhcpV4Config.RouteMetric = 100;
      };

      networking.firewall.allowedTCPPorts = [
        22
      ]
      ++ publishPorts;
      networking.firewall.allowedUDPPorts = [ 41641 ];

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };
      };

      # member account = hostname → ssh alvin@alvin
      users.users.${memberName} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = keys;
      };
      users.users.root.openssh.authorizedKeys.keys = keys;
      security.sudo.wheelNeedsPassword = false;

      # mesh join: preauth from host at /persist/tailscale.authkey
      # state on /persist so reboot keeps the same node (no alvin → alvin-1)
      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = "/persist/tailscale.authkey";
        extraUpFlags = [
          "--login-server=${serverUrl}"
          "--hostname=${memberName}"
          "--accept-dns=true"
        ];
      };

      systemd.tmpfiles.rules = [
        "d /persist/home 0755 ${memberName} users -"
        "d /persist/tailscale 0700 root root -"
        "L+ /home/${memberName} - - - - /persist/home"
        # multi-user nix (else: creating directory /nix/var/nix/temproots: Permission denied)
        "d /nix/var/nix/temproots 1777 root root -"
        "d /nix/var/nix/profiles/per-user/${memberName} 0755 ${memberName} users -"
        "d /nix/var/nix/gcroots/per-user/${memberName} 0755 ${memberName} users -"
      ];

      # bind-mount persistent tailscale state (must exist before tailscaled)
      fileSystems."/var/lib/tailscale" = {
        device = "/persist/tailscale";
        fsType = "none";
        options = [
          "bind"
          "X-mount.mkdir"
        ];
      };

      systemd.services.tailscaled = {
        after = [
          "persist.mount"
          "var-lib-tailscale.mount"
        ];
        requires = [ "var-lib-tailscale.mount" ];
      };

      systemd.services.tailscaled-autoconnect = {
        after = [
          "network-online.target"
          "persist.mount"
          "tailscaled.service"
        ];
        wants = [ "network-online.target" ];
        unitConfig.ConditionPathExists = "/persist/tailscale.authkey";
      };

      environment.systemPackages = with pkgs; [
        curl
        git
        htop
        vim
        python3 # python3 -m http.server for publish demos
      ];

      system.stateVersion = "25.05";
    };
}
