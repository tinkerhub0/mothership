{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "omnibox-tailscale";
  version = "1.104.4";
  src = fetchurl {
    url = "https://pkgs.tailscale.com/stable/tailscale_${version}_amd64.tgz";
    hash = "sha256-Yk6gk9R9Ys9W8XuDMtdLjezaSh+qYQ68YKHeM0srPck=";
  };
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 tailscale "$out/bin/tailscale"
    install -Dm755 tailscaled "$out/bin/tailscaled"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test "$("$out/bin/tailscale" version | head -n1)" = "${version}"
    test "$("$out/bin/tailscaled" --version | head -n1)" = "${version}"
  '';
  meta = {
    description = "Pinned Tailscale for Omnibox's personal tailnet";
    homepage = "https://tailscale.com";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
