#!/usr/bin/env bash
# Builds the single-file game from src/.
#   index.html          standalone page (GitHub Pages or any static host; peer-to-peer multiplayer)
#   dist/artifact.html  Claude artifact format (multiplayer through the artifact runtime)
set -euo pipefail
cd "$(dirname "$0")"
PARTS=$(cat src/parts.txt)
body() {
  cat src/05_preflight.html
  cat src/00_head.html
  echo '<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}</script>'
  echo '<script type="module">'
  for p in $PARTS; do cat "src/$p"; echo; done
  echo '</script>'
}
mkdir -p dist
body > dist/artifact.html
{
  printf '<!doctype html>\n<html lang="en">\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
  # peer-to-peer transport for multiplayer outside claude.ai (Trystero, MIT; see vendor/LICENSES.txt)
  printf '<script>\n'; cat vendor/trystero-nostr.js; printf '\n</script>\n'
  body
  printf '</html>\n'
} > index.html
echo "built index.html and dist/artifact.html"
