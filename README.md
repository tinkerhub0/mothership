<div align="center">

# mothership

**A whole hackerspace's infrastructure in one git repo.**

Open a pull request, get your own Linux machine. Break it, and git builds it back.

[Get a machine](#get-a-machine-in-5-minutes) · [How it works](#how-it-works) · [Docs](docs/) · [Why](why-this-exist) · [Contribute](CONTRIBUTING.md)

</div>

---

mothership runs [TinkerHub](https://github.com/tinkerhub0)'s community server. That's one Dell server in the room, a small public front door, and the space's firewall, all built from this repo with [Nix](https://nixos.org).

There's no admin panel, sign-up form or ticket queue. **Your access is a file in `user-vms/`.** When someone merges your PR, the server builds you a virtual machine with your SSH key, your own subdomain and a disk quota. It takes about five minutes, and nobody has to log in and click anything.

## Get a machine in 5 minutes

You need a GitHub account with an SSH key on it ([how to add one](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)).

```bash
git clone https://github.com/tinkerhub0/mothership && cd mothership

# writes user-vms/<you>.nix with your public key
scripts/signup --name you --github you --key "$(curl -s https://github.com/you.keys | head -1)"

git checkout -b add-you
git add user-vms/you.nix
git commit -m "add member: you"
git push origin add-you        # then open a pull request on GitHub
```

Once it's merged:

```bash
ssh you@you.tharavad.xyz
```

That's your machine. Install anything. Want a website? Add one line and it's live at `https://you.tharavad.xyz`. See [docs/join.md](docs/join.md).

## What you get

- **A real VM, not a shared account.** You get your own kernel and root, and your mess stays yours.
- **SSH from anywhere.** `ssh you@you.tharavad.xyz` works from any network, with no VPN to install.
- **Public HTTPS in one line.** Run a server on a port, list the port in your file, and you get a certificate automatically.
- **Sizes to grow into.** `small` (1 CPU, 1 GB RAM) up to `large` (4 CPU, 4 GB RAM).
- **Everything is reviewable.** Who has access, who approved it, and when: it's all in `git log`.

## How it works

```
  you ── PR ──► GitHub ── merge ──► mothership pulls main every 2 min
                                          │
                                          ▼
                              nix builds the whole server
                              (your VM, keys, URL, quota)

  internet ──► edge (small VPS) ──wireguard──► mothership ──► your VM
               ssh :22, https :443             Dell R730xd
```

| Piece | What it is | Lives in |
|---|---|---|
| **mothership** | the Dell server that runs every member VM | `hosts/mothership/` |
| **edge** | a small public VPS: the front door for SSH and HTTPS | `hosts/edge/` |
| **tharavadmathil** | the space's firewall (OPNsense on a Sophos XGS) | `hosts/tharavadmathil/` |
| **user-vms/** | one file per member | `user-vms/*.nix` |
| **git-sync** | pulls `main` and applies it | `modules/git-sync.nix` |

The longer tour: [docs/](docs/).

## By the numbers

Measured on the real box, 2026-10-29.

| | |
|---|---|
| Hardware | Dell R730xd · 88 threads · 62 GB RAM · 4.5 TB |
| Members | 36 |
| Power at idle | 151 W |
| Rebuild the whole server config from scratch | 5 min 23 s |
| Energy for that rebuild | ~17 Wh |

How we measure, and what we're trying to improve: [docs/drills.md](docs/drills.md).

## For operators

```bash
nix develop          # tools
nix flake check      # what CI runs on every PR
```

Day-to-day running: [docs/ops.md](docs/ops.md). Deploys: [docs/deploy.md](docs/deploy.md).

## Use it as a reference

We want this to be the repo people link when they ask how to:

- **run NixOS on Hetzner**: install, network quirks, DNS as code, wildcard certs. See [docs/hetzner.md](docs/hetzner.md)
- **tune a used server**: real power, boot and build numbers, and what we changed. See [docs/drills.md](docs/drills.md)
- **give a community machines from git**: this whole repo

## Run one at your own space

mothership is built for TinkerHub, but nothing in it is secret sauce. To fork it, swap the domain and public IP (`lib/site.nix`), the admin keys (`lib/adminKeys.nix`) and the host IPs. A guide is on the [roadmap](docs/drills.md#drills-to-run). Open an issue if you try it.

## Contributing

Bug reports, doc fixes and "this confused me" issues are all welcome. Confused newcomers are the people this is for. See [CONTRIBUTING.md](CONTRIBUTING.md).
