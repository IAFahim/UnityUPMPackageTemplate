#!/usr/bin/env bash
# Usage: bash scripts/api-surface.sh [output-file]
# Produces a sorted list of all public types, methods, properties in the runtime assembly.
set -euo pipefail

OUTPUT="${1:-artifacts/api/surface.txt}"
mkdir -p "$(dirname "$OUTPUT")"

SLNX=$(ls *.slnx 2>/dev/null | head -1)
if [ -z "$SLNX" ]; then
    echo "No .slnx file found." && exit 1
fi

# Build first
dotnet build "$SLNX" -c Release --nologo -v quiet >/dev/null 2>&1

# Find the runtime DLL
DLL=$(find . -path '*/Release/netstandard2.1/*.Runtime.dll' \
    ! -path '*/obj/*' 2>/dev/null | head -1)

if [ -z "$DLL" ]; then
    echo "Runtime DLL not found after build." && exit 1
fi

# Use dotnet-reflect or xmldoc to extract public surface
# Strategy: use the XML doc file (always generated) for public API list
XML="${DLL%.dll}.xml"
if [ -f "$XML" ]; then
    python3 - "$XML" "$OUTPUT" <<'PY'
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
members = sorted(m.get("name","") for m in tree.findall(".//member"))
with open(sys.argv[2], "w") as f:
    f.write("\n".join(members) + "\n")
print(f"API surface: {len(members)} members → {sys.argv[2]}")
PY
else
    echo "No XML doc file at $XML — ensure <GenerateDocumentationFile>true</GenerateDocumentationFile>"
    exit 1
fi
