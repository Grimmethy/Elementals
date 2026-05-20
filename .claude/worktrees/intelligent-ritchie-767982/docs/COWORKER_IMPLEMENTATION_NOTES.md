# Coworker Implementation Notes

> Practical reference for the next AI/human coworker.
>
> **Patch history (most recent first):**
> - **Patch 3 — Mimic spawn wiring + minimum viable Net catch** ([ELEMENTALS_PATCH3_STATUS.md](ELEMENTALS_PATCH3_STATUS.md), [AGENT_2_PATCH3_LOG.md](AGENT_2_PATCH3_LOG.md), [AGENT_3_PATCH3_REVIEW.md](AGENT_3_PATCH3_REVIEW.md))
> - **Patch 2 — Breeding generalization** ([ELEMENTALS_PATCH2_STATUS.md](ELEMENTALS_PATCH2_STATUS.md), [AGENT_1_PATCH2_STATE_CHECK.md](AGENT_1_PATCH2_STATE_CHECK.md), [AGENT_2_PATCH2_LOG.md](AGENT_2_PATCH2_LOG.md), [AGENT_3_PATCH2_REVIEW.md](AGENT_3_PATCH2_REVIEW.md))
> - **Patch 1 — Extended Slice** ([ELEMENTALS_IMPLEMENTATION_STATUS.md](ELEMENTALS_IMPLEMENTATION_STATUS.md), [AGENT_1_IMPLEMENTATION_REQUIREMENTS.md](AGENT_1_IMPLEMENTATION_REQUIREMENTS.md), [AGENT_2_IMPLEMENTATION_PATCH_LOG.md](AGENT_2_IMPLEMENTATION_PATCH_LOG.md), [AGENT_3_INTEGRATION_REVIEW.md](AGENT_3_INTEGRATION_REVIEW.md))
>
> All paths repo-relative.

---

## 0a. Patch 3 Addendum (most recent — read this first)

Patch 3 fixed two visible bugs the user reported in-editor:

- **Mimic now spawns in normal Arena play.** `Components/Arena/ArenaSpawner.gd:17` has `@export var mimic_count: int = 1`; spawn loop at lines 59-62 mirrors the existing goblin pattern. Default 1 Mimic per arena; designer-tunable.
- **Net now actually catches things.** Three new primitives (designed so the future full Capture patch EXTENDS them, not replaces):
  - [`Components/ActorComponents/CaptureComponent.gd`](../Components/ActorComponents/CaptureComponent.gd) — lazy-attached at Net-hit time. API: `setup`, `can_be_captured`, `roll_save(modifier)`, `roll_catch(modifier)`, `apply_capture`, `apply_stun(duration)`.
  - [`Components/ActorComponents/CaptureProfile.gd`](../Components/ActorComponents/CaptureProfile.gd) — Resource (`save_dc`, `save_ability`, `stun_duration`, `catch_chance`, `allowed_actor_types`).
  - [`Components/ActorComponents/CaptureProfiles/DefaultNet.tres`](../Components/ActorComponents/CaptureProfiles/DefaultNet.tres) — Net's profile: DC 12 Dex save, 4.0s stun, 0.40 catch chance.
- **Net is 100% data-driven** via `WeaponData.is_capture_tool` parsed from the `"capture"` keyword in the notes string (now `Core/ItemsAutoload.gd:121`). Agent 3 grep-verified zero `if weapon.name == "Net"` hardcoding.
- **Combat flow:** `BaseProjectile._on_body_entered:242-245` early-returns into `_run_capture_flow(target)` when the projectile carries a capture-tool weapon; lazy-attaches `CaptureComponent` with the Net's profile; rolls save → on fail applies stun + catch roll → on catch success calls `HerdManager.add_goat(new_data) + actor.queue_free()`. Damage path is bypassed (no double-fire).
- **Capture creates a fresh `*Data` from runtime stats** (advisor option b). `apply_capture()` walks `actor.element_type` to pick the right subclass (goblin → `GoblinData.new()` etc.) and copies stats from `ability_scores_component`. No spawn-time changes needed — wild creatures are capturable today.
- **Readout messages** for user feedback (Agent 3 §2 verified):
  ```
  [Capture] Net hit Mimic. Save: rolled 11 vs DC 12 → FAIL (d20=9 + dexterity=2)
  [Capture] Mimic stunned for 4.0s. Catch roll: 0.32 vs 0.40 → CAUGHT
  [Capture] Mimic added to herd as mimic
  ```
- Stun routes through existing `Actor.stun()` → `StunComponent._process(delta)` — zero `Timer.new()`, zero `await create_timer()`.

### What's NOT in Patch 3 (deferred with rationale)

- **Full `ActorState` enum** (WILD/RESTRAINED/CONFINED/TAMING/TAMED/FLED) — multi-PR effort per [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md task 4.1](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md). The three Patch 3 primitives extend cleanly into it; future patch adds states + restraint stacking + AI FSM bridge + save schema change without removing existing methods.
- **Restraint stacking + drag mechanics** — design only in Breeding.md §Capture System.
- **Patch 4 work** (breeding generalization: ProgressionComponent.tick_day, sell_goat virtual, die hooks, GoatRenderer rename, asexual breeding) — the original Patch 3 scope; renamed Patch 4 after the pivot. Agent 1's state check at [docs/AGENT_1_PATCH3_STATE_CHECK.md](AGENT_1_PATCH3_STATE_CHECK.md) remains valid as its spec.

### Known v1.0 Patch 3 limitations (documented; not blockers)

| Limitation | Severity | Fix |
|---|---|---|
| Net visual is fallback `ArrowProjectile.tscn` (Net's WeaponData has no `projectile_scene_path`) | Cosmetic | Add `projectile_scene_path` to Net's `_add()` |
| Captured wild non-Mimics get default colors (their `_data == null` at wild spawn) | Cosmetic | Patch 4 procedural spawn data generation |
| No friendly-faction gate — Net hit on player goat captures it | Logic | One-line check in `CaptureComponent.can_be_captured()` |
| `ProgressionComponent.advance_day()` will crash when a captured non-goat advances a day (latent — only fires if captured non-goat in herd) | High but latent | Exactly Patch 4 scope |

The full Patch 3 detail (deferrals + extension contract + Patch 4 recommendation) is in [ELEMENTALS_PATCH3_STATUS.md](ELEMENTALS_PATCH3_STATUS.md).

---

## 0. Patch 2 Addendum (read this second)

Patch 2 generalized the breeding loop from goat-only to any `ActorData` subclass:

- **`ActorData` gained three virtuals:** `get_display_name() -> String`, `get_info_line() -> String`, `set_display_name(name)`. Default impls present; subclasses override.
- **`is_selected: bool` lifted** from `GoatData` to `ActorData`. Any future creature is selectable in the Ranch UI for free.
- **`HerdManager.next_day()` accepts any `ActorData` kid** — the one-line silent killer that dropped non-goat offspring is fixed at [HerdManager.gd:99-102](../Components/BreedingComponents/HerdManager.gd).
- **`GoatData.get_actor_type()` overridden to `"goat"`** (was returning `"GoatData"` from the default) — now matches `element_type` / factory keys / `MimicData` precedent.
- **Three new data subclasses:** [`GoblinData`](../Components/BreedingComponents/GoblinData.gd), [`FarmerData`](../Components/BreedingComponents/FarmerData.gd), [`ElementalData`](../Components/BreedingComponents/ElementalData.gd) (single class covering fire+water via `element_subtype: StringName`). Each has `create_offspring()` mirroring the goat algorithm (color lerp + 50/50 categorical + stat ±10%).
- **Non-goat actors now optionally carry their `*Data`** via typed accessors mirroring `GoatActor.goat_data`. **Critical safety gate**: each non-goat actor's hardcoded `_ready()` ability assignments are wrapped in `if _data == null:` so a designer-assigned data resource is not clobbered. Legacy spawn paths (no data assigned) work unchanged.
- **`ActorCard.gd` accepts any `ActorData`** via the new `actor_data` setter; `goat_data` alias preserved so Patch-1 call sites still work; renderer assignment gated `if actor_data is GoatData` since GoatRenderer rename is deferred.
- **`Ranch.gd` generic** — `selected_doe`/`selected_buck: ActorData`; sort via `get_display_name()`; signal handler renamed `_on_actor_selected`; cheat panel preserved.

What's still goat-only (Patch 3 candidates):
- `ProgressionComponent.advance_day()` reads goat-only `age_days` / `stamina_*` — **latent crash** the first time a non-goat enters the herd
- `HerdManager.sell_goat()` returns 0 gold for non-goats
- Non-goat actor `die()` lacks `HerdManager.remove_goat()` hook
- `GoatRenderer.gd` rename to `ActorCardRenderer.gd` (3 live `.tscn` refs prevent safe rename in one commit)
- `BreedingComponent.breed()` requires male+female — asexual creatures (Mimic) need a separate `breed_asexual()` code path

Save schema unchanged — already `Array[ActorData]` from a prior pass. **Never declare `Array[GoblinData]` / `Array[FarmerData]` etc.** — Godot 4.6 has known issues round-tripping mixed typed-subclass arrays.

The full Patch 2 detail (deferrals + next-patch recommendation + per-file diff list) is in [ELEMENTALS_PATCH2_STATUS.md](ELEMENTALS_PATCH2_STATUS.md). Sections 1-11 below describe the project state as of Patch 1; read with the Patch 2 deltas above in mind.

---

## 1. What Changed

Two categories of change:

**Hygiene + rule-compliance** — cleared documentation drift, deleted ~50 dead files, and removed two `Timer.new()` anti-pattern violations from the components that enforce the no-Timer rule.

**Modular foundations + first new procedural creature** — extracted three reusable systems (`AbilityRegistry`, `ActorFactory`, additive `ActorVisualComponent.setup_visuals(data)`) and introduced the **Mimic** as a full procedural creature with visual morph and skill-copy behavior, routed entirely through `TileSignalComponent` (proximity) and `GameClockComponent` (cadence). Two of the new components (`CreatureMorphComponent`, `SkillCopyComponent`) are deliberately Mimic-agnostic so any future creature can reuse them.

---

## 2. Why It Changed

Three drivers, in priority order:

1. **README explicitly flagged the Ranch return loop as broken.** Root cause was a one-line scene-path typo at [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd). Fixed.
2. **AGENTS.md singled out `TileSignalComponent` and `GameClockComponent` as the proximity and timing authorities, but the very component that enforces the no-Timer rule was violating it.** Two-line fixes in `TileSignalComponent` and `DetectionComponent` removed the `Timer.new()` anti-pattern and shifted both to GameClock registration.
3. **User asked for a procedural Mimic with morph + skill copy.** Doing that without hardcoding the things the user said not to hardcode required three prerequisite extractions first (`AbilityRegistry`, `ActorFactory`, `setup_visuals` polymorphism). All three are independently reusable.

Deferred work was deferred on purpose:
- **Breeding for non-goat species** would silently drop offspring at [HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd) (`var goat_kid = kid as GoatData; if goat_kid: add_goat(goat_kid)`). Fixing that is one line, but it cascades into Ranch.gd, ActorCard, and ActorVisualComponent generalization that exceeds one safe pass.
- **Capture system** has zero implementation and touches the AI FSM, save schema, and weapon catalog simultaneously — flagged in Agent 1 §10.2 as a multi-PR effort.

---

## 3. Files Changed

### New files

| Path | Purpose |
|---|---|
| [Core/AbilityRegistry.gd](../Core/AbilityRegistry.gd) | Autoload — scans `Components/ActorComponents/AbilityComponents/` at boot, caches `StringName → Script`, provides safe per-actor `instantiate_for()` |
| [Components/Arena/ActorFactory.gd](../Components/Arena/ActorFactory.gd) | `StringName → PackedScene` dispatcher used by `ArenaSpawner`. Replaces hardcoded `match type` |
| [Components/BreedingComponents/MimicData.gd](../Components/BreedingComponents/MimicData.gd) | `MimicData : ActorData`; tuning knobs (`scan_radius`, `scan_interval`, `morph_duration`, `skill_copy_limit`, `disallowed_target_types`); asexual `create_offspring()` |
| [Components/ActorComponents/CreatureMorphComponent.gd](../Components/ActorComponents/CreatureMorphComponent.gd) | Generic visual + identity morph helper (snapshot + restore pattern) |
| [Components/ActorComponents/SkillCopyComponent.gd](../Components/ActorComponents/SkillCopyComponent.gd) | Generic skill cloning helper; routes through `AbilityRegistry.instantiate_for()` so clones are actor-bound (never shared refs) |
| [src/actors/types/MimicActor.gd](../src/actors/types/MimicActor.gd) | `MimicActor : Actor`; `is_playable = false`; MONSTERS faction; auto-equips Unarmed strike for bite |
| [src/actors/types/MimicController.gd](../src/actors/types/MimicController.gd) | `MimicController : ActorAIController`; TileSignal radius-4 trigger + GameClock 2Hz tick; dispatches morph/copy via the dedicated components |
| [scenes/actors/MimicActor.tscn](../scenes/actors/MimicActor.tscn) | Minimal `CharacterBody3D` scene with sphere body + collider + default `MimicData` sub-resource |
| [Markdowns/Mimic.md](../Markdowns/Mimic.md) | v1.0 design + implementation reference + deferred-features list |

### Modified files (behavior-changing — all pre-approved on the DO-NOT-BREAK list)

| Path | Change |
|---|---|
| [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) | SDS-1: Ranch return scene path corrected |
| [Components/Arena/TileSignalComponent.gd:20-45](../Components/Arena/TileSignalComponent.gd) | SDS-7: `Timer.new()` removed, replaced with `arena.get_game_clock().register_tick(_refresh_tracked_actors, 1.0)`. Public API unchanged. |
| [Components/ActorComponents/DetectionComponent.gd:25-35,117-122,294-300](../Components/ActorComponents/DetectionComponent.gd) | SDS-8: `Timer` field removed; `_expiry_tick_id` registered via `Actor.register_tick(_on_expiry_tick, 0.5)`; `_notification(EXIT_TREE)` unregisters |
| [Core/ItemsAutoload.gd:14-31,141-163](../Core/ItemsAutoload.gd) | SDS-9: added `selected_actor_data: ActorData`; converted `selected_goat` to a getter/setter alias; `set_selected_actor()` mirrors generic bus and emits goat signal correctly for both goat and non-goat actors |

### Modified files (additive only — no behavior change for existing callers)

| Path | Change |
|---|---|
| [project.godot](../project.godot) | Registered `AbilityRegistry` autoload (additive entry) |
| [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd) | Added `mimic_scene` export + `_actor_factory` composition; existing `spawn_actor_at_tile(type, tile)` call signature preserved |
| [Components/ActorComponents/ActorVisualComponent.gd:85-115](../Components/ActorComponents/ActorVisualComponent.gd) | Added `setup_visuals(data: ActorData)` polymorphic entry point + `_apply_mimic_visuals()`. Existing `update_goat_visuals()` and callers untouched |
| [UI/MainMenu.gd:66-94](../UI/MainMenu.gd) | Internal helpers (`_get_goblin_abilities`, `_get_goat_abilities`, `_resolve_ability_names_for`) refactored to filter via AbilityRegistry instead of reflection. Public displayed names unchanged |

### Modified files (docs only)

| Path | Change |
|---|---|
| [AGENTS.md](../AGENTS.md) | GameClockComponent path corrected (was wrongly under `Components/Arena/`) |
| [README.md](../README.md) | `GoatManager` → `HerdManager` |
| [Markdowns/Capture.md](../Markdowns/Capture.md) | Deprecation header pointing to `Breeding.md §Capture System` |
| [Markdowns/Actor.md](../Markdowns/Actor.md) | `CharacterBody2D / Vector2 / Node2D` → 3D type names in code blocks |
| [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) | Top-of-file admonition: "React/JSX, not part of this Godot project" |
| [Markdowns/Abilities.md](../Markdowns/Abilities.md) | v1.1 — "Core Class 0: AbilityRegistry" section added (SYNC RULE) |
| [Markdowns/UI.md](../Markdowns/UI.md) | v1.1 — new MainMenu helper rows (SYNC RULE) |

### Deletions

- `player.gd` + `player.tscn` + `player.gd.uid` (legacy 2D leftovers)
- 36 orphan `.gd.uid` files at root and in `Core/`, `Components/`, `Components/Arena/`, `Components/ActorComponents/`, `Experimental/`, `tests/`, `test/`, `UI/`
- 8 `.tscn*.tmp` editor-crash leftovers (6 under `Play Space/`, 2 under `QuestSystem/`)

---

## 4. How The Breeding System Works (current state)

Breeding **for goats** is restored end-to-end after this patch:

1. Player selects a goat in MainMenu (`ItemsAutoload.set_selected_actor`) → both `selected_actor_data` and the legacy `selected_goat` are populated; `goat_selected` signal fires for the Ranch UI.
2. Player enters Arena. After "Finish Day", [ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) now correctly loads `Components/BreedingComponents/Ranch/Ranch.tscn` (was a dead path before).
3. In Ranch, pair a doe + buck. `Core/Managers/BreedingComponent.breed(parent_a, parent_b)` performs gender check + exhaustion gate + 3-day pregnancy.
4. On day advance, `BreedingComponent.process_pregnancy()` calls `actor.create_offspring(partner)`. For goats this dispatches to [GoatData.create_offspring() at line 77](../Components/BreedingComponents/GoatData.gd) — color lerp, 50/50 horn/body, stats mean ±10%.
5. `HerdManager.next_day()` casts the kid as `GoatData` and adds to the herd. `SaveComponent` serializes `GoatSaveData` containing the updated herd.

**Breeding for non-goat species is NOT functional yet.** The blocker is one line at [HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd):

```gdscript
var goat_kid = kid as GoatData
if goat_kid:
    add_goat(goat_kid)
# TODO: Add handlers for other actor types
```

This silently drops any offspring whose data type is not `GoatData`. Adding non-goat breeding requires this fix PLUS `Ranch.gd` typed-to-generic refactor (currently sorts by `goat_name`) PLUS `ActorCard` generic acceptance PLUS per-species `*Data` subclasses with their own `create_offspring()`. That's Breeding.md Phases 2-4, sized as 3-4 separate PRs.

### Reusable functions (current naming — matches existing project conventions)

- `BreedingComponent.breed(parent_a: ActorData, parent_b: ActorData) -> bool` — gender + exhaustion gate; sets pregnancy state on the female
- `BreedingComponent.process_pregnancy(actor_data: ActorData) -> ActorData` — returns offspring when timer expires; calls `actor.create_offspring(partner)` polymorphically
- `ActorData.create_offspring(partner: ActorData) -> ActorData` — virtual; subclasses override (e.g. `GoatData.create_offspring`, `MimicData.create_offspring`)

These are the project's actual names; do not rename them to fit a generic spec.

---

## 5. How The Capture System Works (current state)

**Capture is not implemented.** Zero code exists for `CaptureComponent`, `ActorState`, restraint stacking, or drag mechanics. Grep confirms this. [Markdowns/Capture.md](../Markdowns/Capture.md) now carries a deprecation header pointing to [Markdowns/Breeding.md §Capture System](../Markdowns/Breeding.md) as the canonical design.

When the Capture system is built (next major patch), the canonical model is:

- `ActorState` enum: WILD / RESTRAINED / CONFINED / TAMING / TAMED / FLED
- `CaptureComponent` attached to capturable actors
- `CaptureProfile` Resource (restraint resistance, escape DC curve, taming loyalty curve)
- AI FSM bridge: WILD → RESTRAINED disables roam/chase, enables drag-target behavior
- Net + Rope + Chain in `ItemsAutoload` weapon catalog as capture-tools
- `HerdManager.next_day()` must accept non-goat TAMED actors (depends on B7 above)
- `SaveComponent` schema must persist `ActorState` and restraint stack

The Mimic is not currently flagged capturable; flip `MimicData.is_capturable` (when that field is added) once the Capture system lands.

---

## 6. How The Mimic Works

**Core loop** (entirely in [MimicController.gd](../src/actors/types/MimicController.gd)):

1. On `setup(actor)`:
   - Register a continuous `TileSignalComponent` trigger of radius `mimic_data.scan_radius` (default 4 hexes) centered on the Mimic's tile.
   - Listen to `trigger_activated` / `trigger_deactivated` to maintain `_nearby_actors: Array[Actor]` symmetrically.
   - Connect to actor's `tile_changed` signal to update the trigger center as the Mimic moves.
   - Register a GameClock tick via `actor.register_tick(_on_scan_tick, mimic_data.scan_interval)` (default 0.5s = 2 Hz).
2. On each scan tick:
   - If in base form and `_nearby_actors` non-empty → pick a valid candidate (filter out self, disallowed types like `mimic`, `scarecrow`) → **morph + copy skills**.
   - If morphed and `morph_duration` elapsed → **revert to base**.
3. Bite attack is automatic: `MimicActor._equip_default_bite()` walks `ItemsAutoload.weapons` for `"Unarmed strike"` and equips it via the existing `WeaponComponent`. No new WeaponData entry needed.

**Morph behavior** ([CreatureMorphComponent.gd](../Components/ActorComponents/CreatureMorphComponent.gd) — reusable across creatures):

- `morph_into(target_actor: Actor)`: snapshot `_original_data`; call `actor.visual_component.setup_visuals(target._data)` to swap visuals via the new polymorphic dispatch.
- `revert()`: restore `_original_data` and re-apply via `setup_visuals(original)`.
- **v1.0 caveat**: visual morph is tint + scale only because `_apply_mimic_visuals()` in `ActorVisualComponent` does not yet swap meshes. Mesh-swap is gated on the Procedural Character Framework or a per-type model registry — deferred.

**Skill copy behavior** ([SkillCopyComponent.gd](../Components/ActorComponents/SkillCopyComponent.gd) — reusable across creatures):

- `copy_from(donor: Actor, limit: int)`: enumerate `donor.ability_component.actions`; for each (up to `limit`), look up the action's class in `AbilityRegistry`, and call `AbilityRegistry.instantiate_for(name, mimic_actor, mimic_ability_component)` — this creates a **fresh actor-bound clone** (AbilityAction is RefCounted + actor-bound; sharing instances would cross-wire `.actor`). Add the clone to the Mimic's own `AbilityComponent.actions` via `add_action(clone)`.
- `restore()`: remove only the copied actions (tracked by name multiset), never originals.
- Existing `AbilityComponent.execute_ability(type, value)` handles the copied actions with zero special-case code.

**Routing compliance** (verified by Agent 3 §5):
- Zero `Timer.new()` in any Mimic file.
- Zero `await get_tree().create_timer()` in any Mimic file.
- Zero per-frame distance math; all proximity decisions go through TileSignal.
- All cadence (scan tick, morph duration tracking) goes through GameClock via `Actor.register_tick()`.

**What the Mimic does NOT do** (deferred with documented gating prereqs in [Markdowns/Mimic.md](../Markdowns/Mimic.md)):

- Be captured (Capture system missing)
- Breed via `HerdManager.next_day()` (drops non-`GoatData` kids)
- Persist morph + stolen skills across save/load (transient by design; would need `SaveComponent` schema change)
- Morph into non-`*Data` actors visually (Goblin/Farmer/Fire/Water have no `*Data` resource yet — `setup_visuals(null)` no-ops)

---

## 7. Procedural Generation Hooks

This patch adds three new procedural-generation hooks consumed by the Mimic and available to any future system:

1. **`ActorFactory.spawn(actor_type: StringName, parent: Node3D, position: Vector3) -> Actor`** ([Components/Arena/ActorFactory.gd](../Components/Arena/ActorFactory.gd))
   - Input: data-keyed actor type
   - Output: instantiated Actor placed in parent at position
   - Extension point: `factory.register(StringName, PackedScene)` adds a new creature in one line
   - Currently registered: farmer, fire, water, goat, goblin, scarecrow, mimic

2. **`AbilityRegistry.instantiate_for(ability_name: StringName, actor: Node3D, component: Node) -> AbilityAction`** ([Core/AbilityRegistry.gd](../Core/AbilityRegistry.gd))
   - Input: ability name + target actor/component
   - Output: fresh per-actor `AbilityAction` instance (never shared)
   - Extension point: drop a new `class_name MyNewAbility extends AbilityAction` script into `Components/ActorComponents/AbilityComponents/` and the registry picks it up at next boot

3. **`ActorVisualComponent.setup_visuals(data: ActorData)`** ([Components/ActorComponents/ActorVisualComponent.gd:85-115](../Components/ActorComponents/ActorVisualComponent.gd))
   - Input: any `ActorData` subclass
   - Output: visuals dispatched by data type (goat → `update_goat_visuals`; mimic → `_apply_mimic_visuals`; else → no-op)
   - Extension point: add a new `if data is YourData` branch to dispatch new types

Existing procedural systems (unchanged but used by the Mimic):

- **`TileSignalComponent.register_trigger(center_tile, radius, callback, metadata)`** — the Mimic's nearby-creature scan uses this; cost scales like adding one more goblin's detection trigger
- **`GameClockComponent.register_tick(callback, interval)`** — every cadence in the Mimic system goes through here

### Seed behavior

- Goat offspring + Mimic budding both use `randf()` / `randi_range()` against the global RNG (not seeded per-event). Deterministic seeding is a follow-up via the `SeededGenerator` planned in [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md §3.1](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md).

---

## 8. Reusable Modules Created

These are intentionally creature-agnostic and portable to other Godot 4 projects:

| Module | Portable shape | Project deps |
|---|---|---|
| **`AbilityRegistry`** | Filesystem-scan registry of `RefCounted` scripts with an `ability_name` field; one-line autoload in any project | None |
| **`ActorFactory`** | `StringName → PackedScene` dispatch + `register()` + `spawn(parent, position)` | None |
| **`CreatureMorphComponent`** | Snapshot + restore visual swap via any "apply visuals from data" callable | Needs an actor with a `visual_component` exposing `setup_visuals(data)` |
| **`SkillCopyComponent`** | Per-actor RefCounted-action cloning + name-tracked restore | Needs `AbilityRegistry` + `AbilityComponent.add_action()` |
| **`MimicData`** | Template for any "procedural creature config Resource" — all `@export`, asexual `create_offspring()` model with mutation | Inherits `ActorData` |

When you copy these into another project:
- `AbilityRegistry` works as-is if your action base class exposes `ability_name`. Change the scan path constant if your folder layout differs.
- `ActorFactory` is a 40-line dispatch utility; zero changes needed.
- `CreatureMorphComponent` + `SkillCopyComponent` need an actor with a `visual_component` + `ability_component` of the conventional shape. Easiest port path: keep the project's component pattern (`Actor` with attached component children).

---

## 9. How To Extend This Later

### Add a new ability

1. Create `Components/ActorComponents/AbilityComponents/MyAbility.gd`:
   ```gdscript
   class_name MyAbility
   extends AbilityAction

   func _init(p_actor: Node3D, p_component: Node) -> void:
       super(p_actor, p_component)
       ability_name = &"My Ability"
   ```
2. The `AbilityRegistry` picks it up at next boot. MainMenu lists it (if added to a creature's allow-list); SkillCopyComponent makes it stealable by Mimic.
3. **Constraint**: keep `_init()` light — the registry probes each script with throwaway actor/component args at boot. Heavy `_init()` work (touching actor components beyond storage) will push errors to the console.

### Add a new creature type

1. Create `Components/BreedingComponents/MyCreatureData.gd` extending `ActorData` with `create_offspring()` override.
2. Create `src/actors/types/MyCreatureActor.gd` extending `Actor`, mirroring `MimicActor.gd`'s pattern (`get` accessor for typed data, `is_playable` set in `_init`, MONSTERS or appropriate faction in `_ready`).
3. Create `scenes/actors/MyCreatureActor.tscn`.
4. In `Components/Arena/ArenaSpawner._register_default_actor_types()`, add `factory.register(&"my_creature", my_creature_scene)`.
5. To enable visual morph into this creature: add `if data is MyCreatureData` branch in `ActorVisualComponent.setup_visuals()`.

### Enable breeding for a non-goat creature

This is the next major piece of work. Order:

1. Fix [HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd) to add any `ActorData` subclass, not just `GoatData`.
2. Generalize [Ranch.gd](../Components/BreedingComponents/Ranch/Ranch.gd) typed members (`selected_doe`, `selected_buck`) from `GoatData` to `ActorData`; replace `a.goat_name < b.goat_name` sort with a polymorphic `actor_data.get_display_name()` method on `ActorData`.
3. Generalize `ActorCard` to accept `actor_data: ActorData` instead of `goat_data: GoatData`.
4. Rename `UI/GoatRenderer.gd` → `UI/ActorCardRenderer.gd` and dispatch on `get_actor_type()`.
5. `BreedingComponent.breed()` for asexual creatures: add a `breed_asexual(parent)` code path (the Mimic budding model needs this).
6. Update SYNC RULE'd docs (Abilities.md / UI.md) in the same commit.

### Build the Capture system

Treat as its own multi-PR effort. The Mimic is already wired to gracefully participate once `CaptureComponent` exists — `MimicData` will gain `is_capturable` and a `CaptureProfile` reference. No Mimic code changes required if the Capture system uses the documented `ActorState` model.

---

## 10. Testing Checklist (in-editor)

Open Godot once after the patch so it re-imports the new `.gd` and `.tscn` files. Then run `Play Space/Arena.tscn` and verify:

| # | Test | Pass criterion |
|---|------|---------------|
| 1 | **Boot console clean** | No "missing file" warnings; no `[AbilityRegistry]` errors; no tick-register warnings |
| 2 | **Ranch return path** | "Finish Day" in Arena loads `Components/BreedingComponents/Ranch/Ranch.tscn` (was a dead path before) |
| 3 | **Goat selection** | Select a goat in MainMenu → enter Arena → return to Ranch → goat is still highlighted |
| 4 | **Quest camp discovery still works** | Accept a goblin quest → walk toward edge of map → camps appear at the radius-8 trigger boundary (validates SDS-7 didn't regress) |
| 5 | **Hostile AI perception still works** | Goblin chases player when player approaches; loses interest when player walks away (validates SDS-8 didn't regress) |
| 6 | **MainMenu character tab doesn't lag** | Open the character tab — should NOT see the previous reflect-and-free lag spike (validates AbilityRegistry hit) |
| 7 | **Spawn a Mimic** | Add a debug spawn `ArenaSpawner.spawn_actor_at_tile("mimic", some_tile)`; Mimic appears as violet sphere |
| 8 | **Mimic bite** | Mimic attacks adjacent enemy with damage (`WeaponComponent.weapon_data.name == "Unarmed strike"`) |
| 9 | **Mimic morph** | Place a goat within 4 hexes; within 0.5s the Mimic should tint to the goat's color and scale |
| 10 | **Mimic copy skill** | After morph, inspect Mimic's `ability_component.actions` — should contain "Headbutt Charge" |
| 11 | **Mimic revert** | After 8 seconds (default `morph_duration`), Mimic returns to violet sphere and loses the copied action |
| 12 | **No console spam** | No per-frame errors during morph or scan loop |
| 13 | **Goat breeding loop** | Pair two goats in Ranch → advance day 3 times → offspring appears in herd → save + reload → offspring persists |

Tests 9-11 are the headline "did the Extended Slice ship as promised" check.

---

## 11. Known Risks Or Deferred Work

### Caveats (NOT blockers)

| # | Item | Severity | Recommended follow-up |
|---|------|----------|------------------------|
| K1 | Mimic morph is **tint + scale only**, not mesh swap | Low | Wait for Procedural Character Framework Phase 4+; OR add a per-type model registry (PackedScene per `*Data` type) and have `_apply_mimic_visuals()` instantiate it |
| K2 | Mimic morph + copied skills are **transient** (do not persist save/load) | Low (documented) | Schema change in `Core/Managers/SaveComponent.gd` if persistence becomes a requirement |
| K3 | `Label3D` name leak after Mimic morphs into Goat and reverts | Cosmetic | One-line fix in `CreatureMorphComponent.revert()` — hide any `Label3D` child of the actor |
| K4 | `AbilityRegistry` boot probe instantiates each ability script with throwaway actor/component args | Low | Document the "keep `_init()` light" constraint in [Markdowns/Abilities.md](../Markdowns/Abilities.md); add try/catch around the probe if it becomes flaky |
| K5 | `MimicActor.tscn` root `_data` SubResource may be stripped by Godot 4.6's underscore-export-field serialization | Low | `_ready()` already falls back to instantiating default `MimicData`; verify with `print(mimic_data.aggression)` in `_ready()` to confirm which path is winning |
| K6 | Bite reach may be shorter than `ActorAIController.attack_range` (10 units) | Medium | If Mimic stands still without landing bite in attack state, add a Mimic-specific `attack_range` override; do NOT create a new WeaponData entry (per spec) |
| K7 | `MimicData.disallowed_target_types` is silently re-filled in `_init()` if empty | Low | If designers need to intentionally set `[]`, expose a `_use_defaults: bool` flag |
| K8 | `TileSystem.gd:16` still has a `Timer.new()` (out of M8/M9 scope) | Low | Different perception path; not in the Mimic loop. Can convert in a follow-up perf pass per [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md §5.4](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md) |

### Deferred work (with gating prerequisites — documented in [Markdowns/Mimic.md](../Markdowns/Mimic.md))

| Feature | Gating prereq | Reference |
|---|---|---|
| Breeding for non-goat species (Mimic, Goblin, Farmer, Fire, Water) | B7 (HerdManager generic kid acceptance) + B9-B11 (Ranch.gd + ActorCard generalization) + per-species `*Data` subclasses | Breeding.md Phases 2-4 |
| Mimic breeding | B7 + B18 (`BreedableComponent` ASEXUAL mode OR `BreedingComponent.breed_asexual()`) | Same as above |
| Capture system (any creature) | C1-C13 — `ActorState` enum + `CaptureComponent` + AI FSM bridge + save schema + Net weapon | [Agent 3 task 4.1](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md) |
| Mimic capturable | Capture system | Same |
| Mimic mesh-swap morph | Per-type PackedScene registry OR Procedural Character Framework | [Agent 3 tasks 4.7-4.9](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md) |

### Coworker rules that must continue

- All distance/proximity work routes through `TileSignalComponent` — never per-frame distance math
- All timing routes through `GameClockComponent` via `Actor.register_tick()` — never `Timer.new()` on actor-side components
- AbilityAction is RefCounted + actor-bound — never share instances across actors; always `AbilityRegistry.instantiate_for(name, target_actor, target_component)`
- SYNC RULE: update `Markdowns/Abilities.md`, `Markdowns/Actor.md`, `Markdowns/UI.md` (and now `Markdowns/Mimic.md`) in the same commit when their subject systems change
- No placeholder code, no `pass # TODO`, no "rest unchanged" patches

---

*End of coworker implementation notes.*
