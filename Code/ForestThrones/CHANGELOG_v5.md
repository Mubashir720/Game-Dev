# Forest Thrones — Engineering Pass v5

Everything below was measured on the real project in Godot 4.5, not estimated.

---

## 1. The blocker: the game could not have run on a phone

The 200x200 map was emitted as loose nodes — one `Node3D` per grass tuft, one
`StaticBody3D` with ~11 `MeshInstance3D` children per tree, and a brand-new
`StandardMaterial3D` for practically every part.

Measured on the original code:

| Metric | Before | After | Change |
|---|---|---|---|
| Map generation | **12,575 ms** | **2,287 ms** | 5.5x faster |
| Scene nodes | **113,038** | **10,387** | 10.9x fewer |
| Static memory | **1,694 MB** | **107 MB** | 15.8x less |
| Unique materials | **13,510** | **43** | 314x fewer |
| Unique meshes | **88,714** | **927** | 96x fewer |

Real renderer, same scene, measured with `RenderingServer.get_rendering_info`:

| Metric | Before | After |
|---|---|---|
| Draw calls / frame | **1,577** | **338–350** |
| Triangles / frame | **1,080,830** | **157,680** |
| Video memory | **327.5 MB** | **38.4 MB** |
| Process memory | **408 MB** | **148 MB** |

A mid-range phone has roughly 1.5 GB usable. 1.69 GB was a guaranteed
out-of-memory crash before a single frame was drawn.

### How

- **`scripts/render/visual_registry.gd`** — shared material and mesh cache.
- **`scripts/render/prop_baker.gd`** — welds a hand-authored prop node tree into
  one `ArrayMesh`, baking each part's colour into vertex colours so parts that
  differ only in colour collapse into one surface. Also normalises Godot's
  primitive meshes, whose 64-segment defaults made a single tree ~3,900
  triangles, and swaps sharp `BoxMesh` for bevelled boxes.
- **`scripts/render/chunk_batcher.gd`** — groups placements into
  `MultiMeshInstance3D`, one per mesh, plus one `StaticBody3D` per chunk for all
  its collision.
- **`scripts/render/actor_baker.gd`** — the same for animated rigs.
- **`scenes/world/map_generator.gd`** — rewritten to emit chunked, instanced,
  distance-layered geometry. Landscape design (rivers, biome warping, roads,
  bridges, elevation) is unchanged; only the emission strategy changed.
- **`scenes/world/world_streamer.gd`** — chunk collision and visibility stream
  around live entities.
- **`scenes/resources/resource_field.gd`** — 2,468 harvestable nodes as records
  in packed arrays with a spatial hash, rendered as MultiMesh, instead of 2,468
  `StaticBody3D` each with a full prop tree.

The camera's 200-unit far plane was also cut to 115 with matching depth fog.
An orthographic frustum is a box, so it was dragging 200 units of forest into
every frame regardless of the small visible area.

---

## 2. Bugs found and fixed

| Bug | Consequence |
|---|---|
| `DayNightController` looked up `$WorldEnvironment`, but it is a **sibling** in `main.tscn` | Sky colour, fog colour and fog density never changed. The entire day/night atmosphere was dead code. |
| `GameManager` emitted `day_phase_changed` **every frame** | Every listener re-ran transition work 60x/second; the log filled with one line per frame. |
| `GameManager._ready()` called `start_match()` on autoload | The 25-minute match clock started at app launch, on the main menu. The traitor unlock and zone shrink could pass before the player pressed Play. |
| Torso and Head in the character rig had no `name` set | `CharacterAnimator` looks them up by name — those lookups always failed, so torso lean and head turn never ran. |
| Face, crown and cape were **siblings** of the head, not children | Turning the head left the eyes, nose and crown behind. The rig could not animate without falling apart. |
| Arm pivots sat *inside* the torso radius on the heavy build | Arms rendered inside the ribcage. Characters looked armless. |
| Hut proximity-aura ring was baked into the hut's opaque mesh | An 8-unit solid green ring around every hut, reading as laser lines across the map. |
| Transparent baked materials used the opaque shader | Every transparent part in the game (aura rings, well water, goggle lenses, ember trails) rendered solid. |
| Bot build check required the builder to personally carry 6+ resources | Soldier A never gathers, so no squad ever built past its starting Hut for a whole match. |
| HUD safe area used a `MarginContainer` | It force-fits children to its own rect and discards their anchors, collapsing the entire HUD into one stacked full-width panel. |
| `UITheme.body()` word-wraps by default | Table headers and role labels became vertical stacks of single letters. |

---

## 3. The match now actually exists

`main.tscn` previously spawned **one** player, four hard-coded structures and one
wolf. It now runs the game in the design document.

- **`scenes/actors/actor.gd`** — the shared body. Stats, inventory, HP states,
  movement, combat, animation. Reads no input and decides nothing.
- **`scenes/player/player.gd`** — turns touch/keyboard into intent.
- **`scenes/ai/bot_agent.gd`** — fills the other 31 slots. Role-shaped behaviour,
  staggered 2.5 Hz decisions, stuck-detection steering for a dense forest.
- **`scenes/ai/squad_brain.gd`** — squad treasury, stockpile, Queen income with
  the emergency rate, build order, Traitor Token, posture.
- **`scenes/ai/match_director.gd`** — 8 squads x 4, Traitor distribution,
  simulation LOD, win conditions.

Verified over a 10-minute simulated match:

```
boot: 32 actors, 8 squads, 2.7 s, 131 MB
LOD:  4 full / 0 reduced / 28 minimal
traitors: 6 tokens across 6 squads, 2 squads clean   <- exactly GDD S11
t=450s  squad1 stock W124 S20 F11, 6 structures built
t=510s  posture EXPAND, 4 traitors activated, treasuries stolen
t=570s  7 players downed, squad_3 down to 3 members
```

---

## 4. Screens

Complete flow: **Main Menu -> Character Select -> Loading -> Match -> Post-Match.**

- **`scenes/hud/ui_theme.gd`** — a real token system. Colours, type scale,
  spacing and radii defined once; the `Theme` built once and cached; component
  helpers so every screen builds the same widgets the same way. 56 px minimum
  touch targets throughout.
- **`scenes/menus/main_menu.gd`** — live rotating 3D render of your archetype.
- **`scenes/menus/archetype_select.gd`** — role tabs then archetype cards, with
  every ability string copied from the GDD S4 table.
- **`scenes/menus/loading_screen.gd`** — real progress from world generation,
  with rotating field notes that double as onboarding for GDD S20's "too many
  systems" risk.
- **`scenes/hud/game_hud.gd`** — floating multitouch joystick, thumb-arc action
  cluster, vitals, squad roster with Trust dots, treasury, minimap, ransom
  ticker, event feed, phase-aware match clock.
- **`scenes/hud/post_match_summary.gd`** — leads with the full Traitor table,
  including which two squads were clean.
- **`scenes/minimap/minimap.gd`** — biome/river/road terrain baked from the
  generator's own zone field, so it can never disagree with the world.

---

## 5. Visuals

- **`assets/shaders/stylized_prop.gdshader`** — rim light, contact shading and
  wind sway on one shared material, so it costs nothing extra and preserves
  batching. (A first attempt replaced Godot's lighting with a custom `light()`
  function; it flattened every tree into a blob and crushed shadows to black.
  This version layers on top of the engine's lighting instead.)
- **Bevelled boxes** — every box above 0.10 units is chamfered at bake time.
  Sharp 90-degree edges are the loudest "untextured programmer geometry" signal
  there is.
- **Character rig rebuilt** — rounded connected anatomy, shoulder and elbow
  joints that actually bridge the limbs, mitten hands, boots with toes, a jaw
  and hair cap, and a Root > Torso > Head hierarchy that can be animated.
- **Blob shadows** under every actor, so nobody looks pasted onto the ground.
- **Clearings** around drop zones and landmarks, so squads no longer spawn
  inside a tree.

---

## 6. Second pass — dormant systems wired, dead files identified

The first pass rebuilt what was slow or broken. The second pass went looking for
code that *existed and compiled but nothing ever ran*. That is the worst class of
problem, because the file's presence reads as "done" in any review.

### 6.1 Twelve archetype abilities were dead code

`scenes/roles/archetypes/*.gd` — all twelve — were written, correctly named, with
sensible cooldowns. Nothing in the project ever instantiated one. Every archetype
therefore played identically, which removes the entire reason the character
select screen exists.

Fixed by adding `scenes/roles/ability_controller.gd`, attached to every `Actor`
(player and bot alike) in `_attach_abilities()`. It resolves `archetype_id` to a
script, ticks the cooldown, exposes `charge()` for the HUD ring, forwards kills
so kill-triggered passives fire, and gives bots a role-shaped rule for when to
press the button (`BOT_CHECK_INTERVAL` 1.1s, so 31 bots don't evaluate per frame).

`ability_base.gd` was rewritten to carry the shared work: `caster`, `charge()`,
`activate()`, `passive_tick()`, `on_kill()`, `allies_within()`, `enemies_within()`
and `spawn_pulse()`. All twelve subclasses were rewritten against it.

Verified — `tools/ability_probe.gd` → `abilities_ok=12 abilities_bad=0`:

| Archetype | Ability | Cooldown |
|---|---|---|
| Warlord | Rally Cry | 45s |
| Regent | Tax Edict | 90s |
| Beastlord | Tame | 25s |
| Engineer | Overclock | 60s |
| Witch | Hex | 30s |
| Herbalist | Brew | 18s |
| Guardian | Shield Wall | 20s |
| Berserker | Frenzy | 120s |
| Sapper | Demolish | 20s |
| Scout | Flare | 45s |
| Archer | Volley | 4s |
| Builder | Rapid Build | 30s |

The HUD ability button now calls `player.abilities.use()` and draws the real
cooldown ring instead of a decorative one. In a live match, bot Regents show a
`6c` treasury within the first second — Tax Edict firing, visible in the
leaderboard.

### 6.2 Zone shrink was dead *and* wrong in four separate ways

`scenes/zone_shrink/zone_shrink.gd` was never instantiated — and had it been, it
still would not have worked:

1. It measured the safe zone from `grid_to_world(Vector2i(32, 32))`. On a 200x200
   map the centre is (100, 100); the "safe zone" was anchored two thirds of the
   way toward a corner.
2. It hard-coded a 32-tile starting radius. The map's half-extent is 100 tiles,
   so seven eighths of the world was outside the border from the first second.
3. It read `player.stats.state`. No such member exists — that line throws on the
   first tick.
4. It only looked for a node literally named `Player`. Actors are named
   `squad_1_King` and friends, so it would have found nobody, damaged nobody, and
   never considered the other 31 participants at all.

Rewritten to damage every living actor and beast outside the border, publish its
radius so the minimap and fog wall agree with the damage, and render an
inside-out cylinder wall so the border reads as closing in rather than as a
distant tube.

Verified — `tools/zone_probe.gd`: `radius_tiles=10.6  world_radius=21.2`,
`border flagged outside=16/16  wrongly flagged inside=0/16  total hits=32`,
`RESULT=PASS`.

### 6.3 DESIGN DECISION NEEDED — the GDD contradicts itself on shrink rate

GDD §3 says the border closes **1 tile per 30 seconds**. GDD §12 says the match
ends with every squad converged on the Cursed Throne and the zone tiny.

Both cannot be true on a 200x200 map:

- Shrink window: minute 17 → minute 25 = **480 seconds**
- At 1 tile / 30s that is **16 tiles** of closure
- Half-extent is 100 tiles → the border finishes the match at **radius 84**
- **84% of the map is still safe at the final whistle.** Nobody is forced
  anywhere, and §12's convergence never happens.

The literal constant contradicts the stated intent, so the rate is now *derived*
from the two things the design actually commits to — the window, and the outcome.
`Constants.ZONE_SHRINK_RATE` is left in place but no longer drives anything; tune
the endgame with `@export var final_radius_tiles` (currently 9.0) instead. The
curve is smoothstep-eased: slow at first so squads have time to pick up and move,
then decisive.

**This is your call, not mine.** Either §3's rate or §12's outcome has to give.
If you want the literal 1-tile/30s rate, the shrink has to start around minute 9,
not 17 — which rewrites the whole mid-game.

### 6.4 Two more systems that existed but were never created

`MomentsEngine` and `ForestCurse` had exactly the same problem. `match_root.gd`
now creates them in `_attach_systems()` alongside `ZoneShrink`.

### 6.5 Eighteen superseded files

Reachability analysis — resolving both `res://` paths *and* `class_name`
identifiers — found 18 files that nothing reachable references. Five of them look
referenced at a glance, but only reference each other: a closed dead cluster, so
they are safe to remove together rather than one at a time.

| File | Superseded by |
|---|---|
| `scripts/data/map_generator.gd` | `scenes/world/map_generator.gd` (older duplicate) |
| `scenes/hud/hud.gd` / `.tscn` | `scenes/hud/game_hud.gd` |
| `scenes/lighting/day_night_cycle.gd` / `.tscn` | `day_night_controller.gd` |
| `scenes/resources/resource_spawner.gd` | `scenes/resources/resource_field.gd` |
| `scenes/resources/resource_node.gd` / `.tscn` | `resource_field.gd` (records, not nodes) |
| `scenes/squad/squad.gd` | `scenes/ai/squad_brain.gd` |
| `scenes/player/player_stats.gd` | `scenes/actors/actor.gd` |
| `scenes/player/player.tscn` | MatchDirector spawns the player from script |
| `scenes/camera/game_camera.tscn` | IsometricCamera node in `main.tscn` |
| `scenes/world/world.tscn` | `main.tscn` creates the World node directly |
| `scenes/minimap/minimap.tscn` | GameHUD builds the Minimap in code |
| `scripts/test_economy.gd` | the harnesses in `tools/` |
| `scripts/test_living_world.gd` | the harnesses in `tools/` |
| `scripts/test_moments.gd` | the harnesses in `tools/` |
| `scripts/test_polish.gd` | the harnesses in `tools/` |

Retiring them is scripted — double-click `tools/cleanup.bat`, or run
`tools/cleanup_superseded.ps1` from the project root.

**The script moves, it does not delete.** Everything lands in
`_superseded_backup/` with its folder structure intact, next to a `.gdignore` so
Godot skips the folder entirely. The first version of this script deleted, on the
stated grounds that "everything is in git" — but the repo root is `D:\Game Dev`,
one level *above* the project, and nothing here can verify these particular files
were ever committed. A safety net you cannot check is not a safety net, so the
script now moves instead. Delete `_superseded_backup/` yourself once you are
satisfied.

Verified by running the equivalent move in a scratch copy: import stays clean,
`compile_all` goes from `checked=124` to `checked=113` with `failures=0`, and a
32-actor match still boots in 3.4s with all 8 squads live.

### 6.6 The HUD was overlapping itself, and I only caught it by rendering it

Wiring the ability button up made a layout bug visible that had been there all
along. A screenshot of a live match showed the action buttons sitting on top of
the treasury panel, and `RALLY CRY` running off the right edge of the screen.

Measured with a new harness rather than guessed at:

| Control | Was | Problem |
|---|---|---|
| Treasury panel | 228 x **341** | Stretched to fill the column for ~130px of content |
| `RALLY CRY` | x 1162..**1282** | 2px past the 1280px screen edge |
| `BUILD` | y 516..582 | 5,940px² on top of the treasury |
| `ATTACK` | y 590..694 | 1,008px² on top of the treasury |

Three separate root causes, all worth naming because each one is a trap that
recurs:

1. **`UITheme.body()` wraps by default.** A wrapping Label in a narrow HBox
   reports a tall minimum size, which is what inflated four resource rows into a
   341px panel. (It is the same default that once rendered "KING" as a vertical
   stack of letters.) Added `UITheme.line()` for single-line text — labels,
   values, stat names — and left `body()` for actual prose.
2. **A Button's minimum width is driven by its caption.** The ability button was
   placed as an 84px disc but rendered 120px wide because "RALLY CRY" is 120px
   wide, which pushed it off-screen. Twelve archetypes means twelve names, and a
   disc cannot hold "SHIELD WALL". It is now a 148px **pill** with `clip_text`,
   and the probe checks every one of the twelve names against it.
3. **The layout comment asserted a number nobody had measured** — "the right
   column reaches roughly 480px down". It reached 599.

Also fixed while in there: the action buttons were 34% opacity, so `ATTACK` read
lavender over water and red over grass — the primary action changing hue with the
terrain behind it. They are now opaque enough to own their colour. And the
ability pill gained a drain bar, so the cooldown is readable without a timer.

`tools/hud_probe.gd` is the guard: it measures every control's real rect and
fails on overlap, off-screen, or clipped caption. Verified `RESULT=PASS` at
1280x720, 960x720, 1560x720 and 854x480 — the project stretches `canvas_items`
with `aspect=expand`, so the aspect ratio, not the pixel count, is what moves the
layout.

---

## 7. Third pass — the bug that made everything look cheap

### 7.1 Every box in the game was rendering inside-out

`PropBaker.bevelled_box()` replaces plain boxes with chamfered ones so nothing in
the game has a razor-sharp 90-degree edge. It emitted its **six flat faces and
eight corner caps with reversed winding**. The shader culls back faces, so those
20 of 44 triangles were never drawn. What survived was the twelve bevel strips —
a wireframe cage of the box's edges.

On screen that reads as a pale, glassy shell wrapped around a solid core. Beasts
looked like they were sealed in glass. Hut walls were see-through. The watchtower
had rainbow z-fighting stripes across its platform. It looked exactly like a
transparency or lighting problem, which is why it survived several visual passes
aimed at lighting and rim strength.

Every box in the project goes through this function, so this affected props,
structures, all 12 archetypes and all 4 beasts simultaneously.

**The false start, recorded because it cost real time.** The first fix flipped the
twelve edge strips instead, on the reasoning that a triangle's winding normal
should point away from the part's centre. That reasoning is backwards for Godot:
front faces are CLOCKWISE seen from outside, so correct geometry has
`(b-a) x (c-a)` pointing TOWARD the centre. Godot's own `BoxMesh`, `SphereMesh`
and `CylinderMesh` all fail the naive test. Testing the engine's own primitives
first would have caught the inverted assumption immediately; `tools/mesh_probe.gd`
now does exactly that before it reports anything else.

Verified: `mesh_probe` reports `RESULT=PASS bad=0` across `bevelled_box` at five
sizes, 4 beasts, 12 archetypes and 10 structures. Reintroducing the original
winding makes it report 28 failures, so the guard genuinely fails when it should.

### 7.2 Redundant contact shadows welded into the beasts

Each beast root carried a flat `PlaneMesh` at alpha 0.35 as a fake grounding
shadow, on top of the real soft-edged `GroundShadow` that `ActorBaker` already
adds. Worse, it was part of the raw tree, so the baker welded it into the body
mesh — and the baker groups surfaces by roughness and metallic without carrying
transparency across, so it came out opaque. Removed; `SHADOW_SIZE` is the knob.

### 7.3 The beasts were never boxes

The previous "what is NOT done" list claimed beast anatomy was untouched and
still box-shaped. That was stale: `beast_factory.gd` already builds per-limb
wolves, ravens with wings, boars with tusks and stags with antlers. What made
them look wrong was 7.1, not their anatomy. Corrected here rather than left to
mislead the next reader.

### 7.4 Weapons you could not see

The camera is orthographic and isometric; a character stands about 1.9 units and
renders roughly 150px on a 720p screen, so one world unit is about 79 pixels. At
that scale a 0.02-thick sword blade is 1.6 pixels and a 0.005 bowstring is under
half a pixel. Thirteen parts across six archetypes were below the readable floor:

| Archetype | Part | Was | Now |
|---|---|---|---|
| Warlord | broadsword blade | 0.020 (1.6px) | 0.055 |
| Berserker | axe head / edge | 0.035 / 0.010 | 0.065 / 0.075 |
| Guardian | shield emblem | 0.020 | 0.050 |
| Scout | dagger blade / guard | 0.015 / 0.025 | 0.055 / 0.055 |
| Beastlord | bone charms | 0.030 | 0.055 |
| Archer | bowstring | 0.010 (0.8px) | 0.050 |
| Archer | bow limb | 0.020 tube | 0.045 tube |

The archer's bowstring was also positioned 0.38 along X — which, because the bow
torus is rotated 90 degrees about Z, is along the ring's AXIS. It floated beside
the character instead of crossing the bow. Moved onto a diameter of the ring.

`tools/weapon_probe.gd` now fails any held part under ~3px at gameplay distance.

### 7.5 Character previews spent most of their time facing away

Main menu and character select both span the preview on a continuous 360-degree
turntable. Most of that cycle shows the character's back, which tells the player
nothing, and it makes comparing two archetypes impossible because you never see
them from the same angle. Both now oscillate gently around front-facing.

### 7.6 Screen layout audit

`tools/screen_probe.gd` checks main menu, character select, loading and
post-match for off-screen controls, clipped captions and tap targets under 44px.
All four pass at 1280x720, 960x720 and 1560x720. The HUD probe passes at the same
three.

Performance after all of this is unchanged: 336 draw calls, 155k primitives,
38.8 MB video memory, 148 MB process, 32 actors, boot in 3.0s.

---

## 8. What is NOT done

Being explicit, because "production ready" needs an honest boundary.

- **No networking.** The GDD specifies server-authoritative play with client
  prediction. This is a single-process match: you plus 31 bots. Everything is
  structured for it (`Actor` has no input coupling, the map is deterministic
  from a seed), but the netcode is not written.
- **Partially implemented GDD systems.** Capture / carry / imprison, the 5
  prison options, Chain Gang, interrogation tiers, the Ransom Board economy,
  Black Market, Forest Curse triggers, beast taming and the Moments clip engine
  exist as stubs or data-only, not full loops.
- **Beast and character animation** is procedural and fairly simple — walk,
  attack and idle. There are no transitions between states, no hit reactions,
  and no death animation beyond falling over.
- **No audio.**

Run `godot --headless --script tools/compile_all.gd` before every commit — it
catches the parse errors that `--import` alone silently misses.
