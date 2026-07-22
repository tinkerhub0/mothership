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
      description = "Local Headscale HTTP port (loopback; exposed via serve + mesh IP).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = true;
      # All interfaces; firewall below only opens 8080 on tailscale0 (plus local).
      # That makes http://100.64.0.1:8080 work once this node owns the static IP.
      address = "0.0.0.0";
      port = cfg.listenPort;

      settings = {
        # Stable login URL (IP, not MagicDNS) — no base_domain collision.
        # Clients: --login-server=http://100.64.0.1:8080
        # Serve also publishes https://mothership.<baseDomain> (see tailscale.nix).
        server_url = "http://${cfg.mothershipIPv4}:${toString cfg.listenPort}";

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
      # Headscale HTTP from mesh only (not the LAN).
      interfaces.tailscale0.allowedTCPPorts = [ cfg.listenPort ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = "loose";
    };

    environment.systemPackages = [
      hs.package
    ];
  };
}
