---
title: FAQ
description: Answers about OpenBao and Vault compatibility, GitHub App tokens, permissions, leases, revocation, and migration.
---

# FAQ

## Is this a fork of HashiCorp Vault's plugin?

It's an independently maintained fork of
[`martinbaillie/vault-plugin-secrets-github`](https://github.com/martinbaillie/vault-plugin-secrets-github)
(itself a community project, not a HashiCorp one), ported from the HashiCorp Vault SDK to the
OpenBao SDK. It is tracked against that upstream via a git `upstream` remote, but it is not part
of GitHub's fork network, and CI enforces that no `hashicorp/vault` SDK import remains anywhere in
the source tree.

## Does this work with HashiCorp Vault?

The plugin is built and served against the OpenBao SDK (`github.com/openbao/openbao/sdk/v2`) and
`plugin.ServeMultiplex`. It has not been validated against Vault, and CI actively guards against
Vault SDK dependencies creeping back in.

## Can I use this against GitHub Enterprise Server instead of github.com?

Yes — set `base_url` on `github/config` to your GHES instance's API base (typically ending in
`/api/v3`). See [Configuration](configuration.md).

## Why doesn't `github/config` have an `installation_id` field?

Because one App configuration can back tokens for every installation of that App, and which
installation a given token is for is a per-request decision, not a global one. Supply
`installation_id` (or `org_name`) on each `github/token` call, or fix it inside a
[permission set](permission-sets.md). See [Configuration](configuration.md).

## Can a permission set grant access to repositories in a different organization?

No. A permission set — like a direct token request — resolves to exactly one App installation, and
`repositories`/`repository_ids` only narrow the token within that installation. Reaching a
different owner means pointing the set at a different `installation_id` (or `org_name`), not
adding more repository names to the existing one. See
[Permission Sets](permission-sets.md#repositories-is-scoped-within-an-installation-not-across-it).

## How long do minted tokens last, and can I make them last longer?

Token lifetime is set by GitHub, not by this engine — currently about an hour for a GitHub App
installation token. There is no field on this engine to extend it; the OpenBao lease attached to
the response simply mirrors GitHub's own `expires_at`. See [Security](security.md).

## Can I read back the GitHub App's private key after configuring it?

No. `GET github/config` always reports the `prv_key` field as `<configured>` (or `""` if unset) —
never the key material. This is deliberate; see [Security](security.md).

## Does revoking an OpenBao lease actually invalidate the token at GitHub?

Yes. Revocation sends a `DELETE` to GitHub's installation-token revocation endpoint using the
token itself, so the token stops working at GitHub immediately rather than simply being forgotten
by OpenBao.

## Why is `github/metrics` reachable without an OpenBao token?

So a Prometheus scraper or health check doesn't need its own OpenBao credential just to pull
metrics. It's marked unauthenticated alongside `github/info`; neither path returns any credential,
configuration value, or token. See [Security](security.md#unauthenticated-paths).
