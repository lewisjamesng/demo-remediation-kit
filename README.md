# demo-remediation-kit

Supporting material for a demo of an AI software engineer remediating security findings across many repositories. **Everything here is synthetic.** The repositories, teams, tickets and data are fictional sample material.

**Owner:** `@demo-org/security-engineering-team` (see `.github/CODEOWNERS`)

## Contents

| Path | What it is |
|---|---|
| `playbooks/remediate-dependency-finding.md` | Playbook to paste into the agent (Devin) |
| `findings/sarif/` | SARIF from real scanner runs on the baseline repos (`osv-scanner --format sarif`, plus `govulncheck` and `bandit` where they add signal) |
| `findings/raw/` | Raw JSON scanner output that the CSV is derived from |
| `findings/jira-findings.csv` | Synthetic Jira-style ticket export (48 tickets) derived from the scanner output |
| `evidence-template.md` | One-page evidence summary for a CISO |
| `demo-script.md` | 15-minute walkthrough with expected outcomes and fallbacks |
| `verify.sh` | Clones each repo, runs tests and the scanner, and prints a table showing whether the planted finding is still present |
| `fallback/expected-fixes/` | Patches for the expected fixes, verified locally (tests green, scanner clean) |
| `scripts/generate-findings.sh` | Regenerates `findings/` from local checkouts |

## Demo repositories

| Repository | Language | Planted finding | Expected fix |
|---|---|---|---|
| demo-charging-api | TypeScript | lodash 4.17.20 | bump to 4.18.1 |
| demo-fleet-dashboard | TypeScript | lodash 4.17.20 | bump to 4.18.1 |
| demo-ota-status | TypeScript | lodash 4.17.20 | bump to 4.18.1 |
| demo-warranty-service | Java 17 | jackson-databind 2.9.10.8 | bump to 2.18.11 |
| demo-service-portal | Java 17 | jackson-databind 2.9.10.8 | bump to 2.18.11, plus a code change (removed `PropertyNamingStrategy` constant) |
| demo-diagnostics | Python 3.11 | PyYAML 5.3.1, plus unsafe `yaml.load` | bump to 6.0, plus `safe_load` |
| demo-battery-health | Python 3.11 | PyYAML 5.3.1 | bump to 6.0 |
| demo-session-router | Go | golang.org/x/net v0.17.0 (reachable via h2c) | bump to v0.60.0 (raises `go` directive to 1.26.0) |
| demo-legacy-reports | Python | PyYAML 5.3.1 | **none: orphaned repo, agent must stop and report** |

## Running verify.sh

```bash
./verify.sh                 # baseline on main: expect FINDING PRESENT = YES everywhere
./verify.sh --ref fix/      # agent branches: expect "no" for the 8 fixable repos
./verify.sh --local ..      # use local checkouts instead of cloning
```

Needs git, jq, Node 20+, Java 17 + Maven, Go, Python 3.11, osv-scanner, pip-audit, govulncheck and bandit.

## Licence

MIT
