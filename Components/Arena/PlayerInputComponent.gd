class_name PlayerInputComponent
extends Node

## PlayerInputComponent handles mouse and keyboard input for the Arena.
## It translates user events into actions performed by the currently controlled actor.
## Attack and ability aim targets are resolved through the actor's active ControllerMode
## so that targeting works correctly regardless of control scheme.

var arena: ArenaGrid

var current_target_index: int = 0
var current_controlled_actor: Actor:
	set(value):
		if is_instance_valid(current_controlled_actor):
			current_controlled_actor.is_controlled = false
			# Disconnect old death listener so we don't stack callbacks.
			if current_controlled_actor.died.is_connected(_on_controlled_actor_died):
				current_controlled_actor.died.disconnect(_on_controlled_actor_died)

		current_controlled_actor = value

		if current_controlled_actor:
			current_controlled_actor.is_controlled = true
			if not current_controlled_actor.died.is_connected(_on_controlled_actor_died):
				current_controlled_actor.died.connect(_on_controlled_actor_died)
			if arena and arena.ui_component:
				arena.ui_component.update_for_actor(current_controlled_actor)

## The pack the player is currently leading. Used by possession to find the
## next valid body to possess when the controlled actor dies. Populated by
## ArenaSpawner / DungeonRunController on run start.
var player_pack: Array[Actor] = []

## How long after possession the new body has invulnerability frames.
const POSSESSION_IFRAME_SECONDS: float = 0.5
## Reduced damage taken multiplier for POSSESSION_DAMP_SECONDS after possess.
const POSSESSION_DAMP_DURATION: float = 2.0
const POSSESSION_DAMP_MULTIPLIER: float = 0.5

# When the most recent possession happened (Time.get_ticks_msec()).
var _last_possession_ms: int = -1

var _ability_pressed: bool = false
var _ability_press_time: int = 0
var _hide_triggered: bool = false
const HOLD_THRESHOLD_MS: int = 300

# Camera cache for _get_mouse_3d_position optimization
var _cached_camera: Camera3D
var _camera_cache_time: float = 0.0
const CAMERA_CACHE_INTERVAL: float = 0.5  # Refresh every 500ms

## Initializes the component with a reference to the ArenaGrid.
func setup(p_arena: ArenaGrid) -> void:
	arena = p_arena

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Initial mouse state for the arena
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## Processes mouse and keyboard input for actor actions.
func _unhandled_input(event: InputEvent) -> void:
	if not arena or not current_controlled_actor:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_controlled_actor.weapon_component:
				current_controlled_actor.weapon_component.launch_projectile_at(_get_aim_target())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_controlled_actor.weapon_component:
				current_controlled_actor.weapon_component.secondary_attack_at(_get_aim_target())

	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_E:
				current_controlled_actor.cycle_attack_pattern()
			elif event.keycode == KEY_Q:
				current_controlled_actor.prev_attack_pattern()
			elif event.keycode == KEY_T:
				if current_controlled_actor.weapon_component:
					current_controlled_actor.weapon_component.throw_weapon_at(_get_aim_target())
			elif event.keycode == KEY_SHIFT:
				_ability_pressed = true
				_ability_press_time = Time.get_ticks_msec()
			elif event.keycode == KEY_R:
				if current_controlled_actor and current_controlled_actor.ability_component:
					current_controlled_actor.ability_component.execute_ability("ability_r", _get_aim_target())
			elif event.keycode == KEY_C and not event.echo:
				if current_controlled_actor.weapon_component:
					current_controlled_actor.weapon_component.use_net_close_at(current_controlled_actor.global_position)
			elif event.keycode == KEY_G and not event.echo:
				# Voluntary possession — jump to the next packmate.
				possess_next_packmate()
			elif event.keycode == KEY_F2 and not event.echo:
				# Dev: spawn one more of the contract's target species.
				_dev_spawn_more_of_contract_target()
		else: # Key Released
			if event.keycode == KEY_SHIFT:
				_ability_pressed = false
				if _hide_triggered:
					if current_controlled_actor and current_controlled_actor.ability_component:
						current_controlled_actor.ability_component.execute_ability("hide", false)
					_hide_triggered = false
				else:
					var hold_duration: int = Time.get_ticks_msec() - _ability_press_time
					if hold_duration < HOLD_THRESHOLD_MS: # Tap
						if current_controlled_actor and current_controlled_actor.ability_component:
							# Dash direction is away from the mouse cursor — twin-stick specific,
							# intentionally uses raw mouse position rather than mode aim target.
							var mouse_pos := _get_mouse_3d_position()
							var dash_dir := (current_controlled_actor.global_position - mouse_pos).normalized()
							if dash_dir.length() < 0.1:
								dash_dir = -current_controlled_actor.global_transform.basis.z
							dash_dir.y = 0
							current_controlled_actor.ability_component.execute_ability("disengage", dash_dir)

func _process(_delta: float) -> void:
	if _ability_pressed and not _hide_triggered:
		var hold_duration: int = Time.get_ticks_msec() - _ability_press_time
		if hold_duration >= HOLD_THRESHOLD_MS: # Hold
			if current_controlled_actor and current_controlled_actor.ability_component:
				current_controlled_actor.ability_component.execute_ability("hide", true)
			_hide_triggered = true

# ============================================================================
# Possession — Hornbound mechanic for "you ARE one of your monsters"
# ============================================================================

## Take control of a specific actor. Camera retargets, HUD updates, and
## possession i-frames apply. Used when a controlled actor dies (auto-possess
## next packmate) and for voluntary mid-fight switching (G key).
##
## Sets `_last_possession_ms` so post_possession_damage_multiplier() can
## report reduced damage during the brief invulnerability/damp window.
func possess_actor(actor: Actor) -> void:
	if actor == null or not is_instance_valid(actor) or actor.is_dead:
		return
	current_controlled_actor = actor
	# Update target index so prev/next cycle starts here.
	if arena:
		var idx: int = arena.actors.find(actor)
		if idx != -1:
			current_target_index = idx
	# Reattach camera. Mirror update_camera_target's logic.
	var _camera_follower := arena.get_node_or_null("Camera3D") if arena else null
	if _camera_follower and _camera_follower is CameraFollower:
		_camera_follower.set_target(actor)
		if actor is GoatActor:
			_camera_follower.max_zoom = 10.0
		else:
			_camera_follower.max_zoom = 80.0
	_last_possession_ms = Time.get_ticks_msec()

## Possess the nearest alive packmate to the current controlled actor.
## Called automatically when the controlled actor dies. Returns the actor
## possessed, or null if there's nobody alive in the pack.
func possess_next_packmate() -> Actor:
	var origin: Vector3 = Vector3.ZERO
	if is_instance_valid(current_controlled_actor):
		origin = current_controlled_actor.global_position
	var best: Actor = null
	var best_dist_sq: float = INF
	for pm in player_pack:
		if pm == null or not is_instance_valid(pm) or pm == current_controlled_actor:
			continue
		if pm.is_dead:
			continue
		var d: float = pm.global_position.distance_squared_to(origin)
		if d < best_dist_sq:
			best_dist_sq = d
			best = pm
	if best:
		possess_actor(best)
	return best

## Returns the damage taken multiplier currently active due to recent possession.
## 0.0 during i-frames (full immunity), POSSESSION_DAMP_MULTIPLIER during damp,
## 1.0 once the window expires. Read by HealthComponent.take_damage if it
## chooses to honor possession mercy.
func post_possession_damage_multiplier() -> float:
	if _last_possession_ms < 0:
		return 1.0
	var ms_elapsed: int = Time.get_ticks_msec() - _last_possession_ms
	var sec_elapsed: float = ms_elapsed / 1000.0
	if sec_elapsed <= POSSESSION_IFRAME_SECONDS:
		return 0.0  # i-frame window
	if sec_elapsed <= POSSESSION_IFRAME_SECONDS + POSSESSION_DAMP_DURATION:
		return POSSESSION_DAMP_MULTIPLIER
	return 1.0

## Dev hotkey (F2) — spawns one more of the contract's target species at a
## random valid tile near the player. Useful for testing that contract
## monsters actually get into the world, and for QA-spawning extra enemies
## of a known type without leaving the run. Reads the species from
## HerdManager.accepted_contract.target_species; falls back to the first
## enemy type in the current room's template if no contract is active.
func _dev_spawn_more_of_contract_target() -> void:
	if arena == null:
		return
	# Resolve species from the accepted contract.
	var species: String = ""
	var hm: Node = arena.get_node_or_null("/root/HerdManager")
	if hm and "accepted_contract" in hm:
		var c = hm.get("accepted_contract")
		if c and "target_species" in c:
			species = String(c.get("target_species"))
	if species.is_empty():
		print("[Dev] No contract target species — F2 spawn no-op.")
		return
	# Spawn via ArenaSpawner. species_lower routes through its match table.
	if "actor_spawner" in arena and arena.actor_spawner:
		var tile: HexTileData = arena.actor_spawner._get_random_spawn_tile()
		if tile == null:
			print("[Dev] No valid spawn tile.")
			return
		var spawned: Node = arena.actor_spawner.spawn_actor_at_tile(species.to_lower(), tile)
		if spawned:
			print("[Dev] Spawned 1 × %s at random tile." % species)
		else:
			print("[Dev] Spawn failed for species '%s' — likely no scene registered." % species)

## Death listener attached when current_controlled_actor is set.
## Auto-possesses the nearest alive packmate. If none, the run is over.
func _on_controlled_actor_died() -> void:
	var nearest := possess_next_packmate()
	if nearest == null:
		# All packmates down — emit a signal the run controller listens to.
		if arena and arena.has_signal("player_pack_wiped"):
			arena.emit_signal("player_pack_wiped")

## Returns the world-space aim target for the current control mode.
## Asks the actor's controller so the result is correct for every control scheme
## (e.g. ground-plane raycast for twin-stick, screen-centre raycast for third-person).
## Falls back to a raw mouse ground-plane raycast if no controller mode is available.
func _get_aim_target() -> Vector3:
	if is_instance_valid(current_controlled_actor) and current_controlled_actor.controller:
		return current_controlled_actor.controller.get_aim_target()
	return _get_mouse_3d_position()

## Selects the first available playable actor to be controlled.
func select_initial_actor() -> void:
	var idx := _find_playable_actor(0, 1)
	if idx != -1:
		current_target_index = idx
		update_camera_target()

## Updates the camera to follow the currently selected actor and updates UI.
func update_camera_target() -> void:
	if not arena or arena.actors.is_empty():
		return

	var target := arena.actors[current_target_index % arena.actors.size()]
	if not is_instance_valid(target):
		return

	var _camera_follower := arena.get_node_or_null("Camera3D")
	if _camera_follower and _camera_follower is CameraFollower:
		_camera_follower.set_target(target)
		if target is GoatActor:
			_camera_follower.max_zoom = 10.0
		else:
			_camera_follower.max_zoom = 80.0

	current_controlled_actor = target as Actor

## Switches control to the next playable actor.
func next_actor() -> void:
	var next_idx := _find_playable_actor(current_target_index + 1, 1)
	if next_idx != -1:
		current_target_index = next_idx
		update_camera_target()

## Switches control to the previous playable actor.
func previous_actor() -> void:
	var prev_idx := _find_playable_actor(current_target_index - 1, -1)
	if prev_idx != -1:
		current_target_index = prev_idx
		update_camera_target()

## Searches for a playable actor in the actors array.
func _find_playable_actor(start_index: int, step: int) -> int:
	if not arena or arena.actors.is_empty():
		return -1

	var n := arena.actors.size()
	for i in range(n):
		var idx := (start_index + i * step) % n
		if idx < 0:
			idx += n
		var a := arena.actors[idx]
		if is_instance_valid(a) and a is Actor and a.is_playable:
			return idx
	return -1

## Uses a raycast from the mouse position to find the world-space coordinate on the ground plane.
## Camera is cached and refreshed periodically to avoid repeated get_camera_3d() calls.
func _get_mouse_3d_position() -> Vector3:
	_camera_cache_time -= get_process_delta_time()
	if _camera_cache_time <= 0.0 or not is_instance_valid(_cached_camera):
		_cached_camera = get_viewport().get_camera_3d()
		_camera_cache_time = CAMERA_CACHE_INTERVAL

	if not _cached_camera:
		return Vector3.ZERO

	var mouse_pos := _cached_camera.get_viewport().get_mouse_position()

	var ray_origin := _cached_camera.project_ray_origin(mouse_pos)
	var ray_direction := _cached_camera.project_ray_normal(mouse_pos)

	var space_state := arena.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		return result.position

	if abs(ray_direction.y) < 1e-6:
		return Vector3.ZERO

	var t := -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t
