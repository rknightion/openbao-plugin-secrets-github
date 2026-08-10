---
title: Configuration
description: Every field on the openbao-plugin-secrets-github config endpoint, its type, default, and validation behaviour.
---

# Configuration

The engine has exactly one piece of configuration state, written and read at `github/config`
(adjust the path prefix if you mounted the engine somewhere other than `github`). There is no
environment-variable layer and no separate config file — everything is set through this one
OpenBao path.

## `github/config`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `app_id` | integer | yes | — | The GitHub App's numeric Application ID. |
| `prv_key` | string | yes | — | The App's private key for signing GitHub access token requests (JWTs). Must be PEM PKCS#1 `RSA PRIVATE KEY` format — anything else is rejected at write time. |
| `base_url` | string | no | `https://api.github.com` | Base URL for GitHub API requests. Set this to a GitHub Enterprise Server instance's API base to target GHES instead of github.com. Must be a valid absolute URL — an unparseable value is rejected at write time. |
| `exclude_repository_metadata` | boolean | no | `false` | When `true`, trims a token response's `repositories` list down to bare repository names instead of full repository metadata objects, reducing response size and memory use for installations with many repositories. |

There is **no `installation_id` field on this config path**. Installation ID is supplied per
request — either directly on [`github/token`](reference/api.md#post-githubtoken), resolved from
`org_name` on the same path, or fixed inside a [permission set](permission-sets.md). One App
configuration can mint tokens for any installation of that App; which installation is a per-call
decision, not a global setting.

### Write behaviour

- A write only persists to storage if it actually changes a value — writing the same config twice
  is a no-op on the second call, and does not invalidate the cached GitHub client.
- Any successful write (that does change something) invalidates the engine's cached GitHub client,
  so the next token request builds a fresh client from the new configuration.
- `CREATE` and `UPDATE` behave identically — this predates the OpenBao framework's existence-check
  support, so use either interchangeably.
- Deleting the config (`bao delete github/config`) removes the stored configuration entirely and
  also invalidates the cached client. Reading config afterward returns an engine still bound to the
  default `base_url`, but with no `app_id` or `prv_key` — token requests will fail until it is
  reconfigured.

### Read behaviour

`bao read github/config` never returns the private key's value. If one is configured, the
`prv_key` field in the response reads as the literal string `<configured>`; if none is configured,
it reads as an empty string.

### Validation

- `prv_key` is parsed as PEM and then as a PKCS#1 RSA private key at write time. A key that fails
  either parse is rejected with a 400 before it is ever persisted.
- `base_url` is parsed with `url.ParseRequestURI` at write time; an unparseable value is rejected
  with a 400.
- An unrecognized field name in the request body is rejected outright (400, naming the unknown
  field(s)) — every write path on this engine validates the request against its schema before
  doing anything else.

## Example

```sh
bao write github/config \
    app_id=123456 \
    prv_key=@app-private-key.pem \
    base_url=https://github.example.com/api/v3 \
    exclude_repository_metadata=true
```

Omit `base_url` to use the public GitHub API.
