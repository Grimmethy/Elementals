## Centralized actor spawn dispatcher.
##
## Replaces the `match type` arm in ArenaSpawnerComponent.spawn_actor_at_tile().
## Every concrete actor type registers its scene here on boot so adding a new
## creature (e.g. Mimic) does not require editing any hardcoded match block.
##
## This is a plain Node so it can be instantiated and held by ArenaSpawner;
## a future patch may promote it to an autoload, but the current consumer is
## arena-scoped (one ArenaSpawner per arena) so component composition is enough.
class_name ActorFactory
extends Node

## Registered actor scenes keyed by StringName actor type ("goat", "mimic", ...).
var _scenes: Dictionary = {}

## Register (or overwrite) the PackedScene used to spawn a given actor type.
## Use a StringName key. Passing null clears the registration.
func register(actor_type: StringName, scene: PackedScene) -> void:
	if scene == null:
		_scenes.erase(actor_type)
		return
	_scenes[actor_type] = scene

## Returns the registered PackedScene for an actor type, or null if unknown.
func get_scene(actor_type: StringName) -> PackedScene:
	return _scenes.get(actor_type, null)

## Returns true if this actor type is known to the factory.
func has_type(actor_type: StringName) -> bool:
	return _scenes.has(actor_type)

## Returns every registered actor type. Useful for menus and debug HUDs.
func get_types() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _scenes.keys():
		out.append(key)
	return out

## Instantiate the registered scene and parent it under `parent`. Position is
## applied directly — the caller is responsible for any tile-surface lift.
## Returns the spawned Actor (or null if the actor type is unregistered or
## the registered scene does not produce an Actor).
func spawn(actor_type: StringName, parent: Node3D, position: Vector3) -> Actor:
	var scene: PackedScene = get_scene(actor_type)
	if scene == null:
		return null
	var node: Node3D = scene.instantiate()
	if node == null:
		return null
	parent.add_child(node)
	node.transform.origin = position
	return node as Actor
