class_name OptionsMenu
extends Control

@onready var return_to_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	hide()
	process_mode = PROCESS_MODE_ALWAYS
	
	if return_to_menu_button:
		return_to_menu_button.pressed.connect(_on_return_pressed)
	if close_button:
		close_button.pressed.connect(toggle)

func toggle() -> void:
	visible = !visible
	get_tree().paused = visible
	
	var reticle_layer = get_tree().root.find_child("ReticleLayer", true, false)
	if reticle_layer:
		reticle_layer.visible = !visible
	
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
