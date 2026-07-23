# headscale — coordination server.
# canonical login = static mesh IP (no MagicDNS chicken-egg).
# serve (tailscale.nix) fronts HTTPS at mothership.<baseDomain> once you're on-mesh.
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.mesh;
  hs = config.services.headscale;
in
{
  options.mothership.mesh = {
    enable = lib.mkEnableOption "Headscale + Tailscale mesh on the mothership";

    baseDomain = lib.mkOption {
      type = lib.types.str;
      default = "mesh.tinkerhub";
      description = "MagicDNS base domain. Nodes become <hostname>.<baseDomain>.";
    };

    # Reserved for this host. Sequential allocation + register mothership first.
    mothershipIPv4 = lib.mkOption {
      type = lib.types.str;
      default = "100.64.0.1";
      description = "Static Tailscale/Headscale IPv4 for the mothership node.";
    };

    prefixV4 = lib.mkOption {
      type = lib.types.str;
      default = "100.64.0.0/10";
      description = "CGNAT range Headscale hands out (must stay in Tailscale-supported space).";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Headscale HTTP listen port on the host.";
    };

    # MUST be reachable by every client (LAN + internet).
    # LAN-only 100.64.0.1 / 192.168.x dies off-site.
    # Example: "http://49.47.196.126:8080" or "https://hs.example.com"
    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${cfg.mothershipIPv4}:${toString cfg.listenPort}";
      description = ''
        Public control-plane URL written into Headscale config (server_url).
        Clients use the same string as --login-server.
        For off-LAN access: public IP or DNS + router port-forward to this host.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = true;
      address = "0.0.0.0";
      port = cfg.listenPort;

      settings = {
        server_url = cfg.serverUrl;

        prefixes = {
          v4 = cfg.prefixV4;
          v6 = "fd7a:115c:a1e0::/48";
          # First registered node → .1 — register mothership before anyone else.
          allocation = "sequential";
        };

        dns = {
          magic_dns = true;
          base_domain = cfg.baseDomain;
          override_local_dns = true;
          nameservers.global = [
            "1.1.1.1"
            "9.9.9.9"
          ];
          search_domains = [ cfg.baseDomain ];
          extra_records = [
            {
              name = "headscale.${cfg.baseDomain}";
              type = "A";
              value = cfg.mothershipIPv4;
            }
          ];
        };

        log.level = "info";

        # Wide open for phase-1 bring-up. Tighten when user-vms land.
        policy = {
          mode = "file";
          path = ./policy.hujson;
        };
      };
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      # LAN clients need 8080 to join before they have a mesh IP.
      # (only allowing on tailscale0/br-members left Mac unable to auth.)
      allowedTCPPorts = [ cfg.listenPort ];
      interfaces.tailscale0.allowedTCPPorts = [ cfg.listenPort ];
      interfaces.br-members.allowedTCPPorts = [ cfg.listenPort ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = "loose";
    };

    environment.systemPackages = [
      hs.package
    ];
  };
}
