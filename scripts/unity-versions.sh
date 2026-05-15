#!/usr/bin/env bash
# Central list of Unity versions to test against.
# Source this file: source scripts/unity-versions.sh
# Then use: UNITY_TEST_VERSIONS array

UNITY_TEST_VERSIONS=(
    "2022.3.60f1"   # LTS 2022
    "6000.0.36f1"   # LTS 6 (Unity 6)
)

# Minimum supported version from package.json
UNITY_MIN=$(python3 -c \
    "import json; print(json.load(open('package.json')).get('unity','2022.3'))" \
    2>/dev/null || echo "2022.3")
