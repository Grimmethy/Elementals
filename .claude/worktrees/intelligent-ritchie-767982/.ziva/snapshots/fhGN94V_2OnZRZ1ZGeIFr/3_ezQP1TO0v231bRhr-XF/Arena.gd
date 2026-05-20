class_name Arena
extends Node3D

@export var tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var hex_size: float = 1.5

const SQRT3: float = sqrt(3.0)

var tile_grid: Array = []

func _ready() -> void:
	_create_tiles()
	_setup_neighbors()

func _create_tiles() -> void:
	tile_grid.resize(grid_height)
	for y in grid_height:
		var row: Array = []
		for x in grid_width:
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
	for y in grid_height:
		for x in grid_width:
			var tile = tile_grid[y][x]
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
