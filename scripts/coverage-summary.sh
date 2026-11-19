#!/usr/bin/env bash
#
# Prints per-file and total line coverage for lib/ from an lcov file.
#
# Usage: scripts/coverage-summary.sh [lcov-file] (default: coverage/lcov.info)
#
set -euo pipefail

LCOV="${1:-coverage/lcov.info}"
[ -f "$LCOV" ] || { echo "error: $LCOV not found; run flutter test --coverage first" >&2; exit 1; }

awk '
  /^SF:/ { file = substr($0, 4); sub(/^.*\/lib\//, "lib/", file); next }
  /^LF:/ { found[file] += substr($0, 4); next }
  /^LH:/ { hit[file] += substr($0, 4); next }
  END {
    n = 0
    for (f in found) if (f ~ /^lib\//) names[++n] = f
    for (i = 2; i <= n; i++) {
      key = names[i]
      for (j = i - 1; j >= 1 && names[j] > key; j--) names[j + 1] = names[j]
      names[j + 1] = key
    }
    printf "%-55s %9s %7s\n", "File", "Lines", "Cover"
    for (i = 1; i <= n; i++) {
      f = names[i]
      pct = found[f] ? 100 * hit[f] / found[f] : 100
      printf "%-55s %4d/%-4d %6.1f%%\n", f, hit[f], found[f], pct
      total_found += found[f]
      total_hit += hit[f]
    }
    pct = total_found ? 100 * total_hit / total_found : 100
    printf "%-55s %4d/%-4d %6.1f%%\n", "TOTAL", total_hit, total_found, pct
  }
' "$LCOV"
