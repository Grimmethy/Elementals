extends Control

@onready var fire_button: Button = $CenterContainer/VBoxContainer/ElementalSelection/HBoxContainer/FireButton
@onready var water_button: Button = $CenterContainer/VBoxContainer/ElementalSelection/HBoxContainer/WaterButton
@onready var goat_button: Button = $CenterContainer/VBoxContainer/ElementalSelection/HBoxContainer/GoatButton
@onready var size_input: SpinBox = $CenterContainer/VBoxContainer/ArenaSize/SizeInput
@onready var fire_count_input: SpinBox = $CenterContainer/VBoxContainer/NPCSelection/FireNPCs/FireCount
@onready var water_count_input: SpinBox = $CenterContainer/VBoxContainer/NPCSelection/WaterNPCs/WaterCount
@onready var goat_count_input: SpinBox = $CenterContainer/VBoxContainer/NPCSelection/GoatNPCs/GoatCount

@onready var seed_input: SpinBox = $CenterContainer/VBoxContainer/WorldGen/NoiseSeed/SeedInput
@onready var scale_slider: HSlider = $CenterContainer/VBoxContainer/WorldGen/NoiseScale/ScaleSlider
@onready var height_slider: HSlider = $CenterContainer/VBoxContainer/WorldGen/HeightStep/HeightSlider

func _ready() -> void:
	# Initialize values from GameSettings
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		size_input.value = gs.grid_width
		fire_count_input.value = gs.fire_count
		water_count_input.value = gs.water_count
		goat_count_input.value = gs.goat_count
		
		seed_input.value = gs.noise_seed
		scale_slider.value = gs.noise_frequency
		height_slider.value = gs.height_step
		
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
		gs.fire_count = int(fire_count_input.value)
		gs.water_count = int(water_count_input.value)
		gs.goat_count = int(goat_count_input.value)
		
		gs.noise_seed = int(seed_input.value)
		gs.noise_frequency = scale_slider.value
		gs.height_step = height_slider.value
		
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")
