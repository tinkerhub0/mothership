#!/usr/bin/env bash
# run ON the freshly wiped box (console session as mothership).
# unlocks SSH, clones flake, installs REAL hardware-configuration, safe switch.
set -euo pipefail

KEYS=$(
  cat <<'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPgJj9GEaxD16KIwrB0M9qxeaFy33iCuCo99Jm/dxbkO terminal-shop
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfCFpZCX3ZtQg6kLK9cbtMj7V+75/f4VJt+ztTDFkNL terminal-shop-dev
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjUI8xR62zvnfBKoJ/S5UcBE8/5A+jyqppDLWOgpikg nihal-tinkerhub
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMckfpjGyg3/Hx7Xu0racB/V/PlaY5TvmHQdkLC2y90G alvinliju44@gmail.com
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINE0TI9u5ePkeYdDfzQUbdRFNL/8s8C0rCoTjYsSIZF0 test-deploy
EOF
)

echo "==> SSH keys for mothership + root"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  grep -qxF "$line" "$HOME/.ssh/authorized_keys" 2>/dev/null || echo "$line" >>"$HOME/.ssh/authorized_keys"
done <<<"$KEYS"

sudo mkdir -p /root/.ssh /etc/sudoers.d
sudo chmod 700 /root/.ssh
echo "$KEYS" | sudo tee /root/.ssh/authorized_keys >/dev/null
sudo chmod 600 /root/.ssh/authorized_keys
echo 'mothership ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/mothership >/dev/null
sudo chmod 440 /etc/sudoers.d/mothership
echo "    keys + passwordless sudo OK"

echo "==> clone / update repo (nix shell for git)"
cd ~
if [[ ! -d mothership/.git ]]; then
  nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c \
    git clone https://github.com/tinkerhub0/mothership.git
else
  nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c \
    git -C mothership pull --ff-only || true
fi
cd ~/mothership

echo "==> real hardware-configuration from this install (prevents mount death)"
if [[ -f /etc/nixos/hardware-configuration.nix ]]; then
  cp -v /etc/nixos/hardware-configuration.nix hosts/mothership/hardware-configuration.nix
else
  echo "WARN: no /etc/nixos/hardware-configuration.nix — generate:"
  echo "  sudo nixos-generate-config --show-hardware-config > hosts/mothership/hardware-configuration.nix"
  sudo nixos-generate-config --show-hardware-config >hosts/mothership/hardware-configuration.nix
fi

echo "==> confirm useDisko = false in hosts/mothership/default.nix"
grep -n 'useDisko' hosts/mothership/default.nix || true

echo "==> build + switch (SAFE path: installer disks, no disko)"
sudo nixos-rebuild switch --flake .#mothership

echo
echo "done. from laptop:"
echo "  ssh-keygen -R 192.168.11.199"
echo "  ssh mothership@192.168.11.199"
echo
echo "ZFS tank later = clean disko install OR set useDisko=true only after disks match."
