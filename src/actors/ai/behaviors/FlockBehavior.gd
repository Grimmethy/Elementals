class_name FlockBehavior
extends AIBehavior

## Steers this actor to follow a player-controlled leader of matching element_type.
## Overrides movement when a leader is found, releasing it when none exists.
## Replaces AIFlockinState + GoatController._get_player_goat().

var leader_type: String = ""
var min_follow_distance: float = 1.0
var max_follow_distance: float = 5.0

var _leader: Node3D = null
var _is_flocking: bool = false
var _retarget_timer: float = 0.0
const _RETARGET_INTERVAL: float = 1.0

func setup(p_controller: ActorAIController, config: Dictionary) -> void:
	super.setup(p_controller, config)
	leader_type = config.get("flock_leader_type", "")
	min_follow_distance = config.get("flock_min_distance", 1.0)
	max_follow_distance = config.get("flock_max_distance", 5.0)

func is_overriding_movement() -> bool:
	return _is_flocking

func physics_tick(delta: float) -> float:
	_leader = _find_leader()

	if not _leader:
		_is_flocking = false
		return 1.0

	_is_flocking = true
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = _RETARGET_INTERVAL
		_choose_flock_target()

	if not controller._movement_claimed:
		controller.claim_movement()
		_execute_flock_movement(delta)

	return 1.0

func _find_leader() -> Node3D:
	var a := controller.actor as Actor
	if not a or not a._arena_grid:
		return null
	var candidate: Node3D = a._arena_grid.current_controlled_actor
	if is_instance_valid(candidate) \
			and candidate.get("element_type") == leader_type \
			and candidate != controller.actor \
			and candidate.get("is_controlled"):
		return candidate
	return null

func _choose_flock_target() -> void:
	var a := controller.actor as Actor
	if not a or not _leader or not a._arena_grid:
		return

	a.tile_interaction_component.update_tile_below()
	var ground_tile: HexTileData = a.tile_interaction_component.get_ground_tile()
	if not ground_tile:
		return

	var dist := a.global_position.distance_to(_leader.global_position)
	var neighbors := a.tile_navigation_component.get_traversable_neighbors(ground_tile)
	if neighbors.is_empty():
		return

	var next_tile: HexTileData
	if dist > max_follow_distance:
		neighbors.sort_custom(func(x, y): return x.position.distance_to(_leader.global_position) < y.position.distance_to(_leader.global_position))
		next_tile = neighbors[0]
	elif dist < min_follow_distance:
		neighbors.sort_custom(func(x, y): return x.position.distance_to(_leader.global_position) > y.position.distance_to(_leader.global_position))
		next_tile = neighbors[0]
	else:
		var candidates := neighbors.filter(func(t): return t != controller._previous_tile)
		next_tile = candidates[controller._rng.randi_range(0, candidates.size() - 1)] if candidates.size() > 0 else neighbors.pick_random()

	if next_tile:
		controller._previous_tile = ground_tile
		controller._movement_target = next_tile.position
		controller._movement_target.y = a.global_position.y

func _execute_flock_movement(delta: float) -> void:
	var a := controller.actor as Actor
	if not a:
		return

	var current_pos := Vector2(a.global_transform.origin.x, a.global_transform.origin.z)
	var target_pos := Vector2(controller._movement_target.x, controller._movement_target.z)

	if current_pos.distance_to(target_pos) < 0.2:
		_choose_flock_target()

	var direction := (target_pos - current_pos).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance := controller._get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	controller.movement_component.move(dir_3d, delta)
	controller.movement_component.apply_gravity(delta)
