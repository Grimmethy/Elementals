extends Node

func test_tree_recovery():
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		print("Skipping test: No SceneTree")
		return
	var arena = ArenaGrid.new()
	arena.grid_width = 5
	arena.grid_height = 5
	scene_tree.root.add_child(arena)
	
	arena._initialize_grid()
	
	var grass_tile = null
	for tile in arena.tile_data_grid:
		if tile.current_state == TileConstants.State.GRASS:
			grass_tile = tile
			break
	
	if not grass_tile:
		print("No grass tile found for test")
		return
		
	# 1. Start with a TreeFeature
	var tree = load("res://Play Space/tree_feature.tscn").instantiate()
	arena.add_child(tree)
	tree.set_tile(grass_tile)
	grass_tile.feature = tree
	print("Tree setup ok")
	
	# 2. Apply fire
	tree.apply_fire()
	assert(tree.current_state == TreeFeature.State.BURNT_STUMP)
	print("Burnt Stump ok")
	
	# 3. Apply water
	tree.apply_water(Vector3.ZERO)
	assert(tree.current_state == TreeFeature.State.STUMP)
	print("Water to Stump ok")
	
	# 4. Wait for regrowth (10s)
	tree._process(10.1)
	assert(tree.current_state == TreeFeature.State.TREE)
	print("Regrowth to Tree ok")
	
	arena.queue_free()
	print("All tests passed!")

func _ready():
	test_tree_recovery()
	get_tree().quit()
