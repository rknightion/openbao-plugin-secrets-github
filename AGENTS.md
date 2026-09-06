# openbao-plugin-secrets-github

OpenBao secrets engine that mints short-lived, permission-scoped GitHub App installation tokens.
Fork of `martinbaillie/vault-plugin-secrets-github` ported to the OpenBao SDK. Ships as an OCI image
(`ghcr.io/rknightion/openbao-plugin-secrets-github`) plus release binaries.

## Scope: the plugin, not the lab that runs it

The test is whether the change touches a file in this repo. If it does not, it belongs in
`~/repos/chat-personal/camden/openbao/`, which owns camden's OpenBao deployment - server config, ACL
policies, tailnet identity, per-repo JWT roles, CI-consumer onboarding. Do not open a task here for
it. In scope here: the Go engine, its tests, the CI and release workflows, `docs/`, dependency
bumps.

The two seams where a change here does reach camden are below. Read them before renaming a path or
cutting a release.

## Engine

`main.go` is a thin plugin-serve shim; `github/` is the whole engine, one `path_<name>.go` per API
path with a sibling `_test.go`.

- **A path does not exist until it is listed in `Factory()`** in `backend.go`; the `Paths` slice
  there is the registry.
- `PathsSpecial.Unauthenticated` is `info` + `metrics` only. Think before adding to it.
- Every path's literal is a `pathPattern*` const in its own file, never an inline string.
- Wrap new operations in `withFieldValidator` (`path.go`), or the path silently accepts unknown
  fields instead of returning a 400.
- `projectName`, `projectDocs` (`path_info.go`) and `projectVersion` (`backend.go`) are `-X`
  injections made only by `publish.yml`, so they are empty in `go build`, in tests and in any dev
  binary: `/info` returning blanks locally is correct. v0.1.0 shipped without them, which meant an
  empty `User-Agent` on every GitHub call and a WAF 403 on all of them while the mount, config and
  mint plumbing worked. `go build -X` on a symbol path that does not resolve is silently ignored, so
  verify `/info` on a real release.

## Test idiom - match it

Table-driven subtests, `t.Parallel()` on the outer test and on each subtest, `gotest.tools/assert`
with `is "gotest.tools/assert/cmp"`. `testBackend(t, failVerbs...)` returns a backend over
`logical.InmemStorage` and injects storage failures (`failVerbRead|Put|List|Delete`); that is how
the error paths are covered, not with mocks. Sentinel errors are the package's own `Error` string
type (`const errFoo = Error("...")`), compared by value.

`integration_test.go` is behind `//go:build integration` and needs a live OpenBao plus real GitHub
App credentials, so it never runs in CI. `just lint` compiles it under `go vet -tags integration`
without executing it.

## Task interface

`just check` is the gate, and is exactly what CI's `test` job enforces - including the
`hashicorp/vault` import check and `govulncheck`, so nothing passes locally and then fails in CI.

Run `just` with stdin from `/dev/null`, so a `[confirm]` recipe fails fast instead of blocking a
non-interactive session.

`just audit` runs govulncheck in the module's own Go toolchain. Do not substitute
`golang/govulncheck-action`: it sets `go-version: stable` alongside `go-version-file`, so it scans a
different stdlib than releases ship. A newly published stdlib CVE can therefore fail `just audit`
with no source change.

## Two seams into camden

**Path names are load-bearing in an ACL policy outside this repo.** The bare `token` path
(`pathPatternToken`, arbitrary `installation_id` and `permissions` in the request body, no stored
permission set) is denied on camden purely because it does not match that policy's
`github-app-broker/token/*` prefix rule, while `token/<set>` does. Renaming either path, or adding
one that collides with that prefix, silently reopens an unrestricted mint. Say so in the PR if you
touch them.

**Releases are hash-pinned.** `go build` stamps the commit SHA into the binary, so the hash is a
function of commit plus build inputs, not of source alone, and camden pins that hash with
`plugin_download_behavior = "fail"` - a mismatch stops OpenBao starting. Never re-run publish for a
version camden has pinned; cut a new one. The `go` directive in `go.mod` carries a full patch
version and is what `setup-go` reads, so it selects the stdlib every release ships: bumping it is a
deliberate hash change needing the full re-pin procedure in
`~/repos/chat-personal/camden/openbao/runbooks/UPDATE-ROLLBACK.md`, not a quiet patch.

## `gh` resolves to the WRONG repo here - always pass `--repo`

Two remotes, `origin` to `rknightion/openbao-plugin-secrets-github` and `upstream` to
`martinbaillie/vault-plugin-secrets-github`, and no default is set, so a bare `gh issue list`
answers about martinbaillie's tracker - and it looks like a perfectly normal result.

```bash
gh issue list --repo rknightion/openbao-plugin-secrets-github --state all --limit 1000
```

`gh repo view` takes the repo as a positional argument, not `-R`. GitHub reports this repo as
`isFork=false` despite the lineage.

## Task tracking

`backlog/` is the source of truth for open work; new work is `obg-NNNN`. Read the **Agent fan-out
protocol (canonical)** doc before designing a wave, and the **Wave operating model** doc for this
project's own rules.

- **`backlog/` is committed to a PUBLIC repo, so no real identifiers in tasks or docs.** No email
  addresses, handles, App IDs, installation IDs, private-key or token material, tailnet addresses,
  JWT role names or ACL policy bodies - write the shape, not the instance (`<owner>/<repo>`, "the
  broker's permission set"). Aggregate counts, timings and structural findings are fine. A tracker
  feels private, which is exactly why this breaks by accident, and this repo is a credential broker.
  One deliberate exception: `camden`, the deployment host, is named openly - it is a Tailscale
  hostname on a private tailnet, already throughout this repo's history, and pseudonymising it would
  make the camden seams unreadable. Not licence for other host names.
- Never `--notes` or `--plan` bare. They silently replace the whole section, destroying another
  session's writes, and exit 0. Use `--append-notes` and `--append-plan`; a global `PreToolUse` hook
  denies the bare forms rather than trusting anyone to remember.
- Finalize in one call, so an interrupted run cannot leave finished work looking unfinished:
  `backlog task edit obg-0007 --check-ac 1 --check-ac 2 -s Done`.
- Section boundaries in task, draft, doc, decision and milestone markdown are HTML-comment markers.
  Break one by hand-editing and the section is silently dropped at exit 0 - still in the file,
  invisible to the CLI, until the next write destroys it for real. `backlog doctor` only repairs
  duplicate task IDs. `backlog/config.yml` is the one backlog file edited by hand, because
  list-valued keys cannot be set through `backlog config set`.
- Never let two sessions edit the same task. The concurrency fix covers the edit funnel but not
  reorder, draft saves, the TUI edit path, `doc update` or decision updates.
- `Parked` is a real status, not a synonym for To Do: attempted, blocked, and left with a concrete
  resume boundary. Flattening it loses the most valuable thing a long autonomous run produces.
- Do not build on decisions, and do not use the MCP surface. Decisions are half-built upstream - no
  `edit`, `view` or `update`, no supersede mechanism, no validation - so durable reference goes in
  docs and tasks stay the unit. MCP is frozen upstream and costs an order of magnitude more
  permanent context than the CLI.
- The GitHub tracker stays enabled so external contributors can file, this being a public fork with
  its own users; anything arriving that way becomes an `obg-NNNN` task. Every issue this project
  filed has been deleted and the inherited upstream numbers were rewritten to point here, so an
  issue link in `CHANGELOG.md` or a commit message answers 410 or 404 by design - do not "repair"
  those references. `#21` is Renovate's dependency dashboard, recreated on every run, a bot artefact
  and deliberately not a task. The *Closed GitHub issues* doc and
  `~/repos/chat-personal/camden/openbao/archive/github-issues/` are the records of what was deleted.

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
