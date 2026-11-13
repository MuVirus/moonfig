#!/usr/bin/env bash
# Compare each example's stdout with the output block in its README.
#
# The README block starts at `<!-- example-output -->` and is the first fenced
# block after it. CI runs this after the examples, so a changed message or a
# stale README fails the build.
set -euo pipefail

cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0

for dir in examples/*/; do
  name=$(basename "$dir")
  [ -f "$dir/main.mbt" ] || continue

  readme="$dir/README.md"
  if [ ! -f "$readme" ]; then
    echo "missing $readme" >&2
    status=1
    continue
  fi

  expected="$tmp/$name.expected"
  actual="$tmp/$name.actual"

  awk '
    /<!-- example-output -->/ { found = 1; next }
    found && !opened && /^```/ { opened = 1; next }
    found && opened && /^```/ { exit }
    opened { print }
  ' "$readme" | tr -d '\r' > "$expected"

  if [ ! -s "$expected" ]; then
    echo "$readme: missing output block after <!-- example-output -->" >&2
    status=1
    continue
  fi

  if [ "$name" = "multi_source" ]; then
    if ! moon run "examples/$name" -- --log-level=debug | tr -d '\r' > "$actual"; then
      echo "examples/$name: run failed" >&2
      status=1
      continue
    fi
  else
    if ! moon run "examples/$name" | tr -d '\r' > "$actual"; then
      echo "examples/$name: run failed" >&2
      status=1
      continue
    fi
  fi

  if ! diff -u --label "README ($name)" --label "actual ($name)" "$expected" "$actual"; then
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "example output: ok"
fi

exit "$status"
