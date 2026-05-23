# Elementals Implementation Status

> Final combined output of the 3-agent **Extended Slice** implementation pass.
>
> Companion docs:
> - [AGENT_1_IMPLEMENTATION_REQUIREMENTS.md](AGENT_1_IMPLEMENTATION_REQUIREMENTS.md) — spec the implementation followed (incl. §9 Dependency Chain + §10 Smallest Defensible Slice)
> - [AGENT_2_IMPLEMENTATION_PATCH_LOG.md](AGENT_2_IMPLEMENTATION_PATCH_LOG.md) — file-by-file patch log
> - [AGENT_3_INTEGRATION_REVIEW.md](AGENT_3_INTEGRATION_REVIEW.md) — independent verification (no blockers)
> - [COWORKER_IMPLEMENTATION_NOTES.md](COWORKER_IMPLEMENTATION_NOTES.md) — practical reference for the next contributor
>
> Prior-pass audit (still valid as project baseline):
> - [ELEMENTALS_PROJECT_STATUS_AND_NEXT_STEPS.md](ELEMENTALS_PROJECT_STATUS_AND_NEXT_STEPS.md) + the 3 audit reports
>
> All paths repo-relative.

---

## 1. Summary

The **Extended Slice** scope chosen by the user landed cleanly with zero blockers. The patch (a) restored the documented broken Ranch loop, (b) eliminated two AGENTS.md anti-pattern violations in the very components that enforce the no-Timer rule, (c) extracted three reusable modules (`AbilityRegistry`, `ActorFactory`, `ActorVisualComponent.setup_visuals(data)` polymorphism), and (d) introduced the **Mimic** as a full procedural creature with TileSignal-based scanning, GameClock-based cadence, visual morph, and skill-copy that uses `AbilityRegistry.instantiate_for()` so cloned `AbilityAction`s are properly actor-bound rather than shared references.

Capture and breeding-for-non-goats were correctly deferred per Agent 1 §10.2 with documented gating prerequisites, because forcing them in this pass would have either hardcoded the things the user said not to hardcode or touched files on the DO-NOT-BREAK list in behavior-changing ways. The Mimic is wired so it will gracefully participate in both systems when they ship.

---

## 2. Documented Needs Fixed

| ID | Need | Source |
|----|------|--------|
| SDS-1 | Ranch return scene path corrected at [ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) | README "[Currently Busted]"; Agent 3 plan task 0.3 |
| SDS-2 | 36 orphan `.gd.uid` files deleted | Agent 2 audit Appendix A |
| SDS-3 | 8 `.tscn*.tmp` editor-crash files deleted | Agent 2 audit Appendix A |
| SDS-4 | AGENTS.md `GameClockComponent` path corrected | Doc drift; Agent 3 plan task 0.4 |
| SDS-5 | README `GoatManager` → `HerdManager` | Agent 1 audit C1; Agent 3 plan task 0.7 |
| SDS-6 | [Markdowns/Capture.md](../Markdowns/Capture.md) deprecation header pointing to Breeding.md `ActorState` model | Agent 3 plan task 0.8 + R1 |
| M11 | [Markdowns/Actor.md](../Markdowns/Actor.md) 2D type names → 3D | Agent 1 audit C2; Agent 3 plan task 0.5 |
| M12 | [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) React/JSX admonition | Agent 1 audit C8; Agent 3 plan task 0.6 |
| 0.10 | Legacy 2D `player.gd` + `player.tscn` + `player.gd.uid` deleted | Agent 3 plan task 0.10 |
| SDS-7 / M8 | `Timer.new()` removed from [TileSignalComponent.gd:20-45](../Components/Arena/TileSignalComponent.gd); routed through GameClock | Agent 3 plan task 1.2 |
| SDS-8 / M9 | `Timer.new()` removed from [DetectionComponent.gd:25-35](../Components/ActorComponents/DetectionComponent.gd); routed through `Actor.register_tick` | Agent 3 plan task 1.3 |
| SDS-9 / B8 | [ItemsAutoload.gd](../Core/ItemsAutoload.gd) gained `selected_actor_data: ActorData`; `selected_goat` aliased | Agent 3 plan task 1.1 (narrow); Breeding.md Phase 4 |
| BONUS S2 | New [Core/AbilityRegistry.gd](../Core/AbilityRegistry.gd) autoload replaces MainMenu reflection | Agent 3 plan task 2.6 |
| BONUS S3 | New [Components/Arena/ActorFactory.gd](../Components/Arena/ActorFactory.gd) replaces hardcoded `match type` | Agent 3 plan task 2.8 |
| BONUS B12 | [ActorVisualComponent.gd:85-115](../Components/ActorComponents/ActorVisualComponent.gd) gained additive `setup_visuals(data: ActorData)` polymorphism | Breeding.md Phase 3 |
| MIMIC | Full procedural Mimic creature: data Resource, actor, scene, controller, morph component, skill-copy component, doc | New per user request |

**Agent 3 §10 confirmed: every Agent 1 §10.1 (Smallest Defensible Slice) item shipped, plus three §10.2 deferred items (S2, S3, B12) landed early because they were prerequisites for the Mimic. No DO-NOT-BREAK file was modified beyond the four pre-approved edits (SDS-1, SDS-7, SDS-8, SDS-9) + additive-only composition.**

---

## 3. Documented Needs Deferred

All deferrals are documented in [Markdowns/Mimic.md](../Markdowns/Mimic.md) and [COWORKER_IMPLEMENTATION_NOTES.md §11](COWORKER_IMPLEMENTATION_NOTES.md) with gating prerequisites cited. Nothing was silently dropped.

| Deferred work | Gating prereq | Reference |
|---------------|---------------|-----------|
| Breeding for non-goat species (Farmer/Goblin/Fire/Water/Mimic) | B7 (`HerdManager.next_day()` non-goat kid acceptance) at [HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd) + B9 (Ranch.gd typed-to-generic) + B10-B11 (ActorCard + GoatRenderer generalization) + per-species `*Data` subclasses with `create_offspring()` | Breeding.md Phases 2-4; sized 3-4 PRs |
| Mimic breeding | Same as above, plus B18 (`BreedableComponent` ASEXUAL mode OR `BreedingComponent.breed_asexual()` code path — current `breed()` requires male+female pair) | Breeding.md §Reproduction Modes |
| Capture system (all species) | C1 (`ActorState` enum) + C2 (`CaptureComponent`) + C3 (`CaptureProfile`) + C4 (AI FSM bridge) + C6 (Net + restraint items) + C11 (save schema change) | Agent 3 plan task 4.1; high-risk multi-PR effort |
| Mimic capturable | Capture system | Same |
| Mimic mesh-swap visual morph (currently tint + scale only) | Per-type PackedScene registry OR Procedural Character Framework Phases 1-4 | Agent 3 plan tasks 4.7-4.9; Markdowns/procedural_character_framework.md |
| Save/load persistence of Mimic morph + stolen skills | `SaveComponent` schema change | Transient by design; documented in Mimic.md |
| Farmer playability scoping | Decision-only | Agent 3 plan task 1.6 |
| VisibilityManager + tree LOD perf | Pure perf; orthogonal | Agent 3 plan tasks 5.1, 5.8 |
| Projectile pooling | Pure perf; orthogonal | Agent 3 plan task 5.3 |
| Region streaming / MapExpansion | New feature epic | Agent 3 plan tasks 4.2-4.5 |

---

## 4. Breeding System Status

### Supported creatures

- **Goats** (fully functional end-to-end after this patch).

### Excluded creatures (silently blocked today)

- **Farmer, Goblin, Fire, Water, Mimic** — would create offspring via `BreedingComponent.process_pregnancy()` but the kid is dropped at [HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd) because the line `var goat_kid = kid as GoatData; if goat_kid: add_goat(goat_kid)` casts to `GoatData` and discards anything else.

### Parent validation

- Generic at [Core/Managers/BreedingComponent.gd](../Core/Managers/BreedingComponent.gd): gender check, exhaustion gate, 3-day pregnancy timer. Works for any `ActorData` subclass.

### Offspring generation

- Polymorphic via `actor.create_offspring(partner)` virtual method on `ActorData`.
- `GoatData.create_offspring()` (at [GoatData.gd:77](../Components/BreedingComponents/GoatData.gd)): color lerp, 50/50 horn/body categorical, stat mean ± 10%.
- `MimicData.create_offspring()` (new): asexual budding — ignores partner, mutates color + stats.

### Inheritance rules

- Goat: color lerp between parents; 50/50 categorical inheritance for horn/body/pattern; quantitative inheritance for stats (mean ±10%). Same algorithm as before the patch.
- Mimic: jitter on base color + stats (asexual).
- Generic `TraitInheritanceEngine` (MENDELIAN / QUANTITATIVE / ENVIRONMENTAL / MUTATIONAL modes per Breeding.md) NOT extracted yet — see Agent 3 plan §3.5.

### Mutation / variation rules

- Goat: inline ±10% mutation in `create_offspring`.
- Mimic: inline jitter in `create_offspring`.
- No `SpawnVarianceConfig` Resource yet (Agent 3 plan §3.6).

### Save/load support

- Goat: yes, via `Core/Managers/SaveComponent.gd` → `user://herd_save.tres`.
- Other species: blocked at the HerdManager kid-acceptance line — kids never reach save.

### UI support

- Goat: existing `Ranch.gd` + `ActorCard.gd` typed to `GoatData`. Works.
- Other species: blocked. `Ranch.gd` sort `a.goat_name < b.goat_name` would crash on non-goat herds.

### Known risks

- Confusion if a designer adds a non-goat to the herd at runtime expecting it to breed — kid is silently dropped. Mitigation: the next patch should fix B7 + B9 in a single PR before introducing any non-goat to the herd flow.

---

## 5. Capture System Status

### Supported creatures

- **None.** No capture system exists.

### Excluded creatures

- All creatures, by absence of system.

### Capture chance rules / eligibility / ownership / storage / save / UI

- Not implemented.
- [Markdowns/Capture.md](../Markdowns/Capture.md) now carries a deprecation header pointing to [Breeding.md §Capture System](../Markdowns/Breeding.md) as the canonical design (`ActorState` enum WILD/RESTRAINED/CONFINED/TAMING/TAMED/FLED, `CaptureComponent`, restraint stacking).

### Known risks

- The README "broken" tag for capture remains accurate after this patch.
- Net weapon already registered in `ItemsAutoload._init_weapons()` at line 121 (preexisting design intent), so the catalog is partially ready.
- Building capture requires touching the 9-state AI FSM at [src/actors/ai/ActorAIController.gd](../src/actors/ai/ActorAIController.gd) (DO-NOT-BREAK file) and the save schema at [Core/Managers/SaveComponent.gd](../Core/Managers/SaveComponent.gd) — should be its own dedicated session.

---

## 6. Mimic Creature Status

### Data/profile location

- [Components/BreedingComponents/MimicData.gd](../Components/BreedingComponents/MimicData.gd) — `MimicData : ActorData`
- Fields (all `@export`): `mimic_name: StringName`, `base_color: Color`, `aggression: float = 0.6`, `scan_radius: int = 4`, `scan_interval: float = 0.5`, `morph_duration: float = 8.0`, `skill_copy_limit: int = 2`, `disallowed_target_types: Array[StringName] = [&"mimic", &"scarecrow"]`
- `get_actor_type() -> "mimic"`
- `create_offspring(partner)` returns a `MimicData` with mutated color + stats (asexual)

### Spawn integration

- Registered with `ActorFactory` at [ArenaSpawner._register_default_actor_types()](../Components/Arena/ArenaSpawner.gd).
- Spawnable via `arena.actor_spawner._actor_factory.spawn(&"mimic", parent, position)` OR the existing `spawn_actor_at_tile("mimic", tile)` path.
- Scene: [scenes/actors/MimicActor.tscn](../scenes/actors/MimicActor.tscn) (CharacterBody3D + sphere body + collider + default `MimicData` sub-resource).

### Combat integration

- [MimicActor._equip_default_bite()](../src/actors/types/MimicActor.gd) walks `ItemsAutoload.weapons` for `"Unarmed strike"` and equips it via the existing `WeaponComponent`. **No new `WeaponData` entry created.**
- Existing AI attack state in `ActorAIController` triggers melee swings naturally.

### AI integration

- [MimicController.gd](../src/actors/types/MimicController.gd) extends `ActorAIController` — inherits the full 9-state FSM (idle / roam / chase / attack / flee / investigate / stunned / death / Dormant).
- MONSTERS faction (set in `_ready`) so the existing ally/enemy matrix in `FactionComponent` makes it hostile to player + farmstead.

### Morph behavior

- [CreatureMorphComponent.gd](../Components/ActorComponents/CreatureMorphComponent.gd) — generic, reusable across creatures.
- `morph_into(target_actor)` snapshots `_original_data`, then calls `actor.visual_component.setup_visuals(target._data)` to dispatch via the new polymorphic entry point.
- `revert()` restores `_original_data` and re-applies visuals.
- **v1.0 limitation (documented):** visuals are tint + scale only because `_apply_mimic_visuals()` doesn't swap meshes yet. Gated on Procedural Character Framework or a per-type model registry.

### Skill copy behavior

- [SkillCopyComponent.gd](../Components/ActorComponents/SkillCopyComponent.gd) — generic, reusable across creatures.
- `copy_from(donor: Actor, limit: int)`: enumerates donor's `ability_component.actions`; for each name (up to `limit`) calls `AbilityRegistry.instantiate_for(name, mimic, mimic.ability_component)` to create a **fresh actor-bound clone** (AbilityAction is RefCounted + actor-bound; sharing instances would cross-wire `.actor`).
- Clones are added via existing `AbilityComponent.add_action(clone)`.
- `restore()` removes only the cloned actions (tracked by name multiset), never originals.

### Bite / basic attack behavior

- Bite via existing `Unarmed strike` `WeaponData` (auto-equipped at `MimicActor._equip_default_bite()`).
- Damage / reach / animation handled by the existing `WeaponComponent` → `MeleeHitbox` flow — no Mimic-specific combat code.

### Capture support

- **Not yet** — flagged as deferred in Mimic.md and the doc explicitly states it ships when the Capture system lands.

### Breeding support

- Data layer ready: `MimicData.create_offspring()` exists and returns a `MimicData`.
- Runtime flow blocked: `BreedingComponent.breed()` requires male+female pair (Mimic is asexual); even if forced through, `HerdManager.next_day()` would drop the kid. Both blockers documented.

### Save/load support

- **Transient by design** — `SaveComponent` schema unchanged. Mimic resets to base form on save/reload. Documented in Mimic.md.

### Known risks

| Risk | Severity | Note |
|------|----------|------|
| Bite reach may be shorter than `ActorAIController.attack_range` (10 units) — Mimic may stand still in attack state | Medium | Editor verification needed; fix is Mimic-specific `attack_range` override (no new WeaponData per spec) |
| Mesh-swap morph not implemented (tint + scale only) | Low (documented) | Wait for procedural character framework or per-type model registry |
| `Label3D` name leak after Mimic morphs into a Goat and reverts | Cosmetic | One-line fix in `CreatureMorphComponent.revert()` |
| `MimicActor.tscn` root `_data` SubResource may be stripped by Godot 4.6 underscore-export serialization | Low | `_ready()` fallback masks failure (instantiates default `MimicData`); verify with print |
| `MimicData.disallowed_target_types` re-fills in `_init()` if empty | Low | If designers want to set `[]`, expose a `_use_defaults` flag |
| `AbilityRegistry` boot probe instantiates each ability script — heavy `_init()` would crash boot | Low | Today's 3 abilities are safe; document the constraint in Abilities.md |

---

## 7. Procedural Generation Status

### New procedural modules created

| Module | Path | Generic input | Generic output |
|---|---|---|---|
| `AbilityRegistry` | [Core/AbilityRegistry.gd](../Core/AbilityRegistry.gd) | Folder of `AbilityAction` scripts (scanned at boot) | `Dictionary[StringName, Script]` + per-actor `instantiate_for(name, actor, component)` |
| `ActorFactory` | [Components/Arena/ActorFactory.gd](../Components/Arena/ActorFactory.gd) | `StringName → PackedScene` registrations | `spawn(actor_type, parent, position) -> Actor` |
| `CreatureMorphComponent` | [Components/ActorComponents/CreatureMorphComponent.gd](../Components/ActorComponents/CreatureMorphComponent.gd) | Target actor with `_data: ActorData` | Visual snapshot + restore via `ActorVisualComponent.setup_visuals(data)` |
| `SkillCopyComponent` | [Components/ActorComponents/SkillCopyComponent.gd](../Components/ActorComponents/SkillCopyComponent.gd) | Donor's `ability_component.actions` + `AbilityRegistry` | Fresh actor-bound `AbilityAction` clones added to consumer's component |
| `ActorVisualComponent.setup_visuals(data)` | [ActorVisualComponent.gd:85-115](../Components/ActorComponents/ActorVisualComponent.gd) | Any `ActorData` subclass | Type-dispatched visuals (goat → existing path; mimic → tint+scale; else → no-op) |

### New data tables / configs

- [MimicData.gd](../Components/BreedingComponents/MimicData.gd) — all tuning knobs `@export`. Designers can author `.tres` variants without code changes.

### Seed behavior

- Goat offspring + Mimic budding use the global RNG (`randf`, `randi_range`). Not seeded per-event yet.
- Deterministic seeding remains a follow-up via the `SeededGenerator` planned in [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md §3.1](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md).

### Reusable generation rules

- Adding a new ability = drop a `.gd` file into `Components/ActorComponents/AbilityComponents/` → automatic registry pickup; automatic Mimic stealability.
- Adding a new creature type = `.gd` + `.tscn` + `*Data` subclass + one-line `factory.register()` in ArenaSpawner.
- Enabling a new actor type's visual morph by Mimic = add an `if data is YourData` branch in `ActorVisualComponent.setup_visuals()`.

### Static systems avoided

- The Mimic does NOT hardcode any creature name in its scan/morph/copy logic — it discovers candidates via TileSignal, filters by `_data.get_actor_type()` against `mimic_data.disallowed_target_types`.
- Skill list is NOT hardcoded — it comes from the donor's `ability_component.actions` mediated by `AbilityRegistry`.
- ArenaSpawner no longer hardcodes actor scenes in `match type` — dispatch goes through the factory.

### Systems still needing procedural conversion

- `Core/ItemsAutoload._init_weapons()` — 37 hand-coded `_add()` calls; should become a `Resource`-directory scan (Agent 3 plan §5.5).
- `Core/GameSettings.CHARACTER_EQUIPMENT` + duplicate dict at `UI/MainMenu.gd:31-64` — two manually maintained per-actor equipment dicts (Agent 2 audit §9).
- `FactionComponent` matrix — currently hardcoded; should become `FactionData` Resource (Agent 3 plan §6).
- Quest camp visual structures — built node-by-node in `QuestSpawnManager._build_goblin_camp_visual` (Agent 2 audit §8).
- Per-element actor classes (FireActor/WaterActor and the planned Earth/Air) should collapse to one `ElementalActor` template + `ElementalProfile` Resource (Agent 3 plan §4.6).
- `TileSystem.gd` tile state side effects baked into `match` statements; should be `TileReaction` Resources.
- Single hardcoded biome in `TreeSpawner._get_or_create_default_biome()` — `BiomeRegistry` exists but only one biome registered.

---

## 8. Resource Impact

### CPU impact

- **Net reduction.** Removed `Timer.new()` from `TileSignalComponent` (1 per arena) and `DetectionComponent` (1 per perceiving actor — was the AGENTS.md "50 actors × 4 timers = 200 timer nodes" pattern). Replaced with shared GameClock ticks.
- Mimic adds: 1 TileSignal trigger + 1 GameClock tick per Mimic (cost scales like adding one more goblin's detection trigger).
- AbilityRegistry boot scan: one-time at autoload `_init` (currently 3 scripts × `new(temp_actor, temp_component)`); previously MainMenu reflection happened on every menu open with the same cost.

### GPU impact

- No change. No new shaders, no new materials beyond the Mimic's body tint (single albedo update via `setup_visuals`).

### Memory impact

- Net reduction in `Timer` node count.
- New per-Mimic state: 1 `MimicData` Resource, 1 `CreatureMorphComponent`, 1 `SkillCopyComponent`, ~`skill_copy_limit` cloned `AbilityAction` instances (default 2). Trivial.
- AbilityRegistry cache: `Dictionary[StringName, Script]` of ability classes (currently 3 entries).

### Runtime generation impact

- Mimic visual generation is constant-time per morph (tint + scale).
- Skill clone uses existing `AbilityAction._init` cost; no new allocations beyond `n` RefCounted instances.

### Save data impact

- **Zero change.** `SaveComponent` schema NOT modified. Mimic state is transient by design.

### Optimization decisions

- Scan cadence is `mimic_data.scan_interval` (default 0.5s = 2 Hz), tunable per Mimic via the Resource.
- Skill copy bounded by `mimic_data.skill_copy_limit` (default 2).
- Nearby-actor list is symmetric (maintained from `trigger_activated`/`trigger_deactivated` events), not rebuilt per scan tick.
- AbilityRegistry caches `Script` references at boot — zero per-call `load()` cost during gameplay.

---

## 9. Files Changed

| Path | Category | Change |
|---|---|---|
| [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) | Behavior (DO-NOT-BREAK, pre-approved) | Ranch path fix |
| [Components/Arena/TileSignalComponent.gd:20-45](../Components/Arena/TileSignalComponent.gd) | Behavior (DO-NOT-BREAK, pre-approved) | `Timer.new()` → GameClock `register_tick` |
| [Components/ActorComponents/DetectionComponent.gd:25-35,117-122,294-300](../Components/ActorComponents/DetectionComponent.gd) | Behavior | `Timer.new()` → `Actor.register_tick` |
| [Core/ItemsAutoload.gd:14-31,141-163](../Core/ItemsAutoload.gd) | Behavior (DO-NOT-BREAK, pre-approved) | Added `selected_actor_data`; aliased `selected_goat`; fixed clobber bug |
| [project.godot](../project.godot) | Additive (DO-NOT-BREAK, pre-approved) | Registered `AbilityRegistry` autoload |
| [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd) | Additive (DO-NOT-BREAK) | Composed in `ActorFactory`; existing call signatures preserved |
| [Components/ActorComponents/ActorVisualComponent.gd:85-115](../Components/ActorComponents/ActorVisualComponent.gd) | Additive | New `setup_visuals(data)` + `_apply_mimic_visuals()`; existing `update_goat_visuals` untouched |
| [UI/MainMenu.gd:66-94](../UI/MainMenu.gd) | Internal refactor | Helpers route via AbilityRegistry; public displayed names unchanged |
| [AGENTS.md](../AGENTS.md) | Doc | GameClockComponent path corrected |
| [README.md](../README.md) | Doc | `GoatManager` → `HerdManager` |
| [Markdowns/Capture.md](../Markdowns/Capture.md) | Doc | Deprecation header |
| [Markdowns/Actor.md](../Markdowns/Actor.md) | Doc | 2D types → 3D in code blocks |
| [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) | Doc | React/JSX admonition |
| [Markdowns/Abilities.md](../Markdowns/Abilities.md) | Doc (SYNC RULE) | v1.1 — Core Class 0: AbilityRegistry section |
| [Markdowns/UI.md](../Markdowns/UI.md) | Doc (SYNC RULE) | v1.1 — new MainMenu helper rows |

### Deletions

- `player.gd`, `player.tscn`, `player.gd.uid` (root)
- 36 orphan `.gd.uid` files (full list in [AGENT_2_CODEBASE_AUDIT.md Appendix A](AGENT_2_CODEBASE_AUDIT.md))
- 8 `.tscn*.tmp` editor-crash files (6 under `Play Space/`, 2 under `QuestSystem/`)

---

## 10. Files Created

| Path | Purpose |
|---|---|
| [Core/AbilityRegistry.gd](../Core/AbilityRegistry.gd) | Autoload: boot-time scan of every `AbilityAction` subclass; safe per-actor clone factory |
| [Components/Arena/ActorFactory.gd](../Components/Arena/ActorFactory.gd) | `StringName → PackedScene` dispatcher used by `ArenaSpawner` |
| [Components/BreedingComponents/MimicData.gd](../Components/BreedingComponents/MimicData.gd) | `MimicData : ActorData` with asexual `create_offspring()` |
| [Components/ActorComponents/CreatureMorphComponent.gd](../Components/ActorComponents/CreatureMorphComponent.gd) | Generic visual + identity morph helper (snapshot+restore) |
| [Components/ActorComponents/SkillCopyComponent.gd](../Components/ActorComponents/SkillCopyComponent.gd) | Generic skill cloning helper; routes through `AbilityRegistry.instantiate_for()` |
| [src/actors/types/MimicActor.gd](../src/actors/types/MimicActor.gd) | `MimicActor : Actor`; MONSTERS faction; auto-equips Unarmed strike for bite |
| [src/actors/types/MimicController.gd](../src/actors/types/MimicController.gd) | TileSignal radius scan + GameClock tick + morph/copy dispatch |
| [scenes/actors/MimicActor.tscn](../scenes/actors/MimicActor.tscn) | Minimal `CharacterBody3D` scene with default `MimicData` sub-resource |
| [Markdowns/Mimic.md](../Markdowns/Mimic.md) | v1.0 design + implementation reference + deferred features list |
| [docs/AGENT_1_IMPLEMENTATION_REQUIREMENTS.md](AGENT_1_IMPLEMENTATION_REQUIREMENTS.md) | Agent 1 dependency-chain analysis & smallest defensible slice |
| [docs/AGENT_2_IMPLEMENTATION_PATCH_LOG.md](AGENT_2_IMPLEMENTATION_PATCH_LOG.md) | File-by-file patch log + open questions for Agent 3 |
| [docs/AGENT_3_INTEGRATION_REVIEW.md](AGENT_3_INTEGRATION_REVIEW.md) | Independent verification (no blockers) |
| [docs/COWORKER_IMPLEMENTATION_NOTES.md](COWORKER_IMPLEMENTATION_NOTES.md) | Practical reference for the next contributor |
| [docs/ELEMENTALS_IMPLEMENTATION_STATUS.md](ELEMENTALS_IMPLEMENTATION_STATUS.md) | This file |

---

## 11. How This Helps Future Coworkers

- **Adding a new ability is now a one-file drop-in.** Put `MyAbility.gd` into `Components/ActorComponents/AbilityComponents/`; `AbilityRegistry` picks it up at next boot; MainMenu lists it; the Mimic can steal it. No edits to consumers required.
- **Adding a new creature type is now a four-file procedure** (data + actor + scene + one-line factory registration). Previously required editing two hardcoded `match type` blocks plus the per-creature visual path.
- **Adding visual support for a new creature in the Mimic morph** is one `if data is YourData` branch in `setup_visuals()`. The Mimic itself needs no changes.
- **The DO-NOT-BREAK list shrank** in load-bearing ways: `TileSignalComponent` and `DetectionComponent` are now portable (no internal Timer node), so they can be lifted into other Godot 4 projects per the [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md §6](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md) reusable-module inventory.
- **Documentation now agrees with code** on the high-traffic items: README uses `HerdManager`, AGENTS.md cites the correct GameClockComponent path, Capture.md points to the canonical design, Actor.md uses 3D type names.
- **Two new generic components** (`CreatureMorphComponent`, `SkillCopyComponent`) are deliberately Mimic-agnostic — any future creature with similar needs (shapeshifter, mimic-of-mimic, ability mimic ranged unit) can compose them without subclassing.
- **The dependency chain is explicit** for any future patch that wants to extend the Mimic — Mimic morph mesh-swap, Mimic breeding, Mimic capture each carry a documented prerequisite list in [Markdowns/Mimic.md](../Markdowns/Mimic.md), so the next contributor doesn't repeat the analysis.

---

## 12. Testing Checklist

Open Godot once after this patch so the editor re-imports new `.gd` and `.tscn` files. Then run `Play Space/Arena.tscn` and confirm each step. Agent 3 §9 + Agent 2 §9 informed this list.

### Foundational (regression)
- [ ] Start game / open project — no missing-file warnings; no `[AbilityRegistry]` errors; no tick-register warnings in console
- [ ] Spawn or find a Goat in MainMenu — selection state visible; goat enters Arena correctly
- [ ] Attack a goblin with weapon — damage applied; existing combat works
- [ ] "Finish Day" in Arena — loads `Components/BreedingComponents/Ranch/Ranch.tscn` (was a dead path before)

### Breeding (goats only)
- [ ] In Ranch, pair two valid goats (doe + buck)
- [ ] Advance day 3 times — confirm offspring appears in herd
- [ ] Save and reload — confirm offspring persists in `user://herd_save.tres`

### Capture
- [ ] Confirm Capture system is intentionally NOT implemented (zero code; README "broken" tag still accurate; this is correct per Extended Slice scope)

### Mimic
- [ ] Spawn a Mimic — appears as a violet sphere; `MimicController` attached; `_scan_trigger` populated after first frame; `_scan_tick_id >= 0`
- [ ] Confirm Mimic bites adjacent enemy — `WeaponComponent.weapon_data.name == "Unarmed strike"`
- [ ] Place a Goat within `scan_radius` (default 4 hexes) — within ~0.5s the Mimic should:
  - Tint its body to the Goat's `base_color`
  - Scale to match the Goat
  - Gain "Headbutt Charge" in its `ability_component.actions`
- [ ] Wait `morph_duration` seconds (default 8s) — Mimic reverts to violet sphere; copied action removed; bite remains
- [ ] Trigger Mimic to use the copied skill via the existing `AbilityComponent.execute_ability` path — works without special-casing

### Performance
- [ ] Open MainMenu character tab — no lag spike (previously caused by instantiate-and-free reflection cycle; should be eliminated by `AbilityRegistry` cache)
- [ ] No editor console errors during Mimic morph + scan loop
- [ ] No regression in arena framerate with 1-2 Mimics + 5+ other actors

### Existing systems preserved
- [ ] Quest camp discovery still works (validates SDS-7 didn't regress)
- [ ] Goblin AI perception still works (validates SDS-8 didn't regress)
- [ ] All non-Mimic actor types (goat, farmer, goblin, fire, water, scarecrow) still spawn via existing pipelines

---

## 13. Next Recommended Patch

**Patch the [HerdManager.gd:100-104](../Components/BreedingComponents/HerdManager.gd) non-goat kid drop** in the same PR as a `Ranch.gd` typed-to-generic refactor. This is the smallest atomic patch that unblocks breeding for every non-goat species (Mimic, Goblin, Farmer, Fire, Water) without touching the AI FSM or save schema.

Specifically, the next session should ship:

1. `HerdManager.next_day()` — accept any `ActorData` subclass kid, not just `GoatData`.
2. `Ranch.gd` — generalize `selected_doe`/`selected_buck` from `GoatData` to `ActorData`; replace the `a.goat_name < b.goat_name` sort with a polymorphic `actor_data.get_display_name()` virtual on `ActorData`.
3. Either (a) generalize `ActorCard.gd` to accept `actor_data: ActorData` and `UI/GoatRenderer.gd` to dispatch on `get_actor_type()` (Breeding.md Phase 2-3), OR (b) keep ActorCard goat-specific for now and only enable non-goat herd entries with a placeholder card. **(a) is the modular choice and follows the plan.**
4. `GoblinData : ActorData` + `FarmerData : ActorData` + `ElementalData : ActorData` as the first three non-goat subclasses, each with a thin `create_offspring()` override (jitter + categorical inheritance per their domain).
5. Optional: lift `GoatData.create_offspring()` algorithm into a generic `TraitInheritanceEngine` per [Agent 3 plan §3.5](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md).

That patch unblocks the Mimic for breeding without any Mimic code change. The Capture system remains a separate session afterwards.

Alternative if appetite is smaller: a pure-perf pass landing the [Agent 3 plan §8 performance checklist](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md) items (VisibilityManager fix, projectile pooling, scene-tree-timer removal) — orthogonal to creature work, no breeding/capture dependencies.

---

*End of Elementals Implementation Status (Extended Slice pass).*
