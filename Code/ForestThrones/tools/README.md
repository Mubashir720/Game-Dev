# Verification tools

Headless test and benchmark harnesses. Run them from the project root with:

    godot --headless --script tools/<name>.gd

| Script | What it does |
|---|---|
| `compile_all.gd` | Loads every `.gd` under `scenes/` and `scripts/`. Catches parse and dependency errors that `--import` alone misses, because scene scripts are only compiled when something loads them. **Run this before every commit.** |
| `bench_world.gd` | Generates the full 200x200 map and reports generation time, node count, MultiMesh instance count, unique materials/meshes and static memory. |
| `bench_visible.gd` | Estimates draw calls and on-screen triangles from six sample camera positions, honouring each MultiMesh's visibility range. |
| `bench_parts.gd` | Micro-benchmarks the individual generation stages (zone pass, terrain build, collision, prop construction) so you can see which one regressed. |
| `match_test.gd` | Boots a full 32-actor / 8-squad match and prints roster, LOD distribution and the leaderboard every second. |
| `match_long.gd` | Same, at 6x time scale, through the minute-8 traitor window and beyond. Prints coins, stock, build progress, goal distribution and the final traitor table. |
| `actor_probe.gd` | Reports raw vs baked mesh/surface counts per archetype, and asserts the animator's joints survived baking. |
| `mesh_probe.gd` | Checks every triangle's winding against its own normal, across `bevelled_box`, all 4 beasts, all 12 archetypes and 10 structures. Catches inside-out geometry, which renders as a see-through shell and is invisible to code review. **Run after touching prop_baker or any factory.** |
| `weapon_probe.gd` | Measures every in-hand and back-mounted part and fails anything under ~3px at gameplay distance. A 0.02-thick sword blade is a hairline on a phone. |
| `ability_probe.gd` | Instantiates all 12 archetypes and asserts each one resolved a real ability with a name and a cooldown. Prints the full ability table. |
| `zone_probe.gd` | Fast-forwards the match to the shrink window, freezes the actors on a ring straddling the border, and asserts it flags and damages exactly the ones outside. Prints `RESULT=PASS/FAIL`. |

Rendering harnesses (need a display; use `xvfb-run` on a headless machine):

    xvfb-run -a godot --rendering-driver opengl3 --script tools/shot.gd -- out=user://shot.png wait=260

| Script | What it does |
|---|---|
| `shot.gd` | Boots the match scene, waits N frames, prints real draw calls / primitives / video memory, saves a screenshot. |
| `hud_probe.gd` | Measures the real on-screen rect of every HUD control and fails on any button/panel overlap, off-screen control, or clipped caption — and checks the ability pill against all 12 archetype names, not just the one that spawned. **Run this after touching the HUD.** |
| `screen_probe.gd` | The same audit across main menu, character select, loading and post-match: off-screen controls, clipped captions, and tap targets under 44px. Run it at 1280x720, 960x720 and 1560x720 — the project stretches `canvas_items` with `aspect=expand`, so the aspect ratio moves the layout, not the pixel count. |
| `screen_shot.gd` | Same for any UI scene: `-- scene=res://scenes/menus/main_menu.tscn` |
| `char_preview.gd` | Renders a row of archetypes side by side: `-- ids=warlord,witch,archer` |
| `beast_preview.gd` | Renders the beast roster and a row of structures. |
| `postmatch_shot.gd` | Boots a match, force-resolves it, captures the post-match summary. |

## Before every commit

    godot --headless --script tools/compile_all.gd     # expect failures=0
    godot --headless --script tools/mesh_probe.gd      # expect RESULT=PASS
    godot --headless --script tools/weapon_probe.gd    # expect RESULT=PASS
    godot --headless --script tools/ability_probe.gd   # expect abilities_bad=0
    godot --headless --script tools/zone_probe.gd      # expect RESULT=PASS

and, when the UI changed, with a display attached:

    xvfb-run -a godot --rendering-driver opengl3 --script tools/hud_probe.gd
    xvfb-run -a godot --rendering-driver opengl3 --script tools/screen_probe.gd

## Maintenance

Double-click `tools\cleanup.bat`, or:

    powershell -ExecutionPolicy Bypass -File tools\cleanup_superseded.ps1

This retires the 18 files the v5 rebuild superseded — the duplicate map
generator, the old HUD, the old resource nodes, the old squad script, the four
`scripts/test_*.gd` sandboxes and their orphaned scenes — along with their
`.uid` siblings.

**It moves, it does not delete.** Everything lands in `_superseded_backup\`
with its folder structure intact, next to a `.gdignore` so Godot skips the
folder. Putting a file back is a drag and drop. Delete the backup folder
yourself once the project has run clean for a while.

The script refuses to run anywhere without a `project.godot`, and supports
`-WhatIf` to preview.

Verified by running the equivalent move in a scratch copy: import stays clean,
`compile_all` goes from `checked=124` to `checked=113` with `failures=0`, and a
32-actor match still boots in 3.4s. Reopen the project in Godot afterwards so
it rebuilds its script class cache.
