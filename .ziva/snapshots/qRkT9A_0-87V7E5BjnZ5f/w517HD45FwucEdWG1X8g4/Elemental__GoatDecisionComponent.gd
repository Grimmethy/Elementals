class_name GoatDecisionComponent
extends ElementalDecisionComponent

## Specialized AI for goats to make them rowdy and rambunctious.
## They seek out other elementals, scream at them, and headbutt them.

enum State { WANDERING, ALERT, CHARGING, COOLDOWN }
var current_state: State = State.WANDERING

@export var detection_range: float = 10.0
@export var charge_range: float = 6.0
@export var alert_duration: float = 1.0
@export var cooldown_duration: float = 3.0

var _state_timer: float = 0.0
var _target_elemental: Elemental = null

func _handle_ai_logic(delta: float) -> void:
	if not elemental or not elemental._arena_grid or not movement_component:
		return
		
	if is_controlled:
		return

	# Social rowdiness: speed up if others are nearby
	var rowdy_bonus = 1.0
	for other in elemental._arena_grid.elementals:
		if other is GoatElemental and other != elemental:
			if other.global_position.distance_to(elemental.global_position) < 8.0:
				rowdy_bonus += 0.25
	
	# Combine rowdy bonus with state-specific multipliers
	var state_mult = 1.0
	match current_state:
		State.WANDERING:
			state_mult = 1.0
			_update_wandering(delta)
		State.ALERT:
			state_mult = 1.5
			_update_alert(delta)
		State.CHARGING:
			state_mult = 1.0
			_update_charging(delta)
		State.COOLDOWN:
			state_mult = 0.5
			_update_cooldown(delta)
			
	movement_component.speed_multiplier = rowdy_bonus * state_mult

func _update_wandering(delta: float) -> void:
	# Normal wandering behavior from base class
	super._handle_ai_logic(delta)
	
	# Look for a target
	var target = _find_nearby_elemental()
	if target:
		_target_elemental = target
		_transition_to(State.ALERT)

func _update_alert(delta: float) -> void:
	# Stop moving and face the target
	movement_component.stop(delta)
	_face_target(_target_elemental.global_position)
	
	_state_timer -= delta
	if _state_timer <= 0:
		_transition_to(State.CHARGING)

func _update_charging(delta: float) -> void:
	# The GoatElemental script handles the actual charge physics
	# We just need to trigger it once
	if not (elemental as GoatElemental)._is_charging:
		# If we aren't charging yet, start it
		var goat = elemental as GoatElemental
		var target_pos = _target_elemental.global_position
		
		# Set the charge direction in the goat script
		var dir = (target_pos - goat.global_position).normalized()
		dir.y = 0
		
		# We use the internal charge method by simulating a mouse click or calling it directly
		# GoatElemental._start_charge() uses mouse position, so we should add an AI-friendly version
		if goat.has_method("ai_start_charge"):
			goat.ai_start_charge(target_pos)
		
		_transition_to(State.COOLDOWN)

func _update_cooldown(delta: float) -> void:
	# Wander slowly or stay still
	super._handle_ai_logic(delta)
	
	_state_timer -= delta
	if _state_timer <= 0:
		_transition_to(State.WANDERING)

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.WANDERING:
			_target_elemental = null
		State.ALERT:
			_state_timer = alert_duration
			if elemental.has_method("_scream"):
				elemental.call("_scream")
		State.CHARGING:
			pass
		State.COOLDOWN:
			_state_timer = cooldown_duration

func _find_nearby_elemental() -> Elemental:
	if not elemental or not elemental._arena_grid:
		return null
		
	var best_target: Elemental = null
	var min_dist = detection_range
	
	for other in elemental._arena_grid.elementals:
		if other == elemental:
			continue
		
		if not is_instance_valid(other) or not other is Elemental:
			continue
			
		var dist = elemental.global_position.distance_to(other.global_position)
		if dist < min_dist:
			min_dist = dist
			best_target = other
			
	return best_target

func _face_target(pos: Vector3) -> void:
	# The sprite flip logic in GoatElemental handles visual facing
	# But we can update velocity slightly to influence it if needed
	var dir = (pos - elemental.global_position).normalized()
	elemental.velocity.x = dir.x * 0.01
	elemental.velocity.z = dir.z * 0.01
