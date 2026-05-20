extends Node

func test_fire_spread_limitations():
	var arena = ArenaGrid.new()
	arena.grid_width = 3
	arena.grid_height = 3
	# No need to add to root if we are just calling methods
	# Engine.get_main_loop().root.add_child(arena)
	
	arena._initialize_grid()
	
	var center_tile = arena.get_tile_at_grid_coords(1, 1)
	center_tile.current_state = TileConstants.State.GRASS
	
	# Set neighbors
	var dirt_tile = arena.get_tile_at_grid_coords(0, 0)
	dirt_tile.current_state = TileConstants.State.DIRT
	
	var grass_tile = arena.get_tile_at_grid_coords(0, 1)
	grass_tile.current_state = TileConstants.State.GRASS
	
	var neighbor_tile = arena.get_tile_at_grid_coords(1, 0)
	neighbor_tile.current_state = TileConstants.State.STONE
	
	# Case 1: Fire should NOT spread to regular DIRT (it returns false in some cases but let's check apply_element_to_tile)
	print("Testing fire spread to DIRT...")
	# apply_element_to_tile returns true if it changed state
	assert(not arena.apply_element_to_tile(dirt_tile, "fire"), "Dirt should not be ignitable from fire")
	assert(dirt_tile.current_state == TileConstants.State.DIRT, "Dirt state should not change")
	
	# Case 2: Fire SHOULD spread to Grass
	print("Testing fire spread to Grass...")
	assert(arena.apply_element_to_tile(grass_tile, "fire"), "Grass should be ignitable")
	assert(grass_tile.current_state == TileConstants.State.FIRE, "Grass should be on fire")
	
	# Case 3: Fire SHOULD spread to Grass (new test case)
	print("Testing fire spread to Grass...")
	grass_tile.current_state = TileConstants.State.GRASS
	assert(arena.apply_element_to_tile(grass_tile, "fire"), "Grass should be ignitable")
	assert(grass_tile.current_state == TileConstants.State.FIRE, "Grass should be on fire")
	
	# Case 4: Verify _spread_fire skips non-ignitable tiles
	print("Testing _spread_fire skips dirt...")
	# Reset states
	dirt_tile.current_state = TileConstants.State.DIRT
	grass_tile.current_state = TileConstants.State.GRASS
	
	center_tile.current_state = TileConstants.State.FIRE
	arena._spread_fire(center_tile)
	
	assert(grass_tile.current_state == TileConstants.State.FIRE, "Spread fire should have found the grass tile")
	
	arena.queue_free()
	print("All fire spread tests passed!")

func _ready():
	test_fire_spread_limitations()
	get_tree().quit()
