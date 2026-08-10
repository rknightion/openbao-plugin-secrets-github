---
title: Getting Started
description: Register the plugin, configure a GitHub App, and mint your first installation token.
---

# Getting Started

This walks through registering the plugin with OpenBao, configuring it against a GitHub App, and
minting a first installation token.

## Prerequisites

- An **OpenBao** server you can administer (`bao` CLI or equivalent API access), version 2.5 or
  later — see [Installation](installation.md#openbao-version-compatibility) for why.
- A **GitHub App** already created and installed on the organization or repositories you want to
  issue tokens for. You need:
    - The App's **numeric App ID**.
    - The App's **private key**, in PEM PKCS#1 `RSA PRIVATE KEY` format (the format GitHub
      generates when you download the App's private key).
    - Either the **installation ID** (visible in the installation's settings URL) or the
      **organization name** the App is installed into.
- The plugin binary registered in OpenBao's plugin catalog — see
  [Installation](installation.md) if you have not done this yet.

## 1. Enable the secrets engine

```sh
bao secrets enable -path=github -plugin-name=openbao-plugin-secrets-github plugin
```

`-path=github` is a convention, not a requirement — every path in this guide assumes it. Mount it
somewhere else and adjust the paths accordingly.

## 2. Configure the GitHub App

```sh
bao write github/config \
    app_id=123456 \
    prv_key=@path/to/app-private-key.pem
```

`prv_key` must be the App's private key in PEM PKCS#1 format — the engine rejects anything else at
write time. See [Configuration](configuration.md) for every field, including `base_url` (for
GitHub Enterprise Server) and `exclude_repository_metadata`.

Confirm it took:

```sh
bao read github/config
```

The response never echoes the private key back — a configured key reads as `<configured>`.

## 3. Mint a token

With just an installation ID:

```sh
bao read github/token installation_id=87654321
```

Or by organization name (costs one extra round trip to GitHub to resolve the installation ID —
prefer `installation_id` when you already have it):

```sh
bao read github/token org_name=my-org
```

Narrow the token to specific repositories and permissions:

```sh
bao write github/token \
    org_name=my-org \
    repositories=my-repo,another-repo \
    permissions=contents=read,pull_requests=write
```

The response is the GitHub App installation token payload — `token`, `expires_at`, the granted
`permissions` and `repositories` — plus `installation_id` (and `org_name` if you supplied one) and
a `hashed_token` (a SHA-256 digest of the token, useful for correlating with GitHub's audit log
without storing the token itself). OpenBao attaches a lease matching GitHub's `expires_at`, so
`bao lease revoke` on it revokes the token at GitHub immediately.

!!! tip "Prefer a permission set for anything automation calls"
    The commands above accept whatever scope the caller asks for. For CI and other automation,
    define a [permission set](permission-sets.md) instead and restrict callers to
    `github/token/<name>` by OpenBao policy — see [Security](security.md) for why the bare
    `github/token` path should not be reachable by an untrusted caller.

## Next steps

- [Installation](installation.md) — build the binary, the container image, or register a released
  build with a verified checksum.
- [Configuration](configuration.md) — the full field reference.
- [Permission sets](permission-sets.md) — fix a token's scope server-side.
- [Reference: API](reference/api.md) — every path this engine exposes.
- [Security](security.md) — the threat model this engine is built around.
