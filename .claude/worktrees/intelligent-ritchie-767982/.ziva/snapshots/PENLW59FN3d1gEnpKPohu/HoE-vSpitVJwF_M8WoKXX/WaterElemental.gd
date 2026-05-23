class_name WaterElemental
extends CharacterBody3D

@export var move_speed: float = 3.0
@export var roam_radius: float = 22.0
@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 2.2
@export_range(1.0, 10.0, 0.25) var trigger_range_in_tiles: float = 3.0
@export var projectile_interval: float = 1.0
@export var projectile_speed: float = 14.0
@export var projectile_lifetime: float = 5.0
@export var projectile_charge_capacity: int = 5
@export var projectile_scene: PackedScene = preload("res://WaterProjectile.tscn")

@onready var water_particles: GPUParticles3D = $WaterParticles
@onready var tile_detector: RayCast3D = $TileDetector

var _arena_grid: ArenaGrid
var _movement_target: Vector3
var _base_height: float
var _bob_phase: float = 0.0
var _projectile_timer: float = 0.0
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ground_tile: HexTile

var _previous_tile: HexTile

func _ready() -> void:
	_rng.randomize()
	_arena_grid = get_parent() as ArenaGrid
	if not _arena_grid:
		_arena_grid = get_tree().get_current_scene().get_node("Arena") as ArenaGrid
	_origin = global_transform.origin
	_movement_target = _origin
	_base_height = global_position.y
	_projectile_timer = projectile_interval
	_configure_particles()
	
	# Delay initial target choice to ensure arena is ready
	call_deferred("_choose_new_target")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_handle_wandering(delta)
	move_and_slide()

	_apply_bob(delta)
	_apply_ground_effects()
	_handle_projectiles(delta)

func _handle_wandering(delta: float) -> void:
	if not _arena_grid:
		return
		
	var current_pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	if current_pos_2d.distance_to(target_pos_2d) < 0.15:
		_choose_new_target()
		
	var direction = (target_pos_2d - current_pos_2d).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.y * move_speed
	velocity.y = 0.0

func _apply_bob(delta: float) -> void:
	_bob_phase += bob_speed * delta
	var bob_offset = sin(_bob_phase) * bob_amplitude
	var current_position = global_position
	current_position.y = _base_height + bob_offset
	global_position = current_position

func _apply_ground_effects() -> void:
	if not _arena_grid:
		return

	_update_tile_below()
	if _ground_tile:
		_ground_tile.apply_water()

func _update_tile_below() -> void:
	if tile_detector:
		tile_detector.force_raycast_update()
		if tile_detector.is_colliding():
			var collider := tile_detector.get_collider()
			if collider and collider is HexTile:
				_ground_tile = collider
				return

	if _arena_grid:
		var fallback_tile = _arena_grid.get_tile_at_world_position(global_transform.origin)
		_ground_tile = fallback_tile
	else:
		_ground_tile = null

func _handle_projectiles(delta: float) -> void:
	if not _arena_grid or not projectile_scene:
		return
	_projectile_timer -= delta
	if _projectile_timer > 0.0:
		return
	_projectile_timer = projectile_interval
	_launch_projectile()

func _launch_projectile() -> void:
	if not _arena_grid:
		return
	var projectile = projectile_scene.instantiate() as WaterProjectile
	if not projectile:
		return
	var spawn_position = global_transform.origin
	var direction = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	if direction == Vector3.ZERO:
		direction = Vector3.FORWARD
	var parent = get_parent()
	if not parent:
		parent = get_tree().get_current_scene()
	if not parent:
		return
	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis(), spawn_position)
	projectile.initialize(_arena_grid, global_transform.origin, _effective_range_world(), direction, projectile_speed, projectile_charge_capacity, projectile_lifetime)

func _effective_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return trigger_range_in_tiles * base_hex_size * 1.5

func _choose_new_target() -> void:
	_update_tile_below()
	
	if _ground_tile:
		var neighbors = _ground_tile.neighbors.filter(func(t): 
			return t != null and is_instance_valid(t) and t.current_state != HexTile.State.STONE
		)
		
		if neighbors.size() > 0:
			# Avoid backtracking if possible
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

	# Fallback to random wander if stuck
	var heading = _rng.randf_range(0.0, TAU)
	_movement_target = global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * 3.0
	_movement_target.y = _base_height

func _configure_particles() -> void:
	if not water_particles:
		return
	water_particles.emitting = true
	water_particles.amount = 30
	water_particles.lifetime = 1.0
	var material = water_particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		water_particles.process_material = material
	material.direction = Vector3.UP
	material.spread = 40.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0.0, -2.0, 0.0) # Water falls down slightly? Or just float up like bubbles
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = Color(0.1, 0.5, 1.0, 0.8)
	
	if not water_particles.draw_pass_1:
		var pass_mesh = QuadMesh.new()
		var p_mat = StandardMaterial3D.new()
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.vertex_color_use_as_albedo = true
		p_mat.albedo_color = Color(0.1, 0.5, 1.0, 0.8)
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pass_mesh.material = p_mat
		water_particles.draw_pass_1 = pass_mesh
