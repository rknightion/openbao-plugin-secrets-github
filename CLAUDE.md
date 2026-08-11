# openbao-plugin-secrets-github

OpenBao secrets engine that mints short-lived, permission-scoped GitHub App installation tokens.
Fork of `martinbaillie/vault-plugin-secrets-github` ported to the OpenBao SDK. Ships as an OCI image
(`ghcr.io/rknightion/openbao-plugin-secrets-github`) plus release binaries.

## Scope: this repo is the plugin, not the lab that runs it

**The test: would this change a file in this repo?** If no, it belongs in
`~/repos/chat-personal/camden/openbao/` — that folder owns camden's OpenBao deployment (server
config, ACL policies, tailnet identity, per-repo JWT roles, CI-consumer onboarding) and is where its
history and decisions live. Do not open a GitHub issue here for it.

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
