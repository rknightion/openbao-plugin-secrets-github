# openbao-plugin-secrets-github

OpenBao secrets engine that mints short-lived, permission-scoped GitHub App installation tokens.
Fork of `martinbaillie/vault-plugin-secrets-github` ported to the OpenBao SDK. Ships as an OCI image
(`ghcr.io/rknightion/openbao-plugin-secrets-github`) plus release binaries.

## This tracker is for the PLUGIN only

**Do not file homelab, deployment or broker-rollout issues here.** Rob's OpenBao deployment on camden
— server config, ACL policies, tailnet identity, per-repo JWT roles, CI onboarding — is documented in
`~/repos/chat-personal/camden/openbao/`, and that is where its history and decisions belong.

This is a correction, not a preconception: issues #22 (tailnet identity), #23 (the OIDC/CI rollout)
and #26 (splitting the `admin` policy) were all filed here, and all three were **deleted on
2026-08-11** after being archived verbatim to
`~/repos/chat-personal/camden/openbao/archive/github-issues/`. Nothing about them was a code change
to this repo. The CHANGELOG entry for `f2c66f0` still links to the now-deleted #23.

In scope here: the Go engine, its tests, CI/release workflows, the docs site, dependency bumps.
The line to apply: **would this change a file in this repo?** If no, it goes in `chat-personal`.

## Release and deploy coupling

The one place the two genuinely meet, and it is a trap worth knowing before cutting a release:
`go build` stamps the commit SHA into the binary, so **the binary hash is a function of commit +
build inputs, not source alone**, and camden pins that hash with `plugin_download_behavior = "fail"`.
Re-running publish for a version camden has already pinned can produce a different hash and stop
OpenBao from starting. Never re-publish an existing version — cut a new one. Full bump procedure:
`~/repos/chat-personal/camden/openbao/runbooks/UPDATE-ROLLBACK.md`.
