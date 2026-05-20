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
@export var projectile_max_range_in_tiles: float = 20.0
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
@onready var _body: Node3D = get_node_or_null("Body")

var is_controlled: bool = false
var element_type: String = "none"

signal hp_changed(new_hp: int, max_hp: int)
signal mana_changed(new_mana: float, max_mana: float)

var current_hp: int = 10:
	set(value):
		if current_hp != value:
			current_hp = value
			hp_changed.emit(current_hp, max_hp)

var current_mana: float = 100.0:
	set(value):
		var old_int = int(current_mana)
		current_mana = value
		if int(current_mana) != old_int:
			mana_changed.emit(current_mana, max_mana)

var _arena_grid: ArenaGrid
var _movement_target: Vector3
var _base_height: float
var _bob_phase: float = 0.0
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ground_tile: HexTile
var _previous_tile: HexTile

var _hp_bar_node: ProgressBar
var _hp_viewport: SubViewport
var _hp_sprite: Sprite3D

var _base_visual_y: float = 0.0
var _mana_particles: Array[Sprite3D] = []
var _mana_particles_container: Node3D
var _mana_phase: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_mana_phase = _rng.randf_range(0, 100) # Random start
	_arena_grid = get_parent() as ArenaGrid
	if not _arena_grid:
		_arena_grid = get_tree().get_current_scene().get_node_or_null("Arena") as ArenaGrid
	
	_origin = global_transform.origin
	_movement_target = _origin
	_base_height = global_position.y
	
	if _body:
		_base_visual_y = _body.position.y
	
	current_hp = max_hp
	current_mana = max_mana
	
	_setup_elemental()
	_setup_hp_bar()
	_setup_mana_visuals()
	
	# Delay initial target choice to ensure arena is ready
	call_deferred("_choose_new_target")

func _setup_mana_visuals() -> void:
	_mana_particles_container = Node3D.new()
	_mana_particles_container.name = "ManaParticlesContainer"
	add_child(_mana_particles_container)
	# Set initial position to match where Body would be
	if _body:
		_mana_particles_container.position.y = _body.position.y


func _get_mana_particle_texture() -> Texture2D:
	return null

func _setup_hp_bar() -> void:
	# Create a SubViewport for the UI
	_hp_viewport = SubViewport.new()
	_hp_viewport.size = Vector2(128, 16)
	_hp_viewport.transparent_bg = true
	_hp_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	sb_fg.set_border_width_all(2)
	sb_fg.border_color = Color.BLACK
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 1.0) # Opaque background
	
	_hp_bar_node.add_theme_stylebox_override("fill", sb_fg)
	_hp_bar_node.add_theme_stylebox_override("background", sb_bg)
	_hp_viewport.add_child(_hp_bar_node)
	
	# Create the Sprite3D to display it
	_hp_sprite = Sprite3D.new()
	_hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_sprite.no_depth_test = true
	_hp_sprite.render_priority = 10
	_hp_sprite.texture = _hp_viewport.get_texture()
	_hp_sprite.position = Vector3(0, -1.5, 0)
	_hp_sprite.pixel_size = 0.015
	add_child(_hp_sprite)
	
	_update_hp_bar()

func _update_hp_bar() -> void:
	if _hp_bar_node:
		_hp_bar_node.value = current_hp
	
	if _hp_viewport:
		_hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	if _hp_sprite:
		_hp_sprite.texture = _hp_viewport.get_texture()
		_hp_sprite.visible = (current_hp < max_hp) and (current_hp > 0)

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	print(name, " took ", amount, " damage. HP: ", current_hp)
	_update_hp_bar()
	if current_hp <= 0:
		die()

func hit_by_projectile(projectile: BaseProjectile) -> void:
	## Default implementation for being hit by a projectile.
	take_damage(projectile.remaining_charges)

func die() -> void:
	# Respawns at the original position provided by ArenaGrid
	current_hp = max_hp
	_update_hp_bar()
	
	global_transform.origin = _origin + Vector3(0, 0.5, 0) # spawn slightly higher
	velocity = Vector3.ZERO
	_movement_target = _origin
	
	# Ensure physics is reset
	force_update_transform()

func _setup_elemental() -> void:
	# Virtual method for subclasses to configure their specific visuals/particles
	pass

func _process(delta: float) -> void:
	_update_mana_visuals(delta)

func _update_mana_visuals(delta: float) -> void:
	var texture = _get_mana_particle_texture()
	if not texture:
		# Cleanup if no texture
		for p in _mana_particles:
			if is_instance_valid(p): p.queue_free()
		_mana_particles.clear()
		return
		
	var charges = 0
	if shot_mana_cost > 0:
		charges = int(current_mana / 5)
	
	# Sync number of sprites
	while _mana_particles.size() < charges:
		var sprite = Sprite3D.new()
		sprite.texture = texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.03
		sprite.render_priority = 5
		sprite.transparent = true
		if "shading_mode" in sprite:
			sprite.set("shading_mode", BaseMaterial3D.SHADING_MODE_UNSHADED)
		
		# Give it unique movement data
		# We'll use a random rotation to orient the figure-8 orbit in 3D space
		var rand_axis = Vector3(_rng.randf_range(-1,1), _rng.randf_range(-1,1), _rng.randf_range(-1,1)).normalized()
		if rand_axis == Vector3.ZERO: rand_axis = Vector3.UP
		var orbit_basis = Basis(rand_axis, _rng.randf_range(0, TAU))
		
		sprite.set_meta("orbit_rotation", orbit_basis)
		sprite.set_meta("phase_offset", _rng.randf_range(0, TAU))
		sprite.set_meta("speed_mult", _rng.randf_range(0.3, 0.6)) # Slow and loitering
		
		if _mana_particles_container:
			_mana_particles_container.add_child(sprite)
		else:
			add_child(sprite)
		_mana_particles.append(sprite)
		
	while _mana_particles.size() > charges:
		var sprite = _mana_particles.pop_back()
		if is_instance_valid(sprite):
			sprite.queue_free()
		
	# Update positions using figure-8 pattern
	_mana_phase += delta
	var orbit_radius = 1.1
	for i in range(_mana_particles.size()):
		var sprite = _mana_particles[i]
		if not is_instance_valid(sprite): continue
		
		var phase = _mana_phase * sprite.get_meta("speed_mult") + sprite.get_meta("phase_offset")
		
		# Figure 8 in local space: Lissajous curve
		var lx = sin(phase) * orbit_radius
		var ly = sin(2.0 * phase) * (orbit_radius * 0.5)
		var lz = cos(phase) * (orbit_radius * 0.2) # Adds some 3D depth to the path
		
		var orbit_rot = sprite.get_meta("orbit_rotation") as Basis
		sprite.position = orbit_rot * Vector3(lx, ly, lz)
		
		# Scale pulse slightly to feel more alive
		var s = 0.8 + sin(phase * 1.5) * 0.15
		sprite.scale = Vector3.ONE * s

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Mana regeneration for everyone
	var current_regen = mana_regen_rate
	if is_on_floor():
		_update_tile_below()
		if _ground_tile:
			if element_type == "fire" and _ground_tile.current_state == HexTile.State.FIRE:
				current_regen *= 2.0
			elif element_type == "water" and _ground_tile.current_state == HexTile.State.PUDDLE:
				current_regen *= 2.0
				
	current_mana = min(current_mana + current_regen * delta, max_mana)
		
	# Movement
	if is_controlled:
		_handle_controlled_movement(delta)
	else:
		_handle_wandering(delta)
	
	# Gravity for everyone
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif not is_controlled:
		velocity.y = 0.0
		
	move_and_slide()

	_apply_bob(delta)
	
	if is_on_floor():
		_apply_ground_effects()
	
	if not is_controlled:
		if current_mana >= max_mana:
			_launch_projectile()

func _get_move_speed() -> float:
	return move_speed

func _get_jump_force() -> float:
	return jump_force

func _handle_controlled_movement(delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
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
	
	var cam_basis = camera.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	var direction = (forward * (-input_dir.y) + right * input_dir.x).normalized()
	
	var speed = _get_move_speed()
	if direction.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Jump input
	if is_on_floor():
		velocity.y = 0.0 # Reset vertical velocity on landing
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			velocity.y = _get_jump_force()

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
		projectile.initialize(_arena_grid, global_transform.origin, _effective_range_world(), direction, projectile_speed, projectile_charge_capacity, projectile_lifetime, _projectile_max_range_world())

func _handle_wandering(delta: float) -> void:
	if not _arena_grid:
		return
		
	var current_pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	if current_pos_2d.distance_to(target_pos_2d) < 0.15:
		_choose_new_target()
		
	var speed = _get_move_speed()
	var direction = (target_pos_2d - current_pos_2d).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.y * speed

func _apply_bob(delta: float) -> void:
	_bob_phase += bob_speed * delta
	var bob_offset = sin(_bob_phase) * bob_amplitude
	
	if _body:
		_body.position.y = _base_visual_y + bob_offset
	
	if _mana_particles_container:
		_mana_particles_container.position.y = _base_visual_y + bob_offset
	
	if not _body and not is_controlled:
		# Fallback if no Body node found
		global_position.y = _base_height + bob_offset

func _apply_ground_effects() -> void:
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
		projectile.initialize(_arena_grid, global_transform.origin, _effective_range_world(), direction, projectile_speed, projectile_charge_capacity, projectile_lifetime, _projectile_max_range_world())

func _effective_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return trigger_range_in_tiles * base_hex_size * 1.5

func _projectile_max_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return projectile_max_range_in_tiles * base_hex_size * 1.5

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

## Standardizes GPUParticles3D setup for elementals and tiles.
static func setup_gpu_particles(particles: GPUParticles3D, params: Dictionary) -> void:
	if not particles: return
	
	particles.emitting = params.get("emitting", true)
	particles.amount = params.get("amount", 20)
	particles.lifetime = params.get("lifetime", 1.0)
	particles.local_coords = params.get("local_coords", true)
	
	var material = particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
		
	material.direction = params.get("direction", Vector3.UP)
	material.spread = params.get("spread", 45.0)
	material.initial_velocity_min = params.get("velocity_min", 1.0)
	material.initial_velocity_max = params.get("velocity_max", 2.0)
	material.gravity = params.get("gravity", Vector3.ZERO)
	material.scale_min = params.get("scale_min", 0.1)
	material.scale_max = params.get("scale_max", 0.2)
	material.color = params.get("color", Color.WHITE)
	
	if params.has("emission_shape"):
		material.emission_shape = params["emission_shape"]
	if params.has("emission_box_extents"):
		material.emission_box_extents = params["emission_box_extents"]
	if params.has("damping_min"):
		material.damping_min = params["damping_min"]
	if params.has("damping_max"):
		material.damping_max = params["damping_max"]

	if not particles.draw_pass_1:
		var pass_mesh = QuadMesh.new()
		var p_mat = StandardMaterial3D.new()
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.vertex_color_use_as_albedo = true
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		if params.has("texture"):
			var tex = params["texture"]
			if tex is String:
				p_mat.albedo_texture = load(tex)
			elif tex is Texture2D:
				p_mat.albedo_texture = tex
				
		pass_mesh.material = p_mat
		particles.draw_pass_1 = pass_mesh
