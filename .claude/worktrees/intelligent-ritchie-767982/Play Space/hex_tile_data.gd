class_name HexTileData
extends Object

var current_state: int # TileConstants.State
var tile_type: int  # TileConstants.Type
var position: Vector3
var axial_coords: Vector2i # (q, r)
var grid_coords: Vector2i  # (col, row)

var fire_duration: float = 0.0
var fire_spread_triggered: bool = false
var mud_duration: float = 0.0
var puddle_duration: float = 0.0

var height_level: int = 0
var feature: Node3D # If there's a tree or something on it

func _init(p_state: int, p_pos: Vector3, p_axial: Vector2i, p_grid: Vector2i, p_height: int = 0) -> void:
	current_state = p_state
	position = p_pos
	axial_coords = p_axial
	grid_coords = p_grid
	height_level = p_height
	_sync_type()

func _sync_type() -> void:
	# Keep in sync with TileConstants.Type/State
	# State: GRASS(0), DIRT(1), MUD(2), FIRE(3), PUDDLE(4), STONE(5)
	# Type: GRASS(0), DIRT(1), FIRE(2), STONE(3), MUD(4), PUDDLE(5)
	
	match current_state:
		TileConstants.State.GRASS: tile_type = TileConstants.Type.GRASS
		TileConstants.State.DIRT: tile_type = TileConstants.Type.DIRT
		TileConstants.State.MUD: tile_type = TileConstants.Type.MUD
		TileConstants.State.FIRE: tile_type = TileConstants.Type.FIRE
		TileConstants.State.PUDDLE: tile_type = TileConstants.Type.PUDDLE
		TileConstants.State.STONE: tile_type = TileConstants.Type.STONE
