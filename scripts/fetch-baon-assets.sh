#!/usr/bin/env bash
# Download BAON binary assets from the GitHub release into the project tree.
# Requires: gh (authenticated) or GITHUB_TOKEN with read access.
#
# Usage: scripts/fetch-baon-assets.sh [tag]
set -euo pipefail

TAG="${1:-baon-assets-2026.11}"
REPO="${REPO:-muffyuniverse/browser-agent}"

cd "$(dirname "$0")/.."
mkdir -p baon/assets/app baon/assets/campaigns baon/assets/logo baon/motion

if command -v gh >/dev/null 2>&1; then
  gh release download "$TAG" --repo "$REPO" --pattern 'ios-*.jpg'        --dir baon/assets/app
  gh release download "$TAG" --repo "$REPO" --pattern '20[0-9][0-9]-*.jpg' --dir baon/assets/campaigns
  gh release download "$TAG" --repo "$REPO" --pattern 'app-icon-*.png'   --dir baon/assets/logo
  gh release download "$TAG" --repo "$REPO" --pattern 'monogram-*.png'   --dir baon/assets/logo
  gh release download "$TAG" --repo "$REPO" --pattern 'hero-frame.png'   --dir baon/motion
  gh release download "$TAG" --repo "$REPO" --pattern '*.mp4'            --dir baon/motion
else
  : "${GITHUB_TOKEN:?set GITHUB_TOKEN or install gh}"
  api="https://api.github.com/repos/$REPO/releases/tags/$TAG"
  urls=$(curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$api" \
    | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)
  [ -n "$urls" ] || { echo "no assets in $TAG" >&2; exit 1; }
  while read -r url; do
    name=$(basename "$url")
    case "$name" in
      ios-*.jpg)          dir=baon/assets/app ;;
      20[0-9][0-9]-*.jpg) dir=baon/assets/campaigns ;;
      app-icon-*.png|monogram-*.png) dir=baon/assets/logo ;;
      hero-frame.png|*.mp4) dir=baon/motion ;;
      *) echo "skip $name"; continue ;;
    esac
    echo "→ $dir/$name"
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -o "$dir/$name" "$url"
  done <<< "$urls"
fi

echo "done: $(find baon/assets baon/motion -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.mp4' \) | wc -l) files"
