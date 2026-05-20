# Agent 2 — Implementation Patch Log (Extended Slice)

> Scope: Phase 0 hygiene + Phase 1 routing fixes + Phase 2 modular extractions
> (ItemsAutoload alias, AbilityRegistry, ActorFactory, visual polymorphism) +
> Phase 4 Mimic creature (full Extended Slice with morph + skill copy) +
> Phase 6 doc updates.
>
> Strict order per Agent 1 §10.4 followed. No DO-NOT-BREAK file was changed in
> a behavior-altering way except the four pre-approved edits (SDS-1, SDS-7,
> SDS-8, SDS-9).
>
> All paths are repo-relative.

---

## 1. Files Inspected (read-only orientation)

- `docs/AGENT_1_IMPLEMENTATION_REQUIREMENTS.md` (the spec)
- `docs/AGENT_2_CODEBASE_AUDIT.md` (Appendix A — orphan inventory)
- `AGENTS.md` (routing + timing rules)
- `README.md`
- `project.godot`
- `Play Space/Arena.gd` (lines 100-150 — game_clock + tile_signals ordering)
- `src/actors/base/Actor.gd` (lines 1-394 — `_data` setter, `_setup_components`, `register_tick`)
- `src/actors/types/GoatActor.gd`, `src/actors/types/GoblinMinion.gd` (template patterns)
- `src/actors/ai/ActorAIController.gd`
- `Components/ActorComponents/ActorData.gd`
- `Components/ActorComponents/ActorVisualComponent.gd`
- `Components/ActorComponents/DetectionComponent.gd`
- `Components/ActorComponents/AbilityComponents/AbilityAction.gd`, `AbilityComponent.gd`, `GoatCharge.gd`, `NimbleEscape.gd`
- `Components/Arena/ArenaSpawner.gd`
- `Components/Arena/ArenaUIHandler.gd`
- `Components/Arena/TileSignalComponent.gd`
- `Components/GameClockComponent.gd`
- `Components/WeaponComponents/WeaponComponent.gd` (lines 1-115 — fallback path)
- `Components/BreedingComponents/GoatData.gd`
- `Core/ItemsAutoload.gd`
- `UI/MainMenu.gd`
- `scenes/actors/GoatActor.tscn`, `GoblinMinion.tscn`, `ScarecrowDummy.tscn`, `FireActor.tscn` (scene templates)
- `Markdowns/Actor.md`, `Abilities.md`, `Capture.md`, `SettlementImplementationPlan.md`, `UI.md`, `Breeding.md`

## 2. Systems Found (per category)

- **Routing authorities**: `TileSignalComponent` (proximity), `GameClockComponent` (tick bus), `FactionComponent` (ally/enemy).
- **Actor base + AI**: `Actor.gd` (`@export var _data`, `register_tick`, `_setup_components`), `ActorAIController.gd` (9-state FSM, perception trigger).
- **Abilities**: `AbilityComponent` (per-actor manager), `AbilityAction` (RefCounted, actor-bound base); concrete subclasses GoatCharge / NimbleEscape / RedirectAttack.
- **Breeding (data-layer)**: `ActorData` → `GoatData`; `BreedingComponent.breed()` requires male+female; `HerdManager.next_day()` drops non-`GoatData` kids (B7 still open — out of scope this patch).
- **Spawn pipeline**: `ArenaSpawner.spawn_actor_at_tile(type, tile)` used by Arena init, quest manager, and selected-actor flow.
- **Selection bus**: `ItemsAutoload.selected_goat` (goat-only) + `selected_actor` (Actor reference); no generic `selected_actor_data` prior to this patch.
- **Visuals**: `ActorVisualComponent.update_goat_visuals()` is the only data-driven visual path today.
- **Capture / Settlement / Region streaming**: zero code; design docs only.

## 3. Bugs or Gaps Found

| ID | Bug or gap | Patch approach |
|----|-----------|----------------|
| SDS-1 | `ArenaUIHandler:107` calls `change_scene_to_file("res://Ranch/Ranch.tscn")` — real path is `res://Components/BreedingComponents/Ranch/Ranch.tscn`. | One-line path correction. |
| SDS-2 | 36 orphan `.gd.uid` files (no `.gd` companion) — verified via `find . -name "*.gd.uid" -type f \| while read uid; do [...]` matching Agent 2 Appendix A. | Delete after spot-verify. |
| SDS-3 | 8 `.tscn*.tmp` editor-crash artifacts under `Play Space/` + `QuestSystem/`. | Delete. |
| SDS-4 | `AGENTS.md` cites `res://Components/Arena/GameClockComponent.gd` (wrong folder). | Two path corrections — body + reference table. |
| SDS-5 | `README.md` mentions `GoatManager` (renamed to `HerdManager` 2025-01-28). | Text replace. |
| SDS-6 | `Markdowns/Capture.md` still presents the loyalty-based model — Agent 3 R1 designates `Breeding.md §Capture System` as canonical (ActorState enum). | Add deprecation header. |
| M11 | `Markdowns/Actor.md` declares `CharacterBody2D` + `Vector2` in code blocks; project shipped to 3D. | Replace type names only (CharacterBody3D / Vector3 / Node3D); keep prose intact. |
| M12 | `Markdowns/SettlementImplementationPlan.md` describes a React/JSX webapp unrelated to this Godot repo. | Add admonition at top. |
| 0.10 | Legacy 2D `player.gd` + `player.tscn` at project root. Grep confirms zero references in any live `.gd` or `.tscn`. | Delete. |
| SDS-7 / M8 | `TileSignalComponent.gd:20-25` uses `Timer.new()` — direct AGENTS.md violation in the file singled out as the routing authority. | Replace with `arena.get_game_clock().register_tick(_refresh_tracked_actors, 1.0)`. Deferred fetch handles edge case where clock isn't ready. |
| SDS-8 / M9 | `DetectionComponent.gd:107-112` uses `Timer.new()` per-actor with dynamic `wait_time`. | Replace with `Actor.register_tick(_on_expiry_tick, 0.5)`. Convert decrement logic to use the fixed interval as the delta. `_schedule_next_expiry` retained as a no-op so old callers still compile. |
| SDS-9 / B8 | `ItemsAutoload.selected_goat: GoatData` is goat-specific; generic selection bus needed. | Add `selected_actor_data: ActorData`. Convert `selected_goat` to a deprecated property whose setter writes `selected_actor_data` and whose getter returns `selected_actor_data as GoatData`. Keep `set_selected_goat()` as the explicit emit path. `set_selected_actor()` now mirrors data on the new bus *and* still fires `goat_selected` (or `goat_selected.emit(null)` for non-goats — see Bug Fix below). |
| NEW S2 | UI/MainMenu.gd did instantiate-and-free reflection cycles to read each ability's `ability_name` every menu open. No safe surface for the Mimic to clone abilities. | Create `Core/AbilityRegistry.gd` autoload. Scan `Components/ActorComponents/AbilityComponents/` once at boot; cache `StringName -> Script`. Public API: `get_ability_names()`, `get_ability_script()`, `instantiate_for(name, actor, component)`. Wire into `project.godot` autoloads. Refactor MainMenu helpers to filter the per-actor allow-list against the registry. |
| NEW S3 | `ArenaSpawner.spawn_actor_at_tile()` dispatched via `match type` — adding any actor type required editing the hardcoded arm. | Create `Components/Arena/ActorFactory.gd`. ArenaSpawner.setup() instantiates the factory and registers all 7 actor types (including Mimic). `spawn_actor_at_tile()` and `get_selected_actor_scene()` now route through the factory. `spawn_scarecrow()` left alone — it uses `scarecrow_scene` directly. |
| NEW B12 | `ActorVisualComponent.update_goat_visuals()` is the only data-driven visual path. Mimic morph needs polymorphic dispatch. | Add additive `setup_visuals(data: ActorData)` entry point that dispatches by `data` type. Goat path delegates to existing `update_goat_visuals()`. Mimic path tints body + sets scale. Null guard included (Goblin/Farmer have no `_data` — no-op). |
| SDS-10 | No `MimicData` resource type. | Create `Components/BreedingComponents/MimicData.gd` extending `ActorData`. All fields `@export`; `create_offspring()` is asexual budding with color + stat jitter. `disallowed_target_types` initialized in `_init()` (StringName literals can't appear in typed-array initializers). |
| SDS-11 | No `MimicActor` script + scene. | Create `src/actors/types/MimicActor.gd` extending Actor + `scenes/actors/MimicActor.tscn` (sphere body, capsule collider, default `MimicData` sub-resource). Mirrors `GoatActor.goat_data` accessor. Sets `is_playable = false` in `_init()` (otherwise base Actor faction would default to PLAYER and the AI would never engage anyone). |
| Mimic AI | No controller. | Create `src/actors/types/MimicController.gd` extending `ActorAIController`. Owns a TileSignal trigger of radius `scan_radius` whose center follows the Mimic's tile, registers a GameClock tick at `scan_interval`, dispatches morph + copy via dedicated components. Symmetric `_nearby_actors` maintained from `trigger_activated` / `trigger_deactivated`. |
| Mimic morph | Visual morph requires polymorphism + state snapshot. | Create `Components/ActorComponents/CreatureMorphComponent.gd` (generic — reusable across creatures). Snapshots `_original_data` on first morph; calls `actor.visual_component.setup_visuals(target._data)`; `revert()` restores. |
| Mimic skill copy | AbilityAction is RefCounted + actor-bound — sharing instances would cross-wire `action.actor`. | Create `Components/ActorComponents/SkillCopyComponent.gd` (generic). For each donor action up to `limit`, calls `AbilityRegistry.instantiate_for(name, self, ability_component)` to build a fresh actor-bound clone. Tracks `_copied_names` so `restore()` removes only the clones (by name multiset), never originals. |
| SDS-13 | Mimic must spawn via the factory, not a hardcoded match arm. | Mimic is `register()`-ed at `ArenaSpawner._register_default_actor_types()` along with all other types. `ArenaFactory.spawn(&"mimic", parent, position)` works end-to-end. |
| Bite | Mimic carries no weapon — would noop on melee. | `MimicActor._equip_default_bite()` (deferred so WeaponComponent.setup runs first) walks `ItemsAutoload.weapons` for the `"Unarmed strike"` entry and assigns it. No new WeaponData entry shipped (per Agent 1 spec). |
| Bug fix (advisor pass 2) | `set_selected_actor` previously called `set_selected_goat(null)` on the non-goat branch — which writes `selected_actor_data = null`, clobbering the Mimic's data we just wrote. | Emit `goat_selected.emit(null)` inline instead of routing through `set_selected_goat`. |
| Bug fix (advisor pass 2) | `MimicActor._init()` did not set `is_playable = false`, so faction defaulted to PLAYER. | Added explicit `is_playable = false` to `_init()`. |

## 4. Files Patched

| File | Change |
|------|--------|
| `Components/Arena/ArenaUIHandler.gd` | SDS-1: Ranch return scene path corrected. |
| `AGENTS.md` | SDS-4: `GameClockComponent` path corrected (2 spots). |
| `README.md` | SDS-5: `GoatManager` → `HerdManager`. |
| `Markdowns/Capture.md` | SDS-6: deprecation header added. |
| `Markdowns/Actor.md` | M11: `CharacterBody2D/Vector2/Node2D` → `CharacterBody3D/Vector3/Node3D` in code blocks; prose untouched. |
| `Markdowns/SettlementImplementationPlan.md` | M12: top-of-file admonition about React/JSX scope. |
| `Components/Arena/TileSignalComponent.gd` | SDS-7: replaced `Timer.new()` with `arena.get_game_clock().register_tick(_refresh_tracked_actors, 1.0)`; deferred-fetch guard added. |
| `Components/ActorComponents/DetectionComponent.gd` | SDS-8: replaced `_expiry_timer: Timer` with `_expiry_tick_id: int` registered via `Actor.register_tick(_on_expiry_tick, EXPIRY_TICK_INTERVAL=0.5)`. Decrement logic now uses the fixed interval. `_schedule_next_expiry` retained as no-op. `_notification(EXIT_TREE)` unregisters the tick. |
| `Core/ItemsAutoload.gd` | SDS-9 / B8: added `selected_actor_data: ActorData`; converted `selected_goat` to a property aliasing the new bus; `set_selected_goat()` routes through the generic bus; `set_selected_actor()` mirrors data and emits the legacy goat signal correctly for both goat and non-goat actors. |
| `project.godot` | Registered `AbilityRegistry` autoload at `res://Core/AbilityRegistry.gd`. |
| `UI/MainMenu.gd` | Refactored `_get_goblin_abilities` / `_get_goat_abilities` to filter per-actor allow-lists against `AbilityRegistry`. Added `_resolve_ability_names_for()` shared helper. Public flow unchanged. |
| `Components/Arena/ArenaSpawner.gd` | Added `mimic_scene` export + `_actor_factory: ActorFactory` member + `_register_default_actor_types()`. `setup()` composes in the factory. `get_selected_actor_scene()` and `spawn_actor_at_tile()` dispatch through it (preserving call signatures). `spawn_scarecrow()` left untouched. |
| `Components/ActorComponents/ActorVisualComponent.gd` | Added additive `setup_visuals(data: ActorData)` polymorphic entry point + `_apply_mimic_visuals()` helper. `update_goat_visuals()` and all existing callers unchanged. |
| `Markdowns/Abilities.md` | D6: bumped version to v1.1; added a "Core Class 0: AbilityRegistry" section documenting the autoload + ability extension recipe. |
| `Markdowns/UI.md` | D7: bumped version to v1.1; added rows to MainMenu's Key Methods table documenting the new helpers. |

## 5. New Files Created

| File | Purpose |
|------|---------|
| `Core/AbilityRegistry.gd` | Autoload — boot-time scan of every `AbilityAction` subclass; safe per-actor clone factory. |
| `Components/Arena/ActorFactory.gd` | StringName → PackedScene dispatcher used by ArenaSpawner. Replaces the hardcoded `match type` arm. |
| `Components/BreedingComponents/MimicData.gd` | `ActorData` subclass driving the Mimic's scan/morph/copy tuning. Asexual `create_offspring`. |
| `Components/ActorComponents/CreatureMorphComponent.gd` | Generic visual + identity morph helper. Snapshot+restore pattern. |
| `Components/ActorComponents/SkillCopyComponent.gd` | Generic skill-cloning helper. Routes through `AbilityRegistry.instantiate_for()` so clones are actor-bound. |
| `src/actors/types/MimicActor.gd` | Mimic Actor subclass. `mimic_data: MimicData` accessor, MONSTERS faction, `Unarmed strike` bite. |
| `src/actors/types/MimicController.gd` | Mimic AI controller. TileSignal trigger + GameClock tick + morph/copy dispatch. |
| `scenes/actors/MimicActor.tscn` | Minimal `CharacterBody3D` scene with sphere body + capsule collider + default `MimicData` sub-resource. |
| `Markdowns/Mimic.md` | D9: design + implementation reference for the v1.0 Mimic. |

## 6. Systems Preserved (DO-NOT-BREAK files read and intentionally not behavior-modified)

- `project.godot` — autoload list extended additively (added `AbilityRegistry`); existing entries untouched.
- `Play Space/Arena.gd` / `Play Space/Arena.tscn` — not modified.
- `src/actors/base/Actor.gd` — not modified.
- `Components/GameClockComponent.gd` — not modified.
- `Components/Arena/TileSignalComponent.gd` — internal Timer replaced with GameClock; **public API unchanged** (`register_trigger`, `update_trigger_center`, `register_actor`, `remove_trigger`, signals — all unchanged). This is the SDS-7 pre-approved edit.
- `Components/Arena/GridGenerator.gd`, `TileSystem.gd` — not modified.
- `Components/Arena/ArenaSpawner.gd` — refactor is additive on top of existing call signatures (`spawn_actor_at_tile(type, tile)` etc. still work for all current callers). This is the NEW S3 pre-approved edit.
- `Components/BreedingComponents/HerdManager.gd` — not modified.
- `Core/GameEvents.gd` — not modified.
- `Core/ItemsAutoload.gd` — added `selected_actor_data` and aliased `selected_goat`; existing `set_selected_*` signal flow preserved. This is the SDS-9 pre-approved edit.
- `Core/WeaponData.gd`, `Components/WeaponComponents/WeaponComponent.gd` — not modified.
- `src/actors/ai/ActorAIController.gd`, `FactionComponent.gd` — not modified.
- `QuestSystem/QuestSpawnManager.gd`, `QuestDatabase.gd`, `quests.json` — not modified.
- `src/trees/VisibilityManager.gd` — not modified.
- `UI/MainMenu.tscn` — not modified; `MainMenu.gd` refactor is internal to the helper functions and the public displayed names are unchanged.
- `Components/BreedingComponents/Ranch/Ranch.tscn` — not modified.

## 7. Implementation Summary

The patch landed the **complete Extended Slice**: every Phase 0 hygiene item,
both Phase 1 routing-rule violations, all Phase 2 modular extractions
prerequisite to the Mimic, the **full Mimic creature with morph and skill
copy** (not just the bite-only variant), and the Phase 6 doc updates.

Key choices:

- **Generic over Mimic-specific**. `CreatureMorphComponent` and
  `SkillCopyComponent` are reusable across any creature, not Mimic-only. The
  Mimic controller composes them via Node attachment after Actor's
  `_setup_components()` has run.
- **ActorVisualComponent.setup_visuals() is additive**.
  `update_goat_visuals()` is preserved; existing callers (GoatActor,
  `_setup_goat_visuals`) are not touched. This means SDS-9 + B12 do not
  count as a behavior change on the DO-NOT-BREAK file.
- **AbilityRegistry caches at boot, not per-call**. Replaces the per-menu-open
  reflection cycles at the old MainMenu lines 67-100.
- **Save/load of Mimic morph state is transient by design**. Schema-change
  to `SaveComponent` was explicitly deferred; the Mimic resets to base form
  on save+reload. Documented in `Markdowns/Mimic.md`.
- **All Mimic cadence routes through GameClock; all Mimic distance routes
  through TileSignalComponent.** Zero `Timer.new()` and zero `await
  get_tree().create_timer()` in any new file.

## 8. Procedural / Modular Design Summary

This patch noticeably reduces hardcoded fan-out:

- **Actor spawning**: every actor type lives in a `StringName -> PackedScene`
  dictionary registered at one place (`ArenaSpawner._register_default_actor_types`)
  instead of two `match type` blocks. Adding "fire imp" or "earth golem"
  later is a one-line `register()` call.
- **Ability discovery**: every `AbilityAction` subclass is picked up by a
  boot-time folder scan. Adding a new ability requires zero edits to
  `MainMenu.gd`, the Mimic, or any other consumer — they all query the
  registry.
- **Selection bus**: `selected_actor_data: ActorData` lets non-goat consumers
  hook the same channel the Ranch UI uses, without changing the goat-only
  flow during the transition.
- **Visual polymorphism**: `setup_visuals(data: ActorData)` is the entry
  point for any future per-type visual swap; the current implementation only
  handles Goat + Mimic, but the dispatch table is the extension point.
- **Centralized cadence**: every new periodic callback (TileSignal rescan,
  detection expiry, Mimic scan) routes through `GameClockComponent` — one
  shared `_physics_process` tick instead of dozens of `Timer` nodes.
- **Centralized proximity**: the Mimic adds **one** TileSignal trigger, not
  a per-frame distance loop. Its cost scales the same as adding one more
  goblin's `DetectionComponent` trigger.

Reusable artifacts that fall out of this patch:

- `CreatureMorphComponent` + `SkillCopyComponent` — drop into any creature
  that needs morph or copy behavior; nothing Mimic-specific in their
  implementation.
- `ActorFactory` — pure dispatch utility; one short script.
- `AbilityRegistry` — works for any project that organizes abilities as
  `RefCounted` subclasses with an `ability_name` field.

## 9. Testing Notes (in-editor verification checklist)

Run `Play Space/Arena.tscn` after opening the project once (so the editor
re-imports the new `.gd` and `.tscn` files). Then verify:

1. **Phase 0 deletions**: project opens cleanly with no "missing file"
   warnings in the editor console. The Ranch button on the main menu still
   loads `Components/BreedingComponents/Ranch/Ranch.tscn`. "Finish Day" in
   the arena now returns to the same Ranch scene (was a dead path before).
2. **SDS-7**: TileSignal continues to discover quest camps as the player
   approaches them. (`QuestSpawnManager` registers a radius-8 trigger; the
   `_refresh_tracked_actors` cadence is what catches actors added without
   `register_actor()`.)
3. **SDS-8**: Hostile actors fade in and out of perception as the player
   moves toward and away from them at the same cadence as before (within
   ±0.5s due to the fixed-interval expiry).
4. **SDS-9 alias**: select a goat in the main menu and verify the Ranch UI
   still highlights the right goat. `ItemsAutoload.selected_goat` returns
   the same reference as `selected_actor_data` for a Goat actor.
5. **AbilityRegistry**: main menu still shows "Headbutt Charge" for goat,
   "Nimble Escape" and "Redirect Attack" for goblin. Closing and reopening
   the character tab does **not** spawn-and-free Actor nodes (visible as a
   noticeable lag spike on the previous build).
6. **ActorFactory**: Goblin, Goat, Farmer, Fire, Water, Scarecrow all still
   spawn through the existing pipelines.
7. **Mimic spawn**: open the in-editor remote inspector after spawning one
   via a quick `ArenaSpawner.spawn_actor("mimic")` call in `_ready`, or
   trigger via a debug button. Confirm:
   - The Mimic appears as a violet sphere.
   - `MimicController` is attached and `_scan_trigger` is non-empty after
     one frame.
   - `_scan_tick_id` is non-negative.
8. **Mimic morph + copy**: place a goat within `scan_radius` (default 4
   hexes). After up to `scan_interval` seconds (default 0.5s) the Mimic
   should swap visuals (color/scale match the goat's `update_goat_visuals`
   output) and gain "Headbutt Charge" in its `ability_component.actions`.
   After `morph_duration` seconds (default 8s) it should revert and lose
   the copied action.
9. **Mimic bite**: confirm the Mimic's `WeaponComponent.weapon_data.name ==
   "Unarmed strike"` after `_equip_default_bite` runs.

## Open Questions for Agent 3

The following items could not be verified without running the editor. Flag
them in Agent 3's testing pass:

1. **Bite reach vs AI attack_range**: `ActorAIController.attack_range` is
   `10.0` world units, but `Unarmed strike`'s effective melee reach comes
   from `WeaponData` notes parsing. If the Mimic stands still in attack
   state without hitting an adjacent enemy, the Unarmed reach is shorter
   than the AI gate and we need either a custom melee `WeaponData` (against
   the spec — "Do NOT add new WeaponData entries") or a Mimic-specific
   `attack_range` override.
2. **Visual morph fidelity**: `_apply_mimic_visuals` only re-tints +
   re-scales. Morphing the Mimic into a Goat sets the body's albedo to the
   goat's `base_color` but does NOT swap meshes / add horns. Confirm
   visually whether the tint-only morph is convincing enough for v1.0, or
   whether the spec requires actual mesh swap (would need procedural
   character framework work).
3. **TileSignalComponent fallback**: the new `_register_refresh_tick` falls
   back to `call_deferred` if `arena.get_game_clock()` returns null at
   `setup()` time. Real load order in `Play Space/Arena.gd:107-136` creates
   `game_clock` before `tile_signals`, so this path should never fire.
   Confirm via editor log that no `"[AbilityRegistry] Could not open"` or
   tick-register warnings appear in a fresh Arena boot.
4. **Save/load**: confirmed transient by design — `MimicData` is **not**
   added to `SaveComponent`'s persisted set, and morph + stolen-action
   state resets on reload. If players need persistent Mimic state, that's
   a schema change in `Core/Managers/SaveComponent.gd`.
5. **Mimic disallowed_target_types default**: initialized in `_init()` only
   if currently empty. Designers cannot intentionally set `[]` in the
   inspector without it being silently re-filled. If that's a problem, move
   the default elsewhere (e.g. expose a `_should_use_defaults` flag) — but
   that complicates the API surface.
6. **AbilityRegistry probe safety**: each script in
   `Components/ActorComponents/AbilityComponents/` is probed by calling
   `script.new(temp_actor, temp_component)`. If a future ability subclass's
   `_init` does anything beyond storing the args (e.g. accessing actor
   components that aren't on the throwaway), the probe could push errors to
   the console. Today's three subclasses are safe; document the constraint
   in `Markdowns/Abilities.md` if a new subclass adds heavier `_init` work.
7. **Quest spawn dispatch (`spawn_quest_actor` and friends)**: these now
   route through `ActorFactory` via `spawn_actor_at_tile`. Confirm the
   QuestStarterKit goblin camp spawn flow still produces goblins (it should
   — `goblin` is registered) and that camp tile metadata still attaches.
8. **MimicActor.tscn `_data` SubResource**: I pre-set `_data =
   Resource_mimic_data_default` via a SubResource declaration. This works
   the same way `GoatActor.tscn`'s `GeneticComponent.goat_data` SubResource
   does (verified pattern). If Godot 4.6 complains about the SubResource
   type vs the `@export var _data: ActorData` typed export, an alternative
   is to drop the SubResource and rely on `MimicActor._ready()` to
   instantiate a default — that path is already in place as a fallback.
   Notably, Godot 4.6 may strip underscore-prefixed `@export` fields during
   scene serialization (GoatActor.tscn dodges this by routing through
   `GeneticComponent.goat_data` instead of the root's `_data`). The
   `_ready()` fallback masks any failure, but the scene's default tuning
   would then be lost. Print `mimic_data.aggression` at `_ready()` to
   confirm which path is winning.
9. **Name label leak after Mimic morph into Goat**: `update_goat_visuals()`
   adds a `Label3D` child to the actor showing `goat_data.goat_name`. When
   the Mimic reverts, `_apply_mimic_visuals()` does not hide or update that
   label, so the Mimic still wears its previous victim's name until its
   next morph. Cosmetic, not a crash. Fix options: have
   `CreatureMorphComponent.revert()` hide any `Label3D` child of the actor,
   or add an explicit `hide_name_label()` method on `ActorVisualComponent`
   and call it from revert.
