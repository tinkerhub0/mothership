# AGENTS.md

read `why-this-exist`, then `docs/`. git is the IdP. nix compiles. docs explain, nix decides.

- join: one file `user-vms/<you>.nix` from `template.nix`
- name unique + not reserved · `^[a-z][a-z0-9-]{1,15}$` · real ssh pubkey
- same name or same github as an existing member → reject
- do not invent authentik/k8s/terraform
- secrets in git only sops-encrypted as `secrets/*.sops.*` (recipients = the people in `lib/adminKeys.nix`, not machine keys; rules in `.sops.yaml`). never plaintext.
- plain UTF-8, LF, no BOM in `.nix` files (CI rejects them)
- small PRs · no drive-by rewrites
- behaviour change → update the matching `docs/*.md` in the same PR. docs are for newcomers: plain words, sentence case, explain a term or link `docs/glossary.md`. every page opens with a "Source of truth" line
- numbers in docs carry a date; re-measure, don't invent
- after merge, mothership git-sync provisions the guest

| path | role |
|---|---|
| `user-vms/` | members |
| `hosts/mothership` `modules/` | host fabric |
| `hosts/edge` `sites/` | front door / brochure |
| `hosts/tharavadmathil` `lib/opnsense.nix` | house firewall (opnsense, as data) · `scripts/opnsense-apply` plans by default, `--apply` writes · `scripts/opnsense-backup` |
| `secrets/` | sops-encrypted only |

if a doc and the repo disagree, trust the repo and fix the doc.
