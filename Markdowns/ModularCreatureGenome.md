# Modular Creature Genome — Body-Part Architecture

This document describes how procedural creature bodies are decomposed into
**modular parts** in Elementals, how those parts compose into a full creature,
and how to add a new playable species without rewriting the breeding,
rendering, or UI layers.

The goals of this architecture are:

1. **ANY actor × ANY actor breeding** with no special-cased per-pair code.
2. **Visible compound features** in hybrids — not just colour blending but
   actual body-part grafts from both parents.
3. **Stable per-creature identity** so the same creature renders identically
   every time its preview rebuilds (no re-roll on refresh).
4. **Modular**: adding a new species touches only the new species' files plus
   a single dispatch case in `ActorData._populate_graft_slot`.

---

## Layer 1 — `ActorData` is the shared foundation

`Components/ActorComponents/ActorData.gd` is the abstract base every breedable
creature derives from. It owns:

- **Ability scores** (`strength`, `dexterity`, …) — every creature has them.
- **Breeding state** (`gender`, `is_pregnant`, `pregnancy_timer`,
  `pregnancy_father`, `is_exhausted`).
- **Lifecycle** (`is_selected`, `age_days`, `stamina_max`, `stamina_current`).
- **Visual mirrors** (`base_color`, `pattern_color`) — kept in sync with the
  genome palette via `_sync_legacy_palette_from_genome` so legacy UI
  (`GoatRenderer`, `ActorCard` tints) still works.
- **Identity** (`render_seed: int`) — see Layer 5.
- **Lineage** (`mimic_blood: float`, `inherit_mimic_skills: bool`) — Mimic
  bloodline propagates universally through breeding.

ActorData also exposes the **universal breeding algorithm** (Layer 4) and
the **name generator** (`generate_name_from_seed`).

---

## Layer 2 — Each species owns a `genome: Dictionary`

Every species data class (`MimicData`, `MushroomData`, `GoblinData`, future
species) exposes a `genome: Dictionary` field as the source of truth for that
creature's body. The dictionary contains **module slots**, and each slot is a
sub-dictionary of fields.

The shape is **species-flavoured but conceptually consistent**:

| Slot          | What it represents                | Mimic example fields                                  | Mushroom example fields                                |
|---------------|-----------------------------------|-------------------------------------------------------|--------------------------------------------------------|
| `body`        | Lower-body silhouette + dims      | `shape` (`wooden_box` / `treasure_chest` / `vase` / `casket` / `barrel` / `crate`), `width`, `height`, `depth`, `length_stretch`, `neck_ratio` | `height` (stem), `radius_top`, `radius_bottom`, `foot_offset` |
| `head` / `lid`/`cap` | Top of the creature where eyes sit | `lid.variant` (`flat` / `rounded` / `peaked` / `none`), `lid.thickness`, `lid.open_angle_idle` | `cap.profile` (`dome` / `flat` / `cone` / `bell`), `cap.radius`, `cap.height`, `cap.spot_count` |
| `face`        | Eyes, mouth, tongue, teeth        | `eye_count` (2–8), `eye_radius`, `tooth_count`, `tongue_length`, `tongue_protrude`, `eyes_on_lid` | `eye_count` (1–6), `eye_spread`, `mouth_width`, `expression` (smile/frown/o/smirk) |
| `palette`     | Colours                           | `body_color`, `accent_color`, `mouth_color`, `eye_color`, `tongue_color`, `tooth_color` | `cap_color`, `spot_color`, `stem_color`, `eye_color`, `mouth_color` |
| `surface`     | Texture hints                     | `texture_hint` (`wood_planks` / `ceramic` / `polished` / `weathered` / `stone`), `roughness`, `emission` | `texture_hint` (`matte`), `roughness` |
| `decorations` | Surface ornaments                 | `band_count`, `clasp_count`, `gem_count`, `lock_present`, `handle_present` | n/a (mushrooms have spots instead — under `cap`) |
| `limbs`       | Arms & legs                       | `has_arms`, `has_legs`, `arm_length`, `arm_radius`, `arm_y_offset`, `arm_droop`, `leg_length`, `leg_radius`, `leg_spread`, `foot_size` | Same field names as Mimic for parallelism |
| `animation`   | Idle bob, lid speed, etc.         | `lid_idle_speed`, `lid_idle_amplitude`, `tongue_wiggle_speed`, `tongue_wiggle_amplitude` | `bob_speed`, `bob_amplitude`, `idle_lean_speed`, `idle_lean_amplitude` |
| `attack`      | Bite/strike specs                 | `name`, `reach`, `damage_die`, `damage_type`, `secondary_damage_type`, `secondary_damage` | Same shape |
| `mutation`    | Rare special features             | `cursed_glow`, `glow_color`, `blood_stained`, `gem_encrusted` | `glow`, `glow_color`, `spore_burst_radius_bonus` |
| `grafted`     | Cross-species feature data (Layer 6) | `source_species`, `mushroom_cap_radius`, `has_cap_graft`, `has_spots_on_body`, `has_extra_eyes_on_cap`, `has_stem_antenna`, … | `source_species`, `mimic_band_count`, `has_band_graft`, `has_tooth_graft`, `has_extra_eyes_on_cap`, `has_lid_crown`, `has_gem_scatter`, … |

**Discipline rules**:

1. **Field names that exist in multiple species' genomes must mean the same
   thing** (`eye_count`, `eye_color`, `has_arms`, `arm_length`, etc.). This
   is what lets the universal breeder blend them across species without
   per-pair code.
2. **Species-specific slots use species-specific names** (`lid` vs `cap`,
   `body.shape` vs `body.height`-only). The crossover blender skips slots
   that don't exist in both parents.
3. **Every species declares the FULL slot list in `default_genome()`**, even
   if the procedural body only reads a subset. This keeps the data shape
   forward-compatible — when a future patch starts reading e.g. `surface`,
   it's already there.

---

## Layer 3 — Procedural body builders read the genome

Each species has a procedural body script:

- `src/actors/types/ProceduralMimicChest.gd` — handles the six Mimic shapes,
  lid variants, face, decorations, limbs, mutations, and cross-species grafts.
- `src/actors/types/ProceduralMushroomBody.gd` — handles cap profiles, stem,
  face, limbs, mutations, and cross-species grafts.
- *(Future)* `ProceduralGoblinBody.gd`, `ProceduralGoatBody.gd`, etc.

Each script:

1. Reads `<species>_data.genome` at `_ready` (and on every `<species>_data`
   setter assignment if in-tree).
2. Clears prior scaffolding via `_clear_built_children()` using immediate
   `remove_child + free` (NOT `queue_free`), so multi-frame rebuilds don't
   leave ghost meshes.
3. Builds sub-root `Node3D`s per concept: `_body_root`, `_lid_pivot` (or
   `_cap_root`), `_face_root`, `_decorations_root`, `_limbs_root`.
4. Animates via `_process(delta)` reading `genome["animation"]` — uses
   `_cap_base_y + sin(t) * amp` (ADD to base, never overwrite) so animation
   loops cleanly around the stable rest pose.
5. Calls `_apply_cross_species_graft(genome["grafted"])` at the end of
   `rebuild_from_genome()` so the secondary parent's traits paint on top of
   the primary body.

### Cap / lid orientation rules

- **`is_hemisphere = true` on `SphereMesh` is broken / inverted** — Godot 4
  generates the bottom half. Don't use it. The mushroom cap uses a full
  `SphereMesh` positioned so the lower hemisphere becomes the cap's
  underside flange and the upper hemisphere is the visible dome.
- **The mimic treasure-chest lid is a true half-cylinder** built via
  `SurfaceTool` — `_build_half_cylinder_mesh()` produces an upper semicircle
  curved surface + flat bottom + two semicircular end caps. The lid material
  has `cull_mode = DISABLED` so any winding mistake doesn't make the lid
  appear transparent.

### Stable rendering

- Procedural builders own a private `RandomNumberGenerator _rng`.
- At the start of `rebuild_from_genome`, `_rng.seed = <data>.render_seed`
  (Layer 5).
- All random calls inside the body **must use `_rng`** — never the global
  `randi()`/`randf()`. This is what makes the same creature render
  identically every rebuild. Audit any new code carefully.

---

## Layer 4 — Universal breeding

`ActorData.universal_crossover_breed(parent_a, parent_b) -> ActorData` is the
**single entry point** for cross-species breeding.

```text
Both parents same species → defer to parent_a.create_offspring(parent_b)
                            (richer same-species crossover lives in subclass)
Different species         → universal path below
```

Universal path:

1. **50/50 species roll**: `kid_is_a = randf() < 0.5`. The winning parent
   becomes `primary` (kid's body type), the loser becomes `secondary`.
2. **Solo breed** the primary: `kid = primary.create_offspring(primary)` —
   produces a near-clone of the primary with mild mutation jitter.
3. **Blend stats** from BOTH parents into the kid (override solo-clone stats).
4. **Transfer genome traits** from secondary to kid (`_transfer_genome_traits`):
   - **Palette**: every shared-name colour field lerps 30–55%. Plus
     cross-species name mapping — Mushroom `cap_color` blends into Mimic
     `body_color`, Mushroom `spot_color` into Mimic `accent_color`, etc.
   - **Face**: `eye_count` averages and clamps to `[1, 5]`, plus numeric
     fields (`eye_radius`, `eye_spread`, `mouth_width`, `tongue_length`,
     `tongue_thickness`, `tooth_count`, `tooth_size`) all average + jitter.
   - **Limbs**: if `secondary` has `has_arms`/`has_legs` true, the kid
     UNCONDITIONALLY inherits the limbs with the source's actual dimensions.
   - **Animation**: numeric fields blend.
   - **Mutation**: bools 50% transfer, colours 30–55% lerp, numbers blend.
5. **Populate the graft slot** (`_populate_graft_slot`): see Layer 6.
6. **Sync legacy palette mirrors** so `ActorData.base_color` / `pattern_color`
   match the new genome palette.
7. **Apply mimic lineage** — propagates `mimic_blood` (averaged or uplifted
   if a parent is pure Mimic) and rolls `inherit_mimic_skills` against the
   30/60/100 probability gates.
8. **Fresh `render_seed`** + auto-generated name from that seed.

**Adding a new species requires NO changes to existing classes.** Its own
`create_offspring` follows the template:

```gdscript
func create_offspring(partner: ActorData) -> ActorData:
    if partner == null:
        return null
    if partner is MyNewSpeciesData:
        return _create_pure_my_species_kid(partner as MyNewSpeciesData)
    return ActorData.universal_crossover_breed(self, partner)
```

That's it. Mimic × MyNewSpecies, Mushroom × MyNewSpecies, etc. all route
through the universal path automatically.

---

## Layer 5 — Identity: `render_seed`

Without a stable seed, procedural body builders use `_rng.randomize()` per
instance, so each rebuild produces a different visual for the same genome
data — the creature LOOKS regenerated every time its card refreshes.

`ActorData.render_seed: int` is an `@export` field initialised to a fresh
`randi()` in each subclass's `_init`. Bred kids get a fresh `randi()` in
`universal_crossover_breed`. Procedural body builders seed `_rng` from this
value at the start of `rebuild_from_genome`. The result is `(genome,
render_seed) → identical visual every time`.

The same seed also generates the creature's **fantasy name** via
`ActorData.generate_name_from_seed(seed)` — 40 starts × 15 mids × 32 ends ≈
19,000 unique combinations. Identical name on every reload because the seed
is `@export`-serialised.

---

## Layer 6 — Cross-species grafts (Frankenstein layer)

When two different species breed, the kid is one parent's body type plus a
"grafted" payload of **body-part data extracted from the OTHER parent**.
The procedural body builder renders the grafted parts on top of its normal
scaffolding, so a Mimic kid born from a Mushroom partner is visibly a chest
WEARING a mushroom cap (with spots), not just a chest with re-tinted colours.

### The `grafted` slot

Each species' `default_genome()` declares a `"grafted"` sub-dict. Fields are
**source-species-prefixed** so the slot can hold data from any other species
on the kid:

```gdscript
# MimicData "grafted" slot, populated when secondary parent is Mushroom:
"grafted": {
    "source_species": "mushroom",
    "mushroom_cap_profile": "dome",
    "mushroom_cap_radius": 0.31,
    "mushroom_cap_color": Color(0.86, 0.25, 0.25),
    "mushroom_spot_count": 5,
    "mushroom_spot_color": Color(0.95, 0.95, 0.88),
    "mushroom_eye_color": Color(0.10, 0.10, 0.10),
    # COMPOUND MODULAR FEATURE FLAGS (each rolled independently at breed):
    "has_cap_graft": true,         # 85% mushroom cap on top of lid
    "has_spots_on_body": true,     # 65% spots painted across chest
    "has_extra_eyes_on_cap": true, # 65% glowing eyes on the cap
    "has_stem_antenna": false,     # 35% stem antenna sticking up
    "extra_eye_count": 6,
    "extra_eye_radius": 0.05,
    "extra_eye_glow": false,
    # Goblin / Goat graft fields (zero/empty when source != that species):
    "goblin_skin_color": ...,
    "goat_horn_present": false,
}
```

Mushroom's mirror version contains `mimic_band_count`, `mimic_tooth_count`,
`mimic_glow`, `has_band_graft`, `has_tooth_graft`, `has_extra_eyes_on_cap`,
`has_lid_crown`, `has_gem_scatter`, etc.

### Populating the slot — `ActorData._populate_graft_slot(kid, source)`

Single dispatch on `source.get_actor_type()`:

```text
"MushroomData" → fill kid.genome["grafted"] with mushroom_* fields from
                  source's cap/face/palette slots + roll compound flags
"MimicData"    → fill with mimic_* fields from source's
                  face/decorations/palette/mutation slots + roll flags
"GoblinData"   → fill goblin_skin_color from source.base_color
"GoatData"     → fill goat_pattern_color and goat_horn_present
```

**Adding a new species requires one new branch here**. No edits to other
species' classes.

### Rendering the graft — `_apply_cross_species_graft`

Each procedural body has a `_apply_cross_species_graft(grafted)` method that
dispatches on `grafted["source_species"]` and calls per-source graft helpers.
The helpers are **independent and additive** — each compound feature flag
gates its own render path:

```text
# ProceduralMimicChest._apply_cross_species_graft, "mushroom" case:
if has_cap_graft:        _graft_mushroom_features(grafted)
if has_spots_on_body:    _graft_mushroom_spots_on_body(grafted)
if has_extra_eyes_on_cap: _graft_extra_eyes_on_cap(grafted)
if has_stem_antenna:     _graft_stem_antenna(grafted)
```

Sibling hybrids therefore display visibly different combinations of features
from the same parents, because each compound flag is an independent coin
flip at breed time and the rolls are stored in the genome.

### "Self-heal" for legacy data

`_populate_graft_slot` adds the `grafted` slot if it doesn't exist (e.g.,
when one parent was saved before the slot was added to the schema). It
reaches into the kid's own class via `kid.has_method("default_genome")`,
pulls the default `grafted` sub-dict, and clones it into the kid's genome.
No species-specific casts.

---

## Layer 7 — UI: `ActorCard` + `CreaturePreview`

- `UI/DisplayCard/ActorCard.gd` is polymorphic — `actor_resource: ActorData`
  (NOT `GoatData`). Display name reads from `goat_name` if present, else
  `creature_name`, else `get_actor_type()`. Age / level / stats use property-
  existence checks so non-Goat resources don't crash.
- `UI/CreaturePreview.tscn` + `.gd` — a `SubViewportContainer` with
  `own_world_3d = true` (each card has its own isolated 3D world, no
  cross-card light bleed or position collisions). Dispatches on data type:
  - `MimicData` → spawn `ProceduralMimicChest`
  - `MushroomData` → spawn `ProceduralMushroomBody`
  - `GoblinData` / `GoatData` → small placeholder cube tinted from the
    creature's palette (real procedural bodies for these are future work)

`_rebuild()` uses immediate `remove_child + free` (NOT `queue_free`) to
prevent ghost-mesh stacking when the actor_data is reassigned.

---

## Layer 8 — Where to put what (file map)

| Concern                        | File                                                                         |
|--------------------------------|------------------------------------------------------------------------------|
| Universal breeding algorithm   | `Components/ActorComponents/ActorData.gd::universal_crossover_breed`         |
| Cross-species trait transfer   | `ActorData.gd::_transfer_genome_traits` (+ `_blend_palette_slot`, `_blend_face_slot`, …) |
| Cross-species graft populate   | `ActorData.gd::_populate_graft_slot`                                         |
| Name generator                 | `ActorData.gd::generate_name_from_seed`                                      |
| Mimic body genome              | `Components/BreedingComponents/MimicData.gd::default_genome()`               |
| Mimic same-species crossover   | `MimicData.gd::_create_pure_mimic_kid` + `_crossover_genome`                 |
| Mimic procedural rendering     | `src/actors/types/ProceduralMimicChest.gd`                                   |
| Mushroom body genome           | `MushroomData.gd::default_genome()`                                          |
| Mushroom same-species crossover| `MushroomData.gd::_create_pure_mushroom_kid` + `_crossover_genome`           |
| Mushroom procedural rendering  | `src/actors/types/ProceduralMushroomBody.gd`                                 |
| Goblin body genome             | `Components/BreedingComponents/GoblinData.gd`                                |
| Goat body genome               | `Components/BreedingComponents/GoatData.gd`                                  |
| Ranch UI / cheats              | `Components/BreedingComponents/Ranch/Ranch.gd` + `.tscn`                     |
| Herd-state actor card          | `UI/DisplayCard/ActorCard.gd` + `.tscn`                                      |
| 3D card preview                | `UI/CreaturePreview.gd` + `.tscn`                                            |

---

## Layer 9 — Adding a new species (the contract)

To add e.g. `SlimeData`:

1. **Data class** at `Components/BreedingComponents/SlimeData.gd`:
   - Extends `ActorData`
   - Declares `genome: Dictionary` with `default_genome()` returning the
     full nine-slot shape (body, head/cap/lid, face, palette, surface,
     decorations, limbs, animation, attack, mutation, **grafted**). Use
     slot field names from Layer 2 where they overlap with other species.
   - `_init()` initialises stat profile, `render_seed = randi() if 0`,
     `creature_name = generate_name_from_seed(render_seed)`.
   - `create_offspring(partner)`:
     ```gdscript
     if partner == null: return null
     if partner is SlimeData: return _create_pure_slime_kid(partner)
     return ActorData.universal_crossover_breed(self, partner)
     ```
   - `_create_pure_slime_kid` — uses `_crossover_genome` (copy the static
     helper from `MimicData.gd` if needed).

2. **Procedural body** at `src/actors/types/ProceduralSlimeBody.gd`:
   - Extends `Node3D`
   - Owns `slime_data: SlimeData` with a setter that calls
     `rebuild_from_genome` if `is_inside_tree()`.
   - Declares private `_rng := RandomNumberGenerator.new()`.
   - `rebuild_from_genome` seeds `_rng` from `slime_data.render_seed`, then
     builds sub-roots. Use immediate `remove_child + free` for clearing.
   - Last step: `if g.has("grafted"): _apply_cross_species_graft(g["grafted"])`
     with per-source-species graft helpers (mimic / mushroom / goblin /
     goat — at minimum the species you want hybridised against).

3. **Graft hookup** in `ActorData._populate_graft_slot`:
   - Add one `elif source_type == "SlimeData":` branch that pulls
     slime-distinctive features from source's slots and writes them to
     `kid.genome["grafted"]` under `slime_*` prefixed keys.

4. **Each existing procedural body** adds a `"slime"` case in its
   `_apply_cross_species_graft` match statement and a `_graft_slime_features`
   helper that renders slime-derived parts on top of its body. (Or skip if
   you don't want slime-to-other-species visual influence yet — the universal
   breeder still transfers stats, palette, and mimic_blood lineage.)

5. **CreaturePreview** — add an `elif actor_data is SlimeData:` branch that
   spawns `ProceduralSlimeBody`.

6. **ArenaSpawner / cheat menu** — wire `slime_scene` + count export + spawn
   button (mirror the mushroom path).

No edits required to MimicData, MushroomData, GoblinData, GoatData,
ProceduralMimicChest, ProceduralMushroomBody, ActorCard, Ranch.tscn,
or the breeding flow.

---

## Invariants — things that MUST stay true

1. **Every species declares the FULL slot list in `default_genome()`** —
   forward compatibility.
2. **Field names with the same meaning across species use the same name**
   (`eye_count`, `eye_color`, `has_arms`, …) — universal blender depends
   on this.
3. **All procedural-body rendering randomness goes through `_rng`** — never
   global `randi()`/`randf()`. Stable identity depends on this.
4. **Procedural body clears scaffolding with immediate `free()`** — not
   `queue_free()`. Ghost meshes depend on this.
5. **The `grafted` slot's compound flags are independent rolls** — sibling
   variety depends on this.
6. **Universal breeder always rolls 50/50 species**, never bias toward
   `parent_a` or `parent_b`. Don't sneak conditional logic into the
   `kid_is_a` decision.
7. **`mimic_blood` propagates through `apply_mimic_lineage`** on every
   breed, including when the kid takes the partner's body via deferral.
   Don't skip this when adding new code paths.
