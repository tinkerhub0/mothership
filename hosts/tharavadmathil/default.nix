# tharavadmathil — the house firewall. sophos xgs 126 running opnsense
# (npuforge image, os-xgs-npu driver). not nixos: this file is data,
# lib/opnsense.nix checks it, scripts/opnsense-apply pushes it over the api.
#
# what is NOT in here: secrets (api key, root password, certs), and the
# xgs plugin settings. the box is the state; git is the intent.
{
  hostname = "tharavadmathil.internal";

  # front ports by printed label. 9–12 are the aqr412c lanes on the
  # coprocessor (11/12 do 2.5G), 1–8 the 88e6193x switch.
  interfaces = {
    lan = {
      device = "bridge0";
      address = "192.168.12.1";
      prefix = 23; # 192.168.12.0 – 192.168.13.255, one subnet
      members = [ "Port3" ]; # uplink to the netgear; APs hang off the switch
    };
    # wans take dhcp from whatever isp box is on the port; those boxes and
    # their subnets move, so they are not pinned here.
    opt10 = {
      name = "WAN_A";
      device = "npup11"; # Port11
      ipv4 = "dhcp";
    };
    opt11 = {
      name = "WAN_B";
      device = "npup12"; # Port12
      ipv4 = "dhcp";
    };
    opt9 = {
      name = "WAN_C";
      device = "npup10"; # Port10 — jio
      ipv4 = "dhcp";
    };
  };

  # the api user scripts/opnsense-apply + opnsense-backup run as. made once
  # by an admin (it cannot grant itself rights); its key is in
  # secrets/tharavadmathil.sops.yaml. backups read the whole config.xml, so
  # this key is as sensitive as the config — admins only, like all secrets.
  apiUser = {
    name = "mothership";
    privileges = [
      "page-firewall-aliases"
      "page-firewall-alias-edit"
      "page-filter-api"
      "page-system-gateways"
      "page-system-gatewaygroups"
      "page-services-dnsforwarder"
      "page-interfaces-assignnetworkports"
      "page-status-interfaces"
      "page-diagnostics-configurationhistory"
    ];
  };

  # one monitor per gateway — opnsense pins each monitor ip to its own wan,
  # so they must all differ.
  gateways = {
    WAN_A_DHCP = {
      interface = "opt10";
      monitor = "1.1.1.1";
    };
    WAN_B_DHCP = {
      interface = "opt11";
      monitor = "9.9.9.9";
    };
    WAN_C_DHCP = {
      interface = "opt9";
      monitor = "208.67.222.222";
    };
  };

  # tier 1 carries traffic; higher tiers wait. same tier = load balance.
  gatewayGroups = {
    FAILOVER = {
      trigger = "downloss";
      tiers = {
        WAN_A_DHCP = 1;
        WAN_B_DHCP = 2;
        WAN_C_DHCP = 3;
      };
    };
  };

  dhcp = {
    lan = {
      start = "192.168.12.10";
      end = "192.168.13.250";
      leaseSeconds = 14400; # 4 h — phones rotate macs, short leases recycle
    };
  };

  aliases = {
    PrivateNets = {
      type = "network";
      content = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      description = "RFC1918 private networks";
    };
  };

  # matched on the box by description. order = sequence.
  rules = [
    {
      description = "LAN to private networks: normal routing";
      interface = "lan";
      source = "lan";
      destination = "PrivateNets";
      # no gateway: local traffic must not be policy-routed out a wan
    }
    {
      description = "Default allow LAN to any rule";
      interface = "lan";
      source = "lan";
      destination = "any";
      gateway = "FAILOVER";
    }
  ];
}
