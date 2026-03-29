class_name FireElemental
extends Elemental

func _init() -> void:
	projectile_scene = preload("res://FireProjectile.tscn")
	element_type = "fire"

func _setup_elemental() -> void:
	# Specifically looking for "FlameParticles" to match scene tree
	var particles = get_node_or_null("FlameParticles")
	if particles and particles is GPUParticles3D:
		_configure_particles(particles)

func get_elemental_color() -> Color:
	return Color(1.0, 0.4, 0.1)

func _do_tile_effect(tile: HexTile) -> void:
	tile.apply_fire()

func _configure_particles(particles: GPUParticles3D) -> void:
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 1.0
	
	var material = particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
		
	material.direction = Vector3.UP
	material.spread = 40.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0.0, 3.0, 0.0)
	material.scale_min = 0.3
	material.scale_max = 0.6
	material.color = Color(1.0, 0.4, 0.1)
	
	if not particles.draw_pass_1:
		var pass_mesh = QuadMesh.new()
		var p_mat = StandardMaterial3D.new()
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.vertex_color_use_as_albedo = true
		p_mat.albedo_color = Color(1.0, 0.4, 0.1)
		pass_mesh.material = p_mat
		particles.draw_pass_1 = pass_mesh
