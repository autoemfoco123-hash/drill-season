#!/usr/bin/env bash
# The game is the Godot version (godot/). src/ holds the original web prototype that the
# Godot export tool reads to regenerate the city, cars, data and sounds:
#
#   ./build.sh                      -> dist/artifact.html (local only, git-ignored)
#   node tools/export-godot.js      -> godot/assets/...
#
# It is not published anywhere. The site (index.html) is the Android download page.
set -euo pipefail
cd "$(dirname "$0")"
PARTS=$(cat src/parts.txt)
mkdir -p dist
{
  cat src/05_preflight.html
  cat src/00_head.html
  echo '<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}</script>'
  echo '<script type="module">'
  for p in $PARTS; do cat "src/$p"; echo; done
  echo '</script>'
} > dist/artifact.html
echo "built dist/artifact.html (for tools/export-godot.js)"
