class_name FireElemental
extends Elemental

func _init() -> void:
	projectile_scene = preload("res://Elemental/Projectiles/FireProjectile.tscn")
	element_type = "fire"

func _setup_elemental() -> void:
	# Specifically looking for "FlameParticles" to match scene tree
	var particles = get_node_or_null("FlameParticles")
	if particles and particles is GPUParticles3D:
		_configure_particles(particles)
	
	# Hide the body mesh so the elemental is only represented by particles
	var body = get_node_or_null("Body")
	if body:
		body.visible = false

func _get_mana_particle_texture() -> Texture2D:
	return load("res://assets/generated/fire_particle_1774823455.png")

func get_elemental_color() -> Color:
	return Color(1.0, 0.4, 0.1)

func _do_tile_effect(tile: HexTile) -> void:
	if tile.apply_fire():
		if tile.current_state == HexTile.State.FIRE:
			current_mana = min(current_mana + 1.0, max_mana)

func _configure_particles(particles: GPUParticles3D) -> void:
	Elemental.setup_gpu_particles(particles, {
		"amount": 30,
		"spread": 40.0,
		"velocity_min": 2.0,
		"velocity_max": 2.0,
		"gravity": Vector3(0.0, 3.0, 0.0),
		"scale_min": 0.3,
		"scale_max": 0.6
	})
