# Actor System Reference Guide

<!--
================================================================================
VERSION CONTROL
================================================================================
Document Version: 1.2
Last Synced:     2026-05-23
Godot Version:   4.2+

SYNC RULE: When modifying actor structure (add/remove/modify components,
signals, properties, methods, or AI states), update this document in the
same commit. Keep version numbers in sync across files.

VERSION LOG:
  v1.0 (2025-01-09) - Initial documentation
  v1.1 (2025-01-10) - Updated file paths to reflect directory restructuring
  v1.2 (2026-05-23) - Corrected base type (CharacterBody3D); rewrote properties,
					  signals, and methods to match current Actor.gd; added Stats
					  Data Layer section documenting ActorData/_data bridge,
					  ActorTypeData registry, _apply_type_defaults(), and
					  _on_data_changed_impl() override pattern; added MimicActor
					  and MushroomActor to derived actors; updated GoblinMinion
					  to reflect _data wiring and move speed override; updated
					  file structure to include ActorTypeData.gd and
					  BreedingComponents/.
================================================================================
-->

## Overview

Actors are every living thing in Elementals — the goats you breed and fight with, the goblins defending the arena, the elemental creatures lurking in the world. From the player's perspective, each actor is a character with personality expressed through stats: a high-dex goat darts across the battlefield, a high-strength goblin hits harder. The Actor system is the backbone that makes every creature feel distinct and reactive without requiring bespoke code for each type.

The Actor system is a modular, component-based architecture for game entities. It uses a **Finite State Machine (FSM)** for AI behavior, a **Component pattern** for extensibility, and a **Data Layer** (`ActorData` resource + `ActorTypeData` registry) to drive spawn-time stats and persist per-actor stat evolution through breeding. Supports both player-controlled and AI-controlled actors.

---

## Player Fantasy

**Playing with actors** feels like commanding a team of creatures with real personalities. Your bred goat has a name, a stat history, and a charge that hits harder because *you* raised it. Enemy goblins feel like threats with distinct behaviors — one flees when hurt, another calls for help. The player should feel the difference between a freshly spawned minion and a veteran creature without reading a stat sheet.

**Creating a new actor type** should feel empowering, not boilerplate-heavy. The data bridge and component system mean a designer can wire up a new creature in one file and immediately get working movement, health, AI, and stat scaling.

**Watching actors die** should feel meaningful — a dramatic fall, a `died` signal that the rest of the world reacts to, not an entity that just disappears.

---

## Architecture Diagram

```
Actor (CharacterBody3D)
├── _data: ActorData              - Per-actor stat resource (strength, dex, etc.)
│   └── sourced from ActorTypeData registry at spawn time
├── Components (res://Components/ActorComponents/)
│   ├── HealthComponent           - HP, death events, damage routing
│   ├── MovementComponent         - Move speed, acceleration
│   ├── AbilityScoresComponent    - Strength, dex, con, int, wis, cha modifiers
│   ├── ArmorClassComponent       - AC calculation, equipped armor
│   ├── AbilityComponent          - Special actions and cooldowns
│   ├── WeaponComponent           - Equipped weapon + attack dispatch
│   ├── ManaComponent             - Mana pool
│   ├── StunComponent             - Stun duration tracking
│   ├── FactionComponent          - Faction relationships
│   ├── DetectionComponent        - Actor perception / visibility
│   ├── StatusEffectComponent     - Burning, poison, etc.
│   ├── CommunicationComponent    - Voice lines, broadcast signals
│   ├── TerrainSpeedModifierComponent - Speed multipliers by tile type
│   ├── SkillCheckComponent       - Lockpicking, persuasion, etc.
│   ├── ActorTileInteractionComponent - Hex tile tracking
│   ├── ActorTileNavigationComponent  - Pathfinding
│   ├── ActorVisualComponent      - Sprite direction, flash effects
│   ├── ActorParticleComponent    - Mana/hit particles
│   ├── BobComponent              - Idle float animation
│   └── ProjectileComponent       - Projectile firing
├── ActorAIController             - Manages AI state machine
└── AI States (res://src/actors/ai/states/)
    ├── AIIdleState
    ├── AIChaseState
    ├── AIAttackState
    └── (more states...)
```

---

## Stats Data Layer

This is the core of how actor stats work. Read this before touching any stat-related code.

### Three-layer architecture

```
ActorTypeData (registry)
    └── spawn-time defaults only — consulted once, never again
ActorData subclass (resource, per-actor instance)
    └── live stats — owned by the actor, mutated by breeding/levelling
Actor._data (property on the node)
    └── bridge — _on_data_changed() pushes resource stats → components
```

### ActorTypeData

**File:** `res://Components/ActorComponents/ActorTypeData.gd`

A static registry (`const ACTOR_TYPES: Dictionary`) of every species' default ability scores, gold value, and equipment pools. Used **only at spawn time** to initialize a fresh `ActorData` instance.

```gdscript
ActorTypeData.get_defaults("Goblin")   # -> Dictionary of stat defaults
ActorTypeData.get_category("Goblin")   # -> "Humanoid"
ActorTypeData.get_all_types()          # -> Array[String] of all registered names
ActorTypeData.get_types_in_category("Dragon")  # -> ["Fire Dragon", "Ice Dragon", ...]
```

### ActorData and subclasses

**File:** `res://Components/ActorComponents/ActorData.gd`
**Subclasses:** `res://Components/BreedingComponents/`

`ActorData` is a `Resource` subclass that stores the **live, per-actor** stat values. After spawn, these values are owned by the individual actor and evolve independently (via breeding crossover, levelling, etc.). `ActorTypeData` is never consulted again.

Each species subclass calls `_apply_type_defaults("TypeName")` in `_init()` to seed from the registry:

```gdscript
# In GoatData._init():
func _init() -> void:
	_apply_type_defaults("Goat")   # reads ActorTypeData once
	if render_seed == 0:
		render_seed = randi()
	goat_name = ActorData.generate_name_from_seed(render_seed)
```

**`_apply_type_defaults(type_name: String)`** — defined on `ActorData`. Applies `strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, `charisma` from the registry onto `self`. Only the six ability scores; component-level stats (`max_health`, `armor_class`, etc.) are set by the actor node, not the resource.

### The _data bridge

`Actor` exposes `@export var _data: ActorData`. When assigned, its setter connects `stats_changed` → `_on_data_changed()`, which pushes the resource stats into `ability_scores_component`:

```gdscript
func _on_data_changed() -> void:
	ability_scores_component.strength     = _data.strength
	ability_scores_component.dexterity    = _data.dexterity
	ability_scores_component.constitution = _data.constitution
	ability_scores_component.intelligence = _data.intelligence
	ability_scores_component.wisdom       = _data.wisdom
	ability_scores_component.charisma     = _data.charisma
	move_speed = 3.0 * _data.dexterity    # dex scales move speed (see note below)
	_on_data_changed_impl()               # override hook for subclasses
```

**Move speed note:** The dexterity scaling (`move_speed = 3.0 * dex`) is intentional for GoatActor — bred goats with higher dex move faster in the arena. Actor subclasses that need a fixed move speed must override `_on_data_changed_impl()` and reset it there (see GoblinMinion).

### _on_data_changed_impl()

Override hook called at the end of `_on_data_changed()`. Use this in Actor subclasses to react to stat changes — computing derived values, updating visuals, fixing move speed, etc. — without overriding the full sync logic.

```gdscript
# Example: GoatActor
func _on_data_changed_impl() -> void:
	charge_speed = 25.0 + (5.0 * ability_scores_component.strength)
	charge_distance = 5.0 + (1.0 * ability_scores_component.strength)

# Example: GoblinMinion (pins move speed regardless of dex)
func _on_data_changed_impl() -> void:
	move_speed = 3.0
```

### Wiring _data in a new actor type

```gdscript
func _ready() -> void:
	_data = GoblinData.new()   # set BEFORE super._ready() so the bridge fires
	super._ready()             # calls _setup_components() then _on_data_changed()
```

Set `_data` before `super._ready()`. `Actor._ready()` calls `_setup_components()` first, then checks if `_data` is set and calls `_on_data_changed()` — so the components exist when the stats are applied.

---

## Core: Actor.gd

**Type:** `CharacterBody3D`
**File:** `res://src/actors/base/Actor.gd`

The base class for all game actors.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `is_playable` | bool | `true` | Whether this actor is player-controlled |
| `element_type` | String | `"none"` | Element tag used for damage type routing |
| `actor_size` | Size | `MEDIUM` | `SMALL / MEDIUM / LARGE` enum |
| `_data` | ActorData | `null` | Per-actor stat resource; assignment triggers component sync |
| `move_speed` | float | `3.0` | Movement speed in world units; forwarded to MovementComponent |
| `max_hp` | float | `10.0` | Max health; forwarded to HealthComponent |
| `max_mana` | float | `100.0` | Max mana; forwarded to ManaComponent |
| `armor_class` | int | `10` | Base AC; forwarded to HealthComponent |
| `is_controlled` | bool | `false` | Whether a player is currently controlling this actor |
| `is_dead` | bool | `false` | Set true by `die()`; gates physics and component processing |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `died` | — | Emitted when health reaches 0 |
| `resurrected` | — | Emitted when actor is brought back from dead |
| `mana_changed` | `new_mana: float, max_mana: float` | Emitted by ManaComponent |
| `tile_changed` | `new_tile: HexTileData` | Emitted when actor moves to a new hex tile |

### Key Methods

```gdscript
func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void
```
Routes damage through `AbilityComponent` (disengage check) then `HealthComponent`. Triggers `_on_damage_taken()` on abilities.

```gdscript
func die() -> void
```
Sets `is_dead`, triggers fall-over visual, disables all living components, emits `died` and `GameEvents.actor_died`.

```gdscript
func resurrect() -> void
```
Reverses `die()` — re-enables components, resets health, emits `resurrected`.

```gdscript
func stun(duration: float) -> void
```
Delegates to `StunComponent`.

```gdscript
func register_tick(callback: Callable, interval: float = 0.1) -> int
func unregister_tick(id: int) -> void
```
Register/unregister callbacks on the centralized `GameClockComponent` (falls back to local ticking if no clock is found).

```gdscript
func _on_data_changed_impl() -> void
```
Override hook — called at the end of `_on_data_changed()`. Subclasses use this to react to stat changes without disrupting the base sync.

---

## Components

Located in `res://Components/ActorComponents/`. Key components relevant to the stats layer:

### AbilityScoresComponent

**File:** `res://Components/ActorComponents/AbilityScoresComponent.gd`

Stores the six D&D-style ability score modifiers as floats (0.0 = baseline). Populated by `Actor._on_data_changed()` from `_data`. Do not write to this directly in actor subclasses — set stats on `_data` and let the bridge sync.

```gdscript
ability_scores_component.get_strength_score()   # returns int: 10 + (modifier * 2)
ability_scores_component.scores_changed         # signal
```

### ArmorClassComponent

**File:** `res://Components/ActorComponents/ArmorClassComponent.gd`

Manages AC calculation including equipped armor. Call `refresh()` after changing `equipped_armor`.

### HealthComponent

**File:** `res://Components/ActorComponents/HealthComponent.gd`

```gdscript
health_component.roll_max_health(dice_count: int, dice_size: int, rng: RandomNumberGenerator) -> float
health_component.take_damage(amount: float, type: String, direction: Vector3) -> void
health_component.health_depleted  # signal → connected to Actor.die()
```

### AbilityComponent

**File:** `res://Components/ActorComponents/AbilityComponent.gd`

Manages a list of `AbilityAction` instances with cooldown tracking.

```gdscript
ability_component.add_action(action: AbilityAction) -> void
ability_component.actions.clear()
ability_component.execute_ability(name: String, target_pos: Vector3) -> void
ability_component.is_disengaged  # bool — gates take_damage in Actor
```

### Ability Components

Located in `res://Components/ActorComponents/AbilityComponents/`:

| File | Description |
|------|-------------|
| `AbilityComponent.gd` | Base ability management |
| `AbilityAction.gd` | Base class for individual actions |
| `GoatCharge.gd` | Goat charge ability |
| `NimbleEscape.gd` | Hide / Disengage (Goblin) |
| `RedirectAttack.gd` | Swap places with nearby ally (Goblin) |
| `MimicShapechange.gd` | Mimic disguise ability |
| `MimicAmbushBite.gd` | Mimic ambush bite |
| `SporeBurst.gd` | Mushroom area spore attack |

---

## AI System

### AI Controller: ActorAIController.gd

**File:** `res://src/actors/ai/ActorAIController.gd`

Manages the AI state machine for an Actor.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `actor: Actor` | Actor | Owner actor reference |
| `awareness_radius: float` | float | Detection radius |
| `attack_range: float` | float | Melee attack range |

### AI States

Located in `res://src/actors/ai/states/`:

| File | Description |
|------|-------------|
| `AIState.gd` | Base class |
| `AIIdleState.gd` | Default patrol/idle |
| `AIChaseState.gd` | Pursues target |
| `AIAttackState.gd` | Attacks target |
| `AIFleeState.gd` | Flees from threat |
| `AIDeathState.gd` | Death handling |
| `AIFlockinState.gd` | Flocking behavior |
| `AIInvestigateState.gd` | Investigates detected activity |
| `AIRoamState.gd` | Wandering |
| `AIStunnedState.gd` | Stunned |
| `Dormant.gd` | Inactive |

### AI Behavior Overview

```
AIIdleState
	↓ (target detected)
AIChaseState
	↓ (in attack range)
AIAttackState
	↓ (target escapes / low health)
AIChaseState / AIFleeState
	↓ (death)
AIDeathState
```

---

## Actor Controllers

> **Deprecation Goal**: These controller scripts should be eliminated. Per-actor behavioral differences belong in `ActorTypeData.gd` as data, not in individualized scripts. New actor types must not get their own controller — configure them through the registry instead. Existing controllers should be migrated to data-driven entries in `ActorTypeData` and then deleted.

Located in `res://src/actors/types/`:

| File | Description |
|------|-------------|
| `GoatController.gd` | AI logic for GoatActor — **migrate to ActorTypeData** |
| `FarmerController.gd` | AI logic for FarmerActor — **migrate to ActorTypeData** |
| `GoblinController.gd` | AI logic for GoblinMinion — **migrate to ActorTypeData** |

---

## Derived Actors

All actor types in `res://src/actors/types/`.

### GoatActor

**File:** `res://src/actors/types/GoatActor.gd`

Uses `_data` (`GoatData`) set externally by the spawning system. Overrides `_on_data_changed_impl()` to compute `charge_speed` and `charge_distance` from strength, and update visuals. Move speed scales with dexterity via the base formula.

```gdscript
var goat_data: GoatData:
	get: return _data as GoatData
	set(v): _data = v
```

### GoblinMinion

**File:** `res://src/actors/types/GoblinMinion.gd`

Creates a fresh `GoblinData` instance in `_ready()` before calling `super._ready()`, so the data bridge fires during component initialization. Overrides `_on_data_changed_impl()` to pin `move_speed = 3.0` — goblins move at a fixed speed regardless of dexterity modifier.

```gdscript
func _ready() -> void:
	_data = GoblinData.new()
	super._ready()
	...

func _on_data_changed_impl() -> void:
	move_speed = 3.0
```

### MimicActor

**File:** `res://src/actors/types/MimicActor.gd`

Does not use `_data` — carries a separate `mimic_data: MimicData` for the procedural genome system. Stats are applied via `_apply_mimic_stat_profile()` directly to `ability_scores_component`. Move speed, HP, and AC set in `_init()`.

### MushroomActor

**File:** `res://src/actors/types/MushroomActor.gd`

Does not use `_data` — carries `mushroom_data: MushroomData`. Stats applied via `_apply_mushroom_stat_profile()` which reads directly from `mushroom_data`. Move speed, HP, and AC set in `_init()`.

### FarmerActor

**File:** `res://src/actors/types/FarmerActor.gd`

### FireActor / WaterActor

**Files:** `res://src/actors/types/FireActor.gd`, `WaterActor.gd`

Elemental actors.

### ScarecrowDummy

**File:** `res://src/actors/types/ScarecrowDummy.gd`

---

## Usage Patterns

### Spawning an actor with data wiring

```gdscript
# Actors that use _data: assign before adding to the scene tree, or in _ready()
# before super._ready(). The bridge fires automatically in Actor._ready().
var goblin: GoblinMinion = GOBLIN_SCENE.instantiate()
add_child(goblin)
# GoblinMinion._ready() creates _data = GoblinData.new() internally

# For GoatActor, _data is set externally by the spawning/herd system:
var goat: GoatActor = GOAT_SCENE.instantiate()
goat.goat_data = some_goat_data_resource
add_child(goat)
```

### Adding a new actor type

```gdscript
# 1. Create a Data subclass in Components/BreedingComponents/
class_name NewData
extends ActorData

func _init() -> void:
	_apply_type_defaults("NewTypeName")  # reads ActorTypeData registry
	if render_seed == 0:
		render_seed = randi()

# 2. Add "NewTypeName" to ActorTypeData.ACTOR_TYPES and CATEGORY_MAP

# 3. In the Actor subclass, wire _data:
class_name NewActor
extends Actor

func _ready() -> void:
	_data = NewData.new()
	super._ready()

# 4. Override _on_data_changed_impl() for any derived stats:
func _on_data_changed_impl() -> void:
	move_speed = 2.5  # if you need a fixed speed
```

### Handling damage

```gdscript
actor.died.connect(_on_death)

func _on_death():
	queue_free()
```

### Terrain speed modifier

```gdscript
terrain_speed_modifier_component.configure_multipliers({
	TileConstants.Type.MUD: 0.5,
	TileConstants.Type.GRASS: 1.2,
})
```

### Skill check

```gdscript
skill_check_component.skill_check_completed.connect(_on_skill_done)
skill_check_component.start_skill_check(SkillCheckComponent.SkillType.LOCKPICKING)
```

---

## Dependencies

### Requires
| System | Why |
|---|---|
| `ActorTypeData` | Spawn-time stat registry — must exist before any actor is instantiated |
| `ActorData` subclass | Per-actor stat resource — each actor type needs one in `Components/BreedingComponents/` |
| `GameEvents` | Global signal bus — `actor_died` is emitted on death; arena and quest systems listen |
| `GameClockComponent` | Centralized tick registration; falls back to local ticking if absent |

### Consumed By
| System | What it uses |
|---|---|
| Breeding | Reads/writes `ActorData` stats; crossover produces new `ActorData` instances |
| Arena | Spawns actors, manages lifecycle, listens to `died`, tracks in `actors` list |
| Quest System | Listens to `actor_died` via `GameEvents` to track kill objectives |
| PlayerInputComponent | Reads `is_playable`, `is_controlled`; cycles actor selection |
| UI / PlayerConsole | Reads `health_component`, `mana_component` for HUD display |

---

## Edge Cases

| Condition | Resolution |
|---|---|
| `_data` assigned after `super._ready()` | `_on_data_changed()` never fires during init — components will have default stats, not resource stats. Always assign `_data` before `super._ready()`. |
| Actor subclass with fixed move speed | The base formula `move_speed = 3.0 × dex` runs in `_on_data_changed()`. Override `_on_data_changed_impl()` to reset it — do not fight it in `_init()`. |
| `MimicActor` / `MushroomActor` with no `_data` | These actors bypass the `_data` bridge entirely. Stats are applied directly to `ability_scores_component` via their own profile methods. Do not attempt to set `_data` on them. |
| Actor removed from scene while dying | `die()` disables components and emits `died`. If `queue_free()` is called immediately from the signal, downstream listeners may not fire. Use a deferred free or let the Arena handle lifecycle. |
| `stats_changed` signal not emitted after manual component write | Writing directly to `ability_scores_component` bypasses the bridge. The resource and component will be out of sync. Always mutate stats via `_data`. |

---

## Formulas

### Move Speed

| Variable | Source | Notes |
|---|---|---|
| `dexterity` | `ActorData._data` | Modifier float; 0.0 = baseline |
| `move_speed` | Computed | Forwarded to `MovementComponent` |

```
move_speed = 3.0 × dexterity
```

> Override in `_on_data_changed_impl()` to pin a fixed speed (e.g. GoblinMinion sets `move_speed = 3.0` regardless of dex).

### Goat Charge

| Variable | Source | Notes |
|---|---|---|
| `strength` | `ability_scores_component` | Set via `_data` bridge |
| `charge_speed` | Computed in `GoatActor` | Units/sec |
| `charge_distance` | Computed in `GoatActor` | World units |

```
charge_speed    = 25.0 + (5.0 × strength)
charge_distance =  5.0 + (1.0 × strength)
```

### Ability Score → Integer Score

| Variable | Source | Notes |
|---|---|---|
| `modifier` | `AbilityScoresComponent` | Float, 0.0 = baseline |
| `score` | Computed | D&D-style integer |

```
score = 10 + (modifier × 2)
```

---

## Tuning Knobs

| Parameter | Location | Current Value | Effect |
|---|---|---|---|
| `move_speed` base scalar | `Actor._on_data_changed()` | `3.0` | Multiplied by dexterity modifier; raise to make all actors faster |
| `charge_speed` base | `GoatActor._on_data_changed_impl()` | `25.0` | Flat charge velocity floor before strength scaling |
| `charge_speed` strength scalar | `GoatActor._on_data_changed_impl()` | `5.0` | Speed gained per point of strength |
| `charge_distance` base | `GoatActor._on_data_changed_impl()` | `5.0` | Minimum charge range in world units |
| `charge_distance` strength scalar | `GoatActor._on_data_changed_impl()` | `1.0` | Range gained per point of strength |
| `max_hp` | `Actor` export | `10.0` | Base health before component init |
| `max_mana` | `Actor` export | `100.0` | Base mana pool |
| `armor_class` | `Actor` export | `10` | Base AC before `ArmorClassComponent` modifiers |
| `awareness_radius` | `ActorAIController` export | — | Detection radius for AI target acquisition |
| `attack_range` | `ActorAIController` export | — | Distance at which AI transitions to attack state |

---

## Best Practices

1. **Stats** — Never write ability scores directly to `ability_scores_component` in a new actor type. Set stats on `_data` and let `_on_data_changed()` sync them.
2. **Move speed** — If your actor needs a fixed move speed, override `_on_data_changed_impl()` and reset `move_speed` there; do not fight the dex formula in `_init()`.
3. **Component communication** — Components should communicate via signals, not direct references.
4. **AI states** — Keep state logic minimal; delegate complex behavior to dedicated systems.
5. **Damage** — Always route through `take_damage()` to respect disengage and invincibility logic.
6. **_data timing** — Assign `_data` before `super._ready()` so components exist when the bridge fires.

---

## Acceptance Criteria

| # | Given | When | Then |
|---|---|---|---|
| 1 | A new actor type is created with `_data = NewData.new()` set before `super._ready()` | The scene is instantiated | `ability_scores_component` reflects the stats from `NewData` immediately |
| 2 | A GoatActor with `strength = 2.0` is spawned | `_on_data_changed()` fires | `charge_speed == 35.0` and `charge_distance == 7.0` |
| 3 | A GoblinMinion is spawned with any dexterity value | `_on_data_changed()` fires | `move_speed == 3.0` regardless of dexterity |
| 4 | An actor's `health_component` reaches 0 | `die()` is called | `is_dead == true`, `died` signal emitted, `GameEvents.actor_died` emitted, physics disabled |
| 5 | `ability_scores_component` is written to directly (bypassing `_data`) | `stats_changed` is not emitted | `_data` and `ability_scores_component` are out of sync — this is a bug, not intended behavior |
| 6 | A `MimicActor` is instantiated | Any code attempts to set `_data` | Stats are not applied via the bridge; `_apply_mimic_stat_profile()` must be used instead |
| 7 | An actor emits `died` | A listener calls `queue_free()` synchronously | Downstream signal listeners may not fire — defer or let Arena handle |

---

## File Structure

### Source Code

```
res://src/actors/
├── base/
│   └── Actor.gd
├── types/
│   ├── GoatActor.gd
│   ├── GoatController.gd
│   ├── GoatVisuals.gd
│   ├── FireActor.gd
│   ├── FarmerActor.gd
│   ├── FarmerController.gd
│   ├── WaterActor.gd
│   ├── GoblinMinion.gd
│   ├── GoblinController.gd
│   ├── GoblinModels/
│   │   └── GoblinModel.gd
│   ├── MimicActor.gd
│   ├── MushroomActor.gd
│   ├── ScarecrowDummy.gd
│   ├── DormantVisual3D.gd
│   └── StunVisual3D.gd
├── ai/
│   ├── ActorAIController.gd
│   ├── ActorController.gd
│   ├── ActorStateMachine.gd
│   ├── ActorTileNavigationComponent.gd
│   ├── FactionComponent.gd
│   └── states/
│       ├── AIState.gd
│       ├── AIIdleState.gd
│       ├── AIChaseState.gd
│       ├── AIAttackState.gd
│       ├── AIFleeState.gd
│       ├── AIDeathState.gd
│       ├── AIFlockinState.gd
│       ├── AIInvestigateState.gd
│       ├── AIRoamState.gd
│       ├── AIStunnedState.gd
│       └── Dormant.gd
└── projectiles/
    ├── BaseProjectile.gd
    ├── WaveProjectile.gd
    ├── LobProjectile.gd
    ├── FireProjectile.gd
    ├── FireLobProjectile.gd
    ├── WaterProjectile.gd
    ├── WaterLobProjectile.gd
    └── HandaxeProjectile.gd

res://Components/ActorComponents/
├── ActorData.gd               ← per-actor stat resource base class
├── ActorTypeData.gd           ← spawn-time registry (ACTOR_TYPES, CATEGORY_MAP)
├── AbilityScoresComponent.gd
├── ArmorClassComponent.gd
├── HealthComponent.gd
├── MovementComponent.gd
├── ManaComponent.gd
├── StunComponent.gd
├── StatusEffectComponent.gd
├── CommunicationComponent.gd
├── TerrainSpeedModifierComponent.gd
├── SkillCheckComponent.gd
├── DetectionComponent.gd
├── ActorTileInteractionComponent.gd
├── ActorVisualComponent.gd
├── ActorParticleComponent.gd
├── BobComponent.gd
├── ChargeVisualComponent.gd
├── DamageComponent.gd
├── GoatScreamComponent.gd
├── HealthBarPool.gd
├── CreatureMorphComponent.gd
├── SkillCopyComponent.gd
└── AbilityComponents/
    ├── AbilityComponent.gd
    ├── AbilityAction.gd
    ├── GoatCharge.gd
    ├── NimbleEscape.gd
    ├── RedirectAttack.gd
    ├── MimicShapechange.gd
    ├── MimicAmbushBite.gd
    └── SporeBurst.gd

res://Components/BreedingComponents/
├── GoatData.gd                ← ActorData subclass for Goat
├── GoblinData.gd              ← ActorData subclass for Goblin
├── MimicData.gd               ← ActorData subclass for Mimic (+ genome)
└── MushroomData.gd            ← ActorData subclass for Mushroom (+ genome)
```

---

## Version Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-09 | Initial documentation |
| 1.1 | 2025-01-10 | Updated file paths to reflect directory restructuring |
| 1.2 | 2026-05-23 | Corrected base type; rewrote properties/signals/methods; added Stats Data Layer section; added MimicActor, MushroomActor; updated GoblinMinion; updated file structure |

---

*Sync this document when actor structure changes. Every commit touching actor files should include corresponding documentation updates.*
