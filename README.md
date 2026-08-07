# openbao-plugin-secrets-github

An [OpenBao](https://openbao.org) secrets engine that mints short-lived,
permission-scoped GitHub App installation tokens. The App's private key stays
inside OpenBao and is never handed to a client.

This is a fork of
[`martinbaillie/vault-plugin-secrets-github`](https://github.com/martinbaillie/vault-plugin-secrets-github)
(Apache-2.0) ported to the OpenBao SDK. The engine's API is unchanged from
upstream — see upstream's README for the full path reference. Track upstream
via the `upstream` git remote.

## Why

A GitHub App private key stored as a CI secret can be read by any code running
in that workflow, used from anywhere, and stays valid until rotated. Brokering
it means a workflow authenticates by OIDC and receives a token that expires in
about an hour and carries only the permissions that workflow declared.

## Install

OpenBao 2.5+ can download the plugin itself. In `openbao.hcl`:

```hcl
plugin_directory = "/openbao/plugins"

plugin "secret" "github" {
  image       = "ghcr.io/rknightion/openbao-plugin-secrets-github"
  version     = "v0.1.1"
  binary_name = "openbao-plugin-secrets-github"
  sha256sum   = "<binary sha256 from the release checksums file>"
}
```

The `sha256sum` is the checksum of the **binary**, not the image digest. Take
it from the release's `checksums.txt`, matching your platform.

`plugin_directory` must be writable by the OpenBao process. If you run OpenBao
with a read-only root filesystem, mount a writable volume there.

## Build

```bash
go build -o openbao-plugin-secrets-github .
go test ./...
```

## Licence

Apache-2.0. See `LICENSE` and `NOTICE`.
