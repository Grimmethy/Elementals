class_name FireProjectile
extends BaseProjectile

var _sprites: Array[Sprite3D] = []
var _rotation_angle: float = 0.0

func initialize(arena: ArenaGrid, caster_position: Vector3, effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, projectile_max_range: float = 45.0) -> void:
	# Call super.initialize first to set _remaining_charges
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
	
	# Create a sprite for each charge
	for i in range(count):
		var sprite = Sprite3D.new()
		sprite.texture = load("res://assets/generated/fire_particle_1774823455.png")
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.012
		sprite.modulate = Color(1.2, 1.2, 1.2, 1.0) # Slight glow
		add_child(sprite)
		_sprites.append(sprite)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	_rotation_angle += delta * 15.0
	_update_visuals()

func _update_visuals() -> void:
	var active_count = _remaining_charges
	if active_count <= 0:
		for s in _sprites:
			s.visible = false
		return
		
	for i in range(_sprites.size()):
		var sprite = _sprites[i]
		if i < active_count:
			sprite.visible = true
			# Arrange in an orbiting ring that balances as sprites are removed
			var angle = _rotation_angle + (float(i) / active_count) * TAU
			var radius = 0.35
			var y_off = sin(_rotation_angle * 0.4 + i) * 0.08
			sprite.position = Vector3(cos(angle) * radius, y_off, sin(angle) * radius)
		else:
			sprite.visible = false
