# Getting a machine

> **Source of truth:** `user-vms/template.nix` · `lib/tiers.nix` · `lib/memberPolicy.nix` · `lib/mkMemberVM.nix` · `scripts/signup`

## 1. Have an SSH key on GitHub

Check with `curl https://github.com/<your-github>.keys`. If nothing prints,
[add a key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) first.

## 2. Write your member file

```bash
git clone https://github.com/tinkerhub0/mothership && cd mothership
scripts/signup --name you --github you --key "$(curl -s https://github.com/you.keys | head -1)"
```

This creates `user-vms/you.nix`. It's short, so open it and read it:

```nix
{
  github = "you";
  tier = "small";
  enabled = true;
  keys = [ "ssh-ed25519 AAAA… you@laptop" ];
}
```

Prefer doing it by hand? Copy `user-vms/template.nix` to `user-vms/you.nix`
and fill it in.

## 3. Open a pull request

```bash
git checkout -b add-you
git add user-vms/you.nix
git commit -m "add member: you"
git push origin add-you
```

Open the PR on GitHub. CI checks your file automatically, and then a human
reviews it.

## 4. Log in

About five minutes after the merge:

```bash
ssh you@you.tharavad.xyz
```

## Name rules

Your name becomes your username, your VM's hostname and your subdomain. So
it has to be:

- 2–16 characters: lowercase letters, digits and `-`, starting with a letter
- not taken, and not reserved (`root`, `admin`, `www`, …, listed in `lib/memberPolicy.nix`)
- one per person: a second file with the same GitHub handle is rejected

Save the file as plain UTF-8. Some Windows editors add an invisible
character (a "BOM") at the start, and that once broke every deploy for 2.5
months. CI catches it now.

## Sizes

| Tier | CPUs | RAM | Disk |
|---|---|---|---|
| `small` | 1 | 1 GB | 10 GB |
| `medium` | 2 | 2 GB | 20 GB |
| `large` | 4 | 4 GB | 40 GB |

Start with `small`. When you need more, open a PR that changes your tier and
says why.

## Put a website online

Run your app inside the VM on any port, then add it to your file:

```nix
publish = [
  { port = 3000; }                       # → https://you.tharavad.xyz
  { subdomain = "blog"; port = 8080; }   # → https://blog.tharavad.xyz
];
```

The HTTPS certificate is handled for you. Your app just serves plain HTTP.
How the request travels: [network.md](network.md#public-https).

For an app managed by `systemctl --user`, add `linger = true;` to your
member file. This starts your user services at boot and keeps them running
after you log out. Store unit files in `~/.config/systemd/user/`, which
persists across VM restarts, then enable them with `systemctl --user enable
--now <service>`. Keep app data in your home directory too; the guest's
root filesystem is temporary. Omnibox enables this setting for T3 Code
and its dedicated Tailscale service.

If your app ships a prebuilt Linux binary that expects the standard Linux
loader, set `nixLd = true;` in your member file. This enables NixOS's
`nix-ld` loader for your VM. Omnibox uses it so the T3 Code updater can
start the binaries it downloads.

## Keep Nix packages registered across reboots

Set `persistNixState = true;` in your member file. This gives the guest's
Nix database and system-managed profile links a persistent disk. Nix can
then keep track of the packages you install with `nix profile` across
VM reboots. Omnibox enables this option.

On an existing VM, save the current registrations and profile links from
inside the guest before merging the change. Run this after any final
package updates and while Nix still recognizes the installed packages:

```bash
sudo bash -eu <<'EOF'
umask 077
stage=/nix/.rw-store/nix-state-import
install -d -m 0700 "$stage" "$stage/links"
cd /nix/var/nix
for path in gcroots/auto gcroots/per-user profiles/per-user; do
  if [ -d "$path" ]; then
    cp -a --parents "$path" "$stage/links"
  fi
done
nix-store --dump-db > "$stage/registration.new"
mv "$stage/registration.new" "$stage/registration"
EOF
```

The first boot imports the saved state and renames the export to
`registration.imported`. After deployment, run `nix profile list` and
`nix path-info` on the store paths it shows. If Nix already forgot an
installed package before the export, restore that package first.

## Leaving

Delete your file in a PR. If you want to keep the name for later, set
`enabled = false;` instead.

Not using it? Seats idle for 10 days get parked, and later released, always
through a PR with a warning first. See [Keeping your seat](seats.md).
