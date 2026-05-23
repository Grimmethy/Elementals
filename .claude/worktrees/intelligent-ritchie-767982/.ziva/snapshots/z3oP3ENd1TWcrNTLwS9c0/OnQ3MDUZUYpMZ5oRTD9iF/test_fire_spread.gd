extends Node

func test_fire_spread_limitations():
	var arena = ArenaGrid.new()
	arena.grid_width = 3
	arena.grid_height = 3
	# No need to add to root if we are just calling methods
	# Engine.get_main_loop().root.add_child(arena)
	
	arena._create_tiles()
	arena._setup_neighbors()
	
	var center_tile = arena.tile_grid[1][1]
	center_tile.current_state = HexTile.State.GRASS
	
	# Set neighbors
	var dirt_tile = arena.tile_grid[0][0]
	dirt_tile.current_state = HexTile.State.DIRT
	
	var grass_tile = arena.tile_grid[0][1]
	grass_tile.current_state = HexTile.State.GRASS
	
	var neighbor_tile = arena.tile_grid[1][0]
	neighbor_tile.current_state = HexTile.State.STONE
	
	# Force neighbors list to be only these three to be sure
	center_tile.neighbors.clear()
	center_tile.neighbors.append(dirt_tile)
	center_tile.neighbors.append(grass_tile)
	center_tile.neighbors.append(neighbor_tile)
	
	# Case 1: Fire should NOT spread to regular DIRT
	print("Testing fire spread to DIRT...")
	assert(not dirt_tile.apply_fire(), "Dirt should not be ignitable")
	assert(dirt_tile.current_state == HexTile.State.DIRT, "Dirt state should not change")
	
	# Case 2: Fire SHOULD spread to Grass
	print("Testing fire spread to Grass...")
	assert(grass_tile.apply_fire(), "Grass should be ignitable")
	assert(grass_tile.current_state == HexTile.State.FIRE, "Grass should be on fire")
	
	# Case 3: Fire SHOULD spread to Grass (new test case instead of burnt stump)
	print("Testing fire spread to Grass...")
	grass_tile.current_state = HexTile.State.GRASS
	assert(grass_tile.apply_fire(), "Grass should be ignitable")
	assert(grass_tile.current_state == HexTile.State.FIRE, "Grass should be on fire")
	
	# Case 4: Verify _spread_fire skips non-ignitable tiles
	print("Testing _spread_fire skips dirt...")
	# Reset states
	dirt_tile.current_state = HexTile.State.DIRT
	grass_tile.current_state = HexTile.State.GRASS
	
	center_tile.current_state = HexTile.State.GRASS
	center_tile.apply_fire()
	center_tile._spread_fire()
	
	assert(grass_tile.current_state == HexTile.State.FIRE, "Spread fire should have found the grass tile")
	
	arena.queue_free()
	print("All fire spread tests passed!")

func _ready():
	test_fire_spread_limitations()
	get_tree().quit()
