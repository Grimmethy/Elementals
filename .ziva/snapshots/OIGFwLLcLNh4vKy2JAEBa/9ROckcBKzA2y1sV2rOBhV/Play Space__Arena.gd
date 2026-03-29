@tool
class_name ArenaGrid
extends Node3D

@export var tile_scene: PackedScene = preload("res://Play Space/hex_tile.tscn")
@export var grid_width: int = 40
@export var grid_height: int = 40
@export var hex_size: float = 1.5
@export_range(0.25, 3.0, 0.05) var tile_scale: float = 1.5
@export var fire_elemental_scene: PackedScene = preload("res://Elemental/FireElemental.tscn")
@export var water_elemental_scene: PackedScene = preload("res://Elemental/WaterElemental.tscn")

const SQRT3: float = sqrt(3.0)

var tile_grid: Array = []
var elementals: Array[Node3D] = []
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
		current_controlled_elemental = value
		if current_controlled_elemental:
			current_controlled_elemental.is_controlled = true
			if reticle:
				reticle.color = current_controlled_elemental.get_elemental_color()

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_update_editor_tiles()
		_setup_minimap()
		return
	
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
		
	var minimap_viewport = get_node_or_null("UI/MinimapFrame/MinimapContainer/SubViewport")
	if minimap_viewport:
		minimap_viewport.own_world_3d = false
		
		var camera = minimap_viewport.get_node_or_null("MinimapCamera")
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
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if current_controlled_elemental:
				var target_pos = _get_mouse_3d_position()
				current_controlled_elemental.launch_projectile_at(target_pos)

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
	var prev_button = get_node_or_null("UI/HBoxContainer/PrevButton") as Button
	if prev_button:
		prev_button.pressed.connect(previous_elemental)
		prev_button.focus_mode = Control.FOCUS_NONE
	var next_button = get_node_or_null("UI/HBoxContainer/NextButton") as Button
	if next_button:
		next_button.pressed.connect(next_elemental)
		next_button.focus_mode = Control.FOCUS_NONE

func _spawn_elementals() -> void:
	elementals.clear()
	_spawn_fire_elemental()
	_spawn_water_elemental()
	current_target_index = 0
	_update_camera_target()

func _update_camera_target() -> void:
	if elementals.is_empty():
		return
	var camera_controller = get_node_or_null("Camera3D") as CameraFollower
	if camera_controller:
		var target = elementals[current_target_index % elementals.size()]
		camera_controller.set_target(target)
		current_controlled_elemental = target as Elemental
		var label = get_node_or_null("UI/HBoxContainer/TargetLabel") as Label
		if label:
			label.text = "Following: " + target.name

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
	
	if current_controlled_elemental:
		if reticle:
			reticle.mana_value = current_controlled_elemental.current_mana / current_controlled_elemental.max_mana
			
		var label = get_node_or_null("UI/HBoxContainer/TargetLabel") as Label
		if label:
			label.text = "Following: " + current_controlled_elemental.name + \
				" HP: %d / %d | Mana: %d / %d" % [
					current_controlled_elemental.current_hp,
					current_controlled_elemental.max_hp,
					int(current_controlled_elemental.current_mana),
					int(current_controlled_elemental.max_mana)
				]

func _create_tiles() -> void:
	var h = _grid_height_clamped()
	var w = _grid_width_clamped()
	var total_h = h + 2
	var total_w = w + 2
	tile_grid.clear()
	tile_grid.resize(total_h)
	for y in total_h:
		var row: Array[HexTile] = []
		for x in total_w:
			var tile: HexTile = tile_scene.instantiate() as HexTile
			if not tile:
				continue
			add_child(tile)
			tile.scale = Vector3.ONE * tile_scale
			var hex_position = _calculate_hex_position(x, y)
			tile.transform.origin = Vector3(hex_position.x, 0.0, hex_position.y)
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				tile.current_state = HexTile.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				tile.current_state = HexTile.State.DIRT
			else:
				if randf() < 0.2:
					tile.current_state = HexTile.State.TREE
				else:
					tile.current_state = HexTile.State.GRASS
			row.append(tile)
		tile_grid[y] = row

func _setup_neighbors() -> void:
	for y in tile_grid.size():
		var row = tile_grid[y]
		for x in row.size():
			var tile = row[x]
			tile.neighbors = _collect_neighbors(x, y)

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

func _collect_neighbors(column: int, row: int) -> Array[HexTile]:
	var offsets = _neighbor_offsets_for_row(row)
	var result: Array[HexTile] = []
	var grid_h = tile_grid.size()
	var grid_w = tile_grid[0].size() if grid_h > 0 else 0
	for offset in offsets:
		var nx = column + offset.x
		var ny = row + offset.y
		if ny >= 0 and ny < grid_h:
			var row_data = tile_grid[ny]
			if nx >= 0 and nx < row_data.size():
				result.append(row_data[nx])
	return result

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
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				tile.current_state = HexTile.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				tile.current_state = HexTile.State.DIRT
			else:
				if randf() < 0.2:
					tile.current_state = HexTile.State.TREE
				else:
					tile.current_state = HexTile.State.GRASS
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
	var closest: HexTile
	var closest_distance_sq = 1e18
	for row in tile_grid:
		for tile in row:
			if not is_instance_valid(tile):
				continue
			var tile_position = tile.global_transform.origin
			var delta = tile_position - world_position
			delta.y = 0
			var dist_sq = delta.x * delta.x + delta.z * delta.z
			if dist_sq < closest_distance_sq:
				closest_distance_sq = dist_sq
				closest = tile
	return closest

func get_tiles_within_distance(world_position: Vector3, radius: float) -> Array:
	var results: Array = []
	var radius_sq = radius * radius
	for row in tile_grid:
		for tile in row:
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
