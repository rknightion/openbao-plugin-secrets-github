# OpenBao GitHub App secrets engine review

The engine issues permission-scoped installation tokens. Keep the App key within the
engine and out of responses, logs and metrics. Review `github/backend.go` when adding or
changing an endpoint. Only info and metrics are unauthenticated. Use the existing field
validation for operations that accept input.

Treat changes in `github/path_token*.go`, `github/path_permission_set.go`, and
`github/path_config.go` as authorization changes. Preserve the separation between direct
requests and permission-set requests so an authorized caller cannot expand the stored
installation, repositories or permissions. Preserve existing path names and scope because
external ACLs distinguish these interfaces. Check that configuration writes invalidate
cached clients only when configuration changes.

Keep token leases tied to the provider's expiry and preserve revocation semantics in
`github/revocation.go`. Never introduce a path that reports credentials through errors,
logs or metrics. Review `go.mod` and `.github/workflows/publish.yml` for effects on the
hash-pinned plugin binary and its release metadata.

`just check` covers formatting, vet (including compilation of the integration tag), the
Vault-import guard, the module-toolchain vulnerability audit and race tests. Report
behavior those checks miss. Use local in-memory backend tests for the changed contract.
The live integration suite requires separate operator approval and credentials.
