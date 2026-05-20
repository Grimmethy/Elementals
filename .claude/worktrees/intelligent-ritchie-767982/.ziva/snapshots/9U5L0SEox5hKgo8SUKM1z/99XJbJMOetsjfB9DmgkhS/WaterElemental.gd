class_name WaterElemental
extends Elemental

func _init() -> void:
	projectile_scene = preload("res://WaterProjectile.tscn")

func _setup_elemental() -> void:
	# Specifically looking for "WaterParticles" to match scene tree
	var particles = get_node_or_null("WaterParticles")
	if particles and particles is GPUParticles3D:
		_configure_particles(particles)

func get_elemental_color() -> Color:
	return Color(0.1, 0.5, 1.0, 0.8)

func _do_tile_effect(tile: HexTile) -> void:
	tile.apply_water()

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
	material.gravity = Vector3(0.0, -2.0, 0.0)
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = Color(0.1, 0.5, 1.0, 0.8)
	
	if not particles.draw_pass_1:
		var pass_mesh = QuadMesh.new()
		var p_mat = StandardMaterial3D.new()
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.vertex_color_use_as_albedo = true
		p_mat.albedo_color = Color(0.1, 0.5, 1.0, 0.8)
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pass_mesh.material = p_mat
		particles.draw_pass_1 = pass_mesh
