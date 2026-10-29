{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "t3code";
  version = "0.1.3";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/t3-${version}-linux-x64.tar.gz";
    hash = "sha256-Y80PBUfu9iu07OJ/p3m7+eK6hTHMaFQlaLqeeIONxoQ=";
  };
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontBuild = true;
  # Preserve the executable's embedded Node application and bundled native helpers.
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/t3code" "$out/bin"
    cp -a . "$out/libexec/t3code/"
    ln -s "$out/libexec/t3code/t3" "$out/bin/t3"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test "$("$out/bin/t3" --version)" = "t3 v${version}"
  '';
  meta = {
    description = "T3 Code self-contained server";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "t3";
  };
}
