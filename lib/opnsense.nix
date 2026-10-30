# opnsense as data — check a hosts/<fw>/default.nix and turn it into api
# payloads for scripts/opnsense-apply. pure nix, evaluates on any system.
{ lib }:
let
  ipToInt =
    ip:
    let
      o = map lib.toInt (lib.splitString "." ip);
    in
    if lib.length o != 4 || lib.any (x: x < 0 || x > 255) o then
      throw "not an ipv4 address: ${ip}"
    else
      lib.foldl (acc: x: acc * 256 + x) 0 o;

  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);

  subnet =
    address: prefix:
    let
      size = pow2 (32 - prefix);
      base = ipToInt address / size * size;
    in
    {
      network = base;
      broadcast = base + size - 1;
    };

  inside = net: ip: net.network < ipToInt ip && ipToInt ip < net.broadcast;

  builtinNets = [
    "any"
    "lan"
    "(self)"
  ];
in
rec {
  inherit ipToInt subnet;

  # [ "failure" ... ] — empty means the file is sane
  check =
    fw:
    let
      lan = fw.interfaces.lan;
      monitors = lib.mapAttrsToList (_: g: g.monitor) fw.gateways;
      gwNames = lib.attrNames fw.gateways;
      groupNames = lib.attrNames fw.gatewayGroups;
      # an interface with an address is ours (static); without one it's a wan (dhcp)
      wanIfs = lib.filterAttrs (_: i: !(i ? address)) fw.interfaces;
      ownIfs = lib.filterAttrs (_: i: i ? address) fw.interfaces;
      nets = builtinNets ++ lib.attrNames fw.interfaces ++ map (n: "${n}ip") (lib.attrNames fw.interfaces);
      knownNet = n: lib.elem n nets || lib.hasAttr n fw.aliases;
      fail = cond: msg: lib.optional (!cond) msg;
    in
    lib.flatten [
      (fail (lan ? address) "lan needs a static address")
      (lib.mapAttrsToList (
        n: i:
        let
          net = subnet i.address i.prefix;
        in
        [
          (fail (i.prefix >= 8 && i.prefix <= 30) "${n} prefix /${toString i.prefix} out of range")
          (fail (
            ipToInt i.address == net.network + 1
          ) "${n} address ${i.address} is not the first host of its subnet")
        ]
      ) ownIfs)
      (lib.mapAttrsToList (
        n: d:
        let
          i = fw.interfaces.${n} or { };
          net = subnet i.address i.prefix;
          hosts = d.hosts or { };
        in
        if !(i ? address) then
          [ "dhcp on ${n}: not a static interface" ]
        else
          [
            (fail (inside net d.start) "dhcp ${n}: start ${d.start} not inside ${n}")
            (fail (inside net d.end) "dhcp ${n}: end ${d.end} not inside ${n}")
            (fail (ipToInt d.start <= ipToInt d.end) "dhcp ${n}: start is after end")
            (fail (ipToInt d.start > ipToInt i.address) "dhcp ${n}: range overlaps the firewall address")
            (lib.mapAttrsToList (h: r: [
              (fail (inside net r.ip) "dhcp ${n}: host ${h} ${r.ip} not inside ${n}")
              (fail (r.ip != i.address) "dhcp ${n}: host ${h} takes the firewall address")
              (fail (
                ipToInt r.ip < ipToInt d.start || ipToInt r.ip > ipToInt d.end
              ) "dhcp ${n}: host ${h} ${r.ip} sits inside the dynamic range")
            ]) hosts)
          ]
      ) fw.dhcp)
      (fail (lib.length monitors == lib.length (lib.unique monitors)) "gateway monitor ips must differ")
      (lib.mapAttrsToList (
        n: g: fail (lib.hasAttr g.interface wanIfs) "gateway ${n}: interface ${g.interface} not declared"
      ) fw.gateways)
      (lib.mapAttrsToList (
        n: grp:
        lib.mapAttrsToList (gw: tier: [
          (fail (lib.elem gw gwNames) "group ${n}: unknown gateway ${gw}")
          (fail (tier >= 1 && tier <= 5) "group ${n}: tier ${toString tier} for ${gw} not 1–5")
        ]) grp.tiers
      ) fw.gatewayGroups)
      (map (r: [
        (fail (
          r ? gateway -> lib.elem r.gateway (gwNames ++ groupNames)
        ) "rule '${r.description}': unknown gateway ${r.gateway or ""}")
        (fail (knownNet r.destination) "rule '${r.description}': unknown destination ${r.destination}")
        (fail (knownNet r.source) "rule '${r.description}': unknown source ${r.source}")
        (fail (lib.elem (r.action or "pass") [
          "pass"
          "block"
          "reject"
        ]) "rule '${r.description}': action must be pass, block or reject")
        (fail (lib.hasAttr r.interface fw.interfaces) "rule '${r.description}': unknown interface ${r.interface}")
      ]) fw.rules)
      (fail (
        lib.length (map (r: r.description) fw.rules)
        == lib.length (lib.unique (map (r: r.description) fw.rules))
      ) "rule descriptions must be unique — the applier matches on them")
      (fail (
        let
          devs = lib.mapAttrsToList (_: i: i.device) fw.interfaces;
        in
        lib.length devs == lib.length (lib.unique devs)
      ) "two interfaces on the same device")
      (lib.mapAttrsToList (
        n: i:
        fail (lib.elem (i.ipv4 or "dhcp") [
          "dhcp"
        ]) "interface ${n}: ipv4 '${i.ipv4}' — wans are dhcp only for now"
      ) wanIfs)
      (lib.mapAttrsToList (
        n: grp:
        fail (lib.elem grp.trigger triggers) "group ${n}: trigger '${grp.trigger}' not one of ${toString triggers}"
      ) fw.gatewayGroups)
    ];

  # opnsense's gateway group triggers: down, loss, latency, loss or latency
  triggers = [
    "down"
    "downloss"
    "downlatency"
    "downlosslatency"
  ];

  # what scripts/opnsense-apply manages. each item: the api family, how to
  # find it on the box (match), and the fields to set. never deletes.
  resources =
    fw:
    let
      # endpoint names read off the 26.7.7 gui pages, not guessed
      api = {
        iface = {
          search = "interfaces/assignment/search_item";
          get = "interfaces/assignment/get_item";
          add = "interfaces/assignment/add_item";
          set = "interfaces/assignment/set_item";
          apply = "interfaces/assignment/reconfigure";
          wrap = "interface";
        };
        group = {
          search = "routing/group_settings/search";
          get = "routing/group_settings/get";
          add = "routing/group_settings/add";
          set = "routing/group_settings/set";
          apply = "routing/group_settings/reconfigure";
          wrap = "gateway_group";
        };
        alias = {
          search = "firewall/alias/searchItem";
          get = "firewall/alias/getItem";
          add = "firewall/alias/addItem";
          set = "firewall/alias/setItem";
          apply = "firewall/alias/reconfigure";
          wrap = "alias";
        };
        gateway = {
          search = "routing/settings/searchGateway";
          get = "routing/settings/getGateway";
          add = "routing/settings/addGateway";
          set = "routing/settings/setGateway";
          apply = "routing/settings/reconfigure";
          wrap = "gateway_item";
        };
        # one settings object, no uuid: the script gets/sets it without one
        dnsmasq = {
          search = null;
          get = "dnsmasq/settings/get";
          set = "dnsmasq/settings/set";
          apply = "dnsmasq/service/reconfigure";
          wrap = "dnsmasq";
        };
        range = {
          search = "dnsmasq/settings/searchRange";
          get = "dnsmasq/settings/getRange";
          add = "dnsmasq/settings/addRange";
          set = "dnsmasq/settings/setRange";
          apply = "dnsmasq/service/reconfigure";
          wrap = "range";
        };
        host = {
          search = "dnsmasq/settings/searchHost";
          get = "dnsmasq/settings/getHost";
          add = "dnsmasq/settings/addHost";
          set = "dnsmasq/settings/setHost";
          apply = "dnsmasq/service/reconfigure";
          wrap = "host";
        };
        rule = {
          search = "firewall/filter/searchRule";
          get = "firewall/filter/getRule";
          add = "firewall/filter/addRule";
          set = "firewall/filter/setRule";
          apply = "firewall/filter/apply";
          wrap = "rule";
        };
      };
      item = kind: match: fields: {
        inherit kind match fields;
        api = api.${kind};
      };
      # lan has a v4 and a v6 range on the same interface; tell them apart
      v4range = match: fields: item "range" match fields // { family = "inet"; };
      # tiers { gw = n; } → opnsense's item (tier 1) … item5, comma-joined
      tierField = n: if n == 1 then "item" else "item${toString n}";
      tierItems =
        tiers:
        lib.listToAttrs (
          map (n: {
            name = tierField n;
            value = lib.concatStringsSep "," (
              lib.sort lib.lessThan (lib.attrNames (lib.filterAttrs (_: t: t == n) tiers))
            );
          }) (lib.range 1 5)
        );
    in
    # dependency order: interfaces → gateways → groups → aliases → dhcp → rules
    lib.mapAttrsToList (
      id: i:
      item "iface" { identifier = id; } (
        {
          descr = i.name or (lib.toUpper id);
          "if" = i.device;
          enable = "1";
        }
        // (
          if i ? address then
            {
              type4 = "staticv4";
              ipaddr = "${i.address}/${toString i.prefix}";
            }
          else
            { type4 = i.ipv4 or "dhcp"; }
        )
      )
    ) fw.interfaces
    ++ lib.mapAttrsToList (
      name: g:
      item "gateway" { inherit name; } {
        inherit name;
        inherit (g) interface monitor;
        descr = "Interface ${name} Gateway";
        ipprotocol = "inet";
        disabled = "0";
        monitor_disable = "0";
        priority = "254";
        weight = toString (g.weight or 1);
      }
    ) fw.gateways
    ++ lib.mapAttrsToList (
      name: grp:
      item "group" { inherit name; } (
        {
          inherit name;
          inherit (grp) trigger;
        }
        // tierItems grp.tiers
      )
    ) fw.gatewayGroups
    ++ lib.mapAttrsToList (
      name: a:
      item "alias" { inherit name; } {
        inherit name;
        enabled = "1";
        inherit (a) type description;
        content = lib.concatStringsSep "\n" a.content;
      }
    ) fw.aliases
    # dnsmasq only answers dhcp on the interfaces listed here. a range on an
    # interface missing from it is silently ignored (SERVERS, 2026-10-30).
    ++ [
      (item "dnsmasq" { } {
        interface = lib.concatStringsSep "," (lib.sort lib.lessThan (lib.attrNames fw.dhcp));
      })
    ]
    ++ lib.mapAttrsToList (
      n: d:
      v4range
        {
          interface = n;
          domain_type = "range";
        }
        {
          interface = n;
          domain_type = "range";
          start_addr = d.start;
          end_addr = d.end;
          lease_time = toString d.leaseSeconds;
        }
    ) fw.dhcp
    # fixed addresses: dnsmasq hosts, matched by name
    ++ lib.flatten (
      lib.mapAttrsToList (
        _: d:
        lib.mapAttrsToList (
          h: r:
          item "host" { host = h; } {
            host = h;
            inherit (r) ip;
            hwaddr = r.mac;
            descr = r.description or "";
          }
        ) (d.hosts or { })
      ) fw.dhcp
    )
    ++ lib.imap1 (
      i: r:
      item "rule" { inherit (r) description; } {
        inherit (r) description interface;
        enabled = "1";
        sequence = toString i;
        action = r.action or "pass";
        quick = "1";
        direction = r.direction or "in";
        ipprotocol = "inet";
        protocol = r.protocol or "any";
        source_net = r.source;
        source_not = if r.sourceNot or false then "1" else "0";
        destination_net = r.destination;
        destination_port = r.port or "";
        gateway = r.gateway or "";
      }
    ) fw.rules;
}
