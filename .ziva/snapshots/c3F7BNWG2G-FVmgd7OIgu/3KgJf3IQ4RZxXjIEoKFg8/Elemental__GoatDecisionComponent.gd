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

@export_group("Flocking")
## Minimum distance to keep from the player goat.
@export var min_follow_distance: float = 4.0
## Maximum distance to allow from the player goat before seeking them.
@export var max_follow_distance: float = 12.0

var _state_timer: float = 0.0
var _target_elemental: Elemental = null

func _get_player_goat() -> GoatElemental:
	if not elemental or not elemental._arena_grid:
		return null
	var target = elemental._arena_grid.current_controlled_elemental
	if target is GoatElemental and target != elemental:
		return target
	return null

func _choose_new_target() -> void:
	if not elemental or not elemental._arena_grid:
		return
		
	var player_goat = _get_player_goat()
	if not player_goat:
		super._choose_new_target()
		return
		
	elemental._update_tile_below()
	var ground_tile = elemental._ground_tile
	if not ground_tile:
		super._choose_new_target()
		return

	var dist_to_player = elemental.global_position.distance_to(player_goat.global_position)
	var ground_y = elemental._arena_grid._get_tile_surface_y(ground_tile)
	
	# Get valid neighbors
	var neighbors = elemental._arena_grid._get_neighbors(ground_tile).filter(func(t): 
		if t == null or t.current_state == TileConstants.State.STONE: return false
		if t.feature and t.feature is TreeFeature:
			if t.feature.current_state in [TreeFeature.State.TREE, TreeFeature.State.STUMP, TreeFeature.State.BURNT_STUMP]:
				return false
		var ty = elemental._arena_grid._get_tile_surface_y(t)
		if ty > ground_y + 3.0: return false
		return true
	)
	
	if neighbors.is_empty():
		super._choose_new_target()
		return

	var next_tile: HexTileData = null
	
	if dist_to_player > max_follow_distance:
		# Seek player: pick neighbor closest to player
		neighbors.sort_custom(func(a, b):
			return a.position.distance_to(player_goat.global_position) < b.position.distance_to(player_goat.global_position)
		)
		next_tile = neighbors[0]
	elif dist_to_player < min_follow_distance:
		# Repel/Maintain: pick neighbor further from player
		neighbors.sort_custom(func(a, b):
			return a.position.distance_to(player_goat.global_position) > b.position.distance_to(player_goat.global_position)
		)
		next_tile = neighbors[0]
	else:
		# Random wander within neighbors
		var candidates = neighbors.filter(func(t): return t != _previous_tile)
		if candidates.size() > 0:
			next_tile = candidates[_rng.randi_range(0, candidates.size() - 1)]
		else:
			next_tile = neighbors.pick_random()

	if next_tile:
		_previous_tile = ground_tile
		_movement_target = next_tile.position
		_movement_target.y = elemental.global_position.y

func _handle_ai_logic(delta: float) -> void:
	if not elemental or not elemental._arena_grid or not movement_component:
		return
		
	if is_controlled:
		return
		
	# Reactive Flocking: If we are way too far from the player, force a re-target
	var player_goat = _get_player_goat()
	if player_goat and current_state == State.WANDERING:
		var dist_to_player = elemental.global_position.distance_to(player_goat.global_position)
		if dist_to_player > max_follow_distance * 1.5:
			# Force immediate movement update if current target is moving away or too far
			var target_dist_to_player = _movement_target.distance_to(player_goat.global_position)
			if target_dist_to_player > max_follow_distance:
				_choose_new_target()

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

func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	return State.keys()[current_state]

func _find_nearby_elemental() -> Elemental:
	if not elemental or not elemental._arena_grid:
		return null
		
	var player_goat = _get_player_goat()
	var possible_targets: Array[Elemental] = []
	
	for other in elemental._arena_grid.elementals:
		if not is_instance_valid(other) or other == elemental:
			continue
		
		# Prioritize non-goats
		if other is Elemental:
			possible_targets.append(other)
			
	if possible_targets.is_empty():
		return null
		
	var best_target: Elemental = null
	var min_score = 1e9
	
	for target in possible_targets:
		var dist_to_self = elemental.global_position.distance_to(target.global_position)
		var dist_to_player = player_goat.global_position.distance_to(target.global_position) if player_goat else 1e9
		
		# Candidate if near me OR near the player (herd awareness)
		if dist_to_self > detection_range and dist_to_player > detection_range:
			continue
			
		var score = dist_to_self
		
		# Bias score towards enemies (non-goats)
		if target is GoatElemental:
			score += 100.0 # Much lower priority than enemies
		
		# Bias score towards things near the player
		if player_goat:
			var dist_to_player = player_goat.global_position.distance_to(target.global_position)
			# If the player is very close to an enemy, it's highly prioritized
			score += dist_to_player * 0.5
			
		if score < min_score:
			min_score = score
			best_target = target
			
	return best_target

func _face_target(pos: Vector3) -> void:
	# The sprite flip logic in GoatElemental handles visual facing
	# But we can update velocity slightly to influence it if needed
	var dir = (pos - elemental.global_position).normalized()
	elemental.velocity.x = dir.x * 0.01
	elemental.velocity.z = dir.z * 0.01
