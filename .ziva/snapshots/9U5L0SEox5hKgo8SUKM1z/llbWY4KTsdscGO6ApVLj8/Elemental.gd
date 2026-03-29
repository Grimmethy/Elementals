class_name Elemental
extends CharacterBody3D

@export var move_speed: float = 7.0
@export var roam_radius: float = 22.0
@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 2.2
@export_range(1.0, 10.0, 0.25) var trigger_range_in_tiles: float = 3.0
@export var projectile_interval: float = 1.0
@export var projectile_speed: float = 14.0
@export var projectile_lifetime: float = 5.0
@export var projectile_charge_capacity: int = 5
@export var projectile_scene: PackedScene

@export var jump_force: float = 5.0
@export var gravity: float = 9.8

@export_group("Stats")
@export var max_hp: int = 10
@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 20.0
@export var shot_mana_cost: float = 20.0

@onready var tile_detector: RayCast3D = $TileDetector

var is_controlled: bool = false
var element_type: String = "none"
var current_hp: int = 10
var current_mana: float = 100.0

var _arena_grid: ArenaGrid
var _movement_target: Vector3
var _base_height: float
var _bob_phase: float = 0.0
var _projectile_timer: float = 0.0
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ground_tile: HexTile
var _previous_tile: HexTile

var _hp_bar_node: ProgressBar
var _hp_viewport: SubViewport
var _hp_sprite: Sprite3D

func _ready() -> void:
	_rng.randomize()
	_arena_grid = get_parent() as ArenaGrid
	if not _arena_grid:
		_arena_grid = get_tree().get_current_scene().get_node_or_null("Arena") as ArenaGrid
	
	_origin = global_transform.origin
	_movement_target = _origin
	_base_height = global_position.y
	_projectile_timer = projectile_interval
	
	current_hp = max_hp
	current_mana = max_mana
	
	_setup_elemental()
	_setup_hp_bar()
	
	# Delay initial target choice to ensure arena is ready
	call_deferred("_choose_new_target")

func _setup_hp_bar() -> void:
	# Create a SubViewport for the UI
	_hp_viewport = SubViewport.new()
	_hp_viewport.size = Vector2(128, 16)
	_hp_viewport.transparent_bg = true
	_hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_hp_viewport)
	
	# Create the ProgressBar
	_hp_bar_node = ProgressBar.new()
	_hp_bar_node.size = Vector2(128, 16)
	_hp_bar_node.max_value = max_hp
	_hp_bar_node.value = max_hp
	_hp_bar_node.show_percentage = false
	
	# Style the ProgressBar
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = get_elemental_color()
	sb_fg.set_border_width_all(1)
	sb_fg.border_color = Color.BLACK
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	
	_hp_bar_node.add_theme_stylebox_override("fill", sb_fg)
	_hp_bar_node.add_theme_stylebox_override("background", sb_bg)
	_hp_viewport.add_child(_hp_bar_node)
	
	# Create the Sprite3D to display it
	_hp_sprite = Sprite3D.new()
	_hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_sprite.no_depth_test = true # Make it visible through floor/character
	_hp_sprite.texture = _hp_viewport.get_texture()
	_hp_sprite.position = Vector3(0, -1.1, 0)
	_hp_sprite.pixel_size = 0.01
	add_child(_hp_sprite)

func take_damage(amount: int) -> void:
	current_hp -= amount
	if _hp_bar_node:
		_hp_bar_node.value = current_hp
	if current_hp <= 0:
		die()

func die() -> void:
	# Respawns at the original position provided by ArenaGrid
	current_hp = max_hp
	if _hp_bar_node:
		_hp_bar_node.value = current_hp
	
	global_transform.origin = _origin + Vector3(0, 0.5, 0) # spawn slightly higher
	velocity = Vector3.ZERO
	_movement_target = _origin
	
	# Ensure physics is reset
	force_update_transform()

func _setup_elemental() -> void:
	# Virtual method for subclasses to configure their specific visuals/particles
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Mana regeneration
	current_mana = min(current_mana + mana_regen_rate * delta, max_mana)
		
	if is_controlled:
		_handle_controlled_movement(delta)
	else:
		_handle_wandering(delta)
		
	move_and_slide()

	_apply_bob(delta)
	
	if is_on_floor():
		_apply_ground_effects()
	
	if not is_controlled:
		_handle_projectiles(delta)

func _handle_controlled_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	var direction = Vector3(input_dir.x, 0.0, input_dir.y)
	
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_force
		else:
			velocity.y = 0.0

func get_elemental_color() -> Color:
	# Virtual method for subclasses
	return Color.WHITE

func launch_projectile_at(target_position: Vector3) -> void:
	if not _arena_grid or not projectile_scene:
		return
	
	if current_mana < shot_mana_cost:
		return
		
	current_mana -= shot_mana_cost
		
	var projectile = projectile_scene.instantiate()
	if not projectile:
		return
		
	var spawn_position = global_transform.origin
	var direction = (target_position - spawn_position).normalized()
	direction.y = 0 # Keep it horizontal like the automated one
	
	if direction == Vector3.ZERO:
		direction = Vector3.FORWARD
	
	var parent = get_parent()
	if not parent:
		parent = get_tree().get_current_scene()
	
	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis(), spawn_position)
	
	if projectile.has_method("initialize"):
		projectile.initialize(_arena_grid, global_transform.origin, _effective_range_world(), direction, projectile_speed, projectile_charge_capacity, projectile_lifetime)

func _handle_wandering(delta: float) -> void:
	if not _arena_grid:
		return
		
	var current_pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	if current_pos_2d.distance_to(target_pos_2d) < 0.15:
		_choose_new_target()
		
	var direction = (target_pos_2d - current_pos_2d).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.y * move_speed
	velocity.y = 0.0

func _apply_bob(delta: float) -> void:
	_bob_phase += bob_speed * delta
	var bob_offset = sin(_bob_phase) * bob_amplitude
	
	var body = get_node_or_null("Body")
	if body:
		body.position.y = bob_offset
	else:
		# Fallback if no Body node found
		if not is_controlled:
			global_position.y = _base_height + bob_offset

func _apply_ground_effects() -> void:
	_update_tile_below()
	if _ground_tile:
		if _check_tile_damage(_ground_tile):
			return
		_do_tile_effect(_ground_tile)

func _check_tile_damage(tile: HexTile) -> bool:
	if element_type == "fire":
		if tile.current_state == HexTile.State.MUD:
			take_damage(1)
			tile.current_state = HexTile.State.DIRT
			return true
		elif tile.current_state == HexTile.State.PUDDLE:
			take_damage(2)
			tile.current_state = HexTile.State.DIRT
			return true
	elif element_type == "water":
		if tile.current_state == HexTile.State.FIRE:
			take_damage(1)
			tile.current_state = HexTile.State.MUD
			return true
	return false

func _do_tile_effect(tile: HexTile) -> void:
	# Virtual method for subclasses
	pass

func _update_tile_below() -> void:
	if tile_detector:
		tile_detector.force_raycast_update()
		if tile_detector.is_colliding():
			var collider := tile_detector.get_collider()
			if collider and collider is HexTile:
				_ground_tile = collider
				return

	if _arena_grid:
		_ground_tile = _arena_grid.get_tile_at_world_position(global_transform.origin)
	else:
		_ground_tile = null

func _handle_projectiles(delta: float) -> void:
	if not _arena_grid or not projectile_scene:
		return
	_projectile_timer -= delta
	if _projectile_timer <= 0.0:
		_projectile_timer = projectile_interval
		_launch_projectile()

func _launch_projectile() -> void:
	if current_mana < shot_mana_cost:
		return
		
	current_mana -= shot_mana_cost
	
	var projectile = projectile_scene.instantiate()
	if not projectile:
		return
		
	var spawn_position = global_transform.origin
	var direction = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	if direction == Vector3.ZERO:
		direction = Vector3.FORWARD
	
	var parent = get_parent()
	if not parent:
		parent = get_tree().get_current_scene()
	
	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis(), spawn_position)
	
	# Assuming projectile has an initialize method
	if projectile.has_method("initialize"):
		projectile.initialize(_arena_grid, global_transform.origin, _effective_range_world(), direction, projectile_speed, projectile_charge_capacity, projectile_lifetime)

func _effective_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return trigger_range_in_tiles * base_hex_size * 1.5

func _choose_new_target() -> void:
	_update_tile_below()
	
	if _ground_tile:
		var neighbors = _ground_tile.neighbors.filter(func(t): 
			return t != null and is_instance_valid(t) and t.current_state != HexTile.State.STONE
		)
		
		if neighbors.size() > 0:
			var candidates = neighbors.filter(func(t): return t != _previous_tile)
			var next_tile: HexTile
			if candidates.size() > 0:
				next_tile = candidates[_rng.randi_range(0, candidates.size() - 1)]
			else:
				next_tile = neighbors[_rng.randi_range(0, neighbors.size() - 1)]
			
			_previous_tile = _ground_tile
			_movement_target = next_tile.global_transform.origin
			_movement_target.y = _base_height
			return

	# Fallback
	var heading = _rng.randf_range(0.0, TAU)
	_movement_target = global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * 3.0
	_movement_target.y = _base_height
