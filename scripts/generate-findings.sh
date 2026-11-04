#!/usr/bin/env bash
# Regenerate findings/ from real scanner runs against local checkouts of the
# baseline demo repositories. Usage: scripts/generate-findings.sh <dir-with-repos>
set -euo pipefail
SRC="${1:?usage: $0 <directory containing the demo-* repositories>}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$KIT/findings"
REPOS=(demo-charging-api demo-fleet-dashboard demo-ota-status demo-warranty-service
       demo-service-portal demo-diagnostics demo-battery-health demo-session-router
       demo-legacy-reports)
mkdir -p "$OUT/sarif" "$OUT/raw"
for r in "${REPOS[@]}"; do
  echo "scanning $r" >&2
  ( cd "$SRC/$r"
    osv-scanner scan source -r . --format sarif --output "$OUT/sarif/$r.osv-scanner.sarif" >/dev/null 2>&1 || true
    osv-scanner scan source -r . --format json  --output "$OUT/raw/$r.osv-scanner.json"   >/dev/null 2>&1 || true
    case "$r" in
      demo-charging-api|demo-fleet-dashboard|demo-ota-status)
        npm audit --omit=dev --json > "$OUT/raw/$r.npm-audit.json" 2>/dev/null || true ;;
      demo-diagnostics|demo-battery-health|demo-legacy-reports)
        pip-audit -r requirements.txt -f json -o "$OUT/raw/$r.pip-audit.json" >/dev/null 2>&1 || true ;;
      demo-session-router)
        govulncheck -format sarif ./... > "$OUT/sarif/$r.govulncheck.sarif" 2>/dev/null || true
        govulncheck -format json ./...  > "$OUT/raw/$r.govulncheck.json" 2>/dev/null || true ;;
    esac
    if [ "$r" = demo-diagnostics ]; then
      bandit -q -r src -f sarif -o "$OUT/sarif/$r.bandit.sarif" >/dev/null 2>&1 || true
    fi )
done
python3 "$KIT/scripts/findings_to_csv.py" "$SRC" "$OUT/raw" > "$OUT/jira-findings.csv"
echo "wrote $OUT/jira-findings.csv ($(($(wc -l < "$OUT/jira-findings.csv") - 1)) tickets)" >&2
