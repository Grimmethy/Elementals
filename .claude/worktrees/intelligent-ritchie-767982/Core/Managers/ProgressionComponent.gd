class_name ProgressionComponent
extends Node

var current_day: int = 1

func initialize(initial_day: int) -> void:
	current_day = initial_day

func advance_day(herd: Array[ActorData]) -> void:
	current_day += 1

	# Per-actor day logic is now polymorphic via `ActorData.tick_day(day)`.
	# `ActorData.tick_day()` handles the cross-cutting deselect / exhaustion
	# clear; `GoatData.tick_day()` adds aging + stamina restoration. Any
	# future subclass overrides its own per-day work.
	for actor in herd:
		if actor:
			actor.tick_day(current_day)

	GameEvents.day_advanced.emit(current_day)
