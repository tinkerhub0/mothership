# hosts/mothership — identity of this metal.
# capabilities live under ../../modules.
{
  lib,
  ...
}:
let
  # ═══════════════════════════════════════════════════════════
  # STORAGE MODE — read this before every switch
  #
  # false (default): use hardware-configuration.nix
  #   = installer layout (ext4/btrfs). SAFE for switch on a
  #     normal NixOS install. Replace hardware-configuration.nix
  #     with the copy from /etc/nixos/ on the box.
  #
  # true: use disko.nix (ESP + ZFS tank)
  #   = ONLY after a clean install that was formatted with disko.
  #   Switching this on over an installer root = boot.mount dies.
  #   That is what bricked us last time.
  # ═══════════════════════════════════════════════════════════
  useDisko = false;
in
{
  imports = [
    ../../modules/base.nix
    ../../modules/admins.nix
    ../../modules/tools.nix
    ../../modules/deck
    ../../modules/mesh
    ../../modules/microvms
    ../../modules/bastion.nix
    ../../modules/member-publish.nix
    ../../modules/git-sync.nix
  ]
  ++ (
    if useDisko then
      [ ./disko.nix ]
    else
      [ ./hardware-configuration.nix ]
  );

  # frozen at first ZFS pool create (only matters when useDisko = true).
  networking.hostId = "a7c3e91b";
  networking.hostName = "mothership";

  # keep NetworkManager — live install uses it for eno1 DHCP.
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # Headscale lives here; edge is WG reverse + nginx front door only.
  mothership.mesh = {
    enable = true;
    controlPlane = true;
    baseDomain = "mothership"; # MagicDNS: alvin.mothership
    mothershipIPv4 = "100.64.0.1";
    serverUrl = "http://178.105.120.5:8080";

    frontDoor = {
      enable = true;
      role = "home";
      edgePublicKey = "3ZDVjxugaiQTZEuuSVrDxYlfPxywzv/wUYAh9tdit3M=";
      homePublicKey = "MOYEB3uBcV3c/mBBGfyMTAwIFQ9OxpbruwdljG/o8Wo=";
      edgeEndpoint = "178.105.120.5:51820";
    };
  };

  # private bridge for loki/grafana/mattermost/vaultwarden
  mothership.deck.network.enable = true;

  # fleet monitoring on the host (native service, not a microVM)
  # public: https://status.tharavad.xyz via edge status-proxy
  mothership.deck.uptimeKuma.enable = true;

  # member VMs: user-vms/*.nix
  # public: ssh you@you.<domain> via edge bastion; mesh is internal only
  mothership.microvms.enable = true;
  # rollout: count spoof hits only until every guest renewed onto its static
  # lease (leases ≤1h), then delete this line. smtp block + conn cap are live.
  mothership.microvms.isolation.enforce = false;

  # inactive = 10 days with no ssh login and no real work inside the VM.
  # warn at 7, park PR at 10, delete PR 30 days after parking.
  # prune.enable = false → dry-run: journalctl -u prune-inactive shows the plan.
  mothership.microvms.activity = {
    sshHost = "root@10.99.0.1"; # bastion lives on the edge for now
    sshIdentity = "/var/lib/mothership/git-sync/edge_trigger_ed25519";
    prune = {
      enable = false;
      warnDays = 7;
      parkDays = 10;
      deleteDays = 30;
      exempt = [
        "demo"
        "omnibox"
      ];
    };
  };
  mothership.bastion.trustBastionKey = true;
  mothership.memberPublish = {
    enable = true;
    role = "home";
    publicDomain = "tharavad.xyz";
    mothershipTunnelIP = "10.99.0.2";
  };

  # main → metal: path-aware pull + switch (timer ≈ cron)
  # edge-relevant paths (user-vms keys, bastion, landing) also SSH-start edge-git-sync
  mothership.gitSync = {
    enable = true;
    role = "mothership";
    flakeHost = "mothership";
    remote = "https://github.com/tinkerhub0/mothership.git";
    branch = "main";
    interval = "2min";
    triggerEdge = {
      enable = true;
      # edge over WG front door; script also tries public IP
      host = "root@10.99.0.1";
      identityFile = "/var/lib/mothership/git-sync/edge_trigger_ed25519";
    };
  };

  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # match install (NixOS 26.05 Yarara)
  system.stateVersion = "26.05";
}
