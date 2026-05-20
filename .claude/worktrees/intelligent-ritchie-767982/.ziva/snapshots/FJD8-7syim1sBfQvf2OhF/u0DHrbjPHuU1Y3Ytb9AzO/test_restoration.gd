extends Node

func test_tree_recovery():
	var arena = ArenaGrid.new()
	arena.grid_width = 5
	arena.grid_height = 5
	# Add to tree to avoid issues with parent/child in test
	Engine.get_main_loop().root.add_child(arena)
	
	arena._create_tiles()
	arena._setup_neighbors()
	
	var grass_tile = null
	for row in arena.tile_grid:
		for tile in row:
			if tile.current_state == HexTile.State.GRASS:
				grass_tile = tile
				break
		if grass_tile: break
	
	if not grass_tile:
		print("No grass tile found for test")
		return
		
	# 1. Start as Tree
	grass_tile.current_state = HexTile.State.TREE
	assert(grass_tile.tile_subtype == HexTile.SubType.TREE)
	print("Tree setup ok")
	
	# 2. Apply fire
	grass_tile.apply_fire()
	assert(grass_tile.current_state == HexTile.State.BURNING_TREE)
	print("Burning Tree ok")
	
	# 3. Wait for burn (5s) - we simulate it
	grass_tile._process(5.1)
	assert(grass_tile.current_state == HexTile.State.BURNT_STUMP)
	print("Burnt Stump ok")
	
	# 4. Apply water
	grass_tile.apply_water()
	assert(grass_tile.current_state == HexTile.State.STUMP)
	print("Water to Stump ok")
	
	# 5. Wait for regrowth (10s)
	grass_tile._process(10.1)
	assert(grass_tile.current_state == HexTile.State.TREE)
	print("Regrowth to Tree ok")
	
	arena.queue_free()
	print("All tests passed!")

func _ready():
	test_tree_recovery()
	get_tree().quit()
