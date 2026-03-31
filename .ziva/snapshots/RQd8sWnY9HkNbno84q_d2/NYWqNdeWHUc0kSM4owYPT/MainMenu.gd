extends Control

@onready var fire_button: Button = $CenterContainer/VBoxContainer/ElementalSelection/HBoxContainer/FireButton
@onready var water_button: Button = $CenterContainer/VBoxContainer/ElementalSelection/HBoxContainer/WaterButton
@onready var goat_button: Button = $CenterContainer/VBoxContainer/ElementalSelection/HBoxContainer/GoatButton
@onready var size_input: SpinBox = $CenterContainer/VBoxContainer/ArenaSize/SizeInput

func _ready() -> void:
	# Initialize values from GameSettings
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		size_input.value = gs.grid_width
		if gs.selected_elemental_type == "fire":
			_on_fire_button_pressed()
		elif gs.selected_elemental_type == "water":
			_on_water_button_pressed()
		else:
			_on_goat_button_pressed()
	
	# Ensure mouse is visible for the menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_fire_button_pressed() -> void:
	fire_button.button_pressed = true
	water_button.button_pressed = false
	goat_button.button_pressed = false
	var gs = get_node_or_null("/root/GameSettings")
	if gs: gs.selected_elemental_type = "fire"

func _on_water_button_pressed() -> void:
	fire_button.button_pressed = false
	water_button.button_pressed = true
	goat_button.button_pressed = false
	var gs = get_node_or_null("/root/GameSettings")
	if gs: gs.selected_elemental_type = "water"

func _on_goat_button_pressed() -> void:
	fire_button.button_pressed = false
	water_button.button_pressed = false
	goat_button.button_pressed = true
	var gs = get_node_or_null("/root/GameSettings")
	if gs: gs.selected_elemental_type = "goat"

func _on_play_button_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.grid_width = int(size_input.value)
		gs.grid_height = int(size_input.value)
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")
