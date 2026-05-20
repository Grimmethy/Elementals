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

const SQRT3: float = sqrt(3.0)

# Data storage
var tile_data_grid: Array[HexTileData] = []
var active_registry: Dictionary = {} # axial_coords -> HexTileData
var elementals: Array[Node3D] = []

# MultiMesh Rendering
var multimesh_instances: Dictionary = {} # State -> MultiMeshInstance3D
var multimesh_tile_lists: Dictionary = {} # State -> Array[HexTileData]
var fire_effect_mm: MultiMeshInstance3D

# Physics
var floor_static_body: StaticBody3D

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
	# Ignore editor hint for simplicity in this refactor, focus on runtime performance
	if Engine.is_editor_hint():
		return
	
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		grid_width = gs.grid_width
		grid_height = gs.grid_height
	
	_setup_reticle()
	_initialize_grid()
	_setup_physics()
	_spawn_elementals()
	_setup_ui_connections()
	_setup_minimap()
	add_to_group("arena")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _initialize_grid() -> void:
	var h = _grid_height_clamped()
	var w = _grid_width_clamped()
	var total_h = h + 2
	var total_w = w + 2
	var total_tiles = total_h * total_w
	
	_setup_multimeshes(total_tiles)
	_setup_fire_mm(total_tiles)
	
	tile_data_grid.clear()
	tile_counts.clear()
	for state in TileConstants.State.values():
		tile_counts[state] = 0
	
	for y in total_h:
		for x in total_w:
			var pos_2d = _calculate_hex_position(x, y)
			var pos = Vector3(pos_2d.x, 0.0, pos_2d.y)
			var axial = _offset_to_axial(x, y)
			
			var state: TileConstants.State
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				state = TileConstants.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				state = TileConstants.State.DIRT
			else:
				state = TileConstants.State.GRASS
			
			var tile = HexTileData.new(state, pos, axial, Vector2i(x, y))
			tile_data_grid.append(tile)
			tile_counts[state] += 1
			
			# Features
			if state == TileConstants.State.GRASS and randf() < 0.05:
				var tree = tree_feature_scene.instantiate()
				add_child(tree)
				tree.transform.origin = pos
				tile.feature = tree
				if tree.has_method("set_tile"):
					tree.set_tile(tile)
			
			_add_tile_to_multimesh(tile)
			if state == TileConstants.State.FIRE:
				_update_fire_effect(tile, true)
	
	# Initial activeness check
	for tile in tile_data_grid:
		_check_tile_activeness(tile)
		
	tile_counts_changed.emit(tile_counts)

func _setup_fire_mm(max_instances: int) -> void:
	fire_effect_mm = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = QuadMesh.new()
	mm.instance_count = max_instances
	mm.visible_instance_count = 0
	fire_effect_mm.multimesh = mm
	
	var mat = StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = preload("res://assets/generated/fire_particle_1774823455.png")
	fire_effect_mm.set_surface_override_material(0, mat)
	
	add_child(fire_effect_mm)
	fire_effect_mm.set_meta("tile_list", [])

func _update_fire_effect(tile: HexTileData, active: bool) -> void:
	if not fire_effect_mm: return
	var list = fire_effect_mm.get_meta("tile_list") as Array
	
	if active:
		if tile.get_meta("fire_mm_index", -1) != -1: return
		tile.set_meta("fire_mm_index", list.size())
		list.append(tile)
		fire_effect_mm.multimesh.visible_instance_count = list.size()
		var t = Transform3D()
		t.origin = tile.position + Vector3(0, 0.5, 0)
		t = t.scaled_local(Vector3.ONE * 0.8)
		fire_effect_mm.multimesh.set_instance_transform(list.size() - 1, t)
	else:
		var idx = tile.get_meta("fire_mm_index", -1)
		if idx == -1: return
		
		var last_tile = list.back()
		if last_tile != tile:
			list[idx] = last_tile
			last_tile.set_meta("fire_mm_index", idx)
			var t = Transform3D()
			t.origin = last_tile.position + Vector3(0, 0.5, 0)
			t = t.scaled_local(Vector3.ONE * 0.8)
			fire_effect_mm.multimesh.set_instance_transform(idx, t)
			
		list.pop_back()
		tile.set_meta("fire_mm_index", -1)
		fire_effect_mm.multimesh.visible_instance_count = list.size()

func _setup_multimeshes(max_instances: int) -> void:
	var hex_mesh = CylinderMesh.new()
	hex_mesh.top_radius = 1.0
	hex_mesh.bottom_radius = 1.0
	hex_mesh.height = 0.2
	hex_mesh.radial_segments = 6
	
	for state in TileConstants.State.values():
		var mmi = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = hex_mesh
		mm.instance_count = max_instances
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		
		var mat = StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_color = TileConstants.COLORS[state]
		mat.albedo_texture = TileConstants.TEXTURES[state]
		mmi.set_surface_override_material(0, mat)
		
		add_child(mmi)
		multimesh_instances[state] = mmi
		multimesh_tile_lists[state] = []

func _add_tile_to_multimesh(tile: HexTileData) -> void:
	var state = tile.state
	var mmi = multimesh_instances[state]
	var list = multimesh_tile_lists[state]
	
	tile.set_meta("mm_index", list.size())
	list.append(tile)
	mmi.multimesh.visible_instance_count = list.size()
	mmi.multimesh.set_instance_transform(list.size() - 1, _get_tile_transform(tile))

func _remove_tile_from_multimesh(tile: HexTileData) -> void:
	var state = tile.state
	var mmi = multimesh_instances[state]
	var list = multimesh_tile_lists[state]
	var idx = tile.get_meta("mm_index")
	
	var last_tile = list.back()
	if last_tile != tile:
		list[idx] = last_tile
		last_tile.set_meta("mm_index", idx)
		mmi.multimesh.set_instance_transform(idx, _get_tile_transform(last_tile))
	
	list.pop_back()
	mmi.multimesh.visible_instance_count = list.size()

func _get_tile_transform(tile: HexTileData) -> Transform3D:
	var t = Transform3D()
	t.origin = tile.position
	t = t.scaled_local(Vector3.ONE * tile_scale)
	
	if tile.state == TileConstants.State.STONE:
		t = t.scaled_local(Vector3(1, 10, 1))
		t.origin.y = 0.9
	
	return t

func set_tile_state(tile: HexTileData, new_state: int) -> void:
	if tile.state == new_state:
		return
		
	var old_state = tile.state
	_remove_tile_from_multimesh(tile)
	
	if old_state == TileConstants.State.FIRE:
		_update_fire_effect(tile, false)
	
	tile.state = new_state
	tile._sync_type()
	
	_add_tile_to_multimesh(tile)
	
	if new_state == TileConstants.State.FIRE:
		_update_fire_effect(tile, true)
	
	tile_counts[old_state] -= 1
	tile_counts[new_state] += 1
	tile_counts_changed.emit(tile_counts)
	
	_check_tile_activeness(tile)
	for n in _get_neighbors(tile):
		_check_tile_activeness(n)

func _check_tile_activeness(tile: HexTileData) -> void:
	var should_be_active = false
	match tile.type:
		TileConstants.Type.FIRE:
			should_be_active = true
		TileConstants.Type.MUD:
			if _has_adjacent_grass(tile):
				should_be_active = true
		TileConstants.Type.PUDDLE:
			if _get_adjacent_dirt(tile):
				should_be_active = true
	
	if should_be_active:
		active_registry[tile.axial_coords] = tile
	else:
		active_registry.erase(tile.axial_coords)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if current_controlled_elemental and reticle:
		reticle.mana_value = current_controlled_elemental.get_main_action_progress()
	
	_process_active_tiles(delta)

func _process_active_tiles(delta: float) -> void:
	# Use a list to avoid modification issues during iteration
	var active_tiles = active_registry.values()
	for tile in active_tiles:
		match tile.type:
			TileConstants.Type.FIRE:
				tile.fire_duration += delta
				if tile.fire_duration >= 4.0 and not tile.fire_spread_triggered:
					tile.fire_spread_triggered = true
					_spread_fire(tile)
				if tile.fire_duration >= 5.0:
					tile.fire_duration = 0.0
					tile.fire_spread_triggered = false
					set_tile_state(tile, TileConstants.State.DIRT)
					
			TileConstants.Type.MUD:
				if _has_adjacent_grass(tile):
					tile.mud_duration += delta
					if tile.mud_duration >= 5.0:
						set_tile_state(tile, TileConstants.State.GRASS)
						tile.mud_duration = 0.0
				else:
					tile.mud_duration = 0.0
					_check_tile_activeness(tile)
					
			TileConstants.Type.PUDDLE:
				var dirt_neighbor = _get_adjacent_dirt(tile)
				if dirt_neighbor:
					tile.puddle_duration += delta
					if tile.puddle_duration >= 5.0:
						set_tile_state(dirt_neighbor, TileConstants.State.MUD)
						tile.puddle_duration = 0.0
				else:
					tile.puddle_duration = 0.0
					_check_tile_activeness(tile)

func _spread_fire(tile: HexTileData) -> void:
	var neighbors = _get_neighbors(tile)
	neighbors.shuffle()
	for n in neighbors:
		if apply_element_to_tile(n, "fire"):
			break

func apply_element_to_tile(tile: HexTileData, element: String) -> bool:
	if not tile: return false
	
	var feature_handled = false
	if tile.feature and tile.feature.has_method("apply_element"):
		feature_handled = tile.feature.apply_element(element, Vector3.ZERO)
	
	match element:
		"fire":
			if tile.type == TileConstants.Type.FIRE or tile.type == TileConstants.Type.STONE:
				return feature_handled
			match tile.type:
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
			if tile.type == TileConstants.Type.FIRE:
				set_tile_state(tile, TileConstants.State.DIRT)
				tile.fire_spread_triggered = false
				tile.fire_duration = 0.0
				return true
			match tile.type:
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
	var offsets = TileConstants.get_neighbor_offsets(tile.grid_coords.y)
	for offset in offsets:
		var nx = tile.grid_coords.x + offset.x
		var ny = tile.grid_coords.y + offset.y
		var n = get_tile_at_grid_coords(nx, ny)
		if n: result.append(n)
	return result

func _has_adjacent_grass(tile: HexTileData) -> bool:
	for n in _get_neighbors(tile):
		if n.type == TileConstants.Type.GRASS: return true
	return false

func _get_adjacent_dirt(tile: HexTileData) -> HexTileData:
	for n in _get_neighbors(tile):
		if n.type == TileConstants.Type.DIRT: return n
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
	
	var r_float = z / (1.5 * hex_size)
	var q_float = (x / (SQRT3 * hex_size)) - (r_float * 0.5)
	
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
	
	return get_tile_at_grid_coords(col, row)

# Legacy support for Elemental script
func get_tile_at_world_position(world_position: Vector3) -> HexTileData:
	return get_tile_data_at_world_position(world_position)

func _offset_to_axial(col: int, row: int) -> Vector2i:
	var q = col - (row - (row & 1)) / 2
	var r = row
	return Vector2i(q, r)

func _setup_physics() -> void:
	# Create a single StaticBody3D for the floor
	floor_static_body = StaticBody3D.new()
	add_child(floor_static_body)
	
	# For performance and hex-specific collision, we use a ConcavePolygonShape3D
	# generated from the hex mesh and all tile positions.
	var shape = ConcavePolygonShape3D.new()
	var vertices: PackedVector3Array = []
	
	# Use a simple box or plane if flat, but Stone tiles are tall.
	# We'll just add the collision faces for each tile.
	var hex_mesh = CylinderMesh.new()
	hex_mesh.radial_segments = 6
	hex_mesh.height = 0.2
	var mesh_faces = hex_mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
	
	for tile in tile_data_grid:
		var t = _get_tile_transform(tile)
		for v in mesh_faces:
			vertices.append(t * v)
			
	shape.set_faces(vertices)
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape
	floor_static_body.add_child(collision_shape)

# Rest of the functions (UI, spawning, etc.) kept or adapted
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
		_prev_button.pressed.connect(previous_elemental)
	if _next_button:
		_next_button.pressed.connect(next_elemental)
	if _options_button and _options_menu:
		_options_button.pressed.connect(_options_menu.toggle)

func _spawn_elementals() -> void:
	elementals.clear()
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		_spawn_type("fire", 1, 1)
		_spawn_type("water", grid_width, grid_height)
		_spawn_type("goat", grid_width/2, grid_height/2)
	else:
		for i in gs.fire_count: _spawn_type("fire")
		for i in gs.water_count: _spawn_type("water")
		for i in gs.goat_count: _spawn_type("goat")
		
	current_target_index = 0
	_update_camera_target()

func _spawn_type(type: String, x: int = -1, y: int = -1) -> void:
	var scene = fire_elemental_scene
	if type == "water": scene = water_elemental_scene
	elif type == "goat": scene = goat_elemental_scene
	
	var elemental = scene.instantiate()
	if x == -1:
		x = randi_range(1, grid_width)
		y = randi_range(1, grid_height)
	
	var pos_2d = _calculate_hex_position(x, y)
	elemental.position = Vector3(pos_2d.x, 2.0, pos_2d.y)
	add_child(elemental)
	elementals.append(elemental)

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
	var offset = float(row % 2) * 0.5
	var x_position = (SQRT3 * (float(column) + offset)) * hex_size
	var z_position = (1.5 * float(row)) * hex_size
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
		var center_x = (SQRT3 * (float(w_total - 1) * 0.5 + 0.25)) * hex_size
		var center_z = (1.5 * float(h_total - 1) * 0.5) * hex_size
		camera.position = Vector3(center_x, 100.0, center_z)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = max(w_total * SQRT3 * hex_size, h_total * 1.5 * hex_size) * 1.1

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
	if abs(ray_direction.y) < 1e-6: return Vector3.ZERO
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t
