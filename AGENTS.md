# openbao-plugin-secrets-github

OpenBao secrets engine that mints short-lived, permission-scoped GitHub App installation tokens.
Fork of `martinbaillie/vault-plugin-secrets-github` ported to the OpenBao SDK. Ships as an OCI image
(`ghcr.io/rknightion/openbao-plugin-secrets-github`) plus release binaries.

## Scope: this repo is the plugin, not the lab that runs it

**The test: would this change a file in this repo?** If no, it belongs in
`~/repos/chat-personal/camden/openbao/` — that folder owns camden's OpenBao deployment (server
config, ACL policies, tailnet identity, per-repo JWT roles, CI-consumer onboarding) and is where its
history and decisions live. Do not open a task here for it.

This is a correction, not a preconception. Issues #22 (tailnet identity), #23 (the OIDC/CI rollout)
and #26 (splitting the `admin` ACL policy) were all filed on this tracker and none of them touched a
file here. All three were **deleted 2026-08-11** after being archived verbatim to
`chat-personal/camden/openbao/archive/github-issues/`; there is no copy on GitHub any more. The
CHANGELOG entry for `f2c66f0` still links to the deleted #23.

In scope here: the Go engine, its tests, the CI/release workflows, `docs/`, dependency bumps.

The genuine seams, where a change here does have consequences on camden, are the two subsections at
the bottom — read them before changing path names or cutting a release.

## Layout

`main.go` is a thin plugin-serve shim; `github/` is the entire engine. One `path_<name>.go` per API
path with a sibling `_test.go` — `config`, `token`, `token_permission_set`, `permission_set`,
`installations`, `info`, `metrics` — plus `client.go` (GitHub API), `backend.go` (wiring),
`revocation.go`, `config.go`.

**A path does not exist until it is listed in `Factory()`** in `backend.go`; the `Paths` slice there
is the registry. `PathsSpecial.Unauthenticated` is `info` + `metrics` only — think before adding to
it. Every path's literal is a `pathPattern*` const in its own file, never an inline string.

## Gate

```bash
go build ./... && go test -race ./... && go vet ./...
```

Two more checks exist only in `ci.yml` and will fail a PR that passes locally:

- **no `hashicorp/vault` imports** — `grep -rn "hashicorp/vault" --include='*.go' .` must be empty.
  The port to the OpenBao SDK is the point of the fork; a transitive re-introduction is a regression.
- **`govulncheck ./...`**, run inside the job's own `setup-go` environment. Deliberately *not*
  `golang/govulncheck-action`: that action passes `go-version: stable` alongside `go-version-file`,
  and setup-go ignores the file whenever `go-version` is set, so it would scan a toolchain the module
  does not ship. `ci-success` depends on it, which means **a newly published stdlib CVE can turn PRs
  red with no code change** — a red `vuln` job is not necessarily anything the PR did.

`integration_test.go` is behind `//go:build integration` and needs a live OpenBao plus real GitHub App
credentials, so it does not run in CI. `go vet -tags integration ./...` compiles it without running it
— do that after touching anything it references, or it rots unnoticed.

## Test idiom — match it

Table-driven subtests, `t.Parallel()` on both the outer test and each subtest, `gotest.tools/assert`
with `is "gotest.tools/assert/cmp"`. `testBackend(t, failVerbs...)` returns a backend over
`logical.InmemStorage` and injects storage failures (`failVerbRead|Put|List|Delete`) — that is how the
error paths are covered, not with mocks. Sentinel errors are the package's own `Error` string type
(`const errFoo = Error("...")`), compared by value.

Wrap new operations in `withFieldValidator` (`path.go`) or the path silently accepts unknown fields
instead of returning a 400.

## `-X` linker injections: empty in every local build

`projectName`, `projectDocs` (`path_info.go`) and `projectVersion` (`backend.go`) are injected only by
`publish.yml`. They are empty strings in `go build`, in tests, and in any dev binary — so `/info`
returning blanks locally is correct, not a bug.

**v0.1.0 was permanently broken by exactly this.** It shipped without the injections, so
`projectName` was empty, every GitHub API call went out with an empty `User-Agent`, and GitHub's WAF
403'd all of them (`client.go` sets that header in three places). All the mount/config/mint plumbing
worked; only outbound calls failed. `go build -X` on a symbol path that does not resolve is **silently
ignored** — there is no build error to catch this, so verify `/info` on a real release.

## Two seams into camden — check before you change them

**Path names are load-bearing in an ACL policy off this repo.** The bare `token` path
(`pathPatternToken = "token"`, arbitrary `installation_id`/`permissions` in the request body, no
stored permission set) is denied on camden purely because it does *not* match that policy's
`github-app-broker/token/*` prefix rule, while `token/<set>` does. Renaming either path, or adding a
path that collides with that prefix, silently reopens an unrestricted mint. Say so in the PR if you
touch them.

**Releases are hash-pinned.** `go build` stamps the commit SHA into the binary, so the binary hash is
a function of **commit + build inputs, not source alone**, and camden pins that hash with
`plugin_download_behavior = "fail"` — a mismatch stops OpenBao starting. Never re-run publish for a
version camden has pinned; cut a new one. The `go` directive in `go.mod` carries a **full patch
version** and is what `setup-go` reads, so it selects the stdlib every release ships — bumping it is a
deliberate hash change needing the full re-pin procedure in
`chat-personal/camden/openbao/runbooks/UPDATE-ROLLBACK.md`, not a quiet patch.

## `gh` resolves to the WRONG repo here — always pass `--repo`

This checkout has two remotes: `origin` → `rknightion/openbao-plugin-secrets-github` and `upstream` →
`martinbaillie/vault-plugin-secrets-github`. No default is set, so a bare `gh issue list` answers
about **martinbaillie's** tracker — five open issues that are nothing to do with this fork — and it
looks like a perfectly normal result. Every `gh` call names the repo:

```bash
gh issue list --repo rknightion/openbao-plugin-secrets-github --state all --limit 1000
```

Note `gh repo view` takes the repo as a positional argument, not `-R`. GitHub reports this repo as
`isFork=false` despite the lineage, so the `rknightion` push-straight-to-`main` rule applies.

## Task tracking — Backlog.md

Open work lives in `backlog/`, driven **only** through the `backlog` CLI. `backlog task list --plain`
is the queue; `backlog doc list --plain` lists the durable docs. Backlog.md was adopted on
**2026-08-14**. New work is `obg-NNNN`.

**The GitHub tracker stays open, but every issue this project filed has been deleted.** `#1` and
`#25` went on **2026-08-14** (no dump file — deliberate), `#22`/`#23`/`#26` on 2026-08-11. So every
`#NNN` in a commit message or in `CHANGELOG.md` now **404s, by design** — do not "repair" those
references. The *Closed GitHub issues* doc is the record for the first two; the camden archive at
`chat-personal/camden/openbao/archive/github-issues/` is the record for the other three.

`#21` is all that is left: Renovate's dependency dashboard, recreated on every run, a bot artefact
and deliberately not a task. The tracker stays enabled so external contributors can file — this is a
public repo and a fork of a project with its own users. Anything arriving that way becomes an
`obg-NNNN` task; the board, not the issue, is where it is worked.

Read the **Agent fan-out protocol (canonical)** doc before designing a wave, and the **Wave operating
model** doc for this project's own rules. Docs load on demand via `backlog doc view <id> --plain`, so
neither costs context until something reads it. The protocol is harness-neutral — it routes lanes by
**role**, and its Appendix A (Codex) or Appendix B (Claude Code) resolves a role into a concrete
model and reasoning depth. Name the harness in the run contract and resolve every lane from that
profile; the two harnesses differ in kind, not just in model names.

- **`backlog/` is committed to a PUBLIC repo, so no real identifiers in tasks or docs.** No email
  addresses, handles, App IDs, installation IDs, private-key or token material, tailnet addresses,
  JWT role names or ACL policy bodies — write the shape, not the instance (`<owner>/<repo>`, "the
  broker's permission set"). Aggregate counts, timings and structural findings are fine. A tracker
  *feels* private, which is exactly why this breaks by accident, and this repo is a credential
  broker, so the blast radius is higher than most.
  **One deliberate exception: `camden`, the deployment host, is named openly.** It is a Tailscale
  hostname on a private tailnet, it is already committed 8 times in this repo's own history, and
  pseudonymising it now would buy nothing while making the camden seams unreadable. Do not treat
  that as licence for other host names.
- **Never use `--notes` or `--plan` bare** — they *silently replace* the whole section, destroying
  another session's writes with no warning and exit 0. Use `--append-notes` and `--append-plan`.
  `.claude/hooks/backlog-guard.py` denies the bare forms rather than trusting anyone to remember.
- **Finalize in one call**, so an interrupted run cannot leave finished work looking unfinished:
  `backlog task edit obg-0007 --check-ac 1 --check-ac 2 -s Done`. Checking criteria at one step and
  setting status several steps later leaves the task inconsistent if anything interrupts between.
- **Never hand-edit task, draft, doc, decision or milestone markdown.** Section boundaries are
  HTML-comment markers; break one and the section is *silently dropped* at exit 0 — the data is still
  in the file but invisible, until the next write destroys it for real. There is no repair command;
  `backlog doctor` only fixes duplicate task IDs. `backlog/config.yml` is the one file edited by hand,
  because list-valued keys cannot be set through `backlog config set`.
- **Never let two agents edit the same task.** The v1.50 concurrency fix covers the edit funnel but
  *not* reorder, draft saves, the TUI edit path, `doc update` or decision updates.
- **`Parked` is a real status**, not a synonym for To Do: attempted, blocked, and left with a concrete
  resume boundary. Flattening it loses the most valuable thing a long autonomous run produces.
- **Do not build on decisions, and do not use the MCP surface.** Decisions are half-built upstream —
  no `edit`, `view` or `update`, no supersede mechanism, no validation — so durable reference goes in
  **docs** and tasks stay the unit. MCP is frozen upstream and costs 10-50k tokens of permanent
  context against 1-2k for the CLI.

<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.50.1 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**For every user request in this project, run `backlog instructions overview` before answering or taking action.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->
