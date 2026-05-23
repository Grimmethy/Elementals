# Elementals Project Status and Next Steps

> **Combined output of the 3-agent audit.** This document is the executive synthesis of:
> - [AGENT_1_DOCUMENTATION_AUDIT.md](AGENT_1_DOCUMENTATION_AUDIT.md) — every `.md` file inventoried, completed/unfinished/contradictory items extracted
> - [AGENT_2_CODEBASE_AUDIT.md](AGENT_2_CODEBASE_AUDIT.md) — every code path inspected; functional / partial / broken / orphan files mapped
> - [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md) — 7-phase plan with per-task tables, modular & procedural extraction plans, patch order
>
> **Authority rule when sources disagree:** code (Agent 2) wins; the doc gets a Phase 0 hygiene task to be corrected.
>
> All paths are repo-relative.

---

## 1. Current Project Vision

**Elementals** is a Godot 4 (4.6, `gl_compatibility` renderer) hex-grid tactical combat game with an integrated creature ranching/breeding loop. Synthesized from [README.md](../README.md), [AGENTS.md](../AGENTS.md), and the [Markdowns/](../Markdowns) folder:

- Two loops: **Arena combat** on a procedurally generated hex grid with elemental tile interactions (grass / dirt / fire / water / mud / stone / height 0–3) and component-built actors (Farmer, Goat, Goblin, FireActor, WaterActor, ScarecrowDummy); and **ranch/breeding** between battles (does/bucks pair, 3-day pregnancy, traits inherit color/horn/body and stats with ±10% mutation).
- Architectural ethos: every actor is built from interchangeable components; all distance/proximity work routes through `TileSignalComponent`; all timing routes through `GameClockComponent`; all content is data-driven (`Resource` files, weighted tables, biome profiles, seeded RNG).
- Roadmap horizons: capture mechanics, Earth & Air elementals, barns and ranch buildings, region-streamed map expansion, fully procedural code-generated characters.

---

## 2. What Is Done

Confirmed by both docs (Agent 1 §3) and code (Agent 2 §2). Exact file references:

| System | Code source |
|---|---|
| Hex grid procedural world generation (noise grass/dirt + stone border + farmstead BFS + height map 0–3) | [Components/Arena/GridGenerator.gd](../Components/Arena/GridGenerator.gd) |
| `ArenaGrid` central orchestrator | [Play Space/Arena.gd](../Play%20Space/Arena.gd) (`class_name ArenaGrid`) |
| Hex tile mesh / data / state enums | [Play Space/hex_tile.gd](../Play%20Space/hex_tile.gd), [hex_tile_data.gd](../Play%20Space/hex_tile_data.gd), [tile_constants.gd](../Play%20Space/tile_constants.gd), shader at [hex_tile.gdshader](../Play%20Space/hex_tile.gdshader) |
| `TileSignalComponent` proximity hub | [Components/Arena/TileSignalComponent.gd](../Components/Arena/TileSignalComponent.gd) |
| `GameClockComponent` centralized tick bus (10Hz) | [Components/GameClockComponent.gd](../Components/GameClockComponent.gd) |
| Actor base + ~20 wired components | [src/actors/base/Actor.gd:226-337](../src/actors/base/Actor.gd) `_setup_components()` |
| AI state machine (9 states) + FactionComponent | [src/actors/ai/ActorAIController.gd](../src/actors/ai/ActorAIController.gd), [ActorStateMachine.gd](../src/actors/ai/ActorStateMachine.gd), [states/](../src/actors/ai/states), [FactionComponent.gd](../src/actors/ai/FactionComponent.gd) |
| Weapons: 37-weapon D&D catalog, melee + ranged + projectile + visuals; thrown-weapon pickup loop | [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd), [Core/WeaponData.gd](../Core/WeaponData.gd), [Components/WeaponComponents/WeaponComponent.gd](../Components/WeaponComponents/WeaponComponent.gd) and siblings |
| 3 abilities (GoatCharge, NimbleEscape, RedirectAttack) on `AbilityComponent`/`AbilityAction` framework | [Components/ActorComponents/AbilityComponents/](../Components/ActorComponents/AbilityComponents) |
| Status effects (burn, water sinking) routed through GameClock | [Components/ActorComponents/StatusEffectComponent.gd](../Components/ActorComponents/StatusEffectComponent.gd) |
| Tile state behaviors (fire spread, mud↔grass, puddle progression) | [Components/Arena/TileSystem.gd](../Components/Arena/TileSystem.gd) |
| Detection / perception (Wisdom d20, via TileSignal continuous mode) | [Components/ActorComponents/DetectionComponent.gd](../Components/ActorComponents/DetectionComponent.gd) |
| Goblin quest-camp pipeline (data-driven `quests.json`; edge-round-robin placement; visuals built on proximity discovery; 3D fire/smoke marker) | [QuestSystem/QuestSpawnManager.gd](../QuestSystem/QuestSpawnManager.gd), [QuestStarterKit.gd](../QuestSystem/QuestStarterKit.gd), [quests.json](../QuestSystem/quests.json), [CampMarkerFire/](../QuestSystem/CampMarkerFire) |
| Tree generation v2 (Resource/seed driven CSG, biome density, batched spawn) | [src/trees/TreeSpawner.gd](../src/trees/TreeSpawner.gd), [BiomeData.gd](../src/trees/BiomeData.gd), [TreeBlueprint.gd](../src/trees/TreeBlueprint.gd), [HarvestableTree.gd](../src/trees/HarvestableTree.gd), [resources/OakTree.tres](../src/trees/resources/OakTree.tres) |
| Save / Herd / Economy / Progression / Breeding manager composition | [Core/Managers/](../Core/Managers) (5 small components), composed by [Components/BreedingComponents/HerdManager.gd](../Components/BreedingComponents/HerdManager.gd) autoload |
| Breeding data layer (gender, exhaustion, 3-day pregnancy, offspring blend ±10%) | [Components/BreedingComponents/GoatData.gd:77](../Components/BreedingComponents/GoatData.gd) `create_offspring()` |
| Actor directory restructure (Phases 1–9 marked complete) | [Markdowns/FinishedProjects/ActorRefactorPlan.md](../Markdowns/FinishedProjects/ActorRefactorPlan.md) |
| UI refactor: `CycleSelector` + `MapSettingsHelper` | [Components/UI/CycleSelector.gd](../Components/UI/CycleSelector.gd), [MapSettingsHelper.gd](../Components/UI/MapSettingsHelper.gd) |

---

## 3. What Is Partially Done

| System | What works | What is missing | Reference |
|---|---|---|---|
| Breeding gameplay loop | Data layer end-to-end (BreedingComponent / GoatData.create_offspring / SaveComponent) | Player-facing loop blocked because Ranch return path is wrong (see §5) and `ItemsAutoload.selected_goat` is still goat-specific; UI not generalized to `ActorData` | Agent 2 §2.8, §3.1 |
| Ability framework | 3 concrete actions wired | `Core/Abilities/Dash.gd` exists but is not registered in `AbilityComponent.setup()`; `RedirectAttack_NEW.gd.uid` is orphan | Agent 2 §3.2 |
| Tree LOD | `HarvestableTree.switch_to_lod()` exists; LOD0 used at spawn | Nothing ever calls `switch_to_lod()`; level-2 billboard branch is `TODO` at [HarvestableTree.gd:316](../src/trees/HarvestableTree.gd); visible-tree cap unimplemented | Agent 2 §3.3 |
| Tree generation migration | New `src/trees/` system live | Old `Play Space/TreeStates/` still referenced in AGENTS.md project structure; LogPile + harvest tool wiring not done; `tree_feature.tscn` deleted but 6 `.tmp` leftovers remain | Agent 1 §10 P3; Agent 2 §5.1 |
| Status effects | Burn + water sinking | Mud / slow handled separately in [TerrainSpeedModifierComponent.gd](../Components/ActorComponents/TerrainSpeedModifierComponent.gd); no unified effect framework | Agent 2 §3.4 |
| Breeding refactor toward actor-agnostic | Phase 1 done (HerdManager rename, GoatData uses ActorData) | Phases 2–5 still TODO: generic ActorCard, ActorCardRenderer rename, generic signals (`selected_actor_data`), `ActorFactory` | Agent 1 §10 P1 items 5–9 |
| UI refactor | CycleSelector + MapSettingsHelper complete | Debug-settings autoload pending; PlayerConsole panel split pending; optional MainMenu scene restructure | [Markdowns/UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) |

---

## 4. What Is Missing

Documented but **zero implementation in code** (Agent 2 §4; cross-checked against Agent 1 P0–P7 checklist):

| Missing system | Doc source | Why it matters |
|---|---|---|
| Capture system (`CaptureComponent`, `ActorState` enum WILD/RESTRAINED/CONFINED/TAMING/TAMED/FLED, restraint stacking, escape DC, drag) | [Markdowns/Capture.md](../Markdowns/Capture.md), [Markdowns/Breeding.md](../Markdowns/Breeding.md) | README P0 ("capture mechanics broken"); blocks wild-creature acquisition |
| `TraitInheritanceEngine` (Mendelian / quantitative / environmental / mutational) | [Markdowns/Breeding.md](../Markdowns/Breeding.md) | Unblocks Goblin/Elemental/Mimic breeding |
| `GoblinData`, `ElementalData` (ActorData subclasses) | [Markdowns/Breeding.md](../Markdowns/Breeding.md) | Prerequisite for non-goat herds |
| `BreedableComponent`, `SpawnVarianceConfig` | [Markdowns/Breeding.md](../Markdowns/Breeding.md) | Stat variance for spawned creatures |
| Map Expansion: `RegionData`, `RegionManager`, `EdgeProfile` (mountain/ocean/gate), edge-to-edge rivers, region streaming + LRU cache, quest-driven wall destruction, `RoadGenerator` (primary + dead-end + building-access) | [Markdowns/MapExpansion.md](../Markdowns/MapExpansion.md) | Currently only one fixed circular arena with stone wall |
| Procedural Character Framework — entire 12-phase plan (`CreatureDefinition`, `LimbBuilder`, `TorsoBuilder`, `HeadBuilder`, `ShapeAssembler`, `SkeletonInferer`, `CharacterDesignerDock`, `DefinitionSerializer`, `CreatureGizmoPlugin`, `LocomotionSystem`, `SecondaryMotion`, `BehaviourLayer`, IK rig) | [Markdowns/procedural_character_framework.md](../Markdowns/procedural_character_framework.md) | "Status: Design Phase" — no runtime exists |
| Earth & Air elementals + new tile reactions | [README.md](../README.md) roadmap | Only Fire and Water actor types exist |
| Barns + additional ranch buildings | [README.md](../README.md) roadmap | Only house + fences are generated |
| `VisibilityManager` design intent (AABB-based occlusion with lerped opacity, occlusion-driven foliage transparency for player and spotted enemies) | [Markdowns/TreeGeneration.md](../Markdowns/TreeGeneration.md) §16 | The autoload at [src/trees/VisibilityManager.gd](../src/trees/VisibilityManager.gd) is a runtime hot spot, not the design's spec |

**Excluded from scope** (Agent 1 §9.1 C8, Agent 2 §4.2): [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) describes a React/JSX webapp and is **not** implementable in this Godot repo.

---

## 5. What Is Broken or Risky

### 5.1 Hard breaks confirmed in code

| Symptom | Code source | Notes |
|---|---|---|
| **Ranch return from Arena is broken** | [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) calls `change_scene_to_file("res://Ranch/Ranch.tscn")` which does not exist | Real path: `Components/BreedingComponents/Ranch/Ranch.tscn` (correctly used by [UI/MainMenu.gd:281](../UI/MainMenu.gd)). One-line fix. |
| **Capture mechanics broken** | Zero implementation — no `CaptureComponent`, no `ActorState`, no `RESTRAINED`/`CONFINED` anywhere | Agent 2 §4.1 confirmed via Grep |
| **Breeding gameplay loop broken** | Data layer works; user-visible loop blocked by Ranch return + goat-specific selection bus | Agent 2 §3.1 |

### 5.2 AGENTS.md anti-pattern violations (rule violations of the project's own contract)

| Violation | Location | Why it's risky |
|---|---|---|
| `Timer.new()` inside `TileSignalComponent` itself | [Components/Arena/TileSignalComponent.gd:20-25](../Components/Arena/TileSignalComponent.gd) | The component AGENTS.md singles out as the proximity authority violates the "no Timer nodes" rule |
| `Timer.new()` per-actor in `DetectionComponent` | [Components/ActorComponents/DetectionComponent.gd:107-112](../Components/ActorComponents/DetectionComponent.gd) | Exactly the "50 actors × 4 timers = 200 Timer nodes" pattern AGENTS.md forbids |
| `Timer.new()` in `TileSystem` | [Components/Arena/TileSystem.gd:16-19](../Components/Arena/TileSystem.gd) | One-shot scheduling but still bypasses GameClock |
| 6 ad-hoc `get_tree().create_timer()` awaits | [QuestSpawnManager.gd:230,361](../QuestSystem/QuestSpawnManager.gd), [ArenaUIHandler.gd:115](../Components/Arena/ArenaUIHandler.gd), [CommunicationComponent.gd:109](../Components/ActorComponents/CommunicationComponent.gd), [MovementComponent.gd:275](../Components/ActorComponents/MovementComponent.gd), [NimbleEscape.gd:96](../Components/ActorComponents/AbilityComponents/NimbleEscape.gd), [LobProjectile.gd:75](../src/actors/projectiles/LobProjectile.gd) | Some inside `for` loops (one SceneTreeTimer per goblin per camp) |

### 5.3 Filesystem rot (Agent 2 §5, Appendix A)

- **30+ orphan `.uid` files** with no `.gd` companion — most under root, `Core/`, `Components/`, `Components/Arena/`, `Components/ActorComponents/`, `Experimental/`, `tests/`, `test/`, `UI/`. Examples: `Core/Weapon.gd.uid`, `Core/WeaponLibrary.gd.uid`, `Core/WeaponManager.gd.uid`, `Core/Weapon_OLD.gd.uid`, `Components/Arena/ActorSpawnerComponent.gd.uid` (real class renamed to `ArenaSpawnerComponent`), `Components/Arena/MinimapHandler.gd.uid` (real class renamed to `ArenaMinimapHandler`), `RedirectAttack_NEW.gd.uid`, `UI/RanchUI.gd.uid`, and root `test_*.gd.uid` orphans (only [test_fire_spread.gd](../test_fire_spread.gd) is a live test).
- **8 editor-crash `.tmp` leftovers**: 6 `Play Space/tree_feature.tscn*.tmp` + 2 `QuestSystem/QuestTrackerHUD.tscn*.tmp`.
- **Legacy 2D scripts**: [player.gd](../player.gd) + [player.tscn](../player.tscn) are `CharacterBody2D` leftovers, unreferenced.

### 5.4 Doc/code drift

- [AGENTS.md:87](../AGENTS.md) cites `res://Components/Arena/GameClockComponent.gd` — real path is [Components/GameClockComponent.gd](../Components/GameClockComponent.gd).
- README still says `GoatManager`; the autoload is now `HerdManager` (renamed 2025-01-28 per [Markdowns/Breeding.md](../Markdowns/Breeding.md)).
- [Markdowns/Actor.md](../Markdowns/Actor.md) declares `Actor extends CharacterBody2D` and uses `Vector2`; every other doc and all code is 3D.
- [Markdowns/Capture.md](../Markdowns/Capture.md) and [Markdowns/Breeding.md](../Markdowns/Breeding.md) describe two **incompatible** capture APIs (loyalty + items vs `ActorState` + restraint stacking). Agent 3 resolves: adopt Breeding.md `ActorState`.
- [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) is for a React/JSX project, sitting inside a Godot repo's `Markdowns/`.

### 5.5 Fragile dependencies (do not break)

- `QuestStarterKit._ensure_tile_signal_component` uses string-name check against the `TileSignalComponent` Arena already adds (Agent 2 §5.6). Works today; will silently double-add on any node rename.
- `ArenaSpawner` preloads all 6 actor scenes via hardcoded paths (Agent 2 §5.7) — works but blocks the planned `ActorFactory` pattern.

### 5.6 Performance risks (Agent 2 §10) — see §14 for the full list

- [src/trees/VisibilityManager.gd](../src/trees/VisibilityManager.gd) is the single biggest hot spot: per-frame, per-foliage normalize/dot/unproject/FOV/AABB/lerp on **two** unbounded loops, plus debug prints leak in release builds via `if randf() < 0.01` with no `OS.is_debug_build()` gate.
- No projectile pooling — [ProjectileComponent.gd:82-91](../Components/WeaponComponents/ProjectileComponent.gd) instantiates 5 scenes per spread/lob shot.
- [Core/ItemsAutoload.gd:27-66](../Core/ItemsAutoload.gd) does 40+ synchronous `load()` calls at autoload boot.

---

## 6. Modular Systems Already Present

Already isolated enough to lift with minimal coupling (Agent 2 §6):

- **`GameClockComponent`** — ~70 LOC, no project deps once Phase 1 anti-pattern fixes land
- **`TileSignalComponent`** — single assumption (`axial_coords` on tile data); already 6 consumers
- **`FactionComponent`** — cached ally/enemy with a simple enum
- **`AbilityAction` + `AbilityComponent`** pair (RefCounted, actor-agnostic)
- **`HealthBarPool`** — already a proper pool
- **`SaveComponent`** — deferred ResourceSaver with coalescing
- **`TreeBlueprint` + `HarvestableTree`** — Resource-driven CSG, project deps limited to `HealthComponent`
- **`BiomeData` + `TreeSpawner`** — generic seeded weighted-pool spawner
- **`StatusEffectComponent`** — tick-driven buff/debuff model (currently burn + water only)
- **`CycleSelector` / `StationaryCycler`** ([Components/UI/CycleSelector.gd](../Components/UI/CycleSelector.gd))
- **`MapSettingsHelper`** ([Components/UI/MapSettingsHelper.gd](../Components/UI/MapSettingsHelper.gd))
- **`UIStyle`** ([UI/UIStyle.gd](../UI/UIStyle.gd))
- **`DisplayCardBase`** ([UI/DisplayCard/](../UI/DisplayCard))

---

## 7. Modular Systems That Should Be Created

Lift these into reusable, portable shapes (Agent 3 §3 + §6):

| Module | Source code to extract from | Portable shape |
|---|---|---|
| `NodePool<T>` | from `HealthBarPool.gd` | `NodePool.new(scene, max, on_acquire, on_release)`; `acquire()` / `release()` |
| `ResourceSaveStore` | from `SaveComponent.gd` | `ResourceSaveStore.new(path, debounce_ms)`; `save(resource)` / `load() -> Resource` |
| `ScenePaths` | new `Core/ScenePaths.gd` | Project-local `const` strings; replaces literal scene-change paths |
| `AbilityRegistry` | from `UI/MainMenu.gd:67-100` reflection | Filesystem-scan registry at boot, `{name: PackedScript}` |
| `ActorFactory` | extracted from `Components/Arena/ArenaSpawner.gd` `match type` | `register(actor_type, scene)` + `spawn(actor_data, position) -> Actor` |
| `ActorCard` (generic) + `ActorCardRenderer` | rename of `UI/GoatRenderer.gd`, generalize `UI/DisplayCard/ActorCard.gd` | Card consumes any `ActorData`; renderer dispatches on `get_actor_type()` |
| `WeaponListPanel` / `CardDisplayPanel` | split from `UI/PlayerConsole.gd` | Each is a self-contained `Control` with own signals |
| `DebugSettings` namespace within `GameSettings` | extension of `Core/GameSettings.gd` | Persisted debug toggles |

---

## 8. Procedural Systems Already Present

Confirmed in code (Agent 2 §7):

- **Hex world generation** — `FastNoiseLite` seeded by `GameSettings.noise_seed`, grass/dirt threshold, radial stone border, quantized height 0–3 ([GridGenerator.gd:46-91](../Components/Arena/GridGenerator.gd))
- **Farmstead planning** — BFS flood-fill with shuffled neighbors, deterministic given seed ([GridGenerator.gd plan_farmstead()](../Components/Arena/GridGenerator.gd))
- **Biome-driven tree spawning** — `BiomeData.distance_multipliers` interpolated by hex distance, `tree_blueprints` weighted pool, seeded `_rng` ([TreeSpawner.gd:30-46](../src/trees/TreeSpawner.gd))
- **Procedural tree geometry** — per-tree trunk segments / branches / foliage from blueprint params ([TreeBlueprint.gd](../src/trees/TreeBlueprint.gd))
- **Goat genetic inheritance** — color lerp / 50/50 categorical / stat mean ±10% ([GoatData.create_offspring()](../Components/BreedingComponents/GoatData.gd))
- **Wild goat randomization** — random color/pattern/horn/body, randomized stats and gold ([ArenaSpawner._make_random_goat_data():296-310](../Components/Arena/ArenaSpawner.gd))
- **Quest camp placement** — edge-round-robin with spacing constraint ([QuestSpawnManager.gd:49-140](../QuestSystem/QuestSpawnManager.gd))
- **Tile state transitions** — fire spread, mud↔grass, puddle→mud ([TileSystem.gd](../Components/Arena/TileSystem.gd))
- **Ability assignment for goblins** — 50/50 RNG between NimbleEscape and RedirectAttack at component setup
- **Goat name table** (small static — see §10)

---

## 9. Procedural Systems That Should Be Created

Lift / build these as reusable seeded modules (Agent 3 §4 + §7):

| Generator | Schema sketch | Output | Replaces / unlocks |
|---|---|---|---|
| `SeededGenerator` (base) | `seed: int`; `child_rng(salt) -> RandomNumberGenerator` | Sub-stream RNGs | Foundation for all below |
| `WeightedPoolSpawner<T>` | `WeightedEntry { weight, payload }`; `PlacementRule { can_place(tile, neighbors); weight_at(tile) }` | Array of placed payloads | Generalizes `TreeSpawner` for loot, props, enemies |
| `TerrainProfile` | `noise: FastNoiseLite; dirt_threshold; height_levels; height_curve; biome_id` | Tile-type + height per coord | Lets MapExpansion fork biomes without forking GridGenerator |
| `FloodFillRegionPlanner` | `plan(origin, target_size, neighbor_fn, can_include_fn, rng) -> Array[Vector2i]` | Region tile set | Generalizes farmstead planner for towns, dungeon rooms, biome islands |
| `TraitInheritanceEngine` | `TraitSchema { traits: Array[TraitDef] }`; modes MENDELIAN / QUANTITATIVE / ENVIRONMENTAL / MUTATIONAL | Offspring `ActorData` | Lifts `GoatData.create_offspring()` to actor-agnostic |
| `SpawnVarianceConfig` | `distribution: UNIFORM/GAUSSIAN/BOUNDED; per_stat_overrides` | Randomized stat block | Replaces ad-hoc variance in `_make_random_goat_data` |
| `RegionData` + `EdgeProfile` | `RegionData { id; size; terrain_profile; edges; biome_id }`; `EdgeProfile { type: STONE/MOUNTAIN/OCEAN/GATE; gate_unlock_quest_id }` | Complete region instance | Foundation for MapExpansion |
| `RoadProfile` + `RoadGenerator` | `RoadProfile { primary_count; dead_end_chance; building_access }` | `Array[Vector2i]` road tiles | A* hex pathfinding per region |
| `CreatureDefinition` (Procedural Character Framework Phase 1) | body proportions, color palette, `detail_level` enum | Input for LimbBuilder + downstream | Foundation for procedural creatures |
| `ElementalProfile` | `element: StringName; tile_reactions: Array[TileReaction]; projectile_scene: PackedScene` | Configured elemental actor | Lets Earth/Air be data, not new classes |
| `CaptureProfile` | `restraint_resistance; escape_dc_per_restraint: Curve; taming_loyalty_curve: Curve; flee_chance_after_break` | Capture/taming behavior per actor | Foundation for Capture system (4.1) |
| `BuildingProfile` | `footprint: Vector2i; required_tiles: Array[TileType]; interaction_component: PackedScene` | Placed ranch building | Foundation for barns + other buildings |

---

## 10. Static or Manual Systems That Should Become Procedural

Code-level observations (Agent 2 §9):

- **Weapon catalog** — [Core/ItemsAutoload.gd:26-110](../Core/ItemsAutoload.gd) hardcodes 37 `_add()` calls with timestamped icon paths (e.g. `club_icon_frame_0_1776824494.png`). Should become a `Core/Weapons/*.tres` directory scan.
- **`GameSettings.CHARACTER_EQUIPMENT`** ([Core/GameSettings.gd:21-52](../Core/GameSettings.gd)) and a **duplicate** dictionary in [UI/MainMenu.gd:31-64](../UI/MainMenu.gd) — two manually maintained per-actor equipment dicts. Several names (Pitchfork, Shovel, Headbutt, Flame Burst, Water Jet) don't even have matching WeaponData entries.
- **Faction relationships** — [FactionComponent.gd:48-69](../src/actors/ai/FactionComponent.gd) hardcodes only PLAYER↔FARMSTEAD ally pair; should become a `FactionData` Resource.
- **Quest camp structures** — `_build_goblin_camp_visual()` builds rocks/tents/banners/markers from raw `BoxMesh`/`CylinderMesh`. Should be PackedScene-driven (and itself reusable via `BuildingProfile`).
- **Per-element actor classes** (Fire/Water/Earth/Air planned) — should collapse to one `ElementalActor` template + `ElementalProfile` Resource.
- **GoatActor terrain speed multipliers** hardcoded at [GoatActor.gd:43-49](../src/actors/types/GoatActor.gd) — should be per-creature data.
- **Tile state side effects** — fire/mud/puddle progression baked into `TileSystem.gd` `match` statements; should be data-defined (`TileReaction` Resource).
- **Single hardcoded biome** at [TreeSpawner.gd:227-242](../src/trees/TreeSpawner.gd) `_get_or_create_default_biome()` — `BiomeRegistry` exists but only one biome registered.
- **MainMenu ability introspection** ([UI/MainMenu.gd:67-100](../UI/MainMenu.gd)) does instantiate-and-`free()` cycles every menu open just to read `ability_name`. Replace with `AbilityRegistry` autoload that scans once on boot.
- **Goat name table** ([ArenaSpawner.gd:312-316](../Components/Arena/ArenaSpawner.gd)) — small static array; should be a `Resource` table.

---

## 11. Documentation Conflicts

Material conflicts that must be resolved before Phase 4 work begins (Agent 1 §9):

| # | Conflict | Resolution per Agent 3 |
|---|----------|------------------------|
| C1 | README says "`GoatManager` orchestrates"; code & Breeding.md say `HerdManager` | README is stale — Phase 0.7 patches it |
| C2 | [Actor.md](../Markdowns/Actor.md) declares `CharacterBody2D` + `Vector2`; everything else is 3D | Actor.md is stale — Phase 0.5 rewrites it to 3D |
| C3 | Actor.md, AGENTS.md, and UI.md disagree on the component list on `Actor` | Code wins (`_setup_components()` at [Actor.gd:226-337](../src/actors/base/Actor.gd)); reconcile docs Phase 6 |
| C4 | Actor.md uses `try_activate_ability()`; Abilities.md uses `execute_ability(type, value)` | Abilities.md matches code |
| C5 | [Breeding.md](../Markdowns/Breeding.md) interleaves "Old Plan (Abandoned)" with the current actor-agnostic plan | Delete the abandoned plan section Phase 0 |
| C6 | Breeding.md alternately says `BreedableComponent` is "not needed" and uses it in code samples | Resolve to "not needed for Phase 1"; revisit in Phase 4 |
| C7 + D5 | [Capture.md](../Markdowns/Capture.md) (loyalty + items) vs Breeding.md `ActorState` (restraint stacking) | Adopt **Breeding.md `ActorState`** as canonical; Capture.md becomes deprecated header (Phase 0.8) |
| C8 | [SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) is a React/JSX webapp plan, not Godot | Annotate "Not part of this repo" or move to `Markdowns/ExternalProjects/` (Phase 0.6) |
| C10 | TreeGeneration.md marks `TreeStates/` for removal; AGENTS.md still lists it | Code system is `src/trees/`; delete old folder + update AGENTS.md (Phase 4.11 + 6.2) |
| C13 | Path discussion (`Components/ActorComponents/`) is scattered across AGENTS.md, Actor.md, ActorRefactorPlan.md | Consolidate Phase 6 |
| D1 | Ziva README appears twice ([addons/ziva_agent/README.md](../addons/ziva_agent/README.md), [addons/.ziva_update_staging/addons/ziva_agent/README.md](../addons/.ziva_update_staging/addons/ziva_agent/README.md)) | Delete the staging copy (Phase 6.3) |
| Path drift | AGENTS.md cites `Components/Arena/GameClockComponent.gd`; real path is `Components/GameClockComponent.gd` | Patch AGENTS.md (Phase 0.4) |

---

## 12. Recommended Patch Order

From Agent 3 §5 — the safest sequence that avoids regressions:

1. **Entire Phase 0** first (Safety + Source-of-Truth Cleanup). Behavior changes only via the one-line Ranch path fix (0.3); all else is hygiene.
2. **Phase 1.1** (breeding loop generic) before Phase 2.7 / 2.8 / 2.9 — they consume the `selected_actor_data` rename.
3. **Phase 1.2 + 1.3 + 1.5** (Timer-node anti-pattern fixes + QuestStarterKit guard) before Phase 2.1 / 2.2 — don't extract a module that violates its own contract.
4. **Phase 2.1** (GameClock module promotion) before any Phase 5 task that uses `register_tick()` at a new site.
5. **Phase 2.3** (NodePool) before Phase 5.3 (projectile pooling).
6. **Phase 3.1** (SeededGenerator) before Phase 3.2 (WeightedPoolSpawner) and Phase 3.3 (TerrainProfile).
7. **Phase 2.8** (ActorFactory) before Phase 4.1 (Capture), 4.6 (Earth/Air elementals), 4.7+ (Procedural Creatures).
8. **Phase 3.5** (TraitInheritanceEngine) before Phase 4.6 + 4.1.
9. **Phase 3.3 + 3.4** (TerrainProfile, FloodFillRegionPlanner) before Phase 4.2 (RegionData).
10. **Phase 4.2** (RegionData) before Phase 4.3 / 4.4 / 4.5 (edge variations, quest-gate unlock, RoadGenerator).
11. **Phase 5** lands incrementally after Phase 1, in parallel with Phase 4. Specific dependencies: 5.2 needs 2.1; 5.3 needs 2.3; 5.4 needs 2.1 `wait()` helper; 5.6 needs 1.2; 5.8 needs 5.1 first.
12. **Phase 6** (docs, tests, READMEs) runs alongside each phase, not after — SYNC RULE.

**Hard "do not break" gates** (Agent 2 §11): any change to [project.godot](../project.godot), [Play Space/Arena.gd](../Play%20Space/Arena.gd), [Play Space/Arena.tscn](../Play%20Space/Arena.tscn), [src/actors/base/Actor.gd](../src/actors/base/Actor.gd), [Components/GameClockComponent.gd](../Components/GameClockComponent.gd), [Components/Arena/TileSignalComponent.gd](../Components/Arena/TileSignalComponent.gd), [Components/Arena/GridGenerator.gd](../Components/Arena/GridGenerator.gd), [Core/GameEvents.gd](../Core/GameEvents.gd), [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd), [Core/WeaponData.gd](../Core/WeaponData.gd), or [UI/MainMenu.tscn](../UI/MainMenu.tscn) **requires the relevant phase's acceptance test to pass before merge**.

---

## 13. Procedural Generation and Low-Resource Compliance

**Is the project still following the procedural-first goal?** Mostly yes, with two important caveats:

**Yes — the procedural foundation is intact**:
- World generation, tree generation, breeding inheritance, quest camp placement, and goat randomization are all seeded and data-driven.
- The architecture documents (AGENTS.md, TreeGeneration.md, MapExpansion.md, procedural_character_framework.md, Breeding.md) all push toward "more procedural, more data-driven".
- The `Resource`-based content pattern (BiomeData, TreeBlueprint, WeaponData) is well-established.

**Caveats**:
1. **Several catalogs are static** (Weapons in ItemsAutoload, CHARACTER_EQUIPMENT in GameSettings + MainMenu, faction matrix, quest camp visual structure, hardcoded element actor classes, single biome). These should become Resource-directory scans + data tables — see §10.
2. **Performance compliance is uneven** — VisibilityManager, the multiple Timer anti-patterns, and the absence of projectile pooling violate AGENTS.md's stated low-resource rules.

**Systems already procedural that should stay procedural**: hex world gen, height map, farmstead planner, tree spawning, tree geometry, biome data, quest camp placement, goat inheritance, tile state transitions.

**New systems that should be generated, not authored**: capture profiles, elemental profiles, building profiles, weapon catalog, faction relationships, region data, edge profiles, road profiles, trait schemas, spawn variance configs, creature definitions, ability registry.

**Static systems that should be converted**: see §10 in full.

**Performance risks**: see §14.

**Suggested optimizations** (Agent 3 §8 checklist):
- Timer-node removal in `TileSignalComponent` + `DetectionComponent` (Phase 1.2 / 1.3)
- VisibilityManager debug-print gate + frame budget (Phase 5.1)
- AbilityComponent + HarvestableTree `_process` → GameClock (Phase 5.2)
- Projectile pooling via `NodePool` (Phase 5.3)
- `SceneTreeTimer` removal at 6 sites (Phase 5.4)
- ItemsAutoload lazy + Resource scan (Phase 5.5)
- Arena static-obstacle batched trigger registration (Phase 5.6)
- GoatActor double-iteration cache (Phase 5.7)
- Tree LOD wiring + visible-tree cap (Phase 5.8)
- Spatial-hash cache for `get_tile_data_at_world_position` (Phase 5.9)
- Minimap throttle moved to GameClock 5Hz (Phase 5.10)

**Reusable procedural modules to share with other projects** (Agent 3 §7):
`SeededGenerator`, `WeightedPoolSpawner<T>`, `TerrainProfile`, `FloodFillRegionPlanner`, `TraitInheritanceEngine`, `SpawnVarianceConfig`, `RegionData`+`EdgeProfile`, `RoadProfile`+`RoadGenerator`, `CreatureDefinition`, `BiomeData`.

**Recommended procedural patch order**: 3.1 (Seeded base) → 3.2 (WeightedPool) → 3.3 (TerrainProfile) + 3.4 (FloodFill) in parallel → 3.5 (TraitInheritance) + 3.6 (SpawnVariance) in parallel → 4.2 (RegionData composes 3.3+3.4) → 4.3/4.4/4.5 (edges, gates, roads).

---

## 14. Performance and Resource Impact

Synthesized from Agent 2 §10 + Agent 3 Phase 5:

### CPU risks
- [src/trees/VisibilityManager.gd](../src/trees/VisibilityManager.gd) `_process` runs **two unbounded loops** per frame over all registered foliage nodes, each doing normalize / dot / `unproject_position` / FOV / AABB / lerp. Scales linearly with tree count.
- [Components/ActorComponents/AbilityComponents/AbilityComponent.gd:52-54](../Components/ActorComponents/AbilityComponents/AbilityComponent.gd) `_process` iterates all actions every frame on every actor.
- [src/trees/HarvestableTree.gd:182-194](../src/trees/HarvestableTree.gd) `_process` runs for every standing tree, even with no actor harvesting.
- [src/actors/types/GoatActor.gd:99-111](../src/actors/types/GoatActor.gd) iterates `ability_component.actions` twice per physics tick.
- [Play Space/Arena.gd:363-384](../Play%20Space/Arena.gd) `_register_static_obstacles` registers radius-2 trigger per obstacle; `TileSignalComponent._on_actor_tile_changed` iterates **all** triggers on every actor tile change.

### GPU risks
- VisibilityManager debug prints every few frames (`if randf() < 0.01`) — minor, but no `OS.is_debug_build()` gate.
- Tree CSG never baked to MeshInstance3D (TreeGeneration.md §13.1 recommends baking for production).
- Tree LOD never wired (Agent 2 §3.3, Phase 5.8).
- No visible-tree cap (TreeGeneration.md §13.4 recommends ~200).

### Memory risks
- N `Timer` nodes proliferate per actor in [DetectionComponent.gd](../Components/ActorComponents/DetectionComponent.gd) (anti-pattern violation).
- Every projectile lob/spread allocates 5 fresh PackedScene instances ([ProjectileComponent.gd:82-91](../Components/WeaponComponents/ProjectileComponent.gd)).
- [Core/ItemsAutoload.gd:27-66](../Core/ItemsAutoload.gd) loads 40+ resources synchronously at boot.

### Runtime generation risks
- All tree CSG generation happens at first arena load (batched at 10/frame per [TreeSpawner.gd](../src/trees/TreeSpawner.gd) — good); no caching of generated meshes across regions (problem when MapExpansion lands).
- Single arena today, but region streaming will need off-main-thread generation per MapExpansion.md §6.

### Loading / streaming risks
- ItemsAutoload boot cost (40+ synchronous `load()` calls).
- No region streaming or LRU cache yet — future risk for MapExpansion.

### Object count risks
- 6 ad-hoc `SceneTreeTimer` sites (Agent 2 §10.4); two are inside loops (`QuestSpawnManager.gd:230,361`) creating one timer per goblin per camp.
- Per-foliage registration in VisibilityManager scales with trees.
- Per-actor Timer in DetectionComponent.

### Scene size risks
- [QuestSystem/QuestSpawnManager.gd](../QuestSystem/QuestSpawnManager.gd) at 1139 LOC is too large; needs split (Agent 2 §8).
- Camp visuals built node-by-node from primitives rather than PackedScene templates.

### Suggested pooling / caching / chunking / LOD / culling / batching fixes
- **Pooling**: extract `NodePool<T>` from `HealthBarPool` (Phase 2.3); pool projectiles + camp visuals (Phase 5.3).
- **Caching**: spatial-hash cache for `Arena.get_tile_data_at_world_position` (Phase 5.9); LRU cache for region data (Phase 4.2).
- **Chunking**: chunk VisibilityManager scan into N foliage entries per frame, round-robin (Phase 5.1); region streaming in chunks (Phase 4.2).
- **LOD**: wire `HarvestableTree.switch_to_lod()` via a `TreeLODController` driven by camera tile via TileSignal continuous mode (Phase 5.8).
- **Culling**: hard cap ~200 visible trees per TreeGeneration.md §13.4 (Phase 5.8).
- **Batching**: group static obstacle triggers into a single composite (Phase 5.6); batch tree spawn already at 10/frame (preserve through Phase 3.2 refactor).

---

## 15. Next 10 Tasks

From Agent 3 §10. All are Phase 0 or Phase 1; each has the lowest blast radius for its expected payoff.

### 1. Fix Ranch return scene path (Phase 0.3)
- **Goal**: Restore the documented Ranch loop.
- **Files**: [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd)
- **Why now**: Literal cause of the README "[Currently Busted]" tag. Single-line fix.
- **Risk**: Low
- **Procedural / data-driven approach**: Replace the literal with `ScenePaths.RANCH` once Phase 2.5 lands; for now, use the correct literal `res://Components/BreedingComponents/Ranch/Ranch.tscn` (matches [UI/MainMenu.gd:281](../UI/MainMenu.gd)).
- **Resource impact**: None.
- **Acceptance test**: After clearing an arena, the "Return to Ranch" button loads the Ranch scene without error.

### 2. Delete 30+ orphan `.uid` files (Phase 0.1)
- **Goal**: Remove long-standing refactor rot.
- **Files**: Root, `Core/`, `Components/`, `Components/Arena/`, `Components/ActorComponents/`, `Experimental/`, `tests/`, `test/`, `UI/` orphans (full list in Agent 2 §5.3 + Appendix A).
- **Why now**: Deletion-only, no behavior change.
- **Risk**: Low
- **Procedural / data-driven approach**: N/A (deletion).
- **Resource impact**: None.
- **Acceptance test**: Project opens in Godot without "UID broken" warnings on fresh import.

### 3. Delete 8 editor-crash `.tmp` files (Phase 0.2)
- **Goal**: Remove Godot editor autosave leftovers.
- **Files**: 6 `Play Space/tree_feature.tscn*.tmp` + 2 `QuestSystem/QuestTrackerHUD.tscn*.tmp`.
- **Why now**: Deletion-only.
- **Risk**: Low
- **Procedural / data-driven approach**: N/A.
- **Resource impact**: None.
- **Acceptance test**: `Glob *.tmp` returns empty under both folders.

### 4. Fix AGENTS.md GameClockComponent path (Phase 0.4)
- **Goal**: Stop telling contributors the wrong path for the most-cited architecture rule.
- **Files**: [AGENTS.md](../AGENTS.md)
- **Why now**: Doc-only, removes the misdirection on the load-bearing rule.
- **Risk**: Low
- **Procedural / data-driven approach**: N/A.
- **Resource impact**: None.
- **Acceptance test**: Grep `Components/Arena/GameClockComponent.gd` in AGENTS.md returns zero hits.

### 5. Update README `GoatManager` → `HerdManager` (Phase 0.7)
- **Goal**: Reflect the rename that shipped 2025-01-28.
- **Files**: [README.md](../README.md) line 36
- **Why now**: Doc-only; aligns with `HerdManager` autoload in `project.godot`.
- **Risk**: Low
- **Procedural / data-driven approach**: N/A.
- **Resource impact**: None.
- **Acceptance test**: Grep `GoatManager` in README returns zero hits (except in optional "history" footnote).

### 6. Delete legacy 2D `player.gd` + `player.tscn` (Phase 0.10)
- **Goal**: Remove the `CharacterBody2D` leftover that confuses framework choice for new contributors.
- **Files**: [player.gd](../player.gd), [player.tscn](../player.tscn)
- **Why now**: Agent 2 confirmed zero references via Grep.
- **Risk**: Low (verify Grep once more before delete).
- **Procedural / data-driven approach**: N/A.
- **Resource impact**: None.
- **Acceptance test**: Project still opens; MainMenu → Arena flow still works.

### 7. Mark Capture.md deprecated in favor of Breeding.md `ActorState` (Phase 0.8)
- **Goal**: Lock in one canonical capture API before Phase 4 implementation starts.
- **Files**: [Markdowns/Capture.md](../Markdowns/Capture.md), [Markdowns/Breeding.md](../Markdowns/Breeding.md)
- **Why now**: Two incompatible designs in the repo today. Picking now prevents implementation churn.
- **Risk**: Low (doc decision).
- **Procedural / data-driven approach**: The canonical design (Breeding.md `ActorState`) is data-driven via `CaptureProfile` Resource (see §9).
- **Resource impact**: None.
- **Acceptance test**: Capture.md header says "DEPRECATED — see Breeding.md §Capture System for canonical design." Breeding.md `ActorState` section is the sole capture API reference.

### 8. Switch `QuestStarterKit` TileSignalComponent guard from name-check to group-check (Phase 1.5)
- **Goal**: Remove the fragile load-order dependency Agent 2 flagged.
- **Files**: [QuestSystem/QuestStarterKit.gd:25-33](../QuestSystem/QuestStarterKit.gd); optionally [Play Space/Arena.gd:133-136](../Play%20Space/Arena.gd)
- **Why now**: Cheap defensive fix; prevents a silent double-add on any rename.
- **Risk**: Low
- **Procedural / data-driven approach**: Group-based discovery (`get_first_node_in_group("tile_signal_component")`).
- **Resource impact**: None.
- **Acceptance test**: Temporary print on TileSignalComponent `_ready` fires exactly once after Arena loads with QuestStarterKit.

### 9. Remove `Timer.new()` from `TileSignalComponent`, replace with GameClock registration (Phase 1.2)
- **Goal**: Make the proximity authority obey its own no-Timer rule.
- **Files**: [Components/Arena/TileSignalComponent.gd:20-25](../Components/Arena/TileSignalComponent.gd)
- **Why now**: Highest-value Phase 1 fix — unblocks Phase 2.2 (clean extraction of TileSignalComponent as a reusable module).
- **Risk**: Medium — proximity routing is load-bearing for Detection, quest discovery, dormant AI, static obstacles.
- **Procedural / data-driven approach**: Use the existing GameClock `register_tick(callback, interval)` pattern (mirror StatusEffectComponent at [Actor.gd:139-167](../src/actors/base/Actor.gd)).
- **Resource impact**: -1 Timer node per active arena; CPU shifts to GameClock (already running).
- **Acceptance test**: Component has no `Timer.new()`. Quest camp discovery + DetectionComponent perception still fire on actor enter/leave. `test_fire_spread.gd` passes.

### 10. Remove `Timer.new()` from `DetectionComponent`, replace with `Actor.register_tick` (Phase 1.3)
- **Goal**: Eliminate the N-per-actor Timer anti-pattern that AGENTS.md singled out as "50 actors × 4 timers = 200 Timer nodes".
- **Files**: [Components/ActorComponents/DetectionComponent.gd:107-112](../Components/ActorComponents/DetectionComponent.gd)
- **Why now**: Direct follow-on to #9; same pattern; same fix.
- **Risk**: Medium — AI perception.
- **Procedural / data-driven approach**: Schedule expiry via `Actor.register_tick(callback, interval)`.
- **Resource impact**: Eliminates N Timer nodes (N = perceiving actors).
- **Acceptance test**: Component has no `Timer.new()`. Perception still expires after configured interval.

---

## 16. Coworker Design Compliance Rules

The project must continue following these rules through every patch:

- **Preserve working systems.** The 22 components on Actor, ArenaGrid, TileSignal, GameClock, AI FSM, FactionComponent, GoatData breeding data layer, tree v2 spawn pipeline, quest camp pipeline, SaveComponent — none of these are to be rewritten. Touch surgically.
- **Patch surgically.** No "while I'm here" refactors. One concern per patch.
- **Keep systems modular.** Every new system gets its own folder + class + docstring + README; can be deleted as a unit.
- **Keep systems reusable.** Every module should be portable to another Godot 4 project with minimal edits (named dependencies declared at the top of the file).
- **Keep systems procedural when possible.** Default to seeds, weighted tables, Resource files, biome/element profiles. Static content is the exception, not the default. Replace static dicts with Resource scans.
- **Avoid placeholder code.** No stubs that "we'll fill in later." Either implement the thin slice that works, or open an issue.
- **Avoid fake completion.** Acceptance tests in this plan are the gate, not "compiles cleanly."
- **Avoid destructive rewrites.** When in doubt, extend or wrap; don't replace.
- **Use exact file paths.** Every PR description, every commit, every doc update — full paths, line numbers when helpful.
- **Update docs after changes.** SYNC RULE in Abilities.md / Actor.md / UI.md is mandatory.
- **Test after every patch.** §15 of Agent 3 plan lists the smoke flow; re-run the relevant subset after each phase landing.

---

## 17. Final Recommendation

**Land Phase 0 in full first** (tasks #1–7 in §15 above). It is entirely hygiene + one one-line scene-path fix, restores the documented Ranch loop, eliminates 30+ orphan files, fixes the documentation drift on the most-cited architecture rule (AGENTS.md `GameClockComponent` path), and locks in the canonical Capture API choice before anyone starts implementing the wrong one. Total estimated risk: low. Total estimated payoff: the project starts agreeing with itself again.

**Then immediately follow with Phase 1.2, 1.3, 1.5** (tasks #8–10) — the three small Phase 1 cleanups that make `TileSignalComponent`, `DetectionComponent`, and `QuestStarterKit` honor the rules AGENTS.md sets. This is the precondition for Phase 2 module extraction; without it, the project would extract reusable modules that violate their own stated contracts.

**Defer everything else until those 10 tasks land cleanly.** Specifically: do NOT start the breeding loop generic refactor (1.1), the procedural module extractions (Phase 2/3), or any of the Phase 4 new features until the Phase 0 + the three small Phase 1 fixes are merged. The `selected_goat → selected_actor_data` rename, the `ActorFactory` extraction, the `TraitInheritanceEngine` lift, and the `RegionData` foundation all build on a project that agrees with its own docs and obeys its own rules.

When you are ready to begin implementation, ask explicitly for the Phase 0 patches; treat each Phase 1+ task as its own session and apply the SYNC RULE in the same commit.

---

*End of combined project status report. Source reports retained at [AGENT_1_DOCUMENTATION_AUDIT.md](AGENT_1_DOCUMENTATION_AUDIT.md), [AGENT_2_CODEBASE_AUDIT.md](AGENT_2_CODEBASE_AUDIT.md), and [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md).*
