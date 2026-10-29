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
root filesystem is temporary.

### Omnibox's T3 Code service

Source of truth: `user-vms/omnibox.nix` · `modules/guests/omnibox-t3.nix` ·
`pkgs/t3code.nix` · `pkgs/omnibox-tailscale.nix`.

Omnibox imports its service module through the optional `extraModules` list
in its member file. Other member VMs do not load it. Nix supplies T3 Code,
its native libraries, the personal Tailscale client, and the user services.
Package dependencies are retained by the VM's Nix configuration, so the
manual library links are no longer required by the service.

As of 2026-10-29, the pinned versions are T3 Code 0.1.3 and Tailscale 1.104.4.
Change their versions and checksums in a PR; merge and let git-sync deploy.
Do not use `t3 service install` or `t3 update` on this Nix-managed service.

The first deployment archives the old home-directory service files under
`~/.local/state/omnibox-t3/legacy-units/` before the user manager starts.
It leaves `~/.t3` (projects, sessions, and pairing grants) and
`~/.local/share/omnibox-tailscale` (personal tailnet identity and certificates)
in place. Existing provider installations and sign-ins stay in the home
directory; the module does not provision provider credentials.

Omnibox also enables nix-ld, a compatibility loader for generic Linux
executables downloaded by provider updaters. This applies only to Omnibox.
The T3 service searches `~/.local/bin` and `~/.opencode/bin` before the Nix
profile, so native Claude and OpenCode installations can update themselves.
Provider packages installed through `nix profile` still need Nix upgrades;
their self-updaters cannot replace files in the Nix store.

After the merged configuration deploys, check `~/.local/bin/claude --version`
and `~/.opencode/bin/opencode --version` inside Omnibox. If a native provider
is missing, install it with that provider's installer. Once the native copies
work, use `nix profile list` to find any older Claude or OpenCode entries and
`nix profile remove <name>` to remove those entries. Restart T3 with
`systemctl --user restart t3code`, then check its provider versions again.
Provider sign-ins remain in the persistent home directory.

Use `systemctl --user status t3code omnibox-tailscale omnibox-tailscale-serve`
and `journalctl --user -u t3code` inside Omnibox. `tailscale-omnibox status`
addresses the personal connection; plain `tailscale` still addresses the
infrastructure Headscale network. On a new VM, run `tailscale-omnibox up
--hostname=omnibox --accept-dns=false --accept-routes=false`, complete its
sign-in, and enable Tailscale Serve when prompted. The forwarding service
retries until the connection is ready. It exposes SSH and T3 HTTPS only
inside that personal tailnet.

The old downloaded runtimes and manual library links are left in the
persistent home for rollback. They are not used by the Nix-managed units;
remove them only after verifying the merged deployment.

## Leaving

Delete your file in a PR. If you want to keep the name for later, set
`enabled = false;` instead.
