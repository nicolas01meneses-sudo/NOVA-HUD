#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

rojo_bin="${ROJO_BIN:-rojo}"
if ! command -v "$rojo_bin" >/dev/null 2>&1; then
    echo "ERROR: Rojo CLI is required. Set ROJO_BIN or add rojo to PATH." >&2
    exit 1
fi
for required in zip unzip sha256sum; do
    if ! command -v "$required" >/dev/null 2>&1; then
        echo "ERROR: $required is required to package the demo." >&2
        exit 1
    fi
done

version="6.0.1"
archive_name="NOVA-HUD-${version}-Studio-Demo.zip"
stage_root="$(mktemp -d)"
stage="$stage_root/NOVA-HUD-${version}-Studio-Demo"
trap 'rm -rf -- "$stage_root"' EXIT

mkdir -p "$stage" "$repo_dir/dist"
"$rojo_bin" build demo.project.json -o "$stage/NOVA-HUD-${version}-Studio-Demo.rbxlx"

cp README.md default.project.json demo.project.json rokit.toml "$stage/"
cp -R src demo tests "$stage/"
mkdir -p "$stage/docs" "$stage/scripts"
cp docs/ARCHITECTURE.md docs/INSTALL_STUDIO.md docs/LOADER_COMPATIBILITY.md \
    docs/PACKAGE_MANIFEST.md docs/STUDIO_DEMO_TEST.md docs/VALIDATION.md "$stage/docs/"
cp scripts/check.sh scripts/package_demo.sh "$stage/scripts/"

archive="$repo_dir/dist/$archive_name"
(
    cd "$stage_root"
    zip -qr "$archive" "NOVA-HUD-${version}-Studio-Demo"
)
unzip -t "$archive" >/dev/null
(
    cd "$repo_dir/dist"
    sha256sum "$archive_name" > "$archive_name.sha256"
)
printf 'Created %s\n' "$archive"
cat "$archive.sha256"
