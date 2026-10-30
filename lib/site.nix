# the public identity of this deployment, in one place.
# dns/ reads it today; the hosts still hardcode the edge
# (grep 178.105.120.5) and move over here one PR at a time.
{
  domain = "tharavad.xyz";

  # the front door: airtel's static ip on WAN_D, 1:1 to mothership
  # (10.20.0.10, SERVERS). null until WAN_D has its lease and the static ip
  # is confirmed from outside. while it's null the zone refuses to render, so
  # DNS can't be pointed at nothing. see docs/house-network.md.
  publicIPv4 = null;

  # the retired hetzner edge VPS. nothing may point here any more; the zone
  # refuses it. kept only so the check has something to refuse.
  retiredIPv4 = "178.105.120.5";
}
