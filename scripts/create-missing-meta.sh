#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

make_guid() {
    python3 - <<'PY'
import uuid
print(uuid.uuid4().hex)
PY
}

write_meta() {
    local path="$1"
    local meta="${path}.meta"

    if [ -f "$meta" ]; then
        return
    fi

    cat > "$meta" <<EOF
fileFormatVersion: 2
guid: $(make_guid)
EOF

    echo "created $meta"
}

while IFS= read -r f; do
    write_meta "$f"
done < <(
    find \
        __PACKAGE__.Runtime \
        __PACKAGE__.Tests \
        __PACKAGE__.Editor \
        Samples~ \
        -type f \( \
            -name '*.cs' -o \
            -name '*.asmdef' -o \
            -name '*.uxml' -o \
            -name '*.uss' -o \
            -name '*.unity' -o \
            -name '*.prefab' -o \
            -name '*.asset' \
        \) 2>/dev/null | sort
)

while IFS= read -r dir; do
    write_meta "$dir"
done < <(
    find __PACKAGE__.Runtime __PACKAGE__.Tests __PACKAGE__.Editor Samples~ \
        -type d 2>/dev/null | sort
)
