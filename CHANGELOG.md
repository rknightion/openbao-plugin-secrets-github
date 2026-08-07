# Changelog

## [0.1.1](https://github.com/rknightion/openbao-plugin-secrets-github/compare/v0.1.0...v0.1.1) (2026-08-07)


### Bug Fixes

* attach release assets via gh release upload, not action-gh-release ([d51b756](https://github.com/rknightion/openbao-plugin-secrets-github/commit/d51b75697f4cc026554098b7e0e4eb21d93554f2)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)
* restore linker-injected build metadata dropped with .goreleaser.yml ([515a239](https://github.com/rknightion/openbao-plugin-secrets-github/commit/515a2392f8714295b812c2a6800afc49160aeb16)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)
* split publish out of release.yml, gated on the release event not action outputs ([48f9f1e](https://github.com/rknightion/openbao-plugin-secrets-github/commit/48f9f1ed8216f4f4a0d5f60bff45c5d1fb71c7cc)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)
* use the release-please PAT to update an existing release's assets ([4751660](https://github.com/rknightion/openbao-plugin-secrets-github/commit/47516609b38a64fb91deae4d2437c9372418dca1)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)

## 0.1.0 (2026-08-07)


### ⚠ BREAKING CHANGES

* port to the OpenBao SDK

### Features

* add hashed token to responses for correlation with GitHub audit logs ([#163](https://github.com/rknightion/openbao-plugin-secrets-github/issues/163)) ([0ee76ab](https://github.com/rknightion/openbao-plugin-secrets-github/commit/0ee76ab625aaa0fa5fbd36074e662caf016c90b9))
* added a configuration key [hide_repository_metadata] that, if set to true, will minimize the [token.data.repositories] to [token.data.repositories.names] to avoid high memory consumption ([#114](https://github.com/rknightion/openbao-plugin-secrets-github/issues/114)) ([9bfbd38](https://github.com/rknightion/openbao-plugin-secrets-github/commit/9bfbd38431cd4fc3b2403975dd2b63841668a7f3))
* initializes proxy for Transport if needed ([#146](https://github.com/rknightion/openbao-plugin-secrets-github/issues/146)) ([6ddeeb4](https://github.com/rknightion/openbao-plugin-secrets-github/commit/6ddeeb43cc95a3bdbb23d7cf99cebb89245db1b8))
* port to the OpenBao SDK ([8f44f3f](https://github.com/rknightion/openbao-plugin-secrets-github/commit/8f44f3f16d90e07297d0d7fc55165140c61d43cf)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)


### Bug Fixes

* client timeouts with &gt;250 repositories ([#161](https://github.com/rknightion/openbao-plugin-secrets-github/issues/161)) ([5ce15ec](https://github.com/rknightion/openbao-plugin-secrets-github/commit/5ce15ecfa5a054a150267a9322d76f2815ee3e62))
* drop stale upstream config and restart module versioning at v0.1.0 ([d850cef](https://github.com/rknightion/openbao-plugin-secrets-github/commit/d850cef87d40781d4f1cbdd74001930d3f65b5b0)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)
* keep release-please in 0.x territory for breaking-change commits ([c798aac](https://github.com/rknightion/openbao-plugin-secrets-github/commit/c798aaca7fc049f677423aa962b6b63eb2fb5963)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)
* pin the first release-please release to 0.1.0 ([5c02fbc](https://github.com/rknightion/openbao-plugin-secrets-github/commit/5c02fbcd1b198f624c99fdb35b2299aab2080caa)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)
* Use a case-insensitive organization name lookup ([#156](https://github.com/rknightion/openbao-plugin-secrets-github/issues/156)) ([109f340](https://github.com/rknightion/openbao-plugin-secrets-github/commit/109f340c4955450c25113e941f97b5555686544c))
