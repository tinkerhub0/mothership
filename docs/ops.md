# Operating it

> **Source of truth:** `lib/adminKeys.nix` · `modules/admins.nix` · `modules/base.nix` · `hosts/mothership/default.nix` · `flake.lock`

For admins. Members don't need any of this.

## Who's an admin

Anyone whose public key is in `lib/adminKeys.nix`. Admins can log in as
`root`, `mothership` or `nixos`. Sudo needs no password.

**There are no passwords at all**: password login is switched off. Lost
your key? Make a new one and ask another admin to merge a PR adding it.

## Getting in

```bash
ssh mothership@tharavad.xyz                 # the server, through the edge
ssh -J root@178.105.120.5 root@10.99.0.2    # the same, spelled out
```

The first time you connect, SSH shows the server's fingerprint. Check it
with another admin before typing `yes`.

## Looking around

```bash
systemctl --failed                          # anything broken?
systemctl list-units 'microvm@*'            # member VMs
journalctl -u microvm@<name> -n 100         # one VM's log
journalctl -fu mothership-git-sync          # deploys, live
ip -br a                                    # network interfaces
sudo nix shell nixpkgs#ipmitool -c ipmitool dcmi power reading   # watts
```

## Inspecting VMs

Run [microvmctl](https://github.com/mantoine96/microvmctl) on mothership.
Replace `VM` with the name shown by `microvmctl list`.

```bash
microvmctl                       # live, interactive terminal view
microvmctl list                  # VM state, uptime, memory and guest address
microvmctl top                   # live CPU and memory use
microvmctl status VM             # running system and pending update
microvmctl logs VM -f            # follow the VM's logs
```

Start with the commands above as your normal user. Use `sudo microvmctl top`
for disk and network rates. Use `sudo microvmctl status VM` for details such
as shared folders and whether the VM is paused. These details and the
`pause` and `resume` commands need access to the private socket used by
cloud-hypervisor, the program that runs the VMs.

The `console` and `ssh` commands also need guest settings. `console` needs
an interactive console, and `ssh` needs SSH over vsock (a direct
host-to-guest connection). For normal SSH, see [Getting a machine](join.md).

## Undoing a bad change

```bash
sudo nixos-rebuild switch --rollback        # back to the previous version, right now
```

Or pick an older version from the boot menu, through the iDRAC console.

Then **fix it in git**. Otherwise git-sync re-applies the bad commit two
minutes later.

## House rules

- Ask in the channel before rebooting anything shared.
- Secrets go in git only encrypted (`secrets/*.sops.*`). Never in plain text.
- Never put API keys on a command line: they leak into shell history and logs.
