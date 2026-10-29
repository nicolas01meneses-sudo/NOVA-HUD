#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

forbidden='VirtualUser|fireclickdetector|firetouchinterest|firesignal|getconnections|hookmetamethod|getgenv|loadstring|HttpGet|queue_on_teleport'
if rg -n "$forbidden" src; then
    echo "ERROR: executor-only or dynamic-loader API found in src/" >&2
    exit 1
fi

if rg -n ':(FireServer|InvokeServer)\(' src; then
    echo "ERROR: direct remote call found in src/; use the authorized callback seam" >&2
    exit 1
fi

mapfile -t source_files < <(rg --files src -g '*.lua' | sort)
for file in "${source_files[@]}"; do
    first_line="$(sed -n '1p' "$file")"
    if [[ "$first_line" != '--!strict' ]]; then
        echo "ERROR: $file must start with --!strict" >&2
        exit 1
    fi
done

if command -v luau-compile >/dev/null 2>&1; then
    for file in "${source_files[@]}"; do
        luau-compile "$file" >/dev/null
    done
    luau-compile tests/run.luau >/dev/null
else
    echo "WARN: luau-compile not installed; syntax compilation skipped" >&2
fi

if command -v luau >/dev/null 2>&1; then
    luau tests/run.luau
else
    echo "WARN: luau not installed; automated tests skipped" >&2
fi

echo "Static policy checks passed"
