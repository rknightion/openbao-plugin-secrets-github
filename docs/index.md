---
title: openbao-plugin-secrets-github — GitHub App tokens from OpenBao
description: OpenBao secrets engine that mints short-lived, permission-scoped GitHub App installation tokens without ever exposing the App's private key.
image: assets/social-card.png
---

# openbao-plugin-secrets-github

**A GitHub App private key that never leaves OpenBao.** `openbao-plugin-secrets-github` is a
secrets engine plugin for [OpenBao](https://openbao.org) that mints short-lived, permission-scoped
GitHub App installation tokens on demand. The App's private key is stored once, inside OpenBao's
storage backend, and is never returned to a caller — clients only ever receive the resulting
`ghs_` token.

## The security property that matters

A GitHub App private key handed out as a CI secret can be read by any code running in that
workflow, reused from anywhere it ends up, and stays valid until someone rotates it. Brokering
token issuance through OpenBao changes that shape:

- **The private key is a write-once secret.** It is configured on the engine and read back only
  as `<configured>`, never as its value (see [Configuration](configuration.md)).
- **Tokens are short-lived.** Each token inherits GitHub's own expiry (typically about an hour)
  as an OpenBao lease, and is revocable on demand — revoking the lease calls GitHub's own token
  revocation endpoint.
- **Tokens are scoped, not ambient.** A request can be narrowed to specific repositories,
  repository IDs, and a set of permissions, so a compromised caller only ever holds what it asked
  for and was allowed to ask for. [Permission sets](permission-sets.md) let an operator fix that
  scope server-side, so a caller can't request more than it was given.

## When to use this over a PAT

Reach for this engine when a workflow, service, or automation needs to act as a GitHub App
installation and you want that access to be short-lived, scoped, and centrally revocable — the
same shape as a Vault/OpenBao dynamic secret, applied to GitHub. It is a better fit than a
personal access token or a long-lived fine-grained PAT whenever:

- The credential is used by automation (CI, a service account, a bot) rather than a human at a
  terminal.
- You want a compromised caller to be limited to a bounded set of repositories and permissions,
  not "everything the App can see."
- You want to revoke access by revoking a lease, not by hunting down and rotating a secret that
  may have been copied elsewhere.

## Start here

<div class="grid cards" markdown>

- **[Getting started](getting-started.md)** — register the plugin, configure the App, mint a
  first token.
- **[Installation](installation.md)** — building the binary, the container image, the Nix flake,
  and plugin registration.
- **[Configuration](configuration.md)** — every config field, its default, and what it does.
- **[Permission sets](permission-sets.md)** — fix a token's scope server-side so a caller can't
  widen it.

</div>

## Origin

This project is an independently maintained fork of
[`martinbaillie/vault-plugin-secrets-github`](https://github.com/martinbaillie/vault-plugin-secrets-github)
(Apache-2.0), ported to the OpenBao SDK. It is tracked against upstream via a git `upstream`
remote, but it is not part of GitHub's fork network and this site is not a copy of upstream's
docs — everything here describes this repository's own code and API surface as it exists today.

## Project

Source, releases and the issue tracker live on
[GitHub](https://github.com/rknightion/openbao-plugin-secrets-github). Licensed Apache-2.0 — see
`LICENSE` and `NOTICE` in the repository.
