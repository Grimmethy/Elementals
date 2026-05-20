class_name Arena
extends Node3D

@export var tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var grid_radius: int = 5

var tiles: Dictionary = {} # Dictionary[Vector2i, HexTile]

func _ready() -> void:
	generate_grid(grid_radius)
	_link_neighbors()

func generate_grid(radius: int) -> void:
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) <= radius:
				var tile: HexTile = tile_scene.instantiate()
				var pos = _axial_to_world(q, r)
				tile.transform.origin = pos
				add_child(tile)
				tiles[Vector2i(q, r)] = tile

func _axial_to_world(q: int, r: int) -> Vector3:
	# Flat-top hexagon math
	# R = 1.0 (outer radius)
	var x = 1.5 * q
	var z = sqrt(3.0) * (r + q / 2.0)
	return Vector3(x, 0, z)

func _link_neighbors() -> void:
	var offsets = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	for coord in tiles:
		var tile = tiles[coord]
		for offset in offsets:
			var neighbor_coord = coord + offset
			if tiles.has(neighbor_coord):
				tile.neighbors.append(tiles[neighbor_coord])

func get_tile_at_world_pos(world_pos: Vector3) -> HexTile:
	# Simplified: just find nearest tile
	var closest_tile: HexTile = null
	var min_dist = 1e9
	for tile in tiles.values():
		var dist = tile.global_position.distance_to(world_pos)
		if dist < min_dist:
			min_dist = dist
			closest_tile = tile
	
	if min_dist < 1.0: # Close enough to be on the tile
		return closest_tile
	return null
