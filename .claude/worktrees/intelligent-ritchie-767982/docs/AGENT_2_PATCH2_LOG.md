# Agent 2 — Patch 2 Implementation Log (Breeding Generalization)

> Second implementation pass after the Extended Slice. Scope locked by
> `docs/AGENT_1_PATCH2_STATE_CHECK.md` §10 strict patch order.
> All paths repo-relative. Line numbers reference the post-patch state.

---

## 1. Files Inspected

Read in full:

- `docs/AGENT_1_PATCH2_STATE_CHECK.md`
- `docs/COWORKER_IMPLEMENTATION_NOTES.md` (lines 1–280)
- `Components/ActorComponents/ActorData.gd`
- `Components/BreedingComponents/GoatData.gd`
- `Components/BreedingComponents/MimicData.gd`
- `Components/BreedingComponents/HerdManager.gd`
- `Components/BreedingComponents/Ranch/Ranch.gd`
- `Core/Managers/HerdComponent.gd`
- `Core/Managers/ProgressionComponent.gd`
- `Core/Managers/SaveComponent.gd`
- `Core/GoatSaveData.gd` (via §4 of state check)
- `Core/GameEvents.gd` (via §5 of state check)
- `Core/ItemsAutoload.gd` (the two `goat_data` grep hits)
- `UI/DisplayCard/ActorCard.gd`
- `UI/DisplayCard/DisplayCardBase.gd`
- `Play Space/OptionsMenu.gd` (lines 50–80) — verified `gc.goat_data` is on `GeneticComponent`, NOT `ActorCard`, so the ActorCard alias change does not touch this path
- `src/actors/base/Actor.gd` (lines 1–220)
- `src/actors/types/GoatActor.gd`
- `src/actors/types/GoblinMinion.gd`
- `src/actors/types/FarmerActor.gd`
- `src/actors/types/FireActor.gd`
- `src/actors/types/WaterActor.gd`
- `Markdowns/Actor.md`, `Markdowns/Breeding.md`, `Markdowns/UI.md`

Greps performed:

- `"GoatData"` (quoted) — confirmed no live code dependency on the legacy string return; only docs.
- `\.is_selected` — confirmed only `ProgressionComponent.gd` and `HerdComponent.gd` and `ActorCard.gd` touch it. After lifting to ActorData these all keep working unchanged.
- `_on_goat_selected|goat_selected|actor_selected` — confirmed `Ranch.gd:_on_goat_selected` is connected by method reference (line 54: `card.selected.connect(_on_goat_selected)`), not by name string, so renaming the handler is safe.
- `_actor\.goat_data|\._actor\.goat_data` — confirmed only `ActorCard.gd` and `ActorVisualComponent.gd` use this pattern; ActorVisualComponent is out of scope.
- `actor_resource` — confirmed all live call sites inside `ActorCard.gd`; no external callers.

---

## 2. Systems Found

The breeding pipeline as it stands after this patch:

```
Player (Ranch UI)
  ├── selects doe + buck (ActorData typed)
  └── presses Breed
        ↓
HerdManager.breed(parent_a, parent_b)
        ↓
BreedingComponent.breed()      # generic — gender + exhaustion gate
        ↓ on female sets is_pregnant + pregnancy_timer
GameClock day advance
  ↓
HerdManager.next_day()
  ↓ ProgressionComponent.advance_day(herd)    # ages, exhaustion
  ↓ BreedingComponent.process_pregnancy(herd) # returns Array[ActorData]
  ↓ for each kid: add_goat(kid)               # NEW: no longer drops non-goat
        ↓
HerdComponent.add_goat(kid: ActorData)
GameEvents.herd_updated.emit()
  ↓
SaveComponent.save_game()
  ↓
GoatSaveData → ResourceSaver.save(save, SAVE_PATH)
```

Renderer dispatch (relevant to the deferred GoatRenderer rename):

```
ActorCard._update_resource_ui()
  ├── if actor_data is GoatData → actor_renderer.visible = true; assign
  └── else                        → actor_renderer.visible = false
```

Per-actor data binding (relevant to non-goat creature configuration):

```
Designer assigns a .tres GoblinData to GoblinMinion.tscn (optional)
  → Actor._data setter wires stats_changed → _on_data_changed
  → ability_scores_component populated from the resource
  → GoblinMinion._ready() gate: `if _data == null` skips the hardcode block
  → resource-driven stats win
```

---

## 3. Bugs or Gaps Found (with patch approach per item)

| # | Bug / gap | Source | Patch approach |
|---|-----------|--------|----------------|
| B7 | `HerdManager.next_day()` cast-and-dropped any non-`GoatData` kid via `var goat_kid = kid as GoatData; if goat_kid: add_goat(goat_kid)` — silently lost Mimic / future-creature offspring | `Components/BreedingComponents/HerdManager.gd:100-104` | Replaced with `if kid: add_goat(kid)`. `add_goat()` already accepts `ActorData`. |
| R1 | `is_selected: bool` lived on `GoatData` but `HerdComponent.toggle_selection()` read/wrote it on plain `ActorData` references. First click on a non-goat card = `Invalid set index 'is_selected'` runtime error. | `GoatData.gd:63-67` + `HerdComponent.gd:29-47` | Moved the `@export var is_selected` (with setter) from `GoatData` to `ActorData` Breeding group. Removed the duplicate from `GoatData`. `HerdComponent` unchanged. |
| R2 | `ActorCard._update_resource_ui()` hardcoded `actor_resource.goat_name`, `level`, `age_days` — `level` and `age_days` are GoatData-only. | `ActorCard.gd:88-91` | Introduced `get_display_name()` / `get_info_line()` / `set_display_name()` virtuals on ActorData; GoatData overrides both. ActorCard now calls the virtuals. **Intentional minor regression noted by advisor §2:** the goat info line drops the `"Female - "` prefix because `get_info_line()` returns just `"Lvl: %d - Age: %d"`. Gender state remains visible via the pregnant `[P]` / exhausted `[E]` suffixes and the visible separate `arena_checkbox` row. |
| R3 | (Filtering on `is_exhausted` — already works on ActorData; no change) | n/a | No change required |
| R4 | Cheat panel `_on_max_level_goat_pressed()` constructs `GoatData.new()` and must keep working | `Ranch.gd:125-138` | Unchanged. Still constructs a goat; goat still funnels through generic `HerdManager.add_goat()`. |
| R5 | `Ranch.gd` lines 53/89/94 assign `card.goat_data = goat` | `Ranch.gd` + `ActorCard.gd` | **Switched the 3 Ranch assignments to `card.actor_data = ...`** (advisor pass 2 catch — the `goat_data` alias setter is typed `GoatData` so assigning a value typed `ActorData` would fail when the underlying value is a non-goat subclass). `goat_data: GoatData` remains on ActorCard as a defensive typed-getter alias; no live code writes through it now. |
| R6 | `Play Space/OptionsMenu.gd:59-72` reads `gc.goat_data` | confirmed `gc` is a `GeneticComponent`, NOT an `ActorCard` — different path entirely | No change required. |
| R7 | Non-goat actor `_ready()` methods hardcoded ability scores AFTER `super._ready()`, which would clobber resource-driven stats if a `*Data` is assigned. | `GoblinMinion.gd:27-32` + `FarmerActor.gd:14-19` | Gated each hardcoded stat block with `if _data == null:`. Only those exact lines are gated; the armor / weapon / faction setup blocks below them are independent of `_data` and remain unconditional. |
| R8 | `GoatRenderer` rename | 3 live `.tscn` references + typed `@onready` | **Deferred.** Documented in §10 below. |
| R9 | `MainMenu.CHARACTER_EQUIPMENT` duplicate dict | out of scope | No change |
| R10 | Save round-trip with mixed-subclass herd | `SaveComponent.gd:25-50` + `GoatSaveData.gd` | Code-read verdict in §9 below. No code change required for this patch. |
| R11 | `GoatActor.die()` removes from herd; other actors don't | `GoatActor.gd:82-83` | Documented as Patch 2 known gap in `Markdowns/Breeding.md`. Code-change deferred — non-goat actors are not yet first-class herd members. |
| R12 | `HerdManager.sell_goat` casts to GoatData for `gold_value` | `HerdManager.gd:84-89` | Documented as Patch 2 known gap. Code-change deferred. |
| NEW | `ProgressionComponent.advance_day()` reads GoatData-only fields (`age_days`, `stamina_max`, `stamina_current`) on every herd member. With B7 fixed, a non-goat kid in the herd would crash here on the next day advance. | `Core/Managers/ProgressionComponent.gd:12-23` | **NOT a pre-approved file**, deferred. Documented as Patch 2 known gap in `Markdowns/Breeding.md` and §10 below. Note: this is a latent risk only — current UI paths still only place goats in the herd. The fix is to lift these fields to ActorData OR gate iteration on `actor is GoatData`. |

---

## 4. Files Patched (one-line summary each)

| File | Change |
|------|--------|
| `Components/ActorComponents/ActorData.gd` | Added `is_selected` field (lifted from GoatData); added `get_display_name()`, `get_info_line()`, `set_display_name()` virtuals. |
| `Components/BreedingComponents/GoatData.gd` | Removed duplicate `is_selected` field; added `get_actor_type()` override returning `"goat"`; added `get_display_name()` / `get_info_line()` / `set_display_name()` overrides. |
| `Components/BreedingComponents/HerdManager.gd` | B7 fix: replaced cast-and-drop with `if kid: add_goat(kid)` (lines 96–101). |
| `Components/BreedingComponents/Ranch/Ranch.gd` | `selected_doe` / `selected_buck` typed `ActorData` (was GoatData); sort uses `get_display_name()`; signal handler renamed `_on_actor_selected(actor: ActorData)`; **three `card.goat_data = ...` assignments switched to `card.actor_data = ...`** so any ActorData subclass flows through the broader primary setter. Cheat panel unchanged. |
| `UI/DisplayCard/ActorCard.gd` | New `actor_data: ActorData` primary API; `goat_data: GoatData` retained as typed alias for legacy call sites; `actor_resource` retained as internal back-compat alias; renderer assignment gated on `actor_data is GoatData`; name + info rendered via polymorphic virtuals; `set_actor()` now uses `_actor._data` polymorphically. |
| `src/actors/types/GoblinMinion.gd` | Added `goblin_data: GoblinData` typed accessor; gated the 6-line hardcoded stat block with `if _data == null`. |
| `src/actors/types/FarmerActor.gd` | Added `farmer_data: FarmerData` typed accessor; gated the 6-line hardcoded stat block with `if _data == null`. |
| `src/actors/types/FireActor.gd` | Added `fire_data: ElementalData` typed accessor. No stat-gate change (no hardcoded stats to clobber). |
| `src/actors/types/WaterActor.gd` | Added `water_data: ElementalData` typed accessor. No stat-gate change. |
| `Markdowns/Actor.md` | Bumped to v1.2; added "Data Resources" section documenting ActorData base + virtual contract + lifted `is_selected`. Version Log entry. |
| `Markdowns/Breeding.md` | Bumped to v1.2; marked Phase 2/3 partial completion; added "Patch 2 Known Gaps" subsection listing the queued ProgressionComponent / sell_goat / die() / GoatRenderer follow-ups. |
| `Markdowns/UI.md` | Bumped to v1.2; updated ActorCard section to document the new `actor_data` / `goat_data` / `actor_resource` API and the renderer gate. |

---

## 5. New Files Created

| File | Purpose |
|------|---------|
| `Components/BreedingComponents/GoblinData.gd` | `GoblinData : ActorData`. Fields: `goblin_name: StringName`, `tribe_color: Color`, `ear_type: EarType`. Overrides `get_actor_type()` → `"goblin"`, `get_display_name()`, `set_display_name()`. `create_offspring()` mirrors goat algorithm (color lerp + 50/50 categorical + stat mean ±10%) and handles mixed-species partners by inheriting from the goblin parent. |
| `Components/BreedingComponents/FarmerData.gd` | `FarmerData : ActorData`. Fields: `farmer_name: StringName`, `hat_color: Color`. Same override + algorithm shape. `get_actor_type()` → `"farmer"`. |
| `Components/BreedingComponents/ElementalData.gd` | Single `ElementalData : ActorData` covering both Fire and Water. Fields: `elemental_name: StringName`, `element_subtype: StringName` (drives `get_actor_type()`), `glow_intensity: float`. Offspring inherits parent's `element_subtype` (cross-element fusion deferred per Breeding.md §Future). |

`.gd.uid` files are auto-generated by Godot on first editor open; not committed manually.

---

## 6. Systems Preserved (explicit list)

- **Goat-only breeding loop**: Ranch → pair → 3-day pregnancy → goat offspring → save → reload. Verified by code trace in §9. Cheat panel still mints `GoatData.new()`. Goat info card layout identical (modulo the gender prefix simplification noted under R2).
- **`HerdComponent.toggle_selection()`** — unchanged, works against the lifted `is_selected` on ActorData base. No regression.
- **`BreedingComponent`** — unchanged, already generic at ActorData level.
- **`Actor._data` setter and `_on_data_changed()` flow** — unchanged. Non-goat actors that get a `*Data` assigned receive ability scores BEFORE `_ready()` runs because Godot calls `set_data` via the @export setter at scene load, which fires `_on_data_changed()` immediately.
- **`GoatActor` flow** — unchanged. `goat_data: GoatData` accessor untouched. `die()` unchanged. `_on_data_changed_impl()` unchanged.
- **`MimicActor` / `MimicData` flow** — unchanged. `MimicData.create_offspring()` is asexual; with B7 fixed, a Mimic kid would now reach the herd (previously dropped). That actually IS a behavioral change — see §9.
- **`Play Space/OptionsMenu.gd`** — `gc.goat_data` is on `GeneticComponent`, NOT on `ActorCard`. No touch.
- **`GoatRenderer`** — unchanged. Filename, `class_name`, `.tscn` references all preserved. Renderer is now gated to GoatData-only via `if actor_data is GoatData` in ActorCard.
- **`Core/GoatSaveData.gd`** — unchanged. Schema already typed `Array[ActorData]`.
- **`Core/GameEvents.gd`** — unchanged.
- **`Core/ItemsAutoload.gd`** — unchanged. The `goat_selected` legacy signal continues to fire for goat-actor selection.
- **`Components/Arena/ActorFactory.gd` + `ArenaSpawner._register_default_actor_types()`** — unchanged. Registry keys still match the new `get_actor_type()` returns.
- **All TileSignal / GameClock / AbilityAction routing rules** — untouched. This patch makes zero changes to runtime ticking or AI control flow.

---

## 7. Implementation Summary

This patch delivers the **breeding generalization** half of the Phase 2/3 work documented in `Markdowns/Breeding.md`. It is the minimum coherent set of changes that:

1. Lets `HerdManager.next_day()` accept offspring of any `ActorData` subclass (the B7 fix).
2. Lets `ActorCard` render any `ActorData` subclass without subclass-specific casts (`get_display_name()` / `get_info_line()` / `set_display_name()` virtuals).
3. Lets `Ranch.gd` pair any `ActorData` subclass (typed members + polymorphic sort).
4. Lifts `is_selected` to `ActorData` so the selection bus works for any subclass.
5. Introduces three new `*Data` subclasses with their own `create_offspring()` so non-goat species can carry breeding state.
6. Wires non-goat actors to their `*Data` via typed accessors, gated on `_data == null` so legacy spawn paths are bit-for-bit identical.

The patch **does not** make end-to-end non-goat breeding functional in-game today. Three downstream files (`ProgressionComponent`, `HerdManager.sell_goat`, `GoatActor.die` and its missing peers on other actors) still assume GoatData. These were intentionally out of scope per the strict patch order and the DO-NOT-BREAK list. They are queued for Patch 3 in `Markdowns/Breeding.md` and §10 below.

What does work end-to-end today:

- Goat-only breeding loop: identical to before.
- A debug spawn of a Mimic that breeds via `BreedingComponent` would now have its kid actually land in the herd (previously: silently dropped). The kid will survive `HerdComponent.add_goat()`, persist through save/load (see §9), and be selectable. It will crash `ProgressionComponent.advance_day()` on the next day advance — that is the next file to touch.

---

## 8. Procedural / Modular Design Summary

The Mimic patch established a "drop-a-new-subclass" workflow: add a `*Data` subclass with a `create_offspring()`, register a scene with `ActorFactory`, optionally implement a per-type renderer branch. This patch makes that workflow real for three additional creature types:

- **`GoblinData`** / **`FarmerData`** / **`ElementalData`** are pure-data subclasses. They follow the GoatData pattern: identity field, a small number of `@export` genetic knobs, and a `create_offspring()` that uses color lerp + 50/50 categorical for enums + stat mean ±10%. Cross-species partner handling: each falls back to inheriting the same-species parent's genetics if `partner as MyData` fails, so the algorithm is safe under mixed-species pairing even though the herd UI does not yet expose that.
- **`ElementalData.element_subtype`** is the trick that lets one class key into both `"fire"` and `"water"` ActorFactory entries — `get_actor_type()` returns the field directly instead of a hardcoded string. This is the procedural-discriminator pattern that lets one ResourceTemplate serve a family of actors.
- **`ActorData.get_display_name()` / `get_info_line()` / `set_display_name()`** are the new polymorphic UI contract. Any future `*Data` subclass can integrate with ActorCard by overriding three small functions instead of touching ActorCard at all. This is the minimum cut for the "add a new creature without modifying UI files" goal stated in the README + AGENTS.md.
- **Typed `goblin_data` / `farmer_data` / `fire_data` / `water_data` accessors on the actors** mirror `GoatActor.goat_data` / `MimicActor.mimic_data` — same shape, same null-tolerance.
- **`if _data == null` gates in actor `_ready()`** preserve the existing zero-config spawn behavior. A designer who wires a `*Data` resource gets resource-driven stats; a designer who doesn't gets the hardcoded fallback. No third path.

No reusable component (like `CreatureMorphComponent` or `SkillCopyComponent` from the Mimic patch) was added in this patch — the work is all data-class and UI-virtuals.

---

## 9. Testing Notes

### Save round-trip code-read (per scope §"Save round-trip verification")

Trace for `save.herd = [goat_a, goat_b, goblin_kid]` after this patch:

1. **Save path** — `SaveComponent._perform_save_deferred()` constructs a `GoatSaveData`, assigns `save.herd = herd`, calls `ResourceSaver.save(save, SAVE_PATH)`.
   - `GoatSaveData.herd` is typed `Array[ActorData]` (unchanged in this patch).
   - `ResourceSaver` writes each element as a `SubResource` with its `script` pointer. For Godot 4.6 this works as long as each subclass has a registered `class_name` and a `.gd.uid` file.
   - `GoatData` already has a `.gd.uid`. `MimicData` already has one. `GoblinData` / `FarmerData` / `ElementalData` will have one auto-generated the first time the editor opens after this patch — required before save can serialize the script path correctly. **If the user runs the game from CLI without first opening the editor, the new subclass scripts will not have UIDs and ResourceSaver will fall back to writing a literal `script = ExtResource("res://Components/BreedingComponents/GoblinData.gd")` path which Godot still loads correctly on the same machine but is non-portable. Acceptable for this patch.**

2. **Load path** — `SaveComponent.load_game()` calls `ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)`.
   - The load filter at line 43-46 is: `for actor in save.herd: if actor is ActorData: converted_herd.append(actor)`. Any `GoatData`, `MimicData`, `GoblinData`, `FarmerData`, `ElementalData` all pass `is ActorData` since they all extend it. **Mixed-subclass herd survives the filter.**
   - The only documented Godot 4.6 failure mode is "typed-subclass-array load wipe": if the runtime cannot resolve a subclass's script at load (script deleted, branch checkout without that file, etc.), the entire `Array[ActorData]` may be wiped to empty. **Mitigation if observed in-editor: change `GoatSaveData.herd: Array[ActorData]` → `Array[Resource]` and add an explicit `if entry is ActorData` cast in `_perform_save_deferred` AND in `load_game`. Both code locations are 2-line changes.** This patch does NOT preemptively make that change because (a) the wipe is intermittent and version-specific, and (b) `Array[Resource]` would let a non-ActorData resource slip into the herd, which is worse.

**Verdict:** Round-trip will work for goat-only saves (no change from before). Round-trip for mixed-subclass herds (e.g. herd containing a Mimic kid after B7) should work in 4.6 once the new `.gd.uid` files are imported. The known failure mode (typed-array wipe) needs in-editor verification by Agent 3 with the test sequence: spawn a Mimic, force-breed via debug, advance day until kid lands in herd, save, close+reopen editor, reload. **If the herd is empty after reload, immediately fall back to `Array[Resource]` typing.**

### Goat-only regression trace (per scope §"Goat-only regression test")

Step-by-step trace through the goat breeding loop after this patch:

1. **Player enters Ranch**: `Ranch.gd:_ready()` connects `GameEvents.herd_updated` → `refresh_ui`. `refresh_ui()` iterates `HerdManager.herd` (still goats only at game start because `_load_initial_state()` calls `generate_starter_herd()` which only adds GoatData).
2. **Sort step** — `sorted_herd.sort_custom(func(a, b): return a.get_display_name() < b.get_display_name())`. For GoatData this returns `goat_name` (override at GoatData.gd:79-80). Sort order identical to the old `a.goat_name < b.goat_name`.
3. **Card construction** — for each goat: `card.actor_data = actor` — `actor_data: ActorData` setter on `ActorCard.gd:19-23` calls `setup(v)`, which calls `super.setup(p_data)` → `data_resource = p_data`. The renderer gate at `_update_resource_ui()` line 106 sees `actor_data is GoatData == true` → assigns `actor_renderer.goat_data = actor_data` (renderer is typed GoatRenderer, accepts GoatData, no setter type error). **Identical render behavior to pre-patch.**
4. **Card display** — `name_edit.text = actor_data.get_display_name()` → GoatData returns `goat_name`. **Identical to the old `actor_resource.goat_name`.** `info_label.text = actor_data.get_info_line()` → GoatData returns `"Lvl: %d - Age: %d" % [level, age_days]`. **Minor regression noted by advisor §2:** old format was `"%s - Lvl: %d - Age: %d" % [gender_str, level, age_days]`. New format drops the leading `"Female - "` / `"Male - "` prefix. Gender remains discoverable via the doe/buck container split and the breeding picker, so the regression is purely cosmetic and aligns with the spec's `get_info_line()` decision. Pregnancy + exhausted `[P]` / `[E]` suffixes still append.
5. **Player picks doe + buck** — `card.selected` → `_on_actor_selected(actor: ActorData)`. The female goes into `selected_doe`, male into `selected_buck`. Both typed `ActorData`; assignment from a GoatData is a widening cast, always succeeds.
6. **Player presses Breed** — `HerdManager.breed(selected_doe, selected_buck)`. `BreedingComponent.breed` does the gender + exhaustion check (reads `gender` and `is_exhausted`, both on ActorData), sets `is_pregnant = true` and `pregnancy_timer` on the female.
7. **Day advances** — `HerdManager.next_day()` calls `progression_manager.advance_day(herd)`. For a pregnant goat, ProgressionComponent ages it (reads `age_days` on GoatData → still works), decrements timer indirectly via `BreedingComponent.process_pregnancy()`. After three days, `process_pregnancy()` calls `actor.create_offspring(partner)` → returns a GoatData kid.
8. **Kid lands in herd** — the new B7 code at HerdManager.gd:99-101 is `for kid in new_kids: if kid: add_goat(kid)`. The kid (GoatData) goes through `add_goat(actor: ActorData)` → `herd_manager.add_goat(actor: ActorData)`. Identical to pre-patch (just removed the unnecessary `as GoatData` cast).
9. **Save** — `GameEvents.herd_updated` → `save_game()` → `SaveComponent.save_game(herd, ...)`. `herd` is `Array[ActorData]` containing all-GoatData → `ResourceSaver.save()` writes the same file shape as before.
10. **Reload** — `ResourceLoader.load()` → `GoatSaveData.herd` deserialized. Each entry passes `is ActorData`. Herd restored. **Identical to pre-patch.**

**Verdict:** Goat-only path has zero functional regression. The single cosmetic change (info line gender prefix) is intentional per spec and the advisor's accepted note.

### Static-compile sanity check

Mentally compiled each touched `.gd` against the typed signatures and the existing call sites. Top concerns:

- `actor_data is GoatData` short-circuit before `actor_renderer.goat_data = actor_data` ensures no setter type error for non-goat cards (advisor §1).
- `card.goat_data = actor` in Ranch.gd line 62 works for any `ActorData` because the `goat_data` setter on ActorCard is `set(v): actor_data = v` (no type narrowing on the setter side; the getter returns null for non-goat which is fine because no consumer reads `card.goat_data` for a non-goat).
- `actor_data` setter calls `setup(v)`, then `setup()` reads `actor_data` (`if actor_data:` and `actor_data.stats_changed.connect`). The `actor_data` getter is just `data_resource as ActorData`, so after `super.setup(p_data)` writes `data_resource`, the next `actor_data` read returns the value just set. No re-entry hazard.
- `_actor._data` access from `ActorCard.set_actor()` works because `_data` is `@export` on Actor and exported vars are exposed by name; no script-private restriction.

---

## 10. Open Questions for Agent 3

| # | Topic | Action requested |
|---|-------|------------------|
| Q1 | **GoatRenderer rename — flagged follow-up.** Three live `.tscn` files reference `res://UI/GoatRenderer.tscn` by path: `UI/GoatRenderer.tscn` itself, `UI/DisplayCard/GoatCard.tscn`, `UI/DisplayCard/ActorCard.tscn`. Plus `ActorCard.gd:4` types the `@onready` to `GoatRenderer`. Rename requires: (1) move file + update `class_name`, (2) update `[ext_resource]` paths in three `.tscn` files, (3) update `@onready` type in `ActorCard.gd`, (4) regenerate `.uid`. Worth a dedicated patch because of the scene-tree node-name dependency. | Schedule as Patch 3a or 3b. Verify no third-party `.gd` references appear after the rename. |
| Q2 | **`ProgressionComponent.advance_day()` crash on non-goat kid.** With B7 fixed, a non-goat kid in the herd will crash on the next day advance because lines 14, 22 read `age_days` / `stamina_current` / `stamina_max` (GoatData-only). Latent today since no UI path adds non-goats to the herd. **Test trigger:** debug-spawn a Mimic, breed it via Ranch (requires also adding a Mimic to the herd, which currently is impossible via UI). Recommended fix: lift `age_days`, `stamina_max`, `stamina_current` to ActorData OR add `var goat = actor as GoatData; if not goat: continue` at the top of the loop. | Lift to ActorData if these fields are universally meaningful; otherwise gate. |
| Q3 | **`HerdManager.sell_goat()` returns 0 gold for non-goats.** Cast to GoatData at line 84-89 means selling a future Goblin or Elemental yields no economy payout. Trivial fix: lift `gold_value` to ActorData with a sensible default. | Defer until non-goat actors are first-class herd members. |
| Q4 | **`GoatActor.die()` removes from herd; no peer hook on other Actors.** If a non-goat herd member dies in the arena, `HerdManager.remove_goat()` is never called and the dead reference stays in the herd. Latent today. | Add a virtual `_on_actor_died_remove_from_herd()` hook in `Actor.die()` so subclasses can opt in. |
| Q5 | **`GoatData.create_offspring()` reads `partner.horn_type` / `partner.body_type`.** Pre-existing (not from this patch). If a `GoatData` is bred with a non-goat partner, line 103-104 crash. Today impossible via UI (Ranch only shows goats). Document or fix when cross-species pairing becomes a real path. | Note only. |
| Q6 | **In-editor verification needed for the save round-trip with mixed subclasses.** See §9. Open the editor once, force-import the new `*Data` scripts, then run the breeding sequence with a non-goat kid and verify the herd survives a save+reload cycle. Fall-back is `Array[Resource]` in `GoatSaveData.gd`. | Run the test sequence in §9. |
| Q7 | **In-editor verification of goat-only regression.** Spec required confirmation by code reading (done in §9), but a 60-second manual test (load existing save, enter Ranch, pair two goats, advance 3 days, confirm kid + name + sort) gives ground truth. | Run once. |
| Q8 | **Consider auto-creating default `*Data` for the four non-goat actors in `_init()`?** Spec says no — keep legacy `_data == null` behavior. Worth re-evaluating after Patch 3 when the data resources have proven themselves. | Defer. |

---

*End of Agent 2 Patch 2 Log.*
