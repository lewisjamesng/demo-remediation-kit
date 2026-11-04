#!/usr/bin/env python3
"""Turn osv-scanner JSON reports into a synthetic Jira-style ticket CSV.

One ticket per (repository, advisory). Aliases are de-duplicated, and the fixed
version is the lowest fixed release above the installed version for that advisory.
For Go, only advisories that call analysis marks as reachable are included.
The owner comes from .github/CODEOWNERS, or UNKNOWN when there is none.
"""
import csv
import json
import re
import sys
from pathlib import Path

ORDER = ["demo-charging-api", "demo-fleet-dashboard", "demo-ota-status",
         "demo-warranty-service", "demo-service-portal", "demo-diagnostics",
         "demo-battery-health", "demo-session-router", "demo-legacy-reports"]


def vkey(v):
    return tuple(int(p) if p.isdigit() else 0 for p in re.split(r"[.\-+]", v.lstrip("v")))


def severity(score):
    try:
        s = float(score)
    except (TypeError, ValueError):
        return "Unscored"
    return "Critical" if s >= 9 else "High" if s >= 7 else "Medium" if s >= 4 else "Low"


def fixed_for(vuln, name, installed):
    fixes = set()
    for aff in vuln.get("affected", []):
        if aff.get("package", {}).get("name", "").lower() != name.lower():
            continue
        for rng in aff.get("ranges", []):
            for ev in rng.get("events", []):
                if "fixed" in ev:
                    fixes.add(ev["fixed"].lstrip("v"))
    above = sorted((f for f in fixes if vkey(f) > vkey(installed)), key=vkey)
    return above[0] if above else ""


def owner(repo_dir):
    co = repo_dir / ".github" / "CODEOWNERS"
    if not co.exists():
        return "UNKNOWN"
    for line in co.read_text().splitlines():
        parts = line.split()
        if parts and not parts[0].startswith("#") and len(parts) > 1:
            return parts[1]
    return "UNKNOWN"


def main(src, raw):
    w = csv.writer(sys.stdout, lineterminator="\n")
    w.writerow(["key", "summary", "repo", "severity", "package", "installed_version",
                "fixed_version", "owner", "status"])
    n = 101
    for repo in ORDER:
        report = Path(raw) / f"{repo}.osv-scanner.json"
        if not report.exists():
            continue
        data = json.loads(report.read_text())
        seen = set()
        rows = []
        for res in data.get("results", []):
            for pkg in res.get("packages", []):
                p = pkg["package"]
                scores, uncalled = {}, set()
                for g in pkg.get("groups", []):
                    for i in g.get("ids", []) + g.get("aliases", []):
                        scores[i] = g.get("max_severity", "")
                    # Call analysis (Go): skip advisories whose vulnerable code is not reachable.
                    for vid, a in (g.get("experimental_analysis") or {}).items():
                        if not a.get("called", True) or a.get("unimportant"):
                            uncalled.update(g.get("ids", []) + g.get("aliases", []))
                for v in pkg.get("vulnerabilities", []):
                    if v["id"] in uncalled:
                        continue
                    ids = {v["id"], *v.get("aliases", [])}
                    key = (p["name"].lower(), frozenset(i for i in ids if not i.startswith("BIT-")))
                    if any(key[0] == s[0] and key[1] & s[1] for s in seen):
                        continue
                    seen.add(key)
                    cve = sorted(i for i in ids if i.startswith("CVE-"))
                    ref = v["id"] + (f" / {cve[0]}" if cve else "")
                    title = (v.get("summary") or v.get("details", "").split(". ")[0].rstrip(".")).strip()
                    if len(title) > 110:
                        title = title[:107].rsplit(" ", 1)[0] + "..."
                    rows.append([
                        f"{p['name']} {p['version']}: {title} ({ref})",
                        repo, severity(scores.get(v["id"])), p["name"], p["version"],
                        fixed_for(v, p["name"], p["version"]), owner(Path(src) / repo), "Open",
                    ])
        rank = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Unscored": 4}
        for row in sorted(rows, key=lambda r: (rank[r[2]], r[3], r[0])):
            w.writerow([f"DEMO-{n}", *row])
            n += 1


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
