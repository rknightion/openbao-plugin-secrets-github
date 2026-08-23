---
id: OBG-0001
title: Upgrade Go toolchain to 1.27
status: In Progress
assignee: []
created_date: '2026-08-23 19:06'
updated_date: '2026-08-23 19:49'
labels: []
dependencies: []
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Adopt Go 1.27 consistently across the application, nested modules, build images, CI configuration, setup automation, and version-specific contributor documentation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All active Go module and toolchain pins require Go 1.27
- [x] #2 Build images, CI jobs, setup automation, and current documentation agree with the Go 1.27 requirement
- [x] #3 The repository green-bar validation passes under Go 1.27
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 go build ./... && go test -race ./... && go vet ./...
- [x] #2 grep -rn 'hashicorp/vault' --include='*.go' . returns nothing (CI-only gate)
- [x] #3 govulncheck ./... (CI-only gate; a red vuln job may be a new stdlib CVE, not this change)
- [x] #4 go vet -tags integration ./... (only if the change touches anything integration_test.go references)
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Inventory every active Go version pin, including nested modules and container or CI toolchains. 2. Update the pins and version-specific documentation to Go 1.27.0 without changing historical records or fixtures. 3. Run the repository-defined validation gate, review the diff, commit to main, push, and confirm hosted CI.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Local Go 1.27.0 evidence: build, race tests, vet, integration-tag vet, the hashicorp/vault exclusion check, and govulncheck all passed; govulncheck reported no reachable vulnerabilities. Final diff check passed. CodeRabbit was skipped because only the module/toolchain declaration and tracker changed.
<!-- SECTION:NOTES:END -->
