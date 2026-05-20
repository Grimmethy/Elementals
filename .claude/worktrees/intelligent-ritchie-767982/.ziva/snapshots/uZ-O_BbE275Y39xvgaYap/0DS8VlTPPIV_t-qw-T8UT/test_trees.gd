extends Node

func test_tree_transitions():
	var tile = preload("res://Play Space/hex_tile.tscn").instantiate()
	assert(tile.current_state == 0) # GRASS
	tile.current_state = 6 # TREE
	tile.apply_fire()
	assert(tile.current_state == 7) # BURNING_TREE
	
	# Simulate 10 seconds of burning
	tile._process(10.1)
	assert(tile.current_state == 9) # BURNT_STUMP
	
	# Watering burnt stump -> STUMP
	tile.apply_water()
	assert(tile.current_state == 8) # STUMP
	
	# Simulate 10 seconds of regrowth
	tile._process(10.1)
	assert(tile.current_state == 6) # TREE
	
	tile.queue_free()
	print("Test passed!")
