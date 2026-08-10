---
title: Observability
description: The shipped Prometheus metrics and Grafana dashboard, and how to import them.
---

# Observability

## Metrics

`GET /github/metrics` (see [Reference: API](reference/api.md#get-githubmetrics)) serves
Prometheus exposition-format text and is unauthenticated on the OpenBao path — point a Prometheus
scrape job at it directly. Metric names carry the `vault_github_token_` prefix (retained from
upstream for scrape-config compatibility).

| Metric | Type | Labels | Description |
|---|---|---|---|
| `vault_github_token_request_duration_seconds` | summary | `success`, `installation_id`, `org_name`, `permissions`, `repository_ids`, `repositories` | Duration of `github/token` and `github/token/:permissionset` requests. The label values for `permissions`/`repository_ids`/`repositories` are booleans (`true`/`false`) indicating whether that constraint was present on the request, not their content. |
| `vault_github_token_installations_duration_seconds` | summary | `success` | Duration of `github/installations` requests. |
| `vault_github_token_revocation_request_duration_seconds` | summary | `success` | Duration of token revocation calls to GitHub. |
| `vault_github_token_build_info` | gauge (constant `1`) | `version`, and other standard build-info labels | Identifies the running plugin build. |

Standard Go runtime metrics are also registered globally (`go_*`, `process_*`) alongside the
metrics above.

## Grafana dashboard

`dashboard.json` at the repository root is a ready-to-import Grafana dashboard built against these
metrics. It shows:

- **Token creation successes over period** — count of successful `github/token` requests in the
  selected time range.
- **Token creation failures over period** — count of failed requests, surfaced only when non-zero.
- **Plugin version** — the currently reporting `vault_github_token_build_info` version label.
- **Token creation latency** — request-duration quantiles over time.

### Importing it

1. In Grafana, go to **Dashboards → New → Import**.
2. Upload `dashboard.json` from the repository (or paste its contents).
3. When prompted, map the `DS_PROMETHEUS` input to the Prometheus datasource that scrapes
   `github/metrics`.

The dashboard expects the metrics above to already be present under their `vault_github_token_*`
names, so point Prometheus at the OpenBao path first and let at least one scrape interval pass
before checking the import.
