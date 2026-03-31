class_name GoatElemental
extends Elemental

@export_group("Goat Charge")
@export var charge_speed: float = 25.0
@export var charge_distance: float = 5.0
@export var charge_cooldown: float = 1.0

var _is_charging: bool = false
var _charge_remaining_dist: float = 0.0
var _charge_cooldown_timer: float = 0.0

var _burning_time_left: float = 0.0
var _damage_tick_timer: float = 0.0
var _fire_particles: GPUParticles3D
var _splash_timer: float = 0.0
var _is_in_water: bool = false

const SINK_OFFSET_PIXELS = 150.0
const SPLASH_INTERVAL = 1.0

func _init() -> void:
	element_type = "goat"
	# projectile_scene is left null

func _setup_elemental() -> void:
	# Add small fire particles
	_fire_particles = GPUParticles3D.new()
	add_child(_fire_particles)
	_fire_particles.position = Vector3(0, 0, 0)
	_fire_particles.emitting = false
	
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
	# A light brown/grey for the goat
	return Color(0.7, 0.6, 0.4)

func _process(delta: float) -> void:
	super._process(delta)
	_update_sprite_flip()
	_update_burning(delta)
	_update_water_effect(delta)
	if _charge_cooldown_timer > 0:
		_charge_cooldown_timer -= delta

func _update_water_effect(delta: float) -> void:
	if _ground_tile and _ground_tile.tile_type == HexTile.Type.PUDDLE:
		if not _is_in_water:
			_is_in_water = true
			_splash_timer = 0.0 # Splash immediately
		
		_splash_timer -= delta
		if _splash_timer <= 0:
			_play_splash()
			_splash_timer = SPLASH_INTERVAL
	else:
		_is_in_water = false
		_splash_timer = 0.0

func _play_splash() -> void:
	var player = get_node_or_null("SplashPlayer") as AudioStreamPlayer3D
	if player and player.stream:
		player.play()

func _apply_bob(delta: float) -> void:
	# Reduced bobbing for the goat
	var goat_bob_speed = 1.5
	var goat_bob_amplitude = 0.15
	
	_bob_phase += goat_bob_speed * delta
	var bob_offset = sin(_bob_phase) * goat_bob_amplitude
	
	var body = get_node_or_null("Body")
	if body:
		var sink_offset = 0.0
		if _is_in_water:
			# Sink by 40 pixels. pixel_size and scale are used to convert to world units.
			sink_offset = -SINK_OFFSET_PIXELS * body.pixel_size * body.scale.y
		
		body.position.y = _base_visual_y + bob_offset + sink_offset

func _update_burning(delta: float) -> void:
	if _burning_time_left > 0:
		_burning_time_left -= delta
		_damage_tick_timer -= delta
		
		if _fire_particles:
			_fire_particles.emitting = true
		
		if _damage_tick_timer <= 0:
			_take_fire_damage()
	else:
		if _fire_particles:
			_fire_particles.emitting = false
		_damage_tick_timer = 0.0

func _check_tile_damage(tile: HexTile) -> bool:
	if tile.tile_type == HexTile.Type.FIRE:
		_start_burning()
		return true
	return super._check_tile_damage(tile)

func _start_burning() -> void:
	if _burning_time_left <= 0:
		# Just caught fire
		_take_fire_damage()
	_burning_time_left = 1.0

func _take_fire_damage() -> void:
	take_damage(1)
	_scream()
	_flash_red()
	_damage_tick_timer = 1.0

func _flash_red() -> void:
	var body = get_node_or_null("Body")
	if body:
		var tween = create_tween()
		tween.tween_property(body, "modulate", Color.RED, 0.1)
		tween.tween_property(body, "modulate", Color.WHITE, 0.1)

func _update_sprite_flip() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var cam_right = camera.global_transform.basis.x
		var move_dot_right = horizontal_velocity.dot(cam_right)
		
		var body = get_node_or_null("Body") as Sprite3D
		if body:
			# If move_dot_right > 0, it's moving towards screen-right
			# If move_dot_right < 0, it's moving towards screen-left
			# We assume the sprite faces right by default.
			if move_dot_right > 0.1:
				body.flip_h = false
			elif move_dot_right < -0.1:
				body.flip_h = true

func _do_tile_effect(_tile: HexTile) -> void:
	# Goats have no tile effect
	pass

func _launch_projectile() -> void:
	# Projectiles are disabled for goats
	pass

func _unhandled_input(event: InputEvent) -> void:
	if is_controlled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_scream()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_charge()
			get_viewport().set_input_as_handled()

func _handle_wandering(delta: float) -> void:
	if not _arena_grid:
		return
		
	var current_pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	if current_pos_2d.distance_to(target_pos_2d) < 0.15:
		_choose_new_target()
		
	var multiplier = _get_speed_multiplier()
	var direction = (target_pos_2d - current_pos_2d).normalized()
	velocity.x = direction.x * move_speed * multiplier
	velocity.z = direction.y * move_speed * multiplier

func _get_speed_multiplier() -> float:
	if not _ground_tile:
		return 1.0
	if _ground_tile.tile_type == HexTile.Type.MUD:
		return 0.5
	if _ground_tile.tile_type == HexTile.Type.PUDDLE:
		return 0.25
	return 1.0

func _start_charge() -> void:
	if _is_charging or _charge_cooldown_timer > 0:
		return
		
	var target_pos = _get_mouse_3d_position()
	var diff = (target_pos - global_position)
	diff.y = 0 # keep it flat
	
	if diff.length() > 0.1:
		var dir = diff.normalized()
		_is_charging = true
		
		var multiplier = _get_speed_multiplier()
		_charge_remaining_dist = charge_distance * multiplier
		_charge_cooldown_timer = charge_cooldown
		
		velocity = dir * (charge_speed * multiplier)
		_scream()

func _get_mouse_3d_position() -> Vector3:
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
	var multiplier = _get_speed_multiplier()
	
	if _is_charging:
		var current_charge_speed = charge_speed * multiplier
		var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		
		# Update velocity to account for terrain changes during charge
		if horizontal_vel.length() > 0.001:
			var dir = horizontal_vel.normalized()
			velocity.x = dir.x * current_charge_speed
			velocity.z = dir.z * current_charge_speed
		
		# Re-read horizontal_vel after adjustment
		horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		
		# If we hit something (horizontal velocity decreased significantly below expected speed), stop charging.
		if horizontal_vel.length() < current_charge_speed * 0.5 and current_charge_speed > 0.1:
			_is_charging = false
			velocity = Vector3.ZERO
			return
			
		_charge_remaining_dist -= horizontal_vel.length() * delta
		if _charge_remaining_dist <= 0:
			_is_charging = false
			velocity = Vector3.ZERO
		return
	
	# Handle manual movement with multiplier
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
	
	var effective_move_speed = move_speed * multiplier
	
	if direction.length() > 0.1:
		velocity.x = direction.x * effective_move_speed
		velocity.z = direction.z * effective_move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, effective_move_speed)
		velocity.z = move_toward(velocity.z, 0, effective_move_speed)

	# Jump input
	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_force

func _scream() -> void:
	print("Goat is screaming!")
	var player = get_node_or_null("ScreamPlayer") as AudioStreamPlayer3D
	if player and player.stream:
		player.play()
	
	_show_scream_visual()

func _show_scream_visual() -> void:
	var sprite = Sprite3D.new()
	# Use the newly generated comic book bubble
	var texture_path = "res://assets/generated/scream_bubble_frame_0_1774821924.png"
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
		sprite.pixel_size = 0.02 # Slightly larger for comic effect
	else:
		print("Warning: Scream bubble texture not found at ", texture_path)
		_show_scream_text()
		return
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Vector3(0, 1.6, 0.1) # Positioned above the head
	sprite.modulate = Color.WHITE
	add_child(sprite)
	
	# Comic book style pop-in animation
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	# Pop in quickly with a little bounce
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2, 0.15)
	
	# Shake effect
	for i in range(4):
		var shake_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
		tween.tween_property(sprite, "position", Vector3(0, 1.6, 0.1) + shake_offset, 0.05)
	
	# Return to center and then float/fade
	tween.tween_property(sprite, "position", Vector3(0, 1.6, 0.1), 0.05)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", 2.2, 0.4).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _show_scream_text() -> void:
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
	# Projectiles are disabled for goats
	pass
