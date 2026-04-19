class_name ArenaGrid
extends Node3D

@export var tree_feature_scene: PackedScene = preload("res://Play Space/tree_feature.tscn")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var hex_size: float = 1.5
@export_range(0.25, 3.0, 0.05) var tile_scale: float = 1.5
@export var fire_elemental_scene: PackedScene = preload("res://Elemental/FireElemental.tscn")
@export var water_elemental_scene: PackedScene = preload("res://Elemental/WaterElemental.tscn")
@export var goat_elemental_scene: PackedScene = preload("res://Elemental/GoatElemental.tscn")
@export var noise: FastNoiseLite
@export var height_step: float = 1.0
@export var noise_scale: float = 1.0

const SQRT3: float = sqrt(3.0)

# Data storage
var tile_data_grid: Array[HexTileData] = []
var elementals: Array[Node3D] = []

# Components
var renderer: HexGridRenderer
var tile_system: TileSystem
var physics: ArenaPhysics

signal tile_counts_changed(counts: Dictionary)
var tile_counts: Dictionary = {}

@onready var _target_label: Label = get_node_or_null("UI/HBoxContainer/TargetLabel")
@onready var _prev_button: Button = get_node_or_null("UI/HBoxContainer/PrevButton")
@onready var _next_button: Button = get_node_or_null("UI/HBoxContainer/NextButton")
@onready var _camera_follower: CameraFollower = get_node_or_null("Camera3D")
@onready var _minimap_viewport: SubViewport = get_node_or_null("UI/MinimapFrame/MinimapContainer/SubViewport")
@onready var _options_menu: OptionsMenu = get_node_or_null("UI/OptionsMenu")
@onready var _options_button: Button = get_node_or_null("UI/OptionsButton")

var current_target_index: int = 0
var current_controlled_elemental: Elemental:
	set(value):
		if current_controlled_elemental:
			current_controlled_elemental.is_controlled = false
			if current_controlled_elemental.health_component:
				if current_controlled_elemental.health_component.health_changed.is_connected(_on_elemental_hp_changed):
					current_controlled_elemental.health_component.health_changed.disconnect(_on_elemental_hp_changed)
			if current_controlled_elemental.mana_changed.is_connected(_on_elemental_mana_changed):
				current_controlled_elemental.mana_changed.disconnect(_on_elemental_mana_changed)
		
		current_controlled_elemental = value
		
		if current_controlled_elemental:
			current_controlled_elemental.is_controlled = true
			if current_controlled_elemental.health_component:
				current_controlled_elemental.health_component.health_changed.connect(_on_elemental_hp_changed)
			current_controlled_elemental.mana_changed.connect(_on_elemental_mana_changed)
			if reticle:
				reticle.color = current_controlled_elemental.get_elemental_color()
			_update_ui()

var reticle: Control

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		grid_width = gs.grid_width
		grid_height = gs.grid_height
	
	_setup_components()
	_setup_reticle()
	_initialize_grid()
	_setup_physics()
	_spawn_elementals()
	_setup_ui_connections()
	_setup_minimap()
	add_to_group("arena")
	
	_select_initial_elemental()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	GameEvents.elemental_died.connect(_on_elemental_died)

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

func _on_elemental_died(e: Node3D) -> void:
	if elementals.has(e):
		if e is GoatElemental:
			elementals.erase(e)
	
	var player_goats_left = false
	for elemental in elementals:
		if elemental is GoatElemental and elemental.goat_data:
			player_goats_left = true
			break
	
	if not player_goats_left:
		_handle_game_over()

func _initialize_grid() -> void:
	var h = _grid_height_clamped()
	var w = _grid_width_clamped()
	var total_h = h + 2
	var total_w = w + 2
	var total_tiles = total_h * total_w
	
	renderer.setup(total_tiles)
	
	tile_data_grid.clear()
	tile_counts.clear()
	for state in TileConstants.State.values():
		tile_counts[state] = 0
	
	if not noise:
		noise = FastNoiseLite.new()
		var gs = get_node_or_null("/root/GameSettings")
		if gs:
			noise.seed = gs.noise_seed
			noise.frequency = gs.noise_frequency
			height_step = gs.height_step
		else:
			noise.seed = randi()
			noise.frequency = 0.05
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	for y in total_h:
		for x in total_w:
			var pos_2d = _calculate_hex_position(x, y)
			var pos = Vector3(pos_2d.x, 0.0, pos_2d.y)
			var axial = _offset_to_axial(x, y)
			
			var state: int
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				state = TileConstants.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				state = TileConstants.State.DIRT
			else:
				state = TileConstants.State.GRASS
			
			var h_val = 0
			if noise:
				var nv = noise.get_noise_2d(float(x), float(y))
				h_val = int(clamp(floor((nv + 1.0) * 2.0), 0, 3))
			
			var tile = HexTileData.new(state, pos, axial, Vector2i(x, y), h_val)
			tile_data_grid.append(tile)
			tile_counts[state] += 1
			
			if state == TileConstants.State.GRASS and randf() < 0.05:
				var tree = tree_feature_scene.instantiate()
				add_child(tree)
				tree.transform.origin = pos + Vector3(0, _get_tile_surface_y(tile), 0)
				tile.feature = tree
				if tree.has_method("set_tile"):
					tree.set_tile(tile)
			
			renderer.add_tile(tile)
			if state == TileConstants.State.FIRE:
				renderer.update_fire_effect(tile, true)
	
	for tile in tile_data_grid:
		if tile.current_state == TileConstants.State.STONE:
			var max_neighbor_h: float = -10.0
			for n in _get_neighbors(tile):
				if n.current_state != TileConstants.State.STONE:
					max_neighbor_h = max(max_neighbor_h, float(n.height_level) * height_step)
			
			if max_neighbor_h > -10.0:
				tile.set_meta("stone_height", max_neighbor_h + 3.0)
			else:
				tile.set_meta("stone_height", (float(tile.height_level) * height_step) + 3.0)
			
			renderer.remove_tile(tile)
			renderer.add_tile(tile)
	
	for tile in tile_data_grid:
		tile_system.check_activeness(tile)
		
	tile_counts_changed.emit(tile_counts)

func _get_tile_surface_y(tile: HexTileData) -> float:
	if tile.current_state == TileConstants.State.STONE:
		if tile.has_meta("stone_height"):
			return tile.get_meta("stone_height")
		return (float(tile.height_level) * height_step) + 3.0
	return float(tile.height_level) * height_step

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
	
	tile_system.check_activeness(tile)
	for n in _get_neighbors(tile):
		tile_system.check_activeness(n)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if current_controlled_elemental and reticle:
		reticle.mana_value = current_controlled_elemental.get_main_action_progress()
	
	tile_system.process_tiles(delta)

func _spread_fire(tile: HexTileData) -> void:
	var neighbors = _get_neighbors(tile)
	neighbors.shuffle()
	for n in neighbors:
		if apply_element_to_tile(n, "fire"):
			break

func apply_element_to_tile(tile: HexTileData, element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if not tile: return false
	
	var feature_handled = false
	if tile.feature:
		feature_handled = DamageComponent.apply_element(tile.feature, element, direction)
	
	match element:
		"fire":
			if tile.tile_type == TileConstants.Type.FIRE or tile.tile_type == TileConstants.Type.STONE:
				return feature_handled
			match tile.tile_type:
				TileConstants.Type.GRASS:
					set_tile_state(tile, TileConstants.State.FIRE)
					tile.fire_duration = 0.0
					tile.fire_spread_triggered = false
					return true
				TileConstants.Type.MUD:
					set_tile_state(tile, TileConstants.State.DIRT)
					return true
				TileConstants.Type.PUDDLE:
					set_tile_state(tile, TileConstants.State.MUD)
					return true
		"water":
			if tile.tile_type == TileConstants.Type.FIRE:
				set_tile_state(tile, TileConstants.State.DIRT)
				tile.fire_spread_triggered = false
				tile.fire_duration = 0.0
				return true
			match tile.tile_type:
				TileConstants.Type.DIRT:
					set_tile_state(tile, TileConstants.State.MUD)
					tile.mud_duration = 0.0
					return true
				TileConstants.Type.MUD:
					set_tile_state(tile, TileConstants.State.PUDDLE)
					tile.puddle_duration = 0.0
					return true
					
	return feature_handled

func _get_neighbors(tile: HexTileData) -> Array[HexTileData]:
	var result: Array[HexTileData] = []
	var offsets = TileConstants.get_neighbor_offsets(tile.grid_coords.x)
	for offset in offsets:
		var nx = tile.grid_coords.x + offset.x
		var ny = tile.grid_coords.y + offset.y
		var n = get_tile_at_grid_coords(nx, ny)
		if n: result.append(n)
	return result

func _has_adjacent_grass(tile: HexTileData) -> bool:
	for n in _get_neighbors(tile):
		if n.tile_type == TileConstants.Type.GRASS: return true
	return false

func _get_adjacent_dirt(tile: HexTileData) -> HexTileData:
	for n in _get_neighbors(tile):
		if n.tile_type == TileConstants.Type.DIRT: return n
	return null

func get_tile_at_grid_coords(x: int, y: int) -> HexTileData:
	var h = _grid_height_clamped() + 2
	var w = _grid_width_clamped() + 2
	if x < 0 or x >= w or y < 0 or y >= h:
		return null
	return tile_data_grid[y * w + x]

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

func get_tile_at_world_position(world_position: Vector3) -> HexTileData:
	return get_tile_data_at_world_position(world_position)

func _offset_to_axial(col: int, row: int) -> Vector2i:
	var q = col
	var r = row - (col - (col & 1)) / 2
	return Vector2i(q, r)

func _setup_physics() -> void:
	if physics:
		physics.setup_physics(tile_data_grid, hex_size, tile_scale, height_step, grid_width, grid_height)

func _setup_reticle() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ReticleLayer"
	add_child(canvas_layer)
	
	reticle = Control.new()
	reticle.set_script(preload("res://Player/Reticle.gd"))
	reticle.size = Vector2(64, 64)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(reticle)

func _setup_ui_connections() -> void:
	if _prev_button:
		_prev_button.focus_mode = Control.FOCUS_NONE
		_prev_button.pressed.connect(previous_elemental)
	if _next_button:
		_next_button.focus_mode = Control.FOCUS_NONE
		_next_button.pressed.connect(next_elemental)
	if _options_button and _options_menu:
		_options_button.focus_mode = Control.FOCUS_NONE
		_options_button.pressed.connect(_options_menu.toggle)
	
	var finish_button = Button.new()
	finish_button.text = "Finish Day"
	finish_button.focus_mode = Control.FOCUS_NONE
	finish_button.position = Vector2(20, 100)
	finish_button.pressed.connect(_on_finish_day_pressed)
	if has_node("UI"):
		$UI.add_child(finish_button)

func _on_finish_day_pressed() -> void:
	GameEvents.day_finished.emit()
	if has_node("/root/GoatManager"):
		get_node("/root/GoatManager").next_day()
	get_tree().change_scene_to_file("res://Ranch/Ranch.tscn")

func _handle_game_over() -> void:
	if _target_label:
		_target_label.text = "ALL GOATS HAVE PERISHED!"
		_target_label.modulate = Color.RED
	
	current_controlled_elemental = null
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_finish_day_pressed)

func _spawn_elementals() -> void:
	elementals.clear()
	var gs = get_node_or_null("/root/GameSettings")
	
	if not gs:
		_spawn_type("fire", 1, 1)
		_spawn_type("water", grid_width, grid_height)
	else:
		for i in gs.fire_count: _spawn_type("fire")
		for i in gs.water_count: _spawn_type("water")
	
	if has_node("/root/GoatManager"):
		var gm = get_node("/root/GoatManager")
		for goat_data in gm.get_selected_goats():
			_spawn_goat_from_data(goat_data)

func _spawn_goat_from_data(data: GoatData) -> void:
	var goat = goat_elemental_scene.instantiate() as GoatElemental
	var x = randi_range(1, grid_width)
	var y = randi_range(1, grid_height)
	var pos_2d = _calculate_hex_position(x, y)
	var tile = get_tile_at_grid_coords(x, y)
	var h_offset = 0.0
	if tile:
		h_offset = _get_tile_surface_y(tile)
	
	goat.position = Vector3(pos_2d.x, 2.0 + h_offset, pos_2d.y)
	add_child(goat)
	elementals.append(goat)
	goat.goat_data = data

func spawn_elemental(type: String) -> void:
	_spawn_type(type)

func _spawn_type(type: String, x: int = -1, y: int = -1) -> void:
	var scene = fire_elemental_scene
	if type == "water": scene = water_elemental_scene
	elif type == "goat": scene = goat_elemental_scene
	
	var elemental = scene.instantiate()
	if x == -1:
		x = randi_range(1, grid_width)
		y = randi_range(1, grid_height)
	
	var pos_2d = _calculate_hex_position(x, y)
	var tile = get_tile_at_grid_coords(x, y)
	var h_offset = 0.0
	if tile:
		h_offset = _get_tile_surface_y(tile)
	
	elemental.position = Vector3(pos_2d.x, 2.0 + h_offset, pos_2d.y)
	add_child(elemental)
	elementals.append(elemental)

func _select_initial_elemental() -> void:
	if elementals.is_empty():
		return
	
	for i in range(elementals.size()):
		if elementals[i] is GoatElemental:
			current_target_index = i
			_update_camera_target()
			return
			
	current_target_index = 0
	_update_camera_target()

func _update_camera_target() -> void:
	if elementals.is_empty(): return
	var target = elementals[current_target_index % elementals.size()]
	if _camera_follower: _camera_follower.set_target(target)
	current_controlled_elemental = target as Elemental
	if _target_label: _target_label.text = "Following: " + target.name

func next_elemental() -> void:
	current_target_index += 1
	_update_camera_target()

func previous_elemental() -> void:
	current_target_index -= 1
	_update_camera_target()

func _calculate_hex_position(column: int, row: int) -> Vector2:
	var offset = float(column % 2) * 0.5
	var x_position = (1.5 * float(column)) * hex_size
	var z_position = (SQRT3 * (float(row) + offset)) * hex_size
	return Vector2(x_position, z_position)

func _grid_width_clamped() -> int: return max(1, grid_width)
func _grid_height_clamped() -> int: return max(1, grid_height)

func _on_elemental_hp_changed(_hp: float, _m_hp: float) -> void: _update_ui()
func _on_elemental_mana_changed(_m: float, _mm: float) -> void: _update_ui()

func _update_ui() -> void:
	if not current_controlled_elemental or not _target_label: return
	var hp = 0.0
	var m_hp = 0.0
	if current_controlled_elemental.health_component:
		hp = current_controlled_elemental.health_component.current_health
		m_hp = current_controlled_elemental.health_component.max_health
	_target_label.text = "Following: " + current_controlled_elemental.name + \
		" HP: %d / %d | Mana: %d / %d" % [int(hp), int(m_hp), int(current_controlled_elemental.current_mana), int(current_controlled_elemental.max_mana)]

func _setup_minimap() -> void:
	if not _minimap_viewport: return
	var camera = _minimap_viewport.get_node_or_null("MinimapCamera")
	if camera:
		var w_total = _grid_width_clamped() + 2
		var h_total = _grid_height_clamped() + 2
		var center_x = (1.5 * (float(w_total - 1) * 0.5)) * hex_size
		var center_z = (SQRT3 * (float(h_total - 1) * 0.5 + 0.25)) * hex_size
		camera.position = Vector3(center_x, 100.0, center_z)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = max(w_total * 1.5 * hex_size, h_total * SQRT3 * hex_size) * 1.1

func get_tiles_within_distance(world_position: Vector3, radius: float) -> Array[HexTileData]:
	var results: Array[HexTileData] = []
	var radius_sq = radius * radius
	for tile in tile_data_grid:
		var d = tile.position - world_position
		d.y = 0
		if d.length_squared() <= radius_sq:
			results.append(tile)
	return results

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_controlled_elemental:
			current_controlled_elemental.launch_projectile_at(_get_mouse_3d_position())
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E: current_controlled_elemental.cycle_attack_pattern()
		elif event.keycode == KEY_Q:
			var p = (current_controlled_elemental.current_attack_pattern - 1 + Elemental.AttackPattern.size()) % Elemental.AttackPattern.size()
			current_controlled_elemental.current_attack_pattern = p as Elemental.AttackPattern

func _get_mouse_3d_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector3.ZERO
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		return result.position
	
	if abs(ray_direction.y) < 1e-6: return Vector3.ZERO
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t
