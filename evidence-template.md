# Remediation evidence summary

**Programme:** <name> **Period:** <start date> – <end date> **Prepared by:** <name> **Date:** <date>
**Scope:** <N> repositories in `<github owner>`, tickets `<DEMO-101 … DEMO-148>` (source: `findings/jira-findings.csv`)

## 1. Headline

| Metric | Value |
|---|---|
| Findings in scope | <48> |
| Findings closed (scanner-verified) | <n> (<%>) |
| Findings open: skipped or blocked | <n> |
| Repositories touched (PR opened) | <n> of <N> |
| Pull requests merged after human approval | <n> |
| Pull requests merged without human approval | **0** (required by branch protection) |
| Median time from ticket assigned to PR opened | <hh:mm> |
| Total agent compute used | <ACUs / agent-hours> (≈ <cost>) |

## 2. Findings closed

| Ticket(s) | Repository | Package: before → after | Advisories closed | Scanner and result after fix |
|---|---|---|---|---|
| <DEMO-101–104> | <demo-charging-api> | <lodash 4.17.20 → 4.18.1> | <GHSA-…, …> | <npm audit / osv-scanner: 0> |
| | | | | |

## 3. Repositories touched and changes made

| Repository | PR | Files changed | Code change beyond version bump? | Reviewer (human) | Approved at | Merged at |
|---|---|---|---|---|---|---|
| <demo-service-portal> | <#1 link> | <2> | <Yes: PropertyNamingStrategies.SNAKE_CASE> | <@name> | <time> | <time> |
| | | | | | | |

## 4. Tests run and results

| Repository | Test command | Before fix | After fix | CI run link |
|---|---|---|---|---|
| <demo-diagnostics> | <python -m pytest> | <6 passed> | <6 passed> | <link> |
| | | | | |

Every merged change passed the required `test` status check on its PR: **<Yes/No>**

## 5. Human approval

| PR | Approved by | Owning team (CODEOWNERS) | Approval matches owner? |
|---|---|---|---|
| | | | |

## 6. Time and compute

| Item | Value |
|---|---|
| Wall-clock time, first ticket assigned → last PR opened | <hh:mm> |
| Agent sessions | <n> (parallel: <n>) |
| Agent compute (ACUs / hours) | <n> |
| Human review time (sum across PRs) | <hh:mm> |
| Estimated manual effort avoided | <hours, method used> |

## 7. Skipped or blocked, and why

| Ticket | Repository | Reason | Recommended next step | Owner of next step |
|---|---|---|---|---|
| <DEMO-148> | <demo-legacy-reports> | <No tests, no CODEOWNERS, no README owner: playbook stop condition> | <Assign owner; add smoke tests; then re-run playbook> | <Security / platform lead> |
| | | | | |

## 8. Residual risk and assurance notes

- Findings out of scope (for example dev-only tooling): <list, with reason>
- Suppressions or ignores added by the agent: **<none>** (playbook forbids them)
- Verification: `verify.sh` run at <time>. Output attached as appendix A.

**Sign-off:** CISO / delegate <name>, <date>
