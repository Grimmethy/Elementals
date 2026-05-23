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

Equipment pools are filtered per category when an actor type is selected. See [ActorTypeData.md](ActorTypeData.md) for the full table and per-actor weapon/ability/armor lists.

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

## 11. Open Questions

1. **Default Actor**: Should a default actor be pre-selected, or start with a "Choose Type" prompt?
2. **Slider Precision**: Show integer values only, or allow decimals for Size/Speed?
3. **Preview Quality**: Should the preview be a static sprite, or an animated representation?
4. **Equipment Restrictions**: Strict compatibility (some items locked) or soft compatibility (warnings)?
5. **Custom Names**: Allow players to name their created actor?
6. **Color Options**: Limited palette or full color picker?