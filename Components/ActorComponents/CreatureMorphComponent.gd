class_name CreatureMorphComponent
extends Node

signal morphed(target: Node3D)
signal reverted()
signal object_form_changed(active: bool)

var actor: Actor
var is_morphed: bool = false
var is_object_form: bool = false

var _original_body: Node3D = null
var _morphed_body: Node3D = null
var _current_morph_target_type: StringName = &""
var _original_body_scale: Vector3 = Vector3.ONE
var _object_form_speed_backup: float = 1.0

# Adhesive trait (D&D 5e Mimic): while in object form, any actor that comes
# within touch_range is grappled to the mimic. Grappled targets get a tick
# to attempt a Strength check (DC 13) to break free. We register a single
# slow tick when object form activates and tear it down when it deactivates.
const ADHESIVE_TOUCH_RANGE: float = 1.6
const ADHESIVE_DEFAULT_ESCAPE_DC: int = 13
var _adhesive_tick_id: int = -1
var _grappled_targets: Array[Actor] = []

func setup(p_actor: Actor) -> void:
	actor = p_actor
	if actor:
		_original_body = actor.get_node_or_null("Body")
		if _original_body:
			_original_body_scale = _original_body.scale

func morph_into(target: Node3D) -> StringName:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return &""
	if target == actor:
		return &""
	if is_object_form:
		exit_object_form()

	var target_body: Node3D = target.get_node_or_null("Body")
	if target_body == null:
		return &""

	if is_morphed:
		revert()

	_morphed_body = target_body.duplicate()
	_morphed_body.name = "MimicMorphedBody"

	if _original_body:
		_original_body.visible = false
		# Preserve the target body's intrinsic scale + rotation (so a Goat looks
		# Goat-sized, a Goblin Goblin-sized, etc). Only re-anchor its origin to
		# wherever the Mimic's own Body sits in the actor.
		# NOTE: previously this assigned _original_body.transform wholesale,
		# which overwrote the target's scale with the Mimic's body scale and
		# made morphed forms appear oversized.
		_morphed_body.transform.origin = _original_body.transform.origin
	actor.add_child(_morphed_body)
	_set_visual_body(_morphed_body)

	_current_morph_target_type = _resolve_target_type(target)
	actor.set_meta("mimic_morph_type", String(_current_morph_target_type))
	is_morphed = true
	morphed.emit(target)
	return _current_morph_target_type

func revert() -> void:
	if not is_morphed:
		return

	if is_instance_valid(_morphed_body):
		_morphed_body.queue_free()
	_morphed_body = null

	if is_instance_valid(_original_body):
		_original_body.visible = true
		_set_visual_body(_original_body)

	_current_morph_target_type = &""
	if actor:
		actor.set_meta("mimic_morph_type", "")
	is_morphed = false
	reverted.emit()

func get_current_morph_type() -> StringName:
	return _current_morph_target_type

func enter_object_form() -> bool:
	if not is_instance_valid(actor):
		return false
	if is_object_form:
		return true
	if _original_body == null:
		_original_body = actor.get_node_or_null("Body")
	if _original_body == null:
		return false

	if is_morphed:
		revert()

	_original_body.visible = true
	_set_visual_body(_original_body)
	_original_body_scale = _original_body.scale
	_original_body.scale = Vector3(
		_original_body_scale.x * 1.35,
		maxf(0.35, _original_body_scale.y * 0.55),
		_original_body_scale.z * 1.35
	)
	_apply_object_form_speed(0.18)
	actor.set_meta("mimic_object_form", true)
	actor.set_meta("mimic_false_appearance", true)
	is_object_form = true
	# Adhesive trait engages while disguised.
	if _adhesive_tick_id < 0 and actor.has_method("register_tick"):
		_adhesive_tick_id = actor.register_tick(_on_adhesive_tick, 0.4)
	object_form_changed.emit(true)
	return true

func exit_object_form() -> bool:
	if not is_instance_valid(actor):
		return false
	if not is_object_form:
		return false

	if is_instance_valid(_original_body):
		_original_body.scale = _original_body_scale
		_original_body.visible = true
		_set_visual_body(_original_body)

	if actor.movement_component:
		actor.movement_component.speed_multiplier = _object_form_speed_backup
	actor.remove_meta("mimic_object_form")
	actor.remove_meta("mimic_false_appearance")
	is_object_form = false
	# Stop adhesive scanning and release every still-grappled target.
	if _adhesive_tick_id >= 0 and actor.has_method("unregister_tick"):
		actor.unregister_tick(_adhesive_tick_id)
		_adhesive_tick_id = -1
	_release_all_grappled()
	object_form_changed.emit(false)
	return true

func force_true_form() -> void:
	revert()
	exit_object_form()

func _set_visual_body(new_body: Node3D) -> void:
	if not actor or not actor.visual_component or new_body == null:
		return
	actor._body = new_body
	actor.visual_component.body = new_body
	actor.visual_component.body_sprite = null
	actor.visual_component.body_model = null
	if new_body is SpriteBase3D:
		actor.visual_component.body_sprite = new_body as SpriteBase3D
	else:
		actor.visual_component.body_model = new_body
		actor.visual_component.initial_model_scale = new_body.scale

func _resolve_target_type(target: Node3D) -> StringName:
	var data_value: Variant = target.get("_data")
	if data_value is ActorData:
		return StringName((data_value as ActorData).get_actor_type())
	if "element_type" in target:
		return StringName(String(target.element_type).to_lower().strip_edges())
	return StringName(target.name.to_lower().strip_edges())

func _apply_object_form_speed(multiplier: float) -> void:
	if actor == null or actor.movement_component == null:
		return
	_object_form_speed_backup = actor.movement_component.speed_multiplier
	actor.movement_component.speed_multiplier = minf(actor.movement_component.speed_multiplier, multiplier)

# --- Adhesive trait ---------------------------------------------------------

## Scan nearby actors; grapple any unwary visitor within touch range and roll
## an escape check (with disadvantage) for anyone already glued. D&D 5e Mimic.
func _on_adhesive_tick() -> void:
	if not is_instance_valid(actor) or not is_object_form:
		return
	var arena_value: Variant = actor.get("_arena_grid")
	if not (arena_value is ArenaGrid):
		return
	var arena: ArenaGrid = arena_value as ArenaGrid
	var escape_dc: int = int(actor.get_meta("adhesive_escape_dc", ADHESIVE_DEFAULT_ESCAPE_DC))

	# 1) Roll escape for everyone currently glued.
	var still_grappled: Array[Actor] = []
	for grabbed in _grappled_targets:
		if not is_instance_valid(grabbed) or grabbed.is_dead:
			continue
		if _roll_strength_save(grabbed, escape_dc, true):
			_release_target(grabbed)
		else:
			still_grappled.append(grabbed)
	_grappled_targets = still_grappled

	# 2) Acquire new victims in touch range.
	for node in arena.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var candidate: Actor = node as Actor
		if candidate == actor or candidate.is_dead:
			continue
		if candidate in _grappled_targets:
			continue
		if actor.has_method("is_ally") and actor.is_ally(candidate):
			continue
		if candidate.is_playable and actor.is_playable:
			# Two mimic players shouldn't trap each other.
			continue
		var flat_dist: float = Vector2(
			candidate.global_position.x - actor.global_position.x,
			candidate.global_position.z - actor.global_position.z
		).length()
		if flat_dist <= ADHESIVE_TOUCH_RANGE:
			_glue_target(candidate)

func _glue_target(target: Actor) -> void:
	if target == null or not is_instance_valid(target) or target.has_meta("adhered_to"):
		return
	target.set_meta("adhered_to", actor)
	target.set_meta("grappled_by_mimic", true)
	_grappled_targets.append(target)
	# Pin movement to near-zero while glued.
	if target.movement_component:
		target.set_meta("_pre_adhesive_speed_mult", target.movement_component.speed_multiplier)
		target.movement_component.speed_multiplier = 0.0
	print("[Mimic] Adhesive: %s glued to %s (DC %d to escape, disadvantage)." % [
		target.name, actor.name,
		int(actor.get_meta("adhesive_escape_dc", ADHESIVE_DEFAULT_ESCAPE_DC))
	])

func _release_target(target: Actor) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.remove_meta("adhered_to")
	target.remove_meta("grappled_by_mimic")
	if target.movement_component and target.has_meta("_pre_adhesive_speed_mult"):
		target.movement_component.speed_multiplier = float(target.get_meta("_pre_adhesive_speed_mult", 1.0))
		target.remove_meta("_pre_adhesive_speed_mult")
	print("[Mimic] Adhesive: %s broke free of %s." % [target.name, actor.name])

func _release_all_grappled() -> void:
	for grabbed in _grappled_targets:
		if is_instance_valid(grabbed):
			_release_target(grabbed)
	_grappled_targets.clear()

## D&D 5e ability save: 2 d20s if disadvantage, take the LOWER. Add target's
## STR ability modifier. Compare against the DC. Returns true if save succeeds.
##
## Codebase convention: AbilityScoresComponent.strength is already the D&D
## MODIFIER (not the 1-20 score), per AbilityScoresComponent.get_score() doc.
## So we read it directly without the "(score - 10) / 2" conversion.
func _roll_strength_save(target: Actor, dc: int, disadvantage: bool) -> bool:
	var roll_a: int = randi() % 20 + 1
	var final_roll: int = roll_a
	if disadvantage:
		var roll_b: int = randi() % 20 + 1
		final_roll = mini(roll_a, roll_b)
	var str_mod: int = 0
	if target and target.ability_scores_component and "strength" in target.ability_scores_component:
		str_mod = int(round(float(target.ability_scores_component.strength)))
	return (final_roll + str_mod) >= dc
