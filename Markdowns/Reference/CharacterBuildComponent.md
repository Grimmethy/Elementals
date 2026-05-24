# CharacterBuildComponent

**Version:** v0.1 — Draft
**Status:** Planned
**Depends on:** `ActorTypeData`, `AbilityComponent`, `ArmorClassComponent`, `FactionComponent`, `HealthComponent`, `GameSettings`

---

## Overview

`CharacterBuildComponent` is a generic initialization component that replaces per-actor-type setup scripts (e.g. `GoblinMinion._ready()`, `GoblinMinion._setup_ability_from_settings()`). It reads equipment and ability pools from `ActorTypeData`, selects one entry per pool (randomly for NPCs, via `GameSettings` for player-controlled actors), and applies the results to the actor's components.

The goal is to eliminate individualized actor scripts whose only purpose is spawn-time wiring. Once this component exists, `GoblinMinion.gd` (and similarly structured scripts for future humanoid types) can be deprecated in favor of a single data entry in `ActorTypeData`.

---

## Player Fantasy

Goblins you capture feel genuinely varied — one ambushes with Nimble Escape while another swaps targets with Redirect Attack. Players who farm goblins are rewarded with a roster of distinct builds, not identical clones.

---

## Detailed Design

### Responsibility

`CharacterBuildComponent` handles exactly three concerns at spawn time:

1. **Faction** — assign the actor to a faction from ActorTypeData
2. **Equipment selection** — pick armor, weapon, and ability from ActorTypeData pools
3. **HP roll** — roll max HP using the dice formula in ActorTypeData

Everything else (AI behavior, movement, stats scaling) stays with existing components.

### Build Flow

`CharacterBuildComponent.build()` is called from `Actor._ready()` after `_setup_components()` and `_apply_type_config()`, so all components are guaranteed to exist.

```
Actor._ready()
  └─ _setup_components()
  └─ _apply_type_config()        ← terrain, comm, should_bob
  └─ character_build_component.build()
       ├─ _apply_faction()
       ├─ _roll_hp()
       ├─ _apply_armor()
       ├─ _apply_weapon()
       └─ _apply_ability()
```

### Pool Selection

Each pool in ActorTypeData is an ordered array of string keys. Selection index is resolved once:

```gdscript
func _resolve_index(pool: Array, settings_index: int, is_player: bool) -> int:
    if is_player:
        return clampi(settings_index, 0, pool.size() - 1)
    return rng.randi_range(0, pool.size() - 1)
```

Player actors use `GameSettings.selected_armor_index`, `selected_weapon_index`, `selected_ability_index`. NPC actors randomize.

### Ability Registry

Abilities are resolved via a local registry (same pattern as `ActorAIController._BEHAVIOR_REGISTRY`):

```gdscript
const _ABILITY_REGISTRY: Dictionary = {
    "nimble_escape":    preload("res://Components/ActorComponents/AbilityComponents/NimbleEscape.gd"),
    "redirect_attack":  preload("res://Components/ActorComponents/AbilityComponents/RedirectAttack.gd"),
    "goat_charge":      preload("res://Components/ActorComponents/AbilityComponents/GoatCharge.gd"),
    "mimic_shapechange":preload("res://Components/ActorComponents/AbilityComponents/MimicShapechange.gd"),
}
```

`_apply_ability()` clears existing actions on `AbilityComponent` then instantiates and adds the selected entry.

### Armor Application

Armor keys map to `ArmorData.create_standard_armor(key)`. The special key `"none"` sets `armor_type = ArmorType.NONE` and `armor_value = 10` directly on `ArmorClassComponent` without creating an `ArmorData` resource.

After armor is applied, `CharacterBuildComponent` calls `actor.on_equipment_built(armor_key)` — a virtual method on `Actor` that actor subclasses or visual components can override to sync skin/model. Default implementation is a no-op, so actors without model-specific logic require no changes.

### Weapon Application

Weapon application follows the existing `GoblinMinion` pattern:
1. Look up weapon by name in `ItemsAutoload.weapons`
2. Fall back to `WeaponData` creation if not found
3. If the weapon has `"ranged": true` in its data, roll ammo count using `ammo_dice` from ActorTypeData

This keeps ammo logic out of the component — it delegates to `WeaponData` flags.

### Faction Application

ActorTypeData stores the faction as a string key:

```gdscript
"faction": "GOBLINS"
```

`CharacterBuildComponent` resolves this against `FactionComponent.Faction` enum by name and calls `faction_component.setup(resolved)`. If the key is absent or unresolvable, faction is left at the scene default (usually `NEUTRAL`).

---

## ActorTypeData Schema Additions

| Key | Type | Example | Notes |
|-----|------|---------|-------|
| `faction` | String | `"GOBLINS"` | Matches `FactionComponent.Faction` enum name |
| `hp_dice_count` | int | `2` | Number of dice for HP roll |
| `hp_dice_sides` | int | `6` | Sides per die |
| `armor_pool` | Array[String] | `["none", "leather", "chain shirt"]` | Ordered; index matches `GameSettings.selected_armor_index` |
| `weapon_pool` | Array[String] | `["Dagger", "Scimitar", "Shortbow"]` | Ordered; index matches `GameSettings.selected_weapon_index` |
| `ability_pool` | Array[String] | `["nimble_escape", "redirect_attack"]` | Keys into `_ABILITY_REGISTRY` |
| `ammo_dice` | String | `"2d10"` | Used when selected weapon has `ranged = true` |

All keys are optional. Missing pools skip that build step silently.

---

## Formulas

| Value | Formula |
|-------|---------|
| Max HP | `sum(hp_dice_count × roll(1, hp_dice_sides))` using actor's own RNG |
| Armor index (NPC) | `rng.randi_range(0, armor_pool.size() - 1)` |
| Armor index (player) | `clamp(GameSettings.selected_armor_index, 0, armor_pool.size() - 1)` |
| Ammo count | `sum(2 × roll(1, 10))` if `ammo_dice = "2d10"` — generalize to parsed dice string |

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Pool key not in `_ABILITY_REGISTRY` | Log warning, skip — no crash |
| `armor_pool` absent from ActorTypeData | Skip armor step; ArmorClassComponent retains scene default |
| Actor has no `AbilityComponent` | Skip ability step |
| Actor has no `FactionComponent` | Skip faction step |
| `ItemsAutoload` not ready at spawn | Fall back to hardcoded `WeaponData` construction |
| Player index out of pool bounds | Clamp to valid range |
| Actor already has ability actions (from `AbilityComponent.setup`) | Clear before applying — build is authoritative |

---

## Dependencies

### Requires
| System | Reason |
|--------|--------|
| `ActorTypeData` | Source of all pool and dice data |
| `AbilityComponent` | Target for ability application |
| `ArmorClassComponent` | Target for armor application |
| `FactionComponent` | Target for faction assignment |
| `HealthComponent` | Target for HP roll |
| `GameSettings` (autoload) | Player index source |
| `ItemsAutoload` (autoload) | Weapon lookup |

### Consumed By
| System | Reason |
|--------|--------|
| `Actor._ready()` | Calls `build()` during initialization |
| `GoblinMinion.gd` | Deprecated once this is implemented |
| Future humanoid actor scripts | Any actor type that uses pool-based equipment |

---

## Tuning Knobs

| Knob | Location | Effect |
|------|----------|--------|
| Pool contents | `ActorTypeData` per type | Controls what variants can spawn |
| Pool order | `ActorTypeData` per type | Determines which index a player gets per `GameSettings` selection |
| HP dice | `ActorTypeData` per type | Controls HP variance at spawn |
| Ammo dice | `ActorTypeData` per type | Controls ammo variance for ranged weapons |

---

## Acceptance Criteria

| # | Given | When | Then |
|---|-------|------|------|
| 1 | A NPC goblin spawns 100 times | Build runs each time | Both `nimble_escape` and `redirect_attack` appear in the sample |
| 2 | A player goblin spawns with `selected_ability_index = 0` | Build runs | Actor has `NimbleEscape` action, not `RedirectAttack` |
| 3 | `ActorTypeData` has no `ability_pool` for an actor type | Build runs | No error; `AbilityComponent` actions unchanged |
| 4 | An armor pool key (`"chain shirt"`) is selected | Build runs | `ArmorClassComponent.calculate_ac()` reflects chain shirt base AC |
| 5 | A goat spawns | Build runs | GoatCharge is present; goat behaviors fire normally |
| 6 | `GoblinMinion._setup_ability_from_settings()` is deleted | NPC goblin spawns | Ability is still randomly assigned via CharacterBuildComponent |
| 7 | Actor has no `FactionComponent` node | Build runs | No crash; faction step silently skipped |

---

## Migration Path

1. Implement `CharacterBuildComponent` and add it to `Actor._setup_components()`
2. Add pool/dice/faction keys to Goblin entry in `ActorTypeData`
3. Remove `_ready()` armor/weapon/ability/HP blocks from `GoblinMinion.gd`
4. Remove `_setup_ability_from_settings()` from `GoblinMinion.gd`
5. Remove goblin block from `AbilityComponent.setup()` *(already done)*
6. Verify acceptance criteria in a goblin arena session
7. Mark `GoblinMinion.gd` `@deprecated` — class_name stays until scene references are updated
8. Repeat for any future humanoid actor type that needs pool-based equipment
