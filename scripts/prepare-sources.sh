#!/usr/bin/env bash
# Prepares the Ship of Harkinian 9.3.0 sources for the PS4 build.
#
# What it does (run from the ps4port directory, i.e. this repo's root):
#   1. Clones HarbourMasters/Shipwright at tag 9.3.0 (with submodules:
#      libultraship at the 9.3.0 pin 62e973a, torch at the 9.3.0 pin)
#      into <workspace>/Shipwright (sibling of ps4port).
#   2. Applies, in order, the three patches from patches/:
#        a. patches/shipwright-9.3.0-ps4.patch        (PS4 port, rebased to 9.3.0)
#        b. patches/libultraship-9.3.0-ps4.patch     (inside Shipwright/libultraship)
#        c. patches/shipwright-9.3.0-ps4-network-stub.patch
#           (stubs out SDL_net on PS4: Anchor/CrowdControl/Sail disabled)
#   3. Verifies every patch with `git apply --check` before applying, and
#      prints a diff summary at the end.
#
# It is idempotent: if <workspace>/Shipwright already exists it reuses it
# (deletes it first only if --clean is passed). It never downloads a ROM and
# never touches oot.o2r or Piglet modules.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$HERE/.." && pwd)"
SOH_TAG="9.3.0"
LUS_PIN="62e973aeb4a53ad4d22bb91e2d9373ecdfcd246c"  # libultraship pin recorded by Shipwright 9.3.0

CLEAN=0
[ "${1:-}" = "--clean" ] && CLEAN=1

if [ "$CLEAN" = "1" ] && [ -d "$WORKSPACE/Shipwright" ]; then
    echo "== removing existing $WORKSPACE/Shipwright (--clean)"
    rm -rf "$WORKSPACE/Shipwright"
fi

if [ ! -d "$WORKSPACE/Shipwright" ]; then
    echo "== cloning Shipwright tag $SOH_TAG (with submodules)"
    git clone --recurse-submodules --branch "$SOH_TAG" \
        https://github.com/HarbourMasters/Shipwright.git "$WORKSPACE/Shipwright"
else
    echo "== reusing existing $WORKSPACE/Shipwright"
    git -C "$WORKSPACE/Shipwright" rev-parse --verify "refs/tags/$SOH_TAG" >/dev/null 2>&1 \
        || { echo "ERROR: existing Shipwright is not tag $SOH_TAG (use --clean)"; exit 1; }
fi

echo "== libultraship pin: $(git -C "$WORKSPACE/Shipwright" ls-tree HEAD libultraship | awk '{print $3}')"
echo "   (expected $LUS_PIN)"

apply_patch() { # $1 = repo dir, $2 = patch file, $3 = label
    local dir="$1" patch="$2" label="$3"
    if git -C "$dir" apply --check "$patch"; then
        echo "== applying $label"
        git -C "$dir" apply "$patch"
    elif git -C "$dir" diff --quiet && git -C "$dir" apply --check --reverse "$patch" >/dev/null 2>&1; then
        echo "== $label already applied, skipping"
    else
        echo "ERROR: $label does not apply cleanly in $dir"
        echo "       Run: git -C $dir apply --check $patch  (see output above)"
        exit 1
    fi
}

apply_patch "$WORKSPACE/Shipwright" \
    "$HERE/patches/shipwright-9.3.0-ps4.patch" \
    "shipwright-9.3.0-ps4.patch"

apply_patch "$WORKSPACE/Shipwright/libultraship" \
    "$HERE/patches/libultraship-9.3.0-ps4.patch" \
    "libultraship-9.3.0-ps4.patch"

apply_patch "$WORKSPACE/Shipwright" \
    "$HERE/patches/shipwright-9.3.0-ps4-network-stub.patch" \
    "shipwright-9.3.0-ps4-network-stub.patch (SDL_net stub)"

echo "== summary of PS4 changes vs upstream 9.3.0"
git -C "$WORKSPACE/Shipwright" diff --stat | tail -25
echo "== sources ready: $WORKSPACE/Shipwright"
