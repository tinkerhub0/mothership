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
      lanNet = subnet lan.address lan.prefix;
      range = fw.dhcp.lan;
      monitors = lib.mapAttrsToList (_: g: g.monitor) fw.gateways;
      gwNames = lib.attrNames fw.gateways;
      groupNames = lib.attrNames fw.gatewayGroups;
      wanIfs = lib.filterAttrs (n: _: n != "lan") fw.interfaces;
      fail = cond: msg: lib.optional (!cond) msg;
    in
    lib.flatten [
      (fail (lan.prefix >= 8 && lan.prefix <= 30) "lan prefix /${toString lan.prefix} out of range")
      (fail (
        ipToInt lan.address == lanNet.network + 1
      ) "lan address ${lan.address} is not the first host of its subnet")
      (fail (inside lanNet range.start) "dhcp start ${range.start} not inside the lan")
      (fail (inside lanNet range.end) "dhcp end ${range.end} not inside the lan")
      (fail (ipToInt range.start <= ipToInt range.end) "dhcp start is after dhcp end")
      (fail (ipToInt range.start > ipToInt lan.address) "dhcp range overlaps the firewall address")
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
        (fail (
          lib.elem r.destination builtinNets || lib.hasAttr r.destination fw.aliases
        ) "rule '${r.description}': unknown destination ${r.destination}")
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
        range = {
          search = "dnsmasq/settings/searchRange";
          get = "dnsmasq/settings/getRange";
          add = "dnsmasq/settings/addRange";
          set = "dnsmasq/settings/setRange";
          apply = "dnsmasq/service/reconfigure";
          wrap = "range";
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
    ++ [
      (v4range
        {
          interface = "lan";
          domain_type = "range";
        }
        {
          interface = "lan";
          domain_type = "range";
          start_addr = fw.dhcp.lan.start;
          end_addr = fw.dhcp.lan.end;
          lease_time = toString fw.dhcp.lan.leaseSeconds;
        }
      )
    ]
    ++ lib.imap1 (
      i: r:
      item "rule" { inherit (r) description; } {
        inherit (r) description interface;
        enabled = "1";
        sequence = toString i;
        action = "pass";
        quick = "1";
        direction = "in";
        ipprotocol = "inet";
        protocol = "any";
        source_net = r.source;
        destination_net = r.destination;
        gateway = r.gateway or "";
      }
    ) fw.rules;
}
