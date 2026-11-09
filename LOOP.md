# Loop: openbao-plugin-secrets-github
tier: guarded
gate: just check
ci-required: ci-success
grafana-stack: none
tracker: github
landing: pr

The tracker working model is `~/repos/agent-docs/docs/github-tracker.md` (maintainers only).

Public repository and a credential broker: issues are public, so no App or installation ID, key
or token material, tailnet address, JWT role name or ACL policy body in any issue, pull request or doc. Run `just`
with stdin from `/dev/null`. Engine layout, the `-X` injections and the two camden seams are in
`AGENTS.md`.

## Queue

- The queue is `just tracker queue`: open issues at Project Status Ready on the rknightion Project.
- A charter selects work by labels (`type:task`, `type:bug`, `type:feature`, `needs-owner`,
  `needs-triage`) and Project fields (Status, Priority, Effort, Lane). Never queue a `needs-owner` or
  `needs-triage` issue, nor the Renovate Dependency Dashboard (#21).
- Only the root writes issues and the Project, through `just tracker`. A lane returns the status and
  the AC ticks it wants.
- A queue row names the issue as `#N`. A legacy board id (`OBG-0001`) resolves with `just issue <ID>`;
  `.github/tracker/id-map.json` is the map. Issue numbers below #95 are older issues and pull
  requests, not the board.

## Credentials

- The live OpenBao on camden and the real GitHub App belong to the root. `integration_test.go`
  (`//go:build integration`) never runs in CI or in a lane; a lane may only compile it with
  `go vet -tags integration ./...`.

## Traps

- The local gate is not the whole CI: the `hashicorp/vault` import grep and `govulncheck ./...` live
  in `ci.yml` (`ci-success` needs `test`, `image`, `vuln`). A red `vuln` can be a newly published
  stdlib CVE with no code change: read the finding before assigning it.
- `.golangci.yml` is inherited from upstream and CI never runs it, so lint findings are advisory
  unless a task says otherwise. Never put it in a definition of done.
- `go build -ldflags -X` on an unresolvable symbol path is ignored without error. A task touching
  `publish.yml`, the injected symbols or the module path closes only on `/info` returning non-empty
  values from a real published artefact, never on a green build.
- Two changes that look local: renaming or adding a path that collides with the
  `github-app-broker/token/*` prefix reopens an unrestricted mint through an ACL outside this repo,
  and bumping the `go` directive changes the release hash camden pins. A task touching either says so
  in its return.
- A lane inventing a path name, a `PathsSpecial.Unauthenticated` entry or a permission-set default is
  deciding who can mint tokens: stop and return the question.
- Work that would change nothing in this repo (deployment, ACL policy, CI-onboarding for camden)
  belongs on the camden tracker, not here.
- Never re-run `publish.yml` for a version camden pinned; cut a new one.
- A lane brief forbids destructive git by name (`checkout -- .`, `restore`, `stash`, `clean`,
  `reset --hard`, `worktree remove`) as well as commit and push.

## Mutexes

- One lane per `path_<name>.go` plus its test. `github/backend.go` (the `Paths` registry) is a wiring
  pass: freeze pattern constants and field names first, then register everything once.
- Single owner: `go.mod` and `go.sum`, each `.github/workflows/*` file (`ci.yml` one lane only),
  `AGENTS.md` (root only; `CLAUDE.md` stays a one-line import).
- release-please owns `CHANGELOG.md` and `.release-please-manifest.json`: no lane touches them.
- `broker-connectivity-probe.yml` (manual, exercises live tailnet and OpenBao auth), publishing to
  ghcr and cutting a release: root, one at a time.
