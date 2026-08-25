# Forest Thrones — Third-Party Asset Credits

This game uses free third-party 3D assets. Some require **attribution** — the lines
below MUST be shown somewhere in the shipping game (a Credits screen is the normal
place) to comply with their licenses.

---

## Characters — KayKit "Adventurers" pack
- Source: KayKit Game Assets (https://kaylousberg.itch.io / github.com/KayKit-Game-Assets)
- License: **CC0 1.0 (Public Domain)** — no attribution legally required, but crediting is polite.
- Files: `assets/models/characters/*.glb` (Knight, Barbarian, Mage, Rogue, Rogue_Hooded)

## Beasts — animated animal models
Each species uses a different real animated model (see `rigged_beast.gd`).

### "Fox" → Wolf, Dire Wolf, Boar
- Source: Khronos glTF Sample Assets (github.com/KhronosGroup/glTF-Sample-Assets)
- **License: CC-BY 4.0 — ATTRIBUTION REQUIRED.**
- Required credit text (show verbatim in-game):
  > "Fox" model © 2014 tomkranis, rigging/animation © 2017 @AsoboStudio and @scurest,
  > licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
- Files: `assets/models/beasts/Fox.glb`

### "Horse" → Stag   ·   "Stork" → Raven
- Source: three.js example models (github.com/mrdoob/three.js), MIT License.
- Required credit text (show verbatim in-game):
  > Horse and Stork models from the three.js project, © three.js authors, MIT License.
- Files: `assets/models/beasts/Horse.glb`, `assets/models/beasts/Stork.glb`

---

### Notes
- Species are tinted/re-proportioned in `rigged_beast.gd` (wolf grey, boar dark & squat,
  stag brown horse-body, raven black flying bird). Tints multiply the base texture, so
  the wolf reads russet-grey rather than pure grey — a dedicated grey wolf model is a
  drop-in replacement (same rig interface).
- The Stag uses a horse body (no antlers) and the Raven a stork body; both are clear,
  distinct silhouettes. Dedicated deer/crow models drop in the same way if desired.
