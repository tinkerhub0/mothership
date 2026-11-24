# isolation — member VMs can't impersonate each other, spam, or starve the host.
#
#   anti-spoof   frames off a member's tap must carry that member's MAC, and
#                IPv4/ARP must carry its IP (lib/mkMemberVM.nix mac + ip).
#                no rogue DHCP servers, no router adverts, unknown taps dropped.
#   no smtp      tcp/25 out of br-members is refused (one spammer = blocklisted IP)
#   ct cap       new connections per VM capped, so one guest can't fill the
#                host's conntrack table and break NAT for everyone
#
# same idea as hetzner cloud's per-VM OVS flows, compiled from user-vms/*.nix.
#
# rollout: enforce = false only counts hits (`nft list table bridge
# mothership-isolation`). flip it once every guest renewed onto its static lease.
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.microvms.isolation;
  vms = config.mothership.microvms;
  members = vms.enabledMembers;

  spoofVerdict = if cfg.enforce then "counter drop" else "counter";

  taps = lib.mapAttrsToList (_: m: ''"${m.tapId}"'') members;

  perTap = lib.concatStrings (
    lib.mapAttrsToList (name: m: ''
      # ${name}
      iifname "${m.tapId}" ether saddr != ${m.mac} ${spoofVerdict}
      iifname "${m.tapId}" arp saddr ether != ${m.mac} ${spoofVerdict}
      iifname "${m.tapId}" arp saddr ip != { 0.0.0.0, ${m.ip} } ${spoofVerdict}
      iifname "${m.tapId}" ip saddr != { 0.0.0.0, ${m.ip} } ${spoofVerdict}
    '') members
  );

  ips = lib.mapAttrsToList (_: m: m.ip) members;
  dupIps = lib.unique (lib.filter (ip: lib.count (x: x == ip) ips > 1) ips);
in
{
  options.mothership.microvms.isolation = {
    enable = lib.mkEnableOption "per-member anti-spoof, smtp block and conntrack cap" // {
      default = true;
    };

    enforce = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "drop spoofed frames. false = count only (rollout)";
    };

    maxConnsPerVM = lib.mkOption {
      type = lib.types.ints.positive;
      default = 16384;
      description = "concurrent tracked connections per member VM";
    };
  };

  config = lib.mkIf (vms.enable && cfg.enable) {
    assertions = [
      {
        assertion = dupIps == [ ];
        message = "mothership.microvms: members hash to the same ip ${lib.concatStringsSep ", " dupIps}; rename one";
      }
    ];

    networking.nftables.enable = true;

    # room for every VM to sit at its cap without starving the host
    boot.kernel.sysctl."net.netfilter.nf_conntrack_max" = lib.mkDefault 1048576;

    networking.nftables.tables = {
      # L2: what enters br-members from a guest tap
      mothership-isolation = {
        family = "bridge";
        content = ''
          chain from-guest {
            type filter hook prerouting priority filter; policy accept;
            meta ibrname != "br-members" accept

            # DHCP client → host always passes, so a guest on an old lease can renew
            udp sport 68 udp dport 67 accept

            # guests are not DHCP servers or routers
            udp sport 67 counter drop
            icmpv6 type nd-router-advert counter drop

            ${lib.optionalString (taps != [ ]) ''
              iifname != { ${lib.concatStringsSep ", " taps} } counter drop
            ''}
            ${perTap}
          }
        '';
      };

      # L3: what guests send through the host
      mothership-guest-limits = {
        family = "inet";
        content = ''
          set conns {
            type ipv4_addr
            flags dynamic
            size 65535
          }

          chain guest-prerouting {
            type filter hook prerouting priority filter; policy accept;
            iifname "br-members" ct state new add @conns { ip saddr ct count over ${toString cfg.maxConnsPerVM} } counter drop
          }

          chain guest-forward {
            type filter hook forward priority filter; policy accept;
            iifname "br-members" tcp dport 25 counter reject with tcp reset
          }
        '';
      };
    };
  };
}
