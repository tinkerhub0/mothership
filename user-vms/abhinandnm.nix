# member: abhinandnm
#   ssh abhinandnm@abhinandnm.tharavad.xyz
{
  github = "abhinandnm";
  tier = "large"; # 4 vCPU · 4G RAM (needed to host a Flask mini-PaaS that clones repos, runs npm/pip/maven builds, and runs multiple application JVM/node processes in background)
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBFPRE6eYwvknZPmEf3qCqzdXE5KbZDHKnSoL9sSglz realnm@BROOKHEAVEN"
  ];
}
