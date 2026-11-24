# Operating it

> **Source of truth:** `lib/adminKeys.nix` · `modules/admins.nix` · `modules/base.nix`

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

For a live view of every member VM, see [Inspecting member VMs](vm-inspection.md).

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
