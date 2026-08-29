set shell := ["bash", "-euo", "pipefail", "-c"]

# show the task surface
default:
    @just --list

# install the Go module dependencies and local task tools idempotently
setup:
    go mod download
    command -v golangci-lint >/dev/null || go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
    command -v govulncheck >/dev/null || go install golang.org/x/vuln/cmd/govulncheck@latest
    command -v goimports >/dev/null || go install golang.org/x/tools/cmd/goimports@latest

# format Go source and this justfile in place
[group('check')]
fmt:
    gofmt -l -s -w .
    goimports -w .
    just --fmt

# verify Go source and this justfile are formatted without mutating files
[group('check')]
fmt-check:
    @test -z "$(gofmt -l -s .)" || { gofmt -l -s .; echo "run: just fmt"; exit 1; }
    @test -z "$(goimports -l .)" || { goimports -l .; echo "run: just fmt"; exit 1; }
    just --fmt --check

# run static analysis and compile the integration-test build tag
[group('check')]
[no-exit-message]
lint:
    golangci-lint run ./...
    go vet ./...
    go vet -tags integration ./...

# verify this fork never re-imports the HashiCorp Vault SDK
[group('check')]
[no-exit-message]
verify-no-vault-sdk:
    ! grep -rn "hashicorp/vault" --include='*.go' .

# scan dependencies with the module's own Go toolchain, not govulncheck-action
[group('check')]
[no-exit-message]
audit:
    govulncheck ./...

# build a local development binary without release metadata
[group('build')]
build:
    go build -o openbao-plugin-secrets-github .

# run the test suite; pass an optional top-level test filter
[group('check')]
test filter="":
    go build ./...
    go test -race -coverprofile=coverage.out {{ if filter == "" { "./..." } else { "-run " + quote(filter) + " ./..." } }}

# run the full local pull-request gate
[group('check')]
check: fmt-check lint verify-no-vault-sdk audit test

# build the linux/amd64 binary and Containerfile image without pushing
[group('build')]
image tag="openbao-plugin-secrets-github:dev":
    mkdir -p dist
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o dist/openbao-plugin-secrets-github_linux_amd64 .
    docker buildx build --platform linux/amd64 -t {{ tag }} -f Containerfile .

# run check plus image, which needs a Docker daemon for docker buildx
[group('check')]
ci: check image
