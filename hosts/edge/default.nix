# hosts/edge — public front door only (VPS @ 178.105.120.5).
# WireGuard reverse tunnel + nginx → mothership Headscale.
# install: nixos-anywhere --flake .#edge
# day-2:  nixos-rebuild switch --flake .#edge  (or deploy from laptop)
{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/base.nix
    ../../modules/admins.nix
    ../../modules/tools.nix
    ../../modules/acme.nix # Let's Encrypt for public nginx
    ../../modules/mesh # WG front door + optional mesh client
    ../../modules/bastion.nix # public ssh you@you.domain → VM
    ../../modules/member-publish.nix # public http(s) you.domain → VM:port
    ../../modules/landing.nix # tharavad.xyz Astro landing
    ../../modules/git-sync.nix # main → edge (bastion keys, publish, landing)
    ../../modules/landa-proxy.nix # landa.tharavad.xyz → control plane API
    ../../modules/status-proxy.nix # status.tharavad.xyz → deck monitor
  ];

  networking.hostName = "edge";
  networking.hostId = "e5a1c0de";

  networking.usePredictableInterfaceNames = false; # keep eth0 like rescue
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.defaultGateway = lib.mkDefault {
    address = "172.31.1.1";
    interface = "eth0";
  };
  networking.nameservers = lib.mkDefault [
    "185.12.64.1"
    "185.12.64.2"
  ];

  systemd.network.enable = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  mothership.edge.diskDevice = "/dev/sda";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = lib.mkForce false;

  # mesh client only — Headscale is on mothership
  mothership.mesh = {
    enable = true;
    controlPlane = false;
    baseDomain = "mothership";
    mothershipIPv4 = "100.64.0.1";
    serverUrl = "http://178.105.120.5:8080";

    frontDoor = {
      enable = true;
      role = "edge";
      edgePublicKey = "3ZDVjxugaiQTZEuuSVrDxYlfPxywzv/wUYAh9tdit3M=";
      homePublicKey = "MOYEB3uBcV3c/mBBGfyMTAwIFQ9OxpbruwdljG/o8Wo=";
      edgeEndpoint = "178.105.120.5:51820";
    };
  };

  # public member SSH: ssh alvin@alvin.tharavad.xyz  (DNS * → edge)
  mothership.bastion = {
    enable = true;
    publicDomain = "tharavad.xyz";
    jumpHost = "10.99.0.2"; # mothership over WG
  };

  # public member HTTP: http://alvin.tharavad.xyz → VM publish ports
  mothership.memberPublish = {
    enable = true;
    role = "edge";
    publicDomain = "tharavad.xyz";
    mothershipTunnelIP = "10.99.0.2";
  };

  # apex landing
  mothership.landing = {
    enable = true;
    domain = "tharavad.xyz";
  };

  # Let's Encrypt (ACME) for landing + member publish + landa
  mothership.acme = {
    enable = true;
    email = "ops@tharavad.xyz";
  };

  # main → edge: own timer + oneshot (mothership may also trigger this)
  mothership.gitSync = {
    enable = true;
    role = "edge";
    flakeHost = "edge";
    remote = "https://github.com/tinkerhub0/mothership.git";
    branch = "main";
    interval = "2min";
    srcDir = "/var/lib/mothership/src";
    stateDir = "/var/lib/mothership/git-sync-edge";
  };

  # landa UI only — API lives on alvin (member publish landa-back → :8787)
  mothership.landaProxy = {
    enable = true;
    domain = "landa.tharavad.xyz";
    webRoot = "/var/lib/landa/web/dist";
    # no local API process; landa-back is memberPublish → alvin:8787
    manageService = false;
    apiDomain = null; # disable edge API vhost (publish owns landa-back)
  };

  # public status.tharavad.xyz → deck Uptime Kuma (mothership :9081 over WG)
  mothership.statusProxy = {
    enable = true;
    domain = "status.tharavad.xyz";
  };

  networking.firewall.allowedTCPPorts = [
    22
    80 # ACME + redirect
    443 # HTTPS (landing, publish, landa)
    8080 # nginx → Headscale via WG (ops)
  ];
  networking.firewall.allowedUDPPorts = [
    51820 # WireGuard front door
    41641 # tailscale
  ];

  environment.systemPackages = with pkgs; [
    git
    curl
    jq
  ];

  system.stateVersion = "26.05";
}
