# How deploys work

> **Source of truth:** `modules/git-sync.nix` · `scripts/host-git-sync` · `scripts/deploy-notify` · `.github/workflows/check.yml`

## From merge to running

```
1. You open a PR
       └─ CI: checks for invisible characters, evaluates the config, runs nix flake check
2. Someone merges it into main
3. Within 2 minutes, git-sync on mothership notices
       ├─ only user-vms/ changed  → member mode: build, start the new VMs, leave others alone
       ├─ hosts/ modules/ lib/    → fabric mode: rebuild the whole server
       └─ docs, README, site      → skip: nothing to rebuild
4. nixos-rebuild switch: the server becomes what main describes
5. If anything the edge cares about changed, git-sync nudges the edge to update too
```

Nobody runs `nixos-rebuild` by hand on the server. If you feel you need to,
something is missing from git. Add it there instead.

## When a deploy fails

git-sync keeps notes in `/var/lib/mothership/git-sync/`:

| File | Means |
|---|---|
| `last-applied` | the last commit that deployed cleanly. The next run compares against it |
| `last-success` | the last commit that actually rebuilt the server |
| `last-failure` | the last commit that failed, and when. Removed once a deploy succeeds |
| `last-rebuild.log` | output of the last `nixos-rebuild` (feeds the failure comment) |

A failed deploy leaves `last-applied` untouched, so the next run tries again.

That retry is new ([#90](https://github.com/tinkerhub0/mothership/pull/90)).
Before it, one failure looked like "nothing to do" forever. A stray
invisible character in one member file kept the server 63 commits behind
for 2.5 months, and nobody noticed. CI now blocks that kind of file before
it can merge.

## You'll hear about it on GitHub

You don't have to watch the server. After each deploy, git-sync reports
back on GitHub (`scripts/deploy-notify`):

| Where | Success | Failure |
|---|---|---|
| the merged commit | green `deploy/mothership` check | red `deploy/mothership` check |
| your PR | ✅ comment. Member PRs get your `ssh` line and URLs | ❌ comment @-mentioning you, with the last 40 lines of the error |
| issue "deploy broken on mothership" | closed with "recovered at …" | opened (label `deploy-broken`), or updated |

**No spam:** git-sync retries a failing commit every 2 minutes, but each
failure is announced once, and each PR hears about a breakage once. The
state lives in `notified-failure` and `notified-failure-prs`, and both
clear on the next success.

Notifications never decide a deploy. If GitHub is down or the token is
missing, the deploy goes ahead and the log says `notify: …`.

**Setup (admins, once):** create a fine-grained token for
`tinkerhub0/mothership` with *Commit statuses*, *Pull requests* and *Issues*
set to read and write, and *Contents* read-only. Then:

```bash
scripts/install-github-token      # paste it, ctrl-d. it goes over ssh stdin, never into git
```

## Watching a deploy

```bash
ssh mothership@tharavad.xyz
journalctl -fu mothership-git-sync        # live log
sudo cat /var/lib/mothership/git-sync/last-failure
```

## How long it takes (2026-10-29)

Building the entire server config from a fresh clone takes 5 min 23 s: 873
build steps and a 6.1 GB system. Adding one member rebuilds much less.
