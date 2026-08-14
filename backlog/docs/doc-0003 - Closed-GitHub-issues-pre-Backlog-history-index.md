---
id: doc-0003
title: Closed GitHub issues (pre-Backlog history index)
type: other
created_date: '2026-08-14 16:09'
updated_date: '2026-08-14 16:10'
---
> **Historical index of work tracked on GitHub Issues before this repo moved to Backlog.md on
> 2026-08-14.** Unlike some sibling repos, **these issues were NOT deleted** — the GitHub tracker is
> still open and every number below still resolves:
>
> ```sh
> gh issue view 25 --repo rknightion/openbao-plugin-secrets-github --comments
> ```
>
> Note the `--repo`. This checkout has an `upstream` remote pointing at
> `martinbaillie/vault-plugin-secrets-github` and no default is set, so a bare `gh issue view 25`
> answers about **upstream's** tracker and looks entirely normal while doing it.
>
> The load-bearing detail — closing decisions, corrections, acceptance evidence — is in the comments,
> so read the issue, not just this table.

**Why these were not imported as tasks.** Backlog IDs follow creation order, so an imported task
could never carry the number the history already cites: `#23` is referenced from the `CHANGELOG.md`
entry for `f2c66f0`, and 21 commits across this history cite one of these five numbers (44 cite
some issue number, the rest being PR references). Keeping GitHub
numbers as the only ID space over closed work is what keeps those references resolvable. `Done` rows
would also compete with the board's only real signal — what is left. **Cite closed work as `#NNN`;
cite new work as `obg-NNNN`.** Two ID spaces, no overlap.

**The commits column is every commit whose message cites the issue**, newest first, capped at three.
It is a lead, not a verdict: a commit may cite an issue it only touches, and a squashed or un-citing
commit leaves the column empty.

---

## Closed issues

| # | Title | Closed | Reason | Citing commits |
|---|---|---|---|---|
| [#25](https://github.com/rknightion/openbao-plugin-secrets-github/issues/25) | v0.1.2 hardening | 2026-08-08 | completed | 1 — `8f3ab17` |
| [#1](https://github.com/rknightion/openbao-plugin-secrets-github/issues/1) | Port vault-plugin-secrets-github to the OpenBao SDK and ship as an OCI image | 2026-08-07 | completed | 11 — `515a239`, `d51b756`, `4751660` |

Two rows. The number space runs much higher than that because issues and pull requests share it in
GitHub: everything else in the range is a PR, or one of the three deleted issues below.

## Deleted issues — the history cites numbers that now 404

**#22, #23 and #26 were deleted from GitHub on 2026-08-11** after being archived verbatim to
`~/repos/chat-personal/camden/openbao/archive/github-issues/`. There is no copy on GitHub and
deletion is irreversible, so that archive is the record.

| # | Subject | Citations still in this history |
|---|---|---|
| #22 | tailnet identity | 2 commits |
| #23 | the OIDC/CI rollout | 8 commits, **and the `CHANGELOG.md` entry for `f2c66f0`** |
| #26 | splitting the `admin` ACL policy | 1 commit |

They were deleted because none of them changed a file in this repo — they were camden deployment
work filed on the wrong tracker. That is the scope test `AGENTS.md` states, and these three are the
concrete instance behind it.

**A dead link in `CHANGELOG.md` is expected, not a bug to fix.** `f2c66f0`'s entry links to #23 and
that link 404s. Do not rewrite the changelog to remove it: release-please owns that file, the commit
message it was generated from also cites #23, and the reference is still meaningful — it points at
something real that lives in the chat-personal archive.

## Open on GitHub, deliberately not a task

`#21 Dependency Dashboard` is authored by `rknightion-renovate[bot]` and is recreated on every
Renovate run. It is a bot artefact, not work. Leave it there.

The GitHub tracker stays enabled so external contributors can file — this is a public repo and a fork
of an upstream project that still has its own users. Anything arriving that way becomes an
`obg-NNNN` task; the board, not the issue, is where it gets worked.
