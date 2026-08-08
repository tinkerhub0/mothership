# member: omnibox — god-tier playground
#   ssh omnibox@omnibox.tharavad.xyz
{
  tier = "god"; # 8 vCPU · 30G RAM · 200G disk
  enabled = true;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPgJj9GEaxD16KIwrB0M9qxeaFy33iCuCo99Jm/dxbkO terminal-shop"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMckfpjGyg3/Hx7Xu0racB/V/PlaY5TvmHQdkLC2y90G alvinliju44@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPykkjdk3kXfGgRKAllnOse/ez5lU47eGppXuwYmjMH nihalsaeed@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKrtVJcz/lEmUGV3csDpeKc8W0B2HXieZeaUBjnWdSz tinker"
  ];
  publish = [
    {
      port = 3000; # → https://omnibox.tharavad.xyz
    }
  ];
}
