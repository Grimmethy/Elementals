class_name HexTileData
extends Object

var state: int # HexTile.State
var type: int  # HexTile.Type
var position: Vector3
var axial_coords: Vector2i # (q, r)
var grid_coords: Vector2i  # (col, row)

var fire_duration: float = 0.0
var fire_spread_triggered: bool = false
var mud_duration: float = 0.0
var puddle_duration: float = 0.0

var feature: Node3D # If there's a tree or something on it

func _init(p_state: int, p_pos: Vector3, p_axial: Vector2i, p_grid: Vector2i) -> void:
	state = p_state
	position = p_pos
	axial_coords = p_axial
	grid_coords = p_grid
	_sync_type()

func _sync_type() -> void:
	# Keep in sync with HexTile.Type/State
	# State.GRASS=0, DIRT=1, MUD=2, FIRE=3, PUDDLE=4, STONE=5
	# Type.GRASS=0, DIRT=1, FIRE=2, STONE=3, MUD=4, PUDDLE=5
	# Note: The original HexTile.gd had different mappings between Type and State.
	# Let's check HexTile.gd again.
	# State: GRASS(0), DIRT(1), MUD(2), FIRE(3), PUDDLE(4), STONE(5)
	# Type: GRASS(0), DIRT(1), FIRE(2), STONE(3), MUD(4), PUDDLE(5)
	# match current_state:
	#   State.GRASS: tile_type = Type.GRASS (0)
	#   State.DIRT: tile_type = Type.DIRT (1)
	#   State.MUD: tile_type = Type.MUD (4)
	#   State.FIRE: tile_type = Type.FIRE (2)
	#   State.PUDDLE: tile_type = Type.PUDDLE (5)
	#   State.STONE: tile_type = Type.STONE (3)
	
	match state:
		0: type = 0 # GRASS
		1: type = 1 # DIRT
		2: type = 4 # MUD
		3: type = 2 # FIRE
		4: type = 5 # PUDDLE
		5: type = 3 # STONE
