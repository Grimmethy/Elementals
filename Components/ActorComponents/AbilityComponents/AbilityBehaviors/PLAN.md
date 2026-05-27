# Ability Behaviors — Architecture Plan

Reusable building blocks for composing D&D abilities from shared parts.
Stored in `AbilityBehaviors/` to keep entirely separate from bespoke ability
implementations (`GoatCharge.gd`, `NimbleEscape.gd`, etc.) and the data
dictionaries in `AbilityLists/`.

---

## Folder Layout

```
Components/
├── Utilities/                   ← NEW: domain-agnostic primitives
│   └── Cooldown.gd              ← general cooldown; usable by any system
└── ActorComponents/
    └── AbilityComponents/
        ├── AbilityComponent.gd          ← existing orchestrator (unchanged)
        ├── AbilityAction.gd             ← existing base class (unchanged)
        ├── GoatCharge.gd                ← existing bespoke abilities (unchanged)
        ├── NimbleEscape.gd
        ├── RedirectAttack.gd
        ├── MimicShapechange.gd
        ├── MimicAmbushBite.gd
        ├── SporeBurst.gd
        ├── AbilityLists/                ← existing data dictionaries (unchanged)
        │   ├── AbilityList.gd
        │   └── ...
        └── AbilityBehaviors/            ← NEW: ability-specific building blocks
            ├── PLAN.md                  ← this file
            ├── AbilityRecharge.gd
            ├── AbilityAreaQuery.gd
            ├── AbilitySaveResolver.gd
            ├── SaveResult.gd
            ├── AbilityDamageApplicator.gd
            ├── AbilityConditionApplicator.gd
            ├── AbilityVisualSpawner.gd
            └── DataDrivenAbility.gd
```

---

## External Architecture Contracts

These two systems are the source of truth. Every behavior component must
integrate through them rather than rolling its own equivalent.

### GameClockComponent
`res://Components/GameClockComponent.gd`

Centralized tick registry. Replaces all manual `_cooldown_left -= delta` and
`Timer` node patterns. Key details:

- Base rate: **10 Hz (0.1 s per tick)**. Custom intervals are supported.
- `register_tick(callback, custom_interval) -> int` — returns a callback ID.
- `unregister_tick(id)` — always call this on ability cleanup/actor death.
- `paused` property — all ticks pause automatically during game pause; no
  ability component needs to handle this separately.

**Access pattern:** Actors expose the clock directly. Call
`actor.register_tick(callback, interval)` and `actor.unregister_tick(id)` —
do **not** hold a raw `GameClockComponent` reference. This is confirmed by
`StatusEffectComponent`, which uses `_actor.register_tick()` throughout.

**Reference implementation:** `res://Components/ActorComponents/StatusEffectComponent.gd`
already follows the correct pattern: registers two ticks at different rates
in `setup()`, stores both IDs, and unregisters them in `_exit_tree()`. Its
comment — *"replaces 4 individual timers"* — confirms this is the intended
migration path. `AbilityConditionApplicator` should follow this file as a
template.

**Rule:** Any behavior that needs time-based ticking for **round tracking or
  condition durations** must use `actor.register_tick()` rather than
  `_process` / `_physics_process` / local `Timer` nodes. Cooldown gating is
  handled differently — see `Cooldown` in `Utilities/` below.

### TileSignalComponent
`res://Components/Arena/TileSignalComponent.gd`

Hex-tile proximity system. Range queries use **hex tile distance** via axial
coordinates, not world-space floats.

- `register_trigger(center_tile, radius, callback, metadata) -> Dictionary`
  — fires `callback(actor, metadata)` when any actor enters the radius.
- `update_trigger_center(trigger, new_tile)` — call whenever the source actor
  moves to a new tile; keeps auras correctly centered.
- `remove_trigger(trigger)` — always call on cleanup.
- `metadata = { "continuous": true }` — fires the callback on every tile
  move within range, not just on enter. Required for damage auras.

**Reference implementation:** `res://Components/ActorComponents/DetectionComponent.gd`
is a full working example of the correct integration pattern:
- Calls `signals.register_trigger()` in `_register_perception_trigger()`
- Connects to `actor.tile_changed` and calls `update_trigger_center()` in `_on_tile_changed()`
- Reads `trigger.get("active_actors", [])` for one-shot target queries
- Computes hex distance manually using axial coordinates for per-actor checks

`AbilityAreaQuery` should follow `DetectionComponent` as a template.

**Rule:** Any behavior that needs to find actors within range (one-shot or
  persistent) **must** route through `TileSignalComponent`. Never iterate
  `arena.actors` and do float-distance math directly.

#### Feet → Hex Tile Conversion

The arena uses `hex_size` (default `1.5` world units) to define tile
geometry. The exact world-to-tile formula used by `DetectionComponent` is:

```gdscript
int(ceil(world_distance / (sqrt(3.0) * hex_size))) + 1
```

Ability data ranges are in D&D feet, not world units. The working conversion
convention is **1 tile = 5 ft.**, which `AbilityAreaQuery` should apply when
parsing the `range` field. The hex_size-based formula above is for components
working with real world-space distances (like `DetectionComponent`).

| Ability data `range` | Hex tiles |
|---|---|
| `"Touch"` / `"5 ft."` | 1 |
| `"10 ft."` | 2 |
| `"15 ft."` | 3 |
| `"20 ft."` | 4 |
| `"30 ft."` | 6 |
| `"60 ft."` | 12 |
| `"90 ft."` | 18 |
| `"120 ft."` | 24 |
| `"150 ft."` | 30 |
| `"300 ft."` | 60 |
| `"Self"` | 0 (self-only, no query needed) |
| `"Varies per creature"` | must be supplied at registration time |

Cone / line shapes use the same tile radius for length; shape is determined
by the geometry of which tiles fall within the arc.

---

## Confirmed Component Contracts

These components were audited during planning. The notes below prevent
re-implementation mistakes and document integration requirements for all
behavior components.

### AbilityScoresComponent
`res://Components/ActorComponents/AbilityScoresComponent.gd`

**CRITICAL:** Stats are stored as **modifier values** (floats, default `0`),
not as D&D 5e ability scores (3–20). There is no conversion step needed inside
ability code — the stored value **is** the modifier.

```gdscript
# These are all modifiers directly. "strength = 2" means +2 to rolls.
actor.ability_scores_component.strength      # e.g. 2.0
actor.ability_scores_component.dexterity     # e.g. 1.0
actor.ability_scores_component.constitution  # e.g. 1.0
actor.ability_scores_component.intelligence  # e.g. 0.0
actor.ability_scores_component.wisdom        # e.g. 0.5
actor.ability_scores_component.charisma      # e.g. -1.0
```

Utility method: `get_score(modifier) -> int` returns `int(10 + modifier * 2)`,
which converts back to a D&D ability score for display only.

Signal: `scores_changed` — emit-safe for cache invalidation in
`AbilitySaveResolver` if the DC needs recomputing after a stat change.

**DC formula implication:** The save DC formula `8 + proficiency_bonus + modifier`
uses the raw stored value, not `(score - 10) / 2`.

### Proficiency Bonus
**No per-actor `proficiency_bonus` property exists in the project.**

The convention (established by `CaptureProfile.gd`, which documents
*"DC 12 mirrors D&D Net: 8 + Dex 2 + proficiency 2"*) is a hardcoded constant
of `+2`. This matches the D&D 5e CR 1–4 standard proficiency bonus used by
most monster stat blocks in the data library.

```gdscript
# Until a CharacterProgressionComponent or similar is added, use:
const PROFICIENCY_BONUS: int = 2
```

`AbilitySaveResolver` should define this as a named constant rather than
burying the literal `2` inside a formula.

### StunComponent
`res://Components/ActorComponents/StunComponent.gd`

**Pre-existing.** Stun is already implemented with its own timer, signals,
and `is_stunned()` query. `AbilityConditionApplicator` **must not** implement
its own stun tracking — it must delegate to this component.

```gdscript
# Apply stun via the pre-existing component:
target.stun(duration_seconds)    # StunComponent.stun(duration)
target.is_stunned()              # StunComponent.is_stunned()

# StunComponent signals (connect if needed):
# stun_started   — emitted when stun begins
# stun_ended     — emitted when stun expires
```

`AbilityConditionApplicator` should use `StunComponent` for the Stunned
condition, and establish the same delegation pattern for other conditions that
may gain their own components over time (Paralyzed, Frightened, etc.). For
conditions without a dedicated component yet, fall back to an internal flag
plus a `actor.register_tick()` countdown.

### HealthComponent
`res://Components/ActorComponents/HealthComponent.gd`

Confirmed method signatures for `AbilityDamageApplicator`:

```gdscript
target.take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO)
target.heal(amount: float)
target.is_dead() -> bool

# Signals:
# health_changed(current: float, max: float)
# health_depleted()
# damage_received(amount: float, type: String)
```

`type` is a freeform string. The data library uses: `"fire"`, `"cold"`,
`"lightning"`, `"acid"`, `"poison"`, `"psychic"`, `"necrotic"`, `"radiant"`,
`"thunder"`, `"piercing"`, `"slashing"`, `"bludgeoning"`, `"normal"`.

### CharacterBuildComponent
`res://Components/ActorComponents/CharacterBuildComponent.gd`

**Integration point for DataDrivenAbility.** When `DataDrivenAbility` instances
need to be available to a creature, they must be registered in
`CharacterBuildComponent._ABILITY_REGISTRY`.

```gdscript
# _ABILITY_REGISTRY maps string key → preloaded script.
# Current registered abilities (as of audit):
#   "nimble_escape"      → NimbleEscape
#   "redirect_attack"    → RedirectAttack
#   "goat_charge"        → GoatCharge
#   "mimic_shapechange"  → MimicShapechange

# DataDrivenAbility is instantiated differently — from a data dict —
# but the same _apply_ability() integration point in CharacterBuildComponent
# is where new entries hook in.
```

When `DataDrivenAbility.from_dict()` is wired up, `CharacterBuildComponent`
should receive a new branch in `_apply_ability()` that handles ability pool
entries referencing `AbilityList.ABILITIES` keys rather than script paths.
This keeps all ability instantiation in one place.

---

## Utilities

### Cooldown

**File:** `res://Components/Utilities/Cooldown.gd`

**Purpose:** A domain-agnostic cooldown primitive usable by any system in the
project. Tracks remaining time and exposes a progress ratio, but owns **no
ticking logic of its own** — the caller advances it using whatever time
source is appropriate for that context.

This replaces the copy-paste `_cooldown_left: float` / `timer -= delta`
pattern currently duplicated across `NimbleEscape`, `GoatCharge`,
`SporeBurst`, `MimicShapechange`, `WeaponComponent`, and
`DetectionComponent`.

**No external dependency.** Pure value tracking — no clock registration, no
tick IDs, no `_process`.

```gdscript
class_name Cooldown
extends RefCounted

signal ready  # emitted once when remaining time reaches zero

## Begin a new cooldown of the given duration in seconds.
func start(duration: float) -> void

## Advance the cooldown by delta seconds. Call from wherever time comes from.
## Emits ready when remaining reaches zero.
func advance(delta: float) -> void

## True when no cooldown is running (remaining == 0).
func is_ready() -> bool

## Seconds remaining. 0.0 when ready.
func remaining() -> float

## 0.0 = just started, 1.0 = complete. Suitable for progress bars.
func progress() -> float

## Stop a running cooldown without emitting ready.
func cancel() -> void
```

**Each system advances it with its own time source:**

| Caller | How to advance | Why |
|---|---|---|
| `WeaponComponent._process(delta)` | `_cooldown.advance(delta)` | Frame-rate smooth for `get_main_action_progress()` UI |
| `NimbleEscape.update(delta)` | `_cooldown.advance(delta)` | Already in the update loop |
| `GoatCharge.update(delta)` | `_cooldown.advance(delta)` | Already in the update loop |
| `SporeBurst.update(delta)` | `_cooldown.advance(delta)` | Already in the update loop |
| Clock-registered ability tick | `_cooldown.advance(tick_interval)` | Pause-aware via GameClockComponent |
| `DetectionComponent.process_update(delta)` | `_cooldown.advance(delta)` | Rate-limiter for perception checks |

**`progress()` replaces inline formulas.** For example, in `WeaponComponent`:
```gdscript
# Before (line 170):
return 1.0 - (_cooldown / weapon_data.cooldown)

# After:
return _cooldown.progress()
```

---

## Component Specifications

### 2. AbilityRecharge

**File:** `AbilityBehaviors/AbilityRecharge.gd`

**Purpose:** Handle all D&D recharge mechanics. Parses the `recharge` field
from ability data and manages availability accordingly.

**GameClockComponent integration:**
- Dice-roll recharges (`"5-6"`, `"6"`, `"4-6"`): register a tick at a
  ~6-second interval (one combat round). On each tick, roll 1d6; if the
  result meets the threshold, emit `recharged` and mark available.
- Per-day and rest-based modes have no clock dependency — they respond to
  game-level rest events.

**Data field → mode mapping:**

| `recharge` value | Mode | Behaviour |
|---|---|---|
| `""` | `NONE` | Always available |
| `"5-6"` | `DICE_ROLL` | Roll d6 each round; available on 5 or 6 |
| `"6"` | `DICE_ROLL` | Roll d6 each round; available on 6 only |
| `"4-6"` | `DICE_ROLL` | Roll d6 each round; available on 4, 5, or 6 |
| `"1/Day"` | `USES_PER_DAY` | 1 use; resets on long rest |
| `"3/Day"` | `USES_PER_DAY` | 3 uses; resets on long rest |
| `"Short Rest"` | `SHORT_REST` | 1 use; resets on short or long rest |
| `"Long Rest"` | `LONG_REST` | 1 use; resets on long rest only |

```gdscript
class_name AbilityRecharge
extends RefCounted

signal recharged

enum Mode { NONE, DICE_ROLL, USES_PER_DAY, SHORT_REST, LONG_REST }

## Create from the ability data's "recharge" string. Pass clock for DICE_ROLL modes.
static func from_string(recharge_str: String, clock: GameClockComponent = null) -> AbilityRecharge

## True if the ability can be used right now.
func is_available() -> bool

## Consume one use. Call after a successful execute().
func consume() -> void

## Remaining uses (only meaningful for USES_PER_DAY mode).
func uses_remaining() -> int

## Call when the actor takes a short or long rest.
func on_rest(is_long_rest: bool) -> void

## Unregister any clock ticks. Call on actor death / component cleanup.
func cleanup() -> void
```

---

### 3. AbilityAreaQuery

**File:** `AbilityBehaviors/AbilityAreaQuery.gd`

**Purpose:** Locate valid targets using hex tile distance via
`TileSignalComponent`. Abstracts shape (radius, cone, line) and team
filtering so individual abilities never iterate `arena.actors` directly.

**TileSignalComponent integration:**
- **One-shot queries** (e.g., breath weapon fires): reads
  `TileSignalComponent._actor_tiles` and computes hex distance for each
  tracked actor.
- **Persistent triggers** (e.g., Fear Aura, Stench): calls
  `TileSignalComponent.register_trigger()` with `continuous: true`. Calls
  `update_trigger_center()` each time the source actor changes tile. Calls
  `remove_trigger()` on cleanup.

```gdscript
class_name AbilityAreaQuery
extends RefCounted

enum Shape      { RADIUS, CONE, LINE, SINGLE, SELF }
enum TeamFilter { ENEMIES, ALLIES, ALL, SELF_ONLY }

## Build from the ability data's "range" string and a team filter.
static func from_range_string(range_str: String, team: TeamFilter) -> AbilityAreaQuery

## One-shot: return all valid targets right now.
func get_targets_oneshot(
    actor: Actor,
    tile_signal: TileSignalComponent,
    aim_tile: Object = null   # required for CONE and LINE shapes
) -> Array[Actor]

## Persistent: register a proximity trigger that fires as actors enter/exit.
## Returns the trigger handle; caller must store it for cleanup.
func register_persistent(
    actor: Actor,
    tile_signal: TileSignalComponent,
    on_enter: Callable,          # fn(actor: Actor)
    on_exit:  Callable = Callable()
) -> Dictionary

## Update the trigger center when the source actor moves to a new tile.
func update_center(tile_signal: TileSignalComponent, trigger: Dictionary, new_tile: Object) -> void

## Unregister the persistent trigger. Call on actor death / ability deactivated.
func release_persistent(tile_signal: TileSignalComponent, trigger: Dictionary) -> void
```

**Shape resolution from range strings:**
- `"X ft."` → `RADIUS`
- `"X ft. cone"` → `CONE`
- `"X ft. line"` → `LINE`
- `"Self"` → `SELF`
- `"Touch"` / `"5 ft."` → `SINGLE` (melee reach, 1 tile)

---

### 4. AbilitySaveResolver + SaveResult

**Files:** `AbilityBehaviors/AbilitySaveResolver.gd`, `AbilityBehaviors/SaveResult.gd`

**Purpose:** Compute the save DC and invoke the existing `SkillCheckComponent`
to perform the actual roll. `AbilitySaveResolver` does **not** roll dice itself.

#### Relationship to SkillCheckComponent

`res://Components/ActorComponents/SkillCheckComponent.gd` already handles:
- Rolling 1d20
- Adding a stat modifier to the roll
- Comparing the total against a DC
- Natural 20 automatic success
- Structured result: `{ success, roll, total, is_critical }`
- Debug logging via `enable_roll_logs`

It is already used in the ability system — `NimbleEscape` calls
`actor.skill_check_component.perform_check(...)` directly.

`AbilitySaveResolver`'s only unique responsibility is **DC computation**:

```
DC = 8 + proficiency_bonus + stat_modifier(save_dc_stat)
```

Once the DC is known, it passes control to `target.skill_check_component.perform_check()`.
`SaveResult` is a thin wrapper that adds `dc` and `margin` to the Dictionary
that `SkillCheckComponent` already returns.

**DC formula:** `8 + PROFICIENCY_BONUS + caster.ability_scores_component[dc_source_stat]`

The stat value is the **raw modifier** stored in `AbilityScoresComponent` —
not `(score - 10) / 2`. See "Confirmed Component Contracts → AbilityScoresComponent"
above. `PROFICIENCY_BONUS` is the project-wide constant `2` — see "Confirmed
Component Contracts → Proficiency Bonus" above.

```gdscript
class_name AbilitySaveResolver
extends RefCounted

## Project-wide proficiency bonus. No per-actor value exists yet.
const PROFICIENCY_BONUS: int = 2

## What stat the TARGET rolls. From data field "saving_throw".
## e.g. "CON", "WIS", "DEX". Maps to AbilityScoresComponent property names.
var save_stat: String = "CON"

## What stat on the CASTER sets the DC. From data field "save_dc_stat".
## e.g. "CON", "CHA", "INT". Maps to AbilityScoresComponent property names.
var dc_source_stat: String = "CON"

## Build from a data dictionary entry.
static func from_dict(data: Dictionary) -> AbilitySaveResolver

## Compute DC = 8 + PROFICIENCY_BONUS + caster.ability_scores_component[dc_source_stat],
## then delegate the roll to target.skill_check_component.perform_check().
## Returns a SaveResult.
func resolve(caster: Actor, target: Actor) -> SaveResult
```

**Stat name mapping** (ability data string → `AbilityScoresComponent` property):

| Data string | Property |
|---|---|
| `"STR"` | `ability_scores_component.strength` |
| `"DEX"` | `ability_scores_component.dexterity` |
| `"CON"` | `ability_scores_component.constitution` |
| `"INT"` | `ability_scores_component.intelligence` |
| `"WIS"` | `ability_scores_component.wisdom` |
| `"CHA"` | `ability_scores_component.charisma` |

```gdscript
class_name SaveResult
extends RefCounted

## Wraps the Dictionary returned by SkillCheckComponent.perform_check()
## and adds the DC and margin fields it does not track.

var success:     bool   # from SkillCheckComponent: true if roll met or beat DC
var roll:        int    # from SkillCheckComponent: the raw d20 result
var total:       float  # from SkillCheckComponent: roll + modifier
var is_critical: bool   # from SkillCheckComponent: natural 20
var dc:          int    # computed by AbilitySaveResolver
var margin:      int    # total - dc (positive = beat by this much)

static func from_check(check: Dictionary, computed_dc: int) -> SaveResult
```

**Handling `"Contested (X vs Y)"` saves:** When `saving_throw` contains
`"Contested"`, `AbilitySaveResolver` calls `perform_check()` on **both**
actors and compares totals rather than using a fixed DC.

---

### 5. AbilityDamageApplicator

**File:** `AbilityBehaviors/AbilityDamageApplicator.gd`

**Purpose:** Parse dice expression strings from ability data and apply typed
damage to targets. Centralizes the dice roller so it isn't re-implemented per ability.

**No external system dependency.** Calls `target.take_damage(amount, type, direction)`.

**Supported dice formats:** `"2d6"`, `"4d8+4"`, `"10d10"`, `"1d4+2"`,
`"Varies per creature"` (skips roll and returns 0).

**Multiplier:** Pass `1.0` for full damage, `0.5` for half on successful
save, `0.0` to skip damage entirely (e.g., condition-only abilities).

```gdscript
class_name AbilityDamageApplicator
extends RefCounted

var dice_expression: String  # from data field "damage_dice"
var damage_type:     String  # from data field "damage_type"

## Build from a data dictionary entry.
static func from_dict(data: Dictionary) -> AbilityDamageApplicator

## Roll, scale, and apply damage. Returns the final amount dealt.
func apply(caster: Actor, target: Actor, multiplier: float = 1.0) -> int

## Roll the dice without applying (preview / UI display).
func roll_amount() -> int

## True when dice_expression is empty or "Varies per creature".
func is_variable() -> bool
```

---

### 6. AbilityConditionApplicator

**File:** `AbilityBehaviors/AbilityConditionApplicator.gd`

**Purpose:** Apply D&D conditions (Paralyzed, Frightened, Stunned, Restrained,
etc.) with duration tracking and optional per-round re-save.

**Relationship to StatusEffectComponent:**
`res://Components/ActorComponents/StatusEffectComponent.gd` is the existing
condition system for elemental effects (burning, water). It is the proven
template for how conditions should be implemented in this codebase:
- Uses `actor.register_tick()` with two rates: fast (0.1 s) for state
  checks, slow (1.0 s) for damage/expiry ticks
- Stores tick IDs (`_fast_tick_id`, `_slow_tick_id`) and unregisters both
  in `_exit_tree()`
- `_physics_process` is a deliberate no-op — comment reads *"All timing
  routed through GameClockComponent"*

`AbilityConditionApplicator` is the D&D conditions counterpart to
`StatusEffectComponent`. Both use the same actor tick infrastructure. They
are separate because elemental conditions (fire, water) originate from tile
interactions, while D&D combat conditions (Paralyzed, Frightened, etc.)
originate from ability saves and have structured re-save mechanics.

**Relationship to StunComponent:**
`res://Components/ActorComponents/StunComponent.gd` is a **pre-existing**
dedicated Stunned condition implementation. `AbilityConditionApplicator` must
route the Stunned condition through it — never re-implement stun tracking:

```gdscript
# Correct: delegate to the existing component
if "Stunned" in conditions:
    target.stun(duration_seconds)  # StunComponent.stun()

# Incorrect: do NOT add a "stunned" flag here
```

For conditions that do **not** yet have a dedicated component (Paralyzed,
Frightened, Restrained, etc.), `AbilityConditionApplicator` maintains
internal per-target state and a `register_tick()` countdown — following the
same pattern as `StatusEffectComponent`. As dedicated condition components
are added over time, `AbilityConditionApplicator` should delegate to them in
the same way it delegates to `StunComponent`.

**GameClockComponent integration:**
- Duration countdown: registers a slow tick (6 s ≈ 1 round) to decrement
  remaining round count. Uses `actor.register_tick()`, not a raw clock ref.
- Per-round re-saves: on the same tick interval via `AbilitySaveResolver`.
- Stores the tick ID and calls `actor.unregister_tick(id)` in `cleanup()` —
  same pattern as `StatusEffectComponent._exit_tree()`.

**Duration string → round count mapping:**

| `duration` value | Rounds |
|---|---|
| `"Until end of target's next turn"` | 1 |
| `"1 minute"` | 10 |
| `"10 minutes"` | 100 |
| `"1 hour"` | 600 |
| `"Until magically cured"` | indefinite (-1) |
| `"Concentration"` | indefinite (-1), cleared when caster loses concentration |
| `"Permanent until cured"` | indefinite (-1) |

```gdscript
class_name AbilityConditionApplicator
extends RefCounted

## Condition names from the ability data's "conditions_applied" array.
var conditions:    Array[String]

## Parsed from the ability data's "duration" field.
var duration_str:  String

## True if the target can re-save at the end of each round.
var allows_resave: bool

## Stat the target re-saves with. Same as the original save_stat.
var resave_stat:   String

## Build from a data dictionary entry. Requires a resolver for re-saves.
static func from_dict(data: Dictionary, resolver: AbilitySaveResolver) -> AbilityConditionApplicator

## Apply all conditions to the target. Starts duration and re-save ticking.
func apply(
    caster: Actor,
    target: Actor,
    save_result: SaveResult,
    clock: GameClockComponent
) -> void

## Remove all conditions early (e.g., caster died, ability was dispelled).
func remove(target: Actor) -> void

## Unregister clock ticks. Call on caster death / ability cleanup.
func cleanup() -> void
```

---

### 7. AbilityVisualSpawner

**File:** `AbilityBehaviors/AbilityVisualSpawner.gd`

**Purpose:** Centralize particle and visual effects so individual abilities
don't duplicate particle setup code. Extracted and generalized from
`SporeBurst._spawn_burst_visual()`.

**No external system dependency.** Purely additive visuals attached to the
scene tree, auto-cleaned up after their lifetime.

```gdscript
class_name AbilityVisualSpawner
extends RefCounted

## Spherical particle burst at the actor's position.
## Used by: SporeBurst, on-impact effects, death bursts.
static func burst(actor: Actor, radius: float, color: Color, lifetime: float = 0.7) -> void

## Cone-shaped spray in a direction.
## Used by: breath weapons, cone-shaped abilities.
static func cone(actor: Actor, direction: Vector3, length_tiles: int, color: Color) -> void

## Traveling projectile node from one actor to another; fires on_arrive when it lands.
## Used by: Death Ray, Psychic Orb, Lightning Bolt, etc.
static func projectile(from: Actor, to: Actor, color: Color, on_arrive: Callable) -> void

## Persistent ring/halo for ongoing aura effects. Returns the node for later cleanup.
## Used by: Fear Aura, Stench, Radiance, Blazing Presence, etc.
static func ring(actor: Actor, radius_tiles: int, color: Color, pulse: bool = false) -> Node3D

## Floating popup text above an actor (damage numbers, condition names).
static func popup_text(actor: Actor, text: String, color: Color) -> void
```

---

### 8. DataDrivenAbility

**File:** `AbilityBehaviors/DataDrivenAbility.gd`

**Purpose:** Wire all behaviors above together from a single data dictionary
entry. Allows abilities that have no unique logic — approximately 60% of the
270+ ability library — to be instantiated without a custom class.

**Reads from:** `AbilityList.ABILITIES["CATEGORY"]["AbilityName"]`

**Does NOT cover:** Abilities with unique state machines. See Tier 3 below.

**Registration:** Creature types gain access to `DataDrivenAbility` entries
through `CharacterBuildComponent._ABILITY_REGISTRY` and the `_apply_ability()`
method. When this class is ready, `_apply_ability()` needs a new branch that
accepts a data-dict key (an `AbilityList.ABILITIES` lookup path) instead of a
script path, and calls `DataDrivenAbility.from_dict()` to instantiate it.
Until then, abilities can be instantiated directly in `CharacterBuildComponent`
for testing without modifying the registry format.

```gdscript
class_name DataDrivenAbility
extends AbilityAction

## Instantiate from an ability data entry. Requires both external systems.
static func from_dict(
    ability_name:  String,
    data:          Dictionary,
    actor:         Actor,
    component:     Node,
    clock:         GameClockComponent,
    tile_signal:   TileSignalComponent
) -> DataDrivenAbility
```

Internally creates and holds:
- `AbilityRecharge`
- `AbilityAreaQuery`
- `AbilitySaveResolver`
- `AbilityDamageApplicator`
- `AbilityConditionApplicator`
- `AbilityVisualSpawner` (static calls)

Implements the full `AbilityAction` interface:
- `can_execute(type)` — gates on `AbilityRecharge.is_available()`
- `execute(type, value)` — queries targets → resolves saves → applies
  damage → applies conditions → plays visuals → consumes recharge
- `update(delta)` — no-op (clock handles ticking)
- `on_damage_taken()` — breaks concentration if ability requires it
- `cleanup()` — unregisters all clock ticks and tile triggers

---

## Ability Tier Classification

### Tier 1 — Fully data-driven (use `DataDrivenAbility`)

No custom class required. These are pure combinations of save + damage +
condition with standard targeting.

Examples include:
- All **breath weapons** (same cone/save/damage pattern; different dice and type)
- All **single-target damage** abilities (Psychic Orb, Death Ray, Bolts of
  Madness, Rotting Gaze, Psychic Spittle)
- All **paralyzing / petrifying** attacks (same two-stage save structure)
- All **charm / fear** abilities (Charm, Fear, Hypnosis, Luring Song)
- Most **gaze attacks** (Chilling Gaze, Stunning Gaze, Weakening Gaze)
- All **breath weapon** status variants (Paralysis Gas, Petrifying Breath,
  Weakening Breath, Blinding Breath)

### Tier 2 — Custom trigger, shared mechanics (custom subclass + behaviors)

Unique trigger condition but standard mechanics underneath. Custom
`AbilityAction` subclass, but uses behavior components internally rather
than re-implementing them.

| Ability | Custom part | Shared behaviors used |
|---|---|---|
| `AuraAction` | Persistent passive while alive | `AbilityAreaQuery` (persistent), `AbilityConditionApplicator` |
| `RegenerationAction` | Fires on turn start | `Cooldown` (suppression window) |
| `LifeDrainAction` | Steals HP equal to damage | `AbilityDamageApplicator`, `AbilitySaveResolver` |
| `SporeBurst` *(refactor)* | Mushroom genome radius bonus | `Cooldown`, `AbilityAreaQuery`, `AbilityDamageApplicator` |
| `BreathWeaponAction` | Recharge dice roll mechanic | `AbilityRecharge`, `AbilityAreaQuery` (cone), `AbilityDamageApplicator` |

### Tier 3 — Fully bespoke (keep custom, refactor internals only)

State machines too unique to decompose. Keep as custom classes but replace
their internal timer patterns with `Cooldown` from `Utilities/`.

| Ability | Reason |
|---|---|
| `NimbleEscape` | Stealth state machine, opposed skill checks |
| `GoatCharge` | Custom physics force integration |
| `RedirectAttack` | Actor swap with position safety checks |
| `MimicShapechange` | Morph component orchestration, skill copying |
| `MimicAmbushBite` | Ambush timing state machine |
| Possession / Body Thief | Host body management |

---

---

## Build Order

Priority is based on the number of abilities and existing files each
component unblocks.

| # | File | Unblocks |
|---|---|---|
| 1 | `Utilities/Cooldown.gd` | Immediate refactor of 6 existing files across 3 systems; all future active abilities |
| 2 | `AbilityBehaviors/AbilityRecharge.gd` | All active abilities with recharge dice or daily uses |
| 3 | `AbilityBehaviors/SaveResult.gd` | Prerequisite for steps 4 and 6 |
| 4 | `AbilityBehaviors/AbilitySaveResolver.gd` | All ~150 saving-throw abilities |
| 5 | `AbilityBehaviors/AbilityDamageApplicator.gd` | All ~100 damage-dealing abilities; centralizes dice parser |
| 6 | `AbilityBehaviors/AbilityConditionApplicator.gd` | All ~120 condition-inflicting abilities |
| 7 | `AbilityBehaviors/AbilityAreaQuery.gd` | All AoE, cone, and aura abilities; enables persistent triggers |
| 8 | `AbilityBehaviors/AbilityVisualSpawner.gd` | Shared VFX; not blocking but cleans up particle code |
| 9 | `AbilityBehaviors/DataDrivenAbility.gd` | Composes all above; unlocks ~60% of ability library |
