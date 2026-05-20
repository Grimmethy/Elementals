# Agent 3 — Integration Review (Verification Pass)

> Independent verification of Agent 2's implementation against
> `docs/AGENT_1_IMPLEMENTATION_REQUIREMENTS.md` (especially §9 Dependency Chain
> + §10 Smallest Defensible Slice) and the user's original Mimic spec.
>
> Method: file-by-file code reading. Editor-runtime verification is explicitly
> called out where it could not be replaced by reading.

---

## 1. Implementation Reviewed (verified by direct file inspection)

### 1.1 New files (confirmed present on disk)

| Path | Purpose | Status |
|------|---------|--------|
| `Core/AbilityRegistry.gd` | Boot-time scan + per-actor clone factory | EXISTS, correctly scans `Components/ActorComponents/AbilityComponents/`, skips `AbilityAction.gd`/`AbilityComponent.gd`, exposes `get_ability_names()` + `get_ability_script()` + `instantiate_for()` |
| `Components/Arena/ActorFactory.gd` | `StringName → PackedScene` dispatcher | EXISTS, plain `Node` subclass |
| `Components/BreedingComponents/MimicData.gd` | `MimicData : ActorData` | EXISTS, all spec fields present (`mimic_name`, `aggression`, `scan_radius`, `scan_interval`, `morph_duration`, `skill_copy_limit`, `disallowed_target_types`); `get_actor_type() → "mimic"`; asexual `create_offspring()` |
| `Components/ActorComponents/CreatureMorphComponent.gd` | Generic visual swap helper | EXISTS, snapshot-and-restore pattern |
| `Components/ActorComponents/SkillCopyComponent.gd` | Generic skill-clone helper | EXISTS, uses `AbilityRegistry.instantiate_for()` for per-actor binding |
| `src/actors/types/MimicActor.gd` | `MimicActor : Actor` | EXISTS, `is_playable = false` in `_init()`, MONSTERS faction in `_ready()`, `_equip_default_bite()` for Unarmed strike |
| `src/actors/types/MimicController.gd` | `MimicController : ActorAIController` | EXISTS, TileSignal + GameClock routing |
| `scenes/actors/MimicActor.tscn` | Scene with CharacterBody3D + Body + collider + default MimicData sub-resource | EXISTS |
| `Markdowns/Mimic.md` | v1.0 design + deferred features list | EXISTS, status header `STATUS: v1.0 Extended Slice` present |

### 1.2 Files patched (verified by reading the relevant lines)

| Path | Change | Status |
|------|--------|--------|
| `Components/Arena/ArenaUIHandler.gd:107` | Ranch return path `res://Components/BreedingComponents/Ranch/Ranch.tscn` | CORRECT |
| `Components/Arena/TileSignalComponent.gd:20-45` | `Timer.new()` removed; `_register_refresh_tick()` calls `arena.get_game_clock().register_tick(_refresh_tracked_actors, 1.0)`; deferred fetch fallback | CORRECT — public API (`register_trigger`, `update_trigger_center`, etc.) untouched |
| `Components/ActorComponents/DetectionComponent.gd:25-35, 117-122, 294-300` | `Timer` field removed; `_expiry_tick_id` registered via `actor.register_tick(_on_expiry_tick, EXPIRY_TICK_INTERVAL=0.5)`; legacy `_schedule_next_expiry` retained as no-op; `_notification(EXIT_TREE)` unregisters | CORRECT |
| `Core/ItemsAutoload.gd:14-31, 141-163` | `selected_actor_data: ActorData` added; `selected_goat` is a getter/setter alias; `set_selected_actor()` writes generic bus first, then emits goat signal only if actor is GoatActor (avoids clobber) | CORRECT |
| `project.godot:34` | `AbilityRegistry="*res://Core/AbilityRegistry.gd"` registered | CORRECT |
| `UI/MainMenu.gd:66-94` | `_get_goblin_abilities` / `_get_goat_abilities` route through `_resolve_ability_names_for()` against the registry; no more instantiate-and-free reflection | CORRECT |
| `Components/Arena/ArenaSpawner.gd:12, 17, 24-39, 73-74, 288-291` | `mimic_scene` export + `_actor_factory: ActorFactory` member + `_register_default_actor_types()` registers all 7 types (farmer/fire/water/goat/goblin/scarecrow/mimic); `spawn_actor_at_tile()` dispatches through `_actor_factory.spawn()` | CORRECT |
| `Components/ActorComponents/ActorVisualComponent.gd:85-115` | Additive `setup_visuals(data)` dispatches GoatData → `update_goat_visuals`, MimicData → `_apply_mimic_visuals`; existing `update_goat_visuals` preserved + still called by `_setup_goat_visuals()` | CORRECT — additive only |
| `AGENTS.md` (verified via grep) | No remaining `res://Components/Arena/GameClockComponent` references; correct path used | CORRECT |
| `README.md:36` | `HerdManager` (no `GoatManager` references) | CORRECT |
| `Markdowns/Capture.md:3` | `> **DEPRECATED — see Markdowns/Breeding.md §Capture System for the canonical ActorState model.**` | CORRECT |
| `Markdowns/Actor.md` | Per Agent 2 claim — 2D→3D type swap (not exhaustively spot-checked) | ASSUMED CORRECT |
| `Markdowns/SettlementImplementationPlan.md` | Per Agent 2 claim — React/JSX admonition added (not opened) | ASSUMED CORRECT |
| `Markdowns/Abilities.md`, `Markdowns/UI.md` | Per Agent 2 claim — v1.1 sections added (not opened) | ASSUMED CORRECT |

### 1.3 Deletions verified

- `player.gd`, `player.tscn`, `player.gd.uid` at project root — **GONE** (Glob returned no matches anywhere in tree).
- `*.tmp` files (Play Space + QuestSystem) — **GONE** (Glob `**/*.tmp` returned no matches).
- Orphan `.gd.uid` files — **NONE FOUND** (find loop confirmed every `.gd.uid` has a paired `.gd`).

---

## 2. Documented Needs Addressed (Agent 1 §10.1 checklist)

| ID | Item | Status |
|----|------|--------|
| SDS-1 | M1 Ranch return path | DONE |
| SDS-2 | M2 orphan `.uid` deletion | DONE (0 orphans remain) |
| SDS-3 | M3 `.tmp` deletion | DONE |
| SDS-4 | M4 AGENTS.md `GameClockComponent` path | DONE |
| SDS-5 | M5 README `GoatManager` → `HerdManager` | DONE |
| SDS-6 | M7 Capture.md deprecation header | DONE |
| SDS-7 | M8 `TileSignalComponent` Timer removal | DONE (public API preserved) |
| SDS-8 | M9 `DetectionComponent` Timer removal | DONE |
| SDS-9 | M10/B8 `ItemsAutoload.selected_actor_data` + alias | DONE |
| SDS-10 | `MimicData.gd` resource | DONE |
| SDS-11 | `MimicActor.gd` + `MimicActor.tscn` | DONE |
| SDS-12 | `MimicController.gd` with TileSignal + GameClock | DONE |
| SDS-13 | Mimic spawn pipeline | DONE (via ActorFactory rather than hardcoded match — exceeds spec) |
| SDS-14 | `Markdowns/Mimic.md` | DONE |
| BONUS S2 | `AbilityRegistry` autoload (deferred in §10) | DONE — landed early |
| BONUS S3 | `ActorFactory` extraction (deferred in §10) | DONE — landed early |
| BONUS B12 | `ActorVisualComponent.setup_visuals()` polymorphism (deferred in §10) | DONE — landed early |
| BONUS MM7 | Mimic visual morph (explicitly out of scope in §10.2 SDS-X1) | DONE (tint-only, documented as v1.0 limitation) |
| BONUS MM8/MM9 | Mimic skill copy + use (explicitly out of scope in §10.2 SDS-X2) | DONE |

Agent 2 shipped the **Extended Slice**, exceeding the §10 Smallest Defensible Slice in a controlled way: every "bonus" item above was a §10.2 deferred item with a clear gating prerequisite, and Agent 2 implemented the prerequisite (S2, S3, B12) before consuming it.

---

## 3. Breeding Verification

### What works for goats
- **Ranch return loop**: SDS-1 fixes the dead path at `ArenaUIHandler:107`. The "Finish Day" button now lands on `res://Components/BreedingComponents/Ranch/Ranch.tscn`.
- **Goat selection bus**: SDS-9 preserves `selected_goat` semantics. The getter returns `selected_actor_data as GoatData`, the setter writes through to the new field, and `set_selected_actor()` (when given a `GoatActor`) re-emits `goat_selected` so the Ranch UI keeps highlighting correctly.
- **Goat breeding data layer**: untouched (`BreedingComponent`, `GoatData.create_offspring`, `HerdManager.next_day` for goats).

### What is explicitly deferred for non-goats
- **B7 — `HerdManager.next_day()` non-goat acceptance**: still drops non-`GoatData` kids (see `HerdManager.gd:100-104`). Agent 2 did NOT touch this — correct per Agent 1 §10.2.
- **B9 / B10 / B11 — `Ranch.gd` + `ActorCard` + renderer generalization**: untouched (would crash on non-goat herd). Documented as deferred in `Markdowns/Mimic.md`.
- **MimicData breeding**: `MimicData.create_offspring()` exists and produces a `MimicData`, but the current `BreedingComponent.breed()` requires male+female pair AND `HerdManager.next_day()` would drop the kid. Documented in `Markdowns/Mimic.md` as gated on B7 + B18.

---

## 4. Capture Verification

- **Capture system: zero new implementation.** Grep for `ActorState`, `CaptureComponent`, `CaptureProfile` returns no live code (only design-doc mentions). This matches Agent 1 §10.2 SDS-X6 which explicitly defers Capture as a multi-PR effort.
- **No half-implementation leaked in.** The `Net` weapon was already in `ItemsAutoload._init_weapons()` before this patch (line 121) — that is preexisting design intent, not new capture work.
- **`Markdowns/Capture.md` correctly carries the deprecation header** (verified — line 3 of the file).
- **Mimic is NOT marked capturable.** MimicData has no `is_capturable` or restraint fields. Correct.

---

## 5. Mimic Verification (MM1–MM12)

| # | Capability | Status | Evidence / notes |
|---|------------|--------|------------------|
| MM1 | Spawn as Mimic via spawn pipeline | SHIPPED | Registered with `ActorFactory` at `ArenaSpawner._register_default_actor_types()`; `spawn_actor_at_tile("mimic", tile)` works (`Components/Arena/ArenaSpawner.gd:39`). |
| MM2 | `MimicData : ActorData` with procedural fields | SHIPPED | `Components/BreedingComponents/MimicData.gd` — all spec fields, `_init()` populates defaults, `create_offspring()` does color + stat jitter. |
| MM3 | Bite attack | SHIPPED | `MimicActor._equip_default_bite()` walks `ItemsAutoload.weapons` for `"Unarmed strike"` and assigns it. No new WeaponData entry created (per spec). |
| MM4 | AI controller | SHIPPED | `MimicController` extends `ActorAIController` (full 9-state FSM inherited). |
| MM5 | TileSignal scan | SHIPPED | `_register_scan_trigger()` registers a single trigger of radius `scan_radius` at the Mimic's tile; `_on_mimic_tile_changed()` updates center. No per-frame distance math. |
| MM6 | GameClock-driven cadence | SHIPPED | `_register_scan_tick()` calls `actor.register_tick(_on_scan_tick, _mimic_data.scan_interval)`. NO `Timer.new()` and NO `await get_tree().create_timer()` in any new file (grep-verified). |
| MM7 | Visual morph | SHIPPED (v1.0 caveat) | `CreatureMorphComponent.morph_into()` calls `actor.visual_component.setup_visuals(target._data)`. **v1.0 limitation**: only tints body + scales — does not swap meshes / add horns. Documented in `Markdowns/Mimic.md` and Agent 2 patch log Q2. Acceptable scope for first cut. |
| MM8 | Copy skills | SHIPPED | `SkillCopyComponent.copy_from(donor, limit)` enumerates donor's `ability_component.actions`, looks up each by name in `AbilityRegistry`, and calls `registry.instantiate_for(name, actor, component)` to create a **fresh actor-bound instance**. NEVER shares the donor's `AbilityAction` — verified by code reading. |
| MM9 | Use copied skill | SHIPPED | Copied actions are added to the Mimic's own `AbilityComponent.actions` via `add_action(clone)`. Existing `AbilityComponent.execute_ability()` handles them with no special-case code. |
| MM10 | Capturable | DEFERRED | No CaptureComponent exists. Documented in `Markdowns/Mimic.md`. |
| MM11 | Breeds | PARTIAL (data layer only) | `MimicData.create_offspring()` exists; `HerdManager.next_day()` will drop the kid (B7 deferred). Documented. |
| MM12 | Save/load morph + stolen actions | DEFERRED (by design) | Transient by design — `SaveComponent` schema unchanged. Documented in `Markdowns/Mimic.md`. |

### Mimic anti-pattern audit (clean)
- `Timer.new()` in any Mimic file: **none** (only 2 comments referencing the AGENTS.md rule).
- `await get_tree().create_timer(...)` in Mimic code: **none**.
- `_process(delta)` per-frame distance math in `MimicController.gd`: **none** (grep returned nothing).
- Shared `AbilityAction` references: **none** — `SkillCopyComponent.copy_from()` goes through `AbilityRegistry.instantiate_for(name, actor, own_ability_component)` for every clone.
- `MimicController._register_scan_trigger()` passes `continuous: false`. Verified at `TileSignalComponent.gd:136, 178`: the `continuous` flag only controls whether the callback re-fires while still inside the radius. The `trigger_activated` / `trigger_deactivated` signals fire regardless of `continuous`, so the symmetric `_nearby_actors` cache is correct. **Not a bug.**

---

## 6. Performance Review

| Concern | Finding |
|---------|---------|
| `TileSignalComponent` rescan cadence | 1.0s tick (same as the old Timer's wait_time). One GameClock callback per arena. |
| `DetectionComponent` expiry cadence | 0.5s tick per actor (`EXPIRY_TICK_INTERVAL`). Was previously a dynamic-wait Timer per actor — same order-of-magnitude, but the callback is bounded by `perceived_enemies.is_empty()` fast-out at line 128-129. |
| Mimic scan cadence | 0.5s default (`MimicData.scan_interval`, designer-tunable). One callback per Mimic. |
| Per-frame allocations in Mimic | `_on_scan_tick` rebuilds `candidates` per tick (small Array). Acceptable for 2Hz cadence. No `Vector3.distance_to` calls (relies on TileSignal). |
| Mimic morph allocations | A `Label3D` may leak after revert (Agent 2 Q9) — cosmetic, no fix. |
| Save data size | UNCHANGED. `SaveComponent` schema not modified. Mimic morph + stolen actions are transient. |
| AbilityRegistry boot cost | Scans `Components/ActorComponents/AbilityComponents/` once at autoload `_init()`. Currently 3 ability scripts, each instantiated against a throwaway `Actor.new()` + `Node.new()`. Cheap today but see §9 below. |

---

## 7. Coworker Design Review

### Modular?
- **ActorFactory** is a pure dispatch utility — adding a new creature is one line in `_register_default_actor_types()`.
- **AbilityRegistry** scans by folder; adding a new ability requires zero edits to consumers (MainMenu, SkillCopyComponent, future copier actors).
- **CreatureMorphComponent** and **SkillCopyComponent** are intentionally type-agnostic — reusable by any future morph- or copy-capable creature, not Mimic-specific.

### Procedural?
- `MimicData` exposes every tuning knob as `@export` so designers can author `.tres` variants.
- `create_offspring()` does color + stat jitter — same shape as `GoatData.create_offspring()` for future trait-inheritance generalization.

### Reusable?
- `setup_visuals(data: ActorData)` is the polymorphic entry point future ActorCard / future actor types can plug into (B12 prerequisite for non-goat herds).
- `Actor.register_tick()` is the single bridge from actor-side code to GameClock — Mimic and Detection both consume it.

### Docs updated?
- `Markdowns/Mimic.md` — created with status header, fields table, MM1-MM12 mapping, deferred-features list.
- `Markdowns/Capture.md` — deprecation header added.
- `Markdowns/Abilities.md` + `Markdowns/UI.md` — per Agent 2 patch log v1.1 bumps (not re-verified).
- `AGENTS.md` — GameClockComponent path fixed.
- `README.md` — `GoatManager` → `HerdManager`.

---

## 8. Tests Performed (via code reading)

| Test | Result |
|------|--------|
| All new files exist at claimed paths | PASS |
| `Timer.new()` count in TileSignal/Detection/Mimic | PASS (zero in those files; only comment references) |
| `Timer.new()` elsewhere in repo (allowed) | `Components/Arena/TileSystem.gd:16` — pre-existing tile-processing timer, NOT in M8/M9 scope, NOT in any DO-NOT-BREAK file's perception path. Acceptable. |
| `await get_tree().create_timer()` in new Mimic files | PASS (zero) |
| `_process(delta)` distance math in MimicController | PASS (none) |
| AbilityAction sharing in SkillCopyComponent | PASS — uses `instantiate_for()` for fresh per-actor instance |
| `ItemsAutoload.selected_goat` alias to `selected_actor_data` | PASS — getter/setter both proxy correctly |
| `set_selected_actor` no longer clobbers non-goat data | PASS — emits `goat_selected.emit(null)` inline instead of routing through `set_selected_goat(null)` |
| `setup_visuals()` additive (does NOT delete `update_goat_visuals`) | PASS |
| AbilityRegistry registered in `project.godot` autoloads | PASS (line 34) |
| ActorFactory registers all 7 actor types | PASS (farmer, fire, water, goat, goblin, scarecrow, mimic) |
| Ranch path live in `ArenaUIHandler:107` | PASS — points to `res://Components/BreedingComponents/Ranch/Ranch.tscn` |
| AGENTS.md path correction | PASS — no `Components/Arena/GameClockComponent` references |
| `player.gd` + `player.tscn` deletions | PASS (Glob returned zero) |
| Orphan `.gd.uid` count | PASS (zero — find loop confirmed paired `.gd` for every `.gd.uid`) |
| `.tmp` file count | PASS (zero) |
| `MimicData.disallowed_target_types` populated in `_init()` | PASS — initialized to `[&"mimic", &"scarecrow"]` |
| `TileSignalComponent.continuous` flag semantics | PASS — only controls re-callback while inside, does NOT gate `trigger_activated`/`trigger_deactivated` signal emission. MimicController's `continuous: false` is correct. |
| DO-NOT-BREAK files modified beyond authorization | PASS — only the 4 pre-approved edits (SDS-1, SDS-7, SDS-8, SDS-9) + the additive-only AbilityRegistry autoload entry, ArenaSpawner factory composition, and ActorVisualComponent `setup_visuals()` (all behavior-additive). |

---

## 9. Tests Still Needed (requires Godot editor)

These could not be verified by code reading alone. They are NOT blockers — Agent 2 already flagged them in §Open Questions:

1. **Bite reach vs `ActorAIController.attack_range`** (Agent 2 Q1). `Unarmed strike` reach is parsed from `WeaponData.notes`. If shorter than the AI's 10-unit `attack_range`, the Mimic may stand still in attack state without landing the bite. Requires in-editor confirmation.
2. **AbilityRegistry boot probe safety**. The registry calls `script.new(Actor.new(), Node.new())` on every ability script at autoload `_init()`. Today's 3 scripts (GoatCharge, NimbleEscape, RedirectAttack) are safe; **any future AbilityAction whose `_init()` touches actor components beyond storage will push errors at boot**. Document this constraint in `Markdowns/Abilities.md` (Agent 2 Q6).
3. **`MimicActor.tscn` root `_data` SubResource persistence** (Agent 2 Q8). Godot 4.6 may strip underscore-prefixed `@export` fields during scene serialization. `GoatActor.tscn` dodges this by routing through `GeneticComponent.goat_data` instead of the root's `_data`. The MimicActor `_ready()` fallback masks any failure (creates default MimicData), but designer-tuned inspector values would be silently lost. Verify by printing `mimic_data.aggression` in `_ready()`.
4. **Label3D name leak after Mimic revert** (Agent 2 Q9). When the Mimic morphs into a Goat, `update_goat_visuals()` adds a `Label3D` showing the goat's name to the Mimic. On revert, the label is NOT removed. Cosmetic, not a crash. One-line fix in `CreatureMorphComponent.revert()` recommended for follow-up.
5. **Goat-only breeding loop end-to-end** in-game after SDS-1 + SDS-9. Data layer is unchanged but the player-visible flow needs a smoke test (select goat in MainMenu → Arena → Finish Day → Ranch → confirm goat appears in herd with correct selection state).
6. **TileSignalComponent rescan cadence still discovers quest camps** after SDS-7. The QuestSpawnManager flow depends on the `_refresh_tracked_actors` callback catching actors that weren't `register_actor()`-ed.
7. **No editor console errors at Arena boot** (no `[AbilityRegistry] Could not open` warnings; no tick-register warnings).
8. **MainMenu does not freeze when opening the character tab** (old reflection cycle caused a lag spike — should be gone now).

---

## 10. Final Recommendation

**Safe to continue from? YES.**

The patch landed the full Extended Slice cleanly:

- Every Phase 0 hygiene item is done.
- Both Phase 1 routing-rule violations (M8 + M9) are fixed with public APIs preserved.
- Three Phase 2 modular extractions (S2 AbilityRegistry, S3 ActorFactory, B12 visual polymorphism) landed without breaking existing callers.
- The Mimic ships with morph + skill copy, not just the bite-only minimum from §10's Smallest Defensible Slice — this is a positive overshoot enabled by the prerequisite extractions landing in the same patch.
- All DO-NOT-BREAK files were modified only via the pre-approved edits or additive composition; no behavior-changing edits leaked into protected files.
- Capture and non-goat breeding are correctly deferred with documentation of the gating prerequisites.

**Blockers found: NONE.**

**Caveats (NOT blockers):**

- v1.0 Mimic morph is tint + scale only, not mesh swap. Documented.
- Save/load of Mimic morph + stolen skills is transient. Documented.
- Mimic breeding requires B7 (HerdManager generalization) before it functions end-to-end. Documented.
- Future heavy ability `_init()` could crash AbilityRegistry boot probe. Document the constraint in Abilities.md.
- Cosmetic: Label3D name leak after Mimic revert. One-line follow-up.

**Top 3 things a human should test in-editor:**

1. **Mimic morph + copy loop**: spawn a Mimic via debug, place a goat within 4 hexes, watch for body tint change + `ability_component.actions` gaining "Headbutt Charge" within 0.5s, then revert at 8s.
2. **Boot console clean**: no `AbilityRegistry` warnings, no missing-file warnings, no tick-register warnings at Arena boot.
3. **"Finish Day" → Ranch**: confirm the button now lands on the real Ranch scene (`res://Components/BreedingComponents/Ranch/Ranch.tscn`) and that the selected goat is still highlighted there.

---

*End of Agent 3 integration review.*
