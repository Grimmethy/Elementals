class_name AbilityConditionApplicator
extends RefCounted

## Applies D&D conditions to targets with duration tracking and optional
## per-round re-saves.
##
## Condition routing:
##   - "Stunned" → delegates to the pre-existing StunComponent (target.stun())
##   - All other conditions → internal flag + GameClockComponent round tick
##
## As dedicated condition components are added to the project (Paralyzed,
## Frightened, etc.), replace their internal tracking here with delegation
## to the new component, following the same pattern as StunComponent.
##
## GameClockComponent integration:
##   Registers a slow tick at 6 s (1 combat round) via actor.register_tick().
##   On each tick: decrements remaining rounds, fires per-round re-saves,
##   clears expired conditions. Tick ID stored and unregistered in cleanup().
##   Pattern matches StatusEffectComponent exactly — no _process usage.
##
## Usage (from DataDrivenAbility.execute):
##   var applicator := AbilityConditionApplicator.from_dict(data, resolver)
##   applicator.apply(caster, target, save_result, actor_for_clock)
##   # later, on cleanup:
##   applicator.cleanup()

## Emitted when a condition is applied to a target.
signal condition_applied(condition: String, target: Actor)

## Emitted when a condition expires or is removed from a target.
signal condition_removed(condition: String, target: Actor)

## Condition names from ability data "conditions_applied" array.
var conditions: Array[String] = []

## Raw duration string from ability data "duration" field.
var duration_str: String = ""

## True if the target may re-save at the end of each round to end the condition.
var allows_resave: bool = false

## Stat the target re-saves with. Same as the original save_stat.
var resave_stat: String = "CON"

## Duration string → round count.
const DURATION_TABLE: Dictionary = {
	"Until end of target's next turn": 1,
	"Until end of next turn":          1,
	"1 round":                         1,
	"1 minute":                        10,
	"10 minutes":                      100,
	"1 hour":                          600,
	"Until magically cured":           -1,
	"Concentration":                   -1,
	"Permanent until cured":           -1,
	"Permanent":                       -1,
	"Until dispelled":                 -1,
	"Special":                         -1,
}

# Per-target condition tracking.
# Key: target instance_id (int)
# Value: { "conditions": Array[String], "rounds_left": int, "target": Actor }
var _active: Dictionary = {}

# GameClockComponent tick handles. One per actor we've registered on.
# Key: actor instance_id, Value: tick_id int
var _tick_ids: Dictionary = {}

# The AbilitySaveResolver used for per-round re-saves.
var _resolver: AbilitySaveResolver = null

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Build from a data dictionary. resolver is used for per-round re-saves.
## resolver may be null if allows_resave is false.
static func from_dict(data: Dictionary, resolver: AbilitySaveResolver = null) -> AbilityConditionApplicator:
	var a := AbilityConditionApplicator.new()
	a._resolver    = resolver
	a.duration_str = str(data.get("duration", "")).strip_edges()
	a.allows_resave = bool(data.get("allows_resave", false))
	a.resave_stat   = str(data.get("saving_throw", "CON")).strip_edges().to_upper()

	# Parse conditions_applied — may be an Array or a single String.
	var raw = data.get("conditions_applied", [])
	if raw is Array:
		for c in raw:
			a.conditions.append(str(c).strip_edges())
	elif raw is String and raw.strip_edges() != "":
		a.conditions.append(raw.strip_edges())

	return a

# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

## Apply all conditions to target. Starts duration tracking and re-save ticking.
## clock_actor is the actor whose register_tick() will be used for round counts.
## It is usually the caster, but can also be the target — either works because
## GameClockComponent ticks are not actor-local in behaviour.
func apply(caster: Actor, target: Actor, save_result: SaveResult,
		clock_actor: Actor) -> void:
	if conditions.is_empty():
		return
	if not is_instance_valid(target) or target.is_dead:
		return

	var rounds: int = _parse_duration(duration_str)

	# Apply each condition.
	for condition in conditions:
		_apply_single_condition(condition, target)
		condition_applied.emit(condition, target)

	# Track the application if it has a finite or re-saveable duration.
	var tid: int = target.get_instance_id()
	_active[tid] = {
		"conditions": conditions.duplicate(),
		"rounds_left": rounds,
		"target": target,
		"caster": caster,
	}

	# Register a round tick on clock_actor if we don't already have one there.
	_ensure_tick(clock_actor)

## Remove all conditions from a specific target early (caster died, dispelled, etc.).
func remove(target: Actor) -> void:
	if not is_instance_valid(target):
		return
	var tid: int = target.get_instance_id()
	var entry: Variant = _active.get(tid)
	if entry == null:
		return
	for condition in entry["conditions"]:
		_remove_single_condition(condition, target)
		condition_removed.emit(condition, target)
	_active.erase(tid)

## Unregister all GameClockComponent ticks. Call on caster death / ability cleanup.
func cleanup() -> void:
	for actor_id in _tick_ids.keys():
		var tick_id: int = _tick_ids[actor_id]
		# We can't recover the actor from an id after it may be dead — iterate active.
		# Best-effort: try to find a still-valid actor to unregister from.
		for tid in _active.keys():
			var entry: Variant = _active.get(tid)
			if entry and is_instance_valid(entry.get("caster")):
				var a: Actor = entry["caster"] as Actor
				if a.get_instance_id() == actor_id and a.has_method("unregister_tick"):
					a.call("unregister_tick", tick_id)
				break
	_tick_ids.clear()
	_active.clear()

# ---------------------------------------------------------------------------
# Private — condition routing
# ---------------------------------------------------------------------------

## Route a condition to the appropriate component or internal flag.
func _apply_single_condition(condition: String, target: Actor) -> void:
	if not is_instance_valid(target):
		return

	var cond_upper: String = condition.to_upper().strip_edges()

	match cond_upper:
		"STUNNED":
			# Delegate to the pre-existing StunComponent.
			var rounds: int = _parse_duration(duration_str)
			var seconds: float = float(maxi(1, rounds)) * 6.0
			if target.has_method("stun"):
				target.stun(seconds)

		"PARALYZED":
			# No dedicated component yet — set a property if the actor exposes one,
			# otherwise fall back to stun as a mechanical approximation until a
			# ParalyzedComponent is added.
			if target.has_method("set_paralyzed"):
				target.set_paralyzed(true)
			elif target.has_method("stun"):
				var rounds: int = _parse_duration(duration_str)
				target.stun(float(maxi(1, rounds)) * 6.0)

		"FRIGHTENED":
			# No dedicated component yet — mark via a property or signal.
			if "is_frightened" in target:
				target.set("is_frightened", true)

		"CHARMED":
			if "is_charmed" in target:
				target.set("is_charmed", true)

		"RESTRAINED":
			if "is_restrained" in target:
				target.set("is_restrained", true)

		"POISONED":
			if "is_poisoned" in target:
				target.set("is_poisoned", true)

		"BLINDED":
			if "is_blinded" in target:
				target.set("is_blinded", true)

		"DEAFENED":
			if "is_deafened" in target:
				target.set("is_deafened", true)

		"INCAPACITATED":
			if "is_incapacitated" in target:
				target.set("is_incapacitated", true)

		"PETRIFIED":
			if "is_petrified" in target:
				target.set("is_petrified", true)

		_:
			# Unknown condition — log and move on. Do not crash.
			push_warning("AbilityConditionApplicator: unknown condition '%s'" % condition)

func _remove_single_condition(condition: String, target: Actor) -> void:
	if not is_instance_valid(target):
		return

	var cond_upper: String = condition.to_upper().strip_edges()

	match cond_upper:
		"STUNNED":
			# StunComponent has no early-cancel API — the timer runs its course.
			# If StunComponent gains a cancel() method, call it here.
			pass

		"PARALYZED":
			if target.has_method("set_paralyzed"):
				target.set_paralyzed(false)

		"FRIGHTENED":
			if "is_frightened" in target:
				target.set("is_frightened", false)

		"CHARMED":
			if "is_charmed" in target:
				target.set("is_charmed", false)

		"RESTRAINED":
			if "is_restrained" in target:
				target.set("is_restrained", false)

		"POISONED":
			if "is_poisoned" in target:
				target.set("is_poisoned", false)

		"BLINDED":
			if "is_blinded" in target:
				target.set("is_blinded", false)

		"DEAFENED":
			if "is_deafened" in target:
				target.set("is_deafened", false)

		"INCAPACITATED":
			if "is_incapacitated" in target:
				target.set("is_incapacitated", false)

		"PETRIFIED":
			if "is_petrified" in target:
				target.set("is_petrified", false)

		_:
			pass

# ---------------------------------------------------------------------------
# Private — GameClockComponent tick
# ---------------------------------------------------------------------------

## Register a 6-second round tick on clock_actor if not already registered.
func _ensure_tick(clock_actor: Actor) -> void:
	if not is_instance_valid(clock_actor):
		return
	if not clock_actor.has_method("register_tick"):
		return
	var actor_id: int = clock_actor.get_instance_id()
	if actor_id in _tick_ids:
		return
	var tid: int = clock_actor.call("register_tick", _on_round_tick, 6.0)
	_tick_ids[actor_id] = tid

## Called by GameClockComponent every 6 seconds (1 round).
## Decrements duration, fires re-saves, removes expired conditions.
func _on_round_tick() -> void:
	var to_remove: Array[int] = []

	for tid in _active.keys():
		var entry: Variant = _active.get(tid)
		if entry == null:
			to_remove.append(tid)
			continue

		var target: Actor = entry.get("target") as Actor
		if not is_instance_valid(target) or target.is_dead:
			to_remove.append(tid)
			continue

		# Indefinite duration (-1) — only removed by re-save or dispel.
		var rounds_left: int = int(entry.get("rounds_left", -1))

		if rounds_left > 0:
			rounds_left -= 1
			entry["rounds_left"] = rounds_left
			_active[tid] = entry

		# Per-round re-save: if enabled and the target succeeds, end the condition.
		if allows_resave and _resolver != null:
			var caster: Actor = entry.get("caster") as Actor
			var result: SaveResult = _resolver.resolve(caster, target)
			if result.success:
				for condition in entry["conditions"]:
					_remove_single_condition(condition, target)
					condition_removed.emit(condition, target)
				to_remove.append(tid)
				continue

		# Natural expiry.
		if rounds_left == 0:
			for condition in entry["conditions"]:
				_remove_single_condition(condition, target)
				condition_removed.emit(condition, target)
			to_remove.append(tid)

	for tid in to_remove:
		_active.erase(tid)

# ---------------------------------------------------------------------------
# Private — duration parsing
# ---------------------------------------------------------------------------

## Convert a duration string to a round count.
## Returns -1 for indefinite/permanent durations.
func _parse_duration(s: String) -> int:
	var clean: String = s.strip_edges()

	# Exact match from table.
	if clean in DURATION_TABLE:
		return int(DURATION_TABLE[clean])

	# Case-insensitive scan.
	var lower: String = clean.to_lower()
	for key in DURATION_TABLE.keys():
		if lower == key.to_lower():
			return int(DURATION_TABLE[key])

	# Partial matches for common patterns.
	if lower.contains("concentration") or lower.contains("until cured") \
			or lower.contains("permanent") or lower.contains("until dispelled"):
		return -1
	if lower.contains("1 minute"):
		return 10
	if lower.contains("1 round") or lower.contains("next turn"):
		return 1

	# Unknown — default to 1 round rather than indefinite.
	push_warning("AbilityConditionApplicator: unknown duration '%s', defaulting to 1 round." % s)
	return 1
