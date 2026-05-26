# Creature Builder Guide

Read this BEFORE touching `src/actors/body/LowPolyMeshes.gd` or adding a new
sub-template. Captures lessons paid for in dozens of "still wrong" screenshot
iterations — most of which trace back to a small set of recurring bugs.

> Companion to `PerCreatureBodyMath.md`. That doc covers WHAT to build (the
> sub-template registry, body math, breeding chimera math). This doc covers
> HOW to build it well, and which bugs to avoid.

## 1. Anatomy reads at a glance, or it doesn't read at all

The user can tell a Pig from a Wolf in one frame. If your mesh fails that test
("looks like a cat in sunglasses", "looks like a fox", "terrifying in 3D"),
the species silhouette is wrong — palette and detail can't save it.

The rules that drive species reading, in priority order:

1. **Body proportions** — width × height × depth ratios are the single
   strongest signal.
   - Pig: barrel (width ≈ depth, low height), short legs
   - Wolf: lean (depth ≈ 2× width), long legs, raised back
   - Bear: stout (width ≈ depth ≈ height), shoulder hump
   - Dragon: long horizontal spine, lifted off ground by legs
2. **Head shape + position** — a wolf head is pointed, a pig head is short
   wedge with flat snout, a bear head is round. The head MUST sit clearly
   forward of the body (head_back overlaps body's last section by a small
   negative gap — do not leave a positive gap, see Rule 3).
3. **Iconic species marker** — every species has ONE feature the player will
   look for. Wolves: visible lower jaw + teeth. Pigs: round flat nostrils
   on a flat-disk pink snout + curly tail. Boars: visible tusks. Beholder:
   one big central eye. Skip the marker and the creature reads as "generic
   shape with palette".
4. **Limbs** — leg count, length, knee bend direction (forward vs
   reverse-digitigrade). Wolf legs hinge forward at the knee on the front
   pair, backward at the hock on the back pair.

## 2. Everything must touch

Every time something rendered with a visible gap between parts — tail and
butt, head and neck, snout and head, ear and head — the user spotted it
immediately. The fix is always the same:

- Anchor a new part INSIDE the parent silhouette by a small negative gap,
  never with a positive gap. If the body's rear ring is at `z = -d*0.35`,
  the tail base goes at `z = -d*0.32` (inside), not `z = -d*0.50` (behind).
- When connecting two swept_body meshes (head + body), set the seam ring's
  cross-section to MATCH the body's last ring exactly (same w, same h).
  Different cross-sections at the seam = visible ring step.
- Never rely on `cap_ends = true` to "close the gap" — the cap is a
  triangle fan to a centroid, not a magic merge.

## 3. Surfaces must be 3D, not paper

The user immediately notices flat surfaces:
- Eyes layered as sclera/iris/pupil at increasing Z look like an ice-cream
  cone stack from any side angle. Use a single bead INSET into the head.
- Wings as a single triangle pair look like paper. Build a slim wedge:
  front face + back face offset along the wing-perpendicular, with edge
  quads wrapping the perimeter.
- Bodies built as one continuous swept ring extrusion read 3D from any
  angle. Body-as-stacked-boxes (early bear/spider/etc) doesn't.

## 4. No two of the same species should look identical

A herd of pigs should read as a real herd. Color isn't enough — silhouette
has to vary too.

Per-individual jitter (driven by `plan.meta.render_seed`, deterministic):
- Body fat/skinny: `body_fat *= rng.randf_range(0.85, 1.30)`
- Ear scale, PER EAR independently: `this_ear_scale = species_ear_scale * rng.randf_range(0.65, 1.40)`. Also jitter droop, lean_x, lean_z so one ear can be crooked.
- Leg length: `leg_length_jitter = rng.randf_range(0.65, 1.50)` — applied before clearance is derived.
- Tail length / curl turns / segment count.
- Tooth count, jaw drop, jaw width (wolves).
- Spot count + positions (pigs).
- Palette: do NOT just read `palette.primary` — `body_plan_modifiers` in
  the data files hardcode it, so every individual comes out the same color.
  Instead pick from a curated species palette using the render_seed RNG,
  with optional species-name biases (Arctic Wolf → white, Dire Boar → dark).

## 5. Recurring bug families to watch for

### 5a. Procedural ornament/face pollution

`ProceduralCreatureBody._build_face` and `_build_ornaments` will lay duplicate
eyes, tails, wings, flowers, etc. on top of any hand-built mesh.

- Set `LowPolyMeshes.draws_own_face(sub) -> true` and draw your own eyes.
- Set `LowPolyMeshes.draws_own_ornaments(sub) -> true` if your builder
  handles tail/wings/horns. Otherwise PartBuilders will add a `CapsuleMesh`
  tail next to your hand-built tail (the wolf "extra cylinder" bug) or
  3-5 huge pink "flower" spheres at fixed `0.05` radius next to a tiny
  pixie (`flowering_accents`).

### 5b. Absolute constants in shared helpers

`_swept_body` originally pushed cap centroids by `0.05` absolute world
units. Invisible on a wolf (w ≈ 0.55). On a pixie (effective scale ≈
0.16× from Tiny size class × Pixie's `base.scale = 0.35`) that 0.05 became
a 25×-the-eye-radius spike protruding out of every capped feature.

Rule: any "push" / "offset" / "extend" distance in a shared helper must be
PROPORTIONAL to a section radius or feature size, never a fixed world-unit
constant. Use `radius * 0.30`, not `0.05`.

### 5c. Ring orientation

`_swept_body` builds rings perpendicular to the axis the sections are
stacked along — auto-detected from the first/last section spacing:
- dz > dy → horizontal body (wolf, pig, dragon) — rings in X-Y plane
- dy > dz → vertical body (pixie, wraith, fire elemental) — rings in X-Z plane

If you write sections that vary along BOTH axes (e.g. a creature that
curves through 3D), the detection picks the dominant axis. For genuinely
diagonal/curved spines (snake), write the ring construction manually with
a proper per-segment local frame.

### 5d. Eyes anchored inside the head

If `eye_x = ±w * 0.32` but `head_mid_w = ±w * 0.42`, the eye is INSIDE the
head silhouette and gets occluded. Always position eyes ON the actual outer
surface, with a small forward bias to make them visible from the front too.

Pattern that works:
```gdscript
var head_surface_x: float = w * <head_section_outer_w>
var ex: float = side * (head_surface_x + small_outward_offset)
# Eye box wider in face-plane (Y/Z) than in X-depth.
```

### 5e. Procedural face's head_anchor doesn't track hand-built heads

PartBuilders computes `head_anchor` from base dimensions + top type. It
doesn't know where the hand-built mesh's head actually IS, especially
after per-individual `body_size_jitter`. Symptom: "eyes don't line up on
most wolves." Fix: draw your own eyes (see 5a).

## 6. Test loop

1. Render the creature. If it doesn't read as the species in one frame,
   re-check Rule 1 (proportions + iconic marker).
2. Roll the seed 5+ times. If they all look identical except palette,
   you haven't added enough per-individual jitter (Rule 4).
3. Roll multiple species in the same sub-template (Boar, Cow, Hippo,
   Mammoth all → swine_like). They should look visibly different from
   each other, not just from the default Pig.
4. Orbit the creature. Anything flat at one angle (paper wings, slab eyes,
   z=0 body) means a Rule 3 violation.
5. Look for gaps between parts. Rule 2.
6. Cross-check that no procedural feature is doubled up (two tails, two
   eye sets, etc). Rule 5a.

## 7. Where the data lives

- Mesh code: `src/actors/body/LowPolyMeshes.gd` (this is the only file you
  edit when adding a new sub-template mesh).
- Dispatcher: `src/actors/body/ProceduralCreatureBody.gd` — routes to
  `LowPolyMeshes.build_for(sub_template, plan, root)`, then calls
  `_build_face` / `_build_ornaments` / `_build_mutations` UNLESS the
  hand-built mesh opts out via `draws_own_face` / `draws_own_ornaments`.
- Sub-template registry: `Components/ActorComponents/CreatureSignatures.gd`
  (`SUB_TEMPLATE_HINTS` dict — maps species name → sub_template).
- Body math + per-species jitter: `ActorBodyPlanGenerator.gd`. Stamps
  `plan.meta.sub_template`, `species`, `category`, `element_type`,
  `render_seed`.
- Per-species overrides: `body_plan_modifiers` field on each species in
  `Components/ActorComponents/ActorTypes/*Data.gd`. Note that anything set
  here OVERRIDES procedural defaults — including `palette.primary`, which
  is why hardcoding it in data is what made every pixie pink. Prefer
  picking the palette via seed RNG inside the builder instead.

## 8. Common builder skeleton

```gdscript
static func _build_<creature>(plan: Dictionary, root: Node3D) -> void:
    var base: Dictionary = plan.get("base", {})
    var palette: Dictionary = plan.get("palette", {})
    var limbs: Dictionary = plan.get("limbs", {})
    var meta: Dictionary = plan.get("meta", {})
    var species: String = String(meta.get("species", ""))

    # Base dimensions — already scaled by size_class + base.scale upstream.
    var w: float = _axis(base, "width", <default>)
    var h: float = _axis(base, "height", <default>)
    var d: float = _axis(base, "depth", <default>)
    var leg_length: float = float(limbs.get("leg_length", <default>))
    var clearance: float = leg_length

    # Per-species variation (within the same sub_template).
    var species_lower: String = species.to_lower()
    var <traits> = <species-specific values>
    if "<species_keyword>" in species_lower:
        <override traits>

    # Per-individual jitter (deterministic via render_seed).
    var render_seed: int = int(meta.get("render_seed", 0))
    var rng := RandomNumberGenerator.new()
    rng.seed = render_seed if render_seed != 0 else hash(species)
    body_fat *= rng.randf_range(0.85, 1.30)
    leg_length *= rng.randf_range(0.65, 1.50)
    clearance = leg_length
    # ... etc

    # Palette (avoid reading palette.primary directly — pick from a curated
    # species palette using the rng so individuals vary).
    var color_options := [<list of species-appropriate colors>]
    var primary: Color = color_options[rng.randi() % color_options.size()]

    # BODY — _swept_body for the trunk
    var sections: Array = [...]
    _swept_body(root, sections, 8, primary, belly, 0.85, true)

    # HEAD — own sections, overlapping the body's last section
    # FACE features — eyes ON the outer surface, properly anchored
    # ORNAMENTS — your own tail, wings, horns (because draws_own_ornaments)

# In SUPPORTED list:
"<sub_template_name>",
# In build_for match:
"<sub_template_name>": _build_<creature>(plan, root)
# In draws_own_face / draws_own_ornaments — both return true via the
# default `sub_template in SUPPORTED` branch.
```
