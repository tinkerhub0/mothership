#!/usr/bin/env bash
# capture-hardware — frozen scan of THIS box (not your laptop).
# writes hosts/mothership/facter.json → drivers + disk autodetect for disko.
# run on mothership / installer. commit the JSON. if you know you know.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo_root/hosts/mothership/facter.json"

echo "→ facter → $out"
sudo nix run github:nix-community/nixos-facter -- -o "$out"

echo "→ disks:"
nix --extra-experimental-features 'nix-command flakes' eval --raw --impure --expr "
  let
    r = builtins.fromJSON (builtins.readFile $out);
    disks = r.hardware.disk or [];
  in
    builtins.concatStringsSep \"\n\" (map (d: d.unix_device_name or \"?\") disks)
" 2>/dev/null || jq -r '.hardware.disk[]?.unix_device_name // empty' "$out" 2>/dev/null || true

echo
echo "commit:"
echo "  git add hosts/mothership/facter.json && git commit -m 'host: facter report'"
