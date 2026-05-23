## Visual + identity morph helper. Snapshots an actor's original ActorData on
## `morph_into(target)`, then swaps `ActorVisualComponent.setup_visuals(...)` to
## the target's data. `revert()` restores the snapshot.
##
## Designed to be reusable by any actor that needs short-duration mimicry —
## the Mimic is the first consumer but the component is intentionally
## type-agnostic.
##
## Timing is the CALLER's responsibility — this component does NOT own a
## GameClock callback. Drive `revert()` from your own scan tick (the Mimic
## controller does this) so you stay in control of cadence and saves.
class_name CreatureMorphComponent
extends Node

signal morphed(target: Node3D)
signal reverted()

## Reference to the owning actor.
var actor: Actor

## True while the actor is morphed into a target.
var is_morphed: bool = false

## Cached original ActorData captured at the first morph call. We restore
## this on revert so the actor's "true" identity is never lost.
var _original_data: ActorData = null

## Type identifier of the current morph target ("goat", "goblin", ...).
## Empty when not morphed.
var _current_morph_target_type: StringName = &""

func setup(p_actor: Actor) -> void:
	actor = p_actor

## Morph `actor` into `target`. The target's `_data` resource drives the visual
## swap via ActorVisualComponent.setup_visuals(). No-ops on null/invalid input
## or on a target with no `_data` (Goblin, Farmer, etc.).
##
## Returns the type identifier swapped into, or empty StringName on no-op.
func morph_into(target: Node3D) -> StringName:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return &""
	if not "_data" in target:
		return &""
	var target_data: ActorData = target._data
	if target_data == null:
		return &""
	# Snapshot the first time we morph — never overwrite the true identity.
	if _original_data == null:
		_original_data = actor._data
	# Hand off to the visual component's polymorphic entry point.
	if actor.visual_component:
		actor.visual_component.setup_visuals(target_data)
	_current_morph_target_type = StringName(target_data.get_actor_type())
	is_morphed = true
	morphed.emit(target)
	return _current_morph_target_type

## Restore the actor's original visuals. Idempotent — safe to call when not
## morphed (no-op).
func revert() -> void:
	if not is_morphed:
		return
	if actor and actor.visual_component and _original_data != null:
		actor.visual_component.setup_visuals(_original_data)
	_current_morph_target_type = &""
	is_morphed = false
	reverted.emit()

## Returns the type identifier of the current morph target, or empty if not
## morphed.
func get_current_morph_type() -> StringName:
	return _current_morph_target_type
