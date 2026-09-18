# TIV verification tools

Offline checks for the Tornado Intercept Vehicle addon. **Garry's Mod cannot run
in this sandbox** (no GPU, no display, no route to Steam), so these execute the
addon's *real* Lua source inside a stubbed GMod API using a real Lua interpreter.

## Setup

Two things are needed, and both are rebuildable because the workspace snapshot
prunes them between sessions:

```sh
python3 -m venv .venv && .venv/bin/pip install lupa   # for the Python probes
./tools/build_luajit.sh                               # GMod's actual Lua
npm install --global glua-cli@0.6.0                   # optional: the linter
```

## Checks

| Tool | Runs on | What it actually executes | Fails when |
| --- | --- | --- | --- |
| `glua lint jeep_jalopy_interceptor/lua` | glua-cli | The GLua language server's analysis: realm awareness, net payload validation, argument counts, hot-path analysis. Config in `.glua.json`. | Any error, e.g. an undefined global or a net read/write mismatch. |
| `tools/lua_syntax_check.py` | lupa (Lua 5.5) | Compiles every `.lua` under `jeep_jalopy_interceptor/lua`. Expression 2 core files are E2 DSL, so they are transformed to plain Lua first. | Any file has a syntax error. |
| `tools/radar_probe_lua.lua [yaw]` | **LuaJIT 2.1** | `TIV.Instruments.DrawRadarScreen` from `lua/tiv/instruments/cl_radar_screen.lua`, with `surface.DrawRect` / `draw.SimpleText` recorded. | The tornado blip lands on the wrong side of the screen, or the printed `REL BRG` / sector disagrees with where the blip was drawn. |
| `tools/radar_cache_probe.lua` | **LuaJIT 2.1** | The real `PostDrawTranslucentRenderables` hook body, with a simulated map and entity lifecycle. | The radar screen stops rendering, `ents.FindByClass` is called more than once a second, a late-tagged prop is never adopted, or a removed prop keeps rendering. |
| `tools/radar_multiplayer_probe.lua` | **LuaJIT 2.1** | The real `net.Receive("TIV_RadarPathData")` handler and render hook, with two jeeps on opposite sides of one vortex. | A screen renders another vehicle's packet: its `REL BRG` reads the opposite sector, or the result depends on which packet arrived last. |
| `tools/vehicle_detection_probe.lua` | **LuaJIT 2.1** | The real `TIV.IsSupportedVehicle` and `TIV.GetIdentifiedInterceptors` over 19 real GMod vehicle classes and models. | An airboat, prisoner pod, vehicle seat, or unlisted vehicle class is treated as a TIV interceptor. |
| `tools/radar_probe.py [yaw]` | lupa (Lua 5.5) | Same bearing scenario, through the Python bridge. | Same. |
| `tools/e2_bearing_probe.py [yaw]` | lupa (Lua 5.5) | The real `e2function` bodies from `lua/entities/gmod_wire_expression2/core/custom/tiv.lua`. | `tivTornadoRelativeBearing()` / `tivTornadoRelativeSector()` disagree with the vehicle's own basis, or `tivTornadoBearing()` stops being the absolute map angle. |

Run everything (this is what the CI workflow at the bottom of this file does):

```sh
glua lint jeep_jalopy_interceptor/lua
.venv/bin/python tools/lua_syntax_check.py
./tools/build_luajit.sh
tools/bin/luajit tools/radar_probe_lua.lua
tools/bin/luajit tools/radar_cache_probe.lua
tools/bin/luajit tools/radar_multiplayer_probe.lua
tools/bin/luajit tools/vehicle_detection_probe.lua
.venv/bin/python tools/e2_bearing_probe.py
```

Each exits 0 on success. The probes take an optional vehicle yaw in degrees so
the same scenario can be checked from any heading.

## Shared stub

`tools/gmod_stub.lua` is the single source of truth for the stubbed GMod API,
used by both the LuaJIT driver and the Python bridge. `tools/radar_selftest.lua`
pins the Source conventions it relies on — `Angle(0,0,0)` → forward `(1,0,0)`,
right `(0,-1,0)`, up `(0,0,1)`, and so on. Both probes refuse to run if that
self-test fails, so a bad stub can never produce a green result.

The stub installs `bit`, `math.atan2`, `math.Clamp` and `math.Round` **only if
they are absent**, so under LuaJIT GMod's native implementations are used and no
shim is involved at all.

## Lint config

`.glua.json` declares the globals this addon expects from other addons
(`BaseClass` from Wiremod, `E2Lib` / `E2Helper` / `__e2setcost` from Expression 2)
and excludes the `custom/` directory from indexing, because the Expression 2 core
files are E2 DSL rather than Lua and do not parse.

## Continuous integration

The workflow below was not committed: the GitHub App token used here is
granted contents read/write but **not** `workflows`, so GitHub rejects any push
that creates or updates a file under `.github/workflows/`.

```
 ! [remote rejected] (refusing to allow a GitHub App to create or update
   workflow `.github/workflows/glua.yml` without `workflows` permission)
```

To enable it, grant the app `workflows` write access (or push it from your own
credentials), then save this as `.github/workflows/glua.yml`:

```yaml
name: GLua lint + probes

on: [push, pull_request]

jobs:
  lint:
    name: glua lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: "20"

      - run: npm install --global glua-cli@0.6.0

      - name: Lint
        run: glua lint jeep_jalopy_interceptor/lua --format github

  probes:
    name: radar + bearing probes
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - run: pip install lupa

      - name: Syntax gate (all addon Lua files)
        run: python tools/lua_syntax_check.py

      - name: Build LuaJIT (GMod's actual Lua)
        run: bash tools/build_luajit.sh

      - name: Radar screen probe (real LuaJIT)
        run: |
          for yaw in 0 90 180 270; do
            tools/bin/luajit tools/radar_probe_lua.lua "$yaw"
          done

      - name: Radar screen cache probe (real LuaJIT)
        run: tools/bin/luajit tools/radar_cache_probe.lua

      - name: Vehicle detection probe (real LuaJIT)
        run: tools/bin/luajit tools/vehicle_detection_probe.lua

      - name: E2 bearing probe
        run: |
          for yaw in 0 90 180 270; do
            python tools/e2_bearing_probe.py "$yaw"
          done
```

## What is still not verified here

**The canvas orientation of the radar display cannot be derived offline.** It
depends on how `cam.Start3D2D(pos, screenAng, scale)` maps canvas +x, and
deriving it from `MONITOR_CONFIGS` (`rot = Angle(0, 90, 90)`) gave the *opposite*
answer to what the screen actually shows. Both radar probes therefore carry an
explicit `CANVAS_X_TO_VIEWER_RIGHT = -1` constant pinned to **in-game
observation**: a vortex on the vehicle's right was painted on the viewer's left
while `REL BRG` correctly read `090 RIGHT`.

That means the probes are a **regression lock, not an independent proof** of the
horizontal axis. They will catch any change that flips it again; they cannot
discover that the original orientation was wrong. Only a rendered frame can do
that. If a future change touches `cfg.rot` or the `cam.Start3D2D` call, re-derive
the constant in game rather than from the config.

The vertical axis is not in doubt — an ahead vortex painting above centre was
confirmed in game, and both probes assert it directly.

One open cosmetic question follows from the same uncertainty: the centre chevron
is drawn pointing at canvas up, and the comment calls it *"Facing UP =
Forward"*. Under the empirically-pinned orientation that apex may point astern.
It has not been reported as wrong, so it has been left alone.
