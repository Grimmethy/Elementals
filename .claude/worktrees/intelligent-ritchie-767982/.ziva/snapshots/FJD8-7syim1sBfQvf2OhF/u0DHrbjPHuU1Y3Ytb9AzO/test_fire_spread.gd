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
	
	var burnt_stump_tile = arena.tile_grid[1][0]
	burnt_stump_tile.current_state = HexTile.State.BURNT_STUMP
	
	# Force neighbors list to be only these three to be sure
	center_tile.neighbors.clear()
	center_tile.neighbors.append(dirt_tile)
	center_tile.neighbors.append(grass_tile)
	center_tile.neighbors.append(burnt_stump_tile)
	
	# Case 1: Fire should NOT spread to regular DIRT
	print("Testing fire spread to DIRT...")
	assert(not dirt_tile.apply_fire(), "Dirt should not be ignitable")
	assert(dirt_tile.current_state == HexTile.State.DIRT, "Dirt state should not change")
	
	# Case 2: Fire SHOULD spread to Grass
	print("Testing fire spread to Grass...")
	assert(grass_tile.apply_fire(), "Grass should be ignitable")
	assert(grass_tile.current_state == HexTile.State.FIRE, "Grass should be on fire")
	
	# Case 3: Fire SHOULD spread to Burnt Stump
	print("Testing fire spread to Burnt Stump...")
	assert(burnt_stump_tile.apply_fire(), "Burnt Stump should be ignitable")
	assert(burnt_stump_tile.current_state == HexTile.State.BURNING_BURNT_STUMP, "Burnt Stump should be on fire")
	
	# Case 4: Verify _spread_fire skips non-ignitable tiles
	print("Testing _spread_fire skips dirt...")
	# Reset states
	dirt_tile.current_state = HexTile.State.DIRT
	grass_tile.current_state = HexTile.State.GRASS
	burnt_stump_tile.current_state = HexTile.State.DIRT # Make this non-ignitable too
	
	center_tile.apply_fire()
	center_tile._spread_fire() # This shuffles and tries to ignite one neighbor
	
	# Since dirt is not ignitable, it should either ignite grass_tile OR do nothing if it picked only dirt tiles and they all failed.
	# Actually, _spread_fire loops through ALL shuffled neighbors and breaks on the FIRST successful ignition.
	# So it SHOULD find grass_tile eventually.
	
	assert(grass_tile.current_state == HexTile.State.FIRE, "Spread fire should have found the grass tile")
	
	arena.queue_free()
	print("All fire spread tests passed!")

func _ready():
	test_fire_spread_limitations()
	get_tree().quit()
