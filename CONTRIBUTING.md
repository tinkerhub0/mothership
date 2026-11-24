# Contributing

Thanks for being here. You don't need to know Nix to help.

## Easy ways in

- **Get a machine.** Your first PR can be your member file. See [docs/join.md](docs/join.md).
- **Fix a doc.** If something confused you, it'll confuse the next person too. Small fixes are welcome.
- **Ask.** Open an issue titled "I don't understand X". That's a real contribution: it shows us where the docs fall short.
- **Run a drill.** Pick one from [docs/drills.md](docs/drills.md), measure, and add your row.

## Before you open a PR

```bash
nix flake check     # the same thing CI runs
```

No Nix installed? Open the PR anyway. CI runs the check for you.

- Keep PRs small: one idea each.
- Save `.nix` files as plain UTF-8 with LF line endings, and no BOM. CI rejects anything else.
- Changed how something works? Update the matching page in `docs/` in the same PR.
- Never commit secrets in plain text. Encrypted `secrets/*.sops.*` only (ask an admin).

## Review

A human reviews every PR. Member files get checked for a valid name, a
real SSH key and one seat per person. Infrastructure changes get a slower
look, because they rebuild the server for everyone.

## Be kind

Everyone here is learning, including the people who wrote this. Explain
things the way you'd want them explained to you.
