# Demo script: AI software engineer remediating security findings at scale

**Length:** 15 minutes, 6 steps. **Owner:** `lewisjamesng`. **Ticket queue:** `findings/jira-findings.csv` (48 tickets, DEMO-101 to DEMO-148)

All repositories are synthetic and public. All expected outcomes below were confirmed locally with the real scanners before the demo (see `fallback/expected-fixes/`).

## Before the demo (T-30 min)

- [ ] `./verify.sh` shows **FINDING PRESENT = YES** for all 9 repositories, and tests `pass` (or `none` for legacy).
- [ ] Each repo's latest `CI` run on `main` is green, with a warning annotation on `security-scan`.
- [ ] The Jira project has the CSV imported. Filter: `project = DEMO ORDER BY severity`.
- [ ] Devin has GitHub access to the 9 `demo-*` repositories, and the playbook **"Remediate dependency finding"** has been created from `playbooks/remediate-dependency-finding.md`.
- [ ] Optional: a rehearsal run has finished, its PRs are **closed, not merged**, and the tabs are bookmarked (fallbacks below).
- [ ] Tabs open: Jira queue, Devin, `demo-service-portal` repo, `demo-legacy-reports` repo, `evidence-template.md`.

## Step 1: Show the problem queue (0:00–2:00)

**Show:** the Jira queue, sorted by severity, then grouped by `package`.

**Say:** "48 open findings across 9 repositories, and they're the same four packages over and over. That's what it looks like in a real organisation. lodash appears in 3 TypeScript services, jackson-databind in 2 Java services, PyYAML in 3 Python repos, and golang.org/x/net in the Go router."

**Expected:**

| Package @ installed | Repositories | Tickets |
|---|---|---|
| lodash @ 4.17.20 | demo-charging-api, demo-fleet-dashboard, demo-ota-status | DEMO-101–112 (4 each) |
| jackson-databind @ 2.9.10.8 (+ jackson-core 2.9.10) | demo-warranty-service, demo-service-portal | DEMO-113–140 (14 each) |
| PyYAML @ 5.3.1 | demo-diagnostics, demo-battery-health, demo-legacy-reports | DEMO-141, 142, 148 (Critical) |
| golang.org/x/net @ v0.17.0 (reachable) | demo-session-router | DEMO-143–147 |

Point at **DEMO-148: owner = UNKNOWN**. "Keep this one in mind."

**Fallback:** open `findings/jira-findings.csv` in a spreadsheet, or show a code scanning alert list (Security tab → Code scanning) in any repo.

## Step 2: Assign one ticket to the agent (2:00–4:30)

**Do:** start a Devin session with the playbook. Assign **DEMO-101** (`demo-charging-api`, lodash, GHSA-35jh-r3h4-6jhm / CVE-2021-23337, command injection):

> Using the "Remediate dependency finding" playbook, fix Jira DEMO-101 in lewisjamesng/demo-charging-api.

**Expected agent behaviour:**
1. Finds CODEOWNERS (`@demo-org/charging-platform-team`) and tests (6 Jest tests). Baseline is green.
2. Runs `npm audit --omit=dev` and `osv-scanner`, which show **4** lodash advisories (GHSA-29mw-wpgm-hmr9, GHSA-35jh-r3h4-6jhm, GHSA-r5fr-rjxr-66jc, GHSA-xxjr-mmjv-4gpg).
3. Notes that the ticket's fixed version (4.17.21) doesn't clear all of them. Picks **lodash 4.18.1**, the lowest version that clears every advisory. 4.18.0 still has GHSA-f23m-r3pf-42rh.
4. Bump only. 6/6 tests pass, and the scanners report 0 findings. Opens a PR covering DEMO-101–104.

**Talking point:** "It didn't just copy the ticket's fixed version. It closed the whole package's exposure with the smallest change."

**Fallback:** show `fallback/expected-fixes/demo-charging-api.patch` (`package.json` + `package-lock.json` only) or the rehearsal PR.

## Step 3: Show several repositories being fixed in parallel (4:30–8:00)

**Do:** launch parallel sessions (one per repo) with the same playbook:

> Using the "Remediate dependency finding" playbook, fix the open DEMO tickets for each of: demo-fleet-dashboard, demo-ota-status, demo-warranty-service, demo-service-portal, demo-diagnostics, demo-battery-health, demo-session-router. One PR per repository.

**Expected outcomes:**

| Repository | Change | Code change? | Tests | Scanner after |
|---|---|---|---|---|
| demo-fleet-dashboard | lodash 4.17.20 → 4.18.1 | No | 4/4 pass | npm audit: 0 |
| demo-ota-status | lodash 4.17.20 → 4.18.1 | No | 4/4 pass | npm audit: 0 |
| demo-warranty-service | jackson-databind 2.9.10.8 → 2.18.11 (jackson-core follows) | No | 5/5 pass | osv-scanner: no issues |
| demo-service-portal | jackson-databind 2.9.10.8 → 2.18.11 | **Yes**: `PropertyNamingStrategy.CAMEL_CASE_TO_LOWER_CASE_WITH_UNDERSCORES` was removed. Use `PropertyNamingStrategies.SNAKE_CASE` | 6/6 pass | osv-scanner: no issues |
| demo-diagnostics | PyYAML 5.3.1 → **6.0**. 5.4 and 5.4.1 don't build on Python 3.11 | **Yes**: `yaml.load(fh)` → `yaml.safe_load(fh)`. On 6.0 the old call raises `TypeError`, and bandit B506 flags it | 6/6 pass | pip-audit: 0, bandit: 0 |
| demo-battery-health | PyYAML 5.3.1 → 6.0 | No (already `safe_load`) | 4/4 pass | pip-audit: 0 |
| demo-session-router | golang.org/x/net v0.17.0 → **v0.60.0** (also raises `go` directive 1.22 → 1.26.0) | No | 3/3 pass | govulncheck: 0 reachable (was 5) |

**Talking point:** "Same playbook, seven repos, three languages. The two repos where a version bump alone would break the build are exactly where it adapted the code."

**Fallback:** show the rehearsal PR list (`is:pr author:app/devin-ai-integration`, or search by branch `fix/DEMO-`), or `git apply --stat fallback/expected-fixes/*.patch`.

## Step 4: Review one pull request with its test and scan results (8:00–11:00)

**Show:** the **demo-service-portal** PR.

Walk through:
1. **Description:** finding table (14 advisories), fix, test results, before/after scanner output.
2. **Diff:** `pom.xml` (one line) + `JsonSupport.java` (import + one line). Nothing else.
3. **Checks:** `build` ✅, `test` ✅ (required by the ruleset), `security-scan` ✅ with no warning annotation now. Open the job summary to show "No issues found".
4. **Merge gate:** "Merge" is blocked until a human approves. The agent cannot merge.

**Do:** approve as a human reviewer (don't merge, if you want to re-run the demo).

**Fallback:** show `fallback/expected-fixes/demo-service-portal.patch`, then show on `main` that the `security-scan` job summary lists the 14 advisories, and explain that the PR run shows 0.

## Step 5: Show the repository with no tests, and how the agent handles it (11:00–13:00)

**Do:** assign **DEMO-148** (`demo-legacy-reports`, PyYAML 5.3.1, Critical, owner **UNKNOWN**).

**Expected:** the agent runs its pre-flight checks and **stops without opening a fix PR**. It reports:
- no `.github/CODEOWNERS` and no owner in the README
- no tests (no `tests/` directory, no test command) and no CI workflow
- pip-audit confirms PYSEC-2021-142 (CVE-2020-14343) is present
- recommendation: assign an owner and add smoke tests, then re-run the playbook. Fix would be PyYAML → 6.0.

**Talking point:** "Knowing when *not* to change code is a control, not a failure. An unowned repo with no tests is escalated to a human."

**Fallback:** show the repo tree (no `tests/`, no `.github/`), and read out the playbook's "Stop and report" section.

## Step 6: Show the evidence summary (13:00–15:00)

**Show:** `evidence-template.md`, filled in from the run.

**Expected numbers, if all 8 PRs open and the legacy repo is skipped:**
- Findings closed: **47 of 48** (all except DEMO-148)
- Repositories touched: **8 of 9**. Code changes in 2 (demo-service-portal, demo-diagnostics)
- Tests: 38 tests across 8 repos, all passing before and after
- Approved by a human: as many as you approve in the demo. **0 merged without approval.**
- Skipped: DEMO-148, no owner and no tests

**Do:** run `./verify.sh --ref fix/` live, or show its output captured from the rehearsal. The FINDING PRESENT column flips to `no` for fixed branches.

**Fallback:** show the pre-filled evidence from the rehearsal, or the `verify.sh` table from the baseline next to the expected outcomes table in Step 3.

## Reset after the demo

Close (don't merge) the agent PRs and delete their branches, so the planted findings stay on `main` for the next demo.
