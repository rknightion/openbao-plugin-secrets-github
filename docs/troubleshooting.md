---
title: Troubleshooting
description: Common openbao-plugin-secrets-github failure modes and how to diagnose them.
---

# Troubleshooting

## Config write rejected: "unable to parse private key" / "key is not a PEM formatted RSA private key"

**Cause.** `github/config`'s `prv_key` field must decode as a PEM block of type
`RSA PRIVATE KEY` (PKCS#1), and that block must itself parse as a valid RSA private key. A key in
PKCS#8 (`BEGIN PRIVATE KEY`) format, a key with stray whitespace or line-ending corruption from
copy-paste, or a non-key file entirely will fail this check.

**Fix.** Use the private key exactly as GitHub generates it when you download it from the App's
settings page. When passing it on the CLI, use `prv_key=@path/to/key.pem` so the file's bytes are
read directly rather than retyped or re-escaped.

## Config write rejected: "unable to parse base URL"

**Cause.** `base_url` is parsed with a strict absolute-URL parser at write time. A bare hostname,
a relative path, or a malformed scheme is rejected before it is ever persisted.

**Fix.** Supply a full base URL, e.g. `https://github.example.com/api/v3` for GitHub Enterprise
Server, or omit the field entirely to use the public GitHub API default.

## Write rejected: "unknown field" / "unknown fields"

**Cause.** Every write-capable path on this engine validates the request body against its schema
before doing anything else. A typo'd field name, or a field valid on one path but not another
(`prv_key` on `github/token`, say), is rejected outright rather than silently ignored.

**Fix.** The error names the offending field(s) — check the field name against
[Reference: API](reference/api.md) for the path you're calling.

## Token request fails: "app not installed in GitHub organization"

**Cause.** You supplied `org_name` (on `github/token` or a permission set) and this engine's
lookup against the App's installations found no case-insensitive match for that name. This means
either the name is wrong, or the App genuinely isn't installed on that organization/account.

**Fix.** Confirm the organization name, and confirm the App is actually installed there — check
`GET /github/installations` (see [Reference: API](reference/api.md)) for the authoritative mapping
of organization names this App knows about to their installation IDs. Prefer `installation_id`
over `org_name` where you can, both because it's faster (no extra API round trip) and because it
sidesteps name-matching entirely.

## Token request fails with a GitHub API error (4xx/5xx)

**Cause.** The engine forwards GitHub's own response when the access-token or installations
request itself fails — a revoked App installation, an App with insufficient granted permissions
for what was requested, a rate limit, or a genuine GitHub outage all surface this way. The error
includes GitHub's HTTP status and response body verbatim.

**Fix.** Read the embedded GitHub response body — it names the actual problem (e.g. "This app is
not installed" vs. a permissions mismatch vs. a rate-limit message) far more specifically than
this engine can. If it's a permission mismatch, check what the App is actually granted on GitHub
against what was requested in `permissions`.

## Config appears wrong after a write, but the write "succeeded"

**Cause.** A `github/config` write is a no-op if it doesn't actually change any value — nothing is
re-persisted and the cached GitHub client is not invalidated. If you intended to force a client
rebuild (for example, after an out-of-band change to something the client depends on) but every
field you wrote matched the existing stored value, nothing happened.

**Fix.** Confirm the stored values with `bao read github/config` first, or change at least one
field to something different (then set it back if needed) to force the client to rebuild.

## A CI job authenticating to OpenBao fails with 400 before it ever reaches this engine

**Cause.** This is not a failure in `openbao-plugin-secrets-github` itself — it happens one step
earlier, when a workflow logs into OpenBao (for example via an OIDC-based auth backend such as
`auth/gha` or `auth/jwt`) before it can call `github/token` at all. OpenBao's JWT-based auth
backends return a 400 at login when the named **role does not exist** — a typo in the role name, a
role that was never created, or a role created under a different auth mount path than the one the
workflow is targeting all produce the same generic 400.

**Fix.** Confirm the role exists on the exact auth mount the workflow logs into
(`bao read auth/<mount>/role/<name>`), and confirm the workflow's login call references that same
mount and role name. This engine's own paths are never reached while this failure is happening —
if you're chasing a token-minting problem and the failure is actually at login, `github/config`,
`github/token`, and permission sets are all irrelevant to the fix. See
`.github/workflows/broker-connectivity-probe.yml` in the repository for a worked example of
separating an auth-layer failure like this from a genuine engine or network problem.

## Verifying an engine build's provenance

**Cause.** `GET /github/info` (see [Reference: API](reference/api.md#get-githubinfo)) reports
empty version/build fields if the running binary wasn't built with the release `-ldflags`
injections.

**Fix.** This is expected for a plain `go build` — see
[Installation](installation.md#option-a-build-from-source). Released binaries and container images
carry real values; if a production deployment shows empty fields, it was likely built from source
locally rather than from a tagged release.
