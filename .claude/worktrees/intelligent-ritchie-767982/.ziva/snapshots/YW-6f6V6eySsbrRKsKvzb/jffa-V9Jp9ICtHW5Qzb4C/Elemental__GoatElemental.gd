class_name GoatElemental
extends Elemental

## Specialized Elemental that represents a goat.
## Features a charge attack, terrain-based speed modifiers, and specialized visual effects.

@export_group("Goat Charge")
## The speed at which the goat charges forward.
@export var charge_speed: float = 25.0
## The maximum distance the goat can travel in a single charge.
@export var charge_distance: float = 5.0
## The time in seconds between consecutive charges.
@export var charge_cooldown: float = 1.0

# Charging state variables
var _is_charging: bool = false
var _charge_remaining_dist: float = 0.0
var _charge_cooldown_timer: float = 0.0

# Burning state variables
var _burning_time_left: float = 0.0
var _damage_tick_timer: float = 0.0
var _fire_particles: GPUParticles3D

# Water interaction state variables
var _splash_timer: float = 0.0
var _is_in_water: bool = false

# Constants for visual behavior
const SINK_OFFSET_PIXELS = 150.0
const SPLASH_INTERVAL = 1.0

func _init() -> void:
	# Set the elemental identity
	element_type = "goat"
	# Goats do not use projectiles, so projectile_scene is left null

func _setup_elemental() -> void:
	## Initializes the goat-specific visual elements, such as fire particles for the burning state.
	
	_fire_particles = GPUParticles3D.new()
	add_child(_fire_particles)
	_fire_particles.position = Vector3(0, 0, 0)
	_fire_particles.emitting = false
	
	# Configure particle material for fire effect
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 45.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0.0, 2.0, 0.0)
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.color = Color.WHITE
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.3, 0.1, 0.3)
	
	_fire_particles.process_material = material
	
	# Create the mesh for fire particles using a texture
	var pass_mesh = QuadMesh.new()
	var p_mat = StandardMaterial3D.new()
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color.WHITE
	p_mat.albedo_texture = load("res://assets/generated/fire_particle_1774823455.png")
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pass_mesh.material = p_mat
	_fire_particles.draw_pass_1 = pass_mesh
	_fire_particles.amount = 15
	_fire_particles.lifetime = 0.5

func get_elemental_color() -> Color:
	## Returns the thematic color for the goat elemental.
	return Color(0.7, 0.6, 0.4) # A light brown/grey

func _process(delta: float) -> void:
	## Main update loop handling visual updates and cooldowns.
	super._process(delta)
	_update_sprite_flip()
	_update_burning(delta)
	_update_water_effect(delta)
	
	# Handle charge cooldown
	if _charge_cooldown_timer > 0:
		_charge_cooldown_timer -= delta

func _update_water_effect(delta: float) -> void:
	## Monitors if the goat is standing in water (puddle) and triggers splash effects.
	if _ground_tile and _ground_tile.tile_type == HexTile.Type.PUDDLE:
		if not _is_in_water:
			_is_in_water = true
			_splash_timer = 0.0 # Trigger immediate splash upon entry
		
		# Instantly extinguish fire if we enter water
		if _burning_time_left > 0:
			_burning_time_left = 0.0
		
		_splash_timer -= delta
		if _splash_timer <= 0:
			_play_splash()
			_splash_timer = SPLASH_INTERVAL
	else:
		_is_in_water = false
		_splash_timer = 0.0

func _play_splash() -> void:
	## Plays the splash sound effect if available.
	var player = get_node_or_null("SplashPlayer") as AudioStreamPlayer3D
	if player and player.stream:
		player.play()

func _apply_bob(delta: float) -> void:
	## Custom bobbing logic for the goat, including a sinking effect when in water.
	var goat_bob_speed = 1.5
	var goat_bob_amplitude = 0.15
	
	_bob_phase += goat_bob_speed * delta
	var bob_offset = sin(_bob_phase) * goat_bob_amplitude
	
	var body = get_node_or_null("Body")
	if body:
		var sink_offset = 0.0
		if _is_in_water:
			# Calculate sinking depth based on visual pixel size and scale
			sink_offset = -SINK_OFFSET_PIXELS * body.pixel_size * body.scale.y
		
		# Combine base position, sinusoidal bobbing, and water sink offset
		body.position.y = _base_visual_y + bob_offset + sink_offset

func _update_burning(delta: float) -> void:
	## Handles the logic for when the goat is on fire, including damage over time.
	if _burning_time_left > 0:
		_burning_time_left -= delta
		_damage_tick_timer -= delta
		
		if _fire_particles:
			_fire_particles.emitting = true
		
		# Apply damage every tick
		if _damage_tick_timer <= 0:
			_take_fire_damage()
	else:
		if _fire_particles:
			_fire_particles.emitting = false
		_damage_tick_timer = 0.0

func _check_tile_damage(tile: HexTile) -> bool:
	## Overrides base damage check to add specific logic for fire tiles.
	if tile.tile_type == HexTile.Type.FIRE:
		_start_burning()
		return true
	return super._check_tile_damage(tile)

func _start_burning() -> void:
	## Initiates the burning state.
	if _burning_time_left <= 0:
		# Apply initial damage tick immediately
		_take_fire_damage()
	_burning_time_left = 1.0

func _take_fire_damage() -> void:
	## Applies damage and visual/audio feedback for fire damage.
	take_damage(1)
	_scream()
	_flash_red()
	_damage_tick_timer = 1.0

func _flash_red() -> void:
	## Briefly modulates the sprite red to indicate damage.
	var body = get_node_or_null("Body")
	if body:
		var tween = create_tween()
		tween.tween_property(body, "modulate", Color.RED, 0.1)
		tween.tween_property(body, "modulate", Color.WHITE, 0.1)

func _update_sprite_flip() -> void:
	## Flips the sprite horizontally based on its movement relative to the camera view.
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var cam_right = camera.global_transform.basis.x
		var move_dot_right = horizontal_velocity.dot(cam_right)
		
		var body = get_node_or_null("Body") as Sprite3D
		if body:
			# Determine horizontal flip based on screen-space direction
			if move_dot_right > 0.1:
				body.flip_h = false # Moving right
			elif move_dot_right < -0.1:
				body.flip_h = true # Moving left

func _do_tile_effect(_tile: HexTile) -> void:
	## Goats do not currently trigger any special effects when entering a tile.
	pass

func _launch_projectile() -> void:
	## Overrides base projectile logic as goats do not use projectiles.
	pass

func _unhandled_input(event: InputEvent) -> void:
	## Handles player input for scream (right click) and charge (left click) when controlled.
	if is_controlled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_scream()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_charge()
			get_viewport().set_input_as_handled()

func _handle_wandering(delta: float) -> void:
	## AI logic for wandering between points on the arena grid.
	if not _arena_grid:
		return
		
	var current_pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	# Check if we've reached the current target
	if current_pos_2d.distance_to(target_pos_2d) < 0.15:
		_choose_new_target()
		
	var multiplier = _get_speed_multiplier()
	var direction = (target_pos_2d - current_pos_2d).normalized()
	velocity.x = direction.x * move_speed * multiplier
	velocity.z = direction.y * move_speed * multiplier

func _get_speed_multiplier() -> float:
	## Returns a speed multiplier based on the current terrain the goat is standing on.
	if not _ground_tile:
		return 1.0
	if _ground_tile.tile_type == HexTile.Type.MUD:
		return 0.5
	if _ground_tile.tile_type == HexTile.Type.PUDDLE:
		return 0.25
	return 1.0

func _start_charge() -> void:
	## Initiates a fast-moving charge attack towards the mouse cursor position.
	if _is_charging or _charge_cooldown_timer > 0:
		return
		
	var target_pos = _get_mouse_3d_position()
	var diff = (target_pos - global_position)
	diff.y = 0 # Ensure charge is purely horizontal
	
	if diff.length() > 0.1:
		var dir = diff.normalized()
		_is_charging = true
		
		# Terrain affects the total charge distance and speed
		var multiplier = _get_speed_multiplier()
		_charge_remaining_dist = charge_distance * multiplier
		_charge_cooldown_timer = charge_cooldown
		
		velocity = dir * (charge_speed * multiplier)

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

func _handle_controlled_movement(delta: float) -> void:
	## Manages player-controlled movement and the active charge state.
	var multiplier = _get_speed_multiplier()
	
	if _is_charging:
		var current_charge_speed = charge_speed * multiplier
		var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		
		# Dynamically adjust velocity based on terrain during charge
		if horizontal_vel.length() > 0.001:
			var dir = horizontal_vel.normalized()
			velocity.x = dir.x * current_charge_speed
			velocity.z = dir.z * current_charge_speed
		
		horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		
		# Stop charging if we collide with something or reach the distance limit
		if horizontal_vel.length() < current_charge_speed * 0.5 and current_charge_speed > 0.1:
			_is_charging = false
			velocity = Vector3.ZERO
			return
			
		_charge_remaining_dist -= horizontal_vel.length() * delta
		if _charge_remaining_dist <= 0:
			_is_charging = false
			velocity = Vector3.ZERO
		return
	
	# Handle standard WASD/Arrow key movement
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
	
	# Move relative to the camera orientation
	var cam_basis = camera.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	var direction = (forward * (-input_dir.y) + right * input_dir.x).normalized()
	
	var effective_move_speed = move_speed * multiplier
	
	if direction.length() > 0.1:
		velocity.x = direction.x * effective_move_speed
		velocity.z = direction.z * effective_move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, effective_move_speed)
		velocity.z = move_toward(velocity.z, 0, effective_move_speed)

	# Jump logic
	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_force

func _scream() -> void:
	## Triggers the goat's iconic scream sound and visual effect.
	print("Goat is screaming!")
	var player = get_node_or_null("ScreamPlayer") as AudioStreamPlayer3D
	if player and player.stream:
		player.play()
	
	_show_scream_visual()

func _show_scream_visual() -> void:
	## Displays a "BAAAAAA!" comic book style speech bubble above the goat.
	var sprite = Sprite3D.new()
	var texture_path = "res://assets/generated/scream_bubble_frame_0_1774821924.png"
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
		sprite.pixel_size = 0.02
	else:
		# Fallback to text label if texture is missing
		print("Warning: Scream bubble texture not found at ", texture_path)
		_show_scream_text()
		return
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Vector3(0, 1.6, 0.1)
	sprite.modulate = Color.WHITE
	add_child(sprite)
	
	# Animate the speech bubble: pop in, shake, then float and fade
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2, 0.15)
	
	# Rapid shake for emphasis
	for i in range(4):
		var shake_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
		tween.tween_property(sprite, "position", Vector3(0, 1.6, 0.1) + shake_offset, 0.05)
	
	# Final fade and removal
	tween.tween_property(sprite, "position", Vector3(0, 1.6, 0.1), 0.05)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", 2.2, 0.4).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _show_scream_text() -> void:
	## Fallback visual effect using a Label3D.
	var label = Label3D.new()
	label.text = "BAAAAAA!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.5, 0)
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", 2.5, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func launch_projectile_at(_target_position: Vector3) -> void:
	## Implementation of the base class method; goats do not use projectiles.
	pass
