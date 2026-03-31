class_name WaterElemental
extends Elemental

func _init() -> void:
	projectile_scene = preload("res://Elemental/Projectiles/WaterProjectile.tscn")
	element_type = "water"

func _setup_elemental() -> void:	
	# Hide the body mesh so the elemental is only represented by particles
	var body = get_node_or_null("Body")
	if body:
		body.visible = false

func _get_mana_particle_texture() -> Texture2D:
	return load("res://assets/generated/magic_water_drop_frame_0_1774826822.png")

func get_elemental_color() -> Color:
	return Color(0.1, 0.5, 1.0)

func _do_tile_effect(tile: HexTile) -> void:
	if tile.apply_water():
		if tile.current_state == HexTile.State.PUDDLE:
			current_mana = min(current_mana + 1.0, max_mana)

func _configure_particles(particles: GPUParticles3D) -> void:
	Elemental.setup_gpu_particles(particles, {
		"amount": 20,
		"spread": 45.0,
		"velocity_min": 1.0,
		"velocity_max": 2.0,
		"gravity": Vector3(0.0, -1.0, 0.0),
		"scale_min": 0.1,
		"scale_max": 0.2,
		"color": Color(0.4, 0.7, 1.0, 0.6),
		"texture": "res://assets/generated/magic_water_drop_frame_0_1774826822.png"
	})

func _configure_drips(particles: GPUParticles3D) -> void:
	Elemental.setup_gpu_particles(particles, {
		"amount": 15,
		"lifetime": 1.2,
		"local_coords": false,
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX,
		"emission_box_extents": Vector3(0.5, 0.2, 0.5),
		"direction": Vector3.DOWN,
		"spread": 10.0,
		"velocity_min": 0.1,
		"velocity_max": 0.5,
		"gravity": Vector3(0.0, -9.8, 0.0),
		"scale_min": 0.15,
		"scale_max": 0.3,
		"damping_min": 0.5,
		"damping_max": 1.0,
		"texture": "res://assets/generated/magic_water_drop_frame_1_1774826822.png"
	})
