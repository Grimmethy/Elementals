@tool
class_name ArenaGrid
extends Node3D

@export var tile_scene: PackedScene = preload("res://Play Space/hex_tile.tscn")
@export var tree_feature_scene: PackedScene = preload("res://Play Space/tree_feature.tscn")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var hex_size: float = 1.5
@export_range(0.25, 3.0, 0.05) var tile_scale: float = 1.5
@export var fire_elemental_scene: PackedScene = preload("res://Elemental/FireElemental.tscn")
@export var water_elemental_scene: PackedScene = preload("res://Elemental/WaterElemental.tscn")
@export var goat_elemental_scene: PackedScene = preload("res://Elemental/GoatElemental.tscn")

const SQRT3: float = sqrt(3.0)

var tile_grid: Array[Array] = []
var active_tiles: Dictionary = {}
var elementals: Array[Node3D] = []

signal tile_counts_changed(counts: Dictionary)
var tile_counts: Dictionary = {}

@onready var _target_label: Label = get_node_or_null("UI/HBoxContainer/TargetLabel")
@onready var _prev_button: Button = get_node_or_null("UI/HBoxContainer/PrevButton")
@onready var _next_button: Button = get_node_or_null("UI/HBoxContainer/NextButton")
@onready var _camera_follower: CameraFollower = get_node_or_null("Camera3D")
@onready var _minimap_viewport: SubViewport = get_node_or_null("UI/MinimapFrame/MinimapContainer/SubViewport")
@onready var _options_menu: OptionsMenu = get_node_or_null("UI/OptionsMenu")
@onready var _options_button: Button = get_node_or_null("UI/OptionsButton")

func register_active_tile(tile: HexTile) -> void:
	active_tiles[tile] = true

func unregister_active_tile(tile: HexTile) -> void:
	active_tiles.erase(tile)
var current_target_index: int = 0
var _editor_tiles: Array[HexTile] = []
var _editor_last_grid_width: int = -1
var _editor_last_grid_height: int = -1
var _editor_last_hex_size: float = -1.0
var _editor_last_tile_scale: float = -1.0
var _editor_last_tile_scene: PackedScene = tile_scene

var reticle: Control
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

func _on_elemental_hp_changed(_hp: float, _max_hp: float) -> void:
	_update_ui()

func _on_elemental_mana_changed(mana: float, max_mana: float) -> void:
	if reticle and current_controlled_elemental:
		reticle.mana_value = mana / max_mana
		reticle.attack_pattern = current_controlled_elemental.current_attack_pattern
	_update_ui()

func _update_ui() -> void:
	if not current_controlled_elemental:
		return
		
	if _target_label:
		var hp = 0.0
		var m_hp = 0.0
		if current_controlled_elemental.health_component:
			hp = current_controlled_elemental.health_component.current_health
			m_hp = current_controlled_elemental.health_component.max_health
			
		_target_label.text = "Following: " + current_controlled_elemental.name + \
			" HP: %d / %d | Mana: %d / %d" % [
				int(hp),
				int(m_hp),
				int(current_controlled_elemental.current_mana),
				int(current_controlled_elemental.max_mana)
			]

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_update_editor_tiles()
		_setup_minimap()
		return
	
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		grid_width = gs.grid_width
		grid_height = gs.grid_height
	
	_setup_reticle()
	_create_tiles()
	_setup_neighbors()
	_spawn_elementals()
	_setup_ui_connections()
	_setup_minimap()
	add_to_group("arena")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _setup_minimap() -> void:
	# Use call_deferred to ensure we are in the tree and ready
	_do_setup_minimap.call_deferred()

func _do_setup_minimap() -> void:
	if not is_inside_tree():
		return
		
	if _minimap_viewport:
		_minimap_viewport.own_world_3d = false
		
		var camera = _minimap_viewport.get_node_or_null("MinimapCamera")
		if camera:
			var w_total = _grid_width_clamped() + 2
			var h_total = _grid_height_clamped() + 2
			
			var center_x = (SQRT3 * (float(w_total - 1) * 0.5 + 0.25)) * hex_size
			var center_z = (1.5 * float(h_total - 1) * 0.5) * hex_size
			
			camera.position = Vector3(center_x, 100.0, center_z)
			camera.rotation_degrees = Vector3(-90, 0, 0)
			camera.current = true
			
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			var grid_width_world = (SQRT3 * (float(w_total) + 0.5)) * hex_size
			var grid_height_world = (1.5 * float(h_total)) * hex_size
			camera.size = max(grid_width_world, grid_height_world) * 1.1

func _setup_reticle() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ReticleLayer"
	add_child(canvas_layer)
	
	reticle = Control.new()
	reticle.set_script(preload("res://Player/Reticle.gd"))
	reticle.size = Vector2(64, 64)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(reticle)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
		
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if current_controlled_elemental:
					var target_pos = _get_mouse_3d_position()
					current_controlled_elemental.launch_projectile_at(target_pos)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			if current_controlled_elemental:
				current_controlled_elemental.cycle_attack_pattern()
				if reticle:
					reticle.attack_pattern = current_controlled_elemental.current_attack_pattern
		elif event.keycode == KEY_Q:
			if current_controlled_elemental:
				# Cycle backwards
				var p = current_controlled_elemental.current_attack_pattern
				p = (p - 1 + Elemental.AttackPattern.size()) % Elemental.AttackPattern.size()
				current_controlled_elemental.current_attack_pattern = p as Elemental.AttackPattern
				if reticle:
					reticle.attack_pattern = current_controlled_elemental.current_attack_pattern

func _get_mouse_3d_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	if abs(ray_direction.y) < 1e-6:
		return Vector3.ZERO
		
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t

func _setup_ui_connections() -> void:
	if _prev_button:
		_prev_button.pressed.connect(previous_elemental)
		_prev_button.focus_mode = Control.FOCUS_NONE
	if _next_button:
		_next_button.pressed.connect(next_elemental)
		_next_button.focus_mode = Control.FOCUS_NONE
	if _options_button and _options_menu:
		_options_button.pressed.connect(_options_menu.toggle)

func spawn_elemental(type: String) -> void:
	var scene: PackedScene
	var name_prefix: String
	
	match type.to_lower():
		"fire":
			scene = fire_elemental_scene
			name_prefix = "FireElemental"
		"water":
			scene = water_elemental_scene
			name_prefix = "WaterElemental"
		"goat":
			scene = goat_elemental_scene
			name_prefix = "GoatElemental"
		_:
			return
			
	if not scene:
		return
		
	var elemental = scene.instantiate()
	if not elemental:
		return
		
	elemental.name = name_prefix + "_" + str(elementals.size())
	
	# Spawn at a random position or center
	var w = _grid_width_clamped()
	var h = _grid_height_clamped()
	var rx = randi_range(1, w)
	var ry = randi_range(1, h)
	var spawn_pos = _calculate_hex_position(rx, ry)
	elemental.position = Vector3(spawn_pos.x, 2.0, spawn_pos.y)
	
	add_child(elemental)
	elementals.append(elemental)
	
	# If this is the first elemental, update camera
	if elementals.size() == 1:
		current_target_index = 0
		_update_camera_target()

func _spawn_elementals() -> void:
	elementals.clear()
	var gs = get_node_or_null("/root/GameSettings")
	
	if not gs:
		_spawn_fire_elemental()
		_spawn_water_elemental()
		_spawn_goat_elemental()
		current_target_index = 0
	else:
		# Spawn requested counts
		for i in gs.fire_count:
			spawn_elemental("fire")
		for i in gs.water_count:
			spawn_elemental("water")
		for i in gs.goat_count:
			spawn_elemental("goat")
			
		# Ensure player has their selected elemental to control
		var found_index = -1
		for i in range(elementals.size()):
			var e = elementals[i]
			var is_match = false
			if gs.selected_elemental_type == "fire" and e.name.begins_with("FireElemental"):
				is_match = true
			elif gs.selected_elemental_type == "water" and e.name.begins_with("WaterElemental"):
				is_match = true
			elif gs.selected_elemental_type == "goat" and e.name.begins_with("GoatElemental"):
				is_match = true
			
			if is_match:
				found_index = i
				break
		
		if found_index == -1:
			# If none were spawned for the selected type, spawn one now
			spawn_elemental(gs.selected_elemental_type)
			found_index = elementals.size() - 1
			
		current_target_index = found_index
		
	_update_camera_target()

func _spawn_goat_elemental() -> void:
	if not goat_elemental_scene:
		return
	var elemental = goat_elemental_scene.instantiate()
	if not elemental:
		return
	elemental.name = "GoatElemental"
	
	# Spawn somewhere else
	var w = _grid_width_clamped()
	var h = _grid_height_clamped()
	var spawn_pos = _calculate_hex_position(w/2, h/2)
	elemental.position = Vector3(spawn_pos.x, 2.0, spawn_pos.y) # Spawn slightly higher
	
	add_child(elemental)
	elementals.append(elemental)

func _update_camera_target() -> void:
	if elementals.is_empty():
		return
	if _camera_follower:
		var target = elementals[current_target_index % elementals.size()]
		_camera_follower.set_target(target)
		current_controlled_elemental = target as Elemental
		if _target_label:
			_target_label.text = "Following: " + target.name

func next_elemental() -> void:
	if elementals.is_empty():
		return
	current_target_index = (current_target_index + 1) % elementals.size()
	_update_camera_target()

func previous_elemental() -> void:
	if elementals.is_empty():
		return
	current_target_index = (current_target_index - 1 + elementals.size()) % elementals.size()
	_update_camera_target()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		_clear_editor_tiles()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if _has_editor_property_changes():
			_update_editor_tiles()
			_do_setup_minimap()
		return
	
	# Update active tiles logic
	for tile in active_tiles.keys():
		if is_instance_valid(tile):
			tile.process_tile(delta)
		else:
			active_tiles.erase(tile)

func _create_tiles() -> void:
	var h = _grid_height_clamped()
	var w = _grid_width_clamped()
	var total_h = h + 2
	var total_w = w + 2
	tile_grid.clear()
	tile_grid.resize(total_h)
	tile_counts.clear()
	for state in HexTile.State.values():
		tile_counts[state] = 0
		
	for y in total_h:
		var row: Array[HexTile] = []
		for x in total_w:
			var tile: HexTile = tile_scene.instantiate() as HexTile
			if not tile:
				continue
			tile.arena = self
			add_child(tile)
			tile.scale = Vector3.ONE * tile_scale
			var hex_position = _calculate_hex_position(x, y)
			tile.transform.origin = Vector3(hex_position.x, 0.0, hex_position.y)
			
			var initial_state: HexTile.State
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				initial_state = HexTile.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				initial_state = HexTile.State.DIRT
			else:
				initial_state = HexTile.State.GRASS
				if randf() < 0.05:
					var tree = tree_feature_scene.instantiate()
					tile.add_child(tree)
			
			tile.current_state = initial_state
			tile_counts[initial_state] += 1
			tile.state_changed.connect(_on_tile_state_changed)
			
			row.append(tile)
		tile_grid[y] = row
	tile_counts_changed.emit(tile_counts)

func _on_tile_state_changed(old_state: HexTile.State, new_state: HexTile.State) -> void:
	tile_counts[old_state] -= 1
	tile_counts[new_state] = tile_counts.get(new_state, 0) + 1
	tile_counts_changed.emit(tile_counts)

func _setup_neighbors() -> void:
	for y in tile_grid.size():
		var row = tile_grid[y]
		for x in row.size():
			var tile = row[x]
			tile.neighbors.clear()
			tile.neighbor_slots.clear()
			tile.neighbor_slots.resize(6)
			
			var offsets = _neighbor_offsets_for_row(y)
			for i in range(offsets.size()):
				var offset = offsets[i]
				var nx = x + offset.x
				var ny = y + offset.y
				if ny >= 0 and ny < tile_grid.size():
					var r_data = tile_grid[ny]
					if nx >= 0 and nx < r_data.size():
						var neighbor = r_data[nx]
						tile.neighbor_slots[i] = neighbor
						tile.neighbors.append(neighbor)
			tile.check_activeness()

func _spawn_fire_elemental() -> void:
	if not fire_elemental_scene:
		return
	var elemental: FireElemental = fire_elemental_scene.instantiate() as FireElemental
	if not elemental:
		return
	elemental.name = "FireElemental"
	
	# Top-left playable corner: (1, 1)
	var spawn_pos = _calculate_hex_position(1, 1)
	elemental.position = Vector3(spawn_pos.x, 2.0, spawn_pos.y) # Spawn slightly higher
	
	add_child(elemental)
	elementals.append(elemental)

func _spawn_water_elemental() -> void:
	if not water_elemental_scene:
		return
	var elemental = water_elemental_scene.instantiate()
	if not elemental:
		return
	elemental.name = "WaterElemental"
	
	# Bottom-right playable corner: (grid_width, grid_height)
	var w = _grid_width_clamped()
	var h = _grid_height_clamped()
	var spawn_pos = _calculate_hex_position(w, h)
	elemental.position = Vector3(spawn_pos.x, 2.0, spawn_pos.y) # Spawn slightly higher
	
	add_child(elemental)
	elementals.append(elemental)

func _calculate_hex_position(column: int, row: int) -> Vector2:
	var offset = float(row % 2) * 0.5
	var x_position = (SQRT3 * (float(column) + offset)) * hex_size
	var z_position = (1.5 * float(row)) * hex_size
	return Vector2(x_position, z_position)

func _neighbor_offsets_for_row(row: int) -> Array[Vector2i]:
	if row % 2 == 0:
		return [
			Vector2i(1, 0),
			Vector2i(0, -1),
			Vector2i(-1, -1),
			Vector2i(-1, 0),
			Vector2i(-1, 1),
			Vector2i(0, 1)
		]
	else:
		return [
			Vector2i(1, 0),
			Vector2i(1, -1),
			Vector2i(0, -1),
			Vector2i(-1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1)
		]

func _update_editor_tiles() -> void:
	_clear_editor_tiles()
	if not Engine.is_editor_hint():
		return

	tile_counts.clear()
	for state in HexTile.State.values():
		tile_counts[state] = 0
		
	var w = _grid_width_clamped()
	var h = _grid_height_clamped()
	var total_w = w + 2
	var total_h = h + 2
	if w <= 0 or h <= 0:
		_update_editor_tracking(w, h)
		return
	if not tile_scene:
		_update_editor_tracking(w, h)
		return

	for y in total_h:
		for x in total_w:
			var tile: HexTile = tile_scene.instantiate() as HexTile
			if not tile:
				continue
			tile.owner = null
			add_child(tile)
			tile.scale = Vector3.ONE * tile_scale
			var hex_position = _calculate_hex_position(x, y)
			tile.transform.origin = Vector3(hex_position.x, 0.0, hex_position.y)
			var initial_state: HexTile.State
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				initial_state = HexTile.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				initial_state = HexTile.State.DIRT
			else:
				initial_state = HexTile.State.GRASS
				if randf() < 0.05:
					var tree = tree_feature_scene.instantiate()
					tile.add_child(tree)
			
			tile.current_state = initial_state
			tile_counts[initial_state] += 1
			tile.state_changed.connect(_on_tile_state_changed)
			_editor_tiles.append(tile)

	_update_editor_tracking(w, h)

func _clear_editor_tiles() -> void:
	for tile in _editor_tiles:
		if is_instance_valid(tile):
			tile.owner = null
			tile.queue_free()
	_editor_tiles.clear()

func _has_editor_property_changes() -> bool:
	return _editor_last_grid_width != _grid_width_clamped() or _editor_last_grid_height != _grid_height_clamped() or _editor_last_hex_size != hex_size or _editor_last_tile_scene != tile_scene or _editor_last_tile_scale != tile_scale

func _update_editor_tracking(width: int, height: int) -> void:
	_editor_last_grid_width = width
	_editor_last_grid_height = height
	_editor_last_hex_size = hex_size
	_editor_last_tile_scene = tile_scene
	_editor_last_tile_scale = tile_scale

func _grid_width_clamped() -> int:
	return max(1, grid_width)

func _grid_height_clamped() -> int:
	return max(1, grid_height)

func get_tile_at_world_position(world_position: Vector3) -> HexTile:
	if tile_grid.is_empty():
		return null
		
	var local_pos = to_local(world_position)
	var x = local_pos.x
	var z = local_pos.z
	
	# Pointy-topped hex inverse math
	var r_float = z / (1.5 * hex_size)
	var q_float = (x / (SQRT3 * hex_size)) - (r_float * 0.5)
	
	# Cube rounding for robustness
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
	
	var row = int(rr)
	var col = int(rq) + (row - (row & 1)) / 2
	
	if row >= 0 and row < tile_grid.size():
		var row_data = tile_grid[row]
		if col >= 0 and col < row_data.size():
			return row_data[col]
			
	return null

func get_tiles_within_distance(world_position: Vector3, radius: float) -> Array:
	if tile_grid.is_empty():
		return []
		
	var results: Array = []
	var radius_sq = radius * radius
	var local_center = to_local(world_position)
	
	# Grid spacing
	var col_step = SQRT3 * hex_size
	var row_step = 1.5 * hex_size
	
	# Bounding box in row/col space
	var r_min = int(floor((local_center.z - radius) / row_step))
	var r_max = int(ceil((local_center.z + radius) / row_step))
	
	# Column bounding box needs to be generous due to row offsets
	var c_min = int(floor((local_center.x - radius) / col_step)) - 1
	var c_max = int(ceil((local_center.x + radius) / col_step)) + 1
	
	r_min = clamp(r_min, 0, tile_grid.size() - 1)
	r_max = clamp(r_max, 0, tile_grid.size() - 1)
	
	for r in range(r_min, r_max + 1):
		var row_data = tile_grid[r]
		var c_start = clamp(c_min, 0, row_data.size() - 1)
		var c_end = clamp(c_max, 0, row_data.size() - 1)
		
		for c in range(c_start, c_end + 1):
			var tile = row_data[c]
			if not is_instance_valid(tile):
				continue
			var tile_position = tile.global_transform.origin
			var delta = tile_position - world_position
			delta.y = 0
			if delta.x * delta.x + delta.z * delta.z <= radius_sq:
				results.append(tile)
	return results

func is_position_within_range(center: Vector3, position: Vector3, range: float) -> bool:
	return center.distance_squared_to(position) <= range * range
