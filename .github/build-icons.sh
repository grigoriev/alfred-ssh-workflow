#!/bin/bash

# Regenerate the PNG icons from Octicons (https://github.com/primer/octicons,
# MIT). macOS only: rasterizes with rsvg-convert (brew install librsvg), falling
# back to qlmanage. Run via `make icons`. The PNGs are committed, so neither the
# build nor CI needs a rasterizer.

base="https://raw.githubusercontent.com/primer/octicons/main/icons"
tmp="$(mktemp -d)"
mkdir -p icons

GRAY="#8b949e"
BLUE="#58a6ff"

# Rasterize one octicon into a colored PNG.
# $1 output path  $2 octicon name  $3 fill color
render() {
  local out="$1" octicon="$2" color="$3"
  if ! curl -sfL "$base/$octicon.svg" -o "$tmp/in.svg"; then
    echo "  MISSING $octicon"
    return 0
  fi
  sed -E 's/<svg /<svg fill="'"$color"'" /' "$tmp/in.svg" > "$tmp/c.svg"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 256 -h 256 "$tmp/c.svg" -o "$out"
  else
    qlmanage -t -s 256 -o "$tmp" "$tmp/c.svg" >/dev/null 2>&1
    cp "$tmp/c.svg.png" "$out"
  fi
  echo "  $out"
  return 0
}

echo "generating icons..."
render icons/host.png   terminal-24 "$GRAY"
render icons/update.png sync-24     "$BLUE"

rm -rf "$tmp"
echo "done"
