#!/usr/bin/env bash
# run ONCE on the box (as mothership or root) so the laptop/agent can SSH in.
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

append_keys() {
  local home="$1"
  mkdir -p "$home/.ssh"
  chmod 700 "$home/.ssh"
  local ak="$home/.ssh/authorized_keys"
  touch "$ak"
  chmod 600 "$ak"
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    grep -qxF "$line" "$ak" 2>/dev/null || printf '%s\n' "$line" >>"$ak"
  done <<<"$KEYS"
  echo "→ $ak"
}

append_keys "${HOME}"

if [[ "$(id -u)" -eq 0 ]]; then
  append_keys /root
else
  sudo mkdir -p /root/.ssh
  sudo chmod 700 /root/.ssh
  if [[ ! -f /root/.ssh/authorized_keys ]]; then
    echo "$KEYS" | sudo tee /root/.ssh/authorized_keys >/dev/null
  else
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      sudo grep -qxF "$line" /root/.ssh/authorized_keys 2>/dev/null \
        || echo "$line" | sudo tee -a /root/.ssh/authorized_keys >/dev/null
    done <<<"$KEYS"
  fi
  sudo chmod 600 /root/.ssh/authorized_keys
  echo "→ /root/.ssh/authorized_keys"
fi

echo
echo "done. from laptop:"
echo "  ssh mothership@192.168.11.199"
echo "  ssh root@192.168.11.199"
