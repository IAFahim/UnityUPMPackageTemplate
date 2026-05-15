#!/usr/bin/env bash
# Usage: bash scripts/generate-docs.sh [output-dir]
# Reads XML documentation and generates Markdown API reference.
set -euo pipefail

OUT="${1:-Documentation~/api}"
mkdir -p "$OUT"

SLNX=$(ls *.slnx 2>/dev/null | head -1)
dotnet build "$SLNX" -c Release --nologo -v quiet >/dev/null 2>&1

XML=$(find . -path '*/Release/netstandard2.1/*.xml' ! -path '*/obj/*' 2>/dev/null | head -1)
PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])" 2>/dev/null)

if [ -z "$XML" ]; then
    echo "No XML doc file found. Add <GenerateDocumentationFile>true</GenerateDocumentationFile>"
    exit 1
fi

python3 - "$XML" "$OUT" "$PKG_NAME" <<'PY'
import sys, xml.etree.ElementTree as ET, os, re

def strip_tags(text):
    return re.sub(r'<[^>]+>', '', text or '').strip()

def member_kind(name):
    prefix = name[0] if name else '?'
    return {'T': 'Type', 'M': 'Method', 'P': 'Property', 'F': 'Field', 'E': 'Event'}.get(prefix, 'Other')

tree = ET.parse(sys.argv[1])
out_dir = sys.argv[2]
pkg_name = sys.argv[3]

members = {}
for m in tree.findall(".//member"):
    name = m.get("name", "")
    kind = member_kind(name)
    summary = strip_tags(getattr(m.find("summary"), 'text', '') or '')
    returns = strip_tags(getattr(m.find("returns"), 'text', '') or '')
    params = [(p.get("name",""), strip_tags(p.text or '')) for p in m.findall("param")]
    members.setdefault(kind, []).append((name[2:], summary, returns, params))

# Write api.md
with open(os.path.join(out_dir, "api.md"), "w") as f:
    f.write(f"# {pkg_name} API Reference\n\n")
    f.write(f"_Auto-generated from source. Do not edit manually._\n\n")
    for kind in ['Type', 'Method', 'Property', 'Field']:
        items = members.get(kind, [])
        if not items: continue
        f.write(f"## {kind}s\n\n")
        for (name, summary, returns, params) in sorted(items):
            f.write(f"### `{name}`\n\n")
            if summary: f.write(f"{summary}\n\n")
            if params:
                f.write("**Parameters**\n\n")
                for pname, pdesc in params:
                    f.write(f"- `{pname}` — {pdesc}\n")
                f.write("\n")
            if returns: f.write(f"**Returns**: {returns}\n\n")

print(f"Docs written to {out_dir}/api.md")
PY

echo "  ✓ Docs generated at $OUT/api.md"
