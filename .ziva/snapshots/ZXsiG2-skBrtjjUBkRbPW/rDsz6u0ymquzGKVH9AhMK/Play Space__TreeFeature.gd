class_name TreeFeature
extends Node3D

enum State { PINECONE, SAPLING, TREE, STUMP, BURNT_STUMP }

@export var current_state: State = State.TREE:
	set(v):
		current_state = v
		_update_visuals()
		_reset_timer()
		_update_collision()

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
	_update_visuals()
	_reset_timer()
	_update_collision()
	grass_spread_timer = 5.0
	health = MAX_HEALTH
	if health_label: health_label.visible = false
	if audio_player:
		audio_player.stream = load("res://assets/SoundFiles/Tree fall.mp3")

func _reset_timer() -> void:
	timer = 10.0

func _update_collision() -> void:
	if not collision_body: return
	# Trees and stumps block movement
	var should_block = current_state in [State.TREE, State.STUMP, State.BURNT_STUMP]
	collision_body.process_mode = PROCESS_MODE_INHERIT if should_block else PROCESS_MODE_DISABLED

func _update_visuals() -> void:
	if not is_inside_tree(): return
	if not sprite: return
	
	sprite.texture = TEXTURES[current_state]
	
	# Adjust scale/position based on state
	match current_state:
		State.PINECONE:
			sprite.scale = Vector3.ONE * 1
			sprite.position.y = 0.2
			if health_label: health_label.position.y = 1.0
		State.SAPLING:
			sprite.scale = Vector3.ONE * 1.5 # Roughly former tree size
			sprite.position.y = 1.0
			if health_label: health_label.position.y = 2.5
		State.TREE:
			sprite.scale = Vector3.ONE * 4.5 # 3x former size
			sprite.position.y = 2.0
			if health_label: health_label.position.y = 7.0
		State.STUMP, State.BURNT_STUMP:
			sprite.scale = Vector3.ONE * 1.5
			sprite.position.y = .5
			if health_label: health_label.position.y = 2.5

func _process(delta: float) -> void:
	# If on a burning tile, burn the feature
	var parent = get_parent()
	var on_fire = parent is HexTile and parent.tile_type == HexTile.Type.FIRE
	if on_fire:
		# Pinecones and saplings are consumed instantly as before?
		# No, the prompt says "Trees should have 5 hp. Fire should consume 1 hp per second."
		# I'll apply fire logic to all states for consistency if they have HP.
		fire_damage_accumulator += delta
		if fire_damage_accumulator >= 1.0:
			take_damage(1.0, true)
			fire_damage_accumulator -= 1.0
	else:
		fire_damage_accumulator = 0.0

	if is_moving:
		_handle_movement(delta)
		return

	_handle_state_logic(delta)
	
	# Trees spread grass to their tile after 5 seconds
	if current_state == State.TREE and parent is HexTile:
		if parent.current_state != HexTile.State.GRASS:
			grass_spread_timer -= delta
			if grass_spread_timer <= 0:
				parent.current_state = HexTile.State.GRASS
				grass_spread_timer = 5.0
		else:
			grass_spread_timer = 5.0

func take_damage(amount: float, is_fire: bool) -> void:
	health -= amount
	_show_health()
	
	if health <= 0:
		_die(is_fire)

func _show_health() -> void:
	if health_label:
		health_label.text = "HP: %d" % ceil(health)
		health_label.visible = true
		
		# Reset visibility after 2 seconds
		var t = get_tree().create_timer(2.0)
		t.timeout.connect(func(): if is_instance_valid(health_label): health_label.visible = false)

func _die(is_fire: bool) -> void:
	# Only play fall sound for full trees dying
	if current_state == State.TREE and audio_player:
		audio_player.stream = load("res://assets/SoundFiles/Tree fall.mp3")
		audio_player.play()
	
	# If the tile is on fire, we become a burnt stump regardless of how we died
	var parent = get_parent()
	var tile_on_fire = parent is HexTile and parent.tile_type == HexTile.Type.FIRE
	var should_burn = is_fire or tile_on_fire

	match current_state:
		State.PINECONE, State.SAPLING:
			queue_free() # These are removed from play when they "die" (burnt)
		State.TREE, State.STUMP, State.BURNT_STUMP:
			if should_burn:
				current_state = State.BURNT_STUMP
			else:
				current_state = State.STUMP
			health = MAX_HEALTH

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
				health = MAX_HEALTH # Ensure full health on maturity
			State.TREE:
				_spawn_pinecone()
				timer = 10.0 # Reset for next pinecone attempt
			State.STUMP:
				current_state = State.TREE
				health = MAX_HEALTH
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
	match element:
		"fire":
			# Direct fire projectile hit?
			take_damage(1.0, true)
			return true
		"water":
			return apply_water(direction)
		"headbutt":
			if current_state == State.PINECONE:
				_push_pinecone(direction)
				return true
			elif current_state in [State.TREE, State.STUMP, State.BURNT_STUMP, State.SAPLING]:
				take_damage(1.0, false)
				# Shake visual
				var tween = create_tween()
				tween.tween_property(sprite, "position:x", 0.1, 0.05)
				tween.tween_property(sprite, "position:x", -0.1, 0.05)
				tween.tween_property(sprite, "position:x", 0, 0.05)
				return true
	return false

func apply_fire() -> bool:
	match current_state:
		State.PINECONE, State.SAPLING:
			take_damage(5.0, true)
			return true
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
			health = MAX_HEALTH
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
