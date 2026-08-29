---
id: OBG-0002
title: Migrate the repo task surface to just and retire Makefiles and ad-hoc scripts
status: Done
assignee: []
created_date: '2026-08-28 19:25'
updated_date: '2026-08-29 14:33'
labels:
  - 'wave:2-fleet'
dependencies: []
priority: medium
type: chore
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
# Migrate task surface to `just`

Fleet-wide `just` migration for `rknightion/openbao-plugin-secrets-github`. Follows the frozen fleet
standard (`JUST-FLEET-STANDARD.md`) verbatim — do not re-litigate §1–§13 of that document.

## 1. Outcome

A top-level `justfile` is the repo's one task surface. `just --list` shows `default`, `setup`,
`fmt`, `fmt-check`, `lint`, `test`, `check`, `audit`, `image`, `ci` — each with a doc comment and a
group. `just check` runs everything a PR must pass, including the two checks that today live only in
`ci.yml` (`hashicorp/vault` import grep, `govulncheck`). `.github/workflows/ci.yml`'s `test` and
`vuln` jobs collapse to `run: just check`; the `image` job collapses to `run: just image`.
`AGENTS.md` and `backlog/config.yml` point at `just` instead of raw `go` invocations. No Makefile and
no shell scripts exist in this repo today, so there is nothing to delete on that front — this is a
pure "define the justfile, wire CI, update docs" task, not a migration-and-cleanup task.

**This repo has no Makefile and no tracked shell scripts.** `find . -iname Makefile -o -iname
GNUmakefile` and `git ls-files | grep -E '\.(sh|bash|zsh|ps1)$'` both return nothing. Do not go
looking for either — sections 3 and 4 below are short because there is genuinely nothing there, not
because they were skipped.

## 2. The complete justfile

Create `justfile` at the repo root with exactly this content, adjusting only if a command listed in
§9 (Traps) below turns out to need a tweak on the implementing machine:

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

# show the task surface
default:
    @just --list

# install toolchain + deps into the repo-local environment (idempotent)
setup:
    go mod download
    command -v golangci-lint >/dev/null || go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
    command -v govulncheck >/dev/null || go install golang.org/x/vuln/cmd/govulncheck@latest
    command -v goimports >/dev/null || go install golang.org/x/tools/cmd/goimports@latest

# format Go source in place
[group('check')]
fmt:
    gofmt -l -s -w .
    goimports -w .
    just --fmt

# verify Go source and this justfile are formatted (never mutates)
[group('check')]
fmt-check:
    @test -z "$(gofmt -l -s .)" || { gofmt -l -s .; echo "run: just fmt"; exit 1; }
    @test -z "$(goimports -l .)" || { goimports -l .; echo "run: just fmt"; exit 1; }
    just --fmt --check

# static analysis: golangci-lint, go vet, and the integration-test build tag compiles
[group('check')]
[no-exit-message]
lint:
    golangci-lint run ./...
    go vet ./...
    go vet -tags integration ./...

# fork-invariant: this module must never re-import the HashiCorp Vault SDK
[group('check')]
[no-exit-message]
verify-no-vault-sdk:
    ! grep -rn "hashicorp/vault" --include='*.go' .

# dependency vulnerability scan against the toolchain this module ships
[group('check')]
[no-exit-message]
audit:
    govulncheck ./...

# run the test suite (optional filter, e.g. `just test TestPathToken`)
[group('check')]
test filter="":
    go build ./...
    go test -race -coverprofile=coverage.out {{ if filter == "" { "./..." } else { "-run " + filter + " ./..." } }}

# the full local PR gate -- exactly what CI's test+vuln jobs enforce
[group('check')]
check: fmt-check lint verify-no-vault-sdk audit test

# build the linux/amd64 binary and the Containerfile image (no push) -- mirrors ci.yml's `image` job
[group('build')]
image tag="openbao-plugin-secrets-github:dev":
    mkdir -p dist
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o dist/openbao-plugin-secrets-github_linux_amd64 .
    docker buildx build --platform linux/amd64 -t {{ tag }} -f Containerfile .

# full CI superset: everything `check` runs, plus the image build (needs docker buildx)
[group('check')]
ci: check image
```

Notes on choices baked into this file (do not change without re-checking §9):

- `fmt` calls `just --fmt` (no `--check`) after the Go formatters, so a single `just fmt` also fixes
  justfile formatting. `fmt-check` calls `just --fmt --check` last, per fleet rule §5.10.
- `verify-no-vault-sdk` inverts `grep`'s exit code with a leading `!` — `grep` exits 1 on "no match",
  which is the success case here. `[no-exit-message]` keeps `just`'s own failure banner off, but the
  bare `!` will still print `error: Recipe ... failed with exit code 1` from `just` itself when the
  grep *does* match, because `!cmd` reports exit 1 to just on match. That is fine: `[no-exit-message]`
  matches, `just` gives a clean failure with grep's own matching lines already on stdout above it.
- `check` deliberately does **not** include `image` — it needs no docker toolchain, so it runs on any
  machine including a sandboxed agent with no buildx. `ci` is the docker-requiring superset, and is
  what the CI workflow calls (§5).
- `test` runs `go build ./...` first because `ci.yml`'s `test` job has a separate `Build` step before
  `Test` — folding both into `just test`'s body keeps `check`'s dependency list from needing a
  separate `build` recipe nobody else uses. If a future need for a standalone `build` recipe shows up
  (e.g. a local dev binary), add `[group('build')] build: go build -o openbao-plugin-secrets-github .`
  as its own recipe.

## 3. Makefile disposition

None. No `Makefile` or `GNUmakefile` exists anywhere in this repo (root or subdirectory, `vendor/`
excluded — there is no `vendor/` either). No action needed; do not create one to delete.

## 4. Script disposition

None. `git ls-files | grep -E '\.(sh|bash|zsh|ps1)$'` returns zero files. No `scripts/` directory
exists. No action needed.

## 5. CI changes

### `.github/workflows/ci.yml`

Add the `setup-just` step to every job that will call `just` (`test`, `image`; `vuln` folds into
`test` — see below), immediately after `actions/setup-go`:

```yaml
      - uses: extractions/setup-just@<pin-to-current-SHA-for-v4> # v4
        with:
          just-version: '1.58.0'
```

Get the current pinned SHA for `extractions/setup-just`'s `v4` tag the same way every other action in
this file is pinned (`gh api repos/extractions/setup-just/git/refs/tags/v4` or resolve via the
existing convention in this file — do not hand-guess a SHA).

Collapse the `test` job's four `run:` steps (`Build`, `Test`, `Vet`, `Verify no Vault SDK imports
remain`) into one:

```yaml
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0
        with:
          go-version-file: go.mod
          cache: true
      - uses: extractions/setup-just@<pinned-sha> # v4
        with:
          just-version: '1.58.0'
      - run: just check
```

This folds the `vuln` job's `govulncheck ./...` step into the same `just check` call (via the `audit`
recipe), so **delete the `vuln` job entirely** and remove `vuln` from `ci-success`'s `needs:` list.
Also delete the standalone `govulncheck` install step — `just check`'s `audit` recipe installs nothing
itself; `setup` does, so the job needs a `just setup` step before `just check` OR the job installs
`govulncheck` inline the same way `setup` does. **Prefer adding `- run: just setup` before `- run:
just check`** so the job's own tool provisioning goes through the same recipe a developer runs
locally, rather than duplicating the `go install golangci-lint`/`go install govulncheck` lines in
YAML. Keep the existing code comment block explaining why `govulncheck` must run in this job's own
`setup-go` environment (not `golang/govulncheck-action`) — move it to sit above the `just setup` /
`just check` steps so the reasoning survives the collapse.

The `image` job's `Build binary` step body collapses to `run: just image`; keep
`docker/setup-buildx-action` as-is (the recipe shells out to `docker buildx build`, it does not
replace the runner-level buildx setup).

Resulting `test` job (after folding `vuln` in):

```yaml
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0
        with:
          go-version-file: go.mod
          cache: true
      - uses: extractions/setup-just@<pinned-sha> # v4
        with:
          just-version: '1.58.0'
      # govulncheck must run inside THIS job's setup-go environment, not
      # golang/govulncheck-action -- that action always passes go-version:
      # stable alongside go-version-file, and setup-go ignores go-version-file
      # whenever go-version is set, so it would scan with the newest Go rather
      # than the toolchain this module actually pins. Every release ships
      # whatever stdlib the `go` directive selects, so scanning with a
      # different toolchain would report a clean bill of health for a binary
      # that isn't clean.
      - run: just setup
      - run: just check

  image:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0
        with:
          go-version-file: go.mod
      - uses: extractions/setup-just@<pinned-sha> # v4
        with:
          just-version: '1.58.0'
      - uses: docker/setup-buildx-action@37fe631027851001ddb9b187196cc803df7f5f0e # v4.3.0
      - run: just image

  ci-success:
    if: always()
    needs: [test, image]
    runs-on: ubuntu-latest
    steps:
      - name: Check results
        run: |
          if echo '${{ toJSON(needs) }}' | grep -q '"result": *"failure"\|"result": *"cancelled"'; then
            echo "::error::a required job failed"
            exit 1
          fi
          echo "all jobs passed"
```

Do NOT touch: `permissions:` block, `concurrency:` block, the `ci-success` job's name or its
`if: always()` guard, the `actions/checkout` / `actions/setup-go` SHA pins, or
`docker/build-push-action`'s `push: false` semantics inside `just image`.

### `.github/workflows/publish.yml` — out of scope, do not migrate its build step

Leave `publish.yml`'s `Build binaries` step (the `for arch in amd64 arm64; do go build ... done` loop
with the `-X` ldflag injections) exactly as it is. See §10 traps for why.

### Every other workflow file — out of scope, unchanged

`actionlint.yml`, `arm-automerge.yml`, `auto-rc.yml`, `broker-connectivity-probe.yml`, `codeql.yml`,
`dependency-review.yml`, `ghcr-cleanup.yml`, `release-please.yml`, `scorecard.yml`,
`trigger-docs-sync.yml`, `zizmor.yml` contain zero build/test/lint/generate/validate `run:` logic —
every one of them is either a GitHub-native reusable-workflow call or a broker/probe workflow with no
task-surface content. Do not touch any of them.

## 6. Docs and agent-contract changes

### `AGENTS.md`

Replace the `## Gate` section (currently):

```markdown
## Gate

​```bash
go build ./... && go test -race ./... && go vet ./...
​```

Two more checks exist only in `ci.yml` and will fail a PR that passes locally:

- **no `hashicorp/vault` imports** -- `grep -rn "hashicorp/vault" --include='*.go' .` must be empty.
  The port to the OpenBao SDK is the point of the fork; a transitive re-introduction is a regression.
- **`govulncheck ./...`**, run inside the job's own `setup-go` environment. Deliberately *not*
  `golang/govulncheck-action`: ...
```

with:

```markdown
## Task interface

This repo's task surface is a `justfile`. Discover it, don't guess it:

    just --list                        # human-readable
    just --dump --dump-format json     # machine-readable
    just --show <recipe>               # what a recipe actually runs

- `just check` is the full gate and is exactly what CI's `test` job enforces. It must pass before you
  commit. It folds in the two checks that used to live only in `ci.yml` -- the `hashicorp/vault`
  import grep (`verify-no-vault-sdk`) and `govulncheck` (`audit`) -- so there is no longer a
  CI-only gate that passes locally and fails in the PR.
- Prefer `just <recipe>` over the underlying tool. If you are typing `go test`, you want `just test`.
- Run `just` with stdin from /dev/null. No recipe in this repo is `[confirm]`-marked today.
- If a task you need does not exist, add a recipe with a `#` doc comment and a `[group(...)]` rather
  than running a bare command.
```

Keep the `govulncheck` sourcing rationale (why not `golang/govulncheck-action`) — move that specific
paragraph as a comment inside the `justfile`'s `audit` recipe instead of losing it, or leave a short
pointer here: "`just audit`'s doc comment and the `ci.yml` CI comment carry why this runs inside the
module's own toolchain." Do not delete the reasoning outright — AGENTS.md elsewhere (the `/info`
`-X` section) shows this repo values exact provenance for exactly this class of fact.

Also keep the `integration_test.go` paragraph (the `go vet -tags integration ./...` explanation) —
it is still accurate; `just lint` now runs that vet pass every time `lint`/`check` runs, so the "do
that after touching anything it references" caveat can be softened to note it now happens
automatically on every `just check`, rather than deleted.

### `README.md`

Replace the `## Build` section:

```markdown
## Build

​```bash
go build -o openbao-plugin-secrets-github .
go test ./...
​```
```

with:

```markdown
## Build

​```bash
just setup
just check
​```

See `just --list` for the full task surface (formatting, linting, the vulnerability scan, and the
Containerfile image build).
```

### `CLAUDE.md`

No change — it is a two-line pointer (`@AGENTS.md`) with no `make`/script references.

### `docs/` (zensical site)

`docs/getting-started.md`, `docs/installation.md`, `docs/troubleshooting.md`, `docs/faq.md` — grep
each for `go build`, `go test`, `make ` before editing. As inventoried, the only `make`/script
reference in the whole repo tree outside `AGENTS.md`/`README.md`/`ci.yml` is inside those two files
above; re-grep at implementation time in case docs/ changed since this task was filed:

```bash
grep -rn "make \|\./scripts/\|go build\|go test" docs/ README.md AGENTS.md CLAUDE.md CONTRIBUTING.md 2>/dev/null
```

If that grep turns up nothing new in `docs/`, no docs/ edits are needed beyond README/AGENTS above.

## 7. `backlog/config.yml`

Current `definition_of_done`:

```yaml
definition_of_done:
  - "go build ./... && go test -race ./... && go vet ./..."
  - "grep -rn 'hashicorp/vault' --include='*.go' . returns nothing (CI-only gate)"
  - "govulncheck ./... (CI-only gate; a red vuln job may be a new stdlib CVE, not this change)"
  - "go vet -tags integration ./... (only if the change touches anything integration_test.go references)"
```

Replace with:

```yaml
definition_of_done:
  - "just check passes (fmt-check, lint including go vet -tags integration, verify-no-vault-sdk, audit, test)"
  - "a red `just audit` may be a newly published stdlib CVE, not this change -- check before assuming a regression"
  - "just fmt-check passes, including just --fmt --check"
```

Edit this file by hand — it is the one Backlog.md file the project's own `AGENTS.md` says is edited
directly, because list-valued keys cannot be set through `backlog config set`. Do not run this edit
as part of this task; it is documented here for whoever executes the plan, and is itself only a
5-line hand edit once the justfile lands, not a `backlog` CLI action.

## 8. Order of work

1. Add `justfile` at repo root (§2). Run `just --fmt --check`, `just --list`, `just setup`, `just
   check` locally. Fix anything that doesn't match this repo's actual toolchain versions before
   touching CI.
2. Run `just image` locally (needs Docker) and confirm it builds without pushing.
3. Update `.github/workflows/ci.yml` per §5. Push to a branch or rely on the next `main` push;
   confirm `test`, `image`, `ci-success` all go green and that `ci-success`'s `needs:` list now reads
   `[test, image]`.
4. Update `AGENTS.md`, `README.md` per §6.
5. Hand-edit `backlog/config.yml`'s `definition_of_done` per §7.
6. Nothing to delete (§3, §4) — skip the "deletions last" step that a Makefile/script-bearing repo
   would need.

## 9. Traps specific to this repo

- **`.golangci.yml`'s `formatters:` block has `settings:` for `gofmt`/`goimports` but no `enable:`
  list.** Without `enable: [gofmt, goimports]` under `formatters:`, running `golangci-lint fmt` would
  format nothing — the `gofmt`/`goimports` settings (the `interface{}`→`any` rewrite rule, the
  `local-prefixes` import grouping) are dead config today. This justfile sidesteps that entirely by
  calling plain `gofmt`/`goimports` directly rather than `golangci-lint fmt`, so `just fmt`/
  `fmt-check` work regardless — but the `interface{}`→`any` rewrite rule and the import
  local-prefix grouping will NOT be applied by `just fmt`. If that rewrite matters, a follow-up task
  should add `enable: [gofmt, goimports]` to `.golangci.yml` and switch the recipe bodies to
  `golangci-lint fmt` / `golangci-lint fmt --diff`. Out of scope here — note it, don't fix it.
- **`golangci-lint` is v2** (`.golangci.yml` has `version: 2`, confirmed installed binary is 2.12.2).
  `setup`'s install path is `github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` —
  the `/v2/` segment is load-bearing; the pre-v2 module path installs the wrong major version.
- **`publish.yml`'s binary build is deliberately NOT migrated into a recipe.** Its `-X` ldflag
  injections make the binary hash a function of commit + exact build inputs, and camden pins that
  hash with `plugin_download_behavior = "fail"` (per `AGENTS.md`'s "Releases are hash-pinned"
  section). The build step already carries three separate long code comments justifying exact,
  non-obvious choices (`-buildvcs=false`, no `BuildDate`/`BuildUser`, arch loop ordering) written
  specifically to keep rebuilds byte-identical. Wrapping it in a `just release-binaries` recipe is
  mechanically possible (a `[script('bash')]` recipe with the same env-var-driven `for arch in amd64
  arm64` loop) but buys nothing — this step only ever runs once per release, from `publish.yml`
  itself, never from a developer's terminal — and adds a seam where a recipe-vs-workflow drift could
  silently change the hash. Leave it as inline YAML. If a future task wants this in `just` anyway, it
  must diff the resulting binary against a known-good hash before trusting it, not just diff the
  command text.
- **No `lint`/`fmt` job exists in CI today** — `go vet` is the only static check `ci.yml` currently
  runs; `golangci-lint run` has never gated a PR in this repo despite `.golangci.yml` existing. Wiring
  `just check` to include `lint` (→ `golangci-lint run ./...`) is a **real behavior change**: it will
  likely surface pre-existing findings across `github/*.go` the first time `just check` runs, because
  35 linters are enabled (`cyclop`, `dupl`, `gosec`, `wsl_v5`, etc. — see `.golangci.yml`) and none of
  them have ever run against this codebase in CI. Run `just lint` locally BEFORE wiring CI to it and
  budget time to either fix findings or add targeted `//nolint` with `nolintlint`'s required
  `require-explanation: true` / `require-specific: true` settings (a bare `//nolint` is itself a lint
  failure here).
- **`test` filter param and `-race` interact with `t.Parallel()`.** `AGENTS.md`'s "Test idiom" section
  says every test uses `t.Parallel()` on both outer and subtests — `just test filter=TestPathToken`
  using `-run` only filters top-level test names by regex; a subtest-only match needs
  `TestPathToken/subtest_name` as the filter value. Document this in the recipe's doc comment if it
  trips someone up; not fixed here since `-run`'s regex semantics are Go's, not just's.
- **`integration_test.go`** stays behind `//go:build integration` and is never executed by any
  recipe here (`lint`'s `go vet -tags integration ./...` compiles but does not run it, matching
  current CI behavior exactly). Do not add a `just integration` recipe — it needs a live OpenBao plus
  real GitHub App credentials that no CI job or dev machine in this fleet standard's scope has;
  `AGENTS.md` is explicit that this is deliberate.
- **`flake.nix` / `.envrc` are stale and out of scope.** The Nix flake still names the package
  `vault-plugin-secrets-github` under `github.com/martinbaillie/...` — pre-fork, pre-rename, not
  updated when the module path became `github.com/rknightion/openbao-plugin-secrets-github`. It
  defines its own devshell commands (`lint`, `unit`, `build`, `tidy`, `clean`) that overlap in name
  with the new `just` recipes but run different, stale commands (e.g. its `unit` uses `gotestsum`,
  which is not a dependency of this module's `go.mod`). Do not touch `flake.nix` in this task — it is
  a separate, larger cleanup (rename the package, decide whether devshell commands should defer to
  `just`, fix the vendorHash) that this fleet migration does not cover. If a developer runs `nix
  develop`, be aware `menu`/`lint`/`unit` there are NOT the same as `just lint`/`just test` and will
  silently diverge — worth a one-line note in `AGENTS.md` under Layout if this bites someone, but not
  required for this task's acceptance.
- **`coverage.out` is a build artifact `just test` produces** and is already untracked (verify with
  `git status` after running `just test` — if it shows as untracked, no `.gitignore` entry exists for
  it; add one as a drive-by fix only if genuinely missing, otherwise leave it, this is not this task's
  scope to audit `.gitignore` broadly).

## 10. Out of scope

- `publish.yml`'s binary build step (see §9 — deliberately left as inline YAML).
- `flake.nix`, `.envrc`, `flake.lock` (see §9 — stale, pre-fork, separate cleanup).
- Every GitHub-native workflow: `release-please.yml`, `codeql.yml`, `zizmor.yml`, `actionlint.yml`,
  `scorecard.yml`, `dependency-review.yml`, `ghcr-cleanup.yml`, `arm-automerge.yml`, `auto-rc.yml`,
  `broker-connectivity-probe.yml`, `trigger-docs-sync.yml` — none contain build/test/lint logic to
  migrate; do not fold any of them into `just` or touch their `uses:` calls.
- `docs/` content beyond the grep-and-check pass in §6 (no build/test commands were found referenced
  there at inventory time).
- Fixing `.golangci.yml`'s missing `formatters: enable:` list (§9 — noted as a trap, not fixed).
- Adding `golangci-lint run --fix` to any recipe — `lint` must never mutate per the fleet standard's
  `lint` contract (§1); a separate `lint-fix` recipe is NOT part of this task's required scope but may
  be added later if desired (would need `[group('check')]` and a doc comment, and must not be a
  dependency of `check`).
- Any change to `camden`/OpenBao deployment config, ACL policies, or JWT roles — this repo's own
  `AGENTS.md` is explicit that this repo is the plugin, not the lab that runs it; that boundary is
  unaffected by this migration and this task does not touch anything under `chat-personal/camden/`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Top-level justfile exists with all seven mandatory recipes (default, setup, fmt, fmt-check, lint, test, check) plus audit, image and ci, each carrying a # doc comment and a [group(...)]
- [x] #2 just check runs fmt-check, lint (golangci-lint run + go vet + go vet -tags integration), verify-no-vault-sdk, audit (govulncheck), and test, and passes locally
- [x] #3 just --fmt --check passes and is invoked from inside fmt-check
- [x] #4 just --list shows a doc comment and a group for every public recipe
- [x] #5 confirmed no Makefile or GNUmakefile exists anywhere in the repo (there was none to delete)
- [x] #6 confirmed no tracked shell script exists in the repo (there was none to absorb or keep)
- [x] #7 .github/workflows/ci.yml's test job runs just check (folding in the former vuln job's govulncheck), the image job runs just image, and ci-success's needs: list is updated to [test, image] with all other structural blocks (permissions, concurrency, SHA pins) unchanged
- [x] #8 AGENTS.md's Gate section and README.md's Build section reference just instead of raw go build/go test invocations, using the Task interface wording from JUST-FLEET-STANDARD.md section 9
- [x] #9 backlog/config.yml's definition_of_done references just check and just fmt-check instead of raw go commands
- [x] #10 publish.yml's release binary build step and flake.nix/.envrc are explicitly left unmigrated per the task's Traps and Out of scope sections
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 go build ./... && go test -race ./... && go vet ./...
- [x] #2 grep -rn 'hashicorp/vault' --include='*.go' . returns nothing (CI-only gate)
- [x] #3 govulncheck ./... (CI-only gate; a red vuln job may be a new stdlib CVE, not this change)
- [x] #4 go vet -tags integration ./... (only if the change touches anything integration_test.go references)
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add the top-level justfile using the fleet’s mandatory recipes and the repo-specific audit, image, and Docker-gated ci surface.
2. Replace CI task logic with one-line just recipes while retaining the release workflow and reusable workflow calls.
3. Update the task-interface documentation, source-build documentation, and Backlog definition of done; include the newly found installation guide command reference.
4. Run local formatting, check, image, workflow validation, review, exact-head CI, then finalize the task with evidence.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the Just task surface and CI wiring. Local isolated validation passed `just --fmt --check`, `just --dump --dump-format json`, a shell-metacharacter filter test, `just check`, and `just image`; actionlint passed. The local zizmor run reported existing findings in unchanged workflows. CI run 33257817328 passed at aa4963679962d818d558ba5786621d104878d611. CodeRabbit completed one review, whose sole minor quoting finding was fixed; a final re-review was unavailable because the service rate-limited after a connection interruption.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: campaign-ordering
created: 2026-08-29 09:18
---
## Fleet ordering — WAVE 2. Starts after the Wave 0 pilot (`sf2loki` / SFL-0073) and the Wave 1 hubs land.

Within Wave 2 the order is free — these repos do not depend on each other. Batching by language is worthwhile so one lane reuses its Makefile-to-recipe mapping across similar repos.

Do not start before the pilot reports. The standard may be amended off the back of it, and picking this up early risks coding against a superseded seam.

**Provisioning `just` in CI.** Which mechanism depends on the runner, and the two must not be mixed:

| Runner | Mechanism |
| --- | --- |
| `arc-arm64` (m7kni self-hosted) | `just` is **baked into the runner image** by `m7kni/ci-tools` (`runner-image/Dockerfile`, `ARG JUST_VERSION`). Do **not** add `extractions/setup-just`, and delete the step if this repo already has one — it installs a second `just` earlier on `PATH` and turns the image pin into a lie. |
| GitHub-hosted (all `rknightion` repos) | `extractions/setup-just`, SHA-pinned, with an explicit `just-version:`. |

Both sides currently sit on **1.58.0** and are Renovate-managed. `ci-tools`' `Tool version drift` workflow fails if the Dockerfile `ARG` and the published image ever disagree, and lists any repo still carrying a second pin.

**While you are in the workflow files, check the hub pin.** On 2026-08-29 Renovate was unfrozen for `rknightion/.github` in `m7kni/renovate-config` — it had been `enabled: false` on the mistaken belief that callers tracked `@main`, which froze the fleet across 19 different hub SHAs (v1.3.1 June → v1.9.7 August) so that no hub fix ever propagated. Bumps now arrive as one grouped, CI-gated, automerged PR per repo. **A `uses:` whose comment is not a real `# vX.Y.Z` still cannot be bumped** (it resolves to a digest-only update, which the fleet rules disable) — if you find one, repair the comment as part of this task.
---

author: campaign-ordering
created: 2026-08-29 10:43
---
## Standard amendment — `ci` is the sanctioned superset of `check` (RATIFIED)

This supersedes the frozen wording *"`check` is the complete local gate and reproduces every CI job that can run off a GitHub runner"*, which several lanes could not honour without making the pre-commit gate depend on a Docker daemon.

**The definitions now are:**

- **`check`** — everything that runs with **only the language toolchain installed**. This is the pre-commit gate. A leg that runs on a bare toolchain belongs here *however long it takes*.
- **`ci`** — `check` plus the legs CI gates that need a **Docker daemon, a service container, or cross-compilation**, and nothing else. Written as `ci: check <heavy legs>`.

**Every leg you put in `ci` must carry a comment naming which of those three it needs.** That comment is the guard: without it `ci` becomes the bin for anything slow or awkward, `check` quietly stops meaning much, and the fleet is back to a per-repo gate.

Eleven of the 42 lanes arrived at this shape independently before it was ratified, which is why it won.

**If this repo has no such legs, it has no `ci` recipe at all** and `check` is the whole gate. Do not add an empty one.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the top-level justfile, routed CI test/image work through it, and updated the task interface, source-build docs, and definition of done. A small shared metric-label constant resolves pre-existing golangci-lint findings required for `just check` to pass. The release build and Nix surfaces remain intentionally unmigrated. Verified locally and by green CI run 33257817328 at aa4963679962d818d558ba5786621d104878d611.
<!-- SECTION:FINAL_SUMMARY:END -->
