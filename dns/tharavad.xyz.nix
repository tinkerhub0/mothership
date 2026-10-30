# tharavad.xyz — every record, as data. octoDNS pushes it to hetzner DNS
# (the zone is hosted there; no record points at a hetzner machine).
#
#   nix eval --json .#dns.zones.\"tharavad.xyz\"   what octoDNS will be told
#   .github/workflows/dns.yml                       dry-run on PR, apply on merge
#
# shape = octoDNS's YamlProvider (JSON is YAML): name → { type, ttl, value(s) }.
# '' is the apex, '*' the wildcard that gives every member you.tharavad.xyz.
let
  site = import ../lib/site.nix;
  ttl = 300;
  # home, never the retired edge. fail the render instead of guessing.
  front =
    if site.publicIPv4 == null then
      throw "lib/site.nix: publicIPv4 is null. set airtel's static ip (WAN_D) before DNS can render"
    else if site.publicIPv4 == site.retiredIPv4 then
      throw "lib/site.nix: publicIPv4 is the retired hetzner edge"
    else
      site.publicIPv4;
  a = value: {
    inherit ttl value;
    type = "A";
  };
  toApex = {
    inherit ttl;
    type = "CNAME";
    value = "${site.domain}.";
  };
in
{
  # apex + wildcard → front door: airtel static → WAN_D → 1:1 → mothership
  # (bastion ssh, member https, landing, headscale :8080)
  "" = a front;
  "*" = a front;

  auth = toApex;
  chat = toApex;
  headscale = toApex;
  monitor = toApex;
  status = toApex;
  wiki = toApex;
  landa = toApex; # landa console (static ui)
  landa-back = toApex; # landa control plane api (edge nginx → :8787)

  # outbound email via resend (amazon ses underneath). these were added by
  # hand in the hetzner console; without them octoDNS would delete them.
  "resend._domainkey" = {
    ttl = 3600;
    type = "TXT";
    value = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDREVubkMIbYtMe/vBieSqUf07vl8pK43qUW19GSzw1e8gkDmyhE05WYS5wqi9TFumylbEFsQwlKjh/WfodqKSaLOVgKmEZU0JYcp4gxsKmi4y1cZs07QtiFA2UAu4Z8P9zMCDi6u/0EE140kN6+vnbuTho1doWZao5ccQGqAduvQIDAQAB";
  };
  # two record types on one name → a list
  send = [
    {
      ttl = 3600;
      type = "MX";
      value = {
        preference = 0;
        exchange = "feedback-smtp.ap-northeast-1.amazonses.com.";
      };
    }
    {
      ttl = 3600;
      type = "TXT";
      value = "v=spf1 include:amazonses.com ~all";
    }
  ];
}
