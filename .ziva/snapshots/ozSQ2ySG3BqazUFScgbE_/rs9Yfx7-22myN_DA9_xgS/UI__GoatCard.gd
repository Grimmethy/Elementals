class_name GoatCard
extends PanelContainer

signal selected(goat: GoatData)

@onready var renderer: GoatRenderer = $VBoxContainer/GoatRenderer
@onready var name_edit: LineEdit = $VBoxContainer/NameEdit
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var breed_button: Button = $VBoxContainer/SelectButton

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
	breed_button.pressed.connect(func(): selected.emit(goat_data))
	
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
	
	stats_label.text = "%s - Age: %d%s%s\nS: %.1f T: %.1f V: %.1f" % [
		gender_str, goat_data.age_days, preg_str, exh_str,
		goat_data.strength, goat_data.toughness, goat_data.speed
	]
	
	# Visual feedback for exhaustion
	modulate = Color(0.7, 0.7, 0.7) if goat_data.is_exhausted else Color.WHITE

func _on_name_submitted(new_text: String) -> void:
	if goat_data:
		goat_data.goat_name = new_text
	name_edit.release_focus()

func _on_name_focus_exited() -> void:
	if goat_data:
		goat_data.goat_name = name_edit.text
