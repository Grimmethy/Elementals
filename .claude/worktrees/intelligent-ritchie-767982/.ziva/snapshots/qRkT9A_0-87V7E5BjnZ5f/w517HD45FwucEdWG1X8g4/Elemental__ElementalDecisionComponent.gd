class_name ElementalDecisionComponent
extends DecisionComponent

@export var elemental: Elemental

var _previous_tile: HexTileData
var _movement_target: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if not elemental and get_parent() is Elemental:
		elemental = get_parent()
	
	if elemental:
		_movement_target = elemental.global_transform.origin
		if movement_component:
			movement_component.stuck.connect(_choose_new_target)
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
	
	# Apply tree avoidance steering
	var avoidance = _get_tree_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 1.5).normalized()
	
	movement_component.move(dir_3d, delta)
	movement_component.apply_gravity(delta)

func _get_tree_avoidance_vector() -> Vector3:
	var avoidance := Vector3.ZERO
	if not elemental or not elemental._arena_grid:
		return avoidance
		
	# Check a slightly larger radius around the elemental for trees
	var nearby_tiles = elemental._arena_grid.get_tiles_within_distance(elemental.global_position, 3.5)
	for tile in nearby_tiles:
		if tile.feature and tile.feature is TreeFeature:
			# Pinecones and Saplings are small, don't avoid them as much as trees/stumps
			if tile.feature.current_state == TreeFeature.State.PINECONE or tile.feature.current_state == TreeFeature.State.SAPLING:
				continue
				
			var feature_pos = tile.feature.global_position
			var diff = elemental.global_position - feature_pos
			diff.y = 0
			var dist = diff.length()
			
			# Avoidance threshold: trees are roughly hex-sized. 
			# We want to start steering well before we hit.
			if dist < 2.0 and dist > 0.1:
				var weight = (2.0 - dist) / 2.0
				var repulsion = diff.normalized() * weight
				avoidance += repulsion
				
				# Add a "sidestep" force to break symmetry if heading straight at it
				var move_dir = Vector3(elemental.velocity.x, 0, elemental.velocity.z).normalized()
				if move_dir.length_squared() > 0.1:
					var dot = move_dir.dot(-diff.normalized())
					if dot > 0.6: # Heading mostly at the tree
						var side_dir = Vector3(-diff.z, 0, diff.x).normalized()
						# Bias towards our existing sideways movement
						if move_dir.dot(side_dir) < 0:
							side_dir = -side_dir
						avoidance += side_dir * weight * 0.8
				
	return avoidance

func _choose_new_target() -> void:
	if not elemental or not elemental._arena_grid:
		return
		
	elemental._update_tile_below()
	var ground_tile = elemental._ground_tile
	
	if ground_tile and elemental._arena_grid:
		# Get neighbors and filter out Stone AND tiles with blocking trees
		var neighbors = elemental._arena_grid._get_neighbors(ground_tile).filter(func(t): 
			if t == null or t.current_state == TileConstants.State.STONE:
				return false
			
			# Check for blocking features (trees/stumps)
			if t.feature and t.feature is TreeFeature:
				if t.feature.current_state in [TreeFeature.State.TREE, TreeFeature.State.STUMP, TreeFeature.State.BURNT_STUMP]:
					return false
					
			return true
		)
		
		if neighbors.size() > 0:
			var candidates = neighbors.filter(func(t): return t != _previous_tile)
			var next_tile: HexTileData
			if candidates.size() > 0:
				next_tile = candidates[_rng.randi_range(0, candidates.size() - 1)]
			else:
				next_tile = neighbors[_rng.randi_range(0, neighbors.size() - 1)]
			
			_previous_tile = ground_tile
			_movement_target = next_tile.position
			_movement_target.y = elemental.global_position.y
			return

	# Fallback: if somehow stuck or surrounded, pick any non-stone neighbor or random direction
	var fallback_neighbors = elemental._arena_grid._get_neighbors(ground_tile if ground_tile else elemental._arena_grid.get_tile_at_grid_coords(0,0)).filter(func(t): 
		return t != null and t.current_state != TileConstants.State.STONE
	)
	
	if fallback_neighbors.size() > 0:
		_movement_target = fallback_neighbors.pick_random().position
	else:
		var heading = _rng.randf_range(0.0, TAU)
		_movement_target = elemental.global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * 3.0
	
	_movement_target.y = elemental.global_position.y
