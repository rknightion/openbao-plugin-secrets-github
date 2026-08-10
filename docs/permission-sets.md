---
title: Permission Sets
description: Fix a token's installation, repositories and permissions server-side so a caller cannot widen its own scope.
---

# Permission Sets

`github/token` (see [Reference: API](reference/api.md#post-githubtoken)) mints a token scoped to
whatever the caller asks for in the request — that's fine when the caller is trusted with a broad
grant, but it means anyone who can reach that path can request any scope the App itself holds. A
**permission set** moves that decision to the operator: it stores a fixed token request under a
name, and a caller mints against the name instead of specifying its own scope.

## Creating a permission set

```sh
bao write github/permissionset/ci-release \
    org_name=my-org \
    repositories=my-repo \
    permissions=contents=write,pull_requests=write
```

Or by installation ID directly, which avoids the extra GitHub round trip to resolve an
organization name:

```sh
bao write github/permissionset/ci-release \
    installation_id=87654321 \
    repositories=my-repo \
    permissions=contents=write,pull_requests=write
```

Either `installation_id` or `org_name` is required; if both are given, `installation_id` takes
precedence. The same `repositories`, `repository_ids`, and `permissions` fields from
[`github/token`](reference/api.md#post-githubtoken) apply here — they're stored, not requested.

Minting a token from the set takes no scope arguments at all:

```sh
bao read github/token/ci-release
```

The response is identical in shape to a direct `github/token` call, using the stored request.

## `repositories` is scoped within an installation, not across it

A permission set (like a direct token request) resolves to exactly **one** GitHub App
installation — either the `installation_id` you gave it, or the one that `org_name` resolves to.
`repositories` and `repository_ids` then narrow the token to a subset of repositories **within
that installation**.

This means `repositories` cannot be used to reach across organizations or accounts: an
installation belongs to one org/user, and every repository name or ID in the set must belong to
that same installation. If you need to grant access to repositories under a different owner, you
change the permission set's `installation_id` (or `org_name`) — a different installation, not a
longer repository list on the same one. Two owners means two permission sets, each pointing at its
own installation.

## Managing permission sets

```sh
bao read github/permissionset/ci-release      # inspect the stored request
bao list github/permissionsets                # list every stored permission set name
bao delete github/permissionset/ci-release     # remove it
```

`CREATE` and `UPDATE` on `github/permissionset/<name>` behave identically — writing to a name that
already exists overwrites the stored token request in place.

## Why bother, when `github/token` can do the same thing

A permission set exists so the *shape* of a token — which installation, which repositories, which
permissions — is fixed by whoever manages the OpenBao policy, not by whoever holds a token to call
the API. Combined with an OpenBao policy that grants a caller access to
`github/token/ci-release` but not the bare `github/token` path, a caller can mint tokens all day
and never be able to ask for anything beyond what that name was built to grant. See
[Security](security.md) for the full argument for denying the bare path by policy.
