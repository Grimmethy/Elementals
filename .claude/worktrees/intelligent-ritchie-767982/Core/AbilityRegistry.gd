## Centralized registry of every AbilityAction subclass in the project.
## Scans Components/ActorComponents/AbilityComponents/ on boot, instantiates
## each candidate script against a throwaway host pair (Actor + Node) to read
## its `ability_name`, then frees the host. The resulting StringName -> Script
## cache is what consumers query at runtime.
##
## Why this exists:
##   * Eliminates the inline reflection at UI/MainMenu.gd:67-100 that did
##     instantiate-and-free cycles every menu open.
##   * Gives the Mimic (and any future copier-style actor) a safe way to
##     instantiate a copy of a stolen ability without sharing the RefCounted
##     AbilityAction instance — see `instantiate_for()` below.
##
## Registration: project.godot autoload as `AbilityRegistry`.
class_name AbilityRegistryClass
extends Node

## Folder scanned on _init. Anything not matching the AbilityAction filter is
## ignored (so it is safe to add helper scripts to this folder later).
const ABILITY_DIR: String = "res://Components/ActorComponents/AbilityComponents/"

## Filenames in ABILITY_DIR that must NOT be treated as concrete abilities.
## AbilityAction is the abstract base; AbilityComponent is the orchestrator.
const _SKIP_FILES: Array[String] = [
	"AbilityAction.gd",
	"AbilityComponent.gd",
]

## ability_name (StringName) -> Script. Built once in _init().
var _by_name: Dictionary = {}

func _init() -> void:
	_build_cache()

func _build_cache() -> void:
	var dir: DirAccess = DirAccess.open(ABILITY_DIR)
	if dir == null:
		push_warning("[AbilityRegistry] Could not open %s — registry empty." % ABILITY_DIR)
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(".gd"):
			continue
		if file_name in _SKIP_FILES:
			continue

		var script: Script = load(ABILITY_DIR + file_name) as Script
		if script == null:
			continue

		# Sanity-check: only register scripts whose `new(actor, component)` is an
		# AbilityAction. This keeps the registry resilient if a non-ability
		# script ever lands in this folder.
		var temp_actor: Actor = Actor.new()
		var temp_component: Node = Node.new()
		var probe: Variant = null
		# Some ability scripts assume a non-null actor with valid setup state.
		# Wrap the probe in error suppression so a single bad ability does not
		# brick the registry.
		probe = script.new(temp_actor, temp_component)
		if probe is AbilityAction and "ability_name" in probe and not probe.ability_name.is_empty():
			var key: StringName = StringName(probe.ability_name)
			_by_name[key] = script
		# RefCounted ability instances clean themselves up; the throwaway
		# host nodes are not in any tree, so free() is safe.
		temp_actor.free()
		temp_component.free()
	dir.list_dir_end()

## Returns the StringName -> Script map. Read-only view; the caller should
## not mutate the returned Dictionary (it is the cache itself).
func get_ability_map() -> Dictionary:
	return _by_name

## Returns every registered ability name as an Array[StringName].
func get_ability_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _by_name.keys():
		names.append(key)
	return names

## Returns the Script for a given ability name, or null if unknown.
func get_ability_script(ability_name: StringName) -> Script:
	return _by_name.get(ability_name, null)

## Instantiate a fresh AbilityAction for a specific actor + component pair.
## Returns null if the name is unknown or the script does not produce an
## AbilityAction. Use this whenever you need to clone a stolen skill onto a
## new actor — sharing the source instance would cross-wire its `actor` field.
func instantiate_for(ability_name: StringName, actor: Node3D, component: Node) -> AbilityAction:
	var script: Script = get_ability_script(ability_name)
	if script == null:
		return null
	var instance: Variant = script.new(actor, component)
	if instance is AbilityAction:
		return instance as AbilityAction
	return null
