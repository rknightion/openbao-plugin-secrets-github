# Changelog

## [3.0.0](https://github.com/rknightion/openbao-plugin-secrets-github/compare/v2.2.2...v3.0.0) (2026-08-07)


### ⚠ BREAKING CHANGES

* port to the OpenBao SDK

### Features

* add hashed token to responses for correlation with GitHub audit logs ([#163](https://github.com/rknightion/openbao-plugin-secrets-github/issues/163)) ([0ee76ab](https://github.com/rknightion/openbao-plugin-secrets-github/commit/0ee76ab625aaa0fa5fbd36074e662caf016c90b9))
* added a configuration key [hide_repository_metadata] that, if set to true, will minimize the [token.data.repositories] to [token.data.repositories.names] to avoid high memory consumption ([#114](https://github.com/rknightion/openbao-plugin-secrets-github/issues/114)) ([9bfbd38](https://github.com/rknightion/openbao-plugin-secrets-github/commit/9bfbd38431cd4fc3b2403975dd2b63841668a7f3))
* initializes proxy for Transport if needed ([#146](https://github.com/rknightion/openbao-plugin-secrets-github/issues/146)) ([6ddeeb4](https://github.com/rknightion/openbao-plugin-secrets-github/commit/6ddeeb43cc95a3bdbb23d7cf99cebb89245db1b8))
* port to the OpenBao SDK ([8f44f3f](https://github.com/rknightion/openbao-plugin-secrets-github/commit/8f44f3f16d90e07297d0d7fc55165140c61d43cf)), closes [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1)


### Bug Fixes

* client timeouts with &gt;250 repositories ([#161](https://github.com/rknightion/openbao-plugin-secrets-github/issues/161)) ([5ce15ec](https://github.com/rknightion/openbao-plugin-secrets-github/commit/5ce15ecfa5a054a150267a9322d76f2815ee3e62))
* Use a case-insensitive organization name lookup ([#156](https://github.com/rknightion/openbao-plugin-secrets-github/issues/156)) ([109f340](https://github.com/rknightion/openbao-plugin-secrets-github/commit/109f340c4955450c25113e941f97b5555686544c))
