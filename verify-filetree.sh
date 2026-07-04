#!/usr/bin/env bash
set -euo pipefail

manifest_arg="${1:-sha256sum.txt}"

manifest_dir="$(dirname -- "$manifest_arg")"
manifest_file="$(basename -- "$manifest_arg")"

cd "$manifest_dir"

manifest="$manifest_file"

if [[ ! -f "$manifest" ]]; then
    echo "Manifest not found: $manifest" >&2
    exit 1
fi

# These are sidecar proof files for the manifest itself.
# They must not be part of the manifest payload, otherwise the manifest becomes self-referential.
exempt_files=(
    "$manifest.asc"
    "$manifest.asc.ots"
    "$manifest.asc.ots.bak"
    "$manifest.sigstore.json"
)

is_exempt() {
    local path="$1"

    for exempt in "${exempt_files[@]}"; do
        if [[ "$path" == "$exempt" ]]; then
            return 0
        fi
    done

    return 1
}

echo "[1/3] Checking hashes..."

sed -i 's/\r$//' "$manifest"
sha256sum -c "$manifest" --strict

echo "[2/3] Comparing file set..."

allowed="$(mktemp)"
actual="$(mktemp)"
trap 'rm -f "$allowed" "$actual"' EXIT

# Extract allowed file paths from sha256sum.txt.
# Supports:
#   <hash>  file
#   <hash> *file
sed -E '
    s/\r$//;
    /^[0-9a-fA-F]{64}[[:space:]][ *]?.+$/!d;
    s/^[0-9a-fA-F]{64}[[:space:]][ *]?//;
    s#^\./##;
    s#\\#/#g;
' "$manifest" | LC_ALL=C sort -u > "$allowed"

# Scan actual files.
# Exclude:
#   1. the manifest itself
#   2. sidecar proof files for the manifest
while IFS= read -r path; do
    [[ "$path" == "$manifest" ]] && continue

    if is_exempt "$path"; then
        continue
    fi

    printf '%s\n' "$path"
done < <(find . -type f -printf '%P\n' | sed 's#\\#/#g') |
    LC_ALL=C sort -u > "$actual"

missing="$(comm -23 "$allowed" "$actual" || true)"
extra="$(comm -13 "$allowed" "$actual" || true)"

if [[ -n "$missing" ]]; then
    echo
    echo "Missing files:"
    echo "$missing"
fi

if [[ -n "$extra" ]]; then
    echo
    echo "Extra files:"
    echo "$extra"
fi

if [[ -n "$missing" || -n "$extra" ]]; then
    echo
    echo "File set check FAILED."
    exit 1
fi

echo "[3/3] File set is exact."
echo "All files OK."