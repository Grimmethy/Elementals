# Agent 1 — Documentation & Project Plan Audit

> **Scope:** Audit of every Markdown document in the Elementals repo as of audit date.
> **Auditor:** Agent 1 (Documentation reviewer; non-implementation).
> Paths in this report are **repo-relative**. Where docs reference `res://...` Godot paths, they are translated 1:1 (drop the `res://` prefix).

---

## 1. Documentation Inventory

| # | File (repo-relative) | Stated purpose / topic | Size signal | Date / version signals |
|---|----------------------|-------------------------|-------------|------------------------|
| 1 | [README.md](../README.md) | Top-level pitch + roadmap + a detailed deep-dive on the goblin camp / quest spawn pipeline | Large (~130 lines) | No version; status notes say breeding/capture/Ranch are "broken" / "[Currently Busted]" |
| 2 | [AGENTS.md](../AGENTS.md) | Coworker / agent rules: project overview, structure, TileSignalComponent + GameClockComponent rules, coding conventions, performance | Large (~430 lines) | Footer: "Last updated: Auto-generated from project analysis" — no date |
| 3 | [Markdowns/Abilities.md](../Markdowns/Abilities.md) | AbilityComponent + AbilityAction reference, existing abilities (NimbleEscape, RedirectAttack, GoatCharge, Dash data), how to add new | Large (~629 lines) | v1.0 / 2025-01-10 |
| 4 | [Markdowns/Actor.md](../Markdowns/Actor.md) | Actor / Component / AI state reference; full file structure listing | Large (~580 lines) | v1.1 / 2025-01-10 |
| 5 | [Markdowns/Arena.md](../Markdowns/Arena.md) | ArenaGrid responsibilities, component summary, init flow, integration points | Medium (~50 lines) | No version stamp |
| 6 | [Markdowns/Breeding.md](../Markdowns/Breeding.md) | Breeding design + actor-agnostic refactor plan (Phases 1–5), TraitInheritanceEngine, capture, spawn variance | Very large (~815 lines) | v1.1 / 2025-01-28; "Status: IN PROGRESS - Phase 1 Refactor" |
| 7 | [Markdowns/Capture.md](../Markdowns/Capture.md) | Capture (encounter → restrain → drag → tame), restraint tiers, escape DC, taming/loyalty | Medium (~60 lines) | No version stamp |
| 8 | [Markdowns/MapExpansion.md](../Markdowns/MapExpansion.md) | Plan for boundary types, rivers, height variation, region streaming, quest-driven expansion, road generation | Large (~200 lines) | v1.0 / "2023-11-XX" (suspect placeholder) |
| 9 | [Markdowns/SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) | React/JSX (`Settlement.jsx`) implementation plan for a separate Settlement webapp, 6 phases | Large (~270 lines) | "Last updated: Day 1 of the settlement." — no real date |
| 10 | [Markdowns/TileSignalComponent.md](../Markdowns/TileSignalComponent.md) | API reference for TileSignalComponent | Medium (~120 lines) | No version stamp |
| 11 | [Markdowns/TreeGeneration.md](../Markdowns/TreeGeneration.md) | Procedural tree blueprint, biome data, harvest state machine, LOD/perf, foliage transparency system, implementation learnings | Very large (~840 lines) | No top version; mixes "Design" and "Implementation Learnings" |
| 12 | [Markdowns/UI.md](../Markdowns/UI.md) | UI reference: UIStyle, MainMenu, PlayerConsole, DisplayCards, OptionsMenu, ArenaUIHandler, Quest UI | Large (~450 lines) | v1.0 / 2025-01-10 |
| 13 | [Markdowns/UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) | Status of UI refactor (CycleSelector, MapSettingsHelper done; Debug autoload + PlayerConsole pending) | Small (~127 lines) | "Last Updated: 2025-01-10" |
| 14 | [Markdowns/WorldGeneration.md](../Markdowns/WorldGeneration.md) | Hex grid generation (offset/axial coords, noise terrain + height, farmstead planning, caching) | Large (~430 lines) | No version stamp |
| 15 | [Markdowns/procedural_character_framework.md](../Markdowns/procedural_character_framework.md) | Procedural code-generated low-poly character system (CreatureDefinition, ShapeAssembler, SkeletonInferer, AnimationController, editor plugin), with implementation order + AI prompting guide | Very large (~960 lines) | v0.4 / "Design Phase" |
| 16 | [Markdowns/FinishedProjects/ActorRefactorPlan.md](../Markdowns/FinishedProjects/ActorRefactorPlan.md) | The completed actor-directory restructure (Phase 1–11) | Large (~640 lines) | "Status: Phase 1-9 Completed, Partial Phase 11" / "REFACTOR COMPLETE" |
| 17 | [QuestSystem/README_CAMP_FIRE_SMOKE_PATCH.md](../QuestSystem/README_CAMP_FIRE_SMOKE_PATCH.md) | Patch notes: 3D fire/smoke replaces procedural campfire cylinder at quest camps | Small (~30 lines) | No date |
| 18 | [QuestSystem/README_QUEST_SPAWN_ADDON.md](../QuestSystem/README_QUEST_SPAWN_ADDON.md) | Patch notes: quest bounties now create goblin camps with QUEST CAMP markers via ArenaSpawner/QuestSpawnManager | Small (~30 lines) | No date |
| 19 | [addons/ziva_agent/README.md](../addons/ziva_agent/README.md) | Marketing README for third-party Ziva AI agent plugin | Small (~55 lines) | Third-party |
| 20 | [addons/.ziva_update_staging/addons/ziva_agent/README.md](../addons/.ziva_update_staging/addons/ziva_agent/README.md) | Duplicate of #19 in update-staging folder | Small (~55 lines) | Duplicate of #19 |
| 21 | [assets/generated/README.md](../assets/generated/README.md) | One-liner: "Experimental Assets ... art assets generated for the goat project" | 2 lines | n/a |

---

## 2. Intended Project Vision

Synthesized from the README, AGENTS.md and the Markdowns/ folder. **Quotes are literal**.

- Genre / pitch (README, lines 5–6):
  > "**Elementals** is an arena combat simulator that blends tactical hex-based combat with creature ranching and breeding mechanics. Lead your team of specialized goats (and other actors) through elemental battlefields..."
- Two-loop gameplay (README, "Core Gameplay Loops"):
  - Arena Combat Simulator on a "procedurally generated hexagonal arena" with elemental tile interactions (fire/water/grass/mud/stone) and dynamic actors (Farmers, specialized Goats, Goblins).
  - Ranching & Breeding loop between battles: "Pair Does and Bucks to produce offspring. Kids inherit traits and stats from their parents…"
- Architectural ethos (README, "Technical Features"):
  > "**Component-Based Architecture**: Actors and systems are built using modular components (Health, Mana, AI, Movement, etc.) for easy extensibility."
  > "**Advanced Hexagonal Grid**: Custom-built `ArenaGrid` handles noise-based generation, feature placement (trees, fences, houses), and efficient world-to-grid coordinate conversion."
  > "**Centralized Data Management**: `GoatManager` orchestrates sub-systems for Breeding, Economy, Herd state, and Persistence."
  (Note: see contradictions §9 — `GoatManager` is later renamed to `HerdManager` per Breeding.md.)
- Coworker overview (AGENTS.md, lines 5–13): hex tiles with mutable states; component-based actor system; AI FSM with states "idle, roam, chase, attack, flee, investigate, stunned, death"; tile signal system "for efficient proximity/trigger detection without per-frame distance calculations"; quest system + breeding.
- Roadmap (README, lines 51–56):
  > "* **Creature Capture**: Tools and mechanics to tame wild creatures encountered in the arena."
  > "* **Expanded Ranching**: More buildings (Fences, Barns) and interaction types."
  > "* **Deeper Genetic Traits**: More complex inheritance patterns and unique mutations."
  > "* **Elemental Magic**: More elemental types (Earth, Air) and complex tile reactions."
  > "* **Expanded Map Generation** I plan to rework the basic map generation to create a tesselating pattern with varying noisemaps for different biomes and map types to explore"
- World-expansion vision ([MapExpansion.md](../Markdowns/MapExpansion.md), §2): dynamic boundaries (stone/mountain/ocean/frontier gate), edge-to-edge rivers, height variation, expandable map edges (up to four cardinal directions), region streaming, **quest-driven** wall unlocks, and primary/dead-end/building-access road generation.
- Procedural character vision ([procedural_character_framework.md](../Markdowns/procedural_character_framework.md), "Vision"):
  > "A fully code-driven character generation and animation system for Godot 4. No external mesh files. Characters are defined by data (`Resource` files), assembled at runtime from procedural geometry, automatically rigged, and animated through IK and physics-layered motion. Changing a handful of parameters produces an entirely distinct creature."
- Settlement-side vision ([SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md), "Vision"):
  > "Transform Settlement from a single-screen manager into a light simulation game with a **dependency graph** at its core — buildings unlock from goat outputs, outputs feed the economy, and the settlement grows organically..."
  (Note: this doc describes a **React/JSX** project — see §9 for the contradiction with the Godot game.)
- Tree generation philosophy ([TreeGeneration.md](../Markdowns/TreeGeneration.md), §1):
  > "Trees should be generated independently from tile placement... Blueprint-driven construction... Harvest complexity... Two-phase harvest model: Felling and processing are distinct phases. ...Actor-agnostic interactions: Both the player and NPCs must be able to harvest trees."

---

## 3. Documented Completed Features

| Feature / system | Source | Exact quote |
|------------------|--------|-------------|
| Weapons + thrown weapon pickup loop | [README.md](../README.md) line 7 | "Weapons are working, I have thrown weapon mechanics in play that allow actors to pick up thrown weapons or shot arrows to use themselves." |
| Some abilities + stat system | [README.md](../README.md) line 8 | "A few abilities have been implemented and the stat system seems to be working as intended (so far)." |
| Hex grid procedural generation | [WorldGeneration.md](../Markdowns/WorldGeneration.md) §1, §3 | Describes `GridGenerator.initialize_grid()` end-to-end including coordinate conversion, terrain assignment via noise, farmstead planning, and a working `_radius_cache`. |
| ArenaGrid central orchestration | [Arena.md](../Markdowns/Arena.md) §1–4 | Documents working components: HexGridRenderer, TileSystem, ArenaPhysics, ArenaTileInteractionComponent, TileSignalComponent, ArenaSpawnerComponent, PlayerInputComponent, ArenaUIHandler, ArenaMinimapHandler, GridGenerator. |
| TileSignalComponent | [TileSignalComponent.md](../Markdowns/TileSignalComponent.md); [AGENTS.md](../AGENTS.md) §"Critical: Component Routing" | Treated as authoritative, in-use, with real API. AGENTS.md says: "ALL distance-related decisions must route through this component." |
| GameClockComponent (centralized tick clock) | [AGENTS.md](../AGENTS.md) §"Critical: Centralized Timing" | "**`res://Components/Arena/GameClockComponent.gd`** is the single source of truth for all game timing. **ALL timer logic must route through this component.**" Components currently using: "`StatusEffectComponent` — burn duration, damage ticks, splash sound timing". |
| Goblin camp quest-spawn pipeline | [README.md](../README.md) lines 58–130 (deep-dive); [QuestSystem/README_QUEST_SPAWN_ADDON.md](../QuestSystem/README_QUEST_SPAWN_ADDON.md); [QuestSystem/README_CAMP_FIRE_SMOKE_PATCH.md](../QuestSystem/README_CAMP_FIRE_SMOKE_PATCH.md) | README narrates a complete working flow (`QuestStarterKit` → `QuestSpawnManager` → `TileSignalComponent` → `ArenaSpawnerComponent`). Patch READMEs describe shipped changes ("Accepting a goblin quest now creates one or more visible goblin camps."). |
| Goblin camp 3D fire/smoke | [QuestSystem/README_CAMP_FIRE_SMOKE_PATCH.md](../QuestSystem/README_CAMP_FIRE_SMOKE_PATCH.md) | "Replaces the simple procedural campfire cylinder in goblin quest camps with the uploaded 3D fire/smoke scene." |
| Actor directory restructure (Phases 1–9) | [Markdowns/FinishedProjects/ActorRefactorPlan.md](../Markdowns/FinishedProjects/ActorRefactorPlan.md) lines 526–642 | "Status: Phase 1-9 Completed, Partial Phase 11" and an "Executed Changes Summary" with per-phase ✅ marks ending in "REFACTOR COMPLETE - all major goals achieved". |
| Breeding refactor — Phase 1 core infrastructure | [Breeding.md](../Markdowns/Breeding.md) "Implementation Status" + "Next Steps" | All ✅ items: "`ActorData` ... Done", "`GoatData` ... Done", "`BreedingComponent` ... Done", "`GeneticComponent` ... Done", "`GoatManager` → `HerdManager` ... Done", "`HerdComponent` ... Done", "Generic GameEvents ... Done". Also: "✅ Add generic `actor_selection_toggled` GameEvents signal (completed 2025-01-28)". |
| UI refactor — CycleSelector + MapSettingsHelper | [UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) | "COMPLETED: CycleSelector.gd with StationaryCycler for CharacterSelectCard; CharacterSelectCard refactored to use cyclers; MapSettingsHelper utility class; MainMenu simplified to use MapSettingsHelper". |
| Abilities — NimbleEscape, RedirectAttack, GoatCharge, Dash (data only) | [Abilities.md](../Markdowns/Abilities.md) "Existing Abilities" | Each documented with file path, actor type, action verbs and features (e.g., GoatCharge: "Physics-based charge movement", "Damage and stun application", "Terrain speed modifier support"). |
| HerdManager autoload renamed | [Breeding.md](../Markdowns/Breeding.md) Next Steps | "✅ Rename `GoatManager` → `HerdManager` (completed 2025-01-28)". [UI.md](../Markdowns/UI.md) "Autoloads Used by UI" already lists `HerdManager`. |

---

## 4. Documented Unfinished Features

| Feature / system | Source | Exact quote / status |
|------------------|--------|----------------------|
| Breeding mechanics | [README.md](../README.md) line 10 | "Actual breeding and capture mechanics are broken at the moment." |
| Capture mechanics | [README.md](../README.md) line 10 | (same line as above) |
| Ranch screen | [README.md](../README.md) line 45 | "3.  **The Ranch**: [Currently Busted] Select your team of up to 4 goats." |
| Farmer playability | [README.md](../README.md) line 44 | "Farmers and Goblins are currently working, playing farmer is for masochists." |
| `BreedableComponent` | [Breeding.md](../Markdowns/Breeding.md) "Not Yet Implemented" | "❌ Not created — Planned but not needed for Phase 1" |
| `TraitInheritanceEngine` | [Breeding.md](../Markdowns/Breeding.md) | "❌ Not created — Genetics calculator" |
| `GoblinData` / `ElementalData` | [Breeding.md](../Markdowns/Breeding.md) | "❌ Not created — Goblin-specific traits" / "Elemental-specific traits" |
| `CaptureComponent` | [Breeding.md](../Markdowns/Breeding.md) | "❌ Not created — Wild capture system" |
| `SpawnVarianceConfig` | [Breeding.md](../Markdowns/Breeding.md) | "❌ Not created — Stat variance for spawned creatures" |
| Breeding Phases 2–5 (UI generic, visual polymorphism, generic events, ActorFactory) | [Breeding.md](../Markdowns/Breeding.md) "Next Steps" | All listed with "⬜" boxes: "Refactor ActorCard to use ActorData generic", "Rename GoatRenderer → ActorCardRenderer", "Update Ranch.gd", "Refactor ActorVisualComponent.setup_visuals()", "Update ItemsAutoload.selected_goat → selected_actor_data", "Create ActorFactory pattern", "Refactor ArenaSpawner to use ActorFactory". |
| Capture system fully | [Capture.md](../Markdowns/Capture.md) | Document is design-only (no completion ticks); flow "encounter → restrain → drag → tame", restraint stacking, escape DC, drag mechanics, taming loyalty, all framed as plan with the line "By planning the capture tools, stacking mechanic, escape formulas, drag mechanics, and taming progression we can implement…". Also explicitly listed as ❌ in Breeding.md ("CaptureComponent — Not created"). |
| Map expansion plan (regions, rivers, roads, quest-driven gates) | [MapExpansion.md](../Markdowns/MapExpansion.md) §5 "Implementation Roadmap" | Forward-looking Week-1…Week-7 plan; no completion ticks anywhere. |
| Procedural Character Framework | [procedural_character_framework.md](../Markdowns/procedural_character_framework.md) | Header: "Status: Design Phase". 12-phase implementation order described, no phases marked done. |
| Tree generation new system (CSG blueprints, HarvestableComponent, BiomeData, TreeSpawner, LogPile) | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §10–12 | §10 lists "Components to Remove" (old `TreeStates/`, `TreeFeature.gd` state machine, sprite textures) and §12 enumerates "Next Steps" (define resources, build CSG trees, implement HarvestableComponent, build LogPile, implement TreeSpawner, connect actor targeting, tune parameters). Foliage visibility system §16 is fully described as design. §17 "Implementation Learnings" indicates some construction code has been built (CSG centering, foliage guarantee, oak-style extra foliage) but no top-level checklist confirms completion. |
| Settlement webapp (React/JSX) phases 1–6 | [SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) | "Goal: Break the monolithic JSX into the structure above without changing any behavior." Each phase introduces new state; no phase marked done. |
| UI refactor — Debug settings autoload, PlayerConsole refactor, MainMenu scene restructure | [UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) | "PENDING: MainMenu scene restructure (extract to MapSettingsController.tscn); Debug settings autoload; PlayerConsole refactoring"; "⏳ Move debug settings to autoload", "⏳ Update DebugOptionsController.gd", "⏳ (Optional) Scene restructure for MapSettingsController". |
| Earth & Air elementals, more elemental tile reactions | [README.md](../README.md) line 55 | "**Elemental Magic**: More elemental types (Earth, Air) and complex tile reactions." |
| Buildings beyond house+fence (Barns) | [README.md](../README.md) line 53 | "**Expanded Ranching**: More buildings (Fences, Barns) and interaction types." |

---

## 5. Documented Modular / Reusable Systems

What the docs explicitly call out as reusable, generic, or "actor-agnostic" — i.e. designed to live beyond one feature/project.

| Module | Source | What's reusable |
|--------|--------|-----------------|
| Component system on `Actor` base | [AGENTS.md](../AGENTS.md) lines 5–13; [Actor.md](../Markdowns/Actor.md) | All actors are built from interchangeable components (Health, Movement, Detection, Ability, StatusEffect, etc.). The "Adding a New Component" recipe in AGENTS.md is explicitly generic. |
| `AbilityComponent` + `AbilityAction` base | [Abilities.md](../Markdowns/Abilities.md) "Step-by-Step: Creating a New Ability" | Designed for arbitrary actors to mount arbitrary abilities. "Dynamic property lookup" used so abilities "work with any actor that has the expected component without direct type dependencies". |
| `TileSignalComponent` proximity hub | [TileSignalComponent.md](../Markdowns/TileSignalComponent.md); [AGENTS.md](../AGENTS.md) | Generic trigger registration with metadata. Examples already show six unrelated consumers: perception, AI dormant, static obstacles, projectiles, quest camps, status effects. |
| `GameClockComponent` central tick clock | [AGENTS.md](../AGENTS.md) §"Critical: Centralized Timing" | "**1 centralized clock, zero timer nodes per actor**" — meant for any system needing timing. |
| `HerdManager` (renamed from `GoatManager`) | [Breeding.md](../Markdowns/Breeding.md) "Phase 1" | The entire Phase-1 refactor reframes the herd singleton to work with any `ActorData` subclass. |
| Breeding system actor-agnosticism | [Breeding.md](../Markdowns/Breeding.md) "Core Philosophy" → "Actor-Agnostic Design" | Lists Goats, Goblins, Mimics, Elementals, Wildlife as targets of the same reproductive interface. |
| `BreedingProtocol` / `BreedableComponent` interface (planned) | [Breeding.md](../Markdowns/Breeding.md) | Interface "each actor type can implement according to its own biology" — sexual, asexual, elemental combination, gestation. |
| `TraitInheritanceEngine` (planned) | [Breeding.md](../Markdowns/Breeding.md) | "Calculate inheritance of traits across any `ActorData` subclass." Modes: MENDELIAN, QUANTITATIVE, ENVIRONMENTAL, MUTATIONAL. |
| `ActorFactory` (planned, Phase 5) | [Breeding.md](../Markdowns/Breeding.md) | Scene mapping by actor type to remove hardcoded spawning matches. |
| `CycleSelector` / `StationaryCycler` | [UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) §"Completed: CycleSelector (Phase 2)" | "Created reusable cycling utility... Consistent behavior across all selectors". |
| `MapSettingsHelper` | [UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) §"Completed: MapSettingsHelper" | Static utility class for collecting / normalizing / applying map settings. |
| `UIStyle` central styling | [UI.md](../Markdowns/UI.md) §"Central Styling: UIStyle.gd" | Color constants + StyleBoxFlat factories shared across all panels. |
| `DisplayCardBase` | [UI.md](../Markdowns/UI.md) §"Display Card System" | Base class extended by WeaponCard, AbilityCard, ActorCard. |
| `HarvestableComponent` (planned) | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §8.5 | Designed to be attachable to trees **and** log piles — "Log piles are themselves `HarvestableComponent` entities". Actor-agnostic damage acceptance. |
| `BiomeData` / `TreeBlueprint` resources | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §6, §3 | Data-driven biomes (oak forest, boreal woodland) and blueprint-driven trees. |
| `CreatureDefinition` + generator stack | [procedural_character_framework.md](../Markdowns/procedural_character_framework.md) "Design Principles" | "Zero art assets... Single generator, infinite output — one `BipedGenerator` produces humans, goblins, aliens, giants by varying parameters". The editor plugin is decoupled — "the plugin can be removed from a shipped game by deleting `addons/procedural_creature/editor/` — runtime is unaffected". |
| `RegionManager` / `RegionData` (planned) | [MapExpansion.md](../Markdowns/MapExpansion.md) §3.4, §4 | Singleton-driven region streaming intended to support "potentially unlimited expansion". |
| `RoadGenerator` (planned) | [MapExpansion.md](../Markdowns/MapExpansion.md) §3.7 | Architecture explicitly says "must support N-edge roads for future complex maps". |
| `CaptureComponent` (planned) | [Capture.md](../Markdowns/Capture.md) §"CaptureComponent Responsibilities"; [Breeding.md](../Markdowns/Breeding.md) | Designed to apply to any wild actor. |

---

## 6. Documented Procedural Systems

| System | Source | Procedural inputs / outputs |
|--------|--------|------------------------------|
| Hex arena terrain (grass/dirt) | [WorldGeneration.md](../Markdowns/WorldGeneration.md) §3.2 | `FastNoiseLite` Perlin noise + `dirt_threshold` from `GameSettings`. |
| Hex tile heights (levels 0–3) | [WorldGeneration.md](../Markdowns/WorldGeneration.md) §3.3 | Same noise field mapped `int(clamp(floor((nv + 1.0) * 2.0), 0, 3))`. |
| Stone boundary wall | [WorldGeneration.md](../Markdowns/WorldGeneration.md) §3.1, §3.4 | Tiles outside circular radius become STONE; stone post-processed to match neighbor heights. |
| Farmstead interior / perimeter / house placement | [WorldGeneration.md](../Markdowns/WorldGeneration.md) §4; [Arena.md](../Markdowns/Arena.md) | BFS flood-fill from grid center, shuffled neighbors for "slightly irregular farmstead shape", random perimeter tile for house. |
| Grass patches | [Arena.md](../Markdowns/Arena.md) §"Visual polish" | `GrassPatchLayer` "scatters blobs across green tiles, and rebuilds when tile states change". |
| Trees — current sprite system | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §9.1 | Flat 5% probability roll per grass tile outside farmstead. Explicitly tagged "a starting point, not final placement logic." |
| Trees — planned blueprint system | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §3 + §6 | `TreeBlueprint` (trunk segments, branches, foliage layers, jank, variance) + `BiomeData` (valid tiles, spawn_density). |
| Goblin quest camps | [README.md](../README.md) lines 68–86; [TileSignalComponent.md](../Markdowns/TileSignalComponent.md) "Quest Camp Discovery" example | `QuestSpawnManager` picks tiles near map edges round-robin per cardinal direction; each tile registers a proximity trigger (radius 8) that triggers visuals + spawns. |
| Ability assignment | [Abilities.md](../Markdowns/Abilities.md) "Default Setup Logic" | For goblins, 50/50 RNG between NimbleEscape and RedirectAttack at component setup. |
| Goat character traits / colors / horns / body / patterns | [Breeding.md](../Markdowns/Breeding.md) "GoatData" + parent-blending engine | Existing types randomized at spawn; offspring blended at breed time. |
| Spawn variance for elementals/summoned beings (planned) | [Breeding.md](../Markdowns/Breeding.md) §"Spawn Variance System" | `SpawnVarianceConfig` with UNIFORM / GAUSSIAN / BOUNDED distributions, per-stat overrides. |
| Region / map expansion (planned) | [MapExpansion.md](../Markdowns/MapExpansion.md) | Height map generation, river routing edge-to-edge, road generation primary + building access + dead-end. |
| Procedural code-built characters (planned) | [procedural_character_framework.md](../Markdowns/procedural_character_framework.md) | `SurfaceTool`/`ArrayMesh` low-poly geometry, segmented limbs, three-tier `DetailLevel` (SIMPLE / MODERATE / COMPLEX) cascading mesh density + animation richness. |
| Procedural animation | [procedural_character_framework.md](../Markdowns/procedural_character_framework.md) §"AnimationController" | No `AnimationPlayer`; IK foot placement, body lean, spine wave, jiggle solver, idle variation, look-at — all per-frame. |

---

## 7. Documented Low-Resource / Performance Requirements

| Requirement | Source | Exact directive |
|-------------|--------|------------------|
| No per-frame distance math — route through TileSignalComponent | [AGENTS.md](../AGENTS.md) §"Critical: Component Routing", line 391 | "1. **Avoid per-frame distance calculations** — use `TileSignalComponent` triggers" |
| One centralized clock, zero per-actor timers | [AGENTS.md](../AGENTS.md) §"Why This Matters" | "Before: 50 actors × 4 timers = 200+ timer nodes (massive overhead). After: 1 centralized clock, zero timer nodes per actor." |
| Never use `Timer` nodes on actors for game logic | [AGENTS.md](../AGENTS.md) §"Anti-Patterns" | "Do NOT add Timer nodes to actors for game logic … Do NOT use _physics_process for game logic timing — all timing goes through GameClockComponent" |
| Use BFS for area queries, not brute force | [AGENTS.md](../AGENTS.md) line 393 | "Use BFS for area queries — `get_tiles_in_radius()` not brute force scans" |
| Lazy initialization | [AGENTS.md](../AGENTS.md) line 394 | "Lazy initialization — defer non-essential setup to `call_deferred()`" |
| Pool projectiles/particles | [AGENTS.md](../AGENTS.md) line 395 | "Pool objects where applicable — projectiles, particles" |
| Cache `HexTileData` values | [AGENTS.md](../AGENTS.md) line 392 | "Cache frequently accessed values — especially on `HexTileData`" |
| TileSystem uses timers (not per-frame loops) for tile reactions | [Arena.md](../Markdowns/Arena.md) §"Component summary" | "`TileSystem`: Schedules and processes tile reactions (fire spreads/extinguishes, mud dries, puddles drain) using timers rather than per-frame loops". |
| Three-level GridGenerator caching | [WorldGeneration.md](../Markdowns/WorldGeneration.md) §6 | `_neighbor_cache`, `_tile_lookup` (O(1) Vector2i → tile), `_radius_cache` (precomputed offsets for radii 0–20). |
| `ArenaMinimapHandler` throttles updates | [Arena.md](../Markdowns/Arena.md) §"Component summary" | "throttles updates, and responds to quest signals". |
| Tile-signal per-tile actor tracking (no scan) | [TileSignalComponent.md](../Markdowns/TileSignalComponent.md) §"Key Properties" | Maintains `_actor_tiles` + `_tile_to_actors` so distance checks only re-run on actor `tile_changed`. |
| Tree CSG → bake to MeshInstance3D in production | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §13.1 | "Development: CSG for rapid prototyping... Production: Replace CSG with pre-baked `MeshInstance3D` after finalizing blueprints. No runtime CSG modification." |
| Tree LOD levels 0–3 with distance thresholds | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §13.2 | LOD0 0–30 / LOD1 30–60 / LOD2 60–100 / LOD3 100+ hidden. "Trees auto-switch to LOD0 when any actor approaches for harvesting". |
| Spread tree spawning over frames | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §13.3 | `SPAWN_BATCH_SIZE := 10` with `await get_tree().process_frame`. |
| Shared materials + static collider toggling + shadow culling + visible-tree cap | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §13.4 | "Hard cap of ~200 trees visible at once; culling activates beyond that". |
| Foliage transparency without per-pixel raycasts | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §16.7 | "No per-frame raycasting: Occlusion checks use AABB overlap in screen space, not pixel-level ray tests". |
| Detail-level cascade (SIMPLE/MODERATE/COMPLEX) for procedural characters | [procedural_character_framework.md](../Markdowns/procedural_character_framework.md) §"Detail Level System" | Master switch controls limb sides (4/6/8), torso sides (5/8/10), head detail, eye meshes, extras, skeleton bones, IK, body lean, spine wave, jiggle, idle variation, look-at. Designed for runtime distance-based switching and "mobile defaults to SIMPLE for crowds". |
| Map expansion: stream regions off main thread, LRU-cache active regions | [MapExpansion.md](../Markdowns/MapExpansion.md) §6 "Risks and Mitigations" | "Pre-generate regions off the main thread, stream in pieces, and cache results"; "Limit active regions with an LRU cache and unload distant areas automatically". |

---

## 8. Documented Coworker / Implementation Rules

Extracted from [AGENTS.md](../AGENTS.md) and other rule-bearing docs.

### Core routing rules (AGENTS.md)

- **All distance / proximity work goes through `Components/Arena/TileSignalComponent.gd`.** Concrete consumers: Detection, attack range, trigger zones, nearest-enemy queries, area effects.
- **All timing goes through `Components/Arena/GameClockComponent.gd`.** Use `Actor.register_tick(callback, interval)` and `unregister_tick(id)`; never spawn `Timer` nodes on actors; never accumulate in component `_physics_process`.
- Visual-only per-frame effects: "use Tweens instead of `_physics_process`".

### Script-documentation requirements (AGENTS.md §"Script Documentation Requirements")

Every script MUST include:
- Class docstring (`## Brief one-line purpose.` etc.).
- Signal docstrings with parameter descriptions.
- Variable docstrings with units when applicable.
- Function docstrings (brief + edge cases + param/return descriptions).
- Inline comments that explain "WHY this is done this way, not WHAT it does".

### Coding conventions (AGENTS.md §"Coding Conventions")

- `class_name` at top of every script; `_` prefix for private variables; variables grouped with `@export_group`.
- Component pattern: every component takes `actor: Node3D` and has `setup(p_actor)`.
- Hex grid conventions: axial coords (`Vector2i`); use `TileSignalComponent._get_hex_distance()` or `ArenaGrid.get_tiles_in_radius()`; never roll your own.
- State Machine pattern (AI states inherit from `AIState.gd` with `enter`/`exit`/`physics_update`).
- Signal connections: prefer `.bind()` over closures.
- Error handling: always `is_instance_valid()` and `get_node_or_null` for optional nodes.

### Common patterns (AGENTS.md §"Common Patterns")

- Adding a new component: declare on `Actor.gd`, init in `_setup_components()` with `_add_comp(NewComponent.new()).setup(self)`.
- Adding an AI state: extend `AIState.gd`, register in `ActorAIController._init_state_machine()`.
- Adding a tile state: add to `tile_constants.gd` enum, update `HexTileData._sync_type()`, add behavior in `TileSystem.gd`, handle in `ArenaGrid.set_tile_state()`.

### Testing & questions (AGENTS.md §"Testing Guidelines", §"Questions This Agent Should Ask")

- Tests follow `test_*.gd` naming. Component tests verify `setup()`, signal emissions, edge cases. Scene tests verify node positions, attached scripts, export wiring.
- "I may ask clarifying questions if: 1. A requested feature spans multiple systems unclear how to integrate; 2. There's conflict between existing patterns and new requirements; 3. A script modification could break existing functionality; 4. The user's intent maps to multiple possible implementations".

### Sync rule (Abilities.md / Actor.md / UI.md headers)

Verbatim in the version-control comment block of each of those reference docs:
> "SYNC RULE: When modifying [actor/ability/UI] structure (add/remove/modify components, signals, properties, methods, or actions), update this document in the same commit. Keep version numbers in sync across files."

### Procedural-Character AI-prompting rules ([procedural_character_framework.md](../Markdowns/procedural_character_framework.md) §"AI Prompting Guide")

- "Paste the relevant section of this document as context"; "One phase per session"; "Name files explicitly"; "State what must NOT be done".
- A do/don't table: do paste doc sections; don't ask AI to remember between sessions. Do name files + class_name + method signatures; don't leave them open-ended. State forbidden approaches; don't assume AI won't grab AnimationPlayer.

### Tree-system rules ([TreeGeneration.md](../Markdowns/TreeGeneration.md))

- Hard constraint §3.1.1: "The trunk of a tree must **always** have its origin (one end of the cylinder) fixed to the ground."
- §3.1.2 trunk segment chaining algorithm: first segment origin at Y=0; each subsequent origin = previous terminal; jank rotations accumulate incrementally; cylinder `height = origin.distance_to(terminal)`.
- §8.2 HP-pool harvest: any actor can damage any tree at any time; no ownership.
- §8.4 felling uses `AnimationPlayer`, **not** tween or `_process`-rotated.
- §8.8 day reset: trees not in `STANDING` (or with `current_hp < max_hp`) reset on new day. Log piles persist.
- §9.3 1:1 tile-to-tree ratio: "no tile can hold more than one tree".
- §17 implementation learnings: `CSGCylinder3D.position` is the cylinder center, not an end; every branch and the topmost trunk always get at least one foliage sphere; foliage placement uses 0.30–0.60 outward ratio of sphere radius; oak-style extra foliage uses 16-candidate distance maximization.

### Patch READMEs ([QuestSystem/README_*.md](../QuestSystem))

Style is "drop this patch into the root of the Godot project and allow overwrite", with explicit "Patched files" list and a numbered "Test" recipe — implying that bespoke fixes are shipped as overwritable bundles.

---

## 9. Contradictions, Stale Plans, Duplications

### 9.1 Contradictions

| # | Conflict | Sources |
|---|----------|---------|
| C1 | README says "`GoatManager` orchestrates sub-systems" but Breeding.md says it has already been renamed `HerdManager`. UI.md already lists `HerdManager` as an autoload. | [README.md](../README.md) line 36 vs [Breeding.md](../Markdowns/Breeding.md) line 33 ("`GoatManager` → `HerdManager` ... ✅ Done") and [UI.md](../Markdowns/UI.md) §"Architecture Diagram" ("HerdManager — Goat selection management"). |
| C2 | Actor.md declares `Actor extends CharacterBody2D` and uses `Vector2` damage knockback; AGENTS.md and every other doc treat the game as fully 3D (`Node3D`, `Vector3`, `CharacterBody3D` ability examples, hex tiles with 3D height). | [Actor.md](../Markdowns/Actor.md) line 53 ("**Type:** `CharacterBody2D`") and line 77 (`Vector2.ZERO` knockback) vs [AGENTS.md](../AGENTS.md) (3D throughout) and [Abilities.md](../Markdowns/Abilities.md) line 34 ("Actor (CharacterBody3D)"). |
| C3 | Actor.md lists components like `CommunicationComponent`, `SkillCheckComponent`, `TerrainSpeedModifierComponent`, `BobComponent`, `GoatScreamComponent`, `HealthBarPool`, `ManaComponent` etc.; AGENTS.md does not mention most of those and uses a slimmer component list. The two docs disagree on which components actually exist on `Actor`. | [Actor.md](../Markdowns/Actor.md) §"File Structure" / §"Components" vs [AGENTS.md](../AGENTS.md) §"Project Structure" + §"Components Currently Using GameClock". (AGENTS.md also notes only `StatusEffectComponent` is currently using GameClock — implying many components called out in Actor.md may not exist or are not wired.) |
| C4 | Actor.md still references `ability_component.ability_scene = preload(...)` and `try_activate_ability()` — neither appears in Abilities.md, which uses `execute_ability(type, value)`. | [Actor.md](../Markdowns/Actor.md) line 418–420 vs [Abilities.md](../Markdowns/Abilities.md) line 100–104. |
| C5 | Breeding.md "Old Plan (Abandoned)" warning conflicts with later sections of the same doc that still describe `BreedingManager`, `TraitInheritanceEngine`, `BreedableComponent`, `CaptureComponent`, etc. as the actual plan. The "abandoned" plan and the "current" plan are intermixed. | [Breeding.md](../Markdowns/Breeding.md) §"Migration Plan: Actor-Agnostic Refactor" → "Old Plan (Abandoned)" vs §"Breeding Component Architecture", §"TraitInheritanceEngine Design", §"Capture System". |
| C6 | Breeding.md declares `BreedableComponent` "❌ Not created — Planned but not needed for Phase 1" and later in the same doc also says "❌ NOT NEEDED: ActorData provides base functionality"; yet other sections of the same doc still talk about `BreedableComponent` as the breeding interface and use it in code samples. | [Breeding.md](../Markdowns/Breeding.md) lines 40, 727 vs §"BreedableComponent (New)" + §"BreedingComponent Architecture" + State-Machine diagram. |
| C7 | Capture.md is presented as a coherent design plan with no completion markers; Breeding.md lists `CaptureComponent` as ❌ not created; README also says capture is "broken". All three agree it is unfinished, but Capture.md doesn't say so explicitly — could mislead a reader into thinking it's the implementation reference. | [Capture.md](../Markdowns/Capture.md) (no status header) vs [Breeding.md](../Markdowns/Breeding.md) "Not Yet Implemented" vs [README.md](../README.md) line 10. |
| C8 | SettlementImplementationPlan.md describes the Settlement as a **React/JSX** webapp (`Settlement.jsx`, `useState`, `localStorage`); the rest of the project is a Godot 4 game. It's unclear whether this doc is intended for this repo at all. No file under `Settlement/` appears in the inventory implied by README/AGENTS.md. | [SettlementImplementationPlan.md](../Markdowns/SettlementImplementationPlan.md) lines 1–10 vs every other doc. |
| C9 | MapExpansion.md is dated "2023-11-XX" but introduces concepts (RegionData, RegionManager, RoadGenerator) that don't appear in current architecture docs; the date looks like a placeholder rather than a real date — confusing for staleness assessment. | [MapExpansion.md](../Markdowns/MapExpansion.md) header. |
| C10 | TreeGeneration.md §10 "Removal Plan (Old Tree System)" lists `TreeFeature.gd` and `TreeStates/` for removal once the new system lands; AGENTS.md §"Project Structure" still lists `Play Space/TreeStates/` as part of the live project structure; Arena.md still refers to `TreeFeature` and `TreeStates` as integration points (§"Integration points & helpers"). The two systems coexist in the docs. | [TreeGeneration.md](../Markdowns/TreeGeneration.md) §10.1 vs [AGENTS.md](../AGENTS.md) §"Project Structure" vs [Arena.md](../Markdowns/Arena.md) §"Integration points & helpers". |
| C11 | TreeGeneration.md section numbering jumps (§13 → §14 missing → §16; §15 also missing as a top-level header but §15.4 appears inside §17). Probably just stale numbering, but means readers may think a section was lost. | [TreeGeneration.md](../Markdowns/TreeGeneration.md) (compare §13, §16, §17). |
| C12 | UI.md lists `ActorCard` as supporting both `GoatData` and runtime `Actor`; Breeding.md "Phase 2" says ActorCard still has a `goat_data` alias to remove. Hard to tell from docs alone whether the refactor is partially done. | [UI.md](../Markdowns/UI.md) §"ActorCard" vs [Breeding.md](../Markdowns/Breeding.md) Phase-2 todo "Refactor ActorCard to use `ActorData` generic". |
| C13 | AGENTS.md says directory layout uses `Components/ActorComponents/...`, while Actor.md File Structure section under "Source Code" puts `Components/ActorComponents/` at root — but the **completed** ActorRefactorPlan in `Markdowns/FinishedProjects` says "Components/ActorComponents/ paths intentionally kept (actor-specific components)". That's fine, but it means the path discussion is scattered across three docs and any reader has to assemble it. | [AGENTS.md](../AGENTS.md) §"Project Structure" + [Actor.md](../Markdowns/Actor.md) §"File Structure" + [Markdowns/FinishedProjects/ActorRefactorPlan.md](../Markdowns/FinishedProjects/ActorRefactorPlan.md) "Remaining Items". |

### 9.2 Stale plans

| # | Plan | Status / staleness signal |
|---|------|---------------------------|
| S1 | "Old Plan (Abandoned)" inside [Breeding.md](../Markdowns/Breeding.md) — "The original plan called for creating `BreedableComponent.gd`, `BreedingManager.gd`, etc. as new files. This has been superseded by the Actor-Agnostic Refactor Plan above." Yet most of the document still uses the abandoned terminology. |
| S2 | [MapExpansion.md](../Markdowns/MapExpansion.md) calendar is 1-week-per-phase with dates "Week 1…Week 7" and a placeholder doc date — no progress markers; cannot tell what's been built vs not. |
| S3 | [Markdowns/UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) "STATUS: PARTIALLY COMPLETED" is the only timestamped progress doc; safe but small. Suggests other plan docs should adopt the same status header. |
| S4 | [Markdowns/FinishedProjects/ActorRefactorPlan.md](../Markdowns/FinishedProjects/ActorRefactorPlan.md) is correctly archived to `FinishedProjects/`. Establishes a precedent that none of the other plan docs follow. |
| S5 | The actor refactor doc concludes with "REFACTOR COMPLETE - all major goals achieved" but two narrative docs ([AGENTS.md](../AGENTS.md), [Actor.md](../Markdowns/Actor.md)) still disagree on file paths and component lists — see C2, C3, C13. Indicates the docs were not fully synced after the refactor. |

### 9.3 Duplications

| # | Duplicate | Sources |
|---|-----------|---------|
| D1 | The Ziva agent README appears twice. | [addons/ziva_agent/README.md](../addons/ziva_agent/README.md) and [addons/.ziva_update_staging/addons/ziva_agent/README.md](../addons/.ziva_update_staging/addons/ziva_agent/README.md). Bit-identical content. |
| D2 | The breeding refactor file structure appears in two doc sections ([Breeding.md](../Markdowns/Breeding.md) §"Target Architecture" + §"File Structure") and in [UI.md](../Markdowns/UI.md) §"Autoloads Used by UI". They mostly agree, but tables are partly redundant. |
| D3 | The actor component listing appears in [Actor.md](../Markdowns/Actor.md), [AGENTS.md](../AGENTS.md), and (partially) [UI.md](../Markdowns/UI.md) — three sources of partial truth that don't agree (see C3). |
| D4 | The quest-camp pipeline narrative is in [README.md](../README.md) and in [QuestSystem/README_QUEST_SPAWN_ADDON.md](../QuestSystem/README_QUEST_SPAWN_ADDON.md); not strictly duplicates but overlapping. README also imports the patch README text into its own bottom half. |
| D5 | Capture is described in two places: [Capture.md](../Markdowns/Capture.md) (full design) and [Breeding.md](../Markdowns/Breeding.md) §"Capture System" (similar but shorter design with a different `CaptureComponent` API — `attempt_capture(capture_item)` + loyalty math vs `ActorState` machine + restraint stacking). They are not compatible; one favors loyalty-driven taming with capture items, the other an `ActorState` lifecycle with stacked physical restraints. |
| D6 | "Procedural character framework" overlaps thematically with [Actor.md](../Markdowns/Actor.md)'s visual section (`GoatVisuals`, `GoblinModel`, etc.). Procedural framework would replace existing models — no doc reconciles this. |

---

## 10. Documentation-Says-We-Still-Need-This Checklist

Sourced strictly from the docs above. Roughly ordered by how directly the docs flag each item.

### P0 — Explicitly broken / called out in README

1. **Fix breeding mechanics.** "Actual breeding and capture mechanics are broken at the moment." ([README.md](../README.md) line 10.)
2. **Fix capture mechanics.** Same line as above; also the entire [Capture.md](../Markdowns/Capture.md) design and [Breeding.md](../Markdowns/Breeding.md) Capture section presume `CaptureComponent` doesn't exist.
3. **Fix the Ranch screen.** "[Currently Busted] Select your team of up to 4 goats." ([README.md](../README.md) line 45.)
4. **Make Farmer actually playable** (currently "for masochists"). ([README.md](../README.md) line 44.)

### P1 — Breeding Phase-2 → Phase-5 refactor (in progress)

5. **Phase 2 — Generic UI Layer**: refactor `ActorCard` to take `ActorData`; rename `GoatRenderer` → `ActorCardRenderer`; update `Ranch.gd` for generic actor selection. ([Breeding.md](../Markdowns/Breeding.md) §"Next Steps".)
6. **Phase 3 — Visual Polymorphism**: refactor `ActorVisualComponent.setup_visuals()` to dispatch on `get_actor_type()`; optional `VisualConfig` resource. (Breeding.md.)
7. **Phase 4 — Signals & Events**: finish migrating GameEvents to actor-agnostic signals; `ItemsAutoload.selected_goat` → `selected_actor_data`. (Breeding.md.)
8. **Phase 5 — Spawning & Factory**: create `ActorFactory`; refactor `ArenaSpawner` to use it instead of `match type`. (Breeding.md.)
9. **Post-refactor — implement `TraitInheritanceEngine`**, `GoblinData`, `ElementalData`, `CaptureComponent`, capture tools/items, `SpawnVarianceConfig`. (Breeding.md "Future".)

### P2 — UI refactor pending tasks

10. **Move debug settings to an autoload** (Option A: extend `GameSettings`; Option B: new `DebugSettings`); update `DebugOptionsController.gd`. ([UI_Refactoring_Plan.md](../Markdowns/UI_Refactoring_Plan.md) §"Pending: Phase 3".)
11. **(Optional) MainMenu scene restructure** — extract map settings to `UI/MapSettingsController.tscn`. (UI_Refactoring_Plan.md §"Pending: Phase 1 Full".)
12. **PlayerConsole refactor** — extract `WeaponListPanel.gd` and/or `CardDisplayPanel.gd`, or reduce coupling via events. (UI_Refactoring_Plan.md §"Pending: Phase 4".)

### P3 — Tree generation system migration

13. **Define resources**: `TreeBlueprint.tres`, `BiomeData.tres`. ([TreeGeneration.md](../Markdowns/TreeGeneration.md) §12 + §11.)
14. **Build CSG-driven `TreeFeature`** with `HarvestableComponent`. (§8.5, §12.)
15. **Build `LogPile` scene** with its own `HarvestableComponent`. (§8.7, §12.)
16. **Implement `TreeSpawner` service** (replace `GridGenerator.spawn_initial_trees()` 5% roll). (§9.2, §12.)
17. **Wire actor targeting** so player + NPCs can select harvestable entities with equipped tools. (§8.1, §12.)
18. **Delete old tree system** (`TreeStates/`, sprite textures, `TreeFeature` state machine) once new system lands. (§10.)
19. **Implement Foliage Visibility / `VisibilityManager`** singleton with AABB-based occlusion of player + spotted enemy, lerped opacity. (§16.)
20. **Apply tree LOD switching, spawn budgeting, and shared materials** per §13.

### P4 — Map expansion plan

21. **Define `RegionData` schema** + editor inspector. ([MapExpansion.md](../Markdowns/MapExpansion.md) §5 Week 1.)
22. **Prototype height variation** (ravines/cliffs/hills). (§5 Week 2.)
23. **Prototype edge-to-edge river routing** + cross-region continuity. (§5 Week 3.)
24. **Build `RegionManager`** for adjacent-region loading + transitions. (§5 Week 4 + §3.4.)
25. **`RoadGenerator` primary roads** (edge-to-edge, multi-edge-ready) + dead-end roads + building-access roads. (§3.7, §5 Weeks 4–6.)
26. **Quest-driven wall destruction** flipping edges from wall to gateway. (§3.6, §5 Week 7.)
27. **Replace stone walls with mountains/oceans/frontier-gate edge variations.** (§3.1.)

### P5 — Procedural Character Framework (entire system, Design Phase)

28. **Phase 1 — `CreatureDefinition`** Resource with all enums + property groups + `duplicate_definition()`. ([procedural_character_framework.md](../Markdowns/procedural_character_framework.md) §"Phase 1".)
29. **Phase 2 — `LimbBuilder`** (flat-shaded tapered cylinders via `SurfaceTool`).
30. **Phase 3 — `TorsoBuilder`, `HeadBuilder`, `ExtrasBuilder`.**
31. **Phase 4 — `BoneAnchor` + `ShapeAssembler`** (deterministic).
32. **Phase 5 — `CreatureGenerator`** orchestrator node + runtime `set_detail_level()`.
33. **Phase 6 — `SkeletonInferer`** auto-rigger.
34. **Phase 7 — `CharacterDesignerDock`** editor plugin shell + sliders + `EditorUndoRedoManager` integration.
35. **Phase 8 — `DefinitionSerializer`** save/load + template library (`biped_neutral`, `_stocky`, `_lanky`, `_hunched`, `_beast`).
36. **Phase 9 — `CreatureGizmoPlugin`** viewport handles (head scale → torso → arm → leg → spine bend).
37. **Phase 10 — `LocomotionSystem` + `FootPlacement`** (MODERATE).
38. **Phase 11 — `SecondaryMotion`, `BehaviourLayer`, `JiggleSolver`** (COMPLEX).
39. **Phase 12 — Integration + demo scene** + all `DetailLevel` transitions tested.

### P6 — Doc hygiene (called out implicitly by SYNC RULE / staleness)

40. **Reconcile Actor.md** (3D not 2D; component list; ability API). ([Actor.md](../Markdowns/Actor.md) — see C2, C3, C4.)
41. **Update README** to use `HerdManager` instead of `GoatManager`. ([README.md](../README.md) line 36 — see C1.)
42. **Decide whether `Markdowns/SettlementImplementationPlan.md` belongs in this repo**; if yes, mark its language/runtime and explain how it interacts with the Godot game (see C8).
43. **Reconcile Capture vs Breeding-Capture API**: one canonical capture flow (loyalty + items vs ActorState restraint stack). (See D5.)
44. **Apply the SYNC RULE retroactively** to bring Abilities/Actor/UI version logs back in line with current code (these headers explicitly require it).
45. **Remove the duplicate Ziva README** in `.ziva_update_staging/` or document why staging keeps a copy. (See D1.)
46. **Add a status header to MapExpansion.md, TreeGeneration.md, Capture.md, Arena.md, WorldGeneration.md, TileSignalComponent.md**, matching the format used by `UI_Refactoring_Plan.md` ("STATUS: …", "Last Updated: …").

### P7 — Roadmap items from README that are not yet decomposed in design docs

47. **Earth and Air elementals + complex tile reactions.** ([README.md](../README.md) line 55.)
48. **Barns and additional ranch buildings.** ([README.md](../README.md) line 53.)
49. **Tesselating-pattern biome map.** ([README.md](../README.md) line 56.) — Partially covered by MapExpansion.md but README phrases it more loosely (biomes + map types to explore).

---

*End of Agent 1 documentation audit.*
