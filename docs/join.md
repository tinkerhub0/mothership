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

## Leaving

Delete your file in a PR. If you want to keep the name for later, set
`enabled = false;` instead.

Not using it? Seats idle for 10 days get parked, and later released, always
through a PR with a warning first. See [Keeping your seat](seats.md).
