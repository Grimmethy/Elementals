# ActorTypeData — Actor Registry & Equipment Compatibility

Central reference for `res://Components/ActorComponents/ActorTypeData.gd`. All actor default stats, equipment pools, and category mappings live here. See [CharacterSelectController.md](CharacterSelectController.md) for the UI/UX spec that consumes this data.

---

## 1. Equipment Compatibility

When an actor type is selected in the Actor Designer, available equipment dropdowns are filtered by category:

| Category | Available Weapons | Available Abilities | Available Armor |
|----------|-------------------|---------------------|-----------------|
| Aberration | Tentacles, Eye Rays, Bite | Psychic Blast, Antimagic Cone, Dominate | Natural Armor |
| Beast | Bite, Claw, Headbutt, Hoof Strike | Charge, Pack Tactics, Keen Smell | Fur, Hide, Feathers |
| Celestial | Hooves, Divine Strike, Slam | Healing Touch, Fly, Divine Aura | Celestial Hide, Holy Ward |
| Construct | Slam, Fist, Blade Arm | Self-Repair, Sentinel, Siege Strike | Plate, Stone Shell |
| Dragon | Claw, Bite, Tail Swipe | Dragon Breath, Fly, Roar, Frightful Presence | Dragon Scales |
| Elemental | Slam, Elemental Touch, Constrict | Elemental Form, Burrow, Elemental Aura | Elemental Skin |
| Fey | Shortsword, Bow, Thorn Whip | Invisibility, Charm, Blink, Enchant | Bark Armor, Fey Ward |
| Fiend | Claw, Bite, Whip, Trident | Fire Aura, Fear, Teleport, Corruption | Natural Armor, Fire Resistance |
| Giant | Greatclub, Rock Throw, Slam | Siege Monster, Tremor, Hurl | Hide, Thick Skin |
| Humanoid | Sword, Bow, Staff, Dagger, Spear | Varies by class | Leather, Scale Mail, Plate, Robes |
| Monstrosity | Claw, Bite, Gore, Constrict | Unique per type (Charge, Petrify, Lycanthropy) | Natural Armor, Hide |
| Ooze | Pseudopod, Engulf | Acid Splash, Dissolve, Split | Amorphous Body |
| Plant | Slam, Vine Whip, Root Strike | Entangle, Spore Burst, Regrowth | Bark Armor, Thorn Hide |
| Undead | Claw, Bite, Slam | Undead Fortitude, Life Drain, Paralyze | Tattered Armor, Bone Shell |

---

## 2. Architecture

Data is split across per-category files under `ActorTypes/`. `ActorTypeData.gd` preloads each file and merges all `DATA` dicts into a single `_types` dictionary on first access via `_ensure_init()`.

```gdscript
# ActorTypeData.gd (simplified)
class_name ActorTypeData
extends Resource

const _DragonData = preload("res://Components/ActorComponents/ActorTypes/DragonData.gd")
# ... one const per category file ...

static var _types: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
    if _initialized:
        return
    _types.merge(_DragonData.DATA)
    # ... one merge per category ...
    _initialized = true
```

### Entry Schema

Each entry in a category `DATA` dict maps an actor type name to its defaults. Stat values use **modifier notation**: `0.0` = baseline (ability score 10), `+1.0` per 2 points above 10, negative below.

```gdscript
"ActorName": {
    # Combat
    "max_health":    float,   # HealthComponent.max_health
    "armor_class":   int,     # ArmorClassComponent.armor_value
    "damage_amount": float,   # DamageComponent.damage_amount
    "element_type":  String,  # "none" | "fire" | "ice" | "storm" | "shadow"
    # Ability scores
    "strength":      float,
    "dexterity":     float,
    "constitution":  float,
    "intelligence":  float,
    "wisdom":        float,
    "charisma":      float,
    # Economy
    "gold_value":    int,
    # Equipment pools
    "weapons":       Array[String],
    "abilities":     Array[String],
    "armor":         Array[String],
},
```

---

## 3. Category Files

All data files live at `res://Components/ActorComponents/ActorTypes/`.

| Category | File | Entries | CR Range | Notes |
|----------|------|---------|----------|-------|
| Aberration | `AberrationData.gd` | — | — | |
| Beast | `BeastData.gd` | — | — | |
| Celestial | `CelestialData.gd` | — | — | |
| Construct | `ConstructData.gd` | — | — | |
| Dragon | `DragonData.gd` | 52 | ¼–30 | 4 game-specific + 48 5e; full chromatic/metallic set; Tiamat |
| Elemental | `ElementalData.gd` | 34 | ¼–23 | 2 game-specific + 32 5e; includes Myrmidons, Genies, Elder Elementals |
| Fey | `FeyData.gd` | 22 | ⅛–12 | Blights, Hags, Eladrin, Redcap, Korred |
| Fiend | `FiendData.gd` | 35 | ¼–20 | 11 Devils, 13 Demons, 4 Yugoloths, 7 other |
| Giant | `GiantData.gd` | 21 | 2–19 | Full troll variants; all giant types through Storm Giant Quintessent |
| Humanoid | `HumanoidData.gd` | 47 | ⅛–12 | 9 game-specific + 38 5e; includes extended Goblin fields |
| Monstrosity | `MonstrosityData.gd` | 50 | ½–30 | 6 game-specific + 44 5e; through Tarrasque |
| Ooze | `OozeData.gd` | 9 | ¼–23 | Oblex line, core oozes, Juiblex |
| Plant | `PlantData.gd` | 18 | 0–9 | 1 game-specific + 17 5e; Myconids, Blights, Treant |
| Undead | `UndeadData.gd` | 34 | 0–21 | 3 game-specific + 31 5e; shadow-typed incorporeals, Lich |

> **Game-specific entries** (e.g. Fireworm, Sandworm, Goblin with extended AI fields) may carry additional keys beyond the standard schema. Do not overwrite these entries when batch-adding 5e creatures.

---

## 4. Static Lookup Methods

```gdscript
# Returns the full defaults dict for an actor type, or {} if not found.
static func get_defaults(actor_type: String) -> Dictionary

# Returns all registered actor type names across all categories.
static func get_all_types() -> Array[String]

# Returns the category string for a given actor type ("Unknown" if not in CATEGORY_MAP).
static func get_category(actor_type: String) -> String

# Returns the list of actor type names in a given category.
static func get_types_in_category(category: String) -> Array

# Returns all category names from CATEGORY_MAP.
static func get_all_categories() -> Array[String]
```

### CATEGORY_MAP

`CATEGORY_MAP` is a `const Dictionary` keyed by category name. It drives `get_category()` and designer dropdowns. The full list lives in `ActorTypeData.gd`; categories with large populations are summarised here.

| Category | Count | Notable members |
|----------|-------|-----------------|
| Aberration | large | Beholder, Aboleth, Mind Flayer, Elder Brain, Slaads, Star Spawn… |
| Beast | large | Goat, Wolf, Dinosaurs, Giant animals, mundane creatures… |
| Celestial | medium | Couatl, Deva, Planetar, Solar, Unicorn, Ki-rin, Empyrean… |
| Construct | large | Golems (Clay→Iron), Modrons, Shield Guardian, Marut, Nimblewright… |
| Dragon | 52 | Pseudodragon → Tiamat; all chromatic & metallic wyrmling/young/adult/ancient |
| Elemental | 34 | Mephits, Core Elementals, Myrmidons, Genies, Phoenix, Leviathan, Elder Tempest |
| Fey | 22 | Pixie → Winter Eladrin; Blights, Hags, Redcap, Korred |
| Fiend | 35 | Lemure → Pit Fiend; Balor, Marilith, Rakshasa, Night Hag |
| Giant | 21 | Firbolg → Storm Giant Quintessent; all troll variants |
| Humanoid | 47 | Goblin → Archmage; Drow line, Yuan-ti, full caster/martial/monster humanoids |
| Monstrosity | 50 | Cockatrice → Tarrasque; Sphinxes, Kraken, Hydra, lycanthropes |
| Ooze | 9 | Oblex Spawn → Juiblex; Gray Ooze, Black Pudding, Gelatinous Cube |
| Plant | 18 | Shrieker → Treant; Myconids, Blights, Vegepygmies, Corpse Flower |
| Undead | 34 | Crawling Claw → Lich; Vampire line, Mummy Lord, Death Knight, Demilich |

---

## 5. Adding New Entries

To add creatures to an existing category:
1. Open the relevant `ActorTypes/XxxData.gd` file.
2. Append new entries inside `const DATA: Dictionary = { … }` before the closing `}`.
3. Add the new names to `CATEGORY_MAP["Category"]` in `ActorTypeData.gd`.

To add a **new category**:
1. Create `ActorTypes/XxxData.gd` with `const DATA: Dictionary = { … }`.
2. Add `const _XxxData = preload("res://Components/ActorComponents/ActorTypes/XxxData.gd")` to `ActorTypeData.gd`.
3. Add `_types.merge(_XxxData.DATA)` inside `_ensure_init()`.
4. Add the new key to `CATEGORY_MAP`.

> **Note on extended fields:** The Goblin entry in `HumanoidData.gd` carries game-specific keys (`should_bob`, `fixed_move_speed`, `ai_behaviors`, `faction`, `hp_dice_count`, etc.). Any code consuming `get_defaults()` for Goblin must handle these extra keys gracefully.
