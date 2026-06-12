#!/usr/bin/env bash
# Show what every override changes relative to its upstream counterpart.
# Run from anywhere; paths are resolved relative to this script.
set -uo pipefail
cd "$(dirname "$0")"

count=0

show_diffs() {
  local overlay=$1 base=$2 rel f
  [ -d "$overlay" ] || return 0
  while IFS= read -r -d '' f; do
    rel=${f#"$overlay"/}
    count=$((count + 1))
    echo "=== $overlay/$rel"
    if [ ! -f "$base/$rel" ]; then
      echo "    (new file — no upstream counterpart)"
    elif diff -u "$base/$rel" "$f"; then
      echo "    (identical to upstream — this override is a no-op, consider deleting it)"
    fi
    echo
  done < <(find "$overlay" -type f ! -name .gitkeep -print0 | sort -z)
}

show_diffs source "../source 7.6"
show_diffs data ../data

if [ "$count" -eq 0 ]; then
  echo "No overrides present. See overrides/README.md to add one."
fi
