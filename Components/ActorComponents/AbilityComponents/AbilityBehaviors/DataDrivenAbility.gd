class_name DataDrivenAbility
extends AbilityAction

## Wires all AbilityBehavior components together from a single data dictionary
## entry. Allows abilities that have no unique logic to be instantiated without
## a custom class — approximately 60% of the 270+ ability data library.
##
## Reads from: AbilityList.ABILITIES["CATEGORY"]["AbilityName"]
##
## Does NOT cover abilities with unique state machines (GoatCharge, MimicShapechange,
## NimbleEscape, RedirectAttack). See Tier 3 in PLAN.md.
##
## Registration: DataDrivenAbility instances are registered via
## CharacterBuildComponent._ABILITY_REGISTRY and _apply_ability(). See PLAN.md
## "Confirmed Component Contracts → CharacterBuildComponent" for details.
##
## Usage:
##   var ability := DataDrivenAbility.from_dict(
##       "Stench",
##       AbilityList.ABILITIES["STATUS_EFFECTS"]["Stench"],
##       actor, component, clock_actor, tile_signal
##   )
##   actor.ability_component.add_action(ability)

## The data dictionary entry this ability was built from.
var data: Dictionary = {}

## The ability name key from the data library.
var entry_name: String = ""

# -- Behavior components (null when the ability doesn't need them) ----------

var _recharge:   AbilityRecharge           = null
var _area_query: AbilityAreaQuery          = null
var _resolver:   AbilitySaveResolver       = null
var _damage:     AbilityDamageApplicator   = null
var _conditions: AbilityConditionApplicator = null

# -- Internal state ---------------------------------------------------------

## True for persistent aura-type abilities (registered trigger, ongoing effect).
var _is_aura: bool = false

## TileSignalComponent reference for persistent triggers.
var _tile_signal: Node = null

## Persistent trigger handle returned by AbilityAreaQuery. Empty if no aura.
var _aura_trigger: Dictionary = {}

## The actor whose register_tick() is used for clock operations.
var _clock_actor: Actor = null

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Instantiate a DataDrivenAbility from a data dictionary entry.
## entry_name is the key used for display names and logging.
## clock_actor must expose register_tick() / unregister_tick().
## tile_signal is the actor's TileSignalComponent node (may be null for non-AoE).
static func from_dict(
	p_entry_name:  String,
	p_data:        Dictionary,
	p_actor:       Actor,
	p_component:   Node,
	p_clock_actor: Actor   = null,
	p_tile_signal: Node    = null
) -> DataDrivenAbility:
	var a := DataDrivenAbility.new(p_actor, p_component)
	a.entry_name   = p_entry_name
	a.data         = p_data
	a._clock_actor = p_clock_actor if p_clock_actor != null else p_actor
	a._tile_signal = p_tile_signal

	# UI metadata.
	a.ability_name        = str(p_data.get("name", p_entry_name))
	a.ability_description = str(p_data.get("description", ""))
	a.ability_usage       = str(p_data.get("action_type", ""))

	# Build behavior components from data.
	a._recharge = AbilityRecharge.from_string(
		str(p_data.get("recharge", "")),
		a._clock_actor
	)

	var saving_throw: String = str(p_data.get("saving_throw", "")).strip_edges().to_upper()
	if saving_throw != "" and saving_throw != "NONE" and saving_throw != "N/A":
		a._resolver = AbilitySaveResolver.from_dict(p_data)

	var damage_dice: String = str(p_data.get("damage_dice", "")).strip_edges()
	if damage_dice != "" and not (damage_dice.to_lower() in ["none", "n/a"]):
		a._damage = AbilityDamageApplicator.from_dict(p_data)

	var conditions_raw: Variant = p_data.get("conditions_applied", [])
	var has_conditions: bool = (conditions_raw is Array and not (conditions_raw as Array).is_empty()) \
		or (conditions_raw is String and str(conditions_raw).strip_edges() != "")
	if has_conditions:
		a._conditions = AbilityConditionApplicator.from_dict(p_data, a._resolver)

	# Determine targeting from range + action_type.
	var action_type: String = str(p_data.get("action_type", "")).to_lower()
	var range_str: String   = str(p_data.get("range", "Self"))
	a._area_query = AbilityAreaQuery.from_range_string(range_str,
		AbilityAreaQuery.TeamFilter.ENEMIES)

	# Detect aura-type abilities (Legendary / Passive with persistent radius).
	a._is_aura = action_type.contains("legendary") \
		or action_type.contains("passive") \
		or action_type.contains("aura")

	return a

# ---------------------------------------------------------------------------
# AbilityAction interface
# ---------------------------------------------------------------------------

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)

func can_execute(type: String) -> bool:
	if actor == null or actor.is_dead:
		return false
	# Passive / aura abilities activate differently — not via execute().
	if _is_aura:
		return false
	# Check action type matches the trigger.
	var action_type: String = str(data.get("action_type", "action")).to_lower()
	if action_type.contains("bonus action") and type != "ability_bonus":
		return false
	if action_type.contains("reaction") and type != "ability_reaction":
		return false
	if not action_type.contains("bonus") and not action_type.contains("reaction"):
		if type != "ability_r" and type != "ability_action":
			return false
	if _recharge != null and not _recharge.is_available():
		return false
	return true

func execute(type: String, value = null) -> void:
	if not can_execute(type):
		return

	# One-shot ability: get targets, resolve saves, apply damage + conditions.
	var aim_tile: Object = null
	if value is Vector3:
		aim_tile = _world_pos_to_tile(value)

	var targets: Array[Actor] = _area_query.get_targets_oneshot(actor, _tile_signal, aim_tile)

	if targets.is_empty():
		_emit_message("%s: no targets in range." % ability_name)
		if _recharge != null:
			_recharge.consume()
		return

	for target in targets:
		_apply_to_target(target)

	if _recharge != null:
		_recharge.consume()

	_emit_message("%s used %s on %d target(s)." % [actor.name, ability_name, targets.size()])

func update(_delta: float) -> void:
	pass  # All timing routed through GameClockComponent.

func on_damage_taken() -> void:
	# Break concentration if the ability requires it.
	var duration_str: String = str(data.get("duration", "")).to_lower()
	if duration_str.contains("concentration"):
		_end_aura()

# ---------------------------------------------------------------------------
# Aura management
# ---------------------------------------------------------------------------

## Activate a persistent aura. Call after the ability is registered.
## For aura abilities, call this instead of execute().
func start_aura() -> void:
	if not _is_aura or _area_query == null or _tile_signal == null:
		return
	if not _aura_trigger.is_empty():
		return  # already running

	_aura_trigger = _area_query.register_persistent(
		actor,
		_tile_signal,
		_on_aura_enter,
		_on_aura_exit
	)

	# Connect tile_changed to keep the trigger centered as the actor moves.
	if actor.has_signal("tile_changed") and not actor.is_connected("tile_changed", _on_tile_changed):
		actor.tile_changed.connect(_on_tile_changed)

## Deactivate a persistent aura.
func _end_aura() -> void:
	if _aura_trigger.is_empty():
		return
	_area_query.release_persistent(_tile_signal, _aura_trigger)
	_aura_trigger = {}
	if actor.has_signal("tile_changed") and actor.is_connected("tile_changed", _on_tile_changed):
		actor.tile_changed.disconnect(_on_tile_changed)

func _on_tile_changed(new_tile: Object) -> void:
	if not _aura_trigger.is_empty():
		_area_query.update_center(_tile_signal, _aura_trigger, new_tile)

func _on_aura_enter(target: Node, _metadata: Dictionary) -> void:
	if not (target is Actor):
		return
	if not _area_query._passes_team_filter(actor, target as Actor):
		return
	_apply_to_target(target as Actor)

func _on_aura_exit(_target: Node, _metadata: Dictionary) -> void:
	pass  # Override in subclasses for "remove condition on exit" auras.

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

## Unregister all clock ticks and tile triggers. Call on actor death.
func cleanup() -> void:
	_end_aura()
	if _recharge != null:
		_recharge.cleanup()
	if _conditions != null:
		_conditions.cleanup()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Apply saves, damage, and conditions to a single target.
func _apply_to_target(target: Actor) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return

	var direction: Vector3 = (target.global_position - actor.global_position).normalized()
	var save_result: SaveResult = null

	# Saving throw.
	if _resolver != null:
		save_result = _resolver.resolve(actor, target)
	else:
		# No save required — treat as automatic hit.
		save_result = SaveResult.new()
		save_result.success = false  # false = save failed = effect applies

	# Damage.
	if _damage != null:
		var half_on_save: bool = bool(data.get("half_damage_on_save", false))
		var multiplier: float  = 1.0
		if save_result.success:
			multiplier = 0.5 if half_on_save else 0.0
		var dealt: int = _damage.apply(actor, target, multiplier, direction)
		if dealt > 0:
			AbilityVisualSpawner.popup_text(target, str(dealt), Color(1, 0.3, 0.3))

	# Conditions.
	if _conditions != null and not save_result.success:
		_conditions.apply(actor, target, save_result, _clock_actor)

	# Visual.
	var damage_type: String = str(data.get("damage_type", "normal")).to_lower()
	var effect_color: Color = _color_for_type(damage_type)
	AbilityVisualSpawner.burst(target, 0.6, effect_color, 0.5)

## Convert a world Vector3 to a tile Object using the arena grid.
func _world_pos_to_tile(world_pos: Vector3) -> Object:
	var arena_val: Variant = actor.get("_arena_grid")
	if arena_val == null:
		return null
	if arena_val.has_method("get_tile_at_world_position"):
		return arena_val.call("get_tile_at_world_position", world_pos)
	return null

## Return a representative color for a damage type (for visuals).
func _color_for_type(type: String) -> Color:
	match type:
		"fire":       return Color(1.0, 0.4, 0.1, 0.9)
		"cold":       return Color(0.4, 0.8, 1.0, 0.9)
		"lightning":  return Color(0.9, 0.9, 0.2, 0.9)
		"acid":       return Color(0.3, 0.9, 0.1, 0.9)
		"poison":     return Color(0.5, 0.85, 0.4, 0.9)
		"psychic":    return Color(0.8, 0.3, 0.9, 0.9)
		"necrotic":   return Color(0.3, 0.0, 0.4, 0.9)
		"radiant":    return Color(1.0, 0.95, 0.5, 0.9)
		"thunder":    return Color(0.5, 0.6, 1.0, 0.9)
		_:            return Color(0.9, 0.9, 0.9, 0.8)

func _emit_message(text: String) -> void:
	print("[DataDrivenAbility] ", text)
	if actor and actor.get_node_or_null("/root/QuestEvents"):
		QuestEvents.message(text)
