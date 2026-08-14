---
id: doc-0003
title: Closed GitHub issues (pre-Backlog history index)
type: other
created_date: '2026-08-14 16:09'
updated_date: '2026-08-14 16:30'
---
> **Historical index of work tracked on GitHub Issues before this repo moved to Backlog.md on
> 2026-08-14.** **The issues were deleted from GitHub on 2026-08-14 and were not archived to a dump
> file** — that was a deliberate call, so `gh issue view <N>` now 404s and **this document is the
> record**. Deletion is irreversible; nothing else holds their bodies.
>
> What was in them is not lost, because almost all of it had already been written down where it
> belongs: the engine-side traps are in `AGENTS.md`, the plugin's config surface is in `docs/`, and
> the camden deployment traps are in `~/repos/chat-personal/camden/openbao/CLAUDE.md` and
> `runbooks/UPDATE-ROLLBACK.md`. The per-issue notes below carry the rest.
>
> One thing the deletion positively improved: the closing comment on `#1` published the GitHub App ID
> and Installation ID in a public repo. Those identifiers appear nowhere in this checkout, and they
> should not be reintroduced here — see the identifier rule in `AGENTS.md`.

**Why these were not imported as tasks.** Backlog IDs follow creation order, so an imported task
could never carry the number the history already cites: `#23` is referenced from the `CHANGELOG.md`
entry for `f2c66f0`, and 21 commits across this history cite one of these five numbers (44 cite some
issue number, the rest being PR references). Keeping GitHub numbers as the only ID space over closed
work is what keeps those references readable. `Done` rows would also compete with the board's only
real signal — what is left. **Cite closed work as `#NNN`; cite new work as `obg-NNNN`.** Two ID
spaces, no overlap.

**Every `#NNN` in a commit message now 404s.** That is expected, not rot to repair. Do not rewrite
commit messages or the changelog to remove them — release-please owns `CHANGELOG.md`, and the
references still point at something real, which is this table.

**The commits column is every commit whose message cites the issue**, newest first, capped at three.
It is a lead, not a verdict: a commit may cite an issue it only touches, and a squashed or un-citing
commit leaves the column empty.

---

## Closed issues, deleted 2026-08-14

| # | Title | Closed | Citing commits |
|---|---|---|---|
| #25 | v0.1.2 hardening | 2026-08-08 | 1 — `8f3ab17` |
| #1 | Port vault-plugin-secrets-github to the OpenBao SDK and ship as an OCI image | 2026-08-07 | 11 — `515a239`, `d51b756`, `4751660` |

### #1 — the port

Forked `martinbaillie/vault-plugin-secrets-github` (Apache-2.0, HEAD `0ee76ab`) and swapped
`hashicorp/vault/sdk` → `openbao/openbao/sdk/v2` and `hashicorp/vault/api` → `openbao/openbao/api/v2`
across 4 import paths and 37 sites. Mechanical: OpenBao's `api/v2` keeps the identical
`PluginAPIClientMeta` / `VaultPluginTLSProvider` symbols, so `main.go` needed no logic change.
Delivered as a `FROM scratch` OCI image with the binary at the image root, registered through
OpenBao 2.5+ declarative plugins and pinned by binary sha256.

Two facts from it that are still live and are **not** obvious from the code:

- **`api/v2` is pinned to v2.6.0 while `sdk/v2` is at v2.6.2, deliberately.** There is no
  `api/v2.6.1` tag for that submodule — pinning it fails with `unknown revision api/v2.6.1`. The
  asymmetry in `go.mod` is correct, not a stale pin someone forgot to bump.
- **v0.1.0 is permanently broken and must never be pinned.** Root cause is in `AGENTS.md`; the part
  worth keeping here is *how* it happened — a task deleted upstream's `.goreleaser.yml` as "dead
  config" without checking what it provided, and what it provided was the `-X` ldflag injections.

### #25 — v0.1.2 hardening

Four deferred items from the review that produced the v0.1.1 `publish.yml` hardening, all four
landed. The three whose reasoning outlived the issue:

- **The `go` directive selects the shipped stdlib.** Bumping 1.25.0 → 1.26.5 took govulncheck from
  22 reachable stdlib vulnerabilities to zero. The mechanism: `actions/setup-go` parses
  `go-version-file: go.mod` with `/^go (\d+(\.\d+)*)/m`, taking the **full patch version** out of
  that one line. No `toolchain` line is needed, and one would not survive `go mod tidy` anyway.
- **`govulncheck` runs in CI's own `setup-go` environment on purpose**, not via
  `golang/govulncheck-action`. The reasoning is in `AGENTS.md`; the consequence to remember is that
  `ci-success` depends on it, so a newly published CVE reddens PRs with no code change.
- **`GITHUB_TOKEN` is confirmed sufficient for the release asset upload**, measured rather than
  assumed — the v0.1.2 publish run's upload step succeeded under the ephemeral token, and
  `RELEASE_PLEASE_TOKEN` is no longer referenced in any workflow here. The earlier failure that
  looked like a token-scope problem was specific to `softprops/action-gh-release`'s full-release
  PATCH call and reproduced under *both* tokens.

One correction the issue recorded against itself: the config field is **`exclude_repository_metadata`**,
not `hide_repository_metadata` as the issue body first said. Enabling it took a mint response from
~9.7 KB to **562 bytes**. The field is real in `github/` and documented in `docs/`.

## Deleted earlier — 2026-08-11

**#22, #23 and #26** were deleted on 2026-08-11, before this migration, after being archived verbatim
to `~/repos/chat-personal/camden/openbao/archive/github-issues/`. That archive is their record.

| # | Subject | Citations still in this history |
|---|---|---|
| #22 | tailnet identity | 2 commits |
| #23 | the OIDC/CI rollout | 8 commits, **and the `CHANGELOG.md` entry for `f2c66f0`** |
| #26 | splitting the `admin` ACL policy | 1 commit |

They went because none of them changed a file in this repo — they were camden deployment work filed
on the wrong tracker. That is the scope test `AGENTS.md` states, and these three are the concrete
instance behind it.

## Still open on GitHub, deliberately not a task

`#21 Dependency Dashboard` is authored by `rknightion-renovate[bot]` and is recreated on every
Renovate run. It is a bot artefact, not work, and it is the only issue left on the tracker.

The GitHub tracker stays enabled so external contributors can file — this is a public repo and a fork
of an upstream project that still has its own users. Anything arriving that way becomes an
`obg-NNNN` task; the board, not the issue, is where it gets worked.
