# SETUP — bring the mothership online

Read `docs/MAIN.md` first if you do not know why any of this exists.
This file is the runbook. No philosophy. Just the path from bare metal
to `tailscale ip -4` printing `100.64.0.1`.

```
laptop ──edit──► git ──build──► mothership
                     ▲                │
                     └──── facter ────┘  (hardware truth, committed)
```

---

## 0. prerequisites

| you need | why |
|---|---|
| this repo on a machine with Nix (flakes on) | eval / edit |
| console or iDRAC on the box | when `switch` bricks you (it will, once) |
| root SSH pubkey already in `hosts/mothership/default.nix` | first login |
| single target disk | ESP + ZFS · we are not doing multipath fanfic yet |
| time | first install is slow; steady state is not |

On the laptop:

```bash
nix develop          # operator shell
nix flake check      # must pass before you touch metal
```

---

## 1. capture hardware (on the server / installer)

The Mac cannot see the Dell's disks. **facter runs on the box.**

From a Nix-capable environment on the target (installer ISO with Nix, or
an existing OS):

```bash
git clone <this-repo> && cd mothership
./scripts/capture-hardware.sh
# → writes hosts/mothership/facter.json
```

Manual equivalent:

```bash
sudo nix run github:nix-community/nixos-facter -- -o hosts/mothership/facter.json
```

Commit it from a machine that has git auth:

```bash
git add hosts/mothership/facter.json
git commit -m "host: facter report (disk + drivers)"
```

### disk pin (optional but based)

Autodetect takes the first whole disk in the report. If that is wrong:

```nix
# hosts/mothership/default.nix
mothership.diskDevice = "/dev/disk/by-id/nvme-YOUR_SERIAL_HERE";
```

```bash
# on the server
ls -l /dev/disk/by-id/
```

**Never format while the eval still warns about `/dev/sda` fallback.**

---

## 2. evaluate before you destroy anything

From the repo (Linux builder or the box):

```bash
nix eval .#nixosConfigurations.mothership.config.networking.hostName
# "mothership"

nix eval .#nixosConfigurations.mothership.config.mothership.mesh.mothershipIPv4
# "100.64.0.1"

nix eval .#nixosConfigurations.mothership.config.disko.devices.disk.main.device
# must be a real by-id or facter path — not the fallback if you are about to format
```

Build the system closure (needs `x86_64-linux`):

```bash
nix build .#nixosConfigurations.mothership.config.system.build.toplevel
```

If this fails, do not proceed to disko. Fix the eval.

---

## 3. install (destructive)

Pick **one** path. Both wipe the target disk.

### A. nixos-anywhere (remote, preferred if you have SSH to an installer)

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#mothership \
  --generate-hardware-config nixos-facter ./hosts/mothership/facter.json \
  root@<installer-or-box-ip>
```

### B. disko from live media (local console)

On the installer, with the repo present:

```bash
# THIS WIPES THE DISK
sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake .#mothership

sudo nixos-install --flake .#mothership
# set root password if prompted (SSH keys still win)
sudo reboot
```

After reboot: ESP mounted, pool `tank` imported, datasets visible:

```bash
zfs list
# tank/root  tank/nix  tank/var  tank/users
```

SSH in with the key that is in `authorizedKeys`.

---

## 4. first rebuild (day-2)

On mothership, repo at a known path (clone or copy):

```bash
cd /path/to/mothership
sudo nixos-rebuild switch --flake .#mothership
```

Confirm services:

```bash
systemctl status headscale tailscaled
ss -lntp | grep 8080
```

---

## 5. mesh bootstrap (order matters)

**Mothership must be the first node.** Sequential allocation → `.1`.

```bash
# also dropped at /etc/mothership/mesh-bootstrap.md after switch
sudo -u headscale headscale users create tinkerhub

KEY=$(sudo -u headscale headscale preauthkeys create \
  -u tinkerhub --reusable --expiration 24h)
echo "$KEY"

sudo tailscale up \
  --login-server=http://127.0.0.1:8080 \
  --authkey="$KEY" \
  --hostname=mothership \
  --accept-dns=true \
  --advertise-tags=tag:mothership

tailscale ip -4
# expect: 100.64.0.1

sudo -u headscale headscale nodes list
tailscale serve status
# https front → local headscale
```

### other machines (after mothership owns .1)

```bash
tailscale up \
  --login-server=http://100.64.0.1:8080 \
  --authkey=<key-from-headscale> \
  --accept-dns=true

# once MagicDNS works you can also try:
# --login-server=https://mothership.mesh.tinkerhub
```

Canonical login for automation stays **`http://100.64.0.1:8080`**.
Serve is the HTTPS face, not the bootstrap source of truth.

---

## 6. smoke checklist

| check | command / expect |
|---|---|
| hostname | `hostname` → `mothership` |
| ZFS | `zfs list` shows `tank/{root,nix,var,users}` |
| SSH | key auth as root (password auth off) |
| Headscale | `systemctl is-active headscale` → active |
| mesh IP | `tailscale ip -4` → `100.64.0.1` |
| serve | `tailscale serve status` shows 443 → :8080 |
| MagicDNS name | from another node: `ping mothership` / `mothership.mesh.tinkerhub` |
| generations | `nixos-rebuild list-generations` — keep a known-good |

---

## 7. emergency (read before you need it)

Active incident — do not wait for comin:

```bash
# kill mesh access now
sudo -u headscale headscale nodes list
sudo -u headscale headscale nodes delete -i <id>

# stop a member VM when those exist
# microvm -s users-<name>
```

**Rule:** out-of-band action is always followed by a commit within the hour.
Diverged state that stays diverged is the failure mode this repo exists to
escape.

Host bricked after a bad switch:

1. console / iDRAC  
2. boot previous generation from systemd-boot  
3. fix the commit, rebuild, never force-push over the bad one without a note  

---

## 8. what you deliberately do *not* do yet

- stand up Mattermost for real (`modules/deck` is a stub)  
- member microVMs / `user-vms/`  
- sops-encrypted preauth keys (manual key for now)  
- comin auto-rebuild  
- opening Headscale on the LAN "temporarily"  

---

## 9. day-2 operator loop

```bash
nix develop
# edit → commit → push
sudo nixos-rebuild switch --flake .#mothership
```

Later: comin polls `main` and the keyboard leaves the building.

---

**if you know you know.**  
If you do not: re-read `docs/MAIN.md`, then start at section 1.
