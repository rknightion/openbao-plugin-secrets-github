---
title: Installation
description: Build the plugin binary, container image, or Nix package, and register it with OpenBao including the SHA256 checksum step.
---

# Installation

There are three ways to get a `openbao-plugin-secrets-github` binary, and one final step —
registering it with OpenBao — that every route ends with.

## Option A: build from source

```sh
just setup
just check
just build
```

Requires the Go version pinned in `go.mod`; `just build` produces an unstripped binary with no build
metadata baked in. The `/github/info` path (see [Reference: API](reference/api.md#get-githubinfo))
will report empty version fields unless you inject them yourself with `-ldflags`, matching what the
release build does (see `.github/workflows/publish.yml` in the repository for the exact `-X`
injections against `github.projectName`, `github.projectVersion`, `github.projectDocs`, and the
`prometheus/common/version` package).

## Option B: prebuilt container image

Released versions publish a `scratch`-based container image:

```sh
docker pull ghcr.io/rknightion/openbao-plugin-secrets-github:v0.1.2
```

The image contains nothing but the statically linked binary at `/openbao-plugin-secrets-github` —
no shell, no package manager. Pull the binary back out if you need it standalone:

```sh
docker create --platform linux/amd64 --name extract ghcr.io/rknightion/openbao-plugin-secrets-github:v0.1.2
docker cp extract:/openbao-plugin-secrets-github ./openbao-plugin-secrets-github
docker rm extract
```

Images are built for `linux/amd64` and `linux/arm64`.

## Option C: the Nix flake

```sh
nix build
```

`flake.nix` also exposes a dev shell (`nix develop`) with a devshell menu covering linting, unit
and integration testing, and a helper that spins up a background `bao`/`vault`-compatible dev
server with the freshly built plugin already registered in its catalog — see the `integration` and
`integration-server` commands in the flake for the exact steps if you want to reproduce that
locally rather than by hand.

## Registering the plugin with OpenBao

### OpenBao 2.5+: let OpenBao fetch it

OpenBao 2.5 and later can pull plugin images itself. In `openbao.hcl`:

```hcl
plugin_directory = "/openbao/plugins"

plugin "secret" "github" {
  image       = "ghcr.io/rknightion/openbao-plugin-secrets-github"
  version     = "v0.1.2"
  binary_name = "openbao-plugin-secrets-github"
  sha256sum   = "<binary sha256 from the release checksums file>"
}
```

`sha256sum` is the checksum of the extracted **binary**, not the container image's digest — take
it from the release's `checksums.txt` on GitHub, matching your platform
(`openbao-plugin-secrets-github_linux_amd64` or `_linux_arm64`).

`plugin_directory` must be writable by the OpenBao process. If OpenBao runs with a read-only root
filesystem, mount a writable volume at that path.

### Manual registration (any OpenBao/Vault-compatible version)

Place the binary in the configured `plugin_directory`, then register it in the catalog with its
checksum:

```sh
sha256sum /openbao/plugins/openbao-plugin-secrets-github
bao write sys/plugins/catalog/secret/openbao-plugin-secrets-github \
    sha_256=<sha256 from the command above> \
    command=openbao-plugin-secrets-github
```

Then enable it as a secrets engine:

```sh
bao secrets enable -path=github -plugin-name=openbao-plugin-secrets-github plugin
```

## OpenBao version compatibility

The plugin is built against the OpenBao Go SDK (`github.com/openbao/openbao/sdk/v2`) and served
with `plugin.ServeMultiplex`, OpenBao's multiplexing plugin protocol. The self-managed
`sys/plugins/catalog` registration path works against any OpenBao (or HashiCorp Vault) release
that speaks the same plugin protocol; the `plugin "secret" "github"` declarative block in
`openbao.hcl` — which fetches and verifies the image for you — requires **OpenBao 2.5 or later**.

CI verifies the source tree carries no `hashicorp/vault` SDK import, so the plugin only ever
depends on the OpenBao SDK — a stray Vault SDK import would be a regression toward the pre-fork
codebase, not a compatibility feature.
