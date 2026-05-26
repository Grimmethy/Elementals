# Per-Creature Body Math — Real Variation

**Status:** Plan + Phase 1 implementation (2026-05-25)
**Source:** `Components/ActorComponents/ActorBodyPlanGenerator.gd` + `Components/ActorComponents/CreatureSignatures.gd`
**Related:** `Markdowns/Systems/UniversalProceduralBody.md`, `Markdowns/Plans/GameLoopIdea.md` §6

---

## Problem

The 14 category templates produce results that look **too similar within a category**. A Wolf, a Lion, a Bear, and a Tyrannosaurus all spawn as "generic quadruped" because they share the same template with only minor random jitter. Players can't tell breeding outcomes apart, and the menagerie feels samey.

## Goal

Every creature in `ActorTypeData` (~600 entries) produces a **visually distinct** procedural body. Wolves are lean and long-snouted; bears are bulky; tyrannosaurs are bipedal with massive heads; pixies are tiny with wings. **AND** the universal cross-species breeding system (`ActorData.universal_crossover_breed`) still works — kids inherit plans from BOTH parents and blend them into recognizable chimeras.

## Non-Goals

- Hand-authoring 600 unique entries. That's not viable for one developer.
- Pixel-perfect D&D Monster Manual matches. Procedural primitives can't compete with hand-art; we aim for *recognizable silhouettes*.
- Per-creature animation. Just static body geometry + materials.

---

## Architecture: 3-Layer Variation

Each creature's body plan is the composition of three layers:

```
Category Template          (e.g. Beast)
    +
Sub-Template Variant       (e.g. "wolf_like" within Beast)
    +
Species Signature          (per-species deterministic jitter)
    +
Explicit Modifiers         (optional hand-authored overrides on ActorTypeData)
    =
Final shared_body_plan
```

### Layer 1: Category Template

What I already have — 14 functions in `ActorBodyPlanGenerator` that produce a baseline plan for the D&D type. Establishes:
- Body shape (quadruped vs biped vs blob)
- Palette family (browns for Beast, ethereal whites for Celestial, etc.)
- Default ornament tags (tail for Beast, wings+halo for Celestial)

### Layer 2: Sub-Template

A creature within a category can be one of several **anatomical archetypes**. For Beasts:

| Sub-Template | Body Shape | Examples |
|--------------|-----------|----------|
| `wolf_like` | Lean quadruped, long muzzle, alert | Wolf, Tiger, Panther, Fox, Coyote |
| `bear_like` | Bulky quadruped, short legs, rounded | Bear, Boar, Ox, Bulette |
| `small_animal` | Tiny quadruped, low body, short snout | Rat, Cat, Weasel, Badger |
| `dinosaur_like` | Bipedal beast, long tail, big head | T-Rex, Allosaurus, Velociraptor |
| `lizard_like` | Low-slung quadruped, long tail | Crocodile, Giant Lizard |
| `bird_like` | Biped with wings, small head | Hawk, Eagle, Vulture |
| `serpent_like` | Long body, no legs (or vestigial) | Constrictor Snake, Giant Snake |
| `insect_like` | Many legs, segmented body | Centipede, Giant Spider, Beetle |

Sub-template is selected by:
1. **Explicit hint** in `CreatureSignatures.SUB_TEMPLATE_HINTS` — fastest, most accurate
2. **Stat profile heuristic** — high dex + low con → wolf_like; high con + low dex → bear_like; etc.
3. **Default for category** — fallback

### Layer 3: Species Signature

Two creatures with the same name should produce identical body plans for the same render_seed. A Wolf and a Lion (both Beast / wolf_like) should still look different because **their species names hash to different signatures**.

```gdscript
static func _species_signature(species_name: String) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = _fnv1a_32(species_name)
    return rng
```

The signature RNG is used for **species-stable** rolls — dimensions, palette hue, ornament selection. The `render_seed` RNG is used for **instance-stable** rolls — this individual Wolf's exact spot pattern, eye size jitter, etc.

### Layer 4: Explicit Modifiers (optional)

`body_plan_modifiers` on the ActorTypeData entry. Already implemented. Used for showcase creatures (Wolf, Iron Golem, Skeleton, etc.) where we hand-tune specific colors or scales.

---

## How Each Layer Combines

1. Generator picks the **category template** based on `ActorTypeData.get_category(species)`.
2. Generator queries `CreatureSignatures.sub_template_for(species, category, stats)` — gets a sub-template key like `"wolf_like"`.
3. Generator constructs a **species RNG** from the species name hash.
4. The category template is parameterized by sub-template variant AND species RNG. Result: a Wolf produces a "wolf_like" Beast plan; a Bear produces a "bear_like" Beast plan; they share Beast palette family but have very different dimensions and ornaments.
5. Generator overlays explicit `body_plan_modifiers` from ActorTypeData entry, if any.

```
Wolf:
  category=Beast → wolf_like sub-template → species_rng seed=hash("Wolf")
    → base.width=0.55, depth=1.35, leg_length=0.4 (lean, long)
    → palette.primary = Color(0.42, 0.40, 0.38) (grey, hash-derived hue)
    → ornaments=["tail", "alert_ears"]

Lion:
  category=Beast → wolf_like sub-template → species_rng seed=hash("Lion")
    → base.width=0.65, depth=1.25, leg_length=0.38 (still lean but slightly stockier)
    → palette.primary = Color(0.78, 0.55, 0.20) (tan/gold)
    → ornaments=["tail", "mane"]   ← Lion's hand-authored modifier adds "mane"

Bear:
  category=Beast → bear_like sub-template → species_rng seed=hash("Bear")
    → base.width=0.85, height=0.70, depth=1.20, leg_length=0.30 (bulky, short legs)
    → palette.primary = Color(0.50, 0.30, 0.18) (brown)
    → ornaments=["tail"]
```

All three are quadrupeds, all three are Beasts, all three look distinctly themselves.

---

## Breeding Math — Why This Keeps It Universal

`ActorData.universal_crossover_breed(a, b)` already works on the **fully-rolled shared_body_plan dicts**. It doesn't care whether the plan came from category template, sub-template, or modifier overlay — it just blends two complete plans into a kid plan.

When Wolf × Bear breeds:
1. Both parents have their own `shared_body_plan` (rolled at construction time using their species signatures).
2. `universal_crossover_breed` runs:
   - Picks one parent's `base.type` (50/50 — both are `quadruped_torso` here, so no conflict).
   - Mixes dimensions per-axis: Wolf's leg_length=0.4 × Bear's leg_length=0.3 → kid's leg_length ≈ 0.35.
   - Blends palettes via HSV interpolation: grey + brown → muddy grey-brown.
   - Unions ornament tags: ["tail"] ∪ ["tail"] = ["tail"]. (If Bear had ["tail", "fur_collar"] then kid gets both.)
3. Kid's `body_plan_modifiers` are NOT inherited — the kid's modifiers are empty (it's a procedural hybrid, not a stat-block species).
4. Apply universal mutations to the kid (existing system).

**Result:** Wolf × Bear → "Bramblefang" — quadruped, leg_length 0.35, muddy grey-brown, tail, possibly a mutation graft.

The 3-layer system **doesn't break breeding** because each parent contributes a fully-rolled plan, and the blend produces a coherent kid plan that the renderer treats identically to any natural-species plan.

---

## Implementation Plan

### Phase 1 — Foundation (this commit)

- [x] Write this design doc
- [x] Create `Components/ActorComponents/CreatureSignatures.gd` with:
  - `_fnv1a_32(text)` hash function
  - `species_rng(species_name)` returns a seeded RandomNumberGenerator
  - `SUB_TEMPLATE_HINTS` dict — explicit overrides for ~40 showcase species across categories
  - `sub_template_for(species, category, stats)` — resolution with hint → heuristic → default fallback
  - `size_class_for(stats)` — derive Tiny/Small/Medium/Large/Huge/Gargantuan from HP
  - `size_scale(size_class)` — multiplier (Tiny=0.4, Small=0.7, Medium=1.0, Large=1.6, Huge=2.4, Gargantuan=3.5)
- [x] Update `ActorBodyPlanGenerator.generate` to use signatures + apply size scale
- [x] Add **Beast sub-templates**: wolf_like, bear_like, small_animal, dinosaur_like, lizard_like, bird_like, serpent_like, insect_like
- [x] Add Beast sub-template hints for ~20 common Beasts (Wolf, Bear, Tiger, Cat, Rat, T-Rex, Velociraptor, Crocodile, Hawk, Snake, Spider, etc.)

### Phase 2 — Other Categories (follow-up)

- [ ] **Humanoid sub-templates**: warrior (Knight, Veteran), caster (Mage, Archmage), small_humanoid (Goblin, Kobold), brute (Orc, Bugbear), elf_like (Drow, Pixie cross), lizardfolk_like
- [ ] **Dragon sub-templates**: wyrmling (small dragon variants), young (medium with starter wings), adult (large with full wings), ancient (huge with multiple horns), wyvern (no front legs)
- [ ] **Undead sub-templates**: skeleton (bone variant of humanoid), zombie (bloated humanoid), ghoul (low-crouch), wraith (no legs, floating)
- [ ] **Fiend sub-templates**: imp (small flying), devil_humanoid, demon_bestial, pit_fiend (huge winged)
- [ ] **Plant sub-templates**: mushroom (cap-stem), treant (large tree-form), vine_blight (limbed)
- [ ] **Construct sub-templates**: golem (cube body), animated_armor (humanoid shell, hollow), automaton (slim humanoid)
- [ ] **Aberration sub-templates**: tentacled (many tentacles, no legs), floating_eye (Beholder shape), brain_creature (tall humanoid with exposed brain)
- [ ] **Ooze sub-templates**: cube (Gelatinous Cube — actual cube), blob (Black Pudding shape), tracker (low-slither)
- [ ] **Elemental sub-templates**: fire (humanoid with particles), earth (rock-cube), air (whispy), water (translucent blob), genie (large humanoid with tail)
- [ ] **Fey sub-templates**: pixie (tiny with wings), satyr (goat-leg humanoid), dryad (plant-humanoid), eladrin
- [ ] **Celestial sub-templates**: small_celestial (Lantern Archon), winged_humanoid (Deva), majestic (Solar)
- [ ] **Giant sub-templates**: hill_giant (bulky), stone_giant (lean), storm_giant (tall + ethereal)
- [ ] **Monstrosity sub-templates**: chimera (multi-headed), serpentine (Hydra), insectoid (Carrion Crawler)

### Phase 3 — Showcase Signatures (follow-up)

- [ ] Add explicit `body_plan_modifiers` for ~80 high-visibility creatures (one of each iconic monster in each category)
- [ ] Add per-creature `combo_pool` for popular pairings
- [ ] Add per-species `capture_archetype` for at least every category's "iconic boss"

### Phase 4 — Stat-Driven Refinement

- [ ] Use stat profile (HP, AC, str, dex, con) to derive sub-template hints when explicit hint is missing — e.g. high str + low dex → bulky variant
- [ ] Use `gold_value` as a "rarity / size" multiplier (rare = bigger / more ornate)

---

## File Map (Phase 1)

| File | Purpose | Status |
|------|---------|--------|
| `Components/ActorComponents/CreatureSignatures.gd` | Hash + sub-template registry + size class derivation | ✅ Created |
| `Components/ActorComponents/ActorBodyPlanGenerator.gd` | Updated to consume signatures + sub-templates | ✅ Updated |
| `Markdowns/Plans/PerCreatureBodyMath.md` | This doc | ✅ Created |

---

## Open Questions

- **Should size class also affect HP / damage scaling at spawn?** Currently HP comes from ActorTypeData directly; size class is purely visual. If a Gargantuan render-scale creature has only 50 HP it'll feel weird. Lean toward: size_class also scales HP / armor_class proportionally during build.
- **Cross-category breeding** — Beast × Plant. Whose sub-template wins? Currently the kid gets the primary parent's body type (already in universal_crossover_breed). So a Beast × Plant kid is a Beast with grafts from Plant (vines, foliage tag).
- **Recursive sub-templates** — a Beast/wolf_like × Beast/bear_like kid: which sub-template? Currently picks one parent's full plan and overlays the other's grafts. Sufficient for MVP; could blend dimensions per-axis later.

---

*Last updated: 2026-05-25 — Phase 1 complete, Phases 2-4 deferred.*
