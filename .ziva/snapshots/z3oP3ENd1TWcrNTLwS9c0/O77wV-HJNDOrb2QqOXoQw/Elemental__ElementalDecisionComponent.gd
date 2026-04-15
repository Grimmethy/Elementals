class_name ElementalDecisionComponent
extends DecisionComponent

@export var elemental: Elemental

var _previous_tile: Node # HexTile
var _movement_target: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if not elemental and get_parent() is Elemental:
		elemental = get_parent()
	
	if elemental:
		_movement_target = elemental.global_transform.origin
		# Use call_deferred to ensure arena grid is ready
		call_deferred("_choose_new_target")

func _physics_process(delta: float) -> void:
	if elemental and elemental.is_stunned():
		if movement_component:
			movement_component.apply_gravity(delta)
			movement_component.stop(delta)
		return
		
	super._physics_process(delta)

func _handle_ai_logic(delta: float) -> void:
	if not elemental or not elemental._arena_grid or not movement_component:
		return
		
	var current_pos_2d = Vector2(elemental.global_transform.origin.x, elemental.global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	if current_pos_2d.distance_to(target_pos_2d) < 0.15:
		_choose_new_target()
		
	var direction = (target_pos_2d - current_pos_2d).normalized()
	var dir_3d = Vector3(direction.x, 0, direction.y)
	
	movement_component.move(dir_3d, delta)
	movement_component.apply_gravity(delta)

func _choose_new_target() -> void:
	if not elemental or not elemental._arena_grid:
		return
		
	elemental._update_tile_below()
	var ground_tile = elemental._ground_tile
	
	if ground_tile:
		var neighbors = ground_tile.neighbors.filter(func(t): 
			return t != null and is_instance_valid(t) and t.current_state != HexTile.State.STONE
		)
		
		if neighbors.size() > 0:
			var candidates = neighbors.filter(func(t): return t != _previous_tile)
			var next_tile: Node
			if candidates.size() > 0:
				next_tile = candidates[_rng.randi_range(0, candidates.size() - 1)]
			else:
				next_tile = neighbors[_rng.randi_range(0, neighbors.size() - 1)]
			
			_previous_tile = ground_tile
			_movement_target = next_tile.global_transform.origin
			_movement_target.y = elemental.global_position.y
			return

	# Fallback
	var heading = _rng.randf_range(0.0, TAU)
	_movement_target = elemental.global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * 3.0
	_movement_target.y = elemental.global_position.y
