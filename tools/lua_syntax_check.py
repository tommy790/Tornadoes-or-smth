#!/usr/bin/env python3
"""
Syntax gate: compiles (does NOT execute) every Lua file in the TIV addon with a
real Lua 5.x parser via lupa, so a typo in any file fails the build.

Usage:  python3 tools/lua_syntax_check.py [path ...]
        (defaults to the whole jeep_jalopy_interceptor/lua tree)
Exit 0 = every file compiles.
"""
import os
import re
import sys

from lupa import LuaRuntime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_ROOT = os.path.join(REPO, "jeep_jalopy_interceptor", "lua")

CHECK = r"""(function(src, name)
    local chunk, err = load(src, name)
    if chunk then return nil end
    return err
end)"""


def main():
    roots = sys.argv[1:] or [DEFAULT_ROOT]
    files = []
    for root in roots:
        target = root if os.path.isabs(root) else os.path.join(REPO, root)
        if os.path.isfile(target):
            files.append(target)
            continue
        for dirpath, _dirs, names in os.walk(target):
            for n in sorted(names):
                if n.endswith(".lua"):
                    files.append(os.path.join(dirpath, n))

    # Expression 2 core files are E2 DSL, not plain Lua; normalise them first.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from e2_bearing_probe import to_plain_lua  # noqa: E402

    lua = LuaRuntime()
    check = lua.eval(CHECK)

    failed = []
    dsl_count = 0
    for path in files:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        rel = os.path.relpath(path, REPO)
        if re.search(r"^e2function\s", src, re.MULTILINE):
            dsl_count += 1
            src = to_plain_lua(src)
            rel += "  (E2 DSL -> Lua)"
        err = check(src, "@" + rel)
        if err is not None:
            failed.append((rel, str(err)))

    print(f"Compiled {len(files)} Lua file(s) with {lua.eval('_VERSION')} "
          f"({dsl_count} E2 DSL file(s) transformed first)")
    if failed:
        print(f"FAIL: {len(failed)} file(s) did not compile")
        for name, err in failed:
            print(f"  {name}: {err}")
        return 1
    print("OK: all files compile")
    return 0


if __name__ == "__main__":
    sys.exit(main())
