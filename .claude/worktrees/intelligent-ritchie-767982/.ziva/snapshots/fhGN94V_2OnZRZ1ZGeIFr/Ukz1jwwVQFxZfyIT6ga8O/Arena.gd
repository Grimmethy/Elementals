tool
class_name Arena
extends Node3D

@export var tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var hex_size: float = 1.5

const SQRT3: float = sqrt(3.0)

var tile_grid: Array[Array[HexTile]] = []
var _editor_tiles: Array[HexTile] = []
var _editor_last_grid_width: int = -1
var _editor_last_grid_height: int = -1
var _editor_last_hex_size: float = -1.0
var _editor_last_tile_scene: PackedScene = tile_scene

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_update_editor_tiles()
		return
	_create_tiles()
	_setup_neighbors()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		_clear_editor_tiles()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _has_editor_property_changes():
		_update_editor_tiles()

func _create_tiles() -> void:
	var height = _grid_height_clamped()
	var width = _grid_width_clamped()
	tile_grid.resize(height)
	for y in height:
		var row: Array[HexTile] = []
		for x in width:
			var tile: HexTile = tile_scene.instantiate() as HexTile
			if not tile:
				continue
			add_child(tile)
			var hex_position = _calculate_hex_position(x, y)
			tile.transform.origin = Vector3(hex_position.x, 0.0, hex_position.y)
			tile.current_state = HexTile.State.GRASS
			row.append(tile)
		tile_grid[y] = row

func _setup_neighbors() -> void:
	for y in tile_grid.size():
		var row = tile_grid[y]
		for x in row.size():
			var tile = row[x]
			tile.neighbors = _collect_neighbors(x, y)

func _calculate_hex_position(column: int, row: int) -> Vector2:
	var offset = float(row % 2) * 0.5
	var x_position = (SQRT3 * (float(column) + offset)) * hex_size
	var z_position = (1.5 * float(row)) * hex_size
	return Vector2(x_position, z_position)

func _collect_neighbors(column: int, row: int) -> Array[HexTile]:
	var offsets = _neighbor_offsets_for_row(row)
	var result: Array[HexTile] = []
	for offset in offsets:
		var nx = column + offset.x
		var ny = row + offset.y
		if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
			result.append(tile_grid[ny][nx])
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

	var width = _grid_width_clamped()
	var height = _grid_height_clamped()
	if width <= 0 or height <= 0:
		_update_editor_tracking(width, height)
		return
	if not tile_scene:
		_update_editor_tracking(width, height)
		return

	for y in height:
		for x in width:
			var tile: HexTile = tile_scene.instantiate() as HexTile
			if not tile:
				continue
			tile.owner = null
			add_child(tile)
			var hex_position = _calculate_hex_position(x, y)
			tile.transform.origin = Vector3(hex_position.x, 0.0, hex_position.y)
			tile.current_state = HexTile.State.GRASS
			_editor_tiles.append(tile)

	_update_editor_tracking(width, height)

func _clear_editor_tiles() -> void:
	for tile in _editor_tiles:
		if is_instance_valid(tile):
			tile.owner = null
			tile.queue_free()
	_editor_tiles.clear()

func _has_editor_property_changes() -> bool:
	return _editor_last_grid_width != _grid_width_clamped() or _editor_last_grid_height != _grid_height_clamped() or _editor_last_hex_size != hex_size or _editor_last_tile_scene != tile_scene

func _update_editor_tracking(width: int, height: int) -> void:
	_editor_last_grid_width = width
	_editor_last_grid_height = height
	_editor_last_hex_size = hex_size
	_editor_last_tile_scene = tile_scene

func _grid_width_clamped() -> int:
	return max(1, grid_width)

func _grid_height_clamped() -> int:
	return max(1, grid_height)
