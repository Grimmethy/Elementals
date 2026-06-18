# Universal Procedural Creature Body

**Status:** v1 scaffolded (2026-05-25)
**Source:** `src/actors/body/ProceduralCreatureBody.gd` + `src/actors/body/PartBuilders.gd`
**Companion docs:** `GameLoopIdea.md §6`, `Markdowns/Systems/ModularCreatureGenome.md`

---

## Why This Exists

Hornbound has ~600 D&D Monster Manual entries to support. Hand-authoring 600 unique meshes is impossible. The Universal Procedural Body is the **content engine** — it produces a recognizable, varied creature mesh from a single dictionary input (`shared_body_plan`). Every monster in the manual becomes playable by populating that dictionary; no engine code changes per monster.

This system is the natural completion of Cody's `shared_body_plan` scaffold on `ActorData` — that dict was the universal schema; this is the universal renderer that consumes it.

---

## Architecture

```
ActorData
 ├── shared_body_plan: Dictionary       ← schema (existing, scaffolded by Cody)
 ├── render_seed: int                   ← determinism source
 └── genome.universal_mutations: Dict   ← mutation flags

         │
         ▼
ProceduralCreatureBody (extends Node3D)
 ├── actor_data: ActorData
 ├── rebuild_from_genome(plan)
 ├── _seed_rng() ← seeds _rng from render_seed
 └── dispatches to:
         │
         ▼
PartBuilders (static, in PartBuilders.gd)
 ├── build_body(root, type, base, palette, rng)        → MeshInstance3D
 ├── build_top(root, type, top, base, palette, rng)    → MeshInstance3D
 ├── build_face(root, face, base, palette, rng)        → MeshInstance3D[s]
 ├── build_limbs(root, limbs, base, palette, rng)      → MeshInstance3D[s]
 ├── build_ornament(root, tag, ornaments, ..., rng)    → MeshInstance3D[s]
 └── build_mutation(root, tag, base, palette, rng)     → MeshInstance3D[s]
```

The renderer never reads species-specific data directly. It only reads the universal `shared_body_plan` dict + the `universal_mutations` flags from genome. This is what makes the system extensible: a new species adds a body-plan generator, never touches the renderer.

---

## The shared_body_plan Schema (recap)

Defined in `ActorData.default_shared_body_plan()`. Six top-level slots:

| Slot | Purpose | Example |
|------|---------|---------|
| `base` | Body shape + dimensions | `{type: "quadruped_torso", width: 0.4, height: 0.5, depth: 1.2}` |
| `top` | Head / cap / lid | `{type: "head_beast", size_factor: 1.0, height: 0.3}` |
| `face` | Eyes, mouth, teeth | `{eye_count: 2, mouth_style: "teeth_ring", tooth_count: 12}` |
| `limbs` | Arms, legs, tail | `{has_arms: false, has_legs: true, leg_count: 4, leg_length: 0.25}` |
| `ornaments` | Decorative tags | `{tags: ["mane", "tail"], primary_color: <Color>}` |
| `palette` | Color slots | `{primary: <Color>, secondary: <Color>, eye: <Color>, accent: <Color>}` |

Body builders read `base.type` and dispatch. Top builders read `top.type`. Face builders read `face.*`. And so on. Each slot is independent — missing slots are silently skipped (forward-compatible).

---

## Supported `base.type` values (Phase 1)

| Key | Mesh | Used by |
|-----|------|---------|
| `sphere` | SphereMesh | generic blob, ooze base, simple monsters |
| `cube` | BoxMesh | constructs, scarecrows, golems |
| `biped_torso` | CapsuleMesh upright | humanoids, fiends, fey, giants, undead |
| `quadruped_torso` | CapsuleMesh on side | beasts, dragons, monstrosities |
| `blob` | flattened SphereMesh | oozes, slimes |
| `cylinder` | CylinderMesh | plants, stems, treants |
| _(fallback)_ | sphere | unknown types route to sphere |

Adding a new shape = add one branch to `PartBuilders.build_body` + one builder function. No other code touched.

---

## Supported `top.type` values

| Key | Use |
|-----|-----|
| `none` | no head/cap (oozes, blobs) |
| `dome` | rounded cap (mushrooms, mimics with rounded lid) |
| `flat_lid` | flat top (mimic chest lid) |
| `cap_dome` | mushroom cap (wider than body) |
| `head_humanoid` | sphere head for biped creatures |
| `head_beast` | elongated muzzle for quadrupeds |

---

## Ornament Tags (extensible)

Stored as an `Array[String]` in `ornaments.tags`. Each tag dispatches to a builder. Unknown tags are silently skipped (forward-compatible — new tags don't break old saves).

Current set:
- `mane` — torus around head
- `halo` — emissive torus above head
- `wings` — flat pair of side panels
- `horns` — two narrowing cones on top of head
- `tail` — capsule extending back
- `tentacles` — 4 small downward capsules around the base
- `bone_protrusion` — exposed bone shards
- `tattered_cloth` — transparent dark panel
- `metallic_plate` — front chest plate
- `flowering_accents` — small scattered spheres
- `crystal_growth` — sharp emissive cones

Cross-species breeding picks tags from each parent and ORs them — so a Fey × Fiend kid might end up with `flowering_accents` + `horns` + `wings`.

---

## Universal Mutations (extensible)

Stored on `genome.universal_mutations` as a Dict<tag, bool>. Defined on `ActorData.MUTATION_POOL`. Currently 15 entries. The renderer iterates the dict and calls `build_mutation(tag)` for each `true` flag.

This is the system's "weirdness compounder" — high `hybrid_generation` rolls more mutations from the pool, producing visibly weirder kids over multiple generations.

---

## Cross-Species Hybrids

The renderer doesn't know about cross-species mixing. It just renders whatever `shared_body_plan` it's given. Cross-species mixing happens in `ActorData.universal_crossover_breed` — which blends the parents' plans into the kid's plan (palette lerp, per-axis dimension mix, limb inheritance, ornament tag union, mutation OR-ing). The renderer then reads the blended result.

This separation means cross-species breeding works for any species pair as long as both have a populated `shared_body_plan`. Beast × Plant works. Dragon × Ooze works. Construct × Aberration works. None of them need special breeding code — the universal blender handles it.

---

## Specialist Renderers (Mimic, Mushroom)

The existing `ProceduralMimicChest` and `ProceduralMushroomBody` are NOT deprecated. They handle their own body archetypes with higher-fidelity meshes (specialist hinge for mimic lids, half-cylinder for mushroom caps, etc.).

The integration pattern:
- `ProceduralCreatureBody` is the **fallback / universal** renderer
- A future step (Phase 2.5) will let actor types declare which renderer to use via a property on their script
- Mimic/Mushroom retain their specialist renderer; everything else uses the universal one
- Cross-species hybrids can choose either parent's specialist renderer (their `body.type` decides)

---

## Determinism

All randomness inside builders MUST go through the `_rng` parameter, which is seeded from `actor_data.render_seed` at the start of each `rebuild_from_genome` call. This guarantees:

- Same `shared_body_plan` + same `render_seed` = identical visual every rebuild
- The kid's `render_seed` is rolled fresh at breeding, so each individual has a stable identity
- Engine restarts produce identical creatures from the saved data

---

## Performance

Each rebuild creates ~10-30 `MeshInstance3D` nodes. For a typical herd of 12 + a 4-monster pack in the arena, that's ~480 instances at max — within Godot's comfort zone. If performance becomes an issue:

1. Combine all parts into a single ArrayMesh per rebuild
2. Cache built meshes by `(render_seed, plan_hash)` and reuse
3. Use MultiMeshInstance3D for repeated ornaments (tentacles, crystals)

None of these are needed for the MVP scale.

---

## Adding a New Species — What it Takes

1. Add an entry to the appropriate `ActorTypes/XxxData.gd` (already done for 600+ creatures, just needs a few extra fields)
2. Add `category`, `body_plan_modifiers`, and `capture_archetype` to the entry
3. The category template (in `ActorBodyPlanGenerator.gd`) produces the base plan
4. The modifiers tweak species-level details (colors, dimensions, specific ornaments)

**Total work to add a new monster: ~10-15 lines of data, zero code.**

---

## File Map

| File | Role |
|------|------|
| `src/actors/body/ProceduralCreatureBody.gd` | The universal renderer Node3D |
| `src/actors/body/PartBuilders.gd` | Static dispatch + builder functions |
| `Components/ActorComponents/ActorData.gd` | Holds the schema (`shared_body_plan`, `MUTATION_POOL`, breeding logic) |
| `Components/ActorComponents/ActorBodyPlanGenerator.gd` | Per-category template functions (Phase 2) |
| `src/actors/types/ProceduralMimicChest.gd` | Specialist Mimic renderer (coexists) |
| `src/actors/types/ProceduralMushroomBody.gd` | Specialist Mushroom renderer (coexists) |

---

## Open Architecture Questions

- **LOD?** For 100+ creatures on screen we'd want LOD. Out of MVP scope.
- **Animation?** Currently each mesh is static. Bob/idle animations would be handled by a separate component reading the body root.
- **Material variants per species?** Currently materials are simple StandardMaterial3D. Some species (oozes, fire elementals) want shader-driven materials. The `mutation.glowing_veins` already pushes this direction. Future work.

---

*Last updated: 2026-05-25 (Phase 1 scaffolding complete)*
