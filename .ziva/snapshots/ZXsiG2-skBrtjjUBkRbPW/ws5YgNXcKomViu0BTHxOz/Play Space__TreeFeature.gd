class_name TreeFeature
extends Node3D

enum State { PINECONE, SAPLING, TREE, STUMP, BURNT_STUMP }

@export var current_state: State = State.TREE:
	set(v):
		current_state = v
		if is_node_ready():
			set_state_node(v)

var current_state_node: TreeState = null

var timer: float = 10.0
var grass_spread_timer: float = 5.0 # Timer for spreading grass
var is_moving: bool = false
var target_tile: HexTile = null
var move_speed: float = 8.0 # Slightly faster movement for pinecones

## Tree Health System
@export var health: float = 5.0
const MAX_HEALTH: float = 5.0
var fire_damage_accumulator: float = 0.0 # To track 1 HP per second

## Cap on pinecones per tree: Track the pinecone this tree spawned.
var spawned_pinecone_ref: WeakRef = null

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_body: StaticBody3D = $StaticBody3D
@onready var health_label: Label3D = $HealthLabel
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

const TEXTURES = {
	State.PINECONE: preload("res://assets/generated/pinecone_frame_0_1774919979.png"),
	State.SAPLING: preload("res://assets/generated/sapling_frame_0_1774919985.png"),
	State.TREE: preload("res://assets/generated/tree_simple_frame_0_1774919983.png"),
	State.STUMP: preload("res://assets/generated/stump_simple_1774734105.png"),
	State.BURNT_STUMP: preload("res://assets/generated/burnt_stump_simple_1774734102.png")
}

func _ready() -> void:
	health = MAX_HEALTH
	if health_label: health_label.visible = false
	if audio_player:
		audio_player.stream = load("res://assets/SoundFiles/Tree fall.mp3")
	
	set_state_node(current_state)

func set_state_node(new_state: State) -> void:
	current_state = new_state
	
	# Cleanup old state
	if current_state_node:
		current_state_node.exit()
		remove_child(current_state_node)
		current_state_node.queue_free()
	
	# Initialize new state
	match new_state:
		State.PINECONE: current_state_node = TreePineconeState.new()
		State.SAPLING: current_state_node = TreeSaplingState.new()
		State.TREE: current_state_node = TreeMaturedState.new()
		State.STUMP: current_state_node = TreeStumpState.new()
		State.BURNT_STUMP: current_state_node = TreeBurntStumpState.new()
	
	if current_state_node:
		current_state_node.name = "CurrentState"
		current_state_node.tree = self
		add_child(current_state_node)
		current_state_node.enter()

func _process(delta: float) -> void:
	# If on a burning tile, burn the feature
	var parent = get_parent()
	var on_fire = parent is HexTile and parent.tile_type == HexTile.Type.FIRE
	if on_fire:
		fire_damage_accumulator += delta
		if fire_damage_accumulator >= 1.0:
			take_damage(1.0, true)
			fire_damage_accumulator -= 1.0
	else:
		fire_damage_accumulator = 0.0

	if current_state_node:
		current_state_node.update(delta)

func take_damage(amount: float, is_fire: bool) -> void:
	if current_state_node:
		current_state_node.on_damage(amount, is_fire)

func _show_health() -> void:
	if health_label:
		health_label.text = "HP: %d" % ceil(health)
		health_label.visible = true
		
		# Reset visibility after 2 seconds
		var t = get_tree().create_timer(2.0)
		t.timeout.connect(func(): if is_instance_valid(health_label): health_label.visible = false)

func _update_collision() -> void:
	if not collision_body: return
	# Trees and stumps block movement
	var should_block = current_state in [State.TREE, State.STUMP, State.BURNT_STUMP]
	collision_body.process_mode = PROCESS_MODE_INHERIT if should_block else PROCESS_MODE_DISABLED

func _is_on_tree_tile() -> bool:
	var parent = get_parent()
	if parent is HexTile:
		for child in parent.get_children():
			if child is TreeFeature and child != self:
				if child.current_state in [State.TREE, State.STUMP, State.BURNT_STUMP, State.SAPLING]:
					return true
	return false

func _spawn_pinecone() -> void:
	# Check if we already have a pinecone on the field
	if spawned_pinecone_ref and spawned_pinecone_ref.get_ref():
		var pine = spawned_pinecone_ref.get_ref() as TreeFeature
		# If the pinecone is still a pinecone and exists, don't spawn another
		if pine.current_state == State.PINECONE:
			return
			
	var pinecone = load("res://Play Space/tree_feature.tscn").instantiate()
	pinecone.current_state = State.PINECONE
	get_parent().add_child(pinecone)
	spawned_pinecone_ref = weakref(pinecone)

func apply_element(element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if current_state_node:
		return current_state_node.handle_element(element, direction)
	return false

func apply_fire() -> bool:
	# For instant fire application, we deal max damage to kill it and turn it to burnt stump
	take_damage(5.0, true)
	return true

func apply_water(direction: Vector3 = Vector3.ZERO) -> bool:
	return apply_element("water", direction)

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

func _handle_movement(delta: float) -> void:
	if not target_tile:
		is_moving = false
		return
		
	var target_pos = target_tile.global_position
	target_pos.y = global_position.y
	
	global_position = global_position.move_toward(target_pos, move_speed * delta)
	
	if global_position.distance_to(target_pos) < 0.1:
		# Arrived at tile
		# Check if the tile we arrived at is burning
		if target_tile.tile_type == HexTile.Type.FIRE:
			take_damage(5.0, true) # Pinecone dies instantly to fire on landing
			return

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
