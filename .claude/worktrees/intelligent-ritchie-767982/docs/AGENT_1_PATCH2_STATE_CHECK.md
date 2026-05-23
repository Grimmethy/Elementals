# Agent 1 — Patch 2 State Check (Breeding Generalization)

> Read-only audit locking the scope for the next patch (breeding generalization for non-goat species). Per pre-locked scope: fix B7, add `get_display_name()` virtual, generalize Ranch.gd + ActorCard, create GoblinData/FarmerData/ElementalData, wire each non-goat actor to its `*Data`, keep TraitInheritanceEngine inline, conditionally rename GoatRenderer.
>
> All paths repo-relative. Line numbers from current HEAD (commit `7c3b0b2`).

---

## 1. Files Read for State Check

- `docs/ELEMENTALS_IMPLEMENTATION_STATUS.md` §13
- `docs/AGENT_1_IMPLEMENTATION_REQUIREMENTS.md` §3 + §4
- `docs/COWORKER_IMPLEMENTATION_NOTES.md` §4 + §9 + §10–§11
- `Components/ActorComponents/ActorData.gd`
- `Components/BreedingComponents/HerdManager.gd`
- `Components/BreedingComponents/GoatData.gd`
- `Components/BreedingComponents/MimicData.gd`
- `Components/BreedingComponents/Ranch/Ranch.gd`
- `Core/Managers/SaveComponent.gd`
- `Core/Managers/BreedingComponent.gd`
- `Core/Managers/HerdComponent.gd`
- `Core/GoatSaveData.gd`
- `Core/GameEvents.gd`
- `Core/ItemsAutoload.gd` (lines 1–35, 150–164)
- `UI/MainMenu.gd` (lines 1–100)
- `UI/DisplayCard/ActorCard.gd`
- `UI/GoatRenderer.gd`
- `Components/ActorComponents/ActorVisualComponent.gd` (lines 80–140)
- `Components/Arena/ActorFactory.gd`
- `Components/Arena/ArenaSpawner.gd` (registration block)
- `src/actors/base/Actor.gd` (lines 1–215, `_data` accessor)
- `src/actors/types/GoatActor.gd`
- `src/actors/types/GoblinMinion.gd`
- `src/actors/types/FarmerActor.gd`
- `src/actors/types/FireActor.gd`
- `src/actors/types/WaterActor.gd`
- `src/actors/types/MimicActor.gd`

Directory listings: `src/actors/types/`, `Components/BreedingComponents/`, `Components/ActorComponents/`, `Core/`.

Grep audits: `GoatRenderer`, `\.goat_name|\.goat_data`, `get_actor_type`, `_data as`, `is_selected`, `element_type =`.

---

## 2. Current State of Each Touched File

### 2.1 `Components/ActorComponents/ActorData.gd`

Current public members (all `@export` with setter that emits `stats_changed`):

- Ability Scores: `strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, `charisma` (all `float = 1.0`)
- Breeding: `gender: Gender` enum {MALE, FEMALE}, `is_pregnant: bool`, `pregnancy_timer: int`, `pregnancy_father: ActorData`, `is_exhausted: bool`
- Visual: `base_color: Color = WHITE`, `pattern_color: Color = GRAY`
- Signal: `stats_changed`

Virtuals (lines 86–96):

```gdscript
## Override in subclasses to create offspring with proper genetic mixing
func create_offspring(partner: ActorData) -> ActorData:
	push_error("ActorData.create_offspring() must be overridden by subclass")
	return null

## Returns the type identifier for this actor (e.g., "GoatData", "GoblinData")
func get_actor_type() -> String:
	var script = get_script()
	if script:
		return script.get_global_name()
	return "ActorData"
```

**No `get_display_name()` exists.** Only two virtuals: `create_offspring()` and `get_actor_type()`. Note `get_actor_type()` default returns the **class name** (e.g. `"GoatData"`), NOT a canonical lowercase key like `"goat"` — `MimicData` overrides this to return `"mimic"` (§8 below). This default behavior is the registry-key risk.

### 2.2 `Components/BreedingComponents/HerdManager.gd:90-110`

Current cast-and-drop code:

```gdscript
func next_day() -> void:
	progression_manager.advance_day(herd_manager.herd)
	
	# Process pregnancies with generic handler
	var new_kids: Array[ActorData] = breeding_manager.process_pregnancy(herd_manager.herd)
	for kid in new_kids:
		# For now, add as GoatData if possible; future types may have their own handlers
		var goat_kid = kid as GoatData
		if goat_kid:
			add_goat(goat_kid)
		# TODO: Add handlers for other actor types (GoblinData, ElementalData, etc.)
	
	# Any other day-transition logic...
	GameEvents.herd_updated.emit()
```

Fix: replace lines 100–104 with a single `if kid: add_goat(kid)` since `add_goat()` already takes `ActorData` (verified — `HerdManager.add_goat(actor: ActorData)` at line 78 delegates to `herd_manager.add_goat(actor: ActorData)` at `HerdComponent.gd:17`).

### 2.3 `Components/BreedingComponents/Ranch/Ranch.gd`

Goat-typed signatures and references (file is 140 lines):

- Line 18: `var selected_doe: GoatData`
- Line 19: `var selected_buck: GoatData`
- Line 48: `return a.goat_name < b.goat_name` (sort)
- Line 53: `card.goat_data = goat` (in container loop)
- Line 73: `func _on_goat_selected(goat: GoatData) -> void:`
- Line 89: `card.goat_data = selected_doe`
- Line 94: `card.goat_data = selected_buck`
- Line 99: `var selected = HerdManager.get_selected_goats()` (method already returns `Array[ActorData]` — generic on the manager side)
- Lines 125–137: `_on_max_level_goat_pressed()` builds `GoatData.new()`, sets `goat_name`/`level`, calls `HerdManager.add_goat(max_goat)`. **Must remain functional as a cheat path; this is the only file currently constructing `GoatData.new()` from UI.**

### 2.4 `UI/DisplayCard/ActorCard.gd`

Current `goat_data`/`actor_resource` machinery (already partially refactored — there is an `actor_resource` getter on top of `data_resource`):

- Line 4: `@onready var actor_renderer: GoatRenderer = $VBoxContainer/GoatRenderer` — **typed to the `GoatRenderer` class**, blocks the rename
- Lines 16–26:
  ```gdscript
  var actor_resource: GoatData:
  	get:
  		return data_resource as GoatData
  	set(v):
  		setup(v)
  
  # Alias for compatibility with existing code
  var goat_data: GoatData:
  	get: return actor_resource
  	set(v): actor_resource = v
  ```
  Both `actor_resource` and `goat_data` are typed `GoatData`. They share `data_resource` (presumably from `DisplayCardBase`).
- Line 40: `setup(_actor.goat_data)` — branches only if `_actor is GoatActor`
- Line 85: `actor_renderer.goat_data = actor_resource` (in `_update_resource_ui`)
- Line 88: `name_edit.text = actor_resource.goat_name`
- Line 91: `"%s - Lvl: %d - Age: %d" % [..., actor_resource.level, actor_resource.age_days]` — touches `level` and `age_days`, **both `GoatData`-only**
- Lines 93–96: `is_pregnant`, `is_exhausted` (both on `ActorData`, fine)
- Line 112: `actor_resource.is_selected` — **`is_selected` lives on `GoatData`, not `ActorData`** (see §9 risk)
- Lines 196, 201: write `actor_resource.goat_name = ...`
- Line 192: `HerdManager.toggle_selection(actor_resource)` — manager already typed `ActorData`

**Generalization recipe:** introduce `actor_data: ActorData` getter/setter pair as primary; keep `goat_data: GoatData` alias proxying through it; gate every `goat_name`/`level`/`age_days`/`is_selected` access on subclass type or via the new `get_display_name()` virtual + a more generic `get_display_info()`.

### 2.5 `UI/GoatRenderer.gd`

Full file is 46 lines. Public surface:

- Line 1: `class_name GoatRenderer`
- Lines 4–12: `@export var goat_data: GoatData` with setter that connects/disconnects `stats_changed` and calls `update_visuals()`
- Lines 14–27: `const ASSETS = {body, patterns, horns}` — preloads goat-specific PNG textures keyed by `GoatData.PatternType` and `GoatData.HornType` enums
- Lines 29–30: `_ready()` calls `update_visuals()`
- Lines 32–45: `update_visuals()` — early-outs unless `goat_data` set; sets `custom_minimum_size`, `pivot_offset`, `scale` based on `goat_data.body_type` (SMALL/MEDIUM/LARGE). **The ASSETS dictionary is never actually applied** — `update_visuals()` only does scale. Texture maps appear dead in this file.

`ActorVisualComponent.setup_visuals(data)` (lines 85–115) is a **separate** dispatch on the 3D actor body — it does not call into `GoatRenderer.update_visuals()` at all. The 2D card-renderer and 3D world-renderer are independent paths.

### 2.6 `src/actors/types/*Actor.gd` — `*Data` exposure today

| File | element_type | `_data` accessor | Notes |
|---|---|---|---|
| `GoatActor.gd:26-28` | `"goat"` | `var goat_data: GoatData: get: return _data as GoatData; set(v): _data = v` | Reference pattern |
| `MimicActor.gd:14-16` | `"mimic"` | `var mimic_data: MimicData: get: return _data as MimicData; set(v): _data = v` | Reference pattern (parallel) |
| `GoblinMinion.gd` | `"goblin"` | **NO `_data` binding** — sets `ability_scores_component.*` directly in `_ready()` (lines 27–32); reads `GameSettings.selected_armor_index` etc. instead | No data resource; goblin appearance + stats come from `GameSettings` + `ArmorData` |
| `FarmerActor.gd` | `"farmer"` | **NO `_data` binding** — sets ability scores to 0 in `_ready()` (lines 14–19) | No data resource |
| `FireActor.gd` | `"fire"` | **NO `_data` binding** — preloads particle textures only | No data resource |
| `WaterActor.gd` | `"water"` | **NO `_data` binding** — same as Fire | No data resource |

`Actor.gd:23-31` defines `@export var _data: ActorData` with a setter that connects `stats_changed` → `_on_data_changed`. So when a non-goat actor is given a `*Data`, the `_on_data_changed` flow at `Actor.gd:195-210` will already sync ability scores into `ability_scores_component` automatically. **However, `_ready()` on the non-goat actors already hard-sets ability scores AFTER `super._ready()`** — so a `*Data` would need to be assigned BEFORE `_ready()` OR the actor needs to be refactored to consult its data when present.

---

## 3. Grep Audit for GoatRenderer References

Live references (excluding `.ziva/snapshots/` snapshot backups, `docs/`, and `Markdowns/`):

| Path | Line | Use |
|---|---|---|
| `UI/GoatRenderer.gd` | 1 | `class_name GoatRenderer` (definition) |
| `UI/GoatRenderer.tscn` | 3 | `[ext_resource type="Script" path="res://UI/GoatRenderer.gd" id="1_r8y2u"]` |
| `UI/GoatRenderer.tscn` | 5 | `[node name="GoatRenderer" type="Control"]` (root node name) |
| `UI/DisplayCard/ActorCard.gd` | 4 | `@onready var actor_renderer: GoatRenderer = $VBoxContainer/GoatRenderer` (typed class + child path) |
| `UI/DisplayCard/ActorCard.tscn` | 4 | `[ext_resource type="PackedScene" path="res://UI/GoatRenderer.tscn" id="2_r8y2u"]` |
| `UI/DisplayCard/ActorCard.tscn` | 44 | `[node name="GoatRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]` |
| `UI/DisplayCard/GoatCard.tscn` | 4, 44 | Same two references as `ActorCard.tscn` (this is the legacy scene that `Ranch.gd` does NOT instantiate — `ActorCard.tscn` is the one in use) |

Doc references (informational, not blockers): `docs/ELEMENTALS_PROJECT_STATUS_AND_NEXT_STEPS.md:162`, `docs/ELEMENTALS_IMPLEMENTATION_STATUS.md:57,401`, `docs/COWORKER_IMPLEMENTATION_NOTES.md:264`, `docs/AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md:433,439,1018`, `docs/AGENT_2_CODEBASE_AUDIT.md:39`, `docs/AGENT_1_IMPLEMENTATION_REQUIREMENTS.md:71,144`, `docs/AGENT_1_DOCUMENTATION_AUDIT.md:102,309`, `Markdowns/Breeding.md:90,129,739,786`.

**Verdict on rename: NOT SAFE in this patch.** Per pre-locked rule, "if grep returns zero references to the `GoatRenderer` class_name OR file path outside the file itself + ActorCard, do the rename". Grep found:

- File path references in three live `.tscn` files (`UI/GoatRenderer.tscn` itself, `UI/DisplayCard/GoatCard.tscn`, `UI/DisplayCard/ActorCard.tscn`)
- A typed `GoatRenderer` reference in `ActorCard.gd:4` (allowed per the rule)
- Internal node name `"GoatRenderer"` used as scene-tree path in `$VBoxContainer/GoatRenderer`

**KEEP filename + class_name; flag the rename as a follow-up.** The rename requires coordinated edits to (a) `UI/GoatRenderer.gd` `class_name`, (b) rename the file, (c) `UI/GoatRenderer.tscn` script `path=`, (d) optionally rename `.tscn`, (e) `UI/DisplayCard/ActorCard.tscn` `[ext_resource]` path + node name, (f) `UI/DisplayCard/GoatCard.tscn` same, (g) `UI/DisplayCard/ActorCard.gd` `@onready` type + node path string, plus `.uid` regeneration. Worth a dedicated follow-up patch.

---

## 4. Save System Mixed-Subclass Risk

### Current schema

`Core/GoatSaveData.gd` (full file, 7 lines):

```gdscript
class_name GoatSaveData
extends Resource

@export var herd: Array[ActorData] = []
@export var gold: int = 100
@export var current_day: int = 1
```

Typed `Array[ActorData]` — already generic at the schema level. **Mixed subclasses are storable.**

### Serialization (`Core/Managers/SaveComponent.gd:7-23`)

```gdscript
func save_game(herd: Array[ActorData], gold: int, current_day: int) -> void:
	if _save_pending: return
	_save_pending = true
	_perform_save_deferred.call_deferred(herd, gold, current_day)

func _perform_save_deferred(herd: Array[ActorData], gold: int, current_day: int) -> void:
	_save_pending = false
	var save = GoatSaveData.new()
	save.herd = herd
	save.gold = gold
	save.current_day = current_day
	var err = ResourceSaver.save(save, SAVE_PATH)
```

### Deserialization (`SaveComponent.gd:25-50`)

```gdscript
func load_game() -> GoatSaveData:
	...
	var save = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if save is GoatSaveData:
		# Convert legacy GoatData entries to ActorData for generic handling
		var converted_herd: Array[ActorData] = []
		for actor in save.herd:
			if actor is ActorData:
				converted_herd.append(actor)
		save.herd = converted_herd
		return save
```

### Round-trip risk analysis for mixed `Array[ActorData]`

**Round-trip is technically supported but has three concrete risks:**

1. **`ResourceSaver.save()` with `.tres` and sub-resources of varying class_name should serialize them with their script path (`script = ExtResource(...)`)**. For this to round-trip, each `*Data` subclass MUST have its `.gd.uid` registered and its `class_name` resolvable at load time. `GoblinData`/`FarmerData`/`ElementalData` do not yet exist, so the first-ever save after adding them will require an editor re-import. Hot-loading a save built in one editor session with a `class_name` newly added in the same session has historically required at least one Godot restart in 4.x.

2. **The load filter `if actor is ActorData: converted_herd.append(actor)`** discards entries that fail the cast. If `ResourceLoader` cannot resolve a subclass (e.g. user opened a save built on a branch that had `GoblinData`, then checked out a branch without it), `actor` will deserialize as a plain `Resource` (NOT `ActorData`) and **be silently dropped**. This is current behavior and continues to be a concern with more subclasses in play.

3. **Typed `Array[ActorData]` and Godot 4.6 sub-resource handling.** When a `.tres` saved with `Array[ActorData]` contains polymorphic entries, Godot writes each entry as a `SubResource` with its own `script` pointer. The typed-array constraint is enforced at load — if a subclass's script can't load, the whole `Array[ActorData]` may be wiped to empty (observed bug pattern in Godot 4.6.x). **Mitigation suggestion for Agent 2:** verify with a manual editor test once GoblinData/FarmerData/ElementalData exist; if the herd wipes, change `GoatSaveData.herd` to `Array[Resource]` and re-cast on load.

4. **Legacy goat-only saves on disk (`user://herd_save.tres`)**: the file users have today is `Array[GoatData]` written when only GoatData existed. Loading that as `Array[ActorData]` should work since `GoatData extends ActorData`. The load-side filter `if actor is ActorData` will accept all entries. Safe.

**Recommendation to Agent 2:** Do not introduce `Array[GoblinData]`-typed fields anywhere. Keep `Array[ActorData]` only. After creating subclasses, open Godot once before testing breeding to force re-import. If herd-wipe occurs in editor testing, fall back to `Array[Resource]` + explicit cast.

---

## 5. GameEvents Audit

`Core/GameEvents.gd` (full file, 19 lines):

```gdscript
extends Node

# Actor/Combat Signals
signal actor_died(actor: Node3D)
signal element_applied(target: Node, element: String, direction: Vector3)

# Management/Economy Signals
signal gold_changed(new_amount: int)
signal herd_updated()
signal day_advanced(new_day: int)
signal day_finished()

# UI/Interaction Signals
signal actor_selection_toggled(actor: ActorData, is_selected: bool)
signal request_ui_update()
signal weapon_equipped(weapon: WeaponData)

# Deprecated: Use actor_selection_toggled instead
# signal goat_selection_toggled(goat: GoatData, is_selected: bool)
```

**Confirmed:** `actor_selection_toggled(actor: ActorData, is_selected: bool)` exists at line 14. The deprecated `goat_selection_toggled` is **commented out**, not present — Agent 2 must NOT add it back. Selection-bus signals related to this work: `actor_selection_toggled`, `herd_updated`, `day_advanced`. Emitter: `HerdComponent.toggle_selection()` (`Core/Managers/HerdComponent.gd:31,42`).

---

## 6. MainMenu CHARACTER_EQUIPMENT Cross-Reference

`UI/MainMenu.gd:20-64` defines two dicts:

- `ACTOR_SCENES` (lines 20–27): `farmer`, `fire`, `water`, `goat`, `goblin`, `scarecrow` — **does not include `mimic`** (consistent with Mimic being spawn-only via ArenaFactory, not menu-selectable).
- `CHARACTER_EQUIPMENT` (lines 33–64): `goblin`, `farmer`, `goat`, `scarecrow`, `fire`, `water` — same six types as `ACTOR_SCENES`, no mimic.

**Cross-reference to non-goat data we're about to create:** The keys `farmer`, `goblin`, `fire`, `water` match the `element_type` strings on those actors AND match what we will use as the registry key for `FarmerData`/`GoblinData`/`ElementalData`. **Do not touch this dict in this patch** — but be aware Agent 2's new `*Data.get_actor_type()` overrides must return `"farmer"`, `"goblin"`, `"fire"`, `"water"` so the future generic equipment-lookup path will key correctly (see §8).

`scarecrow` is in the dict but Scarecrow is intentionally not in the breeding flow (per Agent 1 §3 table). No `ScarecrowData` planned in this patch.

---

## 7. Existing Breeding-Related Code Already Generic (No Touch Needed)

- `Core/Managers/BreedingComponent.gd` — fully generic at `ActorData` level. `breed(parent_a: ActorData, parent_b: ActorData)`, `process_pregnancy(actors: Array) -> Array[ActorData]`, polymorphic `actor.create_offspring(partner)` at line 44. **No changes needed**.
- `Core/Managers/HerdComponent.gd` — typed `var herd: Array[ActorData]`, generic `add_goat(actor: ActorData)`, `remove_goat(actor: ActorData)`, `toggle_selection(actor: ActorData) -> bool`, `get_selected_goats() -> Array[ActorData]`. **Method names are misleadingly goat-flavored but signatures are generic.** Only the body of `toggle_selection` has a hidden subclass dependency (`is_selected` — see §9 R3).
- `HerdManager.gd` delegate methods (lines 72–92): `toggle_selection`, `get_selected_goats`, `add_goat`, `remove_goat`, `breed` are all typed `ActorData` already. Only `sell_goat` (lines 84–89) does a `goat as GoatData` cast to read `gold_value` — minor; **don't generalize in this patch** unless `gold_value` is lifted to `ActorData`.
- `Core/GoatSaveData.gd` — schema typed `Array[ActorData]`. **Done.**
- `Core/GameEvents.gd::actor_selection_toggled` — generic. **Done.**
- `Core/ItemsAutoload.selected_actor_data: ActorData` (line 19) — generic bus. **Done.**
- `Components/ActorComponents/ActorVisualComponent.setup_visuals(data: ActorData)` (lines 85–92) — polymorphic dispatch already in place; new branches can be added when per-type renderers exist, but the base method is there. **No changes needed for this patch.**
- `Components/Arena/ActorFactory.gd` + `ArenaSpawner._register_default_actor_types()` — generic registry-based dispatch. **Done.**

---

## 8. `get_actor_type()` Strings

Confirmed from grep + reads:

| Class | `get_actor_type()` return | Source |
|---|---|---|
| `ActorData` (base) | `script.get_global_name()` → e.g. `"ActorData"` | `Components/ActorComponents/ActorData.gd:92-96` |
| `GoatData` | **does NOT override** → returns `"GoatData"` (the class name) | `Components/BreedingComponents/GoatData.gd` (no override) |
| `MimicData` | `"mimic"` (lowercase, canonical) | `Components/BreedingComponents/MimicData.gd:62` |

**Actor-side `element_type` strings (these are the canonical lowercase keys used everywhere else — `ACTOR_SCENES` dict, `ActorFactory.register`, `MainMenu.CHARACTER_EQUIPMENT`):**

- `GoatActor.element_type = "goat"`
- `GoblinMinion.element_type = "goblin"`
- `FarmerActor.element_type = "farmer"`
- `FireActor.element_type = "fire"`
- `WaterActor.element_type = "water"`
- `MimicActor.element_type = "mimic"`

`ScarecrowDummy` — not grepped above but is in the spawn list; per Agent 1 docs has `element_type = "scarecrow"` (and is NOT a breeding target).

**Inconsistency Agent 2 must resolve:** `GoatData.get_actor_type()` returns `"GoatData"` today (from the default), but every other consumer (factory keys, MainMenu, MimicData override) uses `"goat"`. **Agent 2 should override `GoatData.get_actor_type()` to return `"goat"` in this patch** to align with `MimicData`'s precedent and the factory keys. Each new `*Data` subclass should follow MimicData's pattern: explicit override returning lowercase canonical key (`"goblin"`, `"farmer"`, `"fire"`, `"water"`).

Registry keys for ActorFactory (already registered in `ArenaSpawner._register_default_actor_types()` lines 33–39): `&"farmer"`, `&"fire"`, `&"water"`, `&"goat"`, `&"goblin"`, `&"scarecrow"`, `&"mimic"`.

---

## 9. Risks & Constraints

| # | Risk | Cite |
|---|---|---|
| R1 | **`is_selected` lives on `GoatData`, not `ActorData`** — `HerdComponent.toggle_selection()` at `Core/Managers/HerdComponent.gd:29,30,36,41` reads/writes `actor.is_selected` directly. Adding a `GoblinData`/`FarmerData`/`ElementalData` to the herd will hit a "Invalid set/get index" runtime error the first time the user clicks its card. **Mitigation: lift `is_selected` from `GoatData` to `ActorData` in this patch** (one of the prerequisite hidden in B7/B9). | `GoatData.gd:63-67`, `HerdComponent.gd:29-47` |
| R2 | **`actor_resource.goat_name`, `level`, `age_days` used in `ActorCard._update_resource_ui()`** at `ActorCard.gd:88,91`. None of these live on `ActorData`. The new `get_display_name()` virtual covers `goat_name`. For `level`/`age_days`, either lift to `ActorData` (clean), gate on subclass type (brittle), or add a generic `get_info_line() -> String` virtual on `ActorData` so each subclass formats its own. **Agent 2 decision needed — recommend the virtual route, mirroring `get_display_name()`.** | `ActorCard.gd:88-91` |
| R3 | **`HerdComponent.toggle_selection()` filters via `if actor.is_exhausted`** at line 36 — `is_exhausted` IS on ActorData, fine. Just noting it works. | `HerdComponent.gd:36`, `ActorData.gd:68-72` |
| R4 | **`Ranch._on_max_level_goat_pressed()` cheat at `Ranch.gd:125-138` constructs `GoatData.new()` directly** and sets `goat_name`, `level`, `strength`, etc. — MUST remain functional. The Ranch generalization must NOT remove this method or change its `GoatData.new()` constructor call. The cheat is goat-specific by design; keep it as-is. | `Ranch.gd:125-138` |
| R5 | **`Ranch.gd:53,89,94` use `card.goat_data = goat`** — after generalization Agent 2 has two choices: (a) keep `goat_data` setter on ActorCard as a typed alias that forwards to the new `actor_data` setter (consistent with ItemsAutoload pattern at line 26–30), OR (b) replace call-sites with `card.actor_data = goat`. **Recommend (a) for backward-compat with `Play Space/OptionsMenu.gd:59-72` which still reads `gc.goat_data`** (see R6). | `Ranch.gd:53,89,94`, `OptionsMenu.gd:59-72` |
| R6 | **`Play Space/OptionsMenu.gd:59-72` reads `gc.goat_data.base_color` and writes `gc.goat_data.base_color = ...`** — `gc` appears to be a CharacterSelectCard. The `goat_data` alias must continue to be a live read/write proxy onto the actor's data resource OR OptionsMenu must be updated in this patch. Easier: keep alias. | `Play Space/OptionsMenu.gd:59-72` |
| R7 | **Non-goat actor `_ready()` methods hardcode ability scores after `super._ready()`**: `GoblinMinion.gd:27-32`, `FarmerActor.gd:14-19`. These run AFTER `Actor._ready` and AFTER `_on_data_changed` (which would otherwise sync from `_data.strength` etc per `Actor.gd:200-205`). If Agent 2 assigns a `*Data` resource to these actors, the actor's hardcoded `_ready()` will clobber the resource's stats. **Agent 2 must decide:** (a) gate the hardcode with `if _data == null:`, (b) only assign `*Data` via `_init`, or (c) refactor the actor to consult its data when present. Easiest: option (a). | `GoblinMinion.gd:22-32`, `FarmerActor.gd:10-19` |
| R8 | **GoatRenderer rename is NOT safe** — three live `.tscn` references + a typed `@onready` in `ActorCard.gd:4` (see §3). Flag as a follow-up patch. | §3 |
| R9 | **`MainMenu.CHARACTER_EQUIPMENT` is a duplicate of `Core/GameSettings.CHARACTER_EQUIPMENT`** per Agent 2 audit §9 — do NOT modify it in this patch (out of scope), but Agent 2 should know that adding `*Data` classes does NOT automatically need this dict updated. Mimic intentionally absent here. | `UI/MainMenu.gd:31-64` |
| R10 | **Save round-trip for first-time mixed herd may require Godot editor restart** so newly-added `*Data` `class_name`s register before `ResourceLoader.load()` can resolve them. Agent 2's smoke test should explicitly: build a goblin kid, save, restart editor, reload — verify the goblin survives. | `SaveComponent.gd:25-50`; §4 |
| R11 | **`GoatActor.die()` at line 82-83 calls `HerdManager.remove_goat(goat_data)`** — already typed-safe because `remove_goat` takes `ActorData`. No issue, just noting that other actor `die()` methods may need parallel hooks if non-goats can be members of the herd. **Out of scope for this patch but worth flagging for a future PR**. | `GoatActor.gd:82-83` |
| R12 | **`HerdManager.sell_goat` (lines 84-89)** casts `actor as GoatData` to read `gold_value`. Non-goat sales will return 0 gold. Acceptable for this patch; lift `gold_value` later or add per-subclass override. | `HerdManager.gd:84-89` |

---

## 10. Recommended Agent 2 Patch Order

Strict ordering, each step independently testable. Test after each step before moving on.

1. **Add `get_display_name() -> String` virtual to `ActorData`** at `Components/ActorComponents/ActorData.gd`. Default returns `get_actor_type()`. Zero consumer changes. *Test: project compiles.*

2. **Lift `is_selected` from `GoatData` to `ActorData`** (R1). Move the `@export var is_selected: bool` + setter from `GoatData.gd:63-67` into `ActorData.gd` Breeding group. Remove from `GoatData`. *Test: open Ranch — goats select/deselect; `HerdComponent.toggle_selection` still works.*

3. **Override `get_actor_type()` on `GoatData`** to return `"goat"` (matches `element_type`; aligns with MimicData precedent). Add `get_display_name()` override returning `goat_name`. *Test: open Ranch — Ranch sort + display unchanged.*

4. **Fix `HerdManager.next_day()` non-goat kid drop** (B7) at `HerdManager.gd:100-104`. Replace cast-and-drop with `if kid: add_goat(kid)`. *Test: breed two goats, advance 3 days, goat kid appears — regression check.*

5. **Create `GoblinData`, `FarmerData`, `ElementalData` (with `element_subtype: StringName` field)** in `Components/BreedingComponents/`. Each:
   - Extends `ActorData`
   - Overrides `get_actor_type()` → `"goblin"`/`"farmer"`/`"fire"` or `"water"` (ElementalData uses `element_subtype` to choose)
   - Overrides `get_display_name()` → identity field (e.g. `goblin_name`, `farmer_name`, `elemental_name`)
   - Implements `create_offspring(partner)` mirroring the goat algorithm (color lerp + 50/50 categorical for any genetic fields + stat mean ±10%)
   - No `is_selected` field (now on ActorData)
   - No new typed-array fields anywhere
   
   *Test: project compiles; create one of each in a debug script and call `create_offspring(self)` — returns a same-class kid.*

6. **Wire each non-goat actor to its `*Data` via `_data` accessor** mirroring GoatActor:
   - Add `var goblin_data: GoblinData: get: return _data as GoblinData; set(v): _data = v` to `GoblinMinion.gd`
   - Same for `FarmerActor`, `FireActor` (`fire_data: ElementalData`), `WaterActor` (`water_data: ElementalData`)
   - **Critical (R7):** gate each actor's `_ready()` hardcoded stat block with `if _data == null:` so a designer-assigned data resource is not clobbered
   
   *Test: spawn each actor type via existing pipeline; if no data assigned, old behavior preserved; if data assigned, scores come from data.*

7. **Generalize `ActorCard.gd`**: introduce `actor_data: ActorData` getter/setter pair as the primary API. Keep `goat_data: GoatData` as a typed alias proxying through it (R5, R6). Add `get_display_name()`-based name access (R2). Add a generic `get_info_line() -> String` virtual on ActorData and have each subclass return its formatted info; default to "Lvl ? Age ?" stub or just `gender` string. Defer if Agent 2 prefers, but R2 is real.
   
   *Test: open Ranch — every goat card renders identically to before; cheat panel still works.*

8. **Generalize `Ranch.gd`**: change `selected_doe`/`selected_buck` types from `GoatData` to `ActorData`. Replace the line-48 sort with `a.get_display_name() < b.get_display_name()`. Keep `card.goat_data = goat` UNCHANGED (the alias handles it) OR switch to `card.actor_data = goat` — both work. Keep `_on_max_level_goat_pressed` UNCHANGED (R4). 
   
   *Test: full breeding loop including the cheat panel.*

9. **GoatRenderer rename — SKIP this patch** (R8). Flag as follow-up.

10. **Smoke test the save round-trip** (R10) with a goblin in the herd. If Godot wipes the herd on reload, fall back to `Array[Resource]` typing in `GoatSaveData.gd` and re-cast on load.

11. **Manual integration test:** add a `GoblinData` to the herd via a debug button, breed it with another goblin, advance day, save, reload — goblin kid persists.

---

*End of Agent 1 Patch 2 State Check.*
