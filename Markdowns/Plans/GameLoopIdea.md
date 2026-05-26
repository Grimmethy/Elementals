# Hornbound: Monster Herd — Game Loop Design

**Status:** Design Locked (2026-05-25)
**Author:** Design conversation summarized by Claude
**Audience:** Solo dev (Cody) + collaborators

---

## TL;DR

> **You ARE the alpha. The pack is your collection. The arena is the proving ground. The ranch is the lab.**

A **roguelike monster-rancher**. Short (15–25 min) permadeath runs where you play AS one of your bred monsters leading a pack of 3 AI companions. Capture wild monsters to learn their traits. Cross-breed *anything with anything* into chimeric abominations. Use the right squad for the right dungeon. Compete on leaderboards instead of a hand-authored ending.

The game generates its ~600-creature roster **procedurally** from the existing D&D Monster Manual taxonomy + the universal procedural body system — so content variety scales without manual asset authoring.

---

## Document Structure

This doc is **modular** — each system is its own section with its own boundaries. You can implement them in any order; each one improves the game state without requiring the others. Cross-references are tagged `[§N]`.

| § | System | Independent of |
|---|--------|----------------|
| 1 | The Run | All others |
| 2 | The Squad | All others |
| 3 | Combat & Pack Commands | §2 |
| 4 | Capture | §3 |
| 5 | Breeding | §4 (traits) |
| 6 | **Universal Procedural Creature** | All others — content engine |
| 7 | Bonds & Loyalty | §2, §5 |
| 8 | The Hub | §1, §5 |
| 9 | Trait Library | §4 |
| 10 | Leaderboards | §1 |
| 11 | Progression Arc | §8, §9 |

---

## §1 — The Run

A **dungeon run** is a contiguous 15–25 minute session. The structure is fixed (so players learn the rhythm); the rooms within it are procedural.

### Run Skeleton (4 rooms)

| # | Room | Purpose | Length |
|---|------|---------|--------|
| 1 | **Warm-up Fight** | Confirms the squad works. Easy. | ~3 min |
| 2 | **Branch** — Loot room OR Alpha room | Choice point. Loot = parts/gold/charms. Alpha = capturable rare. | ~4 min |
| 3 | **Mid-Boss** | The test. Designed to punish bad squad comp. ~40% of deaths happen here. | ~6 min |
| 4 | **Extract Point** | Three buttons: **Leave** (bank loot), **Push** (one more room, bigger reward, real risk), **Abandon** (run ends, keep monsters, lose loot). | ~30s + ~6 min if push |

Greed is the most engaging form of decision-making — make the player choose between "good run, locked in" and "great run, possible disaster" at every extract point.

### Room Generation

Each room type pulls from a **pool of ~10 layouts** per biome. So 3 biomes × 4 room types × 10 layouts = **120 distinct room arrangements** at MVP, before any procedural creature variation.

### Mid-Run State

- **No save/load mid-run.** Death = death. Extract = clean break.
- **No fast travel** within a run. The 4-room sequence is linear (Branch room is the only choice point).
- **Time pressure** is *not* a mechanic — the game waits for the player. The 15–25 min figure is an expected pace, not a clock.

### Day Tick

Accepting a contract **advances the day** by one. Pregnancies progress, eggs hatch, wild populations shift slightly, mission board refreshes, hub buildings produce. The day is *the* heartbeat — no real-time clocks anywhere else.

---

## §2 — The Squad

### Sizes

- **Squad in-run:** 1 lead (controlled by player via possession `[§3]`) + 3 AI companions = **4 total**.
- **Active herd at hub:** **12** slots. These are the monsters available to put on a squad.
- **Pension:** **Unlimited**. Pension members can't be deployed, but they can breed and be rotated back into the active herd at any time, freely.

### Rotation Rules

- Active ↔ Pension swap is **free and instant** at the hub. No timer, no cost.
- The 12-slot cap exists to force "who's in the lineup right now?" decisions, not to limit collection.
- Active monsters can be in a saved squad loadout (see Loadouts below).
- Pension monsters retain bonds, traits, age, and pregnancy state. They are *out of rotation*, not deprecated.

### Loadouts

Up to **3 named squads** stored. Examples:
- "Volcano Crew" (fire-resist + ranged)
- "Spider Hunters" (poison-immune + AoE)
- "Boss Killer" (tank + healer + 2 burst-DPS)

One-click swap. Loadouts reference monsters by ID; if a monster dies, the loadout shows a red slot until the player fills it.

---

## §3 — Combat & Pack Commands

### Your Controlled Monster

You play AS one of the four. Each species has **exactly 3 combat actions** (kept tight to prevent finger-overload while also commanding the pack):

- **Basic** — light, fast, no cost
- **Special** — heavy / status / unique to species
- **Dodge** — i-frames, short cooldown

Different species feel different because their basic and special are *different verbs*:

| Species | Basic | Special |
|---------|-------|---------|
| Goat | Headbutt (knockback) | Charge (long-range gap close) |
| Mimic | Bite (grapple chance) | Pseudopod Lash (AoE arc) |
| Mushroom | Slap (low dmg) | Spore Cloud (poison AoE) |
| Goblin | Stab (fast) | Ankle-slash (slow target) |
| Hybrid X×Y | One from each parent | — (3rd move slot from breeding `[§5]`) |

### Possession (death handling)

When your controlled monster's HP hits 0:
1. The body remains on the field (interactable; if you survive the run you can carry it back for parts).
2. Your "consciousness" possesses the **nearest alive packmate**.
3. You take control of them. Their moveset replaces yours.
4. The previous monster is permadead.
5. If all 4 fall, the run ends — bodies and loot are lost.

**Voluntary possession** (bind to a key): mid-fight, hop to another packmate. Useful for "Goat charges in, swap to ranged Mushroom mid-fight." Comes with a tiny cooldown (~3s) to prevent spam.

### Pack Commands (the 3 AI companions)

Four commands. Lift the design from Pikmin, not RTS micromanagement.

| Command | Effect |
|---------|--------|
| **Attack** | All allies focus your current target |
| **Defend Me** | All allies prioritize threats targeting you |
| **Spread** | Allies spread out (anti-AoE positioning) |
| **Capture** | Allies switch to non-lethal mode and try to weaken target without killing |

Combo unlocks (`[§7]`): at bond level 2 between two specific monsters, a 5th command appears — `Combo` — which triggers their unique team-up move.

---

## §4 — Capture

Capture is the *only* way to learn new traits for breeding. Killing gives parts, gold, XP — all useful. But you can never feed a new trait into the breeding pool without bringing a monster home alive.

This is the rule that makes capture economically necessary, not optional.

### Capture Archetypes (4 patterns, reusable)

Most monsters fall into one of these. The species-specific flavor is the wrapper.

| Archetype | Example monsters | Mechanic |
|-----------|------------------|----------|
| **Weaken + Bind** | Most beasts, goblins, generic humanoids | HP < 30%, throw net. Standard. |
| **Break Armor / Plates** | Constructs, Dragons, Tortoises | Armor must be destroyed first (3+ break points). Net only sticks after. |
| **Kill the Lessers** | Pack leaders (Alphas), Goblin Bosses | All minor minions must die first. Net only works on the alpha. |
| **Counter-Charge** | Aggressive types (Ragehorn, Bulette, Charging beasts) | Must Parry/Dodge a charge attack, exposing the target for 2s. Net during window. |

A monster's capture archetype is a **field on its ActorTypeData entry** (e.g. `"capture_archetype": "break_armor"`). Generic enough to scale to all 600 manual entries.

### Capturable per Run

Most rooms have 1 capturable alpha (the Branch room's Alpha option, or sometimes the mid-boss). Players average 1 successful capture per run — enough to slowly grow the library without overwhelming the breeding pen.

### Restraint Tier (existing in HerdManager — preserves design)

The existing `HerdManager.attempt_capture_with_net` mechanism stays. Restraint Rating accumulates via net + ropes + chains + manacles + traps. Different archetypes have different escape DCs based on the formulas already designed in `Markdowns/Systems/Capture.md`.

---

## §5 — Breeding

### Pre-Run Timing

Breeding happens at the **hub between runs**. No mid-run breeding. No real-time pregnancy clocks. Pregnancies tick on the day-advance counter (each accepted contract = +1 day) `[§1]`.

### Inheritance Rules

**Same-species kid** — gets 2 moves. One from each parent's move pool. Reliable.

**Hybrid (cross-species) kid** — gets 3 moves. Slots 1 & 2 inherited from parents A & B. Slot 3 rolls on this table:

| Roll | Outcome |
|------|---------|
| 60% | Bonus move from either parent's pool |
| 25% | **Graft move** keyed to the kid's grafted body parts (e.g. has-mushroom-cap → Spore Cloud) |
| 12% | A library move — any species the player has captured `[§9]` |
| 3% | **MUTATION** — a brand-new move from a universal pool |

This subtly pushes the player toward hybrids (which are the strongest visual content). Pure-breeds are reliable; hybrids are weirder and have more buttons.

### Universal Mutation Move Pool (~12 entries)

Authored content, not procedural — these are the "remember that goat?" moments.

Pulse Burst · Shadow Step · Earthquake Stomp · Soul Drain · Mirror Self · Time Slip · Berserker Rage · Crystallize · Static Field · Phase Shift · Voidlash · Echo Strike

Each appears on roughly 1 in 33 hybrid kids. After 100 hybrid kids you'll have seen 3 mutations. That's the cadence.

### Stat & Visual Inheritance

Uses the **existing universal_crossover_breed system** in `ActorData.gd`:
- Per-axis dimension mixing (one parent's height + other's width)
- HSV hue rotation on palette
- Eye count / radius / spread blend
- Limb inheritance (force-inherit if either parent has them)
- Grafted slot — body parts visibly carried over (mushroom cap on mimic chest, etc.)
- 1–5 mutations rolled from the existing `MUTATION_POOL` (scales with `hybrid_generation`)

### Generational Naming

Hybrid generation ≥ 2 → "Chimeric Xxx" prefix. ≥ 4 → "Voidwarped / Eldritch / Primordial" prefix. Names are seeded by `render_seed` so they're stable across reloads. (Already implemented in `ActorData.apply_generated_name`.)

---

## §6 — The Universal Procedural Creature (THE CONTENT ENGINE)

This is the single most important system in the game. Without it, every monster has to be hand-authored, and the game is content-starved forever. With it, every D&D Monster Manual entry becomes a playable, breedable, distinguishable creature *automatically*.

### The Insight

Cody already shipped the foundation: `ActorData.shared_body_plan` is a universal genome dictionary scaffolded into the base class. It just isn't *consumed* by any renderer yet — Mimic and Mushroom each have their own specialized procedural body.

**The Plan:** Build one universal `ProceduralCreatureBody` that reads `shared_body_plan` and composes the body from a registry of part-builders. Migrate existing Mimic/Mushroom renderers to slot into the registry as "specialist" plug-ins for their body archetype. Add per-category body-plan **generators** that fill `shared_body_plan` from any `ActorTypeData` entry.

### Architecture

```
ActorTypeData entry ("Wolf", "Dragon", "Mushroom", ...)
        │
        ▼
ActorBodyPlanGenerator.generate(actor_type) → shared_body_plan dict
        │
        ▼
ProceduralCreatureBody.rebuild_from_genome(shared_body_plan)
        │
        ├── PartBuilders.body[base.type](dimensions, palette) → mesh
        ├── PartBuilders.top[top.type](size_factor, palette) → mesh
        ├── PartBuilders.face[mouth_style + eye_count + ...] → meshes
        ├── PartBuilders.limbs[arm/leg counts + sizes + colors] → meshes
        ├── PartBuilders.ornaments[for tag in ornaments.tags: ...] → meshes
        └── PartBuilders.mutations[for flag in universal_mutations: ...] → meshes
```

### Per-Category Body-Plan Templates

Each of the 14 D&D categories gets a generator template. Variety within a category comes from random rolls on dimensions, colors, sub-shape, and grafts.

| Category | Body Plan Skeleton |
|----------|-------------------|
| **Beast** | Quadruped: body + 4 legs + tail + head with maw |
| **Humanoid** | Biped: torso + 2 legs + 2 arms + head |
| **Dragon** | Quadruped + wings (cap as `top`) + long tail + horned head |
| **Undead** | Variant of Humanoid/Beast with bone tint, tattered cloth, hollow eye glow |
| **Ooze** | Amorphous blob: body only (no limbs), eye spots float on surface |
| **Plant** | Sessile: anchored base + tendrils for limbs, foliage for top |
| **Construct** | Angular geometric body + metallic plating, mechanical limbs |
| **Elemental** | Body matches element (Fire = particle-emitting humanoid, Earth = rock biped, Water = liquid blob) |
| **Aberration** | Chaotic: extra eyes (3-8), tentacles for limbs, asymmetric body |
| **Fey** | Humanoid + flowery accents + small wings + glow |
| **Fiend** | Humanoid + horns + clawed limbs + tail + dark color palette |
| **Giant** | Humanoid scaled large (1.5–3x) + crude armor ornaments |
| **Monstrosity** | Varies: pulls from beast or humanoid base + extra heads/eyes/limbs |
| **Celestial** | Humanoid + halo + ethereal palette + small wings |

Each template is a **function** (`make_beast_body_plan(actor_type_data, rng)`) that returns a fully-populated `shared_body_plan` dict using the existing schema. RNG is seeded by `render_seed` so a "Wolf" with seed 1234 always looks identical.

### Within-Category Variation

A Wolf and a Lion are both Beasts. They share the quadruped body plan but differ in:
- `body.width` × `height` × `depth` (Wolf is leaner; Lion is bulkier)
- `palette.primary` (Wolf grey; Lion gold)
- `face.mouth_style = "teeth_ring"` for both, but `tooth_count` and `tooth_size` differ
- `limbs.has_arms = false`; both quadrupeds use legs for all 4 limbs
- `ornaments.tags = ["mane"]` for Lion; empty for Wolf

These per-species differences are stored as **modifiers on the ActorTypeData entry**, e.g.:

```gdscript
"Lion": {
    "category": "Beast",
    "body_plan_modifiers": {
        "ornaments.tags": ["mane"],
        "palette.primary": Color(0.78, 0.55, 0.20),
        "body.scale": 1.2
    },
    ...
}
```

The generator applies the base Beast plan, then overlays modifiers from the actor type entry. Adding a new species = adding ~10 lines of modifiers to its `ActorTypeData` entry. **Zero code changes for a new monster.**

### Cross-Species Breeding (already exists, just plugs in)

`ActorData.universal_crossover_breed(parent_a, parent_b)` already produces a kid whose body type is one of the parents (50/50 roll) with traits grafted from the other. With the universal procedural body in place, this works for *any* species pair — Beast × Aberration, Dragon × Ooze, Humanoid × Plant, etc.

The Frankenstein graft slot already supports:
- Mushroom cap on top of any body
- Mimic teeth ring on any cap/dome
- Eyes scattered on the surface
- Limbs inherited from a parent who has them

We extend the graft slot's allowed grafts to include category-specific features:
- Wings (Dragon, Fey, Celestial)
- Horns (Fiend, Giant, some Beasts)
- Tail (Dragon, Beast, Fiend, Monstrosity)
- Halo (Celestial)
- Tentacles (Aberration, Ooze)
- Tattered cloth (Undead)

### Bodyplan Migration of Existing Specialists

Mimic's `ProceduralMimicChest.gd` and Mushroom's `ProceduralMushroomBody.gd` stay — they become **specialist renderers** for the `body.type = "mimic_chest"` and `body.type = "mushroom_stem"` slots in the universal registry. Existing functionality preserved; new universal renderers slot in alongside.

---

## §7 — Bonds & Loyalty

### Bond Levels

Bonds tick up between **pairs of monsters that survive runs together**. Capped at 5. Never decrease (but losing a bonded packmate has consequences).

| Bond | Tick condition | Unlocks |
|------|----------------|---------|
| 0 | (default for never-paired) | — |
| 1 | Survived 1 run together | +5% damage to a shared target when adjacent |
| 2 | Survived 3 runs together | **Unlocks a 2-monster combo move** (species-pair-specific) |
| 3 | Survived 7 runs together | Combo cooldown −30% |
| 4 | Survived 15 runs together | +2% all stats when paired |
| 5 | Survived 30 runs together | **Legacy bond.** If one dies, the survivor gets +20% damage in the biome where partner fell, for the next run |

### Grief Debuff

When a bonded packmate dies (any bond level ≥ 2), the survivor gets:
- −10% damage output
- +5% damage taken
- Lasts 3 in-game days (3 runs)

This means permadeath has *real* cost beyond losing a unit — your bonds suffer.

### Combo Move Pairings

Each species-pair gets one combo. Authored content, not procedural.

| Pair | Combo |
|------|-------|
| Goat × Mimic | "Bait & Charge" — Mimic taunts (target locks); Goat auto-charges crit |
| Goat × Mushroom | "Spore Sweep" — Goat charges through Spore Cloud, spreading it 2x |
| Mimic × Mushroom | "Fungal Trap" — Mimic ambushes after Mushroom roots target |
| Goblin × Goat | "Stab & Smash" — Goblin Ankle-Slash → Goat Headbutt knockback combo |
| (etc., authored per pair as content scales) |

Hybrid kids inherit ONE combo entitlement from each parent. So a Mimic × Mushroom hybrid kid can unlock both the Mimic combo pool AND the Mushroom combo pool.

---

## §8 — The Hub

The hub is the home base between runs. Stardew-shaped — open-ended, the day structure is the heartbeat.

### Buildings (progressive unlocks)

| Building | Unlocked by | Purpose |
|----------|-------------|---------|
| **Breeding Pen** | (Default — start) | Pair 2 monsters, kid hatches in 1–3 days |
| **Mission Board** | (Default — start) | 3–5 contracts/day, refreshes on day-tick |
| **Apothecary** | Complete first contract | Heal wounded monsters (cheap), revive *recent* corpses (expensive, time-limited window) |
| **Lab** | Capture 5 unique species | Research traits from monster parts; lets you *target* mutations in breeding instead of pure roll |
| **Forge** | Hub day 5 | Craft charms (consumable buffs) and capture gear (better nets, stronger ropes) |
| **Egg Incubator** | Find a wild egg | Hatch eggs faster + small chance of mutation boost |
| **Stable** | Capture a rideable beast | Mount system (1 mount in pack, gives mobility bonus) |
| **Library** | Reach 20 traits learned | Visible trait collection screen `[§9]` |

### Daily Loop at the Hub (5–15 min)

Loose checklist, not forced:

1. Check breeding pen — collect hatched kids, name them, evaluate stats
2. Apothecary — heal wounded, revive any salvaged corpses
3. Lab (if owned) — slot a trait research, examine parts
4. Mission board — pick a contract (this is the day-advance)
5. Squad screen — pick or swap your loadout
6. Depart

The hub day tick happens **when you accept a contract**, not on real time. Players choose their pace.

---

## §9 — Trait Library

The long-tail meta-game. Every captured species adds its traits to the **library**, which then feeds breeding rolls.

### Discovery

- Capture a species for the first time → all its known traits get added to the library (with locked silhouettes for unknown ones)
- Captured monsters retain their traits regardless of library state
- Library is shared across all monsters in the herd (not per-monster)

### Library Traits Feed Breeding

A library trait can roll on any hybrid kid's slot-3 move (`[§5]`, 12% chance). The more library traits you have, the wider your kid-generation pool.

### Visible Progress

Library UI shows:
- "47 / ~200 traits known"
- Per-category breakdown ("Beast: 12/25 traits learned")
- Silhouettes of locked traits with a hint about which biome/species to find them in
- Recently added (last 5 captures) highlighted

This gives the player a permanent answer to "what should I do next?" — every unknown trait is a self-generated quest.

### Trait Examples

Reused from existing `MUTATION_POOL` + new species-tied traits:

- **Universal mutations** (existing 15 + new): Pulse Burst, Shadow Step, Glowing Veins, Crystal Growth, ...
- **Beast-specific**: Pack Tactics, Keen Smell, Charge, Trample, Pounce, ...
- **Dragon-specific**: Frightful Presence, Wing Buffet, Tail Sweep, Breath Weapon, ...
- **Undead-specific**: Life Drain, Undead Fortitude, Paralyzing Touch, ...
- (and so on per category)

Each ActorTypeData entry's `abilities` array becomes the traits learned on first capture. Reuses existing data, zero authoring tax.

---

## §10 — Leaderboards (The Endgame)

Replaces a hand-authored "you won" arc. Hand-authored endings age out; leaderboards become the meta-game forever.

### Five Boards at Launch

| Board | What it rewards | Player type |
|-------|-----------------|-------------|
| **Deepest Dive** | Most floors in a single endless dungeon | Combat skill, squad comp |
| **Apex Bloodline** | Breed a creature with lineage across all 14 categories. Score = fewest generations. (Replaces a "final boss" — completion puts you on the board, doesn't end the game.) | Breeding skill, long-term planning |
| **Trait Library Speed** | How fast you fill the library (50 / 100 / all) | Exploration, capture mastery |
| **Contract Chain** | Longest consecutive run streak without a squad wipe | Strategy, risk management |
| **Highest-Rated Chimera** | One monster's combined score: graft count + mutation count + hybrid gen + library coverage | Pure breeding flex |

### Daily Seeded Runs (the killer feature)

Same dungeon seed for everyone in the world per day. Starting monsters are pre-rolled by seed (no breeding head-start matters). Pure tactical board. Slay the Spire daily climb model. Cheap to implement, infinite replayability.

### Implementation

- Phase 1: **Local-only** leaderboards. Each board stored in `user://leaderboards.cfg`. Player sees their personal records.
- Phase 2: Online backend (Steam Leaderboards or custom). Out of scope for MVP.

### Visible Position

Top of the hub screen shows your rank on each board (or "personal best" in local-only mode). Constant reminder of where you stand.

---

## §11 — Progression Arc

What unlocks over a full campaign. Permadeath means "number bigger" can't be the only vector. Replace with **breadth** that opens new options.

### Progression Vectors

| Vector | Unlock mechanism | Player feel |
|--------|------------------|-------------|
| **Biomes** | Complete intro contract in current biome → next biome unlocked | "New place to go" |
| **Hub buildings** | Hit milestones (first contract, 5 captures, day 5, etc.) | "Ranch is growing" |
| **Trait library** | Capture species | "I'm learning the world" |
| **Contract tiers** | Rep gained from completed contracts | "I'm somebody now" |
| **Monster categories** | Defeat first creature of each category | "I've seen this before" |

### Biome Order (MVP)

1. **Crystal Caverns** — Sonic + Earth monsters favored. Walls break to reveal secret rooms.
2. **Spider Nest** — Poison resist matters. Web traps slow movement.
3. **Volcano** — Fire resist matters. Magma tiles damage non-resistant.
4. (Sky Ruins, Crypts, Frozen Wastes, etc. — added post-MVP)

### MVP Player Goal

"Capture and learn all 47 species in the 3 launch biomes. Breed an apex chimera with traits from all 14 D&D categories."

That goal is approachable in ~30–80 hours of play. Past that, players chase leaderboard positions and weird breeding experiments forever.

---

## Content Strategy: Why Procedural

Hand-authoring 600 monsters from scratch is impossible. Hand-authoring 12 monsters and stopping is boring. The game's content strategy is:

1. **Stats:** Already done. `ActorTypeData` + `ActorTypes/*Data.gd` has ~600 entries with HP, AC, ability scores, equipment pools, AI behavior tags.
2. **Visuals:** Generative. The universal procedural body `[§6]` produces a recognizable creature from category + species modifiers. Variety scales with category templates + per-species modifiers.
3. **Behavior:** Composable. AI behaviors (`FlockBehavior`, `RowdyBehavior`, `ChargeOnSightBehavior`, etc.) are tagged in ActorTypeData. New species → list which behaviors to attach. Same code, new combinations.
4. **Movesets:** Inherited. Each species has 2–3 actions from its abilities pool. Hybrids inherit and roll for mutations.
5. **Capture mechanic:** Templated. 4 archetypes (`weaken`, `break_armor`, `kill_lessers`, `counter_charge`) cover every species in the manual. Each ActorTypeData entry picks one.

**Adding a new monster type = ~15 lines of dictionary entries.** Zero new code unless the species needs a fundamentally new ability not in the registry yet.

---

## MVP Scope

### Ship-ready cuts

- **3 dungeon biomes** with ~10 procedural rooms each (= 30 layouts)
- **~15 species** at launch (existing Goat / Mimic / Mushroom / Goblin / Farmer + 10 new procedural from the manual)
- **4 monster roles**: Bruiser, Support, Disruptor, Scout (rest emerge from breeding combinations)
- **3 quest types**: Hunt, Capture Contract, Boss Bounty
- **5 hub buildings**: Breeding Pen, Mission Board, Apothecary, Lab, Forge
- **4 pack commands**: Attack, Defend, Spread, Capture (+ Combo unlocked at bond 2)
- **5 leaderboards** (local-only) + Daily Seeded Run
- **Universal procedural body** working for 4 of 14 categories (Beast, Humanoid, Plant, Construct) — the others stub out and use the existing Goat-like fallback

### Deferred to post-MVP

- Mounts / Stable building
- Online leaderboards
- Tournaments / Rival fights
- The other 10 D&D categories' specific body plans
- Egg Incubator
- Seasons / weather
- Map expansion (already-designed in `Markdowns/World/MapExpansion.md`)

---

## File Map

### What Cody Already Built

| File | What it does |
|------|--------------|
| `Components/ActorComponents/ActorTypeData.gd` | Registry; merges 14 per-category files |
| `Components/ActorComponents/ActorTypes/*.gd` | ~600 monster stat blocks |
| `Components/ActorComponents/ActorData.gd` | Per-actor data resource; has `shared_body_plan`, `MUTATION_POOL`, `universal_crossover_breed`, render_seed, hybrid_generation |
| `Components/ActorComponents/CharacterBuildComponent.gd` | Reads pools, applies armor/weapon/ability/faction/HP at spawn |
| `src/actors/ai/controller_modes/*.gd` | TwinStick + ThirdPerson player control modes |
| `src/actors/ai/behaviors/*.gd` | Composable AI: Flock, Rowdy, ChargeOnSight, NimbleEscape |
| `src/actors/types/ProceduralMimicChest.gd` | Specialist procedural body for mimics |
| `src/actors/types/ProceduralMushroomBody.gd` | Specialist procedural body for mushrooms |
| `Components/Arena/ArenaSpawner.gd` | Solo "Play As" route already wired |
| `UI/DisplayCard/ActorCard.gd` + `CreaturePreview.gd` | Live 3D preview of any creature |
| `Components/BreedingComponents/HerdManager.gd` | Capture mechanic (nets), herd persistence, `pending_individual_creature` |

### What This Plan Adds

| New file | Purpose |
|----------|---------|
| `src/actors/body/ProceduralCreatureBody.gd` | Universal renderer that reads `shared_body_plan` |
| `src/actors/body/PartBuilders/*.gd` | One file per part type (BodyShapes, Faces, Limbs, Ornaments, Mutations) |
| `Components/ActorComponents/ActorBodyPlanGenerator.gd` | Per-category body-plan generators |
| `Components/BreedingComponents/BondComponent.gd` | Pair-bond tracking |
| `Components/Arena/DungeonRunController.gd` | 4-room state machine for runs |
| `Components/Arena/RoomTemplates/*.gd` | Layout pool per biome × room type |
| `Components/UI/ExtractScreen.gd` + `.tscn` | Leave/push/abandon UI at extract point |
| `Core/TraitLibrary.gd` | Persistent trait collection autoload |
| `Core/LeaderboardManager.gd` | Local leaderboard storage |
| `UI/HubScreen.gd` + supporting scenes | Hub UI with building unlocks |
| `UI/SquadPicker.gd` + `.tscn` | Squad loadout selection |
| `Markdowns/Plans/HornboundImplementationPlan.md` | Step-by-step build order |
| `Markdowns/Systems/UniversalProceduralBody.md` | Architecture doc for §6 |
| `Markdowns/Systems/BondSystem.md` | Architecture doc for §7 |
| `Markdowns/Systems/RunStructure.md` | Architecture doc for §1 |
| `Markdowns/Systems/Leaderboards.md` | Architecture doc for §10 |

### What Gets Refactored

| File | Change |
|------|--------|
| `Components/ActorComponents/ActorData.gd` | Already has `shared_body_plan`; no schema change. Add bond tracking integration. |
| `ActorTypes/*Data.gd` (all 14) | Add `body_plan_modifiers`, `capture_archetype`, `category` fields. |
| `src/actors/types/MimicActor.gd` + `MushroomActor.gd` | Optionally migrate to use `ProceduralCreatureBody` directly. Existing specialist renderers stay as plug-ins. |

---

## Open Questions

These don't block implementation — they're design knobs we can dial after first playable.

1. **Monster age & death from old age** — Currently monsters age in days but don't die of it. Should they? (Forces rotation, but adds emotional toll.)
2. **Loyalty rebellion** — If bond breaks (e.g. you sell a bonded mate?), does the survivor flee/refuse to fight? Suggested: yes, with a 1-week grief lockout.
3. **Combo move sharing rules** — When a hybrid kid inherits 2 combos (one from each parent's pair), can it use both at once? (Lean: yes, but only one active per partner per fight.)
4. **Possession penalty** — When you possess a packmate after your lead dies, is there a cooldown? Mechanical answer: 0.5s i-frames + 2s reduced damage. Feels like a real moment without breaking flow.
5. **Daily-seed monster generation** — On daily-seed runs, do players use their bred herd or pre-rolled monsters? Lean: pre-rolled (level playing field). But maybe a "Pro" daily uses your own.

---

## Modular Implementation Note

Every system above is decoupled enough to ship independently. Suggested order (each unlocks more design space than the last):

1. Universal Procedural Body `[§6]` — content engine FIRST so everything else has visual diversity
2. Bond System `[§7]` — emotional weight
3. Trait Library `[§9]` — long-tail hook
4. Possession `[§3]` — survival depth
5. Run Structure `[§1]` — replaces existing free-form arena
6. Leaderboards `[§10]` — endgame
7. Hub Building Tree `[§8]` — long-term progression
8. Capture Archetypes `[§4]` — depth in capture

See `HornboundImplementationPlan.md` for atomic steps.

---

*Last updated: 2026-05-25*
*Living document — update when any system's contract changes.*
