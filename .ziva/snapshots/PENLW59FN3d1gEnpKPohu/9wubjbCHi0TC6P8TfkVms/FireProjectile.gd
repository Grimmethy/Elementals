class_name FireProjectile
extends Node3D

@export var speed: float = 14.0
@export var lifetime: float = 5.0
@export var charge_capacity: int = 5

@onready var tile_ray: RayCast3D = $TileRay

var _arena: ArenaGrid
var _caster_position: Vector3
var _effect_range: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _remaining_charges: int = 0
var _elapsed: float = 0.0
var _affected_tiles: Dictionary = {}

func initialize(arena: ArenaGrid, caster_position: Vector3, effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float) -> void:
	_arena = arena
	_caster_position = caster_position
	_effect_range = effect_range
	_direction = direction.normalized()
	speed = velocity
	charge_capacity = max_charges
	_remaining_charges = max_charges
	lifetime = projectile_lifetime
	_elapsed = 0.0
	_affected_tiles.clear()
	if tile_ray:
		tile_ray.target_position = Vector3(0, -3.0, 0)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime or _remaining_charges <= 0:
		queue_free()
		return
	translate(_direction * speed * delta)
	_apply_effect_to_tiles()

func _apply_effect_to_tiles() -> void:
	if not _arena or _remaining_charges <= 0:
		return
		
	# Check for direct stone wall impact
	var tile_below := _get_tile_below()
	if not tile_below:
		tile_below = _arena.get_tile_at_world_position(global_transform.origin)
	if tile_below and tile_below.current_state == HexTile.State.STONE:
		queue_free()
		return

	var tiles = _arena.get_tiles_within_distance(global_transform.origin, _effect_range)
	for tile in tiles:
		if _remaining_charges <= 0:
			break
		
		var tid = tile.get_instance_id()
		if _affected_tiles.has(tid):
			continue
			
		if tile.apply_fire():
			_remaining_charges -= 1
			_affected_tiles[tid] = true

func _get_tile_below() -> HexTile:
	if not tile_ray:
		return null
	tile_ray.force_raycast_update()
	if not tile_ray.is_colliding():
		return null
	var collider := tile_ray.get_collider()
	if collider and collider is HexTile:
		return collider
	return null
