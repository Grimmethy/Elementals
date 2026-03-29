extends VBoxContainer

var arena: ArenaGrid
@onready var debug_checkbox: CheckBox = $DebugCheckBox
@onready var debug_label: Label = $TileCountLabel

func _ready() -> void:
	# Find the ArenaGrid in the scene
	arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		# Fallback: search parents
		var parent = get_parent()
		while parent:
			if parent is ArenaGrid:
				arena = parent
				break
			parent = parent.get_parent()

func _process(_delta: float) -> void:
	_update_debug_info()

func _update_debug_info() -> void:
	if not debug_checkbox or not debug_label or not arena:
		return
		
	HexTile.debug_enabled = debug_checkbox.button_pressed
	if not debug_checkbox.button_pressed:
		debug_label.visible = false
		return
		
	debug_label.visible = true
	var counts = {}
	var state_names = {
		HexTile.State.GRASS: "Grass",
		HexTile.State.DIRT: "Dirt",
		HexTile.State.MUD: "Mud",
		HexTile.State.PUDDLE: "Puddle",
		HexTile.State.FIRE: "Fire",
		HexTile.State.STONE: "Stone",
		HexTile.State.TREE: "Tree",
		HexTile.State.BURNING_TREE: "Burning Tree",
		HexTile.State.STUMP: "Stump",
		HexTile.State.BURNT_STUMP: "Burnt Stump",
		HexTile.State.BURNING_BURNT_STUMP: "Burning Burnt Stump"
	}
	
	for state in state_names.keys():
		counts[state] = 0
	
	for row in arena.tile_grid:
		for tile in row:
			if is_instance_valid(tile):
				if tile.current_state in counts:
					counts[tile.current_state] += 1
				else:
					counts[tile.current_state] = 1
					if not tile.current_state in state_names:
						state_names[tile.current_state] = "Unknown (%d)" % tile.current_state
	
	var sorted_counts = []
	for state in counts.keys():
		sorted_counts.append({"name": state_names[state], "count": counts[state]})
	
	sorted_counts.sort_custom(func(a, b): return a.count > b.count)
				
	var text = "Tile Counts:\n"
	for item in sorted_counts:
		text += "%s: %d\n" % [item.name, item.count]
	
	debug_label.text = text
