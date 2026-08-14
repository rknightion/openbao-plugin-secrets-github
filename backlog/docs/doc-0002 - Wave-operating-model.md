---
id: doc-0002
title: Wave operating model
type: guide
created_date: '2026-08-14 16:08'
updated_date: '2026-08-14 16:13'
---
This document carries **only what is true of openbao-plugin-secrets-github**. The campaign model
itself — run contract and run modes, the routing contract, authority and the thread pool, child lane
briefs, external-contract freezing, the blocker contract, the goal-file template, the run-end
protocol and the pre-flight checklist — is the *Agent fan-out protocol (canonical)* doc, and that
doc wins on any specific. Nothing here restates it. If a section below could be pasted into another
repo unchanged, it is in the wrong document.

That protocol is harness-neutral and names no model: it describes lanes by **role**, and its
Appendix A (Codex) or Appendix B (Claude Code) resolves a role into a concrete route. **Name the
harness in the run contract and resolve every lane's route from that harness's profile** — a lane
brief carrying a role name alone is not routed.

The working knowledge of the engine — layout, the `Factory()` registry, the test idiom, the gate,
the `-X` injections, the two camden seams — is in `AGENTS.md`, which is always loaded. This document
does not repeat it; it says what a *wave* has to do differently because of it.

Every rule here exists because something failed. The failure is kept with the rule; a rule without
its reason gets argued away by the next session.

---

## 1. Rules this project added

### Work lands on `main`, and the local branch is called `master`

No PR flow for this repo's own work: it is `rknightion`-owned and `isFork=false`, so lanes commit to
the shared checkout and the root agent pushes straight to `main`. A remote message saying the push
**bypassed** branch-protection rules is the expected mechanism here, not an incident — do not
surface it as a warning.

**The local branch is `master` and it tracks `origin/main`.** The names differ, and that breaks the
obvious commands in both directions.

**A bare `git push` is REFUSED here** — `push.default=simple` will not push when the local and remote
names differ, and it fails with advice about `git push origin HEAD` rather than an error that names
the cause. The working form is explicit:

```sh
git push origin master:main
```

Live-verified 2026-08-14: the migration commit's first bare `git push` was refused on exactly this,
after this section had been written claiming the tracking config made bare `git push` work. It does
not. In the other direction, a lane that hardcodes `git rebase origin/master` or `git reset --soft
origin/master` is writing against a ref that does not exist — the upstream comparison is always
`origin/main`. Never assume the two names match, in either direction.

### Anything that touches camden, or GitHub state, stays on the root agent

A dispatched lane cannot clear a permission block: a soft block clears only on the user's own message
naming the action, and a subagent's transcript has no user message in it. So a lane can be stopped on
work the root agent would have been allowed to do, with nothing able to unstick it, and re-dispatching
reads as bad faith rather than as a retry.

On this repo that means lanes do read-only investigation, Go edits, tests and inventory sweeps, while
the root agent keeps: SSH to camden, anything against the live OpenBao, dispatching
`broker-connectivity-probe.yml`, publishing to ghcr, `gh` mutations (issue/release/secret writes) and
destructive git. A lane that finds it needs one of these returns the request; it does not attempt it.

### A dispatch brief must forbid destructive git explicitly, not just `commit` and `push`

"Do not commit" does not cover `git checkout -- .`, `git restore`, `git stash`, `git clean`, `git
reset --hard`, or `git worktree remove`. Every one of those destroys another lane's uncommitted work
in a shared checkout, and this repo runs lanes in one checkout by design. Name them.

If the working tree carries changes that are not the wave's, stage explicit pathspecs — never
`git add -A` or `git commit -a`.

### A lane that hits a decision its brief does not cover stops and returns the question

One round-trip is cheaper than the rewrite. This matters more than usual here because the wrong
invented answer can be a security change: a path name, a `PathsSpecial.Unauthenticated` entry, or a
permission-set default is not a style choice, and a lane that picks one to keep moving has silently
made a decision about who can mint tokens.

### Specs and plans are never committed

`docs/superpowers/` is already gitignored (with `/site/` and the hub-injected doc assets). Confirm it
is still ignored before writing a plan there; do not un-ignore it to make plans sync — they are
mirrored out of band.

---

## 2. Recurring defects in this codebase

### A local gate passing is not the same question as CI passing

The gate in `AGENTS.md` (`go build && go test -race && go vet`) is not the full set. Two checks live
only in `ci.yml` and will redden a PR that is green locally: the `hashicorp/vault` import grep, and
`govulncheck ./...`. Both are in `ci-success.needs` (`[test, image, vuln]`). A wave that runs only the
local gate and declares itself finished has not tested the thing that gates.

The corollary runs the other way too: **a red `vuln` job is not necessarily anything the wave did.**
A newly published stdlib CVE turns PRs red with no code change. Read the finding before assigning it
to a lane.

### `.golangci.yml` is 8.8 KB of config that CI never runs

Nothing in `.github/workflows/` references golangci-lint — only the Nix devshell does
(`flake.nix:154`). The config is inherited from the upstream fork. So: lint findings are advisory
here, `golangci-lint run` is not an acceptance criterion unless a task says so explicitly, and a lane
told to "fix the lint" is being sent at an ungated surface. Do not put it in a definition of done.

### The `-X` injections fail silently, and did, permanently

`go build -ldflags -X` on a symbol path that does not resolve is ignored with **no build error**.
v0.1.0 shipped that way: `projectName` was empty, so every GitHub API call went out with an empty
`User-Agent` and GitHub's WAF 403'd all of them. Every unit test passed. The release is permanently
broken and cannot be fixed in place, because releases are hash-pinned.

For a wave, the consequence is a verification rule: **no task that touches `publish.yml`, the
injected symbols, or the module path may be closed on a green build.** It closes on `/info` returning
non-empty values from a real published artefact. `AGENTS.md` has the mechanism.

### Scope creep toward camden — three issues that touched no file here

#22, #23 and #26 were all filed on this tracker and none of them changed a file in this repo; all
three were deleted 2026-08-11 and archived to `chat-personal/camden/openbao/`. The test is in
`AGENTS.md` and it is cheap: would this change a file in this repo? A wave that generates deployment,
ACL-policy or CI-onboarding work has generated it for the wrong tracker — record it in the covering
note and put it where it belongs, do not open an `obg-NNNN` task for it.

### Two changes that look local and are not

Renaming a path, or adding one that collides with the `github-app-broker/token/*` prefix, reopens an
unrestricted mint through an ACL policy that lives outside this repo. Bumping the `go` directive in
`go.mod` changes the release binary's hash, which camden pins with `plugin_download_behavior =
"fail"`. Neither has a test that fails. Both are `AGENTS.md` seams; the wave-level rule is that a
task touching either **must** say so in its final summary, because the covering note is what triggers
the re-pin procedure on the other side.

---

## 3. Lane conventions

### The natural lane boundary is one `path_<name>.go` plus its `_test.go`

The engine parallelises cleanly along path files — `config`, `token`, `token_permission_set`,
`permission_set`, `installations`, `info`, `metrics` — because each owns its own `pathPattern*`
consts and its own tests. That is the unit to hand a lane.

The seam they all share is the `Paths` slice in `github/backend.go`. Freeze the pattern constants and
the field names in the goal file **before** fan-out, then let one wiring pass register everything. A
path that is not in `Factory()` does not exist, so a wave whose lanes each edited `backend.go` in
parallel produces conflicts on the one file that decides whether any of the work is reachable.

### Single-owner files — never two lanes, never concurrently

- `github/backend.go` — the registry and composition root. Wiring pass only.
- `go.mod` / `go.sum` — one lane, or the root agent. Note the `go` directive carries a full patch
  version and is a release-hash input; it is not a routine bump.
- `.github/workflows/*` — one lane per file at most, and `ci.yml` only ever one, since `ci-success`
  needs must stay consistent with the jobs.
- `CHANGELOG.md` and `.release-please-manifest.json` — **release-please owns both.** Hand-editing
  either desynchronises the manifest from the tags. No lane touches them, ever.
- `AGENTS.md` — root agent only. `CLAUDE.md` is a five-line `@AGENTS.md` import and must stay one;
  a lane that "helpfully" restores content into it recreates the drift the consolidation removed.
- `backlog/` markdown — CLI only, and the guard hook denies direct edits.

### Exclusive resources — one lane at a time, and only from the root agent

- **camden's live OpenBao and the real GitHub App.** `integration_test.go` is behind `//go:build
  integration` and needs both. It never runs in CI and it never runs in a lane. What a lane *can* do
  is `go vet -tags integration ./...`, which compiles it without running it — require that of any
  task touching what it references, or the file rots unnoticed.
- **`broker-connectivity-probe.yml`.** Manual dispatch, `concurrency: broker-connectivity-probe`,
  `cancel-in-progress: false` — it is already serialised by GitHub, and it exercises live tailnet and
  OpenBao auth. Root agent, one at a time.
- **Publishing to ghcr and cutting a release.** Never re-run `publish.yml` for a version camden has
  pinned; cut a new one.

### The escape hatch

A lane that needs a file it does not own does not take it and does not work around it. It stops,
returns the exact edit it needs, and the root agent applies it in the wiring pass. A boundary with no
escape hatch is a stop condition wearing a safety label — this one is the escape hatch, and a brief
that omits it is incomplete.

---

## 4. Run-end against this tracker

Task state is the record, not a report file. Landed work is `Done` with the SHA in its final summary;
attempted-and-blocked work is `Parked` with a concrete resume boundary, not `To Do`; untouched work is
self-evidently still `To Do`; work discovered mid-run is a new task labelled `needs-triage`. Finalize
in one call so an interruption cannot leave finished work looking unfinished.

The run's closing message goes to the terminal as a covering note — *what did this run learn that no
single task captures*. Nothing durable may live only there. Three things this repo specifically wants
in it, because no single task owns them:

- whether anything touched a **path name**, `PathsSpecial.Unauthenticated`, or the **`go` directive** —
  the two camden seams, both of which need action outside this repo;
- whether a release was cut, and whether `/info` was verified against the real artefact rather than a
  local build;
- any work the run generated that belongs to `chat-personal/camden/openbao/` rather than here, named
  so it is not silently dropped.

The report is a terminal action, not a reply to a request. Nobody asks for it; writing it is the last
unit of work.
