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
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 1.0
	
	var material = particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
		
	material.direction = Vector3.UP
	material.spread = 45.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0.0, -1.0, 0.0)
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.color = Color(0.4, 0.7, 1.0, 0.6)
	
	if not particles.draw_pass_1:
		_setup_particle_mesh(particles, "res://assets/generated/magic_water_drop_frame_0_1774826822.png")

func _configure_drips(particles: GPUParticles3D) -> void:
	particles.emitting = true
	particles.amount = 15
	particles.lifetime = 1.2
	particles.local_coords = false # Critical for "dripping off" look
	
	var material = particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.5, 0.2, 0.5)
	material.direction = Vector3.DOWN
	material.spread = 10.0
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.5
	material.gravity = Vector3(0.0, -9.8, 0.0) # Real gravity for dripping
	material.scale_min = 0.15
	material.scale_max = 0.3
	material.damping_min = 0.5
	material.damping_max = 1.0
	
	if not particles.draw_pass_1:
		_setup_particle_mesh(particles, "res://assets/generated/magic_water_drop_frame_1_1774826822.png")

func _setup_particle_mesh(particles: GPUParticles3D, texture_path: String) -> void:
	var pass_mesh = QuadMesh.new()
	var p_mat = StandardMaterial3D.new()
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_texture = load(texture_path)
	p_mat.vertex_color_use_as_albedo = true
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pass_mesh.material = p_mat
	particles.draw_pass_1 = pass_mesh
