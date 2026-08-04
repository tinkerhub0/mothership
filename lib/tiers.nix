# resource ceilings per member tier — assert sum(mem) on the host later
{
  small = {
    mem = 1024; # MiB
    vcpu = 1;
    refquota = "10G";
  };
  medium = {
    mem = 2048;
    vcpu = 2;
    refquota = "20G";
  };
  large = {
    mem = 4096;
    vcpu = 4;
    refquota = "40G";
  };
  # operator playground — do not hand out lightly
  god = {
    mem = 30720; # MiB · 30G
    vcpu = 8;
    refquota = "200G";
  };
}
