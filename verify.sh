#!/usr/bin/env bash
# verify.sh: for each demo repository, clone it into a temporary folder, run its
# tests, run its language scanner, and print whether the planted finding is still present.
#
# Usage:
#   ./verify.sh                      # clone from github.com/$OWNER (default: lewisjamesng)
#   OWNER=my-org ./verify.sh
#   ./verify.sh --local ../          # use existing local checkouts instead of cloning
#   ./verify.sh --ref fix/           # per repo, test the newest branch whose name starts
#                                    # with this prefix (e.g. agent PR branches fix/DEMO-...)
#
# Needs: gh (authenticated), git, jq, node/npm, Java 17 + mvn, Go, python3.11 (or $PYTHON),
#        osv-scanner, pip-audit, govulncheck, bandit.
set -uo pipefail

OWNER="${OWNER:-lewisjamesng}"
PYTHON="${PYTHON:-python3.11}"
LOCAL=""
REF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --local) LOCAL="$(cd "$2" && pwd)"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# repo|language|planted package
REPOS=(
  "demo-charging-api|typescript|lodash"
  "demo-fleet-dashboard|typescript|lodash"
  "demo-ota-status|typescript|lodash"
  "demo-warranty-service|java|com.fasterxml.jackson.core:jackson-databind"
  "demo-service-portal|java|com.fasterxml.jackson.core:jackson-databind"
  "demo-diagnostics|python|pyyaml"
  "demo-battery-health|python|pyyaml"
  "demo-session-router|go|golang.org/x/net"
  "demo-legacy-reports|python|pyyaml"
)

WORK="$(mktemp -d "${TMPDIR:-/tmp}/demo-verify.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
LOG="$WORK/logs"; mkdir -p "$LOG"

ROWS=()
row() { ROWS+=("$(printf '%s|' "$@")"); }

for entry in "${REPOS[@]}"; do
  IFS='|' read -r repo lang pkg <<<"$entry"
  dir="$WORK/$repo"
  echo ">> $repo" >&2
  if [ -n "$LOCAL" ]; then
    cp -r "$LOCAL/$repo" "$dir" 2>/dev/null || { row "$repo" "$lang" "$pkg" "-" "clone failed" "-" "?"; continue; }
    rm -rf "$dir/node_modules" "$dir/target"
  elif ! gh repo clone "$OWNER/$repo" "$dir" -- -q >"$LOG/$repo.clone" 2>&1; then
    row "$repo" "$lang" "$pkg" "-" "clone failed" "-" "?"; continue
  fi
  if [ -n "$REF" ]; then
    match="$(git -C "$dir" for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' "refs/remotes/origin/$REF*" | grep -v '^HEAD$' | head -1)"
    [ -n "$match" ] && git -C "$dir" checkout -q "$match"
  fi
  cd "$dir" || continue
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  tests="none"; version="?"; present="?"; detail=""

  case "$lang" in
    typescript)
      if npm ci --no-audit --no-fund >"$LOG/$repo.install" 2>&1 && npm run build >"$LOG/$repo.build" 2>&1; then
        npm test >"$LOG/$repo.test" 2>&1 && tests="pass" || tests="FAIL"
      else tests="FAIL (build)"; fi
      version="$(jq -r '.packages["node_modules/lodash"].version // "?"' package-lock.json)"
      npm audit --omit=dev --json >"$LOG/$repo.scan.json" 2>/dev/null
      n="$(jq -r --arg p "$pkg" '.vulnerabilities[$p].via // [] | map(select(type=="object")) | length' "$LOG/$repo.scan.json")"
      present=$([ "${n:-0}" -gt 0 ] && echo "YES" || echo "no"); detail="npm audit: $n advisories"
      ;;
    java)
      if [ -d src/test ]; then mvn -B -q -ntp verify >"$LOG/$repo.test" 2>&1 && tests="pass" || tests="FAIL"; fi
      osv-scanner scan source -r . --format json >"$LOG/$repo.scan.json" 2>/dev/null
      version="$(jq -r --arg p "$pkg" '[.results[]?.packages[]? | select(.package.name==$p) | .package.version][0] // "?"' "$LOG/$repo.scan.json")"
      n="$(jq -r --arg p "$pkg" '[.results[]?.packages[]? | select(.package.name==$p) | .vulnerabilities[]?.id] | unique | length' "$LOG/$repo.scan.json")"
      present=$([ "${n:-0}" -gt 0 ] && echo "YES" || echo "no"); detail="osv-scanner: $n advisories"
      if [ "$version" = "?" ]; then version="$(sed -n 's:.*<jackson.version>\(.*\)</jackson.version>.*:\1:p' pom.xml)"; fi
      ;;
    python)
      "$PYTHON" -m venv .venv >"$LOG/$repo.venv" 2>&1
      .venv/bin/pip install -q -r requirements.txt >"$LOG/$repo.install" 2>&1 || tests="FAIL (install)"
      if [ -d tests ]; then
        .venv/bin/pip install -q -r requirements-dev.txt >>"$LOG/$repo.install" 2>&1
        .venv/bin/python -m pytest -q -p no:cacheprovider >"$LOG/$repo.test" 2>&1 && tests="pass" || tests="FAIL"
      fi
      version="$(grep -i '^pyyaml' requirements.txt | sed 's/.*==//')"
      pip-audit -r requirements.txt -f json >"$LOG/$repo.scan.json" 2>/dev/null
      n="$(jq -r --arg p "$pkg" '[.dependencies[]? | select((.name|ascii_downcase)==$p) | .vulns[]?.id] | unique | length' "$LOG/$repo.scan.json")"
      present=$([ "${n:-0}" -gt 0 ] && echo "YES" || echo "no"); detail="pip-audit: $n advisories"
      if [ -d src ]; then
        b="$(bandit -q -r src -f json 2>/dev/null | jq '[.results[] | select(.test_id=="B506")] | length')"
        [ "${b:-0}" -gt 0 ] && detail="$detail; bandit B506 unsafe yaml.load x$b"
      fi
      rm -rf .venv
      ;;
    go)
      if ls ./*_test.go >/dev/null 2>&1; then go test ./... >"$LOG/$repo.test" 2>&1 && tests="pass" || tests="FAIL"; fi
      version="$(go list -m -f '{{.Version}}' "$pkg" 2>/dev/null || echo '?')"
      govulncheck -format json ./... >"$LOG/$repo.scan.json" 2>/dev/null
      # A finding is reachable when its trace starts at a symbol (function) in the module.
      n="$(jq -rs --arg p "$pkg" '[.[] | select(.finding) | .finding | select(.trace[0].module==$p and .trace[0].function != null) | .osv] | unique | length' "$LOG/$repo.scan.json")"
      present=$([ "${n:-0}" -gt 0 ] && echo "YES" || echo "no"); detail="govulncheck: $n reachable"
      ;;
  esac
  row "$repo" "$lang" "$pkg@$version" "$branch" "$tests" "$detail" "$present"
  cd "$WORK" || exit 1
  rm -rf "$dir"   # keep disk use low; logs stay in $LOG until exit
done

printf '\n'
fmt='%-23s %-11s %-52s %-22s %-13s %-52s %s\n'
printf "$fmt" REPOSITORY LANGUAGE "PLANTED PACKAGE@VERSION" BRANCH TESTS SCANNER "FINDING PRESENT"
printf "$fmt" ----------------------- ----------- ---------------------------------------------------- ---------------------- ------------- ---------------------------------------------------- ---------------
for r in "${ROWS[@]}"; do IFS='|' read -r a b c d e f g <<<"$r"; printf "$fmt" "$a" "$b" "$c" "$d" "$e" "$f" "$g"; done
