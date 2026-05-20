
class_name GoatActor
extends Actor

## Specialized Actor that represents a goat.
## Features a charge attack, terrain-based speed modifiers, and specialized visual effects.

## Emitted when this goat screams, allowing other goats to respond.
signal screamed(position: Vector3)

@export_group("Goat Charge")
## The speed at which the goat charges forward.
@export var charge_speed: float = 25.0
## The maximum distance the goat can travel in a single charge.
@export var charge_distance: float = 5.0
## The time in seconds between consecutive charges.
@export var charge_cooldown: float = 1.0

## Goat-specific scream component (extends base CommunicationComponent).
## Handles scream visuals, cooldowns, and social responses.
var scream_component: GoatScreamComponent

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")

var goat_data: GoatData:
	get: return _data as GoatData
	set(v): _data = v

func _init() -> void:
	element_type = "goat"
	should_bob = false

func _ready() -> void:
	super._ready()
	
	# Set up GoatScreamComponent for goat-specific screaming (visuals, cooldowns)
	scream_component = GoatScreamComponent.new()
	scream_component.setup(self)
	add_child(scream_component)
	
	# Configure goat-specific terrain speed modifiers
	terrain_speed_modifier_component.configure_multipliers({
		TileConstants.Type.MUD: 0.5,
		TileConstants.Type.PUDDLE: 0.7,
		TileConstants.Type.GRASS: 1.2,
		TileConstants.Type.STONE: 1.0,
		TileConstants.Type.FIRE: 1.3
	})

	# Configure goat-specific communication (uses the "screamed" signal)
	if communication_component:
		communication_component.broadcast_signal_name = &"screamed"
		communication_component.communication_range = 15.0
		communication_component.probability = 0.25


func _on_data_changed_impl() -> void:
	if not goat_data:
		return

	# Goat-specific scaling (Base ability scores and move_speed are synced in Actor)
	if health_component:
		max_hp = health_component.roll_max_health(1, 8, _rng)

	charge_speed = 25.0 + (5.0 * ability_scores_component.strength)
	charge_distance = 5.0 + (1.0 * ability_scores_component.strength)

	actor_size = goat_data.body_type as Size

	if visual_component:
		visual_component.update_goat_visuals(goat_data)

	# Hybrid-breeding consumer: a goat whose data carries the inherit_mimic_skills
	# flag (rolled during breeding via ActorData.apply_mimic_lineage) gains the
	# Mimic CreatureMorphComponent + SkillCopyComponent + MimicShapechange ability.
	# Without this graft the headline 30%/60%/100% probability gate would be inert.
	if goat_data.inherit_mimic_skills:
		_graft_mimic_kit()
	# Propagate mimic_blood as actor meta so future systems (visual tints, AI
	# behavior, capture-tool resistance) can read it without holding an
	# ActorData reference.
	set_meta("mimic_blood", goat_data.mimic_blood)

## Add the Mimic ability suite to this goat. AbilityAction instances are
## per-actor (must not be shared across actors), so we new() them fresh.
func _graft_mimic_kit() -> void:
	if has_meta("mimic_kit_grafted"):
		return
	set_meta("mimic_kit_grafted", true)
	# CreatureMorphComponent + SkillCopyComponent are children of the actor.
	const MorphScript = preload("res://Components/ActorComponents/CreatureMorphComponent.gd")
	const SkillCopyScript = preload("res://Components/ActorComponents/SkillCopyComponent.gd")
	const MimicShapechangeScript = preload("res://Components/ActorComponents/AbilityComponents/MimicShapechange.gd")
	if get_node_or_null("CreatureMorphComponent") == null:
		var morph: Node = MorphScript.new()
		morph.name = "CreatureMorphComponent"
		add_child(morph)
		if morph.has_method("setup"):
			morph.call("setup", self)
	if get_node_or_null("SkillCopyComponent") == null:
		var skill_copy: Node = SkillCopyScript.new()
		skill_copy.name = "SkillCopyComponent"
		add_child(skill_copy)
		if skill_copy.has_method("setup"):
			skill_copy.call("setup", self)
	if ability_component:
		# Replace whatever default action a wild goat would have so the hybrid
		# kid leads with Shapechange. Future patches can keep GoatCharge AND
		# add Shapechange as a secondary ability slot.
		var has_shapechange: bool = false
		for action in ability_component.actions:
			if action is MimicShapechange:
				has_shapechange = true
				break
		if not has_shapechange:
			var shapechange: AbilityAction = MimicShapechangeScript.new(self, ability_component)
			ability_component.add_action(shapechange)
	print("[Hybrid] %s inherited Mimic kit (mimic_blood=%.2f)." % [
		goat_data.goat_name if goat_data else name,
		goat_data.mimic_blood if goat_data else 0.0
	])

func die() -> void:
	if is_dead:
		return
	
	# Call base Actor.die() for proper death: fall over, disable components, emit signals
	super.die()
	
	# Goat-specific: Permanent removal from the persistent herd
	if has_node("/root/HerdManager"):
		get_node("/root/HerdManager").remove_goat(goat_data)



const THWAK_TEXTURE = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")

func _create_controller() -> ActorAIController:
	return GoatController.new()

func _process(delta: float) -> void:
	## Main update loop handling visual updates and cooldowns.
	if scream_component:
		scream_component.update(delta)
	if status_effect_component and status_effect_component.is_burning():
		_flash_red()

func _physics_process(delta: float) -> void:
	## Extends physics processing to delegate charge logic to the AbilityComponent.
	if ability_component:
		for action in ability_component.actions:
			if action is GoatCharge:
				action.process_physics(delta)

	super._physics_process(delta)

	if ability_component:
		for action in ability_component.actions:
			if action is GoatCharge:
				action.process_collisions()

func _play_whack() -> void:
	if _whack_player:
		_whack_player.play()

func emit_screamed(position: Vector3) -> void:
	screamed.emit(position)

func _show_thwak_visual(pos: Vector3) -> void:
	## Displays a "THWAK!" comic book style popup at the collision point.
	var sprite = Sprite3D.new()
	var texture = THWAK_TEXTURE
	
	if texture:
		sprite.texture = texture
		sprite.pixel_size = 0.02 # Toned down from 0.04
	else:
		return
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Add to the arena (parent) so it stays at the collision world position
	if get_parent():
		get_parent().add_child(sprite)
	else:
		add_child(sprite)
		
	sprite.global_position = pos + Vector3(0, 0.5, 0) # Position slightly above the hit point
	
	# Animate: Pop in, slight shake, and fade out
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.0, 0.1)
	
	# Brief shake
	for i in range(3):
		var shake = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0)
		tween.tween_property(sprite, "position", sprite.position + shake, 0.04)
	
	# Fade and rise
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 0.4, 0.3).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _on_burning_damage_taken() -> void:
	_scream()
	_flash_red()

func _flash_red() -> void:
	## Briefly flashes the actor red to indicate damage.
	if visual_component:
		visual_component.flash_red()

func get_actor_color() -> Color:
	## Returns the thematic color for the goat actor.
	return Color(0.7, 0.6, 0.4) # A light brown/grey

func _launch_projectile() -> void:
	## Overrides base projectile logic as goats do not use projectiles.
	pass

func _unhandled_input(event: InputEvent) -> void:
	## Handles player input for scream (right click) and charge (left click) when controlled.
	if is_controlled and not is_stunned() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_scream()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var target_pos := _get_mouse_3d_position()
			if ability_component:
				ability_component.execute_ability("charge", target_pos)
			get_viewport().set_input_as_handled()

func _get_mouse_3d_position() -> Vector3:
	## Project the mouse position into the 3D world on the ground plane (y=0).
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	if abs(ray_direction.y) < 1e-6:
		return Vector3.ZERO
		
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t

func _scream() -> void:
	## Triggers the goat's iconic scream sound and visual effect.
	if scream_component:
		scream_component.try_scream()
