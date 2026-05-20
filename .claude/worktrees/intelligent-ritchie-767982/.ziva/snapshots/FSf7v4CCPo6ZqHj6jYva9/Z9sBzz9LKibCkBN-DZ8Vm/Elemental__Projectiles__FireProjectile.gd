class_name FireProjectile
extends BaseProjectile

@export_group("Sine Wave Visuals")
@export var sprite_pixel_size: float = 0.03
@export var wave_speed: float = 0.4
@export var wave_amplitude: float = 0.8
@export var wave_vertical_oscillation: float = 0.2
@export var wave_fwd_spacing: float = 0.4
@export var wave_time_scale: float = 0.25
@export var sprite_base_modulate: Color = Color(1.4, 1.4, 1.4, 1.0) # Glow effect

var _sprites: Array[Sprite3D] = []
var _random_offsets: Array[float] = []
var _rotation_angle: float = 0.0

func initialize(arena: ArenaGrid, caster_position: Vector3, effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, projectile_max_range: float = 45.0) -> void:
	# Call super.initialize first to set remaining_charges
	super.initialize(arena, caster_position, effect_range, direction, velocity, max_charges, projectile_lifetime, projectile_max_range)
	
	# Hide the default sphere if it exists
	var visual = get_node_or_null("ProjectileVisual")
	if visual:
		visual.visible = false
	
	_create_sprites(max_charges)

func _create_sprites(count: int) -> void:
	# Clear existing sprites if any
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	_random_offsets.clear()
	
	# Create a sprite for each charge
	for i in range(count):
		var sprite = Sprite3D.new()
		sprite.texture = load("res://assets/generated/fire_particle_1774823455.png")
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = sprite_pixel_size
		sprite.modulate = sprite_base_modulate
		add_child(sprite)
		_sprites.append(sprite)
		_random_offsets.append(randf() * TAU)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	_rotation_angle += delta * 15.0
	_update_visuals()

func _update_visuals() -> void:
	var active_count = remaining_charges
	if active_count <= 0:
		for s in _sprites:
			s.visible = false
		return
		
	# Calculate a horizontal vector perpendicular to movement
	var side_vec = Vector3(-_direction.z, 0, _direction.x).normalized()
	if side_vec.length_squared() < 0.01:
		side_vec = Vector3.RIGHT
		
	for i in range(_sprites.size()):
		var sprite = _sprites[i]
		if i < active_count:
			sprite.visible = true
			sprite.pixel_size = sprite_pixel_size # Update in case it changed in editor
			
			# _rotation_angle increases by delta * 15.0 (passed from physics_process)
			# Let's use it to calculate a wave phase for each sprite
			var phase = (_rotation_angle * wave_time_scale) + (float(i) * 0.8) + _random_offsets[i]
			
			# Sine wave side-to-side offset
			var side_offset = sin(phase * wave_speed) * wave_amplitude
			# Slight vertical oscillation
			var up_offset = cos(phase * (wave_speed * 0.5)) * wave_vertical_oscillation
			# Spread out along the path (behind the projectile head)
			var fwd_offset = -float(i) * wave_fwd_spacing
			
			# Position relative to node origin
			sprite.position = (side_vec * side_offset) + (Vector3.UP * up_offset) + (_direction * fwd_offset)
			
			# Fade out the ones further back
			var alpha = 1.0 - (float(i) / active_count) * 0.4
			sprite.modulate.a = alpha * sprite_base_modulate.a
		else:
			sprite.visible = false
