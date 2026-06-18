## ArenaGrid manages the hexagonal game world, including tile data, actor spawning,
## farmstead generation, and player control orchestration.
## It acts as a central hub for various sub-systems like rendering, physics, and tile logic.
class_name ArenaGrid
extends Node3D

@export var house_feature_scene: PackedScene = preload("res://Play Space/house_feature.tscn")
@export var fence_feature_scene: PackedScene = preload("res://Play Space/fence_feature.tscn")
@export var grid_width: int =  20
@export var grid_height: int = 20
@export var hex_size: float = 1.5
@export_range(0.25, 3.0, 0.05) var tile_scale: float = 1.5
@export var noise: FastNoiseLite
@export var height_step: float = 1.0
@export var noise_scale: float = 1.0

const SQRT3: float = sqrt(3.0)

# Data storage
var tile_data_grid: Array[HexTileData] = []
var actors: Array[Node3D] = []

# Components
var renderer: HexGridRenderer
var tile_system: TileSystem
var physics: ArenaPhysics
var tile_interaction: ArenaTileInteractionComponent
var tile_signals: TileSignalComponent
var ui_component: Node # ArenaUIHandler
var minimap_component: Node # ArenaMinimapHandler
var actor_spawner: ArenaSpawnerComponent
var player_input: PlayerInputComponent
var grid_generator: GridGenerator
var tree_spawner: TreeSpawner

## Hornbound: the run controller. Optional — set up lazily in
## _setup_dungeon_run_controller() if a Hornbound-style 4-room run is in
## play. For non-run sessions (sandbox arena, capture training, etc.) this
## stays null and nothing breaks.
var run_controller: DungeonRunController = null

## Extract screen UI. Instanced and shown when the run controller emits
## extract_point_reached. Stays null in non-run sessions.
var extract_screen: Control = null

var farmstead_interior_tiles: Array[HexTileData]:
	get: return grid_generator.farmstead_interior_tiles if grid_generator else []

var farmstead_perimeter_tiles: Array[HexTileData]:
	get: return grid_generator.farmstead_perimeter_tiles if grid_generator else []

var house_tile: HexTileData:
	get: return grid_generator.house_tile if grid_generator else null

signal tile_counts_changed(counts: Dictionary)
## Emitted when every actor in the player's pack has died — drives the run
## controller to declare the run a failure. Fired by PlayerInputComponent's
## possession code when no alive packmate can be found.
signal player_pack_wiped()
var tile_counts: Dictionary = {}

@onready var _camera_follower: CameraFollower = get_node_or_null("Camera3D")

var current_controlled_actor: Actor:
	get:
		return player_input.current_controlled_actor if player_input else null
	set(value):
		if player_input:
			player_input.current_controlled_actor = value

# Initializes the arena, sets up components, grid, physics, actors, and UI.
# Should not be moved (Main entry point for scene initialization).
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		grid_width = gs.grid_width
		grid_height = gs.grid_height

	_setup_components()
	grid_generator.initialize_grid()
	_setup_physics()
	grid_generator.setup_farmstead()
	if actor_spawner:
		actor_spawner.spawn_initial_actors()
	if tree_spawner:
		tree_spawner.spawn_trees()
	add_to_group("arena")

	if player_input:
		player_input.select_initial_actor()

	GameEvents.actor_died.connect(_on_actor_died)
	_setup_quest_system()
	# Hornbound: opt-in run controller. Only spins up if HerdManager has a
	# pending run-mode flag (set by Hub when the player accepts a contract).
	# For backward compatibility, sandbox / capture-training sessions skip this.
	_setup_dungeon_run_controller()

	# Register static world obstacles with the tile signal system
	call_deferred("_register_static_obstacles")

	# Visual-only blended terrain layer (Terrain3D demo textures + smoothed mesh).
	# Loaded by path so it can never collide with another global script class.
	# Safe to no-op if the script or shader is missing.
	_setup_terrain_blend_visual()


func _setup_terrain_blend_visual() -> void:
	if has_node("TerrainBlendVisual"):
		return
	var script_path: String = "res://Components/Arena/TerrainBlendVisual.gd"
	if not ResourceLoader.exists(script_path):
		return
	var script_res: Resource = load(script_path)
	if not (script_res is Script):
		return
	var node: Node3D = Node3D.new()
	node.name = "TerrainBlendVisual"
	node.set_script(script_res)
	add_child(node)
	if node.has_method("setup"):
		node.call("setup", self)

# Instantiates and attaches core logic components.
# Should not be moved (Orchestrates arena-specific components).
func _setup_components() -> void:
	renderer = HexGridRenderer.new()
	renderer.name = "HexGridRenderer"
	renderer.tile_scale = tile_scale
	renderer.hex_size = hex_size
	renderer.height_step = height_step
	add_child(renderer)

	tile_system = TileSystem.new()
	tile_system.name = "TileSystem"
	tile_system.arena = self
	add_child(tile_system)

	physics = ArenaPhysics.new()
	physics.name = "ArenaPhysics"
	add_child(physics)

	tile_interaction = ArenaTileInteractionComponent.new()
	tile_interaction.name = "ArenaTileInteractionComponent"
	tile_interaction.setup(self)
	add_child(tile_interaction)

	tile_signals = TileSignalComponent.new()
	tile_signals.name = "TileSignalComponent"
	add_child(tile_signals)
	tile_signals.setup(self)

	actor_spawner = ArenaSpawnerComponent.new()
	actor_spawner.name = "ArenaSpawner"
	add_child(actor_spawner)

	player_input = PlayerInputComponent.new()
	player_input.name = "PlayerInputComponent"
	add_child(player_input)

	ui_component = ArenaUIHandler.new()
	ui_component.name = "ArenaUIHandler"
	add_child(ui_component)

	minimap_component = ArenaMinimapHandler.new()
	minimap_component.name = "ArenaMinimapHandler"
	add_child(minimap_component)

	grid_generator = GridGenerator.new()
	grid_generator.name = "GridGenerator"
	add_child(grid_generator)
	grid_generator.setup(self)

	tree_spawner = TreeSpawner.new()
	tree_spawner.name = "TreeSpawner"
	add_child(tree_spawner)
	tree_spawner.setup(self)

	actor_spawner.setup(self)
	player_input.setup(self)
	ui_component.setup(self)
	minimap_component.setup(self)

# Handles cleanup and logic when an actor dies, including game over checks.
# Should not be moved (Maintains high-level game session state).
func _on_actor_died(e: Node3D) -> void:
	if actors.has(e):
		actors.erase(e)

	var was_controlled_actor: bool = e == current_controlled_actor
	var was_playable_actor: bool = false
	if e is Actor:
		was_playable_actor = (e as Actor).is_playable
	if was_controlled_actor or was_playable_actor:
		if has_node("/root/QuestState"):
			QuestState.fail_active_quest("You died. Quest failed and reset for the next play.")

	if was_controlled_actor:
		if player_input:
			player_input.next_actor()

	# Only check for extinction if a player-allied unit just died
	if e is Actor and e.is_friendly:
		var friendlies_left = false
		for a in actors:
			if is_instance_valid(a) and a is Actor and a.is_friendly:
				friendlies_left = true
				break

		if not friendlies_left:
			if ui_component:
				ui_component.handle_game_over()

# Proxies for grid generation and layout logic
func _get_tile_surface_y(tile: HexTileData) -> float:
	return grid_generator.get_tile_surface_y(tile)

func _get_neighbors(tile: HexTileData) -> Array[HexTileData]:
	return grid_generator.get_neighbors(tile)

func _has_adjacent_grass(tile: HexTileData) -> bool:
	return grid_generator.has_adjacent_grass(tile)

func _get_adjacent_dirt(tile: HexTileData) -> HexTileData:
	return grid_generator.get_adjacent_dirt(tile)

func get_tile_at_grid_coords(x: int, y: int) -> HexTileData:
	return grid_generator.get_tile_at_grid_coords(x, y)

func _grid_width_clamped() -> int:
	return grid_generator._grid_width_clamped()

func _grid_height_clamped() -> int:
	return grid_generator._grid_height_clamped()

# Updates a tile's state, notifies the renderer, and triggers neighbor updates.
# Should not be moved (Central authority for tile state changes).
func set_tile_state(tile: HexTileData, new_state: int) -> void:
	if tile.current_state == new_state:
		return

	var old_state = tile.current_state
	renderer.remove_tile(tile)

	if old_state == TileConstants.State.FIRE:
		renderer.update_fire_effect(tile, false)

	tile.current_state = new_state
	tile._sync_type()

	renderer.add_tile(tile)

	if new_state == TileConstants.State.FIRE:
		renderer.update_fire_effect(tile, true)

	tile_counts[old_state] -= 1
	tile_counts[new_state] += 1
	tile_counts_changed.emit(tile_counts)

	if old_state == TileConstants.State.GRASS or new_state == TileConstants.State.GRASS:
		var grass_layer = get_node_or_null("GrassPatchLayer")
		if grass_layer:
			grass_layer.regenerate()

	tile_system.check_activeness(tile)
	for n in _get_neighbors(tile):
		tile_system.check_activeness(n)

# Processes tile logic every frame.
# Should not be moved (Main process loop).
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Periodic cleanup of freed actor references (safety measure)
	if Engine.get_frames_drawn() % 30 == 0:
		var i = actors.size() - 1
		while i >= 0:
			if not is_instance_valid(actors[i]):
				actors.remove_at(i)
			i -= 1

	tile_system.process_tiles(delta)

# Proxies elemental application to the ArenaTileInteractionComponent.
# Should not be moved (Maintains backward compatibility for actors and projectiles).
func apply_element_to_tile(tile: HexTileData, element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if tile_interaction:
		return tile_interaction.apply_element_to_tile(tile, element, direction)
	return false

# Converts a world position to tile data using hexagonal math.
# TODO(Optimization): Cache spatial lookup or use spatial partitioning for tile queries to reduce heavy math operations (~1% CPU)
func get_tile_data_at_world_position(world_position: Vector3) -> HexTileData:
	var local_pos = to_local(world_position)
	var x = local_pos.x
	var z = local_pos.z

	var q_float = x / (1.5 * hex_size)
	var r_float = (z / (SQRT3 * hex_size)) - (q_float * 0.5)

	var q = q_float
	var r = r_float
	var s = -q - r

	var rq = round(q)
	var rr = round(r)
	var rs = round(s)

	var dq = abs(rq - q)
	var dr = abs(rr - r)
	var ds = abs(rs - s)

	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs

	var col = int(rq)
	var row = int(rr) + (col - (col & 1)) / 2

	return get_tile_at_grid_coords(col, row)

# Alias for get_tile_data_at_world_position.
func get_tile_at_world_position(world_position: Vector3) -> HexTileData:
	return get_tile_data_at_world_position(world_position)

## Returns an array of tiles within a hexagonal radius of the center tile.
## Uses optimized BFS lookup instead of O(N) grid scan.
func get_tiles_in_radius(center: HexTileData, radius: int) -> Array[HexTileData]:
	if grid_generator:
		return grid_generator.get_tiles_in_radius(center, radius)
	return []

# Initializes physics collision for the grid.
func _setup_physics() -> void:
	if physics:
		physics.setup_physics(tile_data_grid, hex_size, tile_scale, height_step, grid_width, grid_height)

# Returns an array of tiles within a given world-space radius.
# DEPRECATED: Use get_tiles_in_radius() for hexagonal grid logic.
# This implementation is now optimized using BFS via get_tiles_in_radius.
func get_tiles_within_distance(world_position: Vector3, radius: float) -> Array[HexTileData]:
	var center = get_tile_at_world_position(world_position)
	if not center:
		return []

	# Convert world radius to approximate hex radius
	# Distance between centers is SQRT3 * hex_size
	var hex_radius = ceil(radius / (SQRT3 * hex_size)) + 1
	var candidates = get_tiles_in_radius(center, int(hex_radius))

	var results: Array[HexTileData] = []
	var radius_sq = radius * radius
	for tile in candidates:
		var d = tile.position - world_position
		d.y = 0
		if d.length_squared() <= radius_sq:
			results.append(tile)
	return results

# Adds the modular Goatlandia-style quest/spawn addon without changing core arena combat.
func _setup_quest_system() -> void:
	if has_node("QuestStarterKit"):
		return
	var script_path: String = "res://QuestSystem/QuestStarterKit.gd"
	if not ResourceLoader.exists(script_path):
		return
	var kit: Node = Node.new()
	kit.name = "QuestStarterKit"
	kit.set_script(load(script_path))
	add_child(kit)
	if kit.has_method("setup"):
		kit.call("setup", self)

## Scans the grid once and registers static obstacles (trees, fences, stone)
## with the TileSignalComponent. This avoids repeated O(N) scans by AI agents.
func _register_static_obstacles() -> void:
	if not tile_signals:
		return

	for tile in tile_data_grid:
		var is_blocker = false
		var weight = 1.0

		# Trees and Fences
		if tile.feature:
			if tile.feature is HarvestableTree:
				if tile.feature.get_state() in [HarvestableTree.State.STANDBY, HarvestableTree.State.FELLEDB]:
					is_blocker = true
					weight = 1.5
			elif tile.feature is FenceFeature:
				is_blocker = true
				weight = 1.8

		# Stone Walls
		if not is_blocker and tile.current_state == TileConstants.State.STONE:
			is_blocker = true
			weight = 2.0

		if is_blocker:
			# Radius 2 for static obstacles
			tile_signals.register_trigger(tile, 2, Callable(), {"weight": weight, "is_static_obstacle": true})

# ============================================================================
# Hornbound — Dungeon Run Controller integration
# ============================================================================
##
## When the player accepts a contract at the hub, HerdManager sets a flag
## (pending_run_mode) that tells this Arena to spin up the 4-room state
## machine. Otherwise (sandbox, capture training, free-play) the run
## controller is never created — keeping non-run sessions completely
## untouched and backward-compatible.
##
## Run lifecycle:
##   1. _setup_dungeon_run_controller() reads HerdManager.pending_run_mode
##   2. If true: instantiate DungeonRunController + ExtractScreen UI
##   3. Wire signals — extract_point_reached → show screen
##                      run_succeeded / run_failed → return to hub
##   4. Pass the player's squad and call start_run()

func _setup_dungeon_run_controller() -> void:
	# Check HerdManager for the run-mode flag. If absent or false, this arena
	# is in sandbox mode — nothing to do.
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null:
		return
	var run_mode: bool = false
	if "pending_run_mode" in hm:
		run_mode = bool(hm.get("pending_run_mode"))
	if not run_mode:
		return

	# Build the controller as a child node so it's reachable via the scene
	# tree and disposes automatically when the arena unloads.
	run_controller = DungeonRunController.new()
	run_controller.name = "DungeonRunController"
	add_child(run_controller)

	# Wire signals.
	run_controller.extract_point_reached.connect(_on_extract_point_reached)
	run_controller.run_succeeded.connect(_on_run_succeeded)
	run_controller.run_failed.connect(_on_run_failed)
	run_controller.room_entered.connect(_on_run_room_entered)

	# Pull the squad the Hub stashed on HerdManager and actually start the
	# run. Without this, the controller stays parked in NOT_STARTED forever
	# and no rooms ever populate — which is what broke contract spawning.
	var squad: Array = []
	if "pending_squad" in hm:
		var stashed: Variant = hm.get("pending_squad")
		if stashed is Array:
			squad = (stashed as Array).duplicate()
	# Hand the controller our squad and kick off WARMUP, which immediately
	# emits room_entered and triggers _on_run_room_entered → spawn enemies.
	# Defer one frame so all components (actor_spawner, etc.) are wired.
	call_deferred("_kick_off_run", squad)

func _kick_off_run(squad: Array) -> void:
	if run_controller == null:
		return
	run_controller.start_run(self, squad)
	# Force a HUD refresh so the contract shows immediately.
	_refresh_quest_hud()

## Find the QuestTrackerHUD anywhere in the arena's UI tree and re-run its
## _update_all. Called after room transitions so the "Room: Mid-Boss" line
## advances live.
func _refresh_quest_hud() -> void:
	var hud: Node = find_child("QuestTrackerHUD", true, false)
	if hud and hud.has_method("_update_all"):
		hud.call("_update_all")

func _on_extract_point_reached() -> void:
	if extract_screen == null:
		# Lazily instance the extract screen UI.
		var scene: PackedScene = load("res://UI/ExtractScreen.tscn") as PackedScene
		if scene:
			extract_screen = scene.instantiate() as Control
			if extract_screen and ui_component:
				ui_component.add_child(extract_screen)
	if extract_screen and extract_screen.has_method("show_for_run"):
		extract_screen.call("show_for_run", run_controller)

func _on_run_succeeded(_rewards: Dictionary) -> void:
	# Hand off to the hub. Caller can read run_controller.pending_rewards.
	print("[Arena] Run succeeded.")
	# Clear the run-mode flag so the next arena entry doesn't auto-arm.
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm and "pending_run_mode" in hm:
		hm.set("pending_run_mode", false)

func _on_run_failed() -> void:
	print("[Arena] Run failed — pack wiped.")
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm and "pending_run_mode" in hm:
		hm.set("pending_run_mode", false)

func _on_run_room_entered(state: int) -> void:
	# Map run state → room_type string for the template lookup.
	var room_type: String = ""
	match state:
		DungeonRunController.RunState.WARMUP:    room_type = "warmup"
		DungeonRunController.RunState.BRANCH:    room_type = "branch_loot"  # default; alpha path is a future fork
		DungeonRunController.RunState.MIDBOSS:   room_type = "midboss"
		DungeonRunController.RunState.PUSH_BOSS: room_type = "boss"
		_:
			print("[Arena] Room entered — state=%d (no template needed)" % state)
			return

	# Pull biome from the accepted contract if present, else default.
	var biome: String = "crystal_caverns"
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm and "accepted_contract" in hm:
		var c = hm.get("accepted_contract")
		if c != null and "biome" in c:
			biome = String(c.get("biome"))

	# Pick a template from the biome+type pool.
	var pool: Array = StarterRoomTemplates.get_pool(biome, room_type)
	if pool.is_empty():
		print("[Arena] No room templates for biome=%s type=%s — empty room" % [biome, room_type])
		return
	var template: RoomTemplate = pool[randi() % pool.size()]
	print("[Arena] Room entered — state=%d biome=%s template=%s enemies=%s" % [state, biome, template.room_id, str(template.enemy_types)])

	# Spawn enemies via the existing ArenaSpawner.
	if actor_spawner == null:
		return
	for species in template.enemy_types:
		var tile: HexTileData = actor_spawner._get_random_spawn_tile()
		if tile == null:
			continue
		# Route through the species → actor-type dispatch the spawner already supports.
		var species_lower: String = String(species).to_lower()
		actor_spawner.spawn_actor_at_tile(species_lower, tile)

	# Also record per-room loot in the run controller's pending_rewards.
	if run_controller:
		template.on_room_completed(run_controller, randi())
	# Refresh the quest tracker so the "Room: Mid-Boss" line advances.
	_refresh_quest_hud()
