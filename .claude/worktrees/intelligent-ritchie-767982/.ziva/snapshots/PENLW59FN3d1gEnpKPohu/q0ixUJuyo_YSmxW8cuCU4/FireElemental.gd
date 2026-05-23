class_name FireElemental
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
@export var projectile_scene: PackedScene = preload("res://FireProjectile.tscn")

@onready var flame_particles: GPUParticles3D = $FlameParticles
@onready var tile_detector: RayCast3D = $TileDetector

var _arena_grid: ArenaGrid
var _movement_target: Vector3
var _base_height: float
var _bob_phase: float = 0.0
var _projectile_timer: float = 0.0
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ground_tile: HexTile

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
	_choose_new_target()

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
	var direction = _movement_target - global_transform.origin
	direction.y = 0.0
	if direction.length_squared() < 0.1:
		_choose_new_target()
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var normalized = direction.normalized()
	velocity.x = normalized.x * move_speed
	velocity.z = normalized.z * move_speed
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

	var radius = _effective_range_world()
	var tiles = _arena_grid.get_tiles_within_distance(global_transform.origin, radius)
	for candidate in tiles:
		candidate.apply_fire()

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
	var projectile = projectile_scene.instantiate() as FireProjectile
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
	var neighbor_targets = _collect_neighbor_targets()
	if neighbor_targets.size() > 0:
		_movement_target = neighbor_targets[_rng.randi_range(0, neighbor_targets.size() - 1)]
		return

	var heading = _rng.randf_range(0.0, TAU)
	var offset = Vector3(cos(heading), 0.0, sin(heading)) * roam_radius
	_movement_target = _origin + offset
	_movement_target.y = _base_height

func _collect_neighbor_targets() -> Array[Vector3]:
	var targets: Array[Vector3] = []
	if not _ground_tile:
		return targets
	for neighbor in _ground_tile.neighbors:
		if not neighbor or not is_instance_valid(neighbor):
			continue
		var position = neighbor.global_transform.origin
		position.y = _base_height
		targets.append(position)
	return targets

func _configure_particles() -> void:
	if not flame_particles:
		return
	flame_particles.emitting = true
	var material = flame_particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		flame_particles.process_material = material
	material.direction = Vector3.UP
	material.spread = 40.0
	material.initial_velocity = 2.0
	material.gravity = Vector3(0.0, 3.0, 0.0)
	material.scale = 0.45
	material.scale_random = 0.3
	material.color = Color(1.0, 0.4, 0.1)
