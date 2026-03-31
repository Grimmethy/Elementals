extends VBoxContainer

var arena: ArenaGrid
@onready var debug_checkbox: CheckBox = $DebugCheckBox
@onready var debug_label: Label = $TileCountLabel

var spawn_buttons_container: HBoxContainer

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
	
	_setup_spawn_buttons()

func _setup_spawn_buttons() -> void:
	spawn_buttons_container = HBoxContainer.new()
	add_child(spawn_buttons_container)
	# Reorder so it's after checkbox but before label
	move_child(spawn_buttons_container, 1)
	
	var fire_btn = Button.new()
	fire_btn.text = "Spawn Fire"
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.pressed.connect(func(): if arena: arena.spawn_elemental("fire"))
	spawn_buttons_container.add_child(fire_btn)
	
	var water_btn = Button.new()
	water_btn.text = "Spawn Water"
	water_btn.focus_mode = Control.FOCUS_NONE
	water_btn.pressed.connect(func(): if arena: arena.spawn_elemental("water"))
	spawn_buttons_container.add_child(water_btn)
	
	var goat_btn = Button.new()
	goat_btn.text = "Spawn Goat"
	goat_btn.focus_mode = Control.FOCUS_NONE
	goat_btn.pressed.connect(func(): if arena: arena.spawn_elemental("goat"))
	spawn_buttons_container.add_child(goat_btn)

func _process(_delta: float) -> void:
	_update_debug_info()

func _update_debug_info() -> void:
	if not debug_checkbox or not debug_label or not arena:
		return
		
	HexTile.debug_enabled = debug_checkbox.button_pressed
	
	if spawn_buttons_container:
		spawn_buttons_container.visible = debug_checkbox.button_pressed
		
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
