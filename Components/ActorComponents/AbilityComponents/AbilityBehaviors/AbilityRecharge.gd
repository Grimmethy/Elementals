class_name AbilityRecharge
extends RefCounted

## Manages D&D ability recharge state.
##
## Parses the "recharge" field from ability data and handles:
##   - Always-available abilities (no recharge)
##   - Dice-roll recharges ("5-6", "6", "4-6") — rolls 1d6 each round
##   - Uses-per-day ("1/Day", "3/Day Each", etc.)
##   - Rest-based ("Short Rest", "Long Rest")
##
## GameClockComponent integration:
##   DICE_ROLL mode registers a ~6-second tick (one combat round) via
##   actor.register_tick(). The tick ID is stored and cleaned up in cleanup().
##   All other modes have no clock dependency.
##
## Usage:
##   var recharge := AbilityRecharge.from_string(data["recharge"], actor)
##   if recharge.is_available():
##       execute()
##       recharge.consume()

## Emitted when a dice-roll recharge succeeds or uses are replenished.
signal recharged

enum Mode {
	NONE,         ## Always available — no recharge tracking needed.
	DICE_ROLL,    ## Roll 1d6 each round; available when result meets threshold.
	USES_PER_DAY, ## Limited daily uses; resets on long rest.
	SHORT_REST,   ## Resets on short or long rest.
	LONG_REST,    ## Resets on long rest only.
}

var mode:          Mode = Mode.NONE
var _available:    bool = true
var _uses_max:     int  = 1
var _uses_current: int  = 1
var _roll_min:     int  = 5    # Minimum d6 result that triggers recharge.

# GameClockComponent tick handle. Stored so cleanup() can unregister it.
var _tick_id:      int  = -1
var _actor:        Node = null  # weak ref equivalent — checked with is_instance_valid

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Create an AbilityRecharge from the ability data's "recharge" string.
## Pass the actor when using DICE_ROLL mode so the tick can be registered.
## actor may be null for non-dice modes.
static func from_string(recharge_str: String, actor: Node = null) -> AbilityRecharge:
	var r := AbilityRecharge.new()
	r._actor = actor

	var s: String = recharge_str.strip_edges()

	if s == "" or s.to_lower() == "none":
		r.mode = Mode.NONE
		return r

	var lower: String = s.to_lower()

	# Dice-roll recharge: "5-6", "6", "4-6", "Recharge 5-6", etc.
	if lower.contains("5-6") or lower == "5" or lower == "6":
		r.mode     = Mode.DICE_ROLL
		r._roll_min = 5
		r._available = false
		r._register_dice_tick()
		return r
	if lower.contains("4-6") or lower == "4":
		r.mode      = Mode.DICE_ROLL
		r._roll_min  = 4
		r._available = false
		r._register_dice_tick()
		return r
	if lower == "recharge 6" or lower == "6":
		r.mode      = Mode.DICE_ROLL
		r._roll_min  = 6
		r._available = false
		r._register_dice_tick()
		return r

	# Short/Long rest.
	if lower.contains("short rest"):
		r.mode = Mode.SHORT_REST
		return r
	if lower.contains("long rest"):
		r.mode = Mode.LONG_REST
		return r

	# Uses per day: "1/Day", "3/Day Each", "2/Day", etc.
	if lower.contains("/day"):
		r.mode = Mode.USES_PER_DAY
		# Extract the number before "/Day".
		var slash_pos: int = lower.find("/day")
		var count_str: String = s.substr(0, slash_pos).strip_edges()
		# Handle formats like "Each 3/Day" — find the last integer token.
		var tokens: PackedStringArray = count_str.split(" ", false)
		for token in tokens:
			if token.is_valid_int():
				r._uses_max     = maxi(1, int(token))
				r._uses_current = r._uses_max
				break
		return r

	# Fallback: treat unknown values as always-available.
	r.mode = Mode.NONE
	return r

# ---------------------------------------------------------------------------
# State queries
# ---------------------------------------------------------------------------

## True if the ability can be used right now.
func is_available() -> bool:
	match mode:
		Mode.NONE:
			return true
		Mode.DICE_ROLL:
			return _available
		Mode.USES_PER_DAY:
			return _uses_current > 0
		Mode.SHORT_REST, Mode.LONG_REST:
			return _available
	return true

## Consume one use. Call immediately after a successful execute().
## In DICE_ROLL mode, marks unavailable until the next successful recharge roll.
func consume() -> void:
	match mode:
		Mode.NONE:
			pass  # Always-available abilities are never consumed.
		Mode.DICE_ROLL:
			_available = false
		Mode.USES_PER_DAY:
			_uses_current = maxi(0, _uses_current - 1)
		Mode.SHORT_REST, Mode.LONG_REST:
			_available = false

## Remaining uses. Only meaningful for USES_PER_DAY mode; returns 1 or 0
## for boolean-available modes, and 999 for NONE.
func uses_remaining() -> int:
	match mode:
		Mode.NONE:
			return 999
		Mode.DICE_ROLL, Mode.SHORT_REST, Mode.LONG_REST:
			return 1 if _available else 0
		Mode.USES_PER_DAY:
			return _uses_current
	return 0

# ---------------------------------------------------------------------------
# Rest handlers
# ---------------------------------------------------------------------------

## Call when the actor takes a rest. is_long_rest = true for long rests.
func on_rest(is_long_rest: bool) -> void:
	match mode:
		Mode.SHORT_REST:
			if not _available:
				_available = true
				recharged.emit()
		Mode.LONG_REST:
			if is_long_rest and not _available:
				_available = true
				recharged.emit()
		Mode.USES_PER_DAY:
			if is_long_rest and _uses_current < _uses_max:
				_uses_current = _uses_max
				recharged.emit()
		_:
			pass

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

## Unregister any GameClockComponent ticks. Call on actor death or ability removal.
func cleanup() -> void:
	if _tick_id >= 0 and is_instance_valid(_actor) and _actor.has_method("unregister_tick"):
		_actor.call("unregister_tick", _tick_id)
	_tick_id = -1

# ---------------------------------------------------------------------------
# Private — dice-roll recharge tick
# ---------------------------------------------------------------------------

## Register a ~6-second round tick with GameClockComponent via actor.register_tick().
func _register_dice_tick() -> void:
	if not is_instance_valid(_actor):
		return
	if not _actor.has_method("register_tick"):
		return
	# 6 seconds ≈ 1 D&D combat round at standard speed.
	_tick_id = _actor.call("register_tick", _on_recharge_tick, 6.0)

## Called each round by GameClockComponent. Rolls 1d6; recharges if >= _roll_min.
func _on_recharge_tick() -> void:
	if _available:
		return
	var roll: int = randi_range(1, 6)
	if roll >= _roll_min:
		_available = true
		recharged.emit()
