# Playbook: Remediate a dependency security finding

Use this playbook when you are given a security ticket (or a list of tickets) that names a repository, a vulnerable package, its installed version and an advisory ID. Work on **one repository per session**. If you are given several repositories, handle each one separately and open one pull request per repository.

## Inputs you should have

- Ticket key, for example `DEMO-101`
- Repository, for example `lewisjamesng/demo-charging-api`
- Package and installed version, for example `lodash 4.17.20`
- Advisory IDs (GHSA, CVE, PYSEC or GO IDs) and the fixed version from the ticket

If any input is missing, read it from the repository's latest `security-scan` workflow artifact or code scanning alerts. Do not guess.

## Procedure

### 1. Pre-flight checks: stop if any fail

Before you change anything, check:

1. **Owner.** The repository has a `.github/CODEOWNERS` file naming an owning team, or the README names an owner. If there is no clear owner, **stop and report** (see "Stop and report" below).
2. **Tests.** The repository has automated tests, such as `test/`, `tests/`, `src/test/` or `*_test.go`, and a test command. If there are no tests, **stop and report**.
3. **Baseline is green.** Run the build and tests on `main` *before* you change anything. If they fail on the unchanged baseline, **stop and report**. Do not fix unrelated failures.

### 2. Read the finding

- Run the language's scanner (table below) on the unchanged repository and save the output.
- Confirm that the ticket's advisory appears for the named package and version.
- List **every** advisory the scanner reports for that package, not only the one on the ticket. One bump should clear all of them.

### 3. Choose the target version

- Pick the **lowest version that fixes every advisory** reported for the package. That means the maximum of the per-advisory fixed versions on the installed release line.
- Check that the version **actually installs and builds** on the repository's runtime. If the lowest fixed version cannot be installed (for example, no build for the Python version in use), move to the next fixed release and say why in the pull request.
- Do not jump to "latest" unless it is also the lowest version that fixes everything.

### 4. Update the dependency

| Language | Where | How |
|---|---|---|
| TypeScript / Node | `package.json` + `package-lock.json` | `npm install <pkg>@<version>` (keep the exact pin style already used) |
| Java / Maven | `pom.xml` (version property or `<version>`) | Edit the version, then run `mvn -B verify` |
| Python | `requirements.txt` | Change the `==` pin |
| Go | `go.mod` + `go.sum` | `go get <module>@v<version>` then `go mod tidy` |

Transitive packages from the same family (for example `jackson-core` alongside `jackson-databind`) should move with the direct dependency. Confirm this with the scanner rather than pinning them separately.

### 5. Adapt the code for breaking changes

- If the build or tests fail after the bump, read the upstream changelog or migration notes for the versions between the installed and target versions. Make the **smallest** code change that restores behaviour.
- Keep public behaviour and API contracts unchanged. The existing tests are the specification. Do not edit tests to make them pass, unless a test relies on behaviour that the advisory itself removes. If that happens, explain it in the pull request.
- If the scanner or a code scanner (for example `bandit`) also flags an **insecure usage pattern** of the same package, fix it in the same pull request. For example, `yaml.load` without a safe loader should become `yaml.safe_load`. It is part of the same finding.
- If the bump changes a toolchain requirement (for example, Go's `go` directive is raised by `go get`), keep the change and call it out in the pull request.

### 6. Run build and tests

Run the repository's own build and test commands, exactly as CI does (`.github/workflows/ci.yml`, jobs `build` and `test`). All tests must pass.

### 7. Re-run the scanner and confirm that the finding is gone

| Language | Scanner command | "Gone" means |
|---|---|---|
| TypeScript | `npm audit --omit=dev` and `osv-scanner scan source -r .` | No advisories for the package |
| Java | `osv-scanner scan source -r .` | No advisories for `jackson-databind` / `jackson-core` |
| Python | `pip-audit -r requirements.txt` and `bandit -r src` | No advisories for the package, and no `B506` |
| Go | `govulncheck ./...` | "Your code is affected by 0 vulnerabilities" for the module |

If the finding is still present, go back to step 3. Do **not** add ignore or suppression entries (`osv-scanner.toml`, `.nsprc`, `# nosec`, `--ignore-vuln`) to make a finding disappear.

### 8. Keep the change minimal

- Change only the dependency manifest, the lockfile and the code needed for the breaking change or unsafe usage.
- No reformatting, unrelated upgrades, refactors, dependency additions or CI changes.
- One commit is preferred. Message: `fix(deps): bump <pkg> <old> -> <new> (<advisory IDs>)`.

### 9. Open one pull request per repository

Branch name: `fix/<ticket-key>-<pkg>`. Target `main`. **Never merge it yourself.** A human reviewer from the owning team approves and merges.

Use this description template:

```markdown
## Security fix: <package> <old> → <new>

**Tickets:** <DEMO-xxx, ...>
**Owner:** <team from CODEOWNERS>

### Finding
| Advisory | Severity | Installed | Fixed in |
|---|---|---|---|
| <GHSA/CVE/PYSEC/GO id> | <sev> | <old> | <fixed> |

### Fix
- Bumped `<package>` from `<old>` to `<new>` (lowest version that fixes all listed advisories).
- Code changes: <none | file:line, what changed and why, with link to upstream migration note>
- Other notable effects: <e.g. go directive raised 1.22 → 1.26 | transitive jackson-core 2.9.10 → 2.18.11 | none>

### Test results
- Command: `<test command>`
- Result: <N passed, 0 failed> (before: <N passed>)

### Scanner result
- Before: `<scanner>` reported <N> advisories for `<package>`
- After: `<scanner>` reports **0** for `<package>`
<paste the relevant scanner output lines>

### Not changed
<anything deliberately left alone, e.g. dev-only tooling findings>
```

## Stop and report: do not open a fix pull request

Stop and post a report, instead of changing code, if any of these is true:

- The repository has **no tests**, or the tests **fail** on the baseline or after your change and you cannot fix them within the scope above.
- The repository has **no clear owner** (no `CODEOWNERS` and no owner in the README).
- The only fixed version needs a major-version migration that goes beyond a small, contained code change.
- The scanner still reports the finding after your best minimal change.

The report should contain: the repository, ticket keys, what you checked, which condition stopped you, the scanner output, and a recommended next step. For example, "assign an owner and add smoke tests, then re-run this playbook". Never merge, force-push, or change branch protection or repository settings.

## Final summary (after all repositories)

Give one table row per repository: repo | ticket(s) | package old → new | code change (y/n) | tests | scanner after | PR link or "stopped: <reason>".
