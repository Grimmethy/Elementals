## AI controller for the Mimic creature.
##
## Composes the base ActorAIController FSM (idle/roam/chase/attack/...) with
## three Mimic-specific behaviors:
##
##   1. TileSignal-based proximity tracking — maintains a `_nearby_actors`
##      cache via a continuous trigger of radius = `mimic_data.scan_radius`.
##   2. GameClock-driven scan tick at `mimic_data.scan_interval` (default 2Hz)
##      that decides when to morph / revert / copy.
##   3. Visual morph + skill-copy via CreatureMorphComponent and
##      SkillCopyComponent, both added to the actor at setup time.
##
## Critical rules (per AGENTS.md):
##   - NO Timer.new(). All cadence is GameClock.register_tick().
##   - NO per-frame distance math. Proximity comes from TileSignalComponent.
##   - AbilityActions are NEVER shared — SkillCopyComponent re-instantiates
##     them through AbilityRegistry so each clone is bound to the Mimic.
class_name MimicController
extends ActorAIController

## Cached MimicData (the actor's `_data` cast). Lazy-resolved.
var _mimic_data: MimicData

## Snapshot of perceived-as-nearby actors maintained by TileSignal triggers.
## Cleaned of invalid instances inside `_on_scan_tick`.
var _nearby_actors: Array[Actor] = []

## The continuous trigger registered with TileSignalComponent for the scan
## radius. Used to update center on tile_changed and to clean up on exit.
var _scan_trigger: Dictionary = {}

## ID of the GameClock tick callback driving `_on_scan_tick`.
var _scan_tick_id: int = -1

## Tracks how long the current morph has been active (seconds). Compared
## against `mimic_data.morph_duration` every scan tick. Reset on morph and on
## revert.
var _morph_elapsed: float = 0.0

## Composite components added during _ready.
var _morph_component: CreatureMorphComponent
var _skill_copy_component: SkillCopyComponent

## Persistent RNG so target selection is reproducible per controller.
var _mimic_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	_mimic_rng.randomize()
	# Wait one frame so Actor._setup_components has wired ability_component
	# and visual_component before we attach the morph/copy helpers.
	call_deferred("_setup_mimic_systems")

func _setup_mimic_systems() -> void:
	if not actor:
		return
	_mimic_data = actor.get("_data") as MimicData
	if _mimic_data == null:
		# No MimicData on this actor — fall back to base AI without morph/copy.
		# This branch keeps the controller safe to attach to any Actor.
		return

	# Attach the morph + skill-copy helpers to the actor.
	_morph_component = CreatureMorphComponent.new()
	_morph_component.name = "CreatureMorphComponent"
	actor.add_child(_morph_component)
	_morph_component.setup(actor)

	_skill_copy_component = SkillCopyComponent.new()
	_skill_copy_component.name = "SkillCopyComponent"
	actor.add_child(_skill_copy_component)
	_skill_copy_component.setup(actor)

	_register_scan_trigger()
	_register_scan_tick()

## Register the proximity trigger that maintains the nearby-actors cache.
## Uses the actor's current ground tile as the center; we update the center
## on `tile_changed` below so the trigger follows the Mimic.
func _register_scan_trigger() -> void:
	if not actor or not actor._arena_grid:
		return
	var signals: Node = actor._arena_grid.get("tile_signals")
	if signals == null:
		return
	var tic: Node = actor.get("tile_interaction_component")
	var current_tile = tic.get_ground_tile() if tic else null
	if current_tile == null:
		# Try again next frame — actor may still be settling on the grid.
		call_deferred("_register_scan_trigger")
		return
	_scan_trigger = signals.register_trigger(
		current_tile,
		_mimic_data.scan_radius,
		_on_scan_trigger_callback,
		{"continuous": false, "owner_id": actor.get_instance_id()}
	)
	# Use the enter/exit signals to maintain the nearby cache symmetrically.
	if not signals.trigger_activated.is_connected(_on_scan_trigger_activated):
		signals.trigger_activated.connect(_on_scan_trigger_activated)
	if not signals.trigger_deactivated.is_connected(_on_scan_trigger_deactivated):
		signals.trigger_deactivated.connect(_on_scan_trigger_deactivated)
	# Move the trigger center whenever the Mimic walks onto a new tile.
	if actor.has_signal("tile_changed") and not actor.tile_changed.is_connected(_on_mimic_tile_changed):
		actor.tile_changed.connect(_on_mimic_tile_changed)

func _on_scan_trigger_callback(_other: Node3D, _meta: Dictionary) -> void:
	# Single-fire callback path. We rely on the enter/exit signals (below) to
	# build the cache symmetrically; this no-op exists because
	# register_trigger() requires a Callable.
	pass

func _on_scan_trigger_activated(trigger: Dictionary, other: Node3D) -> void:
	# TileSignalComponent emits this for EVERY registered trigger; filter to
	# our own. Identity compare on the trigger dictionary is safe — see
	# TileSignalComponent.remove_trigger() for the same pattern.
	# Param type matches the signal declaration (`actor: Node3D`); Actor
	# narrowing happens inside `_is_valid_target` to avoid runtime narrowing
	# errors on non-Actor Node3D candidates.
	if trigger != _scan_trigger:
		return
	if not _is_valid_target(other):
		return
	var actor_other: Actor = other as Actor
	if not _nearby_actors.has(actor_other):
		_nearby_actors.append(actor_other)

func _on_scan_trigger_deactivated(trigger: Dictionary, other: Node3D) -> void:
	if trigger != _scan_trigger:
		return
	if other is Actor:
		_nearby_actors.erase(other as Actor)

func _on_mimic_tile_changed(new_tile) -> void:
	if _scan_trigger.is_empty() or not actor or not actor._arena_grid:
		return
	var signals: Node = actor._arena_grid.get("tile_signals")
	if signals:
		signals.update_trigger_center(_scan_trigger, new_tile)

## Register the periodic scan callback with the centralized GameClock. NEVER
## use Timer.new() here — see AGENTS.md "do NOT add Timer nodes to actors".
func _register_scan_tick() -> void:
	if _scan_tick_id != -1 or not actor:
		return
	_scan_tick_id = actor.register_tick(_on_scan_tick, _mimic_data.scan_interval)

## Heart of the Mimic loop. Decides whether to morph + copy or whether to
## revert. Runs at `mimic_data.scan_interval` seconds (default 0.5).
func _on_scan_tick() -> void:
	if not is_instance_valid(actor) or actor.is_dead:
		return

	# Prune any nearby actors that died or left the tree between ticks.
	for i in range(_nearby_actors.size() - 1, -1, -1):
		if not _is_valid_target(_nearby_actors[i]):
			_nearby_actors.remove_at(i)

	# Branch 1: currently morphed — count elapsed time, revert if expired.
	if _morph_component and _morph_component.is_morphed:
		_morph_elapsed += _mimic_data.scan_interval
		if _morph_elapsed >= _mimic_data.morph_duration:
			_morph_component.revert()
			if _skill_copy_component:
				_skill_copy_component.restore()
			_morph_elapsed = 0.0
		return

	# Branch 2: base form + at least one valid target nearby — pick one
	# (uniform random, filtered by `disallowed_target_types`) and morph.
	if _nearby_actors.is_empty():
		return
	var target: Actor = _pick_morph_target()
	if target == null:
		return
	if _morph_component:
		_morph_component.morph_into(target)
	if _skill_copy_component:
		_skill_copy_component.copy_from(target, _mimic_data.skill_copy_limit)
	_morph_elapsed = 0.0

## Filters `_nearby_actors` against the Mimic's disallow list (mimic, scarecrow
## by default) and returns a uniform random pick, or null if no candidates.
func _pick_morph_target() -> Actor:
	var candidates: Array[Actor] = []
	for candidate in _nearby_actors:
		if not _is_valid_target(candidate):
			continue
		var actor_type: StringName = _resolve_actor_type(candidate)
		if _mimic_data.disallowed_target_types.has(actor_type):
			continue
		candidates.append(candidate)
	if candidates.is_empty():
		return null
	return candidates[_mimic_rng.randi_range(0, candidates.size() - 1)]

## Defensive validity check used by both the trigger handlers and the scan
## tick. Excludes self, freed instances, dead actors, and non-Actor nodes.
func _is_valid_target(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate):
		return false
	if candidate == actor:
		return false
	if not candidate is Actor:
		return false
	if (candidate as Actor).is_dead:
		return false
	return true

## Resolve the type identifier a target advertises. Prefers the `_data`
## resource's `get_actor_type()`, then the actor's `element_type` field as a
## fallback so Goblin/Farmer/Fire/Water (which carry no ActorData today)
## still report a stable type.
func _resolve_actor_type(candidate: Node3D) -> StringName:
	if "_data" in candidate and candidate._data is ActorData:
		return StringName(candidate._data.get_actor_type())
	if "element_type" in candidate:
		return StringName(candidate.element_type)
	return &"unknown"

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_EXIT_TREE:
		# Best-effort cleanup. Failures here cannot prevent the actor from
		# being freed.
		if _scan_tick_id != -1 and is_instance_valid(actor):
			actor.unregister_tick(_scan_tick_id)
			_scan_tick_id = -1
		if not _scan_trigger.is_empty() and actor and actor._arena_grid:
			var signals: Node = actor._arena_grid.get("tile_signals")
			if signals:
				signals.remove_trigger(_scan_trigger)
		_scan_trigger = {}
