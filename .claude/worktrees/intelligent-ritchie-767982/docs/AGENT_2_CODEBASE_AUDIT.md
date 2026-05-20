# Agent 2 — Codebase & Implementation Audit

Scope: descriptive code-truth report for the Elementals Godot 4 project. Read-only audit; no fixes proposed (those belong to Agent 3). All paths are absolute project-relative.

---

## 1. Code Architecture Map

### 1.1 Entry point / configuration
- [project.godot](../project.godot) — `application/run/main_scene` is `res://UI/MainMenu.tscn`. Renderer = `gl_compatibility`. Godot 4.6.
- Main menu: [UI/MainMenu.tscn](../UI/MainMenu.tscn) + [UI/MainMenu.gd](../UI/MainMenu.gd) (load actors via `ACTOR_SCENES` dictionary; introspects ability scripts at runtime).
- Main 3D scene: [Play Space/Arena.tscn](../Play%20Space/Arena.tscn) (script [Play Space/Arena.gd](../Play%20Space/Arena.gd), `class_name ArenaGrid`).

### 1.2 Autoloads (from `project.godot:24-33`)
| Slot | Path | Purpose |
|---|---|---|
| `CyclingComponent` | `res://Components/UI/CycleSelector.gd` | Generic dropdown cycler used by UI |
| `GameEvents` | `res://Core/GameEvents.gd` | Global signal bus (actor_died, gold_changed, day_advanced, etc.) |
| `GameSettings` | `res://Core/GameSettings.gd` | Player prefs + map config persisted to `user://settings.cfg` |
| `HerdManager` | `res://Components/BreedingComponents/HerdManager.gd` | Composite of HerdComponent / EconomyComponent / ProgressionComponent / SaveComponent / BreedingComponent |
| `ItemsAutoload` | `res://Core/ItemsAutoload.gd` | D&D weapon catalog + selection bus |
| `MapSettingsHelper` | `res://Components/UI/MapSettingsHelper.gd` | UI helper for the main menu map sliders |
| `VisibilityManager` | `res://src/trees/VisibilityManager.gd` | Per-frame screen-space foliage transparency |
| `QuestEvents` | `res://QuestSystem/QuestEvents.gd` | Quest-only signal bus |
| `QuestDatabase` | `res://QuestSystem/QuestDatabase.gd` | Loads `quests.json` |
| `QuestState` | `res://QuestSystem/QuestState.gd` | Active quest / kill progress tracker |

All ten autoload script files exist (verified by Glob). No missing autoload targets.

### 1.3 Major folders
- [Core/](../Core) — Autoloads + small managers ([Core/Managers/](../Core/Managers) holds `HerdComponent`, `EconomyComponent`, `ProgressionComponent`, `SaveComponent`, `BreedingComponent`).
- [Components/ActorComponents/](../Components/ActorComponents) — 22 component scripts attached to `Actor` in [src/actors/base/Actor.gd:226](../src/actors/base/Actor.gd) `_setup_components()`.
- [Components/ActorComponents/AbilityComponents/](../Components/ActorComponents/AbilityComponents) — `AbilityAction` base + GoatCharge, NimbleEscape, RedirectAttack.
- [Components/Arena/](../Components/Arena) — Arena-side components: GridGenerator, HexGridRenderer, TileSystem, TileSignalComponent, ArenaSpawner, ArenaUIHandler, ArenaMinimapHandler, ArenaPhysics, PlayerInputComponent, ArenaTileInteractionComponent.
- [Components/BreedingComponents/](../Components/BreedingComponents) — HerdManager, GeneticComponent, GoatData, Ranch/.
- [Components/WeaponComponents/](../Components/WeaponComponents) — WeaponComponent (orchestrator), MeleeHitbox, RangedComponent, ProjectileComponent, WeaponVisualComponent.
- [Play Space/](../Play%20Space) — Arena.gd/.tscn, hex_tile, tile_constants, FenceFeature, HouseFeature, GrassPatchLayer, OptionsMenu.
- [QuestSystem/](../QuestSystem) — QuestStarterKit, QuestSpawnManager (1139 LOC), QuestBoard3D, QuestBoardUI, QuestDatabase, QuestEvents, QuestState, QuestTrackerHUD, CampMarkerFire/, quests.json.
- [UI/](../UI) — MainMenu, EquipmentInventory, GoatRenderer, PlayerConsole, CharacterSelectCard, DisplayCard/ (AbilityCard, ActorCard, WeaponCard, GoatCard.tscn, DisplayCardBase), DebugOptionsController, OptionsMenu, UIStyle.
- [Player/](../Player) — `CameraFollower.gd`, `Reticle.gd` only (very thin).
- [src/actors/](../src/actors) — `base/Actor.gd`, `ai/` (ActorAIController, ActorStateMachine, states/, FactionComponent, ActorTileNavigationComponent), `types/` (GoatActor, FarmerActor, FireActor, WaterActor, GoblinMinion, ScarecrowDummy + controllers + visuals + GoblinModels/), `projectiles/` (BaseProjectile + Fire/Water/Handaxe/Wave/Lob variants).
- [src/trees/](../src/trees) — BiomeData, BiomeRegistry, TreeBlueprint, TreeSpawner, HarvestableTree, VisibilityManager, resources/ (OakTree.tres, FoliageMaterial.tres).
- [scenes/](../scenes) — `actors/`, `projectiles/`, `weapons/` PackedScene libraries.
- [addons/ziva_agent/](../addons/ziva_agent) — Third-party in-editor AI coding assistant (gdextension binary, `README.md` markets it as a coding assistant). NOT a game system.
- [Experimental/](../Experimental) — only `GoatColorTest.gd.uid` (the .gd is missing — orphan).
- [tests/](../tests), [test/](../test) — both contain only `.uid` files; no `.gd` payloads.
- Root-level `test_*.gd` — only [test_fire_spread.gd](../test_fire_spread.gd) actually exists; all other `test_*.gd.uid` files at root are orphans (see §5).

### 1.4 Markdowns / docs
- [Markdowns/](../Markdowns) holds 14 design docs (Abilities, Actor, Arena, Breeding, Capture, MapExpansion, SettlementImplementationPlan, TileSignalComponent, TreeGeneration, UI, UI_Refactoring_Plan, WorldGeneration, procedural_character_framework). One subfolder `FinishedProjects/` contains `ActorRefactorPlan.md`.
- [AGENTS.md](../AGENTS.md) is the load-bearing dev guide. Notable doc drift: it cites `res://Components/Arena/GameClockComponent.gd` but the file lives at [Components/GameClockComponent.gd](../Components/GameClockComponent.gd) (`class_name GameClockComponent` makes this functionally invisible, but it is still doc/code drift).

---

## 2. Implemented Systems (Functional)

### 2.1 Hex grid generation & rendering
- [Components/Arena/GridGenerator.gd](../Components/Arena/GridGenerator.gd) — Perlin-noise grass/dirt + stone-wall border, axial/offset conversions, neighbor caching, flood-fill farmstead planning, radius cache (`_build_radius_cache()`).
- [Play Space/hex_tile.gd](../Play%20Space/hex_tile.gd) + [hex_tile_data.gd](../Play%20Space/hex_tile_data.gd) + [tile_constants.gd](../Play%20Space/tile_constants.gd) — single tile, data record, state enums.
- [Components/Arena/HexGridRenderer.gd](../Components/Arena/HexGridRenderer.gd) — instanced rendering.
- [Play Space/hex_tile.gdshader](../Play%20Space/hex_tile.gdshader) — tile shader.

### 2.2 Actor / component architecture
- [src/actors/base/Actor.gd](../src/actors/base/Actor.gd) wires ~20 components in `_setup_components()` (lines 226-337). Property setters propagate to components so editor changes stay in sync.
- AI state machine: [src/actors/ai/ActorAIController.gd](../src/actors/ai/ActorAIController.gd) + [src/actors/ai/ActorStateMachine.gd](../src/actors/ai/ActorStateMachine.gd) + [src/actors/ai/states/](../src/actors/ai/states) (idle, roam, chase, attack, flee, investigate, stunned, death, Dormant). All 9 state files present.
- Factions: [src/actors/ai/FactionComponent.gd](../src/actors/ai/FactionComponent.gd) — PLAYER, GOBLINS, FARMSTEAD, WILDLIFE, NEUTRAL, MONSTERS with cached ally/enemy lookups.

### 2.3 Combat
- [Components/WeaponComponents/WeaponComponent.gd](../Components/WeaponComponents/WeaponComponent.gd) — orchestrates melee hitbox, ranged, visuals; data-driven via [Core/WeaponData.gd](../Core/WeaponData.gd) which parses D&D notes strings into typed combat flags.
- [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd) — registers 37 weapons, each with icon + (some with) projectile scene. 6 projectile scenes referenced (`Club/Dagger/Handaxe/Javelin/Shortbow/Scimitar`); the additional `ArrowProjectile.tscn`, `FireProjectile.tscn`, `FireLobProjectile.tscn`, `WaterProjectile.tscn`, `WaterLobProjectile.tscn` exist but are not wired to ItemsAutoload entries (used by element actors and as fallback for `drop_inventory()` at [WeaponComponent.gd:124](../Components/WeaponComponents/WeaponComponent.gd)).
- Projectile pickup / throw / drop: working per README claim; `WeaponComponent.drop_inventory()` re-spawns the equipped weapon as a stuck pickup.

### 2.4 Tile state & elemental interactions
- [Components/Arena/ArenaTileInteractionComponent.gd](../Components/Arena/ArenaTileInteractionComponent.gd) applies element + spreads fire.
- [Components/Arena/TileSystem.gd](../Components/Arena/TileSystem.gd) schedules fire/mud/puddle progression with an event-driven `Timer` (uses node timer, not GameClock — see §10).
- [Components/ActorComponents/StatusEffectComponent.gd](../Components/ActorComponents/StatusEffectComponent.gd) — burn / water interactions; correctly registered with GameClock via `Actor.register_tick()` (fast 0.1s, slow 1.0s).

### 2.5 Centralized timing & proximity (per AGENTS.md)
- [Components/GameClockComponent.gd](../Components/GameClockComponent.gd) — 10Hz tick bus; usage list confirmed limited to `StatusEffectComponent` and the local-fallback path in `Actor.register_tick()` ([Actor.gd:139-167](../src/actors/base/Actor.gd)).
- [Components/Arena/TileSignalComponent.gd](../Components/Arena/TileSignalComponent.gd) — hex-distance triggers with enter/exit signals + continuous mode.

### 2.6 Quest / camp system
- [QuestSystem/QuestStarterKit.gd](../QuestSystem/QuestStarterKit.gd) installs `QuestSpawnManager`, `TileSignalComponent` (note: a second one is added under Arena if absent — but Arena.gd:133 already creates one in `_setup_components()`), `QuestBoardUI`, `QuestBoard3D` (deferred).
- [QuestSystem/QuestSpawnManager.gd](../QuestSystem/QuestSpawnManager.gd) (1139 LOC) — designates camp tiles near each edge, registers proximity triggers (radius 8), spawns camp visuals (rocks/tents/banners/fire+smoke marker) and goblin clusters on discovery.
- [QuestSystem/quests.json](../QuestSystem/quests.json) — three goblin-cleanup quests, data-driven (`count`, `camp_count`, `camp_size`, `camp_spawn_radius`).
- [QuestSystem/CampMarkerFire/](../QuestSystem/CampMarkerFire) — toon fire/smoke shaders + scenes (`3d_fire.tscn`, `smoke_particle_1.tscn`, `smoke_particle_2.tscn`) + culling script.

### 2.7 Tree generation
- [src/trees/TreeSpawner.gd](../src/trees/TreeSpawner.gd) — biome-driven, seedable (`tree_seed` from GameSettings), batched (10/frame), avoids farmstead, hex-distance density falloff.
- [src/trees/BiomeData.gd](../src/trees/BiomeData.gd) — `Resource` with `base_density`, `distance_multipliers`, `min_tree_spacing`, `tree_blueprints` array.
- [src/trees/BiomeRegistry.gd](../src/trees/BiomeRegistry.gd) — static dict registry.
- [src/trees/TreeBlueprint.gd](../src/trees/TreeBlueprint.gd) — generates trunk/branch/foliage CSG geometry from a blueprint Resource.
- [src/trees/HarvestableTree.gd](../src/trees/HarvestableTree.gd) — HP via `HealthComponent`, harvest accumulator, fall animation, fallen rigid-body collision, LOD stubs (`switch_to_lod()` with billboard TODO).
- [src/trees/resources/OakTree.tres](../src/trees/resources/OakTree.tres) — sample blueprint.

### 2.8 Save / herd / economy / progression
- All five Core/Managers components exist as small focused units: [HerdComponent.gd](../Core/Managers/HerdComponent.gd), [EconomyComponent.gd](../Core/Managers/EconomyComponent.gd), [ProgressionComponent.gd](../Core/Managers/ProgressionComponent.gd), [SaveComponent.gd](../Core/Managers/SaveComponent.gd), [BreedingComponent.gd](../Core/Managers/BreedingComponent.gd).
- Save uses `ResourceSaver.save(GoatSaveData)` to `user://herd_save.tres` with deferred coalescing ([SaveComponent.gd:8-13](../Core/Managers/SaveComponent.gd)).
- Breeding (data layer) is implemented: gender check, exhaustion gate, 3-day pregnancy, day-tick processing producing offspring via `GoatData.create_offspring()` — works at the data level. See §3 for the gameplay/UI flow.

### 2.9 Visibility / detection
- [Components/ActorComponents/DetectionComponent.gd](../Components/ActorComponents/DetectionComponent.gd) — perception trigger via TileSignalComponent (continuous), Wisdom-based d20 checks, event-driven expiry timer instead of per-frame iteration.

---

## 3. Partially Implemented Systems

### 3.1 Breeding gameplay loop
- Data layer works (`BreedingComponent.breed`, `process_pregnancy`, `GoatData.create_offspring` at [GoatData.gd:77](../Components/BreedingComponents/GoatData.gd) - color/horn/body inheritance + stat mean ±10% mutation).
- UI exists in [Components/BreedingComponents/Ranch/Ranch.gd](../Components/BreedingComponents/Ranch/Ranch.gd) and `Ranch.tscn`, with does/bucks selection and a `MaxLevelGoat` cheat.
- **Gap matching README**: README says "Actual breeding and capture mechanics are broken at the moment" and ranch flow is "[Currently Busted]". The scene-change call at [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) targets `res://Ranch/Ranch.tscn`, which **does not exist**; the real Ranch scene is at `res://Components/BreedingComponents/Ranch/Ranch.tscn`. MainMenu uses the correct path at [UI/MainMenu.gd:281](../UI/MainMenu.gd). Returning from Arena to ranch will fail.

### 3.2 Ability system
- Framework exists ([AbilityAction.gd](../Components/ActorComponents/AbilityComponents/AbilityAction.gd) + [AbilityComponent.gd](../Components/ActorComponents/AbilityComponents/AbilityComponent.gd)), but only 3 concrete actions are implemented: GoatCharge, NimbleEscape, RedirectAttack. The MainMenu introspects ability scripts to populate equipment cards ([UI/MainMenu.gd:67-100](../UI/MainMenu.gd)).
- `Core/Abilities/Dash.gd` is the only file in `Core/Abilities/`, but it is **not** wired into `AbilityComponent.setup()` (which only loads NimbleEscape/RedirectAttack/GoatCharge by element_type).
- `RedirectAttack_NEW.gd.uid` is orphaned (no `.gd` companion).

### 3.3 Tree LOD system
- `HarvestableTree.switch_to_lod()` has a level-2 billboard branch left as TODO ([HarvestableTree.gd:316](../src/trees/HarvestableTree.gd)). No code anywhere actually calls `switch_to_lod()`; LOD plumbing exists but isn't driven.

### 3.4 Status / effects
- StatusEffectComponent covers burn and water sinking only. Mud/slow handled separately by [TerrainSpeedModifierComponent.gd](../Components/ActorComponents/TerrainSpeedModifierComponent.gd). Burst sounds, splash, fire particles are wired.

### 3.5 Player.gd (legacy 2D)
- [player.gd](../player.gd) + [player.tscn](../player.tscn) are a `CharacterBody2D` stub with `animated_sprite` calls — leftover from an earlier 2D iteration. Not referenced by Arena or MainMenu, but still in the project root.

---

## 4. Missing Systems (Documented but not in code)

### 4.1 Capture system
- [Markdowns/Capture.md](../Markdowns/Capture.md) describes nets, restraint ratings, dragging, taming, `ActorState` enum (WILD/RESTRAINED/CONFINED/TAMING/TAMED/FLED), `CaptureComponent`. **None** of `CaptureComponent`, `ActorState`, `RESTRAINED`, or `CONFINED` appears anywhere in `.gd` (verified via Grep).
- README explicitly flags "capture mechanics are broken at the moment" and lists it under Roadmap.

### 4.2 Settlement
- [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) is a plan for a **React/JSX** project (`Settlement.jsx`, `goatFactory.js`, etc.) — not implementable in this Godot codebase. The existing Godot equivalent is the Ranch UI; no Settlement code exists.

### 4.3 Map expansion / region streaming
- [Markdowns/MapExpansion.md](../Markdowns/MapExpansion.md) describes region-transition handler, river edges, openable edges, plate tectonics. None of this is implemented — `GridGenerator` produces a single fixed circle with a stone-wall ring.

### 4.4 Procedural Character Framework
- [Markdowns/procedural_character_framework.md](../Markdowns/procedural_character_framework.md) is design-phase (`Status: Design Phase`), describes `CreatureDefinition`/`BipedGenerator`/IK rig. No `BipedGenerator`, `CreatureDefinition`, or `SurfaceTool`-based runtime generator exists. Goblin/goat models are PackedScenes under [scenes/actors/models/](../scenes/actors/models).

### 4.5 Earth / Air elements
- README roadmap mentions Earth/Air. Only Fire and Water actor scripts exist ([src/actors/types/FireActor.gd](../src/actors/types/FireActor.gd), [WaterActor.gd](../src/actors/types/WaterActor.gd)).

---

## 5. Likely Broken / Risky References

### 5.1 Missing files referenced by other systems
- **`res://Ranch/Ranch.tscn`** referenced at [Components/Arena/ArenaUIHandler.gd:107](../Components/Arena/ArenaUIHandler.gd) — file does not exist. Real path is `res://Components/BreedingComponents/Ranch/Ranch.tscn`.
- **`res://Play Space/tree_feature.tscn`** — gone, but 6 `.tmp` editor-crash leftovers remain in `Play Space/`: `tree_feature.tscn12167402242.tmp`, `…12176042498.tmp`, `…12182356963.tmp`, `…12184540442.tmp`, `…12191344204.tmp`, `…12197615815.tmp`. No live code references the path (only historical `.ziva/snapshots/` mentions).
- **`QuestSystem/QuestTrackerHUD.tscn3514348495.tmp`** and **`…3522565996.tmp`** — same pattern.

### 5.2 Deleted weapon stack (only `.uid` remain in `Core/`)
- [Core/Weapon.gd.uid](../Core/Weapon.gd.uid), [Core/WeaponLibrary.gd.uid](../Core/WeaponLibrary.gd.uid), [Core/WeaponManager.gd.uid](../Core/WeaponManager.gd.uid), [Core/Weapon_OLD.gd.uid](../Core/Weapon_OLD.gd.uid) all have no `.gd` companion. Confirms a refactor sweep that removed the old weapon authority. Current authorities are [Core/WeaponData.gd](../Core/WeaponData.gd) (Resource) + [Components/WeaponComponents/WeaponComponent.gd](../Components/WeaponComponents/WeaponComponent.gd) (orchestrator).

### 5.3 Other orphan `.uid` files (no `.gd` companion)
Pattern is repeated across the project — likely leftovers from moves/renames. The .uid is harmless to Godot but signals stale references in version control:
- Root level: `ArenaMinimapHandler.gd.uid`, `GameEvents.gd.uid`, `GameSettings.gd.uid`, `GeneticComponent.gd.uid`, `GoatColorTest.gd.uid`, `GoatData.gd.uid`, `GoatManager.gd.uid`, `GoatSaveData.gd.uid`, `MainMenu.gd.uid` (the real files are now in `Core/`, `Components/`, `UI/`, etc.)
- `Components/`: `ActorSpawnerComponent.gd.uid`, `CharacterUIComponent.gd.uid`, `TileInteractionComponent.gd.uid`.
- `Components/ActorComponents/`: `DecisionComponent.gd.uid`.
- `Components/ActorComponents/AbilityComponents/`: `RedirectAttack_NEW.gd.uid`.
- `Components/Arena/`: `ActorSpawnerComponent.gd.uid`, `CharacterUIComponent.gd.uid`, `MinimapHandler.gd.uid`.
- `Play Space/`: `ArenaPhysics.gd.uid`, `HexGridRenderer.gd.uid`, `TileSystem.gd.uid` (real files are now in `Components/Arena/`).
- `Experimental/`: `GoatColorTest.gd.uid`.
- `tests/`: `test_armor.gd.uid` (no .gd, entire folder is orphan).
- `test/`: `test_architecture_refactor.gd.uid` (same).
- Root: `test_breeding.gd.uid`, `test_breeding_fix.gd.uid`, `test_goat_hp.gd.uid`, `test_goat_random.gd.uid`, `test_refactor.gd.uid`, `test_tree_lifecycle.gd.uid`, `test_tree_lifecycle_updated.gd.uid`, `test_tree_spread.gd.uid`. Only [test_fire_spread.gd](../test_fire_spread.gd) (single live test) plus its `.uid` remain.
- `UI/`: `RanchUI.gd.uid`.

### 5.4 Duplicate / refactor-leftover code
- `Components/Arena/CharacterUIComponent.gd.uid` and `Components/CharacterUIComponent.gd.uid` — two orphan UIDs for the same class.
- `Components/Arena/ActorSpawnerComponent.gd.uid`, `Components/ActorSpawnerComponent.gd.uid` — same pattern; the live class is now `ArenaSpawnerComponent` in [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd).
- `Components/Arena/MinimapHandler.gd.uid` orphan; the live class is [Components/Arena/ArenaMinimapHandler.gd](../Components/Arena/ArenaMinimapHandler.gd).

### 5.5 Doc / code path drift
- [AGENTS.md:87](../AGENTS.md) tells contributors `res://Components/Arena/GameClockComponent.gd` — actual location is `res://Components/GameClockComponent.gd`. Class-name resolution makes it work at runtime, but the doc lies about the path.
- [Markdowns/Actor.md](../Markdowns/Actor.md), [Breeding.md](../Markdowns/Breeding.md), [Capture.md](../Markdowns/Capture.md) reference component paths that may not match after the refactor — Agent 1 covers docs; flagged here only as a contributing factor.

### 5.6 Quest system duplicate `TileSignalComponent` risk
- Arena creates `TileSignalComponent` at [Play Space/Arena.gd:133-136](../Play%20Space/Arena.gd) as a child node, and `QuestStarterKit._ensure_tile_signal_component()` at [QuestSystem/QuestStarterKit.gd:25-33](../QuestSystem/QuestStarterKit.gd) checks via `arena.has_node("TileSignalComponent")` before adding. Names match (`name = "TileSignalComponent"`) so the guard does work — but this is fragile and depends on the load order keeping the arena's component fully registered before QuestStarterKit runs.

### 5.7 ArenaSpawner preloads vs scene set
- [Components/Arena/ArenaSpawner.gd:6-11](../Components/Arena/ArenaSpawner.gd) preloads all 6 actor scenes; all exist under [scenes/actors/](../scenes/actors). OK.

---

## 6. Reusable Modules Already Present

These are well-isolated enough to lift into another project with minimal coupling:

- **`TileSignalComponent`** ([Components/Arena/TileSignalComponent.gd](../Components/Arena/TileSignalComponent.gd)) — generic hex-distance proximity/trigger registry. Only assumption is the `axial_coords` Vector2i property on whatever you pass as a tile.
- **`GameClockComponent`** ([Components/GameClockComponent.gd](../Components/GameClockComponent.gd)) — drop-in centralized tick bus; ~70 LOC, no project dependencies.
- **`FactionComponent`** ([src/actors/ai/FactionComponent.gd](../src/actors/ai/FactionComponent.gd)) — cached ally/enemy with a simple enum. Faction matrix is hardcoded but pure data.
- **`AbilityAction` + `AbilityComponent`** pair — minimal RefCounted-based ability framework that any actor extending the conventions can use.
- **`HealthBarPool`** ([Components/ActorComponents/HealthBarPool.gd](../Components/ActorComponents/HealthBarPool.gd)) — already a proper pool.
- **Save layer** ([Core/Managers/SaveComponent.gd](../Core/Managers/SaveComponent.gd)) — deferred ResourceSaver pattern; reusable for any Resource-shaped save.
- **Tree blueprint generator** ([src/trees/TreeBlueprint.gd](../src/trees/TreeBlueprint.gd) + [HarvestableTree.gd](../src/trees/HarvestableTree.gd)) — entirely Resource-driven CSG generation, no project-wide assumptions beyond `HealthComponent`.
- **`BiomeData` + `TreeSpawner`** — generic seeded weighted-pool spawner.
- **`StatusEffectComponent`** — model for any "register-with-clock, react-to-tile" buff/debuff (currently only burn/water but extensible).

---

## 7. Procedural Systems Already Present

- **Hex world generation**: noise-seeded grass/dirt + radial stone border in [GridGenerator.gd:46-91](../Components/Arena/GridGenerator.gd), seed read from `GameSettings.noise_seed`.
- **Height map**: noise-driven `height_level` 0-3 quantized in [GridGenerator.gd:77-80](../Components/Arena/GridGenerator.gd).
- **Farmstead planning**: flood-fill in `GridGenerator.plan_farmstead()` — deterministic given seed.
- **Biome-driven tree spawning**: [BiomeData.gd](../src/trees/BiomeData.gd) → `distance_multipliers` table interpolated by hex distance from center, `tree_blueprints` weighted pool, seeded `_rng` in [TreeSpawner.gd:30-46](../src/trees/TreeSpawner.gd).
- **Procedural tree geometry**: per-tree trunk-segment/branch/foliage layout from [TreeBlueprint.gd](../src/trees/TreeBlueprint.gd) (consumes blueprint params, emits `GeneratedTree`).
- **Wild goat randomization**: [ArenaSpawner.gd:296-310](../Components/Arena/ArenaSpawner.gd) `_make_random_goat_data()` — random color/pattern/horn/body, randomized stats and gold.
- **Random goat names**: small static table in [ArenaSpawner.gd:312-316](../Components/Arena/ArenaSpawner.gd).
- **Quest camp placement**: edge-rotating + spacing-constrained tile picking in [QuestSpawnManager.gd:49-140](../QuestSystem/QuestSpawnManager.gd).
- **Goat genetic inheritance with mutation**: [GoatData.create_offspring()](../Components/BreedingComponents/GoatData.gd) — color lerp, 50/50 horn/body, stat mean ± random 10%.
- **Tile state transitions** (fire spread, mud↔grass, puddle→mud): [TileSystem.gd](../Components/Arena/TileSystem.gd).

---

## 8. Systems That Could Become Reusable Modules (observations only)

- **`QuestSpawnManager` (1139 LOC)** — mixes camp placement, visual construction (rocks/tents/banners/markers), spawn metadata routing, kill credit, marker UI sync, and pre-cleared bookkeeping. Each of those is independent in principle.
- **`GoatData.create_offspring()` and the stat-blending logic** — sits inside a goat-specific class, but the algorithm (mean of parents × random factor) is generic.
- **Camp visuals (rocks/tents/banners/fire smoke marker)** built ad-hoc in `_build_goblin_camp_visual()` — not data-driven; structures are hardcoded `BoxMesh`/`CylinderMesh` with shared materials in `_get_shared_*()` helpers.
- **`ArenaSpawner._make_random_goat_data()`** — only used for goats; the same pattern would apply to any actor type with a `*Data` resource.
- **`MainMenu`'s ability-script introspection** ([UI/MainMenu.gd:67-100](../UI/MainMenu.gd)) — instantiates ability classes at runtime to read their `ability_name`. Could become an `AbilityRegistry` autoload.
- **`PlayerInputComponent`** is currently tied to actor cycling and selection; the input-binding side could be lifted.

---

## 9. Static / Manual Systems That Could Be Procedural (observations only)

- **Weapon catalog** ([Core/ItemsAutoload.gd:26-110](../Core/ItemsAutoload.gd)) — 37 hand-coded `_add()` calls with explicit icon path strings tied to per-asset timestamps (e.g., `club_icon_frame_0_1776824494.png`). Adding/renaming any icon means hand-editing this file. Could be a `Resource` directory scan.
- **`GameSettings.CHARACTER_EQUIPMENT`** ([Core/GameSettings.gd:21-52](../Core/GameSettings.gd)) and the duplicate `CHARACTER_EQUIPMENT` reconstructed at runtime in [UI/MainMenu.gd:31-64](../UI/MainMenu.gd) — two manually maintained dictionaries describing per-actor weapons/abilities/armor. Currently fully static; "Pitchfork", "Shovel", "Headbutt", "Flame Burst", "Water Jet", etc. don't even have matching WeaponData entries in ItemsAutoload.
- **Faction relationships** ([FactionComponent.gd:48-69](../src/actors/ai/FactionComponent.gd)) — `_compute_is_ally` matches on the PLAYER↔FARMSTEAD pair only. No data table for the other factions; everything else routes through `_compute_is_enemy` defaults.
- **Quest camp structures** — manually built node trees in `_build_goblin_camp_visual` instead of being PackedScene-driven.
- **Goblin / farmer / fire / water actor types** — separate `*.tscn`+`*.gd` per type instead of a data-driven actor template.
- **GoatActor terrain speed multipliers** hardcoded in [GoatActor.gd:43-49](../src/actors/types/GoatActor.gd) rather than per-creature data.
- **Tile state side effects** (fire spread / mud / puddle progression) baked into [TileSystem.gd](../Components/Arena/TileSystem.gd) as `match` on enum rather than data-defined.
- **Single hardcoded biome** at [TreeSpawner.gd:227-242](../src/trees/TreeSpawner.gd) `_get_or_create_default_biome()` — only one biome in use; BiomeRegistry is otherwise unused.
- **MainMenu actor introspection** ([UI/MainMenu.gd:67-100](../UI/MainMenu.gd)) does instantiate-and-`free()` cycles on Actor + Node every time the menu opens just to read `ability_name`. Effectively a manual reflection step.

---

## 10. Performance Risks

### 10.1 VisibilityManager — the biggest hot spot
- [src/trees/VisibilityManager.gd](../src/trees/VisibilityManager.gd) runs `_process` every frame ([line 51](../src/trees/VisibilityManager.gd)) and for **every registered foliage node** ([lines 213-239](../src/trees/VisibilityManager.gd)) does: vector normalize, dot product, screen-space `unproject_position` for both actor and foliage, FOV math, AABB intersection, and a `lerp` opacity update.
- Two unbounded loops run per frame over `_foliage_opacity_map.keys()`.
- Debug prints fire continuously through `if randf() < 0.01`/`< 0.005`/`< 0.02` checks — they spam every few frames even in release builds (no `OS.is_debug_build()` gate).
- Registration adds every CSG sphere AND every named "TrunkSegment" cylinder of every tree — count scales linearly with trees on the map.

### 10.2 Per-frame logic that should be on GameClock
- [Components/ActorComponents/AbilityComponent.gd:52-54](../Components/ActorComponents/AbilityComponents/AbilityComponent.gd) `_process(delta)` iterates all actions every frame.
- [src/actors/types/HarvestableTree.gd:182-194](../src/trees/HarvestableTree.gd) `_process(delta)` runs for every standing tree, even when no actor is harvesting.
- [src/actors/base/Actor.gd:379-394](../src/actors/base/Actor.gd) `_physics_process` runs an in-actor tick accumulator as a fallback for when no GameClock is found — when both exist, the actor pays the cost of `move_and_slide()` + the accumulator check every physics tick.

### 10.3 Timer node anti-patterns (per AGENTS.md "do NOT add Timer nodes to actors")
Live Timer nodes in non-StatusEffect components:
- [Components/Arena/TileSignalComponent.gd:20-25](../Components/Arena/TileSignalComponent.gd) — `Timer.new()` with `wait_time = 1.0` for actor re-scanning. Ironic given this is the system AGENTS.md singles out as the proximity authority.
- [Components/Arena/TileSystem.gd:16-19](../Components/Arena/TileSystem.gd) — `Timer.new()` driving tile state transitions; this one is at least one-shot scheduled.
- [Components/ActorComponents/DetectionComponent.gd:107-112](../Components/ActorComponents/DetectionComponent.gd) — `Timer.new()` per-actor for perception expiry. AGENTS.md "50 actors × 4 timers = 200 timer nodes" is exactly the pattern this re-introduces.

### 10.4 Ad-hoc `SceneTreeTimer` calls (also bypass GameClock)
Live `get_tree().create_timer(...)` usage:
- [QuestSystem/QuestSpawnManager.gd:230](../QuestSystem/QuestSpawnManager.gd) and [QuestSystem/QuestSpawnManager.gd:361](../QuestSystem/QuestSpawnManager.gd) — `await get_tree().create_timer(0.5).timeout` inside `for i in range(member_count)` — one new SceneTreeTimer per goblin per camp.
- [Components/Arena/ArenaUIHandler.gd:115](../Components/Arena/ArenaUIHandler.gd), [Components/ActorComponents/CommunicationComponent.gd:109](../Components/ActorComponents/CommunicationComponent.gd), [Components/ActorComponents/MovementComponent.gd:275](../Components/ActorComponents/MovementComponent.gd), [Components/ActorComponents/AbilityComponents/NimbleEscape.gd:96](../Components/ActorComponents/AbilityComponents/NimbleEscape.gd), [src/actors/projectiles/LobProjectile.gd:75](../src/actors/projectiles/LobProjectile.gd) — six more inline scene-tree timers.

### 10.5 No projectile pooling
- [Components/WeaponComponents/ProjectileComponent.gd:82-91](../Components/WeaponComponents/ProjectileComponent.gd) `_launch_lob_shot` instantiates 5 projectile PackedScenes per shot in a `for` loop with `scene.instantiate() + add_child`. No pool. Same for `_launch_spread_shot` (5 angles).
- WeaponComponent.drop_inventory instantiates a fresh projectile-as-pickup each death.

### 10.6 Arena bookkeeping
- [Play Space/Arena.gd:260-266](../Play%20Space/Arena.gd) `_process` does a freed-actor sweep every 30 frames. Harmless but per-frame.
- [Play Space/Arena.gd:278-307](../Play%20Space/Arena.gd) `get_tile_data_at_world_position` has a self-noted `TODO(Optimization)` for spatial caching.
- [Play Space/Arena.gd:363-384](../Play%20Space/Arena.gd) `_register_static_obstacles` walks the entire `tile_data_grid` once on startup and registers a radius-2 trigger per obstacle — multiplied by all goblin camps, fences, stones, this is many triggers in `_triggers` array; `TileSignalComponent._on_actor_tile_changed` iterates **all** triggers on every actor tile change.

### 10.7 ItemsAutoload startup cost
- [Core/ItemsAutoload.gd:27-66](../Core/ItemsAutoload.gd) does 40+ `load()` calls synchronously in `_init_weapons()` on autoload boot.

### 10.8 GoatActor `_physics_process` extras
- [src/actors/types/GoatActor.gd:99-111](../src/actors/types/GoatActor.gd) iterates `ability_component.actions` twice per physics tick (before and after `super._physics_process`) to find `GoatCharge` actions. With many goats this scales linearly.

---

## 11. DO-NOT-BREAK List (high blast radius)

Files whose modification ripples through many systems:

| File | Why |
|---|---|
| [project.godot](../project.godot) | Autoload list; any rename here cascades. |
| [Play Space/Arena.gd](../Play%20Space/Arena.gd) (`class_name ArenaGrid`) | Orchestrator; every component reads from it via `actor._arena_grid` or `get_first_node_in_group("arena")`. |
| [Play Space/Arena.tscn](../Play%20Space/Arena.tscn) | Main scene; preloads UI, references `QuestTrackerHUD.tscn`, `WeaponCard.tscn`, `AbilityCard.tscn`, `ActorCard.tscn`, `ControlsPanel.tscn`. |
| [src/actors/base/Actor.gd](../src/actors/base/Actor.gd) | Base class for every entity; component setup order matters. |
| [Components/GameClockComponent.gd](../Components/GameClockComponent.gd) | Tick bus; broken == all StatusEffect ticking silently stops. |
| [Components/Arena/TileSignalComponent.gd](../Components/Arena/TileSignalComponent.gd) | Proximity & detection routing; broken == AI loses obstacle avoidance, perception, quest camp discovery. |
| [Components/Arena/GridGenerator.gd](../Components/Arena/GridGenerator.gd) | World generation; coordinate conventions used everywhere. |
| [Components/Arena/TileSystem.gd](../Components/Arena/TileSystem.gd) | Fire / mud / puddle progression. |
| [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd) (`class_name ArenaSpawnerComponent`) | Used by Arena AND QuestSpawnManager. |
| [Components/BreedingComponents/HerdManager.gd](../Components/BreedingComponents/HerdManager.gd) | Autoload; composes the 5 Managers; consumed by ArenaSpawner, Ranch, and on save. |
| [Core/GameEvents.gd](../Core/GameEvents.gd) | Global signal bus; renames are silent runtime failures. |
| [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd) | Weapon catalog; hardcoded selection by name string in [ArenaSpawner.gd:249-258](../Components/Arena/ArenaSpawner.gd) ("Quarterstaff", "Dagger") and [WeaponComponent.gd:91-103](../Components/WeaponComponents/WeaponComponent.gd) ("Unarmed strike"). |
| [Core/WeaponData.gd](../Core/WeaponData.gd) | Resource shape parses note strings; format changes break every weapon. |
| [Components/WeaponComponents/WeaponComponent.gd](../Components/WeaponComponents/WeaponComponent.gd) | Routes between MeleeHitbox / RangedComponent / VisualComponent. |
| [src/actors/ai/ActorAIController.gd](../src/actors/ai/ActorAIController.gd) | All NPC behavior is gated through its state machine + obstacle avoidance. |
| [src/actors/ai/FactionComponent.gd](../src/actors/ai/FactionComponent.gd) | Drives `is_ally`/`is_enemy` everywhere. |
| [QuestSystem/QuestSpawnManager.gd](../QuestSystem/QuestSpawnManager.gd) | 1139 LOC; touches QuestEvents, QuestState, GameEvents, ArenaSpawner, TileSignalComponent. |
| [QuestSystem/QuestDatabase.gd](../QuestSystem/QuestDatabase.gd) + [quests.json](../QuestSystem/quests.json) | Quest definitions consumed in three different paths in QuestSpawnManager. |
| [src/trees/VisibilityManager.gd](../src/trees/VisibilityManager.gd) | Autoload; touches every spawned tree foliage node. |
| [UI/MainMenu.tscn](../UI/MainMenu.tscn) | `application/run/main_scene` — first scene loaded. |
| [Components/BreedingComponents/Ranch/Ranch.tscn](../Components/BreedingComponents/Ranch/Ranch.tscn) | Entry point from MainMenu (and intended return target from Arena). |

---

## Appendix A — Sample of broken-or-stale artifacts

```
Editor crash leftovers (delete candidates, no code references):
  Play Space/tree_feature.tscn12167402242.tmp
  Play Space/tree_feature.tscn12176042498.tmp
  Play Space/tree_feature.tscn12182356963.tmp
  Play Space/tree_feature.tscn12184540442.tmp
  Play Space/tree_feature.tscn12191344204.tmp
  Play Space/tree_feature.tscn12197615815.tmp
  QuestSystem/QuestTrackerHUD.tscn3514348495.tmp
  QuestSystem/QuestTrackerHUD.tscn3522565996.tmp

Orphan .uid (no .gd companion) — high-signal subset:
  Core/Weapon.gd.uid, Core/WeaponLibrary.gd.uid, Core/WeaponManager.gd.uid, Core/Weapon_OLD.gd.uid
  Components/ActorComponents/AbilityComponents/RedirectAttack_NEW.gd.uid
  Components/ActorComponents/DecisionComponent.gd.uid
  Components/Arena/ActorSpawnerComponent.gd.uid (live class moved to ArenaSpawnerComponent)
  Components/Arena/MinimapHandler.gd.uid (live class is ArenaMinimapHandler)
  tests/test_armor.gd.uid (folder otherwise empty)
  test/test_architecture_refactor.gd.uid (folder otherwise empty)
  All other test_*.gd.uid at project root except test_fire_spread.gd
  UI/RanchUI.gd.uid

Broken path in code:
  Components/Arena/ArenaUIHandler.gd:107 — change_scene_to_file("res://Ranch/Ranch.tscn")
```
