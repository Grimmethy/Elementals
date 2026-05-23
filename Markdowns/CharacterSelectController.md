# Actor Designer Feature - Character Selection Redesign

## Overview

Replace the current card-based character selection with a new **Actor Designer** interface that allows players to **create and customize their own actor** through slider-based controls and a categorized dropdown selection.

---

## 1. Core Concept

The player can design their own actor by:
1. **Selecting an Actor Type** from a categorized dropdown (Aberration, Beast, Celestial, Construct, Dragon, Elemental, Fey, Fiend, Giant, Humanoid, Monstrosity, Ooze, Plant, Undead)
2. **Customizing attributes** via sliders (stats, appearance, abilities)
3. **Previewing the result** in real-time

---

## 2. Dropdown Structure

### Category Hierarchy

```
Actor Type (Root Dropdown)
├── Aberration
│   ├── Beholder
│   ├── Mind Flayer
│   ├── Nothic
│   └── Aboleth
├── Beast
│   ├── Goat
│   ├── Chicken
│   ├── Cow
│   ├── Pig
│   ├── Sheep
│   ├── Wolf
│   └── Earthworm
├── Celestial
│   ├── Unicorn
│   ├── Pegasus
│   └── Deva
├── Construct
│   ├── Scarecrow
│   ├── Iron Golem
│   └── Animated Armor
├── Dragon
│   ├── Fire Dragon
│   ├── Ice Dragon
│   ├── Storm Dragon
│   └── Shadow Dragon
├── Elemental
│   ├── Fire Elemental
│   ├── Water Elemental
│   ├── Earth Elemental
│   ├── Air Elemental
│   ├── Fireworm
│   ├── Iceworm
│   └── Salamander
├── Fey
│   ├── Pixie
│   ├── Sprite
│   ├── Satyr
│   └── Dryad
├── Fiend
│   ├── Imp
│   ├── Incubus
│   ├── Nightmare
│   └── Pit Fiend
├── Giant
│   ├── Ogre
│   ├── Troll
│   ├── Hill Giant
│   └── Frost Giant
├── Humanoid
│   ├── Farmer
│   ├── Knight
│   ├── Mage
│   ├── Ranger
│   ├── Goblin
│   ├── Kobold
│   ├── Orc
│   ├── Gnoll
│   └── Bugbear
├── Monstrosity
│   ├── Mimic
│   ├── Minotaur
│   ├── Basilisk
│   ├── Medusa
│   ├── Werewolf
│   ├── Sandworm
│   ├── Manticore
│   └── Chimera
├── Ooze
│   ├── Ochre Jelly
│   ├── Gelatinous Cube
│   └── Black Pudding
├── Plant
│   ├── Mushroom
│   ├── Treant
│   └── Vine Blight
└── Undead
	├── Skeleton
	├── Zombie
	├── Ghoul
	├── Wraith
	├── Vampire
	└── Lich
```

### Implementation Notes
- Use Godot's `OptionButton` with sub-items via `PopupMenu` hierarchy
- Categories are non-selectable (label only), sub-items are the actual choices
- Alternatively, a two-dropdown system: Category → Specific Type

---

## 3. Slider Categories

### 3.1 Base Stats
| Slider | Range | Default | Description |
|--------|-------|---------|-------------|
| Health | 1-20 | 10 | Hit points |
| Armor Class | 5-20 | 10 | Base defense |
| Strength | 1-20 | 10 | Physical damage |
| Dexterity | 1-20 | 10 | Speed, evasion |
| Constitution | 1-20 | 10 | Stamina, HP growth |
| Intelligence | 1-20 | 10 | Magic power |
| Wisdom | 1-20 | 10 | Perception, spells |
| Charisma | 1-20 | 10 | Persuasion, buffs |

### 3.2 Physical Attributes
| Slider | Range | Default | Description |
|--------|-------|---------|-------------|
| Size | 0.5-3.0 | 1.0 | Scale multiplier |
| Speed | 50-300 | 100 | Movement speed |
| Stealth | 0-20 | 10 | Stealth modifier |

### 3.3 Visual Preview
| Control | Description |
|---------|-------------|
| Color Picker | Primary body color |
| Color Picker | Secondary/accent color |
| Scale Slider | Visual size preview |

---

## 4. UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ACTOR DESIGNER                                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Category Dropdown ▼]  [Actor Type Dropdown ▼]      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────┐  ┌────────────────────────────┐  │
│  │                      │  │  BASE STATS                │  │
│  │    ACTOR PREVIEW     │  │  ├─ Health     [====--] 12 │  │
│  │    (Sprite/Model)    │  │  ├─ Armor Class [===---] 8  │  │
│  │                      │  │  ├─ Strength   [==----] 5  │  │
│  │    [Name Input]      │  │  └─ ...                    │  │
│  │                      │  ├────────────────────────────┤  │
│  └──────────────────────┘  │  PHYSICAL ATTRIBUTES        │  │
│                            │  ├─ Size     [====---] 1.0  │  │
│  ┌──────────────────────┐  │  ├─ Speed    [=====--] 120  │  │
│  │  WEAPON SELECTION    │  │  └─ Stealth  [======-] 14  │  │
│  │  ○ Melee  ○ Ranged   │  ├────────────────────────────┤  │
│  │  [Dropdown of weapons]│  │  EQUIPMENT                 │  │
│  └──────────────────────┘  │  ├─ Weapon   [▼ Dagger  ] │  │
│                            │  ├─ Ability  [▼ Fireball] │  │
│  ┌──────────────────────┐  │  └─ Armor    [▼ Leather ] │  │
│  │  ABILITY SELECTION    │  └────────────────────────────┘  │
│  │  [Available abilities]│                                   │
│  └──────────────────────┘                                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  [Randomize]        [Reset Defaults]    [Confirm ✓] │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Component Inventory

### 5.1 ActorTypeDropdown
- **Type**: Custom Control (extends `Control`)
- **Purpose**: Two-level dropdown (Category → Type)
- **Signals**:
  - `actor_type_changed(category: String, actor_type: String)`
- **States**: Default, Hover, Open (menu visible), Disabled

### 5.2 StatSlider
- **Type**: Custom Control (extends `HSlider`)
- **Purpose**: Single stat adjustment with label and value display
- **Properties**: min, max, default, step
- **States**: Default, Dragging, Disabled

### 5.3 ActorPreviewPanel
- **Type**: Custom Control (extends `Control`)
- **Purpose**: Display actor sprite with real-time updates
- **Features**: Color tinting, scale adjustment, animation preview

### 5.4 ActorDesigner (Main Container)
- **Type**: Scene (`res://UI/ActorDesigner.tscn`)
- **Purpose**: Orchestrates all sub-components
- **Manages**: State validation, equipment compatibility, final output

---

## 6. Equipment Compatibility

When an actor type is selected, available equipment should be filtered:

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

## 7. Data Flow

```
User Input (Sliders/Dropdowns)
         │
         ▼
   ActorDesigner.gd
         │
    ┌────┴────┐
    ▼         ▼
[Validation] [Preview Update]
    │         │
    └────┬────┘
         ▼
   GameSettings.gd (save actor config)
         │
         ▼
   Arena.tscn (spawn actor with config)
```

---

## 8. File Structure

```
res://UI/
├── ActorDesigner.tscn              # Main scene
├── ActorDesigner.gd               # Main controller script
├── components/
│   ├── ActorTypeDropdown.gd       # Category → Type selector
│   ├── StatSlider.gd              # Single stat slider control
│   └── ActorPreviewPanel.gd       # Sprite preview with tint/scale
├── actor_data/
│   ├── ActorTypeData.gd           # Data class for actor definitions
│   └── equipment_compatibility.gd # Equipment lookup tables
```

---

## 9. Migration Strategy

### Phase 1: New System
1. Create `ActorDesigner.tscn` as a standalone scene
2. Create `ActorDesigner.gd` with the main controller logic
3. Create `ActorTypeData.gd` for actor definitions
4. Create `StatSlider.gd` as a reusable component

### Phase 2: Integration
1. Replace `MainMenu.tscn` character selection with `ActorDesigner`
2. Update `GameSettings.gd` to store new actor config format
3. Update `ActorFactory` to build actors from new config

### Phase 3: Cleanup
1. Remove `CharacterSelectCard.tscn` (legacy)
2. Remove `CharacterSelectCard.gd` (legacy)
3. Update `MainMenu.gd` to remove old card population code

---

## 10. Acceptance Criteria

- [ ] Category dropdown displays all 14 categories (Aberration, Beast, Celestial, Construct, Dragon, Elemental, Fey, Fiend, Giant, Humanoid, Monstrosity, Ooze, Plant, Undead)
- [ ] Selecting a category filters the Type dropdown to relevant actors
- [ ] All 8 base stat sliders are functional with correct ranges
- [ ] Physical attribute sliders (Size, Speed, Stealth) work correctly
- [ ] Actor preview updates in real-time when sliders change
- [ ] Equipment dropdowns are filtered based on actor type
- [ ] "Confirm" button saves configuration and proceeds to arena
- [ ] "Randomize" button generates random values within reasonable bounds
- [ ] "Reset Defaults" restores all sliders to actor type defaults
- [ ] Configuration persists via `GameSettings.gd`

---

## 11. ActorTypeData.gd — Dictionary Spec

### 11.1 Purpose

Replaces the per-actor `_init()` stat blocks in `GoatData.gd`, `GoblinData.gd`, `MimicData.gd`, `MushroomData.gd`, etc. with a single centralized dictionary. Adding a new actor type becomes one dictionary entry instead of a new script.

### 11.2 Schema

Each entry maps an actor type name to its defaults. Stat values use the existing modifier notation: `0.0` = baseline, positive = bonus, negative = penalty.

```gdscript
# res://UI/actor_data/ActorTypeData.gd
class_name ActorTypeData
extends Resource

const ACTOR_TYPES: Dictionary = {
    "ActorName": {
        # Combat
        "max_health":    float,   # HealthComponent.max_health
        "armor_class":   int,     # ArmorClassComponent.armor_value
        "damage_amount": float,   # DamageComponent.damage_amount
        "element_type":  String,  # DamageComponent.element_type ("none","fire","ice","shadow","storm")
        # Ability scores (AbilityScoresComponent / ActorData)
        "strength":      float,
        "dexterity":     float,
        "constitution":  float,
        "intelligence":  float,
        "wisdom":        float,
        "charisma":      float,
        # Economy
        "gold_value":    int,
        # Equipment pools (filtered by ActorDesigner dropdowns)
        "weapons":       Array[String],
        "abilities":     Array[String],
        "armor":         Array[String],
    },
}
```

### 11.3 Populated Dictionary

#### Beast

```gdscript
"Goat":    { "max_health": 10, "armor_class": 10, "damage_amount": 1.0, "element_type": "none",
             "strength": 1.0, "dexterity": 1.0, "constitution": 0.0, "intelligence": -4.0, "wisdom": 0.0, "charisma": -3.0,
             "gold_value": 50, "weapons": ["Headbutt","Horn Attack","Hoof Strike"], "abilities": ["Charge","Buck"], "armor": ["Fur","Hide"] },

"Chicken": { "max_health": 4,  "armor_class": 8,  "damage_amount": 0.5, "element_type": "none",
             "strength": -3.0, "dexterity": 2.0, "constitution": -1.0, "intelligence": -4.0, "wisdom": 0.0, "charisma": -2.0,
             "gold_value": 10, "weapons": ["Peck","Talon Scratch"],       "abilities": ["Flee","Cluck Aura"],   "armor": ["Feathers"] },

"Cow":     { "max_health": 15, "armor_class": 10, "damage_amount": 1.5, "element_type": "none",
             "strength": 2.0, "dexterity": -1.0, "constitution": 2.0,  "intelligence": -4.0, "wisdom": 0.0, "charisma": -2.0,
             "gold_value": 40, "weapons": ["Headbutt","Gore"],            "abilities": ["Stampede","Moo"],      "armor": ["Hide"] },

"Pig":     { "max_health": 11, "armor_class": 9,  "damage_amount": 1.0, "element_type": "none",
             "strength": 1.0, "dexterity": 0.0,  "constitution": 1.0,  "intelligence": -2.0, "wisdom": -1.0, "charisma": -2.0,
             "gold_value": 30, "weapons": ["Bite","Tusk Slam"],           "abilities": ["Root","Mudroll"],      "armor": ["Hide"] },

"Sheep":   { "max_health": 8,  "armor_class": 9,  "damage_amount": 0.5, "element_type": "none",
             "strength": 0.0, "dexterity": 1.0,  "constitution": 0.0,  "intelligence": -4.0, "wisdom": -1.0, "charisma": -1.0,
             "gold_value": 20, "weapons": ["Headbutt","Hoof Strike"],     "abilities": ["Herd Mentality"],      "armor": ["Wool","Fleece"] },

"Wolf":      { "max_health": 11, "armor_class": 13, "damage_amount": 2.0, "element_type": "none",
               "strength": 2.0, "dexterity": 2.0, "constitution": 1.0, "intelligence": -2.0, "wisdom": 1.0, "charisma": -1.0,
               "gold_value": 60, "weapons": ["Bite","Claw"],             "abilities": ["Pack Tactics","Howl"], "armor": ["Fur"] },

"Earthworm": { "max_health": 8,  "armor_class": 9,  "damage_amount": 0.5, "element_type": "none",
               "strength": 0.0, "dexterity": -1.0, "constitution": 1.0, "intelligence": -5.0, "wisdom": -3.0, "charisma": -4.0,
               "gold_value": 5,  "weapons": ["Constrict"],               "abilities": ["Burrow"],             "armor": ["Slime Coat"] },
```

#### Aberration

```gdscript
"Beholder":    { "max_health": 180, "armor_class": 18, "damage_amount": 4.0, "element_type": "none",
                 "strength": 2.0, "dexterity": 2.0, "constitution": 4.0, "intelligence": 5.0, "wisdom": 2.0, "charisma": 3.0,
                 "gold_value": 500, "weapons": ["Eye Rays","Bite"],          "abilities": ["Eye Rays","Antimagic Cone"],    "armor": ["Natural Armor"] },
```

#### Construct

```gdscript
"Scarecrow": { "max_health": 36, "armor_class": 11, "damage_amount": 2.0, "element_type": "none",
               "strength": 1.0, "dexterity": 1.0, "constitution": 0.0, "intelligence": -3.0, "wisdom": -2.0, "charisma": -3.0,
               "gold_value": 45, "weapons": ["Claw","Slam"],                   "abilities": ["Horrifying Visage","Scare"],  "armor": ["Natural Armor"] },
```

#### Dragon

```gdscript
"Fire Dragon":   { "max_health": 256, "armor_class": 19, "damage_amount": 6.0, "element_type": "fire",
                   "strength": 9.0, "dexterity": 0.0, "constitution": 5.0, "intelligence": 4.0, "wisdom": 1.0, "charisma": 4.0,
                   "gold_value": 600, "weapons": ["Claw","Bite","Tail Swipe"], "abilities": ["Fire Breath","Fly","Roar"],         "armor": ["Dragon Scales"] },

"Ice Dragon":    { "max_health": 225, "armor_class": 18, "damage_amount": 5.5, "element_type": "ice",
                   "strength": 8.0, "dexterity": 0.0, "constitution": 4.0, "intelligence": 4.0, "wisdom": 1.0, "charisma": 3.0,
                   "gold_value": 580, "weapons": ["Claw","Bite","Tail Swipe"], "abilities": ["Frost Breath","Fly","Roar"],        "armor": ["Dragon Scales"] },

"Storm Dragon":  { "max_health": 243, "armor_class": 19, "damage_amount": 6.0, "element_type": "storm",
                   "strength": 8.0, "dexterity": 1.0, "constitution": 5.0, "intelligence": 4.0, "wisdom": 2.0, "charisma": 4.0,
                   "gold_value": 620, "weapons": ["Claw","Bite","Tail Swipe"], "abilities": ["Lightning Breath","Fly","Roar"],    "armor": ["Dragon Scales"] },

"Shadow Dragon": { "max_health": 189, "armor_class": 19, "damage_amount": 5.0, "element_type": "shadow",
                   "strength": 7.0, "dexterity": 2.0, "constitution": 4.0, "intelligence": 4.0, "wisdom": 1.0, "charisma": 5.0,
                   "gold_value": 650, "weapons": ["Claw","Bite","Tail Swipe"], "abilities": ["Shadow Breath","Fly","Living Shadow"], "armor": ["Dragon Scales"] },
```

#### Elemental

```gdscript
"Fireworm":  { "max_health": 22, "armor_class": 12, "damage_amount": 2.5, "element_type": "fire",
               "strength": 1.0, "dexterity": 0.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
               "gold_value": 55, "weapons": ["Flame Bite","Constrict"],    "abilities": ["Acid Spit","Burrow"],    "armor": ["Fire Scales"] },

"Iceworm":   { "max_health": 22, "armor_class": 12, "damage_amount": 2.5, "element_type": "ice",
               "strength": 1.0, "dexterity": 0.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
               "gold_value": 55, "weapons": ["Frost Bite","Constrict"],    "abilities": ["Freeze Spit","Burrow"],  "armor": ["Ice Scales"] },
```

#### Giant

```gdscript
"Ogre":  { "max_health": 59, "armor_class": 11, "damage_amount": 4.0, "element_type": "none",
           "strength": 5.0, "dexterity": -1.0, "constitution": 3.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
           "gold_value": 90, "weapons": ["Greatclub","Javelin"],  "abilities": ["Siege Monster"],            "armor": ["Natural Armor"] },

"Troll": { "max_health": 84, "armor_class": 15, "damage_amount": 3.5, "element_type": "none",
           "strength": 4.0, "dexterity": 1.0,  "constitution": 5.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -4.0,
           "gold_value": 130, "weapons": ["Claw","Bite"],          "abilities": ["Regeneration","Keen Smell"], "armor": ["Natural Armor"] },
```

#### Humanoid

```gdscript
"Farmer":  { "max_health": 8,  "armor_class": 10, "damage_amount": 1.0, "element_type": "none",
             "strength": 0.0, "dexterity": 0.0, "constitution": 0.0, "intelligence": 0.0, "wisdom": 0.0, "charisma": 0.0,
             "gold_value": 15, "weapons": ["Pitchfork","Scythe"],       "abilities": ["Hard Work"],                        "armor": ["Cloth"] },

"Knight":  { "max_health": 52, "armor_class": 18, "damage_amount": 3.0, "element_type": "none",
             "strength": 3.0, "dexterity": 0.0, "constitution": 2.0, "intelligence": 0.0, "wisdom": 0.0, "charisma": 1.0,
             "gold_value": 120, "weapons": ["Longsword","Lance"],       "abilities": ["Parry","Rally"],                    "armor": ["Plate","Shield"] },

"Mage":    { "max_health": 18, "armor_class": 12, "damage_amount": 4.0, "element_type": "none",
             "strength": -1.0, "dexterity": 2.0, "constitution": 0.0, "intelligence": 5.0, "wisdom": 1.0, "charisma": 0.0,
             "gold_value": 100, "weapons": ["Staff","Dagger"],          "abilities": ["Fireball","Shield","Magic Missile"], "armor": ["Robes"] },

"Ranger":  { "max_health": 33, "armor_class": 15, "damage_amount": 2.5, "element_type": "none",
             "strength": 1.0, "dexterity": 3.0, "constitution": 1.0, "intelligence": 0.0, "wisdom": 1.0, "charisma": 0.0,
			 "gold_value": 80, "weapons": ["Longbow","Shortsword"],     "abilities": ["Hunter's Mark","Favored Enemy"],    "armor": ["Leather","Scale Mail"] },

"Goblin":  { "max_health": 7,  "armor_class": 15, "damage_amount": 1.5, "element_type": "none",
			 "strength": -1.0, "dexterity": 2.5, "constitution": 0.0, "intelligence": 0.0, "wisdom": -1.0, "charisma": -1.0,
			 "gold_value": 65, "weapons": ["Scimitar","Shortbow"],      "abilities": ["Nimble Escape"],                    "armor": ["Leather","Shield"] },

"Kobold":  { "max_health": 5,  "armor_class": 12, "damage_amount": 1.0, "element_type": "none",
			 "strength": -3.0, "dexterity": 2.0, "constitution": -1.0, "intelligence": -1.0, "wisdom": -2.0, "charisma": -2.0,
			 "gold_value": 25, "weapons": ["Dagger","Sling"],           "abilities": ["Pack Tactics","Sunlight Sensitivity"], "armor": ["Leather"] },

"Orc":     { "max_health": 15, "armor_class": 13, "damage_amount": 2.5, "element_type": "none",
			 "strength": 3.0, "dexterity": 1.0, "constitution": 3.0, "intelligence": -2.0, "wisdom": -1.0, "charisma": -1.0,
			 "gold_value": 55, "weapons": ["Greataxe","Javelin"],       "abilities": ["Aggressive","Relentless"],          "armor": ["Hide","Shield"] },

"Gnoll":   { "max_health": 22, "armor_class": 15, "damage_amount": 2.0, "element_type": "none",
			 "strength": 2.0, "dexterity": 1.0, "constitution": 0.0, "intelligence": -2.0, "wisdom": 0.0, "charisma": -2.0,
			 "gold_value": 50, "weapons": ["Bite","Spear"],             "abilities": ["Rampage"],                          "armor": ["Hide","Shield"] },

"Bugbear": { "max_health": 27, "armor_class": 16, "damage_amount": 3.0, "element_type": "none",
			 "strength": 3.0, "dexterity": 2.0, "constitution": 1.0, "intelligence": -1.0, "wisdom": 0.0, "charisma": -1.0,
			 "gold_value": 70, "weapons": ["Morningstar","Javelin"],    "abilities": ["Brute","Surprise Attack"],          "armor": ["Hide","Shield"] },
```

#### Monstrosity

```gdscript
"Mimic":    { "max_health": 58,  "armor_class": 12, "damage_amount": 3.0, "element_type": "none",
			  "strength": 3.0,  "dexterity": 1.0, "constitution": 2.0, "intelligence": -3.0, "wisdom": 1.0, "charisma": -1.0,
			  "gold_value": 80,  "weapons": ["Pseudopod","Bite"],       "abilities": ["False Appearance","Adhesive"],     "armor": ["Natural Armor"] },

"Minotaur": { "max_health": 76,  "armor_class": 14, "damage_amount": 4.0, "element_type": "none",
			  "strength": 5.0,  "dexterity": 0.0, "constitution": 3.0, "intelligence": -3.0, "wisdom": 0.0, "charisma": -2.0,
			  "gold_value": 120, "weapons": ["Greataxe","Gore"],        "abilities": ["Charge","Labyrinthine Recall"],    "armor": ["Natural Armor"] },

"Basilisk": { "max_health": 52,  "armor_class": 15, "damage_amount": 2.5, "element_type": "none",
			  "strength": 2.0,  "dexterity": -1.0, "constitution": 3.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
			  "gold_value": 100, "weapons": ["Bite"],                   "abilities": ["Petrifying Gaze"],                 "armor": ["Natural Armor"] },

"Medusa":   { "max_health": 127, "armor_class": 15, "damage_amount": 3.0, "element_type": "none",
			  "strength": 0.0,  "dexterity": 2.0, "constitution": 3.0, "intelligence": 2.0, "wisdom": -1.0, "charisma": 1.0,
			  "gold_value": 200, "weapons": ["Shortsword","Longbow"],   "abilities": ["Petrifying Gaze","Snake Hair"],    "armor": ["Natural Armor"] },

"Werewolf": { "max_health": 58,  "armor_class": 12, "damage_amount": 2.5, "element_type": "none",
			  "strength": 3.0,  "dexterity": 1.0, "constitution": 2.0, "intelligence": 0.0, "wisdom": 1.0, "charisma": 0.0,
			  "gold_value": 110, "weapons": ["Claw","Bite"],            "abilities": ["Lycanthropy","Pack Tactics"],      "armor": ["Natural Armor"] },

"Sandworm": { "max_health": 247, "armor_class": 18, "damage_amount": 6.0, "element_type": "none",
			  "strength": 8.0,  "dexterity": -1.0, "constitution": 5.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
			  "gold_value": 400, "weapons": ["Bite","Swallow"],         "abilities": ["Tunneler","Tremorsense"],          "armor": ["Hardened Hide"] },
```

#### Plant

```gdscript
"Mushroom": { "max_health": 15, "armor_class": 10, "damage_amount": 1.0, "element_type": "none",
			  "strength": 1.0, "dexterity": -1.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": 0.0, "charisma": -3.0,
			  "gold_value": 35, "weapons": ["Spore Burst","Root Slam"], "abilities": ["Poison Spores","Regrowth"],        "armor": ["Natural Armor"] },
```

#### Undead

```gdscript
"Skeleton": { "max_health": 13, "armor_class": 13, "damage_amount": 1.5, "element_type": "none",
			  "strength": 0.0, "dexterity": 2.0, "constitution": -1.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
			  "gold_value": 30, "weapons": ["Shortsword","Shortbow"],   "abilities": ["Undead Fortitude"],                "armor": ["Armor Scraps"] },

"Zombie":   { "max_health": 22, "armor_class": 8,  "damage_amount": 2.0, "element_type": "none",
			  "strength": 1.0, "dexterity": -2.0, "constitution": 3.0, "intelligence": -5.0, "wisdom": -4.0, "charisma": -4.0,
			  "gold_value": 25, "weapons": ["Slam"],                    "abilities": ["Undead Fortitude"],                "armor": ["Tattered Cloth"] },

"Ghoul":    { "max_health": 22, "armor_class": 12, "damage_amount": 2.0, "element_type": "none",
			  "strength": 1.0, "dexterity": 2.0, "constitution": 0.0, "intelligence": -2.0, "wisdom": 0.0, "charisma": -3.0,
			  "gold_value": 60, "weapons": ["Claws","Bite"],            "abilities": ["Paralyzing Touch","Undead Fortitude"], "armor": ["Natural Armor"] },
```

### 11.4 Static Lookup Methods

```gdscript
static func get_defaults(actor_type: String) -> Dictionary:
    return ACTOR_TYPES.get(actor_type, {})

static func get_all_types() -> Array[String]:
    return ACTOR_TYPES.keys()

static func get_category(actor_type: String) -> String:
    for category in CATEGORY_MAP:
        if actor_type in CATEGORY_MAP[category]:
            return category
	return "Unknown"

const CATEGORY_MAP: Dictionary = {
	"Aberration": ["Beholder"],
	"Beast":      ["Goat","Chicken","Cow","Pig","Sheep","Wolf","Earthworm"],
	"Celestial":  [],
	"Construct":  ["Scarecrow"],
	"Dragon":     ["Fire Dragon","Ice Dragon","Storm Dragon","Shadow Dragon"],
	"Elemental":  ["Fireworm","Iceworm"],
	"Fey":        [],
	"Fiend":      [],
	"Giant":      ["Ogre","Troll"],
	"Humanoid":   ["Farmer","Knight","Mage","Ranger","Goblin","Kobold","Orc","Gnoll","Bugbear"],
	"Monstrosity":["Mimic","Minotaur","Basilisk","Medusa","Werewolf","Sandworm"],
	"Ooze":       [],
	"Plant":      ["Mushroom"],
	"Undead":     ["Skeleton","Zombie","Ghoul"],
}
```

### 11.5 Migration Path

To replace an existing per-actor script with a dictionary lookup:

1. Delete the stat assignments from `_init()` in `GoatData.gd`, `GoblinData.gd`, etc.
2. In `ActorData.gd` base `_init()`, call `ActorTypeData.get_defaults(type_name)` and apply the values.
3. Keep per-actor scripts only for properties unique to that type (genome, `mimic_blood`, `horn_type`, etc.) — anything that isn't a shared stat.

---

## 12. Open Questions

1. **Default Actor**: Should a default actor be pre-selected, or start with a "Choose Type" prompt?
2. **Slider Precision**: Show integer values only, or allow decimals for Size/Speed?
3. **Preview Quality**: Should the preview be a static sprite, or an animated representation?
4. **Equipment Restrictions**: Strict compatibility (some items locked) or soft compatibility (warnings)?
5. **Custom Names**: Allow players to name their created actor?
6. **Color Options**: Limited palette or full color picker?