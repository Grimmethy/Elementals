# Agent 3 — Modular Procedural Implementation Plan

> **Inputs synthesized:**
> - `docs/AGENT_1_DOCUMENTATION_AUDIT.md` (doc-truth)
> - `docs/AGENT_2_CODEBASE_AUDIT.md` (code-truth)
>
> **Authority rule:** When the two disagree, Agent 2 (code-truth) wins and the doc is added to Phase 0 hygiene tasks.
> All paths are repo-relative. Per-task fields use a compact two-column table.

---

## 1. Synthesis Summary

Agent 1 (docs) and Agent 2 (code) substantially agree on what is broken, what is missing, and what the architectural vision is — but they disagree on **paths and component names**, with the docs lagging behind a refactor that landed in code. Agent 2 confirms the README's "breeding/capture broken" + "Ranch busted" claims and locates the root cause: `Components/Arena/ArenaUIHandler.gd:107` calls `change_scene_to_file("res://Ranch/Ranch.tscn")` against a path that does not exist (the real scene is `Components/BreedingComponents/Ranch/Ranch.tscn`). Agent 1 catalogs documentation drift (Actor.md is still 2D, AGENTS.md cites the wrong GameClockComponent path, SettlementImplementationPlan.md is for a React/JSX project, Breeding.md interleaves "abandoned" and "current" plans), and Agent 2 catalogs filesystem drift (30+ orphan `.uid` files at root, 8 editor-crash `.tmp` files, leftover 2D `player.gd`). The two converge on the same anti-pattern: the very components that AGENTS.md designates as the authority for proximity and timing (`TileSignalComponent`, `DetectionComponent`) **violate** the "no Timer nodes on actors" rule themselves. Everything else in the audits feeds one of the seven phases below.

**Cross-audit conflicts resolved by this plan:**

| # | Conflict | Resolution |
|---|----------|-----------|
| R1 | Capture API: Capture.md (loyalty + items) vs Breeding.md (`ActorState` enum + restraint stacking) | Adopt **Breeding.md's `ActorState` model** as canonical — it composes with the existing AI FSM and the in-flight ActorData refactor. Capture.md is deprecated and moved to `Markdowns/FinishedProjects/` or rewritten in Phase 0. |
| R2 | Actor.md says 2D / Vector2; AGENTS.md and all code is 3D | Code wins. Rewrite Actor.md Phase 0 task. |
| R3 | AGENTS.md says `Components/Arena/GameClockComponent.gd`; code has `Components/GameClockComponent.gd` | Code wins. AGENTS.md patched Phase 0. |
| R4 | Breeding.md says `GoatManager` already renamed `HerdManager`; README still says `GoatManager` | Both code and Breeding.md agree — README is stale. Patch README Phase 0. |
| R5 | TreeGeneration.md §10 marks old `TreeStates/` for deletion; AGENTS.md still lists it | Agent 2 confirms `src/trees/` is the live system. Delete old TreeStates folder + update AGENTS.md project structure Phase 0/Phase 2. |
| R6 | SettlementImplementationPlan.md is for a React/JSX webapp, not Godot | Move out of `Markdowns/` or annotate as "Not part of this repo" header in Phase 0. Excluded from all implementation phases. |

---

## 2. Phased Roadmap

Each task carries the full 12-field schema as a two-column table. `N/A` is the correct value when a field truly does not apply (e.g. "Procedural approach" on an orphan-file deletion).

### Phase 0 — Safety & Source-of-Truth Cleanup

Pure-hygiene work. Zero behavioral change, except the Ranch-return fix (which is a one-line scene path correction that restores documented intent). All Phase 0 tasks are **Do now**.

#### 0.1 Delete orphan `.uid` files

| Field | Value |
|---|---|
| Reason it matters | 30+ stale `.uid` orphans (Agent 2 §5.3) confuse contributors and survive merges. Harmless to Godot but signal real refactor sweeps that left rot behind. |
| Source | Agent 2 §5.2, §5.3, §5.4, Appendix A |
| Files likely affected | Root `*.gd.uid` (8 `test_*.gd.uid`, `ArenaMinimapHandler.gd.uid`, `GameEvents.gd.uid`, `GameSettings.gd.uid`, `GeneticComponent.gd.uid`, `GoatColorTest.gd.uid`, `GoatData.gd.uid`, `GoatManager.gd.uid`, `GoatSaveData.gd.uid`, `MainMenu.gd.uid`); `Core/Weapon*.gd.uid` (×4); `Components/{ActorComponents,Arena,}/*.gd.uid` orphans; `Experimental/GoatColorTest.gd.uid`; `tests/test_armor.gd.uid`; `test/test_architecture_refactor.gd.uid`; `UI/RanchUI.gd.uid`; `Components/ActorComponents/AbilityComponents/RedirectAttack_NEW.gd.uid` |
| Risk level | low |
| Modular/reusable design approach | N/A — deletion only |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | `git status` clean after delete; Godot opens project without "UID broken" warnings on a fresh import. |
| Do now / later | Do now |

#### 0.2 Delete editor-crash `.tmp` leftovers

| Field | Value |
|---|---|
| Reason it matters | 6 `Play Space/tree_feature.tscn*.tmp` + 2 `QuestSystem/QuestTrackerHUD.tscn*.tmp` are Godot crash autosaves (Agent 2 Appendix A). No code references them. |
| Source | Agent 2 §5.1, Appendix A |
| Files likely affected | The 8 `.tmp` files listed in Appendix A |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | `Glob *.tmp` returns empty under `Play Space/` and `QuestSystem/`. |
| Do now / later | Do now |

#### 0.3 Fix Ranch return scene path

| Field | Value |
|---|---|
| Reason it matters | This is the literal cause of the README "[Currently Busted]" tag on the Ranch loop. Single-line fix. |
| Source | Agent 2 §3.1, §5.1; Agent 1 §10 P0 item 3 |
| Files likely affected | `Components/Arena/ArenaUIHandler.gd:107` |
| Risk level | low |
| Modular/reusable design approach | None needed — but consider replacing the literal path with a `ScenePaths.RANCH` constant (see Phase 2 module 2.5). |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | After clearing an arena, the "Return to Ranch" button loads `Components/BreedingComponents/Ranch/Ranch.tscn` without error. Verify against `UI/MainMenu.gd:281` which already uses the correct path. |
| Do now / later | Do now |

#### 0.4 Fix AGENTS.md GameClockComponent path

| Field | Value |
|---|---|
| Reason it matters | AGENTS.md tells contributors `res://Components/Arena/GameClockComponent.gd`; real path is `res://Components/GameClockComponent.gd`. Runtime works only because of `class_name` resolution. |
| Source | Agent 2 §1.4, §5.5; Agent 1 "Known critical facts" |
| Files likely affected | `AGENTS.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Grep `Components/Arena/GameClockComponent.gd` in AGENTS.md returns zero hits. |
| Do now / later | Do now |

#### 0.5 Reconcile Actor.md to 3D or archive it

| Field | Value |
|---|---|
| Reason it matters | Actor.md still declares `CharacterBody2D` + `Vector2` knockback (Agent 1 C2). Code is uniformly 3D. Misleads anyone reading the doc. |
| Source | Agent 1 §9.1 C2, §10 P6 item 40 |
| Files likely affected | `Markdowns/Actor.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Doc uses `CharacterBody3D` + `Vector3`; component list reconciled against the actual `_setup_components()` in `src/actors/base/Actor.gd:226-337`. |
| Do now / later | Do now |

#### 0.6 Annotate or relocate `SettlementImplementationPlan.md`

| Field | Value |
|---|---|
| Reason it matters | This doc plans a React/JSX project (Agent 1 C8, Agent 2 §4.2). It belongs to a different repo. Leaving it in `Markdowns/` invites someone to start implementing JSX inside the Godot project. |
| Source | Agent 1 §9.1 C8, §10 P6 item 42; Agent 2 §4.2 |
| Files likely affected | `Markdowns/SettlementImplementationPlan.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Doc carries a top-level `> **NOTE: This document describes a separate React/JSX webapp and is not implemented in this Godot project.**` admonition, OR has been moved out of `Markdowns/` to `Markdowns/ExternalProjects/`. |
| Do now / later | Do now |

#### 0.7 README: `GoatManager` → `HerdManager`

| Field | Value |
|---|---|
| Reason it matters | Rename already shipped (Agent 2 §1.2: `HerdManager` autoload exists at `Components/BreedingComponents/HerdManager.gd`). README still says `GoatManager`. |
| Source | Agent 1 §9.1 C1, §10 P6 item 41 |
| Files likely affected | `README.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Grep `GoatManager` in README returns zero hits except in a "history" footnote if desired. |
| Do now / later | Do now |

#### 0.8 Mark Capture.md deprecated in favor of Breeding.md `ActorState` model

| Field | Value |
|---|---|
| Reason it matters | Capture.md and Breeding.md describe two incompatible capture APIs (Agent 1 D5). Picking one now prevents implementation churn in Phase 4. |
| Source | Agent 1 §9.3 D5, §10 P6 item 43 |
| Files likely affected | `Markdowns/Capture.md`, `Markdowns/Breeding.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Capture.md header says "DEPRECATED — see Breeding.md §Capture System for canonical design." Breeding.md `ActorState` section is the only place describing the capture API. |
| Do now / later | Do now |

#### 0.9 Add `STATUS:` / `Last Updated:` header to plan-style docs

| Field | Value |
|---|---|
| Reason it matters | `UI_Refactoring_Plan.md` is the only timestamped progress doc (Agent 1 §9.2 S3). Other planning docs (MapExpansion, TreeGeneration, procedural_character_framework, Capture, Arena, WorldGeneration, TileSignalComponent) lack a status header, so reviewers can't tell what's stale. |
| Source | Agent 1 §10 P6 item 46 |
| Files likely affected | 7 docs listed above |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | All planning docs have a top-of-file `STATUS:` line. |
| Do now / later | Do now |

#### 0.10 Decide fate of legacy 2D `player.gd` / `player.tscn`

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §3.5 confirms these are CharacterBody2D leftovers, unreferenced. Confuses contributors who think the project is still 2D anywhere. |
| Source | Agent 2 §3.5 |
| Files likely affected | `player.gd`, `player.tscn` at project root |
| Risk level | low — verify with Grep that nothing references them; Agent 2 already did this. |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Files deleted, project still opens and runs MainMenu → Arena flow. |
| Do now / later | Do now |

---

### Phase 1 — Fix Broken or Incomplete Existing Systems

Behavior-restoring patches. Includes the AGENTS.md anti-pattern violations because they are **rule violations of a stated contract**, not pure perf. Pure perf work lives in Phase 5.

#### 1.1 Restore breeding gameplay loop

| Field | Value |
|---|---|
| Reason it matters | Data layer works (Agent 2 §2.8, §3.1) but the user-visible loop is broken because Ranch return path is wrong (fixed in 0.3) AND `ItemsAutoload.selected_goat` still goat-specific (Agent 1 P1 item 7). Breeding produces offspring at the `BreedingComponent` layer but they never reach the player without the Ranch loop. |
| Source | Agent 1 §10 P0 item 1, P1 items 5–7; Agent 2 §2.8, §3.1 |
| Files likely affected | `Components/BreedingComponents/Ranch/Ranch.gd`, `Components/BreedingComponents/Ranch/Ranch.tscn`, `Core/ItemsAutoload.gd`, possibly `Core/Managers/BreedingComponent.gd` |
| Risk level | medium — touches autoload state |
| Modular/reusable design approach | Generalize `selected_goat` → `selected_actor_data` (`ActorData` base). Make `Ranch.gd` accept any `ActorData` subclass; keep goat-specific filter as a property of the selector, not hardcoded. |
| Procedural approach | Offspring already use mean ± 10% mutation in `GoatData.create_offspring()` — preserve. Could later be promoted to a `TraitInheritanceEngine` (Phase 4). |
| Runtime perf risk | None — Ranch is a separate scene. |
| Memory/CPU/GPU impact | None additional. |
| Reusability across other projects | Selection-bus pattern (selected actor data + signal) is portable. |
| Acceptance test | Pair two does + bucks in Ranch; advance day(s) via `HerdManager`/`GameEvents.day_advanced`; verify offspring appears in the herd list and is selectable next session. |
| Do now / later | Do now |

#### 1.2 Remove `TileSignalComponent` Timer-node anti-pattern

| Field | Value |
|---|---|
| Reason it matters | AGENTS.md singles out TileSignalComponent as the proximity authority AND prohibits Timer nodes on actor components. The component itself violates the rule (Agent 2 §10.3, `TileSignalComponent.gd:20-25`). |
| Source | Agent 2 §10.3 |
| Files likely affected | `Components/Arena/TileSignalComponent.gd` |
| Risk level | medium — proximity routing is load-bearing for Detection, quest discovery, dormant AI, static obstacles. |
| Modular/reusable design approach | Replace the `Timer.new()` with `GameClockComponent` registration via `GameClockComponent.register_tick(callback, interval)` (mirror the StatusEffectComponent pattern from `Actor.gd:139-167`). |
| Procedural approach | N/A |
| Runtime perf risk | Improvement — one centralized tick vs every actor having its own. |
| Memory/CPU/GPU impact | -1 Timer node per active arena instance; CPU shifts to GameClock (already running). |
| Reusability across other projects | Component becomes a clean reusable module once Timer removed. |
| Acceptance test | TileSignalComponent has no `Timer.new()` after change. Quest camp discovery + DetectionComponent perception still fire on actor entering radius. Run `test_fire_spread.gd` for smoke check. |
| Do now / later | Do now |

#### 1.3 Remove `DetectionComponent` Timer-node anti-pattern

| Field | Value |
|---|---|
| Reason it matters | AGENTS.md "50 actors × 4 timers = 200 timer nodes" is exactly this pattern (Agent 2 §10.3, `DetectionComponent.gd:107-112`). Per-actor expiry timer. |
| Source | Agent 2 §10.3 |
| Files likely affected | `Components/ActorComponents/DetectionComponent.gd` |
| Risk level | medium — AI perception |
| Modular/reusable design approach | Use `Actor.register_tick(callback, interval)` to schedule expiry through GameClock. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement, scales linearly with actor count. |
| Memory/CPU/GPU impact | Eliminates N Timer nodes (N = perceiving actors). |
| Reusability across other projects | Component becomes portable. |
| Acceptance test | DetectionComponent has no `Timer.new()`. Perception still expires after configured interval. |
| Do now / later | Do now |

#### 1.4 Pre-stage Capture mechanics gate (no implementation yet)

| Field | Value |
|---|---|
| Reason it matters | Capture is documented as broken but Agent 2 found **zero** implementation. Don't try to "fix" something that doesn't exist. Phase 4 implements it. Phase 1 only ensures nothing else breaks once it arrives. |
| Source | Agent 1 §10 P0 item 2; Agent 2 §4.1 |
| Files likely affected | None in Phase 1 — defer to Phase 4 |
| Risk level | low |
| Modular/reusable design approach | N/A in Phase 1 |
| Procedural approach | N/A in Phase 1 |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | README "broken" tag remains until Phase 4 ships. |
| Do now / later | Later (Phase 4) |

#### 1.5 Verify `QuestStarterKit` does not double-add `TileSignalComponent`

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §5.6 flagged this as fragile — `Arena.gd:133-136` adds one, `QuestStarterKit._ensure_tile_signal_component()` checks via node name. Works today but depends on load order. |
| Source | Agent 2 §5.6 |
| Files likely affected | `QuestSystem/QuestStarterKit.gd:25-33`, optionally `Play Space/Arena.gd` |
| Risk level | low |
| Modular/reusable design approach | Switch the duplicate guard to check via `ArenaGrid.get_first_node_in_group("tile_signal_component")` and have Arena add the component to that group on `_ready`. Decouples from naming. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Add temporary print on TileSignalComponent `_ready`; load Arena; print fires exactly once. |
| Do now / later | Do now |

#### 1.6 Decide farmer playability scope (research only)

| Field | Value |
|---|---|
| Reason it matters | README says "playing farmer is for masochists." Need a one-paragraph scoping decision before allocating work. Spawn farmer with a working weapon kit, or defer to Phase 4? |
| Source | Agent 1 §10 P0 item 4 |
| Files likely affected | TBD |
| Risk level | low (decision-only) |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Decision documented in `Markdowns/UI_Refactoring_Plan.md` or a new short note. |
| Do now / later | Do now (decision); Later (any code) |

---

### Phase 2 — Extract Reusable Modules (non-procedural)

Lift well-isolated, already-functional code into reusable shapes. **Phase 1 must land first** because the modules touched by Phase 1 (TileSignal, GameClock) are not portable until the Timer violations are gone.

#### 2.1 Promote `GameClockComponent` to a standalone module folder

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §6: ~70 LOC, no project dependencies. Easiest module to extract; everything else builds on it. |
| Source | Agent 2 §6 |
| Files likely affected | `Components/GameClockComponent.gd` → move to `Components/Modules/Timing/GameClockComponent.gd` (or similar) |
| Risk level | low (after Phase 1) |
| Modular/reusable design approach | Keep autoload-or-component dual usage. Public API: `register_tick(callback: Callable, interval: float) -> int`, `unregister_tick(id: int)`, `signal tick_fired(dt)`. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High — drop-in tick bus for any Godot 4 project. |
| Acceptance test | Existing StatusEffect ticks still fire; `test_fire_spread.gd` passes; new project can `autoload` the file with zero edits. |
| Do now / later | Do now (after Phase 1) |

#### 2.2 Promote `TileSignalComponent` to a reusable proximity module

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §6 + §10.3 — once Timer removed (1.2), this is a clean module. Hex-distance abstraction is the only project assumption. |
| Source | Agent 1 §5; Agent 2 §6 |
| Files likely affected | `Components/Arena/TileSignalComponent.gd` |
| Risk level | medium |
| Modular/reusable design approach | Parameterize the distance function: accept a `Callable distance_fn(a, b) -> int` so non-hex projects can pass Manhattan/Chebyshev/Euclidean. Default = current `_get_hex_distance()`. |
| Procedural approach | N/A |
| Runtime perf risk | Distance function indirection: small. Mitigate with `set_distance_fn(null)` short-circuit using current hex impl. |
| Memory/CPU/GPU impact | Negligible. |
| Reusability across other projects | High after parameterization. |
| Acceptance test | Existing quest camp discovery + Detection perception unchanged. New tests for Manhattan distance use case (Phase 6). |
| Do now / later | Do now (after 1.2) |

#### 2.3 Extract `HealthBarPool` pattern to a generic `NodePool<T>` template

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §6: already a proper pool. The pattern (acquire / release / max size / on-acquire reset) generalizes to projectiles, particles, UI cards, text popups. |
| Source | Agent 2 §6 |
| Files likely affected | `Components/ActorComponents/HealthBarPool.gd` (model), new `Components/Modules/Pooling/NodePool.gd` |
| Risk level | low |
| Modular/reusable design approach | `NodePool.new(scene: PackedScene, max_size: int, on_acquire: Callable, on_release: Callable)` with `acquire()` / `release(node)`. Existing `HealthBarPool` becomes a thin wrapper. |
| Procedural approach | N/A |
| Runtime perf risk | None — same behavior. |
| Memory/CPU/GPU impact | Pooling pays off in Phase 5. |
| Reusability across other projects | High |
| Acceptance test | HealthBarPool acquires/releases via `NodePool` and existing health-bar visuals are unchanged. |
| Do now / later | Do now |

#### 2.4 Extract `SaveComponent` pattern to a generic `ResourceSaveStore`

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §6: deferred `ResourceSaver` with coalescing. Reusable for any Resource-shaped save (settings, profile, level state). |
| Source | Agent 2 §6 |
| Files likely affected | `Core/Managers/SaveComponent.gd` |
| Risk level | low |
| Modular/reusable design approach | `ResourceSaveStore.new(path: String, debounce_ms: int)` with `save(resource: Resource)` and `load() -> Resource`. HerdManager keeps its specialized `SaveComponent` as a wrapper. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High |
| Acceptance test | Existing herd save flow preserved (write `user://herd_save.tres`, load on boot). |
| Do now / later | Do now |

#### 2.5 Introduce `ScenePaths` constants module

| Field | Value |
|---|---|
| Reason it matters | The Ranch path bug (fixed in 0.3) was a literal string typo. A `const RANCH := "res://..."` constants script catches future drift. |
| Source | Derived from Agent 2 §3.1, §5.1 |
| Files likely affected | New `Core/ScenePaths.gd`; replace literals in `ArenaUIHandler.gd`, `MainMenu.gd`, `QuestStarterKit.gd`, etc. |
| Risk level | low |
| Modular/reusable design approach | Simple `class_name ScenePaths` with `const` strings. Optional `preload_all() -> Dictionary[String, PackedScene]` for warm-start scenarios. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | Pattern is portable; constants are project-specific. |
| Acceptance test | No literal `"res://..."` scene paths remain in scene-change call sites that use ScenePaths. |
| Do now / later | Do now |

#### 2.6 Promote `AbilityRegistry` from MainMenu introspection

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §8: `UI/MainMenu.gd:67-100` instantiates ability classes via reflection each time MainMenu opens, just to read `ability_name`. An `AbilityRegistry` autoload solves it once. |
| Source | Agent 2 §8 |
| Files likely affected | New `Core/AbilityRegistry.gd` autoload; `UI/MainMenu.gd:67-100`; `Components/ActorComponents/AbilityComponents/AbilityComponent.gd` |
| Risk level | low |
| Modular/reusable design approach | Scan `Components/ActorComponents/AbilityComponents/*.gd` on `_init`, build `{name: PackedScript}` dict. AbilityComponent.setup() consumes registry instead of hardcoded element_type matches. |
| Procedural approach | Data-driven action loading via filesystem scan — small step toward "abilities are content, not code". |
| Runtime perf risk | One-time scan at boot; per-frame nothing. Eliminates per-menu-open instantiation. |
| Memory/CPU/GPU impact | Small one-time alloc; net win. |
| Reusability across other projects | High — pattern works for any "discover scripts by convention" need. |
| Acceptance test | Open MainMenu, switch character; equipment cards still show correct ability names; no `Node.new()`/`free()` churn on menu open (Profile-verify). |
| Do now / later | Do now |

#### 2.7 Decouple `HerdManager` composition (already mostly modular)

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §1.2, §2.8: HerdManager already composes 5 small components. Almost portable; only the goat-specific assumptions in `BreedingComponent` / `HerdComponent` need a Phase 4 generalization sweep. |
| Source | Agent 2 §1.2, §2.8 |
| Files likely affected | `Core/Managers/HerdComponent.gd`, `Core/Managers/BreedingComponent.gd` |
| Risk level | medium — these are part of the breeding loop fix in 1.1 |
| Modular/reusable design approach | Already structured well. Document the public API of each manager component in a top-of-file docstring. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | Medium — concept is portable; goat-specific naming will need rename in Phase 4. |
| Acceptance test | All 5 components have a docstring describing their public API. |
| Do now / later | Do now |

#### 2.8 Extract `ActorFactory` (Breeding.md Phase 5)

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P1 item 8 + Agent 2 §11 flag `Components/Arena/ArenaSpawner.gd` as do-not-break and it currently dispatches via hardcoded `match type` (Agent 2 §9). Extracting an `ActorFactory` is the unlock for actor-agnostic spawning — and a prerequisite for Capture (4.1), elementals (4.6), and procedural creatures (4.7+). |
| Source | Agent 1 §10 P1 item 8; Agent 2 §9, §11 |
| Files likely affected | New `Components/Arena/ActorFactory.gd`; `Components/Arena/ArenaSpawner.gd` (consume the factory) |
| Risk level | medium — touches the spawner that QuestSpawnManager and Arena both call |
| Modular/reusable design approach | Registry pattern: `ActorFactory.register(actor_type: StringName, scene: PackedScene)` + `ActorFactory.spawn(actor_data: ActorData, position: Vector3) -> Actor`. Initial registration block lives in one place; ArenaSpawner stops importing actor scenes directly. |
| Procedural approach | Data-keyed dispatch (string → PackedScene). Could later read registry from a `Resource` table for full data-drivenness. |
| Runtime perf risk | None — same dict lookup as a match would compile to. |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High — same factory pattern works for any project with `*Data → *Scene` mapping. |
| Acceptance test | ArenaSpawner has no `match type` for actor scene selection; spawning a goat/farmer/goblin/fire/water/scarecrow still works identically; QuestSpawnManager's goblin spawning still works. |
| Do now / later | Do now (after 1.1) |

#### 2.9 Generic `ActorCard` + rename `GoatRenderer` → `ActorCardRenderer`

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P1 items 5–6 + §9.1 C12: Breeding.md Phase 2 calls for refactoring `ActorCard` to take `ActorData` and removing the `goat_data` alias. UI.md already documents ActorCard as supporting both; the alias is the stale glue to drop. |
| Source | Agent 1 §10 P1 items 5–6, §9.1 C12 |
| Files likely affected | `UI/DisplayCard/ActorCard.gd` + its scene; `UI/GoatRenderer.gd` (rename to `ActorCardRenderer.gd`); `Components/BreedingComponents/Ranch/Ranch.gd` (consumer); SYNC RULE update to `Markdowns/UI.md` |
| Risk level | medium — UI rename ripples through Ranch + selection bus |
| Modular/reusable design approach | `ActorCard` takes `actor_data: ActorData` only; visual is dispatched via `ActorCardRenderer.render(actor_data, card_node)` which inspects `get_actor_type()` (no hardcoded GoatData paths). |
| Procedural approach | N/A — pure refactor |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High — `ActorCard` becomes a drop-in card for any ActorData-shaped resource. |
| Acceptance test | Ranch shows goat cards identically; MainMenu character cards identical; a `GoblinData` resource (when 4.1 adds it) can be passed to ActorCard and renders via the same code path. |
| Do now / later | Do now (after 1.1) |

#### 2.10 Debug settings autoload + DebugOptionsController update

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P2 item 10 + Markdowns/UI_Refactoring_Plan.md explicitly marks PENDING. Debug-related state currently lives ad-hoc; promoting it to an autoload removes scattered toggles. |
| Source | Agent 1 §10 P2 item 10; Markdowns/UI_Refactoring_Plan.md |
| Files likely affected | New `Core/DebugSettings.gd` autoload (or extend `Core/GameSettings.gd` — UI_Refactoring_Plan.md gives both options); `UI/DebugOptionsController.gd`; `project.godot` if new autoload chosen |
| Risk level | low |
| Modular/reusable design approach | Decision: extend `GameSettings` (Option A, fewer autoloads) — `DebugSettings` namespace as inner dict — OR create dedicated `DebugSettings` autoload (Option B, cleaner separation). Default to **Option A** since GameSettings already persists to `user://settings.cfg`. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High pattern; specific keys project-local. |
| Acceptance test | DebugOptionsController reads/writes through the new autoload; debug toggles persist across runs. |
| Do now / later | Do now |

#### 2.11 PlayerConsole refactor — extract `WeaponListPanel.gd` / `CardDisplayPanel.gd`

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P2 item 12 + UI_Refactoring_Plan.md marks PENDING. PlayerConsole is coupled to weapon list + card display logic; extraction reduces blast radius for future UI changes. |
| Source | Agent 1 §10 P2 item 12; Markdowns/UI_Refactoring_Plan.md |
| Files likely affected | `UI/PlayerConsole.gd`; new `UI/PlayerConsole/WeaponListPanel.gd`; new `UI/PlayerConsole/CardDisplayPanel.gd` |
| Risk level | medium — PlayerConsole is heavily used in-game |
| Modular/reusable design approach | Each panel is a self-contained `Control` with its own signals. PlayerConsole becomes a thin orchestrator that wires panels together via event bus. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High — panel pattern is portable. |
| Acceptance test | PlayerConsole visual behavior identical; switching weapons updates the WeaponListPanel via signal, not direct method call. |
| Do now / later | Do now |

> **Phase 2 deferred:** Markdowns/UI_Refactoring_Plan.md also lists MainMenu scene restructure (extract `MapSettingsController.tscn`) as **optional**; defer unless Phase 4 work makes it necessary.

---

### Phase 3 — Extract Reusable Procedural Generation Modules

Lift the seeded/data-driven systems Agent 2 already identified as procedural (§7). Each becomes a portable generator with a clear input Resource and a deterministic output.

#### 3.1 Extract `SeededGenerator` base + RNG conventions

| Field | Value |
|---|---|
| Reason it matters | `GridGenerator`, `TreeSpawner`, `_make_random_goat_data`, `QuestSpawnManager` camp picking all roll their own RNG. A shared base ensures deterministic seeds and consistent stream naming. |
| Source | Agent 2 §7 |
| Files likely affected | New `Components/Modules/Procedural/SeededGenerator.gd`; touch sites that currently roll their own `RandomNumberGenerator.new()` |
| Risk level | low |
| Modular/reusable design approach | `SeededGenerator` class with `seed: int`, `_rng: RandomNumberGenerator`, `child_rng(salt: String) -> RandomNumberGenerator` for sub-streams (e.g. `terrain`, `trees`, `quests`). |
| Procedural approach | Foundational — every other procedural module consumes this. |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | One RNG per sub-stream; trivial. |
| Reusability across other projects | High |
| Acceptance test | `GridGenerator` and `TreeSpawner` reproduce the same world for the same `noise_seed`. |
| Do now / later | Do now |

#### 3.2 Generalize `BiomeData` + `TreeSpawner` into `WeightedPoolSpawner<T>`

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §6, §7: BiomeData/TreeSpawner pair is already a generic seeded weighted-pool spawner with distance falloff and spacing constraint. Generalize the spawn loop so the same engine spawns goblin loot, props, enemies. |
| Source | Agent 2 §6, §7 |
| Files likely affected | `src/trees/TreeSpawner.gd`, `src/trees/BiomeData.gd`, new `Components/Modules/Procedural/WeightedPoolSpawner.gd` |
| Risk level | medium |
| Modular/reusable design approach | `WeightedPoolSpawner.new(seed, pool: Array[WeightedEntry], placement_rule: PlacementRule)`. `BiomeData` becomes a specialization. `PlacementRule` is an interface (BFS-from-center, distance falloff, spacing). |
| Procedural approach | Schema sketch: `WeightedEntry { weight: float; payload: Resource }`; `PlacementRule { can_place(tile, neighbors) -> bool; weight_at(tile) -> float }`. |
| Runtime perf risk | Same as current TreeSpawner (10/frame batching preserved). |
| Memory/CPU/GPU impact | Same. |
| Reusability across other projects | High |
| Acceptance test | TreeSpawner produces same trees for same seed after refactor. New `LootSpawner` uses same WeightedPoolSpawner for goblin camp loot. |
| Do now / later | Do now |

#### 3.3 Extract noise-driven `TerrainProfile` resource

| Field | Value |
|---|---|
| Reason it matters | `GridGenerator.gd:46-91` hardcodes the noise → terrain → height pipeline. A `TerrainProfile` Resource lets MapExpansion (Phase 4) build different biomes/regions without forking GridGenerator. |
| Source | Agent 1 §6, §10 P4 item 21; Agent 2 §7 |
| Files likely affected | `Components/Arena/GridGenerator.gd`, new `Components/Arena/TerrainProfile.gd` |
| Risk level | medium |
| Modular/reusable design approach | `TerrainProfile { noise: FastNoiseLite; dirt_threshold: float; height_levels: int; height_map_curve: Curve; biome_id: StringName }`. GridGenerator accepts a profile. |
| Procedural approach | Schema sketch: pure data; no code in the resource. Maps `(noise_value, distance_from_center) -> TileType + height_level`. |
| Runtime perf risk | None — same noise math. |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High |
| Acceptance test | Same default profile produces same world; loading a "boreal" profile produces a visibly different distribution. |
| Do now / later | Do now |

#### 3.4 Promote farmstead planner to `FloodFillRegionPlanner`

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §6: BFS flood-fill from center with shuffled neighbors. Same pattern fits any "carve a roughly-shaped region into a grid" need (settlement, dungeon room, biome island). |
| Source | Agent 1 §6; Agent 2 §7 |
| Files likely affected | `Components/Arena/GridGenerator.gd` (extract `plan_farmstead()`), new `Components/Modules/Procedural/FloodFillRegionPlanner.gd` |
| Risk level | low |
| Modular/reusable design approach | `FloodFillRegionPlanner.plan(origin: Vector2i, target_size: int, neighbor_fn: Callable, can_include_fn: Callable, rng: RandomNumberGenerator) -> Array[Vector2i]`. |
| Procedural approach | Deterministic given seed (shuffled-neighbor order). |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High |
| Acceptance test | Farmstead shape identical for same seed; planner reusable for a small "town center" region in Phase 4 MapExpansion. |
| Do now / later | Do now |

#### 3.5 Lift `GoatData.create_offspring()` into `TraitInheritanceEngine`

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §7, §8: the algorithm (color lerp / 50/50 categorical / stat mean ± 10%) is generic but currently inside `GoatData`. Promoting it unblocks Goblin/Elemental/Mimic breeding (Breeding.md Phase 4+). |
| Source | Agent 1 §5 (planned); Agent 2 §7 |
| Files likely affected | `Components/BreedingComponents/GoatData.gd`, new `Components/BreedingComponents/TraitInheritanceEngine.gd` |
| Risk level | medium — touches breeding loop |
| Modular/reusable design approach | Engine takes parents (`ActorData`), a `TraitSchema` (per-trait inheritance mode: MENDELIAN / QUANTITATIVE / ENVIRONMENTAL / MUTATIONAL per Agent 1 §5), and an RNG. Returns offspring `ActorData`. |
| Procedural approach | Schema sketch: `TraitSchema { traits: Array[TraitDef] }`, `TraitDef { name; mode; mean_mutation: float; categorical_options }`. |
| Runtime perf risk | None — same math. |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High |
| Acceptance test | Existing goat offspring color/horn/body/stat distribution identical to current `create_offspring()`. A `GoblinData` derived ActorData can call the same engine. |
| Do now / later | Do now |

#### 3.6 Promote `SpawnVarianceConfig` (planned in Breeding.md)

| Field | Value |
|---|---|
| Reason it matters | Breeding.md plans this; ArenaSpawner `_make_random_goat_data()` already does ad-hoc variance. Consolidating gives elementals/summoned beings a clean config Resource. |
| Source | Agent 1 §6 (planned), §10 P1 item 9; Agent 2 §7, §8 |
| Files likely affected | `Components/Arena/ArenaSpawner.gd`, new `Components/BreedingComponents/SpawnVarianceConfig.gd` |
| Risk level | low |
| Modular/reusable design approach | `SpawnVarianceConfig { distribution: enum(UNIFORM, GAUSSIAN, BOUNDED); per_stat_overrides: Dictionary[StringName, StatVariance] }`. |
| Procedural approach | Schema sketch as above. |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High |
| Acceptance test | Existing spawn behavior matches old output when default config used; loading a `GAUSSIAN` config visibly tightens stat distribution. |
| Do now / later | Do now |

---

### Phase 4 — Implement Documented Missing Features (Procedural / Data-Driven)

The "big new content" phase. Each task is sized to one or two focused PRs, not a months-long epic. Where Agent 1 §10 lists a multi-phase plan (e.g. Procedural Character Framework's 12 phases), only the foundational sub-phases are `Do now`; the rest are `Later`.

#### 4.1 Capture system — `CaptureComponent` + `ActorState` enum

| Field | Value |
|---|---|
| Reason it matters | README P0. Two design docs, one canonical (Breeding.md `ActorState`; Capture.md deprecated by 0.8). |
| Source | Agent 1 §10 P0 item 2, §10 P1 item 9; Agent 2 §4.1 |
| Files likely affected | New `Components/ActorComponents/CaptureComponent.gd`; new `Components/ActorComponents/ActorState.gd` enum; touch `src/actors/ai/ActorAIController.gd` to bridge `ActorState` into AI FSM (transition from WILD → RESTRAINED disables roam/chase, enables drag-target behavior). |
| Risk level | high — touches base AI state machine |
| Modular/reusable design approach | CaptureComponent is a component you attach to any actor that **can be captured**. Its config Resource is a `CaptureProfile` (restraint resistance, escape DC table, taming curve). Capture *items* (nets, ropes) live in `ItemsAutoload` weapon catalog as a new category. |
| Procedural approach | Schema sketch: `CaptureProfile { restraint_resistance: int; escape_dc_per_restraint: Curve; taming_loyalty_curve: Curve; flee_chance_after_break: float }`. Each "restraint" applied stacks `_restraint_count`. Escape rolls go through the existing skill-check pattern in DetectionComponent (Wisdom d20). |
| Runtime perf risk | Capture events are rare; negligible. |
| Memory/CPU/GPU impact | One extra component per capturable actor; small. |
| Reusability across other projects | High — `ActorState` enum is generic. |
| Acceptance test | Throw a net at a wild goat: enters RESTRAINED. Roll escape: returns to WILD. Drag to ranch + complete taming: transitions to TAMED, joins herd. README "broken" tag removable. |
| Do now / later | Do now |

#### 4.2 Map expansion — `RegionData` + `RegionManager`

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P4 items 21, 24. Foundation for biomes, rivers, quest-gate edges. |
| Source | Agent 1 §10 P4; Agent 2 §4.3 |
| Files likely affected | New `Play Space/Regions/RegionData.gd` (Resource), `Play Space/Regions/RegionManager.gd` (autoload candidate), refactor `Play Space/Arena.gd` to load a `Region` not just a grid. |
| Risk level | high — touches the arena orchestrator |
| Modular/reusable design approach | `RegionData { id: StringName; size: Vector2i; terrain_profile: TerrainProfile (from 3.3); edges: Array[EdgeProfile]; biome_id: StringName }`. `RegionManager` loads/unloads adjacent regions, holds an LRU cache (Agent 1 §7). |
| Procedural approach | Schema sketch as above. Use `WeightedPoolSpawner` (3.2) for region-specific features. Use `FloodFillRegionPlanner` (3.4) for sub-regions. |
| Runtime perf risk | Streaming must be off-main-thread per MapExpansion.md §6. Acceptable on first pass to load synchronously with a loading screen; threading is Phase 5. |
| Memory/CPU/GPU impact | One active region's grid + caches; controlled by LRU. |
| Reusability across other projects | High |
| Acceptance test | Spawn into a region; walk to its eastern edge; adjacent region loads and remains traversable. Existing single-circle arena still spawnable as a default `RegionData` resource. |
| Do now / later | Do now (RegionData + single-region load); Later (multi-region streaming, threading) |

#### 4.3 Edge variations — stone wall replaced by mountain/ocean/frontier-gate

| Field | Value |
|---|---|
| Reason it matters | MapExpansion.md §3.1; Agent 1 §10 P4 item 27. Currently `GridGenerator` only knows stone. |
| Source | Agent 1 §10 P4 item 27 |
| Files likely affected | `Components/Arena/GridGenerator.gd`, `Play Space/tile_constants.gd`, new `Play Space/Regions/EdgeProfile.gd` |
| Risk level | medium |
| Modular/reusable design approach | `EdgeProfile { edge_type: enum(STONE, MOUNTAIN, OCEAN, GATE); gate_unlock_quest_id: StringName }`. GridGenerator consumes per-edge profile from `RegionData`. |
| Procedural approach | Tile type derived from edge profile + distance from boundary. |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | One or two new tile types in HexTileData enum. |
| Reusability across other projects | Medium |
| Acceptance test | A region with OCEAN east edge spawns water tiles instead of stone; AI cannot path across it. |
| Do now / later | Do now (after 4.2) |

#### 4.4 Quest-driven wall destruction

| Field | Value |
|---|---|
| Reason it matters | MapExpansion.md §3.6; Agent 1 §10 P4 item 26. Connects quest completion to map expansion. |
| Source | Agent 1 §10 P4 item 26 |
| Files likely affected | `QuestSystem/QuestState.gd`, `Components/Arena/GridGenerator.gd`, new `QuestSystem/QuestRewards/EdgeUnlockReward.gd` |
| Risk level | medium |
| Modular/reusable design approach | Reward Resource pattern: `QuestReward` base + `EdgeUnlockReward { region_id; edge_direction }`. QuestState dispatches reward on completion. |
| Procedural approach | Data-driven via quests.json reward field. |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | Pattern (typed quest rewards) is portable. |
| Acceptance test | A test quest with an `EdgeUnlockReward`; completing it flips the relevant edge from `GATE` to traversable. |
| Do now / later | Do now (after 4.2 + 4.3) |

#### 4.5 RoadGenerator (primary + dead-end + building-access)

| Field | Value |
|---|---|
| Reason it matters | MapExpansion.md §3.7; Agent 1 §10 P4 item 25. Multi-edge ready per the doc. |
| Source | Agent 1 §10 P4 item 25 |
| Files likely affected | New `Play Space/Regions/RoadGenerator.gd` |
| Risk level | medium |
| Modular/reusable design approach | A* hex pathfinding (reuse `ArenaGrid.get_tiles_in_radius` and tile costs). `RoadGenerator.generate(region, road_profile)` returns `Array[Vector2i]` of road tiles. |
| Procedural approach | Schema sketch: `RoadProfile { primary_count: int; dead_end_chance: float; building_access: bool }`. |
| Runtime perf risk | One-time during region generation; bounded by region size. |
| Memory/CPU/GPU impact | Adds a tile state DIRT_PATH (or similar). |
| Reusability across other projects | High |
| Acceptance test | A region with `primary_count: 2` shows two roads crossing edge-to-edge; one dead-end if rolled. |
| Do now / later | Later — only after 4.2/4.3 land |

#### 4.6 Earth and Air elementals

| Field | Value |
|---|---|
| Reason it matters | README roadmap; Agent 1 §10 P7 item 47. Fire/Water actors exist; the Earth/Air slots are missing. |
| Source | Agent 1 §10 P7 item 47; Agent 2 §4.5 |
| Files likely affected | New `src/actors/types/EarthActor.gd` + scene; new `src/actors/types/AirActor.gd` + scene; new tile reactions in `Components/Arena/TileSystem.gd`; new projectiles under `src/actors/projectiles/`. |
| Risk level | medium |
| Modular/reusable design approach | Use the same `ElementalActor` template as Fire/Water. If Phase 3.2 `WeightedPoolSpawner` and Phase 3.5 `TraitInheritanceEngine` landed, `ElementalData` becomes a config Resource instead of one class per element. |
| Procedural approach | Data-driven element definition: `ElementalProfile { element: StringName; tile_reactions: Array[TileReaction]; projectile_scene: PackedScene }`. |
| Runtime perf risk | Same as existing elementals. |
| Memory/CPU/GPU impact | Two more PackedScenes, two projectile variants. |
| Reusability across other projects | Pattern (elemental profiles) is portable. |
| Acceptance test | Earth elemental spawned in arena; its tile reaction (e.g. converts grass to stone) fires; Air elemental's gust pushes other actors one tile. |
| Do now / later | Later — after data-driven elemental profile refactor |

#### 4.7 Procedural Character Framework — Phase 1 only (`CreatureDefinition` Resource)

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P5 item 28. This is the foundation for the whole framework. Phases 2–12 of the framework are deferred. |
| Source | Agent 1 §10 P5 item 28; Agent 2 §4.4 |
| Files likely affected | New `addons/procedural_creature/runtime/CreatureDefinition.gd` (Resource), `addons/procedural_creature/plugin.cfg` |
| Risk level | low (pure data definition) |
| Modular/reusable design approach | Per `procedural_character_framework.md`: Resource with `@export_group` for body proportions, color palette, detail level enum. `duplicate_definition()` for variants. |
| Procedural approach | All inputs are data; runtime generators (later phases) consume this. |
| Runtime perf risk | None (no runtime yet) |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | High once full framework lands. |
| Acceptance test | A `CreatureDefinition.tres` can be created, edited in the inspector, and `duplicate_definition()` returns a deep copy. |
| Do now / later | Do now |

#### 4.8 Procedural Character Framework — Phase 2 (`LimbBuilder`)

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P5 item 29. The smallest runnable proof-of-concept. |
| Source | Agent 1 §10 P5 item 29 |
| Files likely affected | New `addons/procedural_creature/runtime/LimbBuilder.gd` |
| Risk level | low |
| Modular/reusable design approach | `SurfaceTool`/`ArrayMesh`-based tapered cylinders. Returns `MeshInstance3D`. Side count from `CreatureDefinition.detail_level`. |
| Procedural approach | All deterministic from definition + seed. |
| Runtime perf risk | One-time mesh gen per limb at spawn. |
| Memory/CPU/GPU impact | A few KB per limb. |
| Reusability across other projects | High |
| Acceptance test | Demo scene with one `CreatureDefinition` → calls `LimbBuilder.build_limb()` → renders a tapered cylinder at SIMPLE/MODERATE/COMPLEX detail. |
| Do now / later | Do now (after 4.7) |

#### 4.9 Procedural Character Framework — Phases 3–12

| Field | Value |
|---|---|
| Reason it matters | Full system (torso/head/extras builders, ShapeAssembler, generator orchestrator, SkeletonInferer, editor plugin, serializer, gizmo, locomotion, secondary motion, integration). |
| Source | Agent 1 §10 P5 items 30–39 |
| Files likely affected | Entire `addons/procedural_creature/` tree |
| Risk level | high (large scope) |
| Modular/reusable design approach | One sub-phase per PR. Editor plugin lives in `addons/procedural_creature/editor/` so it can be stripped for shipping per the doc's design principles. |
| Procedural approach | Resource-driven throughout. |
| Runtime perf risk | DetailLevel cascade (Agent 1 §7) controls per-frame cost. |
| Memory/CPU/GPU impact | Significant; controlled by DetailLevel. |
| Reusability across other projects | Very high — entire framework is the modularity story. |
| Acceptance test | Per sub-phase; final acceptance = demo scene with 50 procedurally generated creatures at MODERATE detail running at 60 FPS. |
| Do now / later | Later — each sub-phase is its own PR. Do not collapse into one task. |

#### 4.10 Barns + additional ranch buildings

| Field | Value |
|---|---|
| Reason it matters | README roadmap; Agent 1 §10 P7 item 48. Currently only house + fences. |
| Source | Agent 1 §10 P7 item 48 |
| Files likely affected | New `Play Space/RanchBuildings/Barn.gd` + scene; `Components/Arena/GridGenerator.gd` to slot building tiles. |
| Risk level | medium |
| Modular/reusable design approach | `BuildingProfile` Resource describing footprint, required tiles, interaction component. `GridGenerator.plan_farmstead()` reads a `Array[BuildingProfile]`. |
| Procedural approach | Building placement uses `FloodFillRegionPlanner` (3.4) constrained to farmstead interior. |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | A few static meshes per building. |
| Reusability across other projects | Pattern is portable. |
| Acceptance test | A ranch can be configured to include 1 house + 1 barn + N fences; barn renders, has interaction component for goat sheltering. |
| Do now / later | Later |

#### 4.11 Tree generation migration finalization

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §2.7 confirms the new tree system is live; Agent 1 §10 P3 items 13–20 list the remaining tasks (LOD wiring, log piles, harvest tools, delete old `TreeStates/`). |
| Source | Agent 1 §10 P3 items 13–20; Agent 2 §3.3 |
| Files likely affected | `src/trees/HarvestableTree.gd` (LOD wiring + billboard), new `src/trees/LogPile.gd`, delete `Play Space/TreeStates/` if it still exists, update AGENTS.md project structure |
| Risk level | medium |
| Modular/reusable design approach | LOD driver via `TileSignalComponent` proximity (continuous mode); billboard at LOD2 uses pre-baked mesh. LogPile reuses `HarvestableComponent` (Agent 1 §5). |
| Procedural approach | Already procedural (TreeSpawner + TreeBlueprint). |
| Runtime perf risk | LOD wiring **improves** perf (Phase 5 concern overlaps). |
| Memory/CPU/GPU impact | Significant reduction once LOD is real. |
| Reusability across other projects | High |
| Acceptance test | At 100+ trees, only nearby (LOD0/1) trees use full CSG; far trees swap to billboards or hide. No frame drop with 200 trees. |
| Do now / later | Do now (LOD wiring); Later (LogPile, full TreeStates deletion) |

---

### Phase 5 — Performance Optimization

Pure perf work. Phase 1 already removed the two Timer anti-patterns that were correctness violations; this phase handles the remaining hot spots Agent 2 §10 found.

#### 5.1 VisibilityManager — debug-print gate + frame budget

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.1: the single biggest hot spot. Per-frame, per-foliage normalize/dot/unproject/FOV/AABB/lerp, plus unconditional debug prints behind `randf() < 0.01`. |
| Source | Agent 2 §10.1 |
| Files likely affected | `src/trees/VisibilityManager.gd` |
| Risk level | medium |
| Modular/reusable design approach | Gate all debug prints behind `OS.is_debug_build()` AND a `debug_verbose` exported toggle (default false). Move per-foliage loop to a chunked schedule: process N foliage entries per frame, round-robin, with the entire set traversed every 4–8 frames (config). Skip work entirely when no actor moved past a tile boundary. |
| Procedural approach | N/A |
| Runtime perf risk | Already a risk; this reduces it. |
| Memory/CPU/GPU impact | Major CPU reduction. |
| Reusability across other projects | Module becomes portable. |
| Acceptance test | With 200 trees registered, frame time drops measurably (target: -3ms+ on debug builds). No debug spam in console. |
| Do now / later | Do now |

#### 5.2 Move per-frame `_process` to GameClock for AbilityComponent + HarvestableTree

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.2: `AbilityComponent._process(delta)` iterates all actions every frame; `HarvestableTree._process(delta)` runs for every standing tree. Both are GameClock candidates. |
| Source | Agent 2 §10.2 |
| Files likely affected | `Components/ActorComponents/AbilityComponents/AbilityComponent.gd`, `src/trees/HarvestableTree.gd` |
| Risk level | medium |
| Modular/reusable design approach | Both register a tick via `Actor.register_tick()` / `GameClockComponent.register_tick()` at appropriate rates (abilities: 10Hz; harvestable: only when an actor is within proximity via TileSignalComponent). |
| Procedural approach | N/A |
| Runtime perf risk | Improvement scales with actor count and tree count. |
| Memory/CPU/GPU impact | Major CPU reduction when many idle trees exist. |
| Reusability across other projects | High |
| Acceptance test | AbilityComponent triggers ability cooldown ticks at 10Hz exactly; HarvestableTree consumes zero CPU when no actor is within harvest radius. |
| Do now / later | Do now |

#### 5.3 Projectile pooling

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.5: `ProjectileComponent._launch_lob_shot` and `_launch_spread_shot` instantiate 5 PackedScenes per shot, no pool. `drop_inventory` allocates one per death. |
| Source | Agent 2 §10.5 |
| Files likely affected | `Components/WeaponComponents/ProjectileComponent.gd`, `Components/WeaponComponents/WeaponComponent.gd`, uses `NodePool` from 2.3 |
| Risk level | medium |
| Modular/reusable design approach | One pool per projectile PackedScene, owned by an `ArenaProjectilePool` node on Arena. `BaseProjectile` learns `_reset(start_pos, velocity)` + `_recycle()`. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement. |
| Memory/CPU/GPU impact | Allocations drop to near-zero in steady state combat. |
| Reusability across other projects | High via `NodePool`. |
| Acceptance test | Fire 100 ranged shots; instantiation count (Profiler) holds steady after warm-up. |
| Do now / later | Do now |

#### 5.4 Eliminate ad-hoc `SceneTreeTimer` calls

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.4: 6 sites do `await get_tree().create_timer(...).timeout`, some inside loops (`QuestSpawnManager.gd:230,361` spawn one timer per goblin per camp). |
| Source | Agent 2 §10.4 |
| Files likely affected | `QuestSystem/QuestSpawnManager.gd`, `Components/Arena/ArenaUIHandler.gd`, `Components/ActorComponents/CommunicationComponent.gd`, `Components/ActorComponents/MovementComponent.gd`, `Components/ActorComponents/AbilityComponents/NimbleEscape.gd`, `src/actors/projectiles/LobProjectile.gd` |
| Risk level | medium |
| Modular/reusable design approach | Replace with `await GameClockComponent.wait(seconds)` (new helper on the clock that yields after the next tick crossing that interval). For the QuestSpawnManager spawn loops, switch to a single `call_deferred` chain or process-frame coroutine. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement. |
| Memory/CPU/GPU impact | One fewer SceneTreeTimer node per await. |
| Reusability across other projects | High via GameClock module. |
| Acceptance test | `Grep "get_tree().create_timer"` returns zero hits. Spawn behavior visibly identical. |
| Do now / later | Do now |

#### 5.5 ItemsAutoload — lazy + Resource-directory scan

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.7: 40+ synchronous `load()` calls on autoload boot; also a maintenance nightmare with timestamped icon paths. |
| Source | Agent 2 §10.7; §9 (manual catalog) |
| Files likely affected | `Core/ItemsAutoload.gd`; weapon Resource files in `Core/Weapons/*.tres` (new) |
| Risk level | medium |
| Modular/reusable design approach | Each weapon becomes a `WeaponData.tres` Resource on disk. ItemsAutoload scans the directory on first `get_weapon_by_name()` call (lazy) and caches. Icons referenced via relative paths inside the resource. |
| Procedural approach | Data-as-content: adding a weapon = dropping a `.tres`. |
| Runtime perf risk | Boot time drops; first weapon lookup pays the scan cost (still fast). |
| Memory/CPU/GPU impact | Smaller boot heap; load-on-demand icons. |
| Reusability across other projects | High |
| Acceptance test | Add a new weapon by creating a `WeaponData.tres` only; it appears in MainMenu equipment cards. Boot time decreases. |
| Do now / later | Do now |

#### 5.6 Arena `_register_static_obstacles` → batched trigger registration

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.6: walks entire `tile_data_grid` registering a radius-2 trigger per obstacle. With many fences/stones, `_triggers` becomes large and every actor tile-change iterates all of them. |
| Source | Agent 2 §10.6 |
| Files likely affected | `Play Space/Arena.gd:363-384`, `Components/Arena/TileSignalComponent.gd` |
| Risk level | medium |
| Modular/reusable design approach | Group static obstacles into a single composite trigger keyed by tile; TileSignalComponent maintains a `_static_obstacle_set: Dictionary[Vector2i, true]` consulted in O(1) instead of iterating triggers for each. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement scales with obstacle count. |
| Memory/CPU/GPU impact | Smaller `_triggers` array. |
| Reusability across other projects | High |
| Acceptance test | With 200 static obstacles, `_on_actor_tile_changed` cost stays flat. |
| Do now / later | Do now |

#### 5.7 GoatActor double-iteration cleanup

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.8: `GoatActor._physics_process` iterates `ability_component.actions` twice per tick to find GoatCharge. Linear in actor count. |
| Source | Agent 2 §10.8 |
| Files likely affected | `src/actors/types/GoatActor.gd:99-111`, `Components/ActorComponents/AbilityComponents/AbilityComponent.gd` |
| Risk level | low |
| Modular/reusable design approach | Cache the GoatCharge reference on `_ready` via `ability_component.get_action(GoatCharge)`. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement. |
| Memory/CPU/GPU impact | None. |
| Reusability across other projects | Pattern (cache action lookup) is portable. |
| Acceptance test | GoatCharge still triggers; per-frame iteration removed. |
| Do now / later | Do now |

#### 5.8 Tree LOD wiring + visible-tree cap

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §10 P3 item 20; Agent 2 §3.3 — `HarvestableTree.switch_to_lod()` exists but is never called. |
| Source | Agent 1 §10 P3; Agent 2 §3.3 |
| Files likely affected | `src/trees/HarvestableTree.gd`, `src/trees/TreeSpawner.gd`, `src/trees/VisibilityManager.gd` |
| Risk level | medium |
| Modular/reusable design approach | A `TreeLODController` (new) listens to player camera position, computes per-tree distance bucket, calls `switch_to_lod(n)`. Use TileSignalComponent continuous mode keyed on camera tile, not per-frame. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement. |
| Memory/CPU/GPU impact | Hard cap ~200 visible trees per TreeGeneration.md §13.4. |
| Reusability across other projects | High |
| Acceptance test | At 500 spawned trees, only ~200 are visible at LOD0/1; LOD2 billboards beyond; LOD3 hidden past threshold. |
| Do now / later | Do now (after 5.2) |

#### 5.9 Cache common Arena queries

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §10.6: `Play Space/Arena.gd:278-307 get_tile_data_at_world_position` carries a self-noted `TODO(Optimization)`. Frequently called by combat code. |
| Source | Agent 2 §10.6 |
| Files likely affected | `Play Space/Arena.gd` |
| Risk level | low |
| Modular/reusable design approach | Spatial hash on `(int(x/cell_size), int(z/cell_size))` → list of candidate tiles. |
| Procedural approach | N/A |
| Runtime perf risk | Improvement. |
| Memory/CPU/GPU impact | Small bounded cache. |
| Reusability across other projects | Medium |
| Acceptance test | Profile shows fewer per-frame ms in `get_tile_data_at_world_position`. |
| Do now / later | Do now |

#### 5.10 ArenaMinimapHandler throttle audit

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §7 confirms it already throttles, but verify the throttle interval and add a configurable cap per quest-signal burst. |
| Source | Agent 1 §7; Agent 2 §1.3 |
| Files likely affected | `Components/Arena/ArenaMinimapHandler.gd` |
| Risk level | low |
| Modular/reusable design approach | Move throttle to GameClock tick at 5Hz (200ms). |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | Pattern is portable. |
| Acceptance test | Minimap updates feel responsive but never exceed 5Hz. |
| Do now / later | Do now |

---

### Phase 6 — Polish, Tests, Docs, Portability

#### 6.1 Restore the test suite

| Field | Value |
|---|---|
| Reason it matters | Agent 2 §1.3 + Appendix A: only `test_fire_spread.gd` survives; 8+ test `.gd.uid` orphans suggest tests existed and were deleted. Rebuilding even minimal coverage prevents regressions in Phase 1–5 work. |
| Source | Agent 2 §1.3, Appendix A |
| Files likely affected | New `tests/test_breeding.gd`, `tests/test_capture.gd`, `tests/test_tile_signal.gd`, `tests/test_tree_spawn.gd` |
| Risk level | low |
| Modular/reusable design approach | Test-per-component matching AGENTS.md guidance: verify `setup()`, signal emissions, edge cases. |
| Procedural approach | N/A |
| Runtime perf risk | N/A |
| Memory/CPU/GPU impact | N/A |
| Reusability across other projects | High — testing conventions are portable. |
| Acceptance test | All four tests pass on local + CI. |
| Do now / later | Do now (after each of Phase 1–5 lands) |

#### 6.2 Apply SYNC RULE retroactively

| Field | Value |
|---|---|
| Reason it matters | Abilities.md / Actor.md / UI.md headers state "SYNC RULE: update doc in same commit." After Phase 1–5, regenerate version stamps. |
| Source | Agent 1 §8 SYNC RULE |
| Files likely affected | `Markdowns/Abilities.md`, `Markdowns/Actor.md`, `Markdowns/UI.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Versions bumped, dates current, component lists match code. |
| Do now / later | Do now (after each landing) |

#### 6.3 Resolve the `Markdowns/.ziva_update_staging` duplicate Ziva README

| Field | Value |
|---|---|
| Reason it matters | Agent 1 §9.3 D1. Bit-identical duplicate. |
| Source | Agent 1 §9.3 D1 |
| Files likely affected | `addons/.ziva_update_staging/addons/ziva_agent/README.md` |
| Risk level | low |
| Modular/reusable design approach | N/A |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | N/A |
| Acceptance test | Duplicate removed or staging folder documented. |
| Do now / later | Do now |

#### 6.4 Add per-module README.md for each Phase 2/3 extracted module

| Field | Value |
|---|---|
| Reason it matters | Modules without docstring + README don't get reused. |
| Source | Derived from Phase 2/3 |
| Files likely affected | Each new module folder |
| Risk level | low |
| Modular/reusable design approach | One short README per module: purpose, dependencies, API, drop-in instructions. |
| Procedural approach | N/A |
| Runtime perf risk | None |
| Memory/CPU/GPU impact | None |
| Reusability across other projects | This *is* the portability story. |
| Acceptance test | Every module folder has a README. |
| Do now / later | Do now (after each extraction) |

---

## 3. Modular Systems Extraction Plan

Non-procedural reusable extractions, expected portable shape.

| Module | Source code | Target portable shape | Dependencies stripped |
|---|---|---|---|
| `GameClockComponent` | `Components/GameClockComponent.gd` | Autoload-or-component tick bus; pure GDScript; `register_tick(callable, interval)` / `unregister_tick(id)` / `wait(seconds)` helper | None (after Phase 1) |
| `TileSignalComponent` | `Components/Arena/TileSignalComponent.gd` | Generic distance-trigger registry; `distance_fn` injectable so non-hex projects can use Manhattan/Chebyshev/Euclidean | Hardcoded `_get_hex_distance` (after Phase 1) |
| `NodePool` | extracted from `Components/ActorComponents/HealthBarPool.gd` | `NodePool.new(scene, max, on_acquire, on_release)`; `acquire()` / `release()` | None |
| `ResourceSaveStore` | extracted from `Core/Managers/SaveComponent.gd` | Generic deferred ResourceSaver with debounce; `save(resource)` / `load() -> Resource` | Goat-specific assumptions |
| `ScenePaths` | new `Core/ScenePaths.gd` | Project-specific constants but pattern-portable | N/A — pattern only |
| `AbilityRegistry` | from `UI/MainMenu.gd:67-100` introspection | Filesystem-scan registry of ability scripts | One-shot reflection at MainMenu open |
| `FactionComponent` | `src/actors/ai/FactionComponent.gd` | After replacing hardcoded matrix with `FactionData` Resource (deferred to Phase 4 if time) | Hardcoded faction matrix |
| `AbilityAction` + `AbilityComponent` pair | as-is | Already RefCounted-based, minimal | None |
| `ActorFactory` | extracted from `Components/Arena/ArenaSpawner.gd` `match type` | Registry: `register(actor_type, scene)` + `spawn(actor_data, position)` | Hardcoded scene preloads |
| `ActorCard` (generic) + `ActorCardRenderer` | `UI/DisplayCard/ActorCard.gd`, `UI/GoatRenderer.gd` | Card that consumes any `ActorData`; renderer dispatches on `get_actor_type()` | `goat_data` alias |
| `DebugSettings` (namespace within `GameSettings`) | extension of `Core/GameSettings.gd` | Persisted debug toggles via the existing settings.cfg pipeline | None |
| `WeaponListPanel` / `CardDisplayPanel` | extracted from `UI/PlayerConsole.gd` | Self-contained `Control` panels with their own signals | PlayerConsole orchestrator dependence |

---

## 4. Procedural Systems Extraction Plan

| Module | Source code | Config schema sketch | Output |
|---|---|---|---|
| `SeededGenerator` (base) | new `Components/Modules/Procedural/SeededGenerator.gd` | `seed: int`; `child_rng(salt: String) -> RandomNumberGenerator` | Sub-stream RNGs |
| `WeightedPoolSpawner<T>` | from `src/trees/TreeSpawner.gd` + `BiomeData.gd` | `WeightedEntry { weight: float; payload: Resource }`; `PlacementRule { can_place(tile, neighbors); weight_at(tile) }` | Array of placed payloads |
| `TerrainProfile` | new `Components/Arena/TerrainProfile.gd` | `noise: FastNoiseLite; dirt_threshold: float; height_levels: int; height_curve: Curve; biome_id: StringName` | Tile-type + height per coord |
| `FloodFillRegionPlanner` | from `GridGenerator.plan_farmstead()` | `plan(origin, target_size, neighbor_fn, can_include_fn, rng) -> Array[Vector2i]` | Region tile set |
| `TraitInheritanceEngine` | from `GoatData.create_offspring()` | `TraitSchema { traits: Array[TraitDef] }`; `TraitDef { name; mode: enum(MENDELIAN, QUANTITATIVE, ENVIRONMENTAL, MUTATIONAL); mean_mutation: float; categorical_options }` | Offspring `ActorData` |
| `SpawnVarianceConfig` | new `Components/BreedingComponents/SpawnVarianceConfig.gd` | `distribution: enum(UNIFORM, GAUSSIAN, BOUNDED); per_stat_overrides: Dictionary[StringName, StatVariance]` | Randomized stat block |
| `RegionData` + `EdgeProfile` | new `Play Space/Regions/RegionData.gd` | `RegionData { id; size; terrain_profile; edges: Array[EdgeProfile]; biome_id }`; `EdgeProfile { edge_type: enum(STONE, MOUNTAIN, OCEAN, GATE); gate_unlock_quest_id }` | Complete region instance |
| `RoadProfile` (consumed by RoadGenerator) | new | `RoadProfile { primary_count: int; dead_end_chance: float; building_access: bool }` | `Array[Vector2i]` road tiles |
| `CreatureDefinition` | new (Phase 4.7) | Per `procedural_character_framework.md`: body proportions, color palette, detail level enum | Input to LimbBuilder + downstream |
| `ElementalProfile` | new (Phase 4.6) | `element: StringName; tile_reactions: Array[TileReaction]; projectile_scene: PackedScene` | Configured elemental actor |
| `CaptureProfile` | new (Phase 4.1) | `restraint_resistance: int; escape_dc_per_restraint: Curve; taming_loyalty_curve: Curve; flee_chance_after_break: float` | Capture/taming behavior |
| `BuildingProfile` | new (Phase 4.10) | `footprint: Vector2i; required_tiles: Array[TileType]; interaction_component: PackedScene` | Placed ranch building |

---

## 5. Patch Order That Avoids Regressions

Strict ordering. Each phase's success preconditions are listed.

1. **Phase 0** entirely first. Nothing in 0 changes behavior except 0.3 (one-line scene-path fix). No risk of regressing other work.
2. **Phase 1.1** (breeding loop) before Phase 2.7 (HerdManager docstrings), Phase 2.8 (ActorFactory), and Phase 2.9 (generic ActorCard) — because 1.1 changes `selected_goat → selected_actor_data` which all three downstream tasks consume.
3. **Phase 1.2 + 1.3 + 1.5** (TileSignal Timer, Detection Timer, QuestStarterKit guard) before Phase 2.1 + 2.2 (extract GameClock + TileSignal modules) — extracting a module that violates its own contract is wrong.
4. **Phase 2.1** (GameClock module) before any Phase 5 task that uses `GameClockComponent.register_tick()` from a new site.
5. **Phase 2.3** (NodePool) before Phase 5.3 (projectile pooling).
6. **Phase 3.1** (SeededGenerator) before Phase 3.2 (WeightedPoolSpawner) and Phase 3.3 (TerrainProfile) — they consume it.
7. **Phase 2.8** (ActorFactory) before Phase 4.1 (Capture — needs to spawn captured-then-tamed actors generically), Phase 4.6 (Earth/Air elementals — new actor types should register via factory), and Phase 4.7+ (Procedural Creatures — they spawn through the factory).
8. **Phase 3.5** (TraitInheritanceEngine) before Phase 4.6 (Earth/Air elementals) and Phase 4.1 (Capture) if the latter needs taming-loyalty inheritance.
9. **Phase 3.3 + 3.4** (TerrainProfile, FloodFillRegionPlanner) before Phase 4.2 (RegionData) — RegionData composes both.
10. **Phase 4.2** (RegionData) before Phase 4.3 / 4.4 / 4.5 (edge variations, quest-gate unlock, RoadGenerator).
11. **Phase 5 work** lands incrementally **after** Phase 1, but does not need to wait for all of Phase 4. Specifically:
    - 5.1 (VisibilityManager) is independent; can ship as soon as Phase 1 is in.
    - 5.2 (per-frame → GameClock) needs Phase 2.1.
    - 5.3 (projectile pool) needs Phase 2.3.
    - 5.4 (`SceneTreeTimer` removal) needs Phase 2.1 `wait(seconds)` helper.
    - 5.5 (ItemsAutoload lazy) is independent.
    - 5.6 (static-obstacle batching) needs Phase 1.2 (TileSignal cleanup).
    - 5.8 (tree LOD wiring) needs Phase 5.1 done first (don't add LOD work on top of an already-thrashing VisibilityManager).
12. **Phase 6** runs alongside, not after — each module extracted in Phase 2/3 gets its README in the same PR; each system fixed in Phase 1/4/5 gets its doc updated in the same commit per SYNC RULE.

**Hard "do not break" gates** (Agent 2 §11): any change to `project.godot`, `Play Space/Arena.gd`, `Play Space/Arena.tscn`, `src/actors/base/Actor.gd`, `Components/GameClockComponent.gd`, `Components/Arena/TileSignalComponent.gd`, `Components/Arena/GridGenerator.gd`, `Core/GameEvents.gd`, `Core/ItemsAutoload.gd`, `Core/WeaponData.gd`, or `UI/MainMenu.tscn` requires the corresponding acceptance test from the relevant phase to pass before merge.

---

## 6. Reusable Module List For Other Projects

One-line "what it gives you" inventory.

- **`GameClockComponent`** — Drop-in centralized tick bus. 1 clock, N callers, zero Timer nodes per actor.
- **`TileSignalComponent`** (with injectable `distance_fn`) — Proximity/trigger registry that scales without per-frame distance math.
- **`NodePool`** — Generic Godot scene pool with acquire/release/auto-reset.
- **`ResourceSaveStore`** — Deferred ResourceSaver with debounce; works for any save shape.
- **`ScenePaths`** — Project-local constants for every scene-change path, catches typos at parse time.
- **`AbilityRegistry`** — Filesystem-scan registry of scripts with a convention (`class_name SomethingAction`).
- **`AbilityAction` + `AbilityComponent` pair** — RefCounted-based minimal action framework, actor-agnostic.
- **`HealthBarPool`** — Already a real pool; usable for any "fleet of UI billboards" need.
- **`FactionComponent`** (after Phase 4 generalization) — Faction relationship matrix with cached ally/enemy lookups.
- **`StatusEffectComponent`** — Tick-driven buff/debuff applier that integrates with GameClock and TileSignal.
- **`UIStyle`** — Central color/StyleBoxFlat factory.
- **`DisplayCardBase`** — Base for any "card showing a Resource" UI.
- **`CycleSelector` / `StationaryCycler`** — Generic dropdown/cycler used by character + map settings UI.
- **`MapSettingsHelper`** — Static utility for collecting/applying map config.
- **`ActorFactory`** — Data-keyed actor spawner; register `ActorData` type → `PackedScene`, spawn by data.
- **`ActorCard` (generic) + `ActorCardRenderer`** — Card UI that consumes any `ActorData`; renderer dispatches per actor type.
- **`WeaponListPanel` / `CardDisplayPanel`** — Reusable PlayerConsole sub-panels with their own signal contracts.
- **Persisted settings via `GameSettings` pattern** — `ConfigFile`-backed exported properties autoload (use the pattern as-is, swap keys per project).

---

## 7. Reusable Procedural Generator List For Other Projects

- **`SeededGenerator`** — Deterministic seeded RNG with named sub-streams.
- **`WeightedPoolSpawner<T>`** — Seeded weighted pool spawning with pluggable placement rules; works for trees, props, enemies, loot.
- **`TerrainProfile`** — Noise + curve → tile-type + height-level, swap profiles to change biome.
- **`FloodFillRegionPlanner`** — Deterministic flood-fill carving with shuffled neighbor order; "rough organic region" generator.
- **`TraitInheritanceEngine`** — Mendelian / quantitative / environmental / mutational trait inheritance for any `*Data` resource.
- **`SpawnVarianceConfig`** — UNIFORM/GAUSSIAN/BOUNDED stat variance applied at spawn time.
- **`RegionData` + `EdgeProfile`** — Composable region descriptor for multi-region streaming.
- **`RoadProfile` + RoadGenerator** — A* hex pathfinding configured by per-region road profile.
- **`CreatureDefinition`** (from Procedural Character Framework) — Data-only creature spec consumed by LimbBuilder + downstream generators.
- **`BiomeData`** (specialization of WeightedPoolSpawner config) — Per-biome flora density and weighting.

---

## 8. Performance Optimization Checklist

Direct mapping from Agent 2 §10 to action items. Check each off as it lands.

- [ ] **Timer-node removal** in `TileSignalComponent.gd` (Phase 1.2) and `DetectionComponent.gd` (Phase 1.3). These are correctness violations, not pure perf.
- [ ] **VisibilityManager** — chunked per-frame foliage scan + debug-print gate (Phase 5.1).
- [ ] **AbilityComponent `_process`** moved to GameClock 10Hz tick (Phase 5.2).
- [ ] **HarvestableTree `_process`** disabled unless actor in proximity via TileSignal continuous mode (Phase 5.2).
- [ ] **Actor.gd `_physics_process` fallback accumulator** — only run if no GameClock found (already conditional; verify the cost only fires in fallback path, Phase 5.2).
- [ ] **Projectile pooling** for lob/spread shots (Phase 5.3, uses NodePool from 2.3).
- [ ] **`SceneTreeTimer` removal** at all 6 call sites (Phase 5.4).
- [ ] **QuestSpawnManager spawn-loop awaits** — coroutine that schedules via GameClock instead of one timer per goblin per camp (Phase 5.4).
- [ ] **ItemsAutoload lazy load** + Resource-directory weapon scan (Phase 5.5).
- [ ] **Arena static-obstacle batching** — O(1) `_static_obstacle_set` lookup vs iterating all triggers (Phase 5.6).
- [ ] **GoatActor double-iteration** — cache GoatCharge ref at ready (Phase 5.7).
- [ ] **Tree LOD wiring** + visible-tree cap (Phase 5.8).
- [ ] **Spatial-hash cache** for `Arena.get_tile_data_at_world_position` (Phase 5.9).
- [ ] **Minimap throttle** moved to GameClock 5Hz (Phase 5.10).
- [ ] **Shared materials** on trees per TreeGeneration.md §13.4 — verify TreeBlueprint actually shares material instances (Phase 5.8 verification).
- [ ] **CSG → baked MeshInstance3D** for production tree variants per §13.1 — defer; mark in Phase 4.11 backlog.
- [ ] **Tree spawn batching** — verify the existing `SPAWN_BATCH_SIZE := 10` in TreeSpawner is still honored after Phase 3.2 refactor.

---

## 9. Testing Checklist

After each patch ships, verify the corresponding acceptance test. The full smoke flow after every Phase landing:

1. **Boot** — MainMenu loads under 2s, no errors in `Output` panel.
2. **Settings persistence** — change a map setting, restart, setting persists.
3. **Arena entry** — pick a character, enter Arena, all autoloads present.
4. **Tile interactions** — `test_fire_spread.gd` passes; throw fire projectile on grass, fire spreads, water extinguishes.
5. **Combat** — Goblin AI engages player, weapon swings hit, projectiles pick up.
6. **Quest** — Accept goblin quest from quest board → camp markers appear at edge → approach camp → goblins spawn (no duplicate spawns; no per-goblin timer regressions).
7. **Tree harvest** — Hit a tree with a weapon, HP drops, tree falls into log pile (after Phase 4.11).
8. **Status effects** — Stand in fire → burn ticks via GameClock. Stand in water → sinking applied.
9. **Capture** (after Phase 4.1) — Throw net at wild goat, RESTRAINED, drag to ranch, taming completes, goat in herd.
10. **Ranch loop** — Return from Arena to Ranch (after Phase 0.3) succeeds; breeding two adults produces a kid after 3 in-game days (after Phase 1.1).
11. **Save/load** — Close game, re-open, herd state intact.
12. **Stress test** — Spawn 50 actors + 200 trees: frame time within budget (after Phase 5.1–5.8).

After Phase 1 → re-run 1, 3, 4, 5, 6, 8, 10.
After Phase 2 → re-run 1, 3, 4, 5, 7, 8, 10, 11.
After Phase 3 → re-run 1, 3, 4 (world generation identical for same seed), 7.
After Phase 4 → run 9 plus its specific section's acceptance tests.
After Phase 5 → re-run 12 with Profiler.

---

## 10. The Next 10 Safest Tasks (ordered)

In priority order. Each is from Phase 0 or Phase 1; each has the lowest blast radius for its expected payoff.

1. **0.3** — Fix Ranch return scene path in `ArenaUIHandler.gd:107`. **One line. Restores documented intent. Zero risk.**
2. **0.1** — Delete 30+ orphan `.uid` files. **Deletion-only, no behavior change, but removes long-standing rot.**
3. **0.2** — Delete 8 editor-crash `.tmp` files. **Deletion-only.**
4. **0.4** — Fix AGENTS.md GameClockComponent path. **Doc-only, removes the lie about the most-referenced architecture rule.**
5. **0.7** — Update README `GoatManager` → `HerdManager`. **Doc-only, reflects what shipped 2025-01-28.**
6. **0.10** — Delete legacy 2D `player.gd` + `player.tscn` (after Grep confirms zero references — Agent 2 already did). **Removes 2D leftover that confuses framework choice.**
7. **0.8** — Mark Capture.md deprecated, point to Breeding.md `ActorState`. **Doc-only, prevents Phase 4 implementing the wrong API.**
8. **1.5** — Switch `QuestStarterKit._ensure_tile_signal_component` from name-check to group-check. **Removes the fragile load-order dependency Agent 2 flagged.**
9. **1.2** — Remove `Timer.new()` from `TileSignalComponent`, replace with GameClock registration. **Highest-value Phase 1 fix: the component that enforces the no-Timer rule should obey it.**
10. **1.3** — Remove `Timer.new()` from `DetectionComponent`, replace with `Actor.register_tick`. **Direct follow-on to #9; eliminates N-per-actor Timer pattern.**

---

*End of Agent 3 plan.*
