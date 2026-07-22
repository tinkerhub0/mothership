# mothership — the main doc

```
                    ┌─────────────────────────────────────┐
                    │            tinkerhub0               │
                    │         one box. one repo.          │
                    │      git is the identity provider   │
                    └─────────────────────────────────────┘
```

This is not a homelab writeup. This is a **pubnix control plane** that pretends
to be boring infrastructure so the interesting parts can stay sharp.

If you wanted Proxmox + a wiki page of `useradd` incantations, the exit is
behind you. Nest did that. Nest is suspended. We are not doing Nest again.

---

## 0x00 — threat model (the real one)

| adversary | you lose when |
|---|---|
| **toil** | you SSH in to provision a human |
| **mutable authz** | the source of truth is a database you can't `git blame` |
| **weekend heroics** | one incident burns momentum and the rewrite-to-Proxmox proposal lands |
| **kernel escape** | member microVM → host (accepted residual; why not containers) |

Everything else is secondary. Judge every PR by the **admin-toil number**:
how many times a human has to touch the mothership per member lifecycle.
Target: **one PR review**. Anything that adds a manual step is a regression
dressed up as elegance.

---

## 0x01 — trust chain (locked, not "for now")

```
GitHub account
  → opens PR adding user-vms/<name>.nix
  → CODEOWNERS blocks self-merge
  → merge lands on main
  → Nix eval is the only compiler of reality
       ├─ authorized_keys inside the member VM
       ├─ Headscale ACL grant
       ├─ ZFS dataset + refquota
       ├─ MagicDNS / extra_records
       └─ nftables egress class
```

**One identity. One artifact. One audit log.**

```
git log user-vms/alvin.nix
```

answers *who has access*, *who granted it*, *when*, and *why* — in one
object. Authentik gives you authentication and parks authorization in
mutable database state that is not versioned and does not explain itself.
That is the whole argument. **Git is the IdP for everything git can cover.
Full stop. Not a temporary Authentik substitute.**

### Where git cannot reach

Web-service login. Mattermost / Vaultwarden / deck services cannot auth
against a git repo. Those keep **local accounts** until Dex bridges GitHub.
When that becomes annoying, Dex slots in without disturbing the trust chain
above. Do not invent a second IdP in a panic.

---

## 0x02 — topology

```
                         internet / LAN
                              │
                              ▼
                    ┌──────────────────┐
                    │    mothership    │  bare metal · NixOS · single disk
                    │  ESP + ZFS tank  │  hostId frozen · srvos base
                    └────────┬─────────┘
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
      modules/base      modules/mesh      modules/deck
      modules/tools     Headscale         Mattermost…
                        Tailscale         (shared hall)
                        100.64.0.1
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
         member microVMs   mesh peers    future: comin
         (user-vms/*)      MagicDNS      git→rebuild loop
```

| layer | path | owns | does not own |
|---|---|---|---|
| **host** | `hosts/mothership/` | this machine: disks, hostname, keys, which modules | service logic |
| **base** | `modules/base.nix` | flakes, gc, ssh hardening, boot gen limit | apps |
| **tools** | `modules/tools.nix` | operator CLI surface | shared services |
| **mesh** | `modules/mesh/` | Headscale + host tailscaled + serve | member VMs |
| **deck** | `modules/deck/` | shared hub services (chat, vault, …) | IdP for mesh |
| **members** | `user-vms/` + `lib/mkMemberVM` | *(later)* one file → five derived outputs | deck auth |

**Rule:** if you hand-edit a derived output, the generator has a hole.
Fix the generator. Do not patch the artifact.

---

## 0x03 — mesh plane

Headscale is the coordination server. The host is also a node.

| constant | value | why |
|---|---|---|
| mothership CGNAT | `100.64.0.1` | sequential alloc · register this node **first** |
| prefix | `100.64.0.0/10` | Tailscale-legal space · do not get cute |
| MagicDNS base | `mesh.tinkerhub` | `<host>.mesh.tinkerhub` |
| canonical login | `http://100.64.0.1:8080` | IP avoids base_domain collision with MagicDNS |
| serve front | `https://mothership.mesh.tinkerhub` | tailscale serve → localhost:8080 |
| friendly A | `headscale.mesh.tinkerhub → 100.64.0.1` | extra_records |

**Chicken-egg is real.** Bootstrap the host with
`--login-server=http://127.0.0.1:8080`. After it owns `.1`, everyone else
uses the static IP. Serve is the HTTPS face for nodes already on the mesh.

Firewall: Headscale HTTP is **not** a LAN gift. `tailscale0` + loopback.
If you open 8080 on the uplink "just for a minute," you have failed a quiz
you did not know you were taking.

---

## 0x04 — storage

Single disk. ESP + ZFS root. Pool name: **`tank`**.

```
disk/by-id/<truth>
└─ GPT
   ├─ ESP 1G → /boot
   └─ zfs → tank
        ├─ tank/root  → /
        ├─ tank/nix   → /nix
        ├─ tank/var   → /var
        └─ tank/users → parent only
             └─ tank/users/<name>  (+ refquota)  ← mkMemberVM later
```

Disk resolution order: explicit `mothership.diskDevice` → first whole disk
in `facter.json` → eval fallback `/dev/sda` (warning; **do not format** on
fallback). Hardware inventory is a **frozen scan**, not telemetry:

```
./scripts/capture-hardware.sh   # ON THE BOX, once, commit the JSON
```

`hostId` is frozen at first pool create. Change it later and you get to
learn about import flags the hard way.

---

## 0x05 — failure modes you already accepted

| failure | mitigation | residual? |
|---|---|---|
| malformed member file | `nix flake check` on PR | no |
| member asks for 64G | tier enum | no |
| two members claim `blog` | hostname uniqueness assert | no |
| member PR touches `modules/` | CODEOWNERS | no |
| bad merge evals, bricks host | previous gens · console/iDRAC · comin rollback (later) | **yes — row that matters** |
| member fills disk | ZFS refquota | contained |
| kernel escape from member VM | nothing — by design of the threat model | **yes** |
| Headscale dies | no new joins; existing peer links limp on | yes |

Row "evals fine, host is toast": serial/iDRAC **before** you need it.
Keep generations. Do not discover the BMC on a Saturday.

Emergency revocation (active incident):

```
headscale nodes delete -i <id>   # mesh access gone now
microvm -s users-<name>          # VM stopped
# then commit within the hour — out-of-band without reconvergence is how
# you re-enter the failure mode this redesign exists to escape
```

---

## 0x06 — what we are actually building

1. **The admin-toil number.** Near zero or this dies in eight months when
   someone proposes Proxmox because "the Nix thing was too complicated."
   They will be right if you let toil creep.

2. **Curriculum as structure.** To get a machine you open a PR, pass review,
   read a diff. Git, code review, declarative config, mesh networking — by
   wanting a shell. Not a side effect. The reason PR provisioning beats a
   signup form.

3. **The artifact.** A forkable per-member microVM pubnix on NixOS with mesh
   identity. Nest is Proxmox + shared unix. wolfgirl is a shared box. clan
   is a framework without this use case. If this repo runs for someone else
   cold, that is the contribution. It costs almost nothing extra — you were
   going to write it declaratively anyway.

**What loses:** boredom, or one incident that burns a weekend. Same
mitigation: keep the toil number near zero.

---

## 0x07 — phase map (honest)

| phase | state | payload |
|---|---|---|
| **1** | **you are here** | host · disko · ZFS · srvos · mesh · deck stub |
| 2 | next | sops · comin (git → rebuild without a keyboard) |
| 3 | later | harden ACL · DERP policy · maybe embedded DERP |
| 4 | later | `lib/mkMemberVM` · first `user-vms/*` · microvm.nix |
| 5 | later | GH Actions asserts · CODEOWNERS · key-refresh Action |
| 6 | later | ZFS snapshots · egress nftables · deck services for real |

Do not skip to microVMs because the mesh looks shiny. A host that does not
reboot clean is not a control plane; it is a science fair.

---

## 0x08 — repo grammar

```
flake.nix                 # the only entry the machine cares about
hosts/mothership/         # identity of this metal
modules/{base,tools}      # policy + operator surface
modules/mesh/             # control plane + data plane client
modules/deck/             # shared services (not member machines)
user-vms/                 # (later) the only files members touch
lib/mkMemberVM.nix        # (later) one input → five outputs
docs/                     # you are reading the map
scripts/                  # one-shot ops that are not worth a module yet
```

Voice of the tree: short comments, no corporate README theater, assumptions
stated as invariants. If a comment apologizes, delete the feature or the
comment.

---

## 0xFF — coda

One box. One repo. One trust chain.

Git decides who exists. Nix decides what runs. ZFS decides who can fill a
disk. Headscale decides who can find whom. You decide whether the toil
number stays near zero.

There is no second control plane. There is no "we'll put Authentik in front
for now." There is no snowflake SSH session that is allowed to diverge from
`main` for more than an hour.

**if you know you know.**
