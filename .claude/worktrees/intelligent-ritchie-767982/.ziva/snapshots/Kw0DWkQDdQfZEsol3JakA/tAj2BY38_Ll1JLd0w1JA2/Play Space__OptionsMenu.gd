class_name OptionsMenu
extends Control

@onready var return_to_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var goat_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/GoatColorContainer/GoatColorSlider

func _ready() -> void:
	hide()
	process_mode = PROCESS_MODE_ALWAYS
	
	if return_to_menu_button:
		return_to_menu_button.pressed.connect(_on_return_pressed)
	if close_button:
		close_button.pressed.connect(toggle)
	if goat_slider:
		goat_slider.value_changed.connect(_on_goat_slider_changed)

func toggle() -> void:
	visible = !visible
	get_tree().paused = visible
	
	var reticle_layer = get_tree().root.find_child("ReticleLayer", true, false)
	if reticle_layer:
		reticle_layer.visible = !visible
	
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_update_slider_visibility()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _update_slider_visibility() -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and "current_controlled_elemental" in arena:
		var target = arena.current_controlled_elemental
		$PanelContainer/MarginContainer/VBoxContainer/GoatColorContainer.visible = (target and target.name.to_lower().contains("goat"))

func _on_goat_slider_changed(value: float) -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and "current_controlled_elemental" in arena:
		var target = arena.current_controlled_elemental
		if target:
			var gc = target.get_node_or_null("GeneticComponent")
			if gc and gc.goat_data:
				gc.goat_data.base_color = Color.from_hsv(value, 0.6, 1.0)

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
