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
		
	if not debug_checkbox.button_pressed:
		debug_label.visible = false
		return
		
	debug_label.visible = true
	var counts = {
		HexTile.State.GRASS: 0,
		HexTile.State.DIRT: 0,
		HexTile.State.MUD: 0,
		HexTile.State.PUDDLE: 0,
		HexTile.State.FIRE: 0,
		HexTile.State.STONE: 0
	}
	
	for row in arena.tile_grid:
		for tile in row:
			if is_instance_valid(tile):
				counts[tile.current_state] += 1
				
	# Sort counts high to low
	var sorted_counts = []
	var state_names = {
		HexTile.State.GRASS: "Grass",
		HexTile.State.DIRT: "Dirt",
		HexTile.State.MUD: "Mud",
		HexTile.State.PUDDLE: "Puddle",
		HexTile.State.FIRE: "Fire",
		HexTile.State.STONE: "Stone"
	}
	
	for state in counts.keys():
		sorted_counts.append({"name": state_names[state], "count": counts[state]})
	
	sorted_counts.sort_custom(func(a, b): return a.count > b.count)
				
	var text = "Tile Counts:\n"
	for item in sorted_counts:
		text += "%s: %d\n" % [item.name, item.count]
	
	debug_label.text = text
