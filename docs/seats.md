# Keeping your seat

> **Source of truth:** `modules/microvms/activity.nix` · `scripts/member-activity` · `scripts/prune-inactive` · `hosts/mothership/default.nix`

The server is shared, and a parked VM frees RAM and CPU for someone who'll
use them. So seats nobody uses get released, slowly and in public.

## What counts as using it

Either of these resets the clock:

- **an SSH login**: `ssh you@you.tharavad.xyz`
- **real work inside your VM**: in any hour, more than 60 s of CPU or 2 MiB
  of network traffic. A website people visit counts. A cron job counts.

An idle VM measured 13–27 CPU-seconds and about 425 KiB per hour
(2026-10-29), from Tailscale keepalives and timers. So just being switched
on doesn't count.

The clock starts when your VM first runs. Time before that never counts.

## What happens when you don't

| Idle for | What happens |
|---|---|
| 7 days | you're @-mentioned on the **"inactive seats"** issue, with at least 3 days' notice |
| 10 days | a PR sets `enabled = false` in your file. After merge your VM stops, but your name, file and disk are kept |
| 30 days after parking | a PR deletes your file. **After merge your VM disk is gone** |

All three are **pull requests or comments a human reviews.** Nothing is
removed automatically.

## Coming back

- **Warned?** Log in once. That's it.
- **Parked?** Open a PR changing your file back to `enabled = true;`. Your
  disk is still there.
- **Deleted?** Sign up again like new. The old disk is gone.

## For admins

```bash
journalctl -u member-activity -u prune-inactive -n 50    # what it saw, what it decided
sudo cat /var/lib/mothership/activity/activity.json      # first_seen / last_ssh / last_vm
```

`mothership.microvms.activity.prune.enable = false` runs it in **dry-run**:
it decides and logs, but posts nothing. Seats in `prune.exempt` (house and
service seats) are never touched. The GitHub token is the deploy bot's,
and it needs **Contents: write** to open park/delete PRs.
