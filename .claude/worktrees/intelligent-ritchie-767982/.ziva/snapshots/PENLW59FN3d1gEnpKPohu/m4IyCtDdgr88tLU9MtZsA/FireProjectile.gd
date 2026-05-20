class_name FireProjectile
extends Node3D

@export var speed: float = 14.0
@export var lifetime: float = 5.0
@export var charge_capacity: int = 5

var _arena: ArenaGrid
var _caster_position: Vector3
var _effect_range: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _remaining_charges: int = 0
var _elapsed: float = 0.0
var _last_tile: HexTile

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
	_last_tile = null

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime or _remaining_charges <= 0:
		queue_free()
		return
	translate(_direction * speed * delta)
	_apply_effect_to_tile()

func _apply_effect_to_tile() -> void:
	if not _arena or _remaining_charges <= 0:
		return
	var tile = _arena.get_tile_at_world_position(global_transform.origin)
	if not tile or tile == _last_tile:
		return
	if not _arena.is_position_within_range(_caster_position, tile.global_transform.origin, _effect_range):
		return
	tile.apply_fire()
	_remaining_charges -= 1
	_last_tile = tile
