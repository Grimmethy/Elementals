# Agent 1 — Implementation Requirements & Dependency Chain Analysis

> **Scope.** Read-only requirements document for the next implementation pass on the Elementals Godot 4 project. Inventories the dependency chain for the four user-requested goals (Phase 0/1 hygiene + broken-fix; generalize breeding; generalize capture; introduce a procedural Mimic creature) and ends with a single concrete recommendation for what one patch session can defensibly deliver.
>
> **Authority rule when prior audits disagreed.** Code (Agent 2) wins over docs (Agent 1); Agent 3's plan resolves cross-doc conflicts. This document does not re-derive those resolutions — it cites them.
>
> All paths are repo-relative.

---

## 1. Source Reports Read

Read in full:

1. [docs/AGENT_1_DOCUMENTATION_AUDIT.md](AGENT_1_DOCUMENTATION_AUDIT.md)
2. [docs/AGENT_2_CODEBASE_AUDIT.md](AGENT_2_CODEBASE_AUDIT.md)
3. [docs/AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md)
4. [docs/ELEMENTALS_PROJECT_STATUS_AND_NEXT_STEPS.md](ELEMENTALS_PROJECT_STATUS_AND_NEXT_STEPS.md)

Spot-read (the load-bearing files the prior audits pointed at):

- [Components/ActorComponents/ActorData.gd](../Components/ActorComponents/ActorData.gd) — verified `class_name ActorData`, base resource, exposes `gender`, `is_pregnant`, `pregnancy_timer`, `pregnancy_father`, `is_exhausted`, `base_color`, `pattern_color`, virtual `create_offspring(partner) -> ActorData`, virtual `get_actor_type() -> String`.
- [Components/BreedingComponents/GoatData.gd](../Components/BreedingComponents/GoatData.gd) — `GoatData extends ActorData`; `create_offspring()` at lines 77-96 (color lerp, 50/50 horn/body, stat mean ± 10%); goat-only `goat_name`, `level`, `gold_value`, `stamina_*`, `age_days`, enums `HornType/BodyType/PatternType`.
- [Components/BreedingComponents/HerdManager.gd](../Components/BreedingComponents/HerdManager.gd) — autoload that composes 5 manager components; `herd: Array[ActorData]`; **but `next_day()` at lines 94-107 silently drops any kid that is not `GoatData`** (see TODO "Add handlers for other actor types").
- [Core/Managers/BreedingComponent.gd](../Core/Managers/BreedingComponent.gd) — fully generic at the `ActorData` level; `breed(parent_a, parent_b)` calls `actor.create_offspring(partner)`.
- [Components/BreedingComponents/Ranch/Ranch.gd](../Components/BreedingComponents/Ranch/Ranch.gd) — UI is **hardcoded to goats**: `selected_doe: GoatData`, `selected_buck: GoatData`, `card.goat_data = goat`, sort `a.goat_name < b.goat_name`, `MaxLevelGoat` cheat constructs `GoatData.new()` and pushes to `add_goat()`.
- [Components/ActorComponents/AbilityComponents/AbilityComponent.gd](../Components/ActorComponents/AbilityComponents/AbilityComponent.gd) — `actions: Array[AbilityAction]`; `setup()` lines 26-39 is a hardcoded `if element_type == "goblin" / "goat"` block.
- [Components/ActorComponents/AbilityComponents/AbilityAction.gd](../Components/ActorComponents/AbilityComponents/AbilityAction.gd) — `RefCounted`; `_init(p_actor, p_component)` binds the action to a specific actor.
- [src/actors/base/Actor.gd:226-337](../src/actors/base/Actor.gd) — `_setup_components()` wires ~20 components.
- [src/actors/ai/ActorAIController.gd](../src/actors/ai/ActorAIController.gd), [ActorStateMachine.gd](../src/actors/ai/ActorStateMachine.gd), [states/](../src/actors/ai/states) — 9 states (idle, roam, chase, attack, flee, investigate, stunned, death, Dormant).
- [src/actors/types/](../src/actors/types) — `GoatActor`, `FarmerActor`, `FireActor`, `WaterActor`, `GoblinMinion`, `ScarecrowDummy` + their controllers + `GoblinModels/`. **Only `GoatActor` carries a `goat_data: GoatData`** (`get: return _data as GoatData`); the others have no `*Data` resource binding.
- [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd) — six hardcoded `@export var *_scene := preload(...)` at the top; `spawn_actor_at_tile(type, tile)` uses `match type`; `_make_random_goat_data()` exists only for goats.
- [Components/Arena/TileSignalComponent.gd](../Components/Arena/TileSignalComponent.gd) — verified `Timer.new()` at lines 20-25 (anti-pattern), generic hex-distance trigger registry, `register_trigger(center_tile, radius, callback, metadata)`.
- [Components/GameClockComponent.gd](../Components/GameClockComponent.gd) — `register_tick(callback, interval) -> id`, `unregister_tick(id)`, `tick_elapsed(delta)` signal.
- [UI/MainMenu.gd:67-100](../UI/MainMenu.gd) — confirmed reflection-based ability lookup (instantiate Actor + Node + AbilityAction, read `ability_name`, free) each menu open.
- [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd) lines 1-30 — exposes `selected_goat: GoatData`, `selected_actor: Actor`, plus the weapon catalog.
- [Markdowns/Capture.md](../Markdowns/Capture.md) — describes loyalty + items model with `ActorState` enum WILD / RESTRAINED / CONFINED / TAMING / TAMED / FLED.
- [Markdowns/Breeding.md](../Markdowns/Breeding.md) §Capture System — same `ActorState` model; Agent 3 R1 designates this as canonical, deprecating Capture.md's loyalty-driven framing.
- [Markdowns/Abilities.md](../Markdowns/Abilities.md), [Markdowns/procedural_character_framework.md](../Markdowns/procedural_character_framework.md) §Vision + §Detail Level System.

---

## 2. Documented Needs To Fix

Priority ordered. Each cites a source path. Categories follow Agent 3's "Do now / Later" split.

### 2.1 Must fix now (Phase 0 hygiene + Phase 1 broken-fix)

| # | Need | Source |
|---|------|--------|
| M1 | Fix Ranch return scene path. [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) targets `res://Ranch/Ranch.tscn` (does not exist); real path is `res://Components/BreedingComponents/Ranch/Ranch.tscn`. | Agent 2 §3.1, §5.1; Agent 3 task 0.3 |
| M2 | Delete 30+ orphan `.uid` files (no `.gd` companion). | Agent 2 §5.2-5.4, Appendix A; Agent 3 task 0.1 |
| M3 | Delete 8 editor-crash `.tmp` files (`Play Space/tree_feature.tscn*.tmp` ×6, `QuestSystem/QuestTrackerHUD.tscn*.tmp` ×2). | Agent 2 §5.1, Appendix A; Agent 3 task 0.2 |
| M4 | Patch AGENTS.md path lie (`res://Components/Arena/GameClockComponent.gd` → `res://Components/GameClockComponent.gd`). | Agent 2 §1.4, §5.5; Agent 3 task 0.4 |
| M5 | Update README `GoatManager` → `HerdManager` (rename shipped 2025-01-28). | Agent 1 §9.1 C1; Agent 3 task 0.7 |
| M6 | Delete legacy 2D `player.gd` + `player.tscn`. | Agent 2 §3.5; Agent 3 task 0.10 |
| M7 | Mark `Markdowns/Capture.md` deprecated in favor of `Markdowns/Breeding.md` §Capture System (`ActorState` model is canonical). | Agent 1 §9.3 D5; Agent 3 task 0.8 + R1 |
| M8 | Remove `Timer.new()` from `TileSignalComponent` (anti-pattern: the proximity authority violates the AGENTS.md no-Timer rule). Replace with `GameClockComponent.register_tick`. | Agent 2 §10.3; Agent 3 task 1.2 |
| M9 | Remove `Timer.new()` from `DetectionComponent`. Replace with `Actor.register_tick`. | Agent 2 §10.3; Agent 3 task 1.3 |
| M10 | Restore breeding gameplay loop end-to-end: depends on M1 (Ranch return) + generalizing `ItemsAutoload.selected_goat` → `selected_actor_data`. Currently the data layer works but the player-visible loop is blocked. | Agent 2 §3.1; Agent 3 task 1.1 |
| M11 | Reconcile Actor.md to 3D (currently declares `extends CharacterBody2D` + `Vector2`). | Agent 1 §9.1 C2; Agent 3 task 0.5 |
| M12 | Annotate or move `Markdowns/SettlementImplementationPlan.md` (React/JSX project; not implementable in this Godot repo). | Agent 1 §9.1 C8; Agent 3 task 0.6 |

### 2.2 Should fix soon (Phase 1 prep + Phase 2 modular extractions)

| # | Need | Source |
|---|------|--------|
| S1 | `QuestStarterKit._ensure_tile_signal_component` group-check instead of node-name check. | Agent 2 §5.6; Agent 3 task 1.5 |
| S2 | Promote `AbilityRegistry` autoload to replace the MainMenu reflection at [UI/MainMenu.gd:67-100](../UI/MainMenu.gd). **Prerequisite for the Mimic skill-copy feature.** | Agent 2 §8; Agent 3 task 2.6 |
| S3 | Extract `ActorFactory` from `ArenaSpawner` `match type` dispatch + hardcoded preloads. **Prerequisite for any new actor type (incl. Mimic).** | Agent 1 P1 item 8; Agent 2 §9, §11; Agent 3 task 2.8 |
| S4 | Generalize `ActorCard` to take `ActorData` and rename `GoatRenderer` → `ActorCardRenderer`. **Prerequisite for any non-goat in the Ranch UI.** | Agent 1 §10 P1 items 5-6; Agent 3 task 2.9 |
| S5 | Decide farmer playability scope (README "playing farmer is for masochists"). One-paragraph scoping decision before any code. | Agent 1 §10 P0 item 4; Agent 3 task 1.6 |

### 2.3 Can wait (Phase 3 procedural extractions + Phase 4 big content)

| # | Need | Source |
|---|------|--------|
| W1 | Extract `TraitInheritanceEngine` from `GoatData.create_offspring()` so Goblin/Elemental/Mimic can use it. | Agent 1 §10 P1 item 9; Agent 3 task 3.5 |
| W2 | `SpawnVarianceConfig` Resource for elementals/summoned beings. | Agent 1 §10 P1 item 9; Agent 3 task 3.6 |
| W3 | `CaptureComponent` + `ActorState` enum implementation. | Agent 1 §10 P0 item 2; Agent 3 task 4.1 |
| W4 | `RegionData` + `RegionManager` (map expansion). | Agent 1 §10 P4; Agent 3 task 4.2 |
| W5 | Earth & Air elementals (data-driven `ElementalProfile`). | Agent 1 §10 P7 item 47; Agent 3 task 4.6 |
| W6 | Procedural Character Framework — phases 1-2 (CreatureDefinition + LimbBuilder). | Agent 1 §10 P5 items 28-29; Agent 3 tasks 4.7-4.8 |
| W7 | VisibilityManager rewrite (per-foliage hot loop + ungated debug prints). | Agent 2 §10.1; Agent 3 task 5.1 |
| W8 | Tree LOD wiring + visible-tree cap. | Agent 1 §10 P3 item 20; Agent 3 task 5.8 |
| W9 | Projectile pooling. | Agent 2 §10.5; Agent 3 task 5.3 |

### 2.4 Needs more inspection

| # | Need | Why |
|---|------|-----|
| I1 | Is `BreedableComponent` worth adding? Breeding.md "Not Yet Implemented" says "Planned but not needed for Phase 1" and the same doc later contradicts itself (Agent 1 C6). Decide before generalizing `BreedingComponent` further. |
| I2 | What is the canonical Capture *agent* relationship? Capture.md talks about the *player* throwing nets, but in Elementals the player controls an Actor (Goat/Farmer/etc.) — not a separate human avatar. The capture verb is owned by the *controlled actor*, which means any actor needs a `WeaponComponent`-equipped Net **and** the Net needs to be a weapon-like restraint, not a damage weapon. Capture.md does not address this. |
| I3 | Does the user want `FarmerData`, `GoblinData`, `ElementalData`, `MimicData`, `ScarecrowData` as separate `ActorData` subclasses or a single data-driven `ActorProfile` Resource? Breeding.md assumes the former; the procedural character framework points toward the latter. Cannot pick without user input. |
| I4 | Save/load semantics of transient state (Mimic morph target, capture `ActorState`, restraint stack). `Core/Managers/SaveComponent.gd` serializes `GoatSaveData` only. If captured actors persist across save/load, save schema must change. |

---

## 3. Creature System Requirements (per playable creature type)

Status per axis: `OK` (works today) / `partial` / `missing`. Cited by file path.

| Axis | Goat (GoatActor) | Farmer (FarmerActor) | Goblin (GoblinMinion) | Fire (FireActor) | Water (WaterActor) | Scarecrow (ScarecrowDummy) |
|------|------------------|----------------------|------------------------|------------------|---------------------|----------------------------|
| `ActorData` subclass | OK — `GoatData` ([Components/BreedingComponents/GoatData.gd](../Components/BreedingComponents/GoatData.gd)) | **missing** | **missing** | **missing** | **missing** | **missing** |
| `*Data` resource carried on the actor | OK — `goat_data: GoatData` ([src/actors/types/GoatActor.gd:26-28](../src/actors/types/GoatActor.gd)) | **missing** — no resource | **missing** | **missing** | **missing** | **missing** |
| Stats (Actor base fields + ActorData ability scores) | OK | OK (base only) | OK (base only) | OK (base only) | OK (base only) | OK (base only) |
| Skills/abilities | OK — `GoatCharge` wired in [AbilityComponent.gd:36-39](../Components/ActorComponents/AbilityComponents/AbilityComponent.gd) | **missing** — no abilities assigned | OK — random NimbleEscape/RedirectAttack in [AbilityComponent.gd:29-35](../Components/ActorComponents/AbilityComponents/AbilityComponent.gd) | **missing** — no AbilityAction wired | **missing** | **missing** |
| AI controller | OK — `GoatController` | OK — `FarmerController` | OK — `GoblinController` | partial — base `ActorAIController` only | partial | partial — Dormant state used |
| Spawning | OK — `goat_actor_scene` + `_make_random_goat_data()` in [ArenaSpawner.gd:9, 296](../Components/Arena/ArenaSpawner.gd) | OK — `farmer_scene` preloaded | OK — `goblin_scene` preloaded; quest pipeline spawns goblins specifically | OK — `fire_actor_scene` preloaded | OK — `water_actor_scene` preloaded | OK — `spawn_scarecrow()` |
| Ownership / faction | OK — `FactionComponent.PLAYER` when selected, NEUTRAL otherwise | partial — defaults to FARMSTEAD | partial — defaults to GOBLINS via quest spawn faction config | partial | partial | partial |
| Save/load | OK — `GoatSaveData` serializes `Array[GoatData]` | **missing** — no per-actor persistence | **missing** | **missing** | **missing** | **missing** |
| UI (Ranch card, MainMenu select) | OK — `ActorCard` hardcoded to `goat_data` ([Ranch.gd:51-59](../Components/BreedingComponents/Ranch/Ranch.gd)) | **missing** — no card; MainMenu has a `farmer` actor-type entry but no data card | partial — MainMenu actor-type entry exists | partial — same as farmer | partial — same | **missing** |
| Progression / leveling | partial — `GoatData.level` exists but no XP system | **missing** | **missing** | **missing** | **missing** | **missing** |
| Procedural generation (visual + stats) | partial — `_make_random_goat_data()` randomizes goat traits; `ActorVisualComponent.update_goat_visuals` is goat-specific | **missing** | **missing** | **missing** — only the actor scene is preloaded | **missing** | **missing** |
| Breeding participation | OK at data layer ([BreedingComponent.gd](../Core/Managers/BreedingComponent.gd)) but `HerdManager.next_day()` only re-adds `GoatData` kids (lines 100-104) | **blocked** — no `FarmerData`; even if breed succeeded, `next_day()` drops the kid | **blocked** — same | **blocked** — same | **blocked** — same | N/A (not a living creature) |
| Capture *as target* | **blocked** — no CaptureComponent anywhere | **blocked** | **blocked** | **blocked** | **blocked** | N/A |
| Capture *as agent* (can it throw a net?) | undefined — depends on user decision in I2 | undefined | undefined | undefined | undefined | N/A |

### 3.1 Generalization gaps that make "all playable creatures" hard

- `HerdManager.next_day()` at [Components/BreedingComponents/HerdManager.gd:94-107](../Components/BreedingComponents/HerdManager.gd) explicitly only re-adds the offspring if `kid as GoatData` succeeds. **Any non-goat breeding produces a phantom kid that is created and dropped.** This is a one-line code path but it is a hard block.
- `Ranch.gd` uses `selected_doe: GoatData` / `selected_buck: GoatData` types and sorts by `a.goat_name`. Any non-goat in the herd would fail this sort and crash.
- `ActorVisualComponent.setup_visuals()` (Breeding.md Phase 3) does not yet dispatch by `get_actor_type()`. Adding a `GoblinData` to the herd cannot render in `ActorCard` today.

---

## 4. Breeding System Requirements

Checklist with per-item status + file path.

| # | Requirement | Status | Path |
|---|-------------|--------|------|
| B1 | `ActorData` base resource (gender, pregnancy fields, virtual `create_offspring`) | **exists** | [Components/ActorComponents/ActorData.gd](../Components/ActorComponents/ActorData.gd) |
| B2 | `GoatData : ActorData` with goat-specific `create_offspring()` | **exists** | [Components/BreedingComponents/GoatData.gd:77](../Components/BreedingComponents/GoatData.gd) |
| B3 | Generic `BreedingComponent.breed(a, b)` (gender check, exhaustion gate, pregnancy fields) | **exists** | [Core/Managers/BreedingComponent.gd](../Core/Managers/BreedingComponent.gd) |
| B4 | `process_pregnancy()` calls `actor.create_offspring(partner)` polymorphically | **exists** | [Core/Managers/BreedingComponent.gd:32-48](../Core/Managers/BreedingComponent.gd) |
| B5 | `HerdManager` autoload composes the 5 sub-components | **exists** | [Components/BreedingComponents/HerdManager.gd](../Components/BreedingComponents/HerdManager.gd) |
| B6 | `HerdComponent.herd: Array[ActorData]` (generic) | **exists** | [Core/Managers/HerdComponent.gd](../Core/Managers/HerdComponent.gd) |
| B7 | `HerdManager.next_day()` re-adds offspring of any `ActorData` type, not just goats | **partial** — explicit cast-and-drop at lines 100-104; TODO is acknowledged in code | [Components/BreedingComponents/HerdManager.gd:94-107](../Components/BreedingComponents/HerdManager.gd) |
| B8 | `ItemsAutoload.selected_actor_data: ActorData` (generic selection bus) | **partial** — both `selected_goat: GoatData` and `selected_actor: Actor` exist; no generic `selected_actor_data` | [Core/ItemsAutoload.gd:5-15](../Core/ItemsAutoload.gd) |
| B9 | `Ranch.gd` accepts any `ActorData` subclass | **missing** — typed as `GoatData` throughout | [Components/BreedingComponents/Ranch/Ranch.gd](../Components/BreedingComponents/Ranch/Ranch.gd) |
| B10 | `ActorCard` consumes `actor_data: ActorData` (not `goat_data: GoatData`) | **partial / missing** — Breeding.md Phase 2 work; Ranch.gd line 53 still sets `card.goat_data = goat` | [UI/DisplayCard/ActorCard.gd](../UI/DisplayCard/ActorCard.gd) (consumer of `.goat_data`); see Agent 1 C12 |
| B11 | `ActorCardRenderer` (rename of `GoatRenderer`) dispatches per `get_actor_type()` | **missing** | [UI/GoatRenderer.gd](../UI/GoatRenderer.gd) |
| B12 | `ActorVisualComponent.setup_visuals(data: ActorData)` dispatches by type (Breeding.md Phase 3) | **missing** — `update_goat_visuals(goat_data)` is the only entry today | [Components/ActorComponents/ActorVisualComponent.gd](../Components/ActorComponents/ActorVisualComponent.gd) (consumer of `goat_data`) |
| B13 | `GoblinData : ActorData` with goblin-specific `create_offspring()` | **missing** | would need to be created in `Components/BreedingComponents/GoblinData.gd` (Phase 4 of Breeding.md) |
| B14 | `FarmerData : ActorData` | **missing** | not even planned in Breeding.md |
| B15 | `ElementalData : ActorData` (Fire/Water/Earth/Air variants) | **missing** | planned in Breeding.md |
| B16 | `MimicData : ActorData` (for the user-requested Mimic) | **missing** | not currently planned anywhere |
| B17 | `TraitInheritanceEngine` (MENDELIAN/QUANTITATIVE/ENVIRONMENTAL/MUTATIONAL modes) | **missing** — algorithm lives inline in `GoatData.create_offspring()` | Agent 3 task 3.5; would be `Components/BreedingComponents/TraitInheritanceEngine.gd` |
| B18 | `BreedableComponent` (per-actor breeding policy: SEXUAL/ASEXUAL/ELEMENTAL/GESTATION) | **missing** — Breeding.md "Not needed for Phase 1" + contradiction (Agent 1 C6); see I1 |
| B19 | `SpawnVarianceConfig` (UNIFORM/GAUSSIAN/BOUNDED per-stat) | **missing** | Agent 3 task 3.6 |
| B20 | Generic `GameEvents.actor_selection_toggled(actor_data, is_selected)` | **exists** alongside deprecated `goat_selection_toggled` | [Core/GameEvents.gd](../Core/GameEvents.gd) per Breeding.md Phase 1 status |
| B21 | Ranch return scene path (M1 above) | **broken** | [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) |
| B22 | Save schema persists offspring of all actor types | **partial** — `SaveComponent` writes `GoatSaveData`; offspring of non-goat types are dropped *before* save | [Core/Managers/SaveComponent.gd](../Core/Managers/SaveComponent.gd) |

**Net conclusion.** Breeding for *goats* is one Ranch-path-fix away from working. Breeding for *any other species* requires at minimum: `*Data` subclass with `create_offspring()` (B13-B16), `HerdManager.next_day()` generalization (B7), `Ranch.gd` typed-to-generic refactor (B9), and `ActorCard` + visual dispatch (B10-B12). That is Breeding.md Phases 2 + 3 + 4 + part of Phase 5, **not** a single patch.

---

## 5. Capture System Requirements

Checklist. Canonical model is Breeding.md `ActorState` per Agent 3 R1.

| # | Requirement | Status | Path |
|---|-------------|--------|------|
| C1 | `ActorState` enum (WILD / RESTRAINED / CONFINED / TAMING / TAMED / FLED) | **missing** — Grep confirmed zero hits | would be `Components/ActorComponents/ActorState.gd` |
| C2 | `CaptureComponent` on capturable actors | **missing** — Grep confirmed zero hits | would be `Components/ActorComponents/CaptureComponent.gd` |
| C3 | `CaptureProfile` Resource (restraint resistance, escape DC curve, taming curve) | **missing** | Agent 3 task 4.1 schema |
| C4 | AI FSM bridge: WILD→RESTRAINED disables roam/chase, enables drag-target; TAMED rejoins owner's faction | **missing** — `ActorAIController` does not consult any capture state | [src/actors/ai/ActorAIController.gd](../src/actors/ai/ActorAIController.gd) |
| C5 | Restraint stacking math (`Escape DC = base + restraint_rating × 2 + size_mod + traits`) | **missing** | Capture.md design only |
| C6 | Net + Rope + Chain + Manacle + Trap items in `ItemsAutoload` weapon catalog (as capture-tools) | **missing** — Net is *mentioned* in [Markdowns/Capture.md](../Markdowns/Capture.md) but **not** registered in the catalog | [Core/ItemsAutoload.gd:26-110](../Core/ItemsAutoload.gd) — no `Net` entry |
| C7 | Drag mechanic (player speed reduction, shared-tile lock, drop-on-hit save) | **missing** | Capture.md design only |
| C8 | "Confinement Threshold" base-value table + size modifier | **missing** | Capture.md design only |
| C9 | Taming session loop (consumes items + time, raises loyalty 0-1) — *or* per Agent 3 R1, the canonical `ActorState.TAMING → TAMED` transition that integrates with `HerdManager` | **missing** | Breeding.md §Capture System |
| C10 | `HerdManager` accepts a TAMED non-goat actor | **blocked by B7** | [Components/BreedingComponents/HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd) |
| C11 | Save/load persists `ActorState` and restraint stack across sessions | **missing** | requires schema change in `Core/Managers/SaveComponent.gd` |
| C12 | UI to show captured/dragged actor state | **missing** | no UI hooks exist |
| C13 | Capture *agent* affordance: any controlled actor can equip-and-throw a Net via existing `WeaponComponent`/`ProjectileComponent` | **needs decision (I2)** then **missing** | [Components/WeaponComponents/](../Components/WeaponComponents) — `ProjectileComponent` supports thrown weapons (`drop_inventory()` even spawns pickups), but no capture-type projectile exists |

**Reading of "capture for ALL playable creatures."** Interpreted as: *the capture system must work generically for any capturable actor type (i.e. not hardcoded to goats)* — because "every actor can be captured" would imply farmers and scarecrows are capturable, which is nonsense. With that reading, all C1-C13 items apply equally to whatever `ActorData` subclasses end up flagged "capturable." Confirm with user (I2).

**Net conclusion.** Capture is *zero* implemented. It cannot be "fixed" — it has to be *built*. That is Agent 3 Phase 4 task 4.1, sized as a high-risk multi-PR effort because it touches the AI FSM, the herd, the save schema, and the weapon catalog simultaneously.

---

## 6. Mimic Creature Requirements

A new procedural creature that can attack, bite, **morph into nearby creatures**, and **use copied skills**. Map each requested capability to its prerequisite system and that system's status.

### 6.1 Core capabilities (user specification)

| # | Mimic capability | Required system(s) | Prerequisite status |
|---|------------------|--------------------|----------------------|
| MM1 | Spawn as a Mimic via the existing spawn pipeline | `ActorFactory` registered with `MimicData → MimicActor.tscn`; OR fall back to a hardcoded `mimic_scene` `@export` on `ArenaSpawner` | `ActorFactory` **missing** (S3); fallback path is a one-line code addition |
| MM2 | `MimicData : ActorData` with procedural creature profile (mean stats, color, size, mutation rates) | `MimicData.gd` subclass; optional `TraitInheritanceEngine` integration if Mimics can breed | `MimicData` **missing**; `TraitInheritanceEngine` **missing** (W1) — but a minimal `MimicData` with inline genetics can ship without the engine |
| MM3 | Basic melee bite attack | `WeaponComponent` + a "bite" `WeaponData` entry **or** an unarmed strike with bite damage type | `WeaponComponent` **exists**; "bite" weapon entry **missing** in ItemsAutoload; existing `Unarmed strike` fallback at [WeaponComponent.gd:91-103](../Components/WeaponComponents/WeaponComponent.gd) is reusable |
| MM4 | AI controller — chase, attack, flee like other creatures | `ActorAIController` base class; existing 9-state FSM | **exists** — direct use of `ActorAIController` (or a thin `MimicController`) is sufficient |
| MM5 | Scan nearby creatures with low CPU cost | **must use `TileSignalComponent`** (per AGENTS.md) — register a continuous-mode trigger of radius R around the Mimic's current tile; consume `trigger_activated`/`trigger_deactivated` to maintain a `_nearby_actors: Array` | `TileSignalComponent` **exists** but uses `Timer.new()` (M8 anti-pattern). Mimic can use the registry today; the M8 fix is independent. |
| MM6 | Cooldown / scan cadence (don't re-pick a target every frame) | **must use `GameClockComponent.register_tick(callback, interval)`** (per AGENTS.md) | `GameClockComponent` **exists** |
| MM7 | Morph into a nearby creature (swap visual + swap behavior) | (a) Visual swap: requires `ActorVisualComponent.setup_visuals(data)` dispatch on type — **Breeding.md Phase 3**; (b) behavior swap: requires either re-`setup()`-ing AI controller for the new type OR a stateless visual-only morph that keeps Mimic AI | (a) **missing** (B12) — without it, the Mimic cannot render as a Goblin/Goat/etc; (b) AI re-setup is risky because most controllers assume their `Actor` subclass type at `_ready()` |
| MM8 | Copy skills from a nearby creature's `AbilityComponent` | (a) Enumerate target's `ability_component.actions: Array[AbilityAction]`; (b) discover each action's class via `action.get_script()`; (c) instantiate `ActionClass.new(self, self.ability_component)` and `add_action()`. **Requires `AbilityRegistry` (S2)** so the Mimic knows the full universe of stealable abilities AND for safe class-name → script resolution; without it, the Mimic is limited to introspection of whatever the target happens to have today | `AbilityRegistry` **missing** (S2); only **3** concrete `AbilityAction` classes exist (GoatCharge, NimbleEscape, RedirectAttack), so the *stealable pool is currently tiny* |
| MM9 | Use the copied skill | Existing `AbilityComponent.execute_ability(type, value)` | **exists** — works once MM8 lands because each `AbilityAction._init(p_actor, p_component)` rebinds the action to the Mimic |
| MM10 | Be capturable | `CaptureComponent` + `ActorState` enum | **missing** (Section 5); ships only if/when Capture system ships |
| MM11 | Breed (Mimic biology — Breeding.md `ReproductionMode.ASEXUAL` budding) | `MimicData.create_offspring()` self-reproduction logic; `HerdManager.next_day()` accepts non-goat kids (B7) | `HerdManager` generalization **partial** (B7); `MimicData` **missing**. Asexual reproduction is simpler than sexual (no partner gating in `BreedingComponent.breed()`), but the current `BreedingComponent.breed()` requires male+female and returns false otherwise — so Mimic breeding needs either a new code path or `BreedableComponent` (B18) |
| MM12 | Save/load Mimic state (morph target, copied actions) | `SaveComponent` schema | **missing**. Reasonable default: Mimic state is **transient** (resets to base form on save/load); persisting morph + cloned action class names is a non-trivial schema change. |

### 6.2 Mimic-specific design constraints (derived, not in any current doc)

- **AbilityAction is RefCounted and actor-bound** ([Components/ActorComponents/AbilityComponents/AbilityAction.gd:14](../Components/ActorComponents/AbilityComponents/AbilityAction.gd)). "Copying a skill" cannot share an instance — it must construct a fresh instance with the Mimic as `actor`. Confirmed by reading `_init(p_actor, p_component)`.
- **Mimic morph is not free.** Even a visual-only morph requires `ActorVisualComponent.setup_visuals()` to dispatch on type (Breeding.md Phase 3). Without it the Mimic visually stays a Mimic, and the "morph" is just a behavior trick.
- **Mimic uses TileSignalComponent for scans, but that component still has a Timer (M8).** Mimic can be implemented before M8 lands; M8 is an internal cleanup that does not change `TileSignalComponent`'s public API.
- **Mimic abilities pool is currently tiny.** With only 3 `AbilityAction` classes total (GoatCharge, NimbleEscape, RedirectAttack), the gameplay payoff of the "copy skill" feature is low until more abilities exist. **Worth scoping with the user.**
- **No `Core/Abilities/Dash.gd` registration.** Agent 2 §3.2 found `Dash.gd` exists but isn't wired in `AbilityComponent.setup()`. Wiring it would double the stealable pool with low risk.

---

## 7. Coworker Design Protection Rules

Extracted from AGENTS.md + Agent 2's DO-NOT-BREAK list (Agent 2 §11).

### 7.1 Routing rules (must obey)

- **All distance/proximity decisions route through `Components/Arena/TileSignalComponent.gd`.** Never re-implement hex-distance math; use `register_trigger(center_tile, radius, callback)` or `_get_hex_distance()`. (AGENTS.md §"Critical: Component Routing".)
- **All timing routes through `Components/GameClockComponent.gd`** via `Actor.register_tick(callback, interval)` / `unregister_tick(id)`. **Never** spawn `Timer.new()` on actor-side components. Never accumulate in `_physics_process` for game logic. (AGENTS.md §"Critical: Centralized Timing".)
- Visual-only per-frame effects use `Tween`, not `_physics_process`.

### 7.2 Coding conventions (must obey)

- `class_name` at top of every script; `_` prefix for private vars; group vars with `@export_group`.
- Component pattern: every component takes `actor: Node3D` and exposes `setup(p_actor)`.
- Hex grid: axial `Vector2i`; use `ArenaGrid.get_tiles_in_radius()` for area queries.
- State machine: AI states inherit from `AIState.gd` with `enter / exit / physics_update`.
- Signal connections: prefer `.bind()` over closures.
- Always `is_instance_valid()` + `get_node_or_null` for optional nodes.
- **SYNC RULE** (Abilities.md / Actor.md / UI.md headers): "When modifying [actor/ability/UI] structure (add/remove/modify components, signals, properties, methods, or actions), update this document in the **same commit**."

### 7.3 Adding-a-thing recipes (must obey)

- New component: declare on `Actor.gd`, init in `_setup_components()` with `_add_comp(NewComponent.new()).setup(self)`.
- New AI state: extend `AIState.gd`, register in `ActorAIController._init_state_machine()`.
- New tile state: add to `tile_constants.gd` enum, update `HexTileData._sync_type()`, add behavior in `TileSystem.gd`, handle in `ArenaGrid.set_tile_state()`.

### 7.4 DO-NOT-BREAK files (Agent 2 §11)

`project.godot`, `Play Space/Arena.gd`, `Play Space/Arena.tscn`, `src/actors/base/Actor.gd`, `Components/GameClockComponent.gd`, `Components/Arena/TileSignalComponent.gd`, `Components/Arena/GridGenerator.gd`, `Components/Arena/TileSystem.gd`, `Components/Arena/ArenaSpawner.gd`, `Components/BreedingComponents/HerdManager.gd`, `Core/GameEvents.gd`, `Core/ItemsAutoload.gd`, `Core/WeaponData.gd`, `Components/WeaponComponents/WeaponComponent.gd`, `src/actors/ai/ActorAIController.gd`, `src/actors/ai/FactionComponent.gd`, `QuestSystem/QuestSpawnManager.gd`, `QuestSystem/QuestDatabase.gd`, `QuestSystem/quests.json`, `src/trees/VisibilityManager.gd`, `UI/MainMenu.tscn`, `Components/BreedingComponents/Ranch/Ranch.tscn`.

Any change to these files requires the corresponding acceptance test (Agent 3 §9 testing checklist) to pass before merge.

### 7.5 Procedural-character rules (procedural_character_framework.md §"AI Prompting Guide")

- One phase per session; name files explicitly; state what must NOT be done; do not assume AI will remember between sessions.
- **Hard "never use AnimationPlayer"** — procedural characters are 100% IK/physics-layered.

---

## 8. Documentation Updates Required After This Pass

| # | Doc | Update | Source |
|---|-----|--------|--------|
| D1 | [README.md](../README.md) | `GoatManager` → `HerdManager`; remove "[Currently Busted]" from Ranch line once M1+M10 land. | Agent 1 §9.1 C1 |
| D2 | [AGENTS.md](../AGENTS.md) | Correct `GameClockComponent` path to `res://Components/GameClockComponent.gd`. Update project structure to list current actor types and the new Mimic. | Agent 2 §1.4, §5.5 |
| D3 | [Markdowns/Actor.md](../Markdowns/Actor.md) | Rewrite as 3D (`CharacterBody3D` + `Vector3`); reconcile component list against [src/actors/base/Actor.gd:226-337](../src/actors/base/Actor.gd). | Agent 1 §9.1 C2 |
| D4 | [Markdowns/Capture.md](../Markdowns/Capture.md) | Add header `DEPRECATED — see Breeding.md §Capture System for canonical ActorState model.` | Agent 1 §9.3 D5; Agent 3 R1 |
| D5 | [Markdowns/Breeding.md](../Markdowns/Breeding.md) | Mark Phase 1 explicitly complete; resolve the `BreedableComponent` contradiction (Agent 1 C6) before any further breeding work. Reflect the `HerdManager.next_day()` non-goat gap (B7). | Agent 1 §9.1 C5, C6 |
| D6 | [Markdowns/Abilities.md](../Markdowns/Abilities.md) | After `AbilityRegistry` lands (S2), describe registry's `register_ability(class_name, script)` API + how Mimic consumes it. Per SYNC RULE. | §7.2 |
| D7 | [Markdowns/UI.md](../Markdowns/UI.md) | After `ActorCard` generic + `ActorCardRenderer` rename (S4), update card section. Per SYNC RULE. | §7.2 |
| D8 | [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) | Move to `Markdowns/ExternalProjects/` or add admonition: "NOTE: This document describes a separate React/JSX webapp and is not implemented in this Godot project." | Agent 1 §9.1 C8 |
| D9 | New: `Markdowns/Mimic.md` | Document the Mimic design once implemented — `MimicData`, scan/morph/copy state machine, save/load semantics, dependency on `AbilityRegistry`. | — |
| D10 | [docs/AGENT_1_DOCUMENTATION_AUDIT.md](AGENT_1_DOCUMENTATION_AUDIT.md), [AGENT_2_CODEBASE_AUDIT.md](AGENT_2_CODEBASE_AUDIT.md) | Refresh status notes after each phase lands so the next audit cycle starts from current truth. | Agent 1 §10 P6 |

---

## 9. Dependency Chain Analysis (CRITICAL)

The table below is the load-bearing artifact of this document. Each row says: feature → what *must* exist first → whether it exists → what breaks if you skip the prereq → recommended action.

| Feature | Hard Prerequisites | Prerequisite Status | Risk If Built Without | Recommended Action |
|---------|--------------------|-----------------------|------------------------|---------------------|
| **Ranch return from Arena works** | Correct scene path in [ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) | M1 fix is one line | Player ejects from Arena to a dead path; "Return to Ranch" silently fails | **Ship M1 immediately.** Zero blast radius. |
| **Goat breeding loop visible to player** | M1 (Ranch path) + B8 (`selected_actor_data`) + B22 (save schema) | M1 trivial; B8 partial; B22 OK for goats | Without M1, player never reaches Ranch from Arena. Without B8, MainMenu selection bus mixes legacy `selected_goat` with new generic; no functional break for goat-only flow but blocks future generalization. | **Ship M1 + a minimal B8 (alias `selected_goat` to `selected_actor_data`).** Defer Ranch generalization. |
| **Breeding works for non-goat species** | B7 (HerdManager generalization) + B9 (Ranch.gd typed-to-generic) + B10-B12 (ActorCard + ActorVisualComponent dispatch) + B13/B14/B15/B16 (`*Data` subclasses with `create_offspring()`) + B18 decision (BreedableComponent or inline) | All **missing or partial** | Offspring data is created and silently dropped at [HerdManager.gd:101-104](../Components/BreedingComponents/HerdManager.gd); Ranch crashes on `a.goat_name < b.goat_name`; ActorCard renders nothing for non-goat | **DO NOT ship in single slice.** Sized as Breeding.md Phases 2-4 (3-4 focused PRs). Goat-only generalization is fine as an interim. |
| **Capture works for any creature** | C1 (`ActorState` enum) + C2 (`CaptureComponent`) + C4 (AI FSM bridge) + C6 (Net + restraint items) + C10 (HerdManager non-goat acceptance = B7) + C11 (save schema change) + I2 (capture-agent decision) | All **missing** | The README "broken" tag stays; cannot acquire wild creatures by any means; data layer cannot persist captured state | **DO NOT ship in single slice.** This is Agent 3 Phase 4 task 4.1, a high-risk multi-PR effort. Ship a *gate-stub* (decision doc + empty `CaptureComponent.gd` scaffold) at most. |
| **Mimic — bite-only base creature** | M8 unrelated; `MimicData : ActorData` (B16); minimal `MimicActor : Actor` + scene; hardcoded `mimic_scene` `@export` on ArenaSpawner (S3 not required for hardcoded slot) | `MimicData` missing; everything else trivial | Without `MimicData` the Mimic has no procedural stats and cannot ever participate in breeding | **Shippable in one patch.** Minimal scope = bite attack via `Unarmed strike` weapon, no morph, no copy. |
| **Mimic — TileSignal-based scan for nearby creatures** | `TileSignalComponent.register_trigger()` (exists); `GameClockComponent.register_tick()` (exists); the **bite-only Mimic** as a host | TileSignal + GameClock both **exist** | Without routing through TileSignal, the Mimic would have to per-frame iterate `arena.actors` — direct AGENTS.md violation | **Shippable in one patch** alongside the Mimic base. Uses existing public APIs. |
| **Mimic — morph (visual swap into nearby creature)** | B12 (`ActorVisualComponent.setup_visuals(data)` dispatch on type — Breeding.md Phase 3) + decision on whether morph swaps mesh only or also AI controller | **missing — B12 not done** | Mimic visually stays a Mimic; "morph" is invisible to the player | **CANNOT ship in single slice.** Requires Breeding.md Phase 3 to land first. Surface this honestly to the user. |
| **Mimic — copy a skill from a nearby creature** | S2 (`AbilityRegistry` autoload to enumerate stealable classes) + actor-bound `AbilityAction` constructor pattern (already exists) + a non-trivial pool of `AbilityAction` classes (currently only 3) | `AbilityRegistry` **missing**; only 3 abilities exist | Without registry, Mimic can introspect target's actions but has no safe way to instantiate them generically — and even with introspection, the stealable pool is tiny (GoatCharge, NimbleEscape, RedirectAttack). Gameplay payoff today is low. | **DEFER until S2 lands** AND/OR until more abilities are authored. Possible interim: hardcode steal-only-GoatCharge to demonstrate the loop, but flag the limitation. |
| **Mimic — use copied skill** | The copy step (above) | Blocked by above | N/A | **Trivially works once copy lands** (existing `AbilityComponent.execute_ability` handles it). |
| **Mimic — captureable** | Capture system (Section 5) | Blocked by all of Section 5 | Mimic only acquirable by Mimic-specific spawn (not capture) | **DEFER until Capture system ships.** |
| **Mimic — breeds (asexual budding per Breeding.md)** | B7 (HerdManager non-goat acceptance) + B16 (`MimicData.create_offspring()` returning a `MimicData`) + B18 (BreedableComponent for ASEXUAL mode) **or** a new `BreedingComponent.breed_asexual(self)` code path | All **missing**; current `BreedingComponent.breed()` *requires* male+female pair (returns false otherwise) | Even if `MimicData.create_offspring()` exists, calling `HerdManager.breed(mimic, mimic)` returns false on the gender check; if forced through, the kid would be dropped at `HerdManager.next_day()` | **DEFER until Breeding generalization ships.** |
| **Mimic — save/load morph+stolen actions** | Schema change in `Core/Managers/SaveComponent.gd`; `MimicData` serializes morph target name + cloned action class names | Schema **missing** | Mimic restores in base form on reload; players lose progress mid-encounter | **Recommend transient-only by design.** Document that Mimic morph + copied skills do not persist. |

---

## 10. Smallest Defensible Implementation Slice

The single-patch recommendation. Designed to (a) restore documented working state, (b) eliminate two AGENTS.md rule violations, (c) land a minimal Mimic that does not promise capabilities its prerequisites can't deliver, and (d) not break anything on the DO-NOT-BREAK list.

### 10.1 In scope (this patch)

| # | Item | Cited |
|---|------|-------|
| SDS-1 | M1: fix Ranch return path at [ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) | §2.1 |
| SDS-2 | M2: delete the 30+ orphan `.uid` files listed in Agent 2 Appendix A | §2.1 |
| SDS-3 | M3: delete the 8 `.tmp` editor-crash files | §2.1 |
| SDS-4 | M4: patch AGENTS.md `GameClockComponent` path | §2.1 |
| SDS-5 | M5: README `GoatManager` → `HerdManager` | §2.1 |
| SDS-6 | M7: deprecation header on [Markdowns/Capture.md](../Markdowns/Capture.md) | §2.1 |
| SDS-7 | M8: remove `Timer.new()` from `TileSignalComponent`; route through `GameClockComponent.register_tick` | §2.1 |
| SDS-8 | M9: remove `Timer.new()` from `DetectionComponent`; route through `Actor.register_tick` | §2.1 |
| SDS-9 | M10 (narrow): generalize `ItemsAutoload.selected_goat` → `selected_actor_data` (add new property; keep `selected_goat` as a deprecated alias that proxies to the new one) — this is the minimum to verify the goat-only breeding loop works end-to-end after M1 | §2.1, B8 |
| SDS-10 | **New file `Components/BreedingComponents/MimicData.gd`** — `class_name MimicData extends ActorData`; carries `mimic_name`, color palette, stats overrides; stub `create_offspring(partner)` that returns a `MimicData` (asexual budding: ignores partner, applies mutation) | §6.1 MM2 |
| SDS-11 | **New file `src/actors/types/MimicActor.gd` + `scenes/actors/MimicActor.tscn`** — `class_name MimicActor extends Actor`; `element_type = "mimic"`; carries `mimic_data: MimicData` via `_data` (mirroring `GoatActor.goat_data`) | §6.1 MM1, MM2 |
| SDS-12 | **New file `src/actors/types/MimicController.gd`** — `extends ActorAIController`; uses existing FSM; in `_ready` registers a `TileSignalComponent` continuous trigger of radius 4 centered on the Mimic's tile; consumes `trigger_activated`/`trigger_deactivated` into a `_nearby_actors: Array` cache; runs scan logic on a `GameClockComponent.register_tick(callback, 0.5)` (2Hz) — **demonstrates the correct routing pattern** | §6.1 MM5, MM6 |
| SDS-13 | **Hardcode `mimic_scene` `@export` on `ArenaSpawner.gd`** (one new line + `match` arm) — bite-only Mimic spawnable via `spawn_actor("mimic")`; uses `Unarmed strike` weapon (existing fallback at [WeaponComponent.gd:91-103](../Components/WeaponComponents/WeaponComponent.gd)) for the bite | §6.1 MM1, MM3 |
| SDS-14 | New doc `Markdowns/Mimic.md` — describes the minimal Mimic, lists the **explicit deferred features** (morph, copy, breed, capture) with their gating prerequisites by section reference | §8 D9 |

### 10.2 Explicitly out of scope (this patch)

| # | Item | Why deferred | Gating prereq |
|---|------|--------------|---------------|
| SDS-X1 | Mimic morph (visual swap into nearby creature) | `ActorVisualComponent.setup_visuals(data)` polymorphism does not exist | Breeding.md Phase 3 / B12 |
| SDS-X2 | Mimic copy skills (clone target's AbilityAction onto self) | `AbilityRegistry` autoload does not exist; only 3 abilities to steal — low payoff today | S2 + new ability authoring |
| SDS-X3 | Mimic breeding | `HerdManager.next_day()` drops non-goat kids; `BreedingComponent.breed()` requires male+female pair | B7 + B18 decision |
| SDS-X4 | Mimic capture | Entire Capture system missing | Section 5 |
| SDS-X5 | Generalizing Ranch.gd to non-goat herds | B9 + B10 + B11 + B12 all missing; Ranch sort would crash on non-goats | Breeding.md Phases 2-3 |
| SDS-X6 | Capture system of any kind | Single largest missing system in the project; touches AI FSM, save schema, weapon catalog | Agent 3 task 4.1 (separate multi-PR effort) |
| SDS-X7 | Earth/Air elementals | Out of audit scope for this patch | Agent 3 task 4.6 |
| SDS-X8 | Procedural Character Framework | "Status: Design Phase" — separate epic | Agent 3 tasks 4.7-4.9 |
| SDS-X9 | VisibilityManager perf fix + Tree LOD wiring | Pure perf; safe to defer | Agent 3 tasks 5.1, 5.8 |
| SDS-X10 | `ActorFactory` extraction | Recommended for next pass; not required to land the bite-only Mimic | Agent 3 task 2.8 |

### 10.3 Why this slice is defensible

- **Every item in 10.1 either (a) corrects documented intent (M1-M9, M11-M12 deltas) or (b) follows AGENTS.md routing rules verbatim (SDS-12 uses `TileSignalComponent` + `GameClockComponent`).**
- **Nothing in 10.1 touches a DO-NOT-BREAK file in a behavior-changing way.** The only file in that list that changes is `ItemsAutoload.gd` (additive alias), and the alias preserves the old `selected_goat` binding.
- **No new feature is shipped that depends on a missing prerequisite.** Mimic morph, Mimic copy-skill, Mimic breeding, and Mimic capture are explicitly deferred with a citation of the gating prerequisite.
- **The patch leaves the project in a state where the next patch can ship `ActorFactory` (S3), then Breeding.md Phase 3 (B12 visual polymorphism) and `AbilityRegistry` (S2), unlocking Mimic morph and copy in two follow-on patches.**

### 10.4 Strict patch order inside the slice

1. SDS-1 (one line, zero risk).
2. SDS-2, SDS-3, SDS-6 (deletions + doc-only — independent).
3. SDS-4, SDS-5 (doc-only).
4. SDS-7, SDS-8 in that order — `TileSignal` must keep working while changing its internal timer; verify by running [test_fire_spread.gd](../test_fire_spread.gd) and observing quest-camp discovery on a fresh Arena.
5. SDS-9 (additive alias on `ItemsAutoload`).
6. SDS-10, SDS-11, SDS-12, SDS-13, SDS-14 — Mimic introduction. Run the smoke flow (Agent 3 §9.1-§9.6) after SDS-13.

Acceptance: every item in Agent 3's testing checklist §9 steps 1, 3, 4, 5, 6, 8, 10 still passes; new step "Mimic spawns via `spawn_actor('mimic')`, scans via TileSignal, bites adjacent enemy on a GameClock tick" passes.

---

*End of Agent 1 implementation requirements.*
