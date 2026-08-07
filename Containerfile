FROM scratch

ARG TARGETOS
ARG TARGETARCH

LABEL org.opencontainers.image.source=https://github.com/rknightion/openbao-plugin-secrets-github
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.description="OpenBao secrets engine for scoped, short-lived GitHub App installation tokens"

COPY dist/openbao-plugin-secrets-github_${TARGETOS}_${TARGETARCH} /openbao-plugin-secrets-github

ENTRYPOINT ["/openbao-plugin-secrets-github"]
