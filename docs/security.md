---
title: Security
description: The threat model behind openbao-plugin-secrets-github, what a compromised client can and cannot do, and token lifetimes.
---

# Security

## What never leaves OpenBao

The GitHub App's private key (`prv_key` in [Configuration](configuration.md)) is written once and
stored in OpenBao's storage backend. It is never returned by any read on this engine — `GET
github/config` reports `<configured>` for that field, not the key material — and no path on this
engine exposes it in any other form. The only thing a caller ever receives from this engine is a
GitHub installation access token, not the credential used to mint it.

## What a caller with access to `github/token` can do

A caller authorized (by OpenBao policy) to reach the bare `github/token` path can mint a token for
**any installation this App is installed into**, with **any repository scope and any permission
combination the caller specifies**, up to the ceiling of what that App installation is actually
granted on GitHub. Concretely:

- It can supply any `installation_id`, or any `org_name` the App is installed into, whether or not
  that installation is the one the caller "should" have access to.
- It can request `permissions` broader than it strictly needs — the engine performs no scope
  reduction of its own; GitHub itself is what caps a request at the installation's actual granted
  permissions.
- It cannot read the App's private key, mint a token as a *different* GitHub App, or exceed what
  the App installation itself was granted when it was installed on GitHub.

This is why the bare `github/token` path is the sharpest edge of this engine's threat model.

## Why the bare token path should be unreachable by policy

[Permission sets](permission-sets.md) exist to move the scoping decision out of the caller's
hands: `github/token/:permissionset` mints a token whose installation, repositories, and
permissions are all fixed by whoever created the set, and the request accepts no scope parameters
at all. Combined with an OpenBao policy that denies the bare `github/token` (and `github/config`)
paths to ordinary callers and grants only specific `github/token/<name>` paths, a compromised
caller is bounded to exactly the sets it was given — it cannot ask this engine for a wider grant,
because the request format for a permission-set token has nowhere to put one.

A representative policy for a caller that should only ever mint the `ci-release` permission set:

```hcl
path "github/token/ci-release" {
  capabilities = ["read"]
}
```

That caller has no path to `github/token`, `github/config`, or any other `github/token/:name`, so
even full compromise of that caller's OpenBao token yields nothing beyond what `ci-release` was
built to grant.

## Token lifetime and revocation

Every minted token carries an OpenBao lease whose TTL is derived from GitHub's own `expires_at` on
the token response — GitHub's default installation-token lifetime is about one hour, and this
engine does not extend or shorten it. There is no renewal: GitHub has no API to extend an
installation token's life, so the engine's `Secret` definition implements revoke only.

Revoking the lease (`bao lease revoke <lease_id>`, or automatic revocation when the lease expires
under OpenBao's own management) sends the revocation immediately to GitHub's
`DELETE /installation/token` endpoint, invalidating the token at the source rather than merely
forgetting it locally. A revocation against a token GitHub already considers gone (expired or
already revoked, which GitHub reports as 401) is treated as a successful revocation, not an error.

## Unauthenticated paths

Two paths are served without requiring an OpenBao token: `github/info` (build/version metadata)
and `github/metrics` (Prometheus metrics). Neither returns any credential, configuration value, or
token — they are read-only observability surfaces, marked unauthenticated so a Prometheus scraper
or health check doesn't need an OpenBao token of its own. Every other path, including token
minting and permission-set management, requires normal OpenBao authentication and policy
authorization.

## Configuration write validation

`github/config` rejects a malformed private key or an unparseable `base_url` at write time
(before persisting anything), and every write-capable path on this engine rejects unrecognized
field names outright. This doesn't defend against a malicious caller so much as it prevents a
config typo from silently degrading into a broken or partially-applied configuration.
