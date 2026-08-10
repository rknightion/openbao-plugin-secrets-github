---
title: API Reference
description: Every path openbao-plugin-secrets-github exposes, its parameters, and its response shape.
---

# API Reference

All paths are relative to the engine's mount point. Every example below assumes the conventional
`github/` mount used elsewhere in this documentation. `bao read`/`bao write` map to OpenBao's
`GET`/`POST` HTTP API the same way they do for any other secrets engine.

Two paths are marked **unauthenticated** below: OpenBao serves them without requiring the caller
to present a valid OpenBao token. Every other path requires normal OpenBao authentication and
policy authorization.

## `GET /github/info`

**Unauthenticated.** Returns build and project information about the running plugin.

**Parameters:** none.

**Response fields:**

| Field | Description |
|---|---|
| `project_name` | The plugin's project name, injected at build time. |
| `project_docs` | A link to the project's documentation, injected at build time. |
| `build_version` | The built version string. |
| `build_revision` | The VCS revision (commit SHA) the binary was built from. |
| `build_branch` | The branch the binary was built from. |
| `build_date` | The build timestamp. |
| `build_user` | The user/system that produced the build. |

A binary built without the release `-ldflags` injections (a plain `go build`, for example) returns
empty strings for these fields — see [Installation](../installation.md#option-a-build-from-source).

## `GET /github/metrics`

**Unauthenticated.** Returns Prometheus exposition-format metrics for this engine instance. See
[Observability](../observability.md) for what's in it and how to visualize it.

**Parameters:** none.

**Response:** `text/plain` Prometheus exposition format, not a JSON logical response.

## `github/config`

Engine configuration. See [Configuration](../configuration.md) for the full field reference,
defaults, and validation rules.

### `POST /github/config` (create/update)

**Parameters:**

| Field | Type | Required |
|---|---|---|
| `app_id` | int | yes |
| `prv_key` | string | yes |
| `base_url` | string | no |
| `exclude_repository_metadata` | bool | no |

Returns no response body on success. `CREATE` and `UPDATE` are equivalent.

### `GET /github/config` (read)

**Response fields:** `app_id`, `base_url`, `exclude_repository_metadata`, and `prv_key` (returned
as the literal string `<configured>` if a key is set, or `""` otherwise — the raw key is never
returned).

### `DELETE /github/config`

Removes the stored configuration and invalidates the cached GitHub client. No response body.

## `POST /github/token`

Mint a GitHub App installation token with a caller-specified scope. `GET`, `POST` and the
equivalent `UPDATE` operation all behave identically on this path — a plain `bao read` mints a
fresh token just as a write does, regardless of HTTP verb.

**Parameters:**

| Field | Type | Required | Description |
|---|---|---|---|
| `installation_id` | int | one of `installation_id`/`org_name` | The App installation ID to mint against. Takes precedence over `org_name` if both are set. |
| `org_name` | string | one of `installation_id`/`org_name` | Organization name the App is installed into. Resolved to an installation ID via one extra GitHub API round trip (case-insensitive match). |
| `repositories` | comma-separated string list | no | Repository names (short names, not `owner/repo`) to scope the token to, within the resolved installation. |
| `repository_ids` | comma-separated int list | no | Repository IDs to scope the token to, within the resolved installation. |
| `permissions` | comma-separated `key=value` pairs | no | Permission names mapped to `read` or `write`. See [GitHub's permissions reference](https://developer.github.com/v3/apps/permissions). |

At least one of `installation_id` or `org_name` is required; omitting both returns an error
response (not an OpenBao-level 400 — a `logical.ErrorResponse`).

**Response fields:** the GitHub installation access token API response (`token`, `expires_at`,
`permissions`, `repositories`, etc. — see
[GitHub's create-an-installation-access-token docs](https://docs.github.com/en/rest/apps/apps#create-an-installation-access-token-for-an-app)
for the full upstream shape), plus:

| Field | Description |
|---|---|
| `installation_id` | The installation ID the token was minted against (always present, even if you supplied `org_name`). |
| `org_name` | Echoed back only if you supplied it in the request. |
| `hashed_token` | SHA-256 digest of the token, base64-encoded — for correlating with GitHub audit-log entries without storing the raw token. |

If `exclude_repository_metadata` is set on the engine config, `repositories` in the response is
reduced to bare names rather than full repository objects.

**Lease:** the response carries an OpenBao lease whose TTL is computed from GitHub's `expires_at`
(time remaining until expiry at the moment of the call). Revoking the lease
(`bao lease revoke <lease_id>`) calls GitHub's token revocation endpoint immediately — see
[Revocation](#revocation-secret-type-github_token) below.

## `github/permissionset/:name`

Store, inspect, or remove a named, fixed token request. See
[Permission Sets](../permission-sets.md) for the concept and why you'd use it.

### `POST /github/permissionset/:name` (create/update)

Same field set as `github/token` above (`installation_id`, `org_name`, `repositories`,
`repository_ids`, `permissions`), stored under `:name` rather than used immediately. `CREATE` and
`UPDATE` are equivalent — writing an existing name overwrites the stored request.

### `GET /github/permissionset/:name` (read)

Returns the stored token-request fields for `:name`: `installation_id`, `org_name`, `repositories`,
`repository_ids`, `permissions`. Reading a name that doesn't exist returns an empty response, not
an error.

### `DELETE /github/permissionset/:name`

Removes the stored permission set.

## `LIST /github/permissionsets`

Lists the names of every stored permission set (`bao list github/permissionsets`).

**Parameters:** none.

**Response:** a `keys` array of permission set names.

## `POST /github/token/:permissionset` (also readable via `GET`)

Mint a token using a stored [permission set](../permission-sets.md)'s fixed request — no scope
parameters accepted; the request always comes from what was stored under `:permissionset`.

**Parameters:**

| Field | Type | Required |
|---|---|---|
| `permissionset` | string (path segment) | yes |

Requesting a `:permissionset` that does not exist returns an error response naming the missing
set. Response shape is identical to `github/token` above.

## Revocation (secret type `github_token`)

Every token minted by this engine is registered as an OpenBao secret of internal type
`github_token`. Revoking the corresponding lease sends a `DELETE` to GitHub's installation-token
revocation endpoint with the token as a bearer credential. GitHub has no token *renewal*
mechanism, so this secret type supports revoke only — there is no renew callback.

A revocation is treated as successful both when GitHub returns 2xx and when it returns 401 (which
GitHub returns for a token that no longer exists — already revoked or already expired), since both
outcomes mean the token is no longer usable.
