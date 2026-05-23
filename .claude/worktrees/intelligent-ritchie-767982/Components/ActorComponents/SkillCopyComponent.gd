## Generic skill-copy helper. Clones AbilityActions from a donor actor onto the
## owning actor, capped at a configurable limit. Restores the original set on
## `restore()`.
##
## Why a dedicated component:
##   - Cleanly separates the "what skills did I copy" bookkeeping from any
##     individual AbilityAction implementation.
##   - Reusable for any creature that needs to lift abilities at runtime (a
##     future Doppelganger or Trickster shares the same shape).
##
## Implementation notes:
##   - AbilityAction is RefCounted and actor-bound. Sharing the donor's
##     instance would cross-wire `action.actor` to the donor. We instantiate
##     fresh actions through AbilityRegistry so they are bound to *this*
##     actor's AbilityComponent.
##   - The component does NOT own a tick — the caller decides when to copy
##     and when to restore.
class_name SkillCopyComponent
extends Node

signal copied(donor: Node3D, ability_names: Array)
signal restored()

## Owning actor that receives the copied actions.
var actor: Actor

## Cache of `ability_name` (StringName) for every copied action this
## component currently has on the owner's AbilityComponent. Used by
## `restore()` to find-and-remove only the copies, never the originals.
var _copied_names: Array[StringName] = []

func setup(p_actor: Actor) -> void:
	actor = p_actor

## Returns true if there is at least one copy currently installed.
func has_copies() -> bool:
	return _copied_names.size() > 0

## Returns the list of currently-copied ability names.
func get_copied_names() -> Array[StringName]:
	return _copied_names.duplicate()

## Copy up to `limit` AbilityActions from `donor` onto the owning actor.
## Skips abilities the actor already has (by name) and abilities that
## AbilityRegistry does not know about (defensive — should never happen for
## abilities under Components/ActorComponents/AbilityComponents/).
##
## Returns the list of ability names actually copied this call.
func copy_from(donor: Node3D, limit: int) -> Array[StringName]:
	var copied_this_call: Array[StringName] = []
	if not is_instance_valid(actor) or not is_instance_valid(donor):
		return copied_this_call
	if limit <= 0:
		return copied_this_call
	if not "ability_component" in donor:
		return copied_this_call
	var donor_ability_component: Node = donor.ability_component
	if donor_ability_component == null:
		return copied_this_call
	var own_ability_component: Node = actor.ability_component
	if own_ability_component == null:
		return copied_this_call

	# Build the set of existing names on self so we don't double-add.
	var existing_names: Dictionary = {}
	for existing_action in own_ability_component.actions:
		if "ability_name" in existing_action:
			existing_names[StringName(existing_action.ability_name)] = true

	var registry: Node = actor.get_node_or_null("/root/AbilityRegistry")
	if registry == null:
		# Without the registry we cannot safely clone — return empty.
		return copied_this_call

	for action in donor_ability_component.actions:
		if copied_this_call.size() >= limit:
			break
		if not "ability_name" in action or action.ability_name.is_empty():
			continue
		var key: StringName = StringName(action.ability_name)
		if existing_names.has(key):
			continue
		var clone: AbilityAction = registry.instantiate_for(key, actor, own_ability_component)
		if clone == null:
			continue
		own_ability_component.add_action(clone)
		_copied_names.append(key)
		copied_this_call.append(key)
		existing_names[key] = true

	if copied_this_call.size() > 0:
		copied.emit(donor, copied_this_call)
	return copied_this_call

## Remove every copied action from the owner's AbilityComponent. Originals are
## untouched — only entries whose `ability_name` is in `_copied_names` are
## removed. Idempotent.
func restore() -> void:
	if not has_copies():
		return
	if not is_instance_valid(actor) or actor.ability_component == null:
		_copied_names.clear()
		return
	# Build a multiset of names-to-remove so we remove the exact count we
	# inserted, in case the donor and the actor shared a name elsewhere.
	var remove_budget: Dictionary = {}
	for name in _copied_names:
		remove_budget[name] = remove_budget.get(name, 0) + 1

	var actions: Array = actor.ability_component.actions
	# Iterate in reverse so removals don't shift indices we still need.
	for i in range(actions.size() - 1, -1, -1):
		var action = actions[i]
		if not "ability_name" in action:
			continue
		var key: StringName = StringName(action.ability_name)
		if remove_budget.get(key, 0) > 0:
			actions.remove_at(i)
			remove_budget[key] -= 1
	_copied_names.clear()
	restored.emit()
