class_name GoatCard
extends PanelContainer

signal selected(goat: GoatData)

@onready var renderer: GoatRenderer = $VBoxContainer/GoatRenderer
@onready var name_edit: LineEdit = $VBoxContainer/TopRow/NameEdit
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var arena_checkbox: CheckBox = $VBoxContainer/ArenaCheckBox

var goat_data: GoatData:
	set(v):
		if goat_data:
			if goat_data.stats_changed.is_connected(_update_ui):
				goat_data.stats_changed.disconnect(_update_ui)
		goat_data = v
		if goat_data:
			goat_data.stats_changed.connect(_update_ui)
		if is_node_ready():
			_update_ui()

func _ready() -> void:
	_update_ui()
	arena_checkbox.toggled.connect(_on_arena_toggled)
	gui_input.connect(_on_gui_input)
	
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)

func _update_ui() -> void:
	if not goat_data or not is_node_ready(): return
	renderer.goat_data = goat_data
	
	if not name_edit.has_focus():
		name_edit.text = goat_data.goat_name
	
	var gender_str = "Doe" if goat_data.gender == GoatData.Gender.DOE else "Buck"
	var preg_str = " (Pregnant)" if goat_data.is_pregnant else ""
	var exh_str = " (Exhausted)" if goat_data.is_exhausted else ""
	
	stats_label.text = "%s - Age: %d%s%s\nStrength: %.1f\nToughness: %.1f\nSpeed: %.1f" % [
		gender_str, goat_data.age_days, preg_str, exh_str,
		goat_data.strength, goat_data.toughness, goat_data.speed
	]
	
	arena_checkbox.button_pressed = goat_data.is_selected
	arena_checkbox.disabled = goat_data.is_exhausted and not goat_data.is_selected
	
	# Visual feedback for exhaustion
	modulate = Color(0.7, 0.7, 0.7) if goat_data.is_exhausted else Color.WHITE
	if goat_data.is_selected:
		modulate = Color(0.8, 1.0, 0.8) # Greenish tint for selected

func _on_arena_toggled(pressed: bool) -> void:
	if not goat_data: return
	if pressed != goat_data.is_selected:
		_toggle_arena_selection()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_arena_selection()
		selected.emit(goat_data)
		accept_event()

func _toggle_arena_selection() -> void:
	if has_node("/root/GoatManager"):
		get_node("/root/GoatManager").toggle_selection(goat_data)

func _on_name_submitted(new_text: String) -> void:
	if goat_data:
		goat_data.goat_name = new_text
	name_edit.release_focus()

func _on_name_focus_exited() -> void:
	if goat_data:
		goat_data.goat_name = name_edit.text
