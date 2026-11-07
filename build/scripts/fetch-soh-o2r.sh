#!/usr/bin/env bash
# Downloads the Ship of Harkinian 9.3.0 PC release and extracts soh.o2r,
# which package.sh needs to build the PS4 .pkg.
#
# soh.o2r holds Ship of Harkinian's OWN assets (shaders, menus, port data).
# It contains NO game data and NO Sony binaries. The game data archive
# (oot.o2r) is generated separately on a PC from Lux's own ROM and is NEVER
# downloaded or bundled here.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SOH_TAG="9.3.0"
ZIP="SoH-Dewey-Alpha-Win64.zip"
URL="https://github.com/HarbourMasters/Shipwright/releases/download/${SOH_TAG}/${ZIP}"

mkdir -p "$HERE/release-pc" "$HERE/dl"
cd "$HERE/dl"

if [ ! -f "$ZIP" ]; then
    echo "== downloading $URL"
    curl -fL -o "$ZIP" "$URL"
else
    echo "== reusing existing $ZIP"
fi

echo "== extracting soh.o2r -> $HERE/release-pc/soh.o2r"
unzip -o "$ZIP" soh.o2r -d "$HERE/release-pc"

[ -s "$HERE/release-pc/soh.o2r" ] || { echo "ERROR: soh.o2r missing or empty"; exit 1; }
echo "== soh.o2r: $(stat -c%s "$HERE/release-pc/soh.o2r" 2>/dev/null || stat -f%z "$HERE/release-pc/soh.o2r") bytes"
sha256sum "$HERE/release-pc/soh.o2r" 2>/dev/null || shasum -a 256 "$HERE/release-pc/soh.o2r"
echo "== soh.o2r ready (Ship of Harkinian 9.3.0, Dewey Alpha)"
