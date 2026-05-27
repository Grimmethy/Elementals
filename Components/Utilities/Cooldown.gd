class_name Cooldown
extends RefCounted

## Domain-agnostic cooldown primitive.
##
## Tracks remaining time and exposes a progress ratio for UI, but owns NO
## ticking logic — the caller advances it with whatever time source is
## appropriate for that context (_process delta, GameClockComponent tick, etc.).
##
## Usage:
##   var _cd := Cooldown.new()
##   _cd.start(7.5)                     # begin a 7.5-second cooldown
##   # in update(delta):
##   _cd.advance(delta)
##   if _cd.is_ready(): execute()
##
## Replaces the copy-paste pattern:
##   var _cooldown_left: float = 0.0
##   func update(delta): _cooldown_left = maxf(0.0, _cooldown_left - delta)
##   func can_execute(): return _cooldown_left <= 0.0

## Emitted exactly once when remaining time reaches zero.
## Only emitted by advance() — not by cancel().
signal ready

var _remaining: float = 0.0
var _duration:  float = 0.0

## Begin (or restart) a cooldown of duration seconds.
## duration <= 0 is treated as already-ready.
func start(duration: float) -> void:
	_duration  = maxf(0.0, duration)
	_remaining = _duration

## Advance the cooldown by delta seconds.
## Emits ready the first time remaining reaches zero.
func advance(delta: float) -> void:
	if _remaining <= 0.0:
		return
	var was_running: bool = _remaining > 0.0
	_remaining = maxf(0.0, _remaining - delta)
	if was_running and _remaining <= 0.0:
		ready.emit()

## True when no cooldown is running (remaining == 0).
## Also true before start() has ever been called.
func is_ready() -> bool:
	return _remaining <= 0.0

## Seconds remaining. 0.0 when ready.
func remaining() -> float:
	return _remaining

## Normalised completion fraction: 0.0 = just started, 1.0 = complete.
## Always 1.0 when is_ready(). Suitable for progress bars and UI fill.
## Replaces inline formulas like: 1.0 - (_cooldown / weapon_data.cooldown)
func progress() -> float:
	if _duration <= 0.0:
		return 1.0
	return 1.0 - (_remaining / _duration)

## Stop a running cooldown without emitting ready.
## Leaves the cooldown in the "ready" state.
func cancel() -> void:
	_remaining = 0.0
