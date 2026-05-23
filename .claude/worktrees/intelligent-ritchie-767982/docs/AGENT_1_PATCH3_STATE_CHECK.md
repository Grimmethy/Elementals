# Agent 1 — Patch 3 State Check (Unblock Non-Goat Creatures End-to-End)

> Read-only audit locking the scope for Patch 3. Pre-locked items per [ELEMENTALS_PATCH2_STATUS.md §10](ELEMENTALS_PATCH2_STATUS.md):
> 1. `ProgressionComponent.advance_day()` generalized via `ActorData.tick_day(day)` virtual.
> 2. `HerdManager.sell_goat()` uses `ActorData.get_sell_value()` virtual.
> 3. Non-goat actor `die()` hooks call `HerdManager.remove_goat(_data)`.
> 4. `BreedingComponent.breed_asexual(parent)` skips the gender gate.
> 5. `ActorData.get_actor_type()` default loud (returns `&""` + warning).
> 6. `UI/GoatRenderer.gd` → `UI/ActorCardRenderer.gd` rename + per-type dispatch.
>
> All paths repo-relative. Line numbers from current HEAD (`7c3b0b2`).

---

## 1. Files Read

- `docs/ELEMENTALS_PATCH2_STATUS.md` (Patch 3 scope §10)
- `docs/AGENT_1_PATCH2_STATE_CHECK.md` (Patch 2 R-list)
- `docs/COWORKER_IMPLEMENTATION_NOTES.md` §0 (Patch 2 Addendum)
- `Core/Managers/ProgressionComponent.gd` (full file, 26 lines)
- `Components/BreedingComponents/HerdManager.gd` (full file, 109 lines)
- `Core/Managers/BreedingComponent.gd` (full file, 55 lines)
- `Core/Managers/HerdComponent.gd` (full file, 71 lines)
- `Components/ActorComponents/ActorData.gd` (full file, 130 lines)
- `Components/BreedingComponents/GoatData.gd` (full file, 114 lines)
- `Components/BreedingComponents/GoblinData.gd`, `FarmerData.gd`, `ElementalData.gd`, `MimicData.gd` (full files)
- `Components/ActorComponents/ActorVisualComponent.gd` lines 80–145
- `src/actors/base/Actor.gd` lines 410–470 (`die()`)
- `src/actors/types/GoatActor.gd` (full)
- `src/actors/types/GoblinMinion.gd`, `FarmerActor.gd`, `FireActor.gd`, `WaterActor.gd`, `MimicActor.gd` (full)
- `src/actors/types/MimicController.gd` lines 200–235
- `Components/ActorComponents/CreatureMorphComponent.gd` lines 40–70
- `Components/BreedingComponents/Ranch/Ranch.gd` (full file, 149 lines)
- `UI/GoatRenderer.gd` (full file, 46 lines)
- `UI/GoatRenderer.tscn` (full file)
- `UI/GoatRenderer.gd.uid`
- `UI/DisplayCard/ActorCard.gd` (full file, 230 lines)
- `UI/DisplayCard/ActorCard.tscn` (full file)
- `UI/DisplayCard/GoatCard.tscn` (full file)
- `Markdowns/Actor.md` (version header)

Greps: `get_actor_type`, `func die\(\)`, `remove_goat`, `GoatRenderer`, `ActorCard\.tscn|GoatCard`.

Directory listings: `src/actors/types/`, `UI/`, `UI/DisplayCard/`, `Components/BreedingComponents/`.

---

## 2. Current Body of Each Touched Method/File

### 2.1 `Core/Managers/ProgressionComponent.gd` — full file

```gdscript
class_name ProgressionComponent
extends Node

var current_day: int = 1

func initialize(initial_day: int) -> void:
    current_day = initial_day

func advance_day(herd: Array[ActorData]) -> void:
    current_day += 1

    for goat in herd:
        # Aging
        goat.age_days += 1

        # Stamina Recovery (if they weren't selected, they recover fully)
        # If they were selected, they become exhausted
        if goat.is_selected:
            goat.is_exhausted = true
            goat.is_selected = false # Deselect for next day
        else:
            goat.stamina_current = goat.stamina_max
            goat.is_exhausted = false

    GameEvents.day_advanced.emit(current_day)
```

**Goat-only fields read:** `age_days`, `stamina_current`, `stamina_max`. All three live on `GoatData` only ([GoatData.gd:46-62](../Components/BreedingComponents/GoatData.gd)). `is_selected`/`is_exhausted` are now on `ActorData` (Patch 2). **Patch 3 target:** the entire body of the `for` loop becomes `actor.tick_day(current_day)` so each `ActorData` subclass owns its per-day logic.

### 2.2 `Components/BreedingComponents/HerdManager.gd:84-89` (`sell_goat`)

```gdscript
func sell_goat(actor: ActorData) -> void:
    # Cast to GoatData for goat-specific property, but design supports any ActorData
    var goat = actor as GoatData
    if goat:
        economy_manager.gold += goat.gold_value
    remove_goat(actor)
```

**`gold_value` lives at [GoatData.gd:66-71](../Components/BreedingComponents/GoatData.gd)** under `@export_group("Economy")`, default `50`. No other `*Data` subclass declares `gold_value`. **Patch 3 target:** replace the cast with `economy_manager.gold += actor.get_sell_value()`.

### 2.3 `src/actors/types/GoatActor.gd:74-83` (`die`)

```gdscript
func die() -> void:
    if is_dead:
        return

    # Call base Actor.die() for proper death: fall over, disable components, emit signals
    super.die()

    # Goat-specific: Permanent removal from the persistent herd
    if has_node("/root/HerdManager"):
        get_node("/root/HerdManager").remove_goat(goat_data)
```

**Template for non-goat actors.** Note `goat_data` is the typed accessor (returns `_data as GoatData`); if `_data == null` then `goat_data == null` and `remove_goat(null)` would call `herd.erase(null)` which is a no-op but emits `herd_updated` — the new non-goat hooks should gate with `if _data != null:` to avoid spurious events (more important: unowned wild creatures should not signal the herd at all).

### 2.4 `src/actors/base/Actor.gd:415-425` (`die` base)

```gdscript
func die() -> void:
    if is_dead:
        return
    is_dead = true
    if weapon_component:
        weapon_component.drop_inventory()
    if visual_component:
        visual_component.fall_over()
    _disable_living_components()
    died.emit()
    GameEvents.actor_died.emit(self)
```

Base `die()` is fully generic and idempotent (`if is_dead: return`). Subclasses call `super.die()` first then add hooks — GoatActor is the only subclass that overrides today.

### 2.5 `Core/Managers/BreedingComponent.gd:4-30` (`breed`)

```gdscript
func breed(parent_a: ActorData, parent_b: ActorData) -> bool:
    # Find which is male and which is female
    var male: ActorData
    var female: ActorData

    if parent_a.gender == ActorData.Gender.MALE and parent_b.gender == ActorData.Gender.FEMALE:
        male = parent_a
        female = parent_b
    elif parent_a.gender == ActorData.Gender.FEMALE and parent_b.gender == ActorData.Gender.MALE:
        male = parent_b
        female = parent_a
    else:
        return false  # Must be male + female

    if female.is_pregnant or female.is_exhausted or male.is_exhausted:
        return false

    female.is_pregnant = true
    female.pregnancy_timer = 3 # 3 days pregnancy
    female.pregnancy_father = male

    # Breeding is tiring
    female.is_exhausted = true
    male.is_exhausted = true

    GameEvents.herd_updated.emit()
    return true
```

**Gender gate** is the `if/elif/else: return false` block at lines 9-16. **Patch 3:** add a sibling method that bypasses this gate and assigns `is_pregnant = true` + `pregnancy_father = parent` on the same `parent`.

### 2.6 `Core/Managers/BreedingComponent.gd:32-48` (`process_pregnancy`) — already polymorphism-ready

```gdscript
func process_pregnancy(actors: Array) -> Array[ActorData]:
    var new_offspring: Array[ActorData] = []
    for actor in actors:
        if actor is ActorData and actor.is_pregnant:
            actor.pregnancy_timer -= 1
            if actor.pregnancy_timer <= 0:
                actor.is_pregnant = false
                var partner = actor.pregnancy_father
                if not partner:
                    partner = _find_random_male(actors)

                if partner:
                    var kid = actor.create_offspring(partner)
                    new_offspring.append(kid)

                actor.pregnancy_father = null
    return new_offspring
```

**This already supports asexual.** If `breed_asexual(parent)` sets `parent.pregnancy_father = parent` and `parent.is_pregnant = true`, this loop will call `parent.create_offspring(parent)` — exactly what `MimicData.create_offspring(_partner)` expects (it ignores the partner). The wider fallback `_find_random_male()` at line 50 is only used if `pregnancy_father` is null, so asexual paths bypass it.

### 2.7 `Components/ActorComponents/ActorData.gd:104-108` (`get_actor_type` default)

```gdscript
func get_actor_type() -> String:
    var script = get_script()
    if script:
        return script.get_global_name()
    return "ActorData"
```

**The silent-default risk.** Any subclass that forgets to override returns its raw `class_name` (e.g. `"GoatData"`, `"GoblinData"`) instead of the canonical lowercase factory key. `script.get_global_name()` is also reflection — replacing the body with `push_warning(...); return &""` makes accidental misses loud.

### 2.8 `Components/ActorComponents/ActorData.gd:9-92` (current Patch 2 surface)

Confirmed members after Patch 2:
- Ability scores (`strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, `charisma`) — all `float = 1.0` with `stats_changed` setters.
- Breeding: `gender`, `is_pregnant`, `pregnancy_timer`, `pregnancy_father: ActorData`, `is_exhausted`, **`is_selected` (lifted in Patch 2 at lines 76-80)**.
- Visual: `base_color`, `pattern_color`.
- Signal: `stats_changed`.

Virtuals after Patch 2 (lines 94-129):
- `create_offspring(partner: ActorData) -> ActorData` (push_error default)
- `get_actor_type() -> String` (silent default — Patch 3 target)
- `get_display_name() -> String` (returns `get_actor_type()`)
- `get_info_line() -> String` (returns `"Female"` / `"Male"`)
- `set_display_name(_new_name: String) -> void` (no-op)

### 2.9 `Components/BreedingComponents/GoatData.gd` — Patch 2 state

- `get_actor_type()` → `"goat"` (line 75-76) ✓
- `get_display_name()` → `goat_name` (line 79-80) ✓
- `get_info_line()` → `"Lvl: %d - Age: %d"` (line 85-86) ✓
- `set_display_name(new_name)` → `goat_name = new_name` (line 90-91) ✓
- `gold_value: int = 50` at lines 66-71 under `@export_group("Economy")` — the only home for this field.
- `age_days`, `stamina_max`, `stamina_current` at lines 46-62 — needed inside `GoatData.tick_day()`.

### 2.10 `UI/GoatRenderer.gd` — full file (46 lines)

See §4 below for the rename plan. Class definition: `class_name GoatRenderer extends Control`. Exports `goat_data: GoatData` with a setter that wires `stats_changed → update_visuals`. The `ASSETS` preload const dictionary references three goat-specific PNGs but **`update_visuals()` never reads them** — only scale is applied based on `body_type`. Dead texture maps; new `ActorCardRenderer` can drop them.

### 2.11 `UI/GoatRenderer.tscn` — full file

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://UI/GoatRenderer.gd" id="1_r8y2u"]
[node name="GoatRenderer" type="Control"]
...
script = ExtResource("1_r8y2u")
[node name="Body" type="TextureRect" parent="."]
[node name="Pattern" type="TextureRect" parent="."]
[node name="Horns" type="TextureRect" parent="."]
```

**No `uid="uid://..."` on the scene's `gd_scene` header.** `UI/GoatRenderer.gd.uid` exists as a sibling (`uid://bh4clot0ax5n3`).

### 2.12 `UI/DisplayCard/ActorCard.tscn` — relevant lines

```
[gd_scene load_steps=4 format=3 uid="uid://becy15jcmkmob"]
[ext_resource type="Script" uid="uid://crxh7omyleiuo" path="res://UI/DisplayCard/ActorCard.gd" id="1_p4l2m"]
[ext_resource type="PackedScene" path="res://UI/GoatRenderer.tscn" id="2_r8y2u"]
...
[node name="GoatRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]
```

### 2.13 `UI/DisplayCard/GoatCard.tscn` — relevant lines

```
[gd_scene load_steps=4 format=3 uid="uid://cxuqt0d6aexr2"]
[ext_resource type="Script" path="res://UI/DisplayCard/GoatCard.gd" id="1_p4l2m"]
[ext_resource type="PackedScene" path="res://UI/GoatRenderer.tscn" id="2_r8y2u"]
...
[node name="GoatRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]
```

**`GoatCard.tscn` references a `GoatCard.gd` script that does NOT exist on disk** (glob for `UI/DisplayCard/GoatCard.gd` returns nothing). The scene file is a dead asset already broken — Godot will fail to instantiate it. Live code never preloads `GoatCard.tscn` (all hits are in `.ziva/snapshots/`). Updating the path inside it is still required to keep the rename grep-clean, but breaking it further is harmless because nothing loads it.

### 2.14 `UI/DisplayCard/ActorCard.gd:1-15`

```gdscript
class_name ActorCard
extends DisplayCardBase

@onready var actor_renderer: GoatRenderer = $VBoxContainer/GoatRenderer
@onready var name_edit: LineEdit = $VBoxContainer/TopRow/NameEdit
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var str_label: Label = $VBoxContainer/StatsGrid/StrLabel
...
```

Line 4 is the only typed `GoatRenderer` reference outside the renderer file itself. Line 110 (inside `_update_resource_ui`) writes `actor_renderer.goat_data = actor_data` after a `if actor_data is GoatData:` gate. After the rename, that property becomes `actor_renderer.actor_data` (or both, with the defensive alias).

---

## 3. Death Flow Analysis

### Current state

| Actor | Has `die()`? | Calls `HerdManager.remove_goat`? | Notes |
|---|---|---|---|
| `Actor` (base) | YES — `Actor.gd:415-425` | NO | Generic shutdown: drop weapon, fall over, disable components, emit `died` + `actor_died`. |
| `GoatActor` | YES — `GoatActor.gd:74-83` | YES — `get_node("/root/HerdManager").remove_goat(goat_data)` | Template for Patch 3. |
| `GoblinMinion` | NO | NO (relies on base) | Needs override calling `remove_goat(_data)` if `_data != null`. |
| `FarmerActor` | NO | NO | Same. |
| `FireActor` | NO | NO | Same. |
| `WaterActor` | NO | NO | Same. |
| `MimicActor` | NO | NO | Same — and the prompt's `(if exists)` qualifier reflects that no override is present today. |

### Today's death flow (single-actor)

1. Damage → `HealthComponent` fires `died` (read but not displayed in this audit; pattern confirmed by `GoatActor.die()` being callable).
2. Actor (or subclass) `die()` runs `Actor.die()` shutdown.
3. `GameEvents.actor_died.emit(self)` fires for everyone.
4. For goats only: `HerdManager.remove_goat(goat_data)` keeps the persistent herd in sync.

### Risk if a non-goat is in the herd today

`HerdComponent.remove_goat(actor)` does `herd.erase(actor)` + emits `herd_updated`. If the actor's `die()` doesn't call it, the herd retains a stale `ActorData` reference whose backing actor is dead. Save round-trip persists the corpse. Ranch UI shows a still-clickable ghost goblin. No crash, but state desync.

### Why `if _data != null:` matters

`Actor._data` is `null` for all current spawn paths of `GoblinMinion`/`FarmerActor`/`FireActor`/`WaterActor` (Patch 2 confirmed — see [AGENT_1_PATCH2_STATE_CHECK.md §2.6](AGENT_1_PATCH2_STATE_CHECK.md)). Without the null gate, wild combat goblins would emit `herd_updated` on every death and call `herd.erase(null)`. The Patch 3 spec gates correctly.

### Recommended `die()` shape for non-goat actors

```gdscript
func die() -> void:
    if is_dead:
        return
    super.die()
    # Persistent herd cleanup — only fires when this actor carries a data
    # resource (designer-assigned, not the legacy unowned spawn path).
    if _data != null and has_node("/root/HerdManager"):
        get_node("/root/HerdManager").remove_goat(_data)
```

(Mirrors `GoatActor.die()` exactly — guards the autoload lookup, idempotent via `is_dead`, generic via `_data` not the typed accessor.)

---

## 4. GoatRenderer Rename Plan

### Files that must change (live tree only)

| # | Path | Change | Risk |
|---|---|---|---|
| 1 | `UI/GoatRenderer.gd` | Rename to `UI/ActorCardRenderer.gd`. Change `class_name GoatRenderer` → `class_name ActorCardRenderer`. Add `actor_data: ActorData` export with `goat_data: GoatData` alias. Make `update_visuals()` dispatch on `actor_data.get_actor_type()`. | Low — single file, no callers besides the .tscn ext_resource. |
| 2 | `UI/GoatRenderer.gd.uid` | Rename to `UI/ActorCardRenderer.gd.uid`. **Keep the same `uid://bh4clot0ax5n3` contents** so any external references resolve. Godot will regenerate if deleted, but renaming preserves UID stability. | Low if preserved verbatim. |
| 3 | `UI/GoatRenderer.tscn` | Rename to `UI/ActorCardRenderer.tscn`. Edit `[ext_resource ... path="res://UI/GoatRenderer.gd" id="1_r8y2u"]` → `path="res://UI/ActorCardRenderer.gd"`. **Keep `id="1_r8y2u"` so `script = ExtResource("1_r8y2u")` on line 10 still resolves.** Edit `[node name="GoatRenderer" type="Control"]` (line 5) → `[node name="ActorCardRenderer" type="Control"]`. | Medium — string IDs must match exactly. |
| 4 | `UI/DisplayCard/ActorCard.tscn` line 4 | Edit `[ext_resource type="PackedScene" path="res://UI/GoatRenderer.tscn" id="2_r8y2u"]` → `path="res://UI/ActorCardRenderer.tscn"`. **Keep `id="2_r8y2u"` so `instance=ExtResource("2_r8y2u")` on line 44 still resolves.** | Low — single line edit. |
| 5 | `UI/DisplayCard/ActorCard.tscn` line 44 | Edit `[node name="GoatRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]` → `[node name="ActorCardRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]`. **Node-tree path changes from `$VBoxContainer/GoatRenderer` to `$VBoxContainer/ActorCardRenderer`** — must match item 6. | **High — name change breaks the `@onready` lookup if path string is not updated in lockstep.** |
| 6 | `UI/DisplayCard/ActorCard.gd:4` | Edit `@onready var actor_renderer: GoatRenderer = $VBoxContainer/GoatRenderer` → `@onready var actor_renderer: ActorCardRenderer = $VBoxContainer/ActorCardRenderer`. Update `actor_renderer.goat_data = actor_data` at line 110 → `actor_renderer.actor_data = actor_data`. | **High — must coordinate with item 5.** |
| 7 | `UI/DisplayCard/GoatCard.tscn` line 4 | Edit `path="res://UI/GoatRenderer.tscn"` → `path="res://UI/ActorCardRenderer.tscn"`. **Keep `id="2_r8y2u"`.** Note: this scene also references `UI/DisplayCard/GoatCard.gd` at line 3 which does NOT exist on disk — the scene is already broken/dead. Updating its path keeps the grep clean and avoids resurrecting a half-broken alias. | Low — dead asset (no live callers); update for hygiene. |
| 8 | `UI/DisplayCard/GoatCard.tscn` line 44 | Edit `[node name="GoatRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]` → `[node name="ActorCardRenderer" parent="VBoxContainer" instance=ExtResource("2_r8y2u")]`. | Low — same dead asset. |

### About `ext_resource` IDs

The IDs (`1_r8y2u`, `2_r8y2u`) are **scene-local string handles**, not global. They map a short token to an external path inside one scene file. As long as the `id="..."` strings stay the same and the `path="..."` strings are updated, every `ExtResource("...")` reference inside the same scene continues to resolve to the new file. **DO NOT change the `id` values** — that would force changing every `ExtResource()` callsite inside the same .tscn.

### What's NEW vs simple rename

Per the pre-locked spec, the renamed class should:

1. Accept `actor_data: ActorData` (primary) with `goat_data: GoatData` defensive alias.
2. `update_visuals()` dispatches on `actor_data.get_actor_type()`:
   - `"goat"` → existing scale logic (preserve byte-exact behavior for the goat regression test).
   - other types → tinted-square placeholder + `get_display_name()` label until per-type renderers ship.
3. Connect/disconnect `stats_changed` on the setter the same way as today (write-time check `if actor_data:` before disconnect).

### `.uid` regeneration risk

Godot auto-generates `.uid` for any new script the first time the editor opens. If `UI/GoatRenderer.gd.uid` is deleted instead of renamed, a new UID gets assigned, breaking any future `uid://...` reference in saved `.tres` files. **Recommend renaming the `.uid` file in lockstep with the .gd, preserving the contents (`uid://bh4clot0ax5n3`).** `ActorCard.tscn` line 3 uses a different UID (`uid://crxh7omyleiuo`) which belongs to `ActorCard.gd`, not the renderer — unaffected.

---

## 5. Asexual Breeding Decision Surface

### Placement — `breed_asexual()` as sibling on `BreedingComponent`

Pre-locked recommendation per Patch 3 §10.5: new method `breed_asexual(parent: ActorData) -> bool` on `BreedingComponent`. This:

- Skips the gender gate (`else: return false`).
- Still respects `is_pregnant` + `is_exhausted` gates (no double-pregnancy, no zombie breeding).
- Sets `parent.is_pregnant = true`, `parent.pregnancy_timer = 3`, `parent.pregnancy_father = parent` (self-reference).
- Sets `parent.is_exhausted = true`.
- Emits `GameEvents.herd_updated`.

`HerdManager.breed_asexual(actor)` delegates exactly like `HerdManager.breed()`.

### Why this works without touching `process_pregnancy()`

[BreedingComponent.gd:39-45](../Core/Managers/BreedingComponent.gd) already does:

```gdscript
var partner = actor.pregnancy_father
if not partner:
    partner = _find_random_male(actors)

if partner:
    var kid = actor.create_offspring(partner)
```

When `pregnancy_father == actor`, `partner` resolves to `actor`, and `actor.create_offspring(actor)` is exactly the asexual-budding call signature `MimicData.create_offspring(_partner)` already accepts (it ignores the argument). No edit to `process_pregnancy` needed.

### Why NOT overload `breed()` itself

Two reasons: (a) `breed(parent_a, parent_b)` semantics are male+female and well-tested in the goat loop — adding optional behavior breaks the signature contract. (b) Asexual mode is a separate UI flow ("Bud" button on a Mimic card, not "Pair" button on two cards). A separate method makes the UI dispatch trivial.

### Future `BreedableComponent` ASEXUAL mode

Patch 3 scope is `breed_asexual()` only — the more invasive `BreedableComponent` enum is deferred per the pre-locked scope's narrower wording.

---

## 6. `get_actor_type()` Default Fix

### Subclass override coverage (verified by grep + reads)

| Class | Overrides `get_actor_type()`? | Returns | Source |
|---|---|---|---|
| `GoatData` | YES (Patch 2) | `"goat"` | [GoatData.gd:75-76](../Components/BreedingComponents/GoatData.gd) |
| `MimicData` | YES (Patch 1) | `"mimic"` | [MimicData.gd:62-63](../Components/BreedingComponents/MimicData.gd) |
| `GoblinData` | YES (Patch 2) | `"goblin"` | [GoblinData.gd:54-55](../Components/BreedingComponents/GoblinData.gd) |
| `FarmerData` | YES (Patch 2) | `"farmer"` | [FarmerData.gd:40-41](../Components/BreedingComponents/FarmerData.gd) |
| `ElementalData` | YES (Patch 2) | `String(element_subtype)` (typically `"fire"` or `"water"`) | [ElementalData.gd:56-57](../Components/BreedingComponents/ElementalData.gd) |

**All five subclasses override.** No subclass relies on the old `script.get_global_name()` default. Safe to swap default body to `push_warning(...); return ""`.

### `get_actor_type()` consumers

| File:Line | Use |
|---|---|
| [Components/ActorComponents/ActorData.gd:115](../Components/ActorComponents/ActorData.gd) | Default body of `get_display_name()` — `return get_actor_type()`. If default returns `""`, the card name blanks out for misconfigured subclasses (which IS the loud-failure mode we want — empty card vs `"GoblinData"` is much more visible). |
| [Components/ActorComponents/CreatureMorphComponent.gd:54](../Components/ActorComponents/CreatureMorphComponent.gd) | `_current_morph_target_type = StringName(target_data.get_actor_type())`. Used as a key — empty StringName is detectable (`if morph_type.is_empty(): bail`). |
| [src/actors/types/MimicController.gd:216](../src/actors/types/MimicController.gd) | `return StringName(candidate._data.get_actor_type())` inside `_resolve_actor_type()`. The function already falls back to `&"unknown"` at line 219 if no key resolves; empty-string from default would also work as filter key. |

**After Patch 3:** if a new subclass forgets to override, the morph component will bail safely, the Mimic controller will treat it as `&""` (filter excludes empty), and the ActorCard will show a blank name — all immediately visible to a tester.

### Recommended default

```gdscript
func get_actor_type() -> String:
    push_warning("ActorData.get_actor_type() not overridden by %s — returning empty string"
        % (get_script().resource_path if get_script() else "<unknown>"))
    return ""
```

`""` over `&""` because the signature returns `String`, not `StringName`. Callers that want `StringName` already wrap.

---

## 7. Risks (R-list for Agent 2)

| # | Risk | Cite |
|---|---|---|
| R1 | **`HerdComponent.remove_goat(null)` is silently a no-op but emits `herd_updated`** — without the `if _data != null:` gate in non-goat `die()`, every wild-combat goblin death (no data resource) would spam herd-update signals and the autosave loop. Mitigation is in the Patch 3 spec — Agent 2 must include the gate. | [HerdComponent.gd:23-26](../Core/Managers/HerdComponent.gd), Patch 3 spec item 3 |
| R2 | **`ProgressionComponent.advance_day()` currently mutates `is_selected` and `is_exhausted` for ALL herd members** ([ProgressionComponent.gd:18-23](../Core/Managers/ProgressionComponent.gd)) — these two fields are on `ActorData`, but the stamina-recovery branch reads `goat.stamina_max` / `goat.stamina_current` which are `GoatData`-only. After lifting the loop body into `GoatData.tick_day()`, the **default `ActorData.tick_day()` MUST still handle `is_selected` / `is_exhausted`** (clear-on-non-selected). Otherwise non-goat herd members never deselect after an arena run. | [ProgressionComponent.gd:18-23](../Core/Managers/ProgressionComponent.gd) |
| R3 | **`Ranch.gd:135` cheat path constructs `GoatData.new()` directly and reads `goat_data.goat_name` / `level` / `strength`** ([Ranch.gd:134-148](../Components/BreedingComponents/Ranch/Ranch.gd)) — must remain functional after Patch 3. The cheat is goat-only by design; the renderer rename + per-type dispatch must not break the goat render path. | [Ranch.gd:134-148](../Components/BreedingComponents/Ranch/Ranch.gd) |
| R4 | **`GoatCard.tscn` references a missing `GoatCard.gd` script at line 3** — the scene is already broken (no live preloader hits it, all `GoatCard.tscn` references in grep are inside `.ziva/snapshots/`). Touching its `GoatRenderer.tscn` path is hygiene-only; **do NOT try to make `GoatCard.tscn` instantiable** in this patch. If the editor warning bothers Agent 2, suggest deleting `GoatCard.tscn` in a follow-up patch — not this one. | [UI/DisplayCard/GoatCard.tscn:3](../UI/DisplayCard/GoatCard.tscn), live caller grep |
| R5 | **Renaming `UI/GoatRenderer.gd.uid` vs deleting it** — if Agent 2 just renames the .gd and lets Godot regenerate the .uid, every saved `.tres` that references `uid://bh4clot0ax5n3` will silently break on next load. **Rename `UI/GoatRenderer.gd.uid` → `UI/ActorCardRenderer.gd.uid` keeping the contents (`uid://bh4clot0ax5n3`) verbatim**, and do the same for `UI/GoatRenderer.tscn` (no UID in its `gd_scene` header today, so no .uid sidecar to track). | [UI/GoatRenderer.gd.uid](../UI/GoatRenderer.gd.uid) |
| R6 | **`ActorCard.gd:108-112` already gates `if actor_data is GoatData:`** — after the renderer rename + per-type dispatch, this gate becomes redundant (the renderer itself dispatches). Agent 2 must **remove the gate** when switching the renderer assignment to `actor_renderer.actor_data = actor_data`, otherwise non-goat cards still get hidden. | [ActorCard.gd:102-112](../UI/DisplayCard/ActorCard.gd) |
| R7 | **`process_pregnancy()` self-reference re-entrance for asexual** — when `actor.pregnancy_father = actor`, the loop's `actor.is_pregnant = false` clear runs BEFORE `actor.create_offspring(actor)` is called ([BreedingComponent.gd:37-45](../Core/Managers/BreedingComponent.gd)). This is safe (no infinite re-entry), but Agent 2 should add a test: bud → next_day three times → kid appears + parent is no longer pregnant. Also `actor.pregnancy_father = null` runs after the create call — confirms no dangling self-reference in save data. | [BreedingComponent.gd:37-48](../Core/Managers/BreedingComponent.gd) |
| R8 | **`get_actor_type()` warning spam in CreatureMorphComponent** — the Mimic morphs every few seconds. If a non-overriding subclass ever reaches the morph path, the new `push_warning` fires per tick. The current subclasses all override, but defensive design suggests adding `if get_actor_type().is_empty(): return &""` at the top of `_resolve_actor_type()` and `morph_into()` so the warning fires once and downstream skips cleanly. | [CreatureMorphComponent.gd:54](../Components/ActorComponents/CreatureMorphComponent.gd), [MimicController.gd:214-219](../src/actors/types/MimicController.gd) |
| R9 | **`MimicActor._ready()` auto-creates a `MimicData` if none assigned** ([MimicActor.gd:33-34](../src/actors/types/MimicActor.gd)) — when a wild combat Mimic dies, `_data` is non-null (auto-created), so the new `MimicActor.die()` hook will call `remove_goat(_data)` on a Mimic that was never in the herd. The herd.erase() is a no-op for non-members, but the `herd_updated` signal fires. **Recommend**: in `MimicActor.die()`, additionally check `if _data in HerdManager.herd:` before removing. Mirror this in any actor whose `_ready()` auto-allocates `_data`. (GoatActor, GoblinMinion, FarmerActor, FireActor, WaterActor do NOT auto-create — only the Mimic does.) | [MimicActor.gd:31-34](../src/actors/types/MimicActor.gd) |
| R10 | **SYNC RULE — three doc files must update in the same commit:** `Markdowns/Actor.md` (add `tick_day` + `get_sell_value` to virtuals table; bump to v1.3); `Markdowns/Breeding.md` (note `breed_asexual` lands; mark Mimic UI path complete); `Markdowns/UI.md` (note ActorCardRenderer rename + per-type dispatch). | Patch 2 SYNC RULE in [COWORKER_IMPLEMENTATION_NOTES.md §11](COWORKER_IMPLEMENTATION_NOTES.md) |

---

## 8. Recommended Strict Patch Order

Each step independently testable. Test after each before the next. **Rename is LAST** so the other five items ship even if the rename trips a regression that needs a separate fix.

1. **`ActorData.tick_day(day: int)` virtual** at [ActorData.gd](../Components/ActorComponents/ActorData.gd). Default body: handle `is_selected` / `is_exhausted` clear-and-set behavior so non-goat herd members deselect correctly (R2). Add at the top so subclass overrides can `super.tick_day(day)` to inherit the deselect logic.
   - *Test:* project compiles; no consumer changes yet.

2. **`GoatData.tick_day(day)` override** at [GoatData.gd](../Components/BreedingComponents/GoatData.gd). Body: `super.tick_day(day)` + `age_days += 1` + the stamina/exhaustion logic from `ProgressionComponent.advance_day()` lines 18-23. *(Stamina behavior is currently entangled with `is_selected`; keep the exact same conditional so the regression test passes.)*
   - *Test:* breed two goats, advance 3 days, kid appears — regression check vs Patch 2 behavior.

3. **`ProgressionComponent.advance_day()` becomes a tick loop**: replace lines 12-23 with `for actor in herd: actor.tick_day(current_day)`.
   - *Test:* same goat regression as step 2 still passes.

4. **`ActorData.get_sell_value() -> int` virtual + `GoatData.get_sell_value()` override**. Default returns `0`; GoatData returns `gold_value`. Update `HerdManager.sell_goat()` lines 84-89 to `economy_manager.gold += actor.get_sell_value(); remove_goat(actor)`.
   - *Test:* sell a goat — gold delta unchanged from current behavior.

5. **Non-goat `die()` hooks** in `GoblinMinion`, `FarmerActor`, `FireActor`, `WaterActor`, `MimicActor`. Each adds:
   ```gdscript
   func die() -> void:
       if is_dead: return
       super.die()
       if _data != null and has_node("/root/HerdManager"):
           get_node("/root/HerdManager").remove_goat(_data)
   ```
   For `MimicActor` specifically also gate `if _data in HerdManager.herd:` to avoid spurious `herd_updated` from wild-combat Mimics (R9).
   - *Test:* spawn a wild goblin in arena, kill it — no console warnings, no spurious autosave.

6. **`BreedingComponent.breed_asexual(parent: ActorData) -> bool`** at [BreedingComponent.gd](../Core/Managers/BreedingComponent.gd). Body: gate on `parent.is_pregnant`/`is_exhausted`, set `pregnancy_timer = 3`, `pregnancy_father = parent`, `is_exhausted = true`, emit `herd_updated`, return `true`. **Add `HerdManager.breed_asexual(parent)` delegate.**
   - *Test:* programmatically `var m = MimicData.new(); HerdManager.add_goat(m); HerdManager.breed_asexual(m); HerdManager.next_day(); HerdManager.next_day(); HerdManager.next_day()` — kid Mimic appears in herd.

7. **`ActorData.get_actor_type()` default — make loud**. Replace lines 104-108 with `push_warning(...); return ""`. Verify all five subclasses override (§6 confirms they do).
   - *Test:* boot Ranch — no warnings (because all current subclasses override). Add a deliberately-unoverriding throwaway `ActorData` resource to confirm the warning fires.

8. **`UI/GoatRenderer` → `UI/ActorCardRenderer` rename** (LAST). Per §4 plan:
   - Rename `UI/GoatRenderer.gd` → `UI/ActorCardRenderer.gd`, change `class_name`, add `actor_data` export + `goat_data` alias, dispatch `update_visuals()` on `actor_data.get_actor_type()`.
   - Rename `UI/GoatRenderer.gd.uid` → `UI/ActorCardRenderer.gd.uid` (preserve `uid://bh4clot0ax5n3`).
   - Rename `UI/GoatRenderer.tscn` → `UI/ActorCardRenderer.tscn`, update `ext_resource` path (keep `id="1_r8y2u"`), update root `[node name="..."]`.
   - Update `UI/DisplayCard/ActorCard.tscn` line 4 path + line 44 node name.
   - Update `UI/DisplayCard/ActorCard.gd:4` `@onready` type + path string, and line 110 `actor_renderer.goat_data` → `actor_renderer.actor_data`. **Remove the `if actor_data is GoatData:` gate at line 108** (R6) so non-goat cards render the placeholder.
   - Update `UI/DisplayCard/GoatCard.tscn` lines 4 + 44 for hygiene (R4 — dead asset, no live callers).
   - *Test:* boot Ranch — goat cards render identically. Add a GoblinData to the herd via debug → goblin card shows placeholder visual + name + info line.

9. **Markdowns sync** (SYNC RULE — R10): bump `Markdowns/Actor.md` to v1.3, `Markdowns/Breeding.md` and `Markdowns/UI.md` to reflect Patch 3 deltas.

10. **Smoke test the mixed save round-trip**: goblin + farmer + fire elemental + mimic + goat in one herd, advance day 5×, save, reload — all five persist, all five tick correctly, no console errors.

---

*End of Agent 1 Patch 3 State Check.*
