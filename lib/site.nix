# the public identity of this deployment, in one place.
# dns/ reads it today; the hosts still hardcode the same values
# (grep 178.105.120.5) and should move over here one PR at a time.
{
  domain = "tharavad.xyz";

  # edge VPS (hetzner). when airtel's static ip replaces the edge, change
  # it here and DNS follows on merge.
  publicIPv4 = "178.105.120.5";
}
