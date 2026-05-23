class_name TreeFeature
extends Node3D

enum State { PINECONE, SAPLING, TREE, STUMP, BURNT_STUMP }

@export var current_state: State = State.TREE:
	set(v):
		current_state = v
		_update_visuals()
		_reset_timer()

var timer: float = 10.0
var is_moving: bool = false
var target_tile: HexTile = null
var move_speed: float = 5.0

@onready var sprite: Sprite3D = $Sprite3D

const TEXTURES = {
	State.PINECONE: preload("res://assets/generated/pinecone_frame_0_1774918606.png"),
	State.SAPLING: preload("res://assets/generated/sapling_frame_0_1774918607.png"),
	State.TREE: preload("res://assets/generated/tree_simple_frame_0_1774734106.png"),
	State.STUMP: preload("res://assets/generated/stump_simple_frame_0_1774734105.png"),
	State.BURNT_STUMP: preload("res://assets/generated/burnt_stump_simple_frame_0_1774734102.png")
}

func _ready() -> void:
	_update_visuals()
	_reset_timer()

func _reset_timer() -> void:
	timer = 10.0

func _update_visuals() -> void:
	if not is_inside_tree(): return
	if not sprite: return
	
	sprite.texture = TEXTURES[current_state]
	
	# Adjust scale/position based on state
	match current_state:
		State.PINECONE:
			sprite.scale = Vector3.ONE * 0.5
			sprite.position.y = 0.2
		State.SAPLING:
			sprite.scale = Vector3.ONE * 0.6
			sprite.position.y = 0.3
		State.TREE:
			sprite.scale = Vector3.ONE * 1.5
			sprite.position.y = 1.0
		State.STUMP, State.BURNT_STUMP:
			sprite.scale = Vector3.ONE * 1.0
			sprite.position.y = 0.5

func _process(delta: float) -> void:
	if is_moving:
		_handle_movement(delta)
		return

	_handle_state_logic(delta)

func _handle_state_logic(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		match current_state:
			State.PINECONE:
				if not _is_on_tree_tile():
					current_state = State.SAPLING
				else:
					# Reset timer if we are stuck on a tree tile
					timer = 10.0
			State.SAPLING:
				current_state = State.TREE
			State.TREE:
				_spawn_pinecone()
				timer = 10.0 # Reset for next pinecone
			State.STUMP:
				current_state = State.TREE
			State.BURNT_STUMP:
				# Burnt stumps don't grow back on their own
				timer = 10.0

func _handle_movement(delta: float) -> void:
	if not target_tile:
		is_moving = false
		return
		
	var target_pos = target_tile.global_position
	target_pos.y = global_position.y
	
	global_position = global_position.move_toward(target_pos, move_speed * delta)
	
	if global_position.distance_to(target_pos) < 0.1:
		# Arrived at tile
		var old_parent = get_parent()
		if old_parent:
			old_parent.remove_child(self)
		target_tile.add_child(self)
		position = Vector3.ZERO # Reset local position
		is_moving = false
		target_tile = null
		# Reset timer when arriving at new tile as per requirement:
		# "if it remains stationary for 10 seconds"
		timer = 10.0

func _is_on_tree_tile() -> bool:
	var parent = get_parent()
	if parent is HexTile:
		for child in parent.get_children():
			if child is TreeFeature and child != self:
				if child.current_state in [State.TREE, State.STUMP, State.BURNT_STUMP, State.SAPLING]:
					return true
	return false

func _spawn_pinecone() -> void:
	var pinecone = load("res://Play Space/tree_feature.tscn").instantiate()
	pinecone.current_state = State.PINECONE
	get_parent().add_child(pinecone)

func apply_element(element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	match element:
		"fire":
			return apply_fire()
		"water":
			return apply_water(direction)
	return false

func apply_fire() -> bool:
	match current_state:
		State.PINECONE, State.SAPLING:
			queue_free()
			return true
		State.TREE, State.STUMP:
			current_state = State.BURNT_STUMP
			return true
		State.BURNT_STUMP:
			return false
	return false

func apply_water(direction: Vector3) -> bool:
	match current_state:
		State.PINECONE:
			_push_pinecone(direction)
			return true
		State.SAPLING, State.STUMP, State.TREE:
			timer *= 0.5
			return true
		State.BURNT_STUMP:
			current_state = State.STUMP
			return true
	return false

func _push_pinecone(direction: Vector3) -> void:
	if is_moving: return
	
	var parent = get_parent()
	if not (parent is HexTile): return
	
	# Find neighbor closest to direction
	var best_neighbor: HexTile = null
	var best_dot = -2.0
	
	var push_dir = direction.normalized()
	if push_dir.length_squared() < 0.1:
		push_dir = Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized()

	for neighbor in parent.neighbors:
		var dir_to_neighbor = (neighbor.global_position - parent.global_position).normalized()
		var dot = push_dir.dot(dir_to_neighbor)
		if dot > best_dot:
			best_dot = dot
			best_neighbor = neighbor
			
	if best_neighbor:
		target_tile = best_neighbor
		is_moving = true
