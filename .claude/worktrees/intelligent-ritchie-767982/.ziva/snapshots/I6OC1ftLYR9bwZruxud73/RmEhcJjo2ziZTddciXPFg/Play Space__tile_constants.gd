class_name TileConstants
extends Object

enum State { GRASS, DIRT, MUD, FIRE, PUDDLE, STONE }
enum Type { GRASS, DIRT, FIRE, STONE, MUD, PUDDLE }

const COLORS = {
	State.GRASS: Color.WHITE,
	State.DIRT: Color.WHITE,
	State.MUD: Color.WHITE,
	State.FIRE: Color(1.0, 0.4, 0.0),
	State.PUDDLE: Color.WHITE,
	State.STONE: Color.WHITE,
}

const TEXTURES = {
	State.GRASS: preload("res://assets/generated/grass_hex_tile_frame_0_1774844697.png"),
	State.DIRT: preload("res://assets/generated/dirt_hex_tile_frame_0_1774844719.png"),
	State.MUD: preload("res://assets/generated/mud_hex_tile_frame_0_1774844756.png"),
	State.PUDDLE: preload("res://assets/generated/puddle_hex_tile_frame_0_1774844737.png"),
	State.STONE: preload("res://assets/generated/stone_hex_tile_frame_0_1774844738.png"),
	State.FIRE: preload("res://assets/generated/dirt_hex_tile_frame_0_1774844719.png"),
}

# Pointy-topped hex directions
# Order: E, NE, NW, W, SW, SE
static func get_neighbor_offsets(row: int) -> Array[Vector2i]:
	if row % 2 == 0:
		return [
			Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
		]
	else:
		return [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)
		]
