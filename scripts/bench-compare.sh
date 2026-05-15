#!/usr/bin/env bash
# Usage: bash scripts/bench-compare.sh
# Fails if any benchmark regressed by more than 10%.
set -euo pipefail

BASELINE="artifacts/benchmarks/baseline.json"

if [ -f "$BASELINE" ]; then
    CURRENT=$(find artifacts/benchmarks -name '*full-compressed.json' -newer "$BASELINE" 2>/dev/null | head -1)
else
    CURRENT=$(find artifacts/benchmarks -name '*full-compressed.json' 2>/dev/null | head -1)
fi

if [ -z "$CURRENT" ]; then
    echo "No current benchmark results found. Run scripts/bench.sh first."
    exit 1
fi

if [ ! -f "$BASELINE" ]; then
    echo "No baseline. Creating from current results."
    cp "$CURRENT" "$BASELINE"
    echo "Commit artifacts/benchmarks/baseline.json to track regressions."
    exit 0
fi

python3 - "$BASELINE" "$CURRENT" <<'PY'
import json, sys

def load(path):
    with open(path) as f: return json.load(f)

def bench_map(data):
    out = {}
    for b in data.get("Benchmarks", []):
        name = b.get("FullName") or b.get("Method", "")
        ns = b.get("Statistics", {}).get("Mean", 0)
        out[name] = ns
    return out

baseline = bench_map(load(sys.argv[1]))
current = bench_map(load(sys.argv[2]))

THRESHOLD = 0.10  # 10% regression = failure
failures = []

for name, base_ns in baseline.items():
    cur_ns = current.get(name)
    if cur_ns is None:
        print(f"  ⚠ Benchmark removed: {name}")
        continue
    ratio = (cur_ns - base_ns) / base_ns
    if ratio > THRESHOLD:
        failures.append((name, base_ns, cur_ns, ratio))
        print(f"  ✗ REGRESSION {name}: {base_ns:.0f}ns → {cur_ns:.0f}ns (+{ratio*100:.1f}%)")
    elif ratio < -0.05:
        print(f"  ✓ IMPROVEMENT {name}: {base_ns:.0f}ns → {cur_ns:.0f}ns ({ratio*100:.1f}%)")
    else:
        print(f"  ✓ {name}: {cur_ns:.0f}ns (stable)")

if failures:
    print(f"\n  {len(failures)} performance regressions detected.")
    sys.exit(1)
else:
    print(f"\n  No regressions.")
PY
