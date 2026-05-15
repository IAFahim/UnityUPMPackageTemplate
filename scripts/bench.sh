#!/usr/bin/env bash
# Usage: bash scripts/bench.sh [filter]
# Runs benchmarks and saves results to artifacts/benchmarks/
set -euo pipefail

FILTER="${1:-*}"
SLNX=$(ls *.slnx 2>/dev/null | head -1)

mkdir -p artifacts/benchmarks

dotnet run \
    --project Dev~/benchmarks/*.Benchmarks/*.csproj \
    -c Release \
    -- \
    --filter "$FILTER" \
    --exporters json \
    --artifacts artifacts/benchmarks \
    2>&1 | tee artifacts/benchmarks/run.log

echo "  ✓ Benchmarks complete. Results in artifacts/benchmarks/"
