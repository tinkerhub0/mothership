#!/usr/bin/env bash
# Run this ON mothership (or install media with Nix), not on your laptop.
# Writes hosts/mothership/facter.json — kernel modules + disk autodetect for disko.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo_root/hosts/mothership/facter.json"

echo "→ capturing hardware → $out"
sudo nix run github:nix-community/nixos-facter -- -o "$out"

echo "→ disks seen by facter:"
nix --extra-experimental-features 'nix-command flakes' eval --raw --impure --expr "
  let
    r = builtins.fromJSON (builtins.readFile $out);
    disks = r.hardware.disk or [];
  in
    builtins.concatStringsSep \"\n\" (map (d: d.unix_device_name or \"?\") disks)
" 2>/dev/null || jq -r '.hardware.disk[]?.unix_device_name // empty' "$out" 2>/dev/null || true

echo
echo "Commit it:"
echo "  git add hosts/mothership/facter.json && git commit -m 'host: add facter report'"
