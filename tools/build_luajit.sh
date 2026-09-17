#!/usr/bin/env bash
# Builds LuaJIT 2.1 -- the exact Lua that Garry's Mod ships -- and drops the
# binary at tools/bin/luajit.
#
# The Python probes work without this (they use lupa's Lua 5.5 plus a bit/atan2
# shim), but running them on real LuaJIT means the harness uses GMod's actual
# `bit` library, `math.atan2`, and Lua 5.1 integer/number semantics instead of
# a shim, which removes the last "is the stub lying to me?" variable.
#
#   ./tools/build_luajit.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HERE/bin/luajit"
WORK="${TMPDIR:-/tmp}/luajit-build"

if [[ -x "$DEST" ]]; then
    echo "already built: $DEST"
    "$DEST" -v
    exit 0
fi

for tool in git gcc make; do
    command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done

rm -rf "$WORK"
git clone --depth 1 -b v2.1 https://github.com/LuaJIT/LuaJIT.git "$WORK"
make -C "$WORK" -j"$(nproc)" BUILDMODE=static amalg

mkdir -p "$(dirname "$DEST")"
cp "$WORK/src/luajit" "$DEST"
chmod +x "$DEST"

echo "built: $DEST"
"$DEST" -v
"$DEST" -e 'assert(bit and math.atan2, "expected GMod-compatible bit/atan2")
print("bit.band(0xFF,0x0F) = " .. bit.band(0xFF, 0x0F))
print("math.atan2(1,1)     = " .. math.atan2(1, 1))
print("_VERSION            = " .. _VERSION)'
