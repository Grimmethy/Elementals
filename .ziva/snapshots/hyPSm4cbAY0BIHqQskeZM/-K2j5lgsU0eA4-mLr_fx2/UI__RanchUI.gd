class_name RanchUI
extends Control

@onready var does_container: VBoxContainer = %DoesContainer
@onready var bucks_container: VBoxContainer = %BucksContainer
@onready var selected_doe_card: Control = %SelectedDoeCard
@onready var selected_buck_card: Control = %SelectedBuckCard
@onready var breed_button: Button = %BreedButton
@onready var next_day_button: Button = %NextDayButton
@onready var close_button: Button = get_node_or_null("MarginContainer/HBoxContainer/ActionCenter/CloseButton")
@onready var gold_label: Label = %GoldLabel
@onready var day_label: Label = %DayLabel

var selected_doe: GoatData
var selected_buck: GoatData

func _ready() -> void:
	GoatManager.herd_updated.connect(refresh_ui)
	GoatManager.day_advanced.connect(_on_day_advanced)
	GoatManager.gold_changed.connect(_on_gold_changed)
	
	breed_button.pressed.connect(_on_breed_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)
	if close_button:
		close_button.text = "CLOSE"
		close_button.pressed.connect(toggle)
	
	refresh_ui()
	_on_gold_changed(GoatManager.gold)
	_on_day_advanced(GoatManager.current_day)

func refresh_ui() -> void:
	_clear_containers()
	
	for goat in GoatManager.herd:
		var card = preload("res://UI/GoatCard.tscn").instantiate()
		card.goat_data = goat
		card.selected.connect(_on_goat_selected)
		
		if goat.gender == GoatData.Gender.DOE:
			does_container.add_child(card)
		else:
			bucks_container.add_child(card)
	
	_update_breeding_selection()

func _clear_containers() -> void:
	for child in does_container.get_children():
		child.queue_free()
	for child in bucks_container.get_children():
		child.queue_free()

func _on_goat_selected(goat: GoatData) -> void:
	if goat.gender == GoatData.Gender.DOE:
		selected_doe = goat
	else:
		selected_buck = goat
	_update_breeding_selection()

func _update_breeding_selection() -> void:
	# Clear previous
	for child in selected_doe_card.get_children(): child.queue_free()
	for child in selected_buck_card.get_children(): child.queue_free()
	
	if selected_doe:
		var card = preload("res://UI/GoatCard.tscn").instantiate()
		card.goat_data = selected_doe
		selected_doe_card.add_child(card)
		
	if selected_buck:
		var card = preload("res://UI/GoatCard.tscn").instantiate()
		card.goat_data = selected_buck
		selected_buck_card.add_child(card)
	
	breed_button.disabled = not (selected_doe and selected_buck)

func _on_breed_pressed() -> void:
	if GoatManager.breed_goats(selected_doe, selected_buck):
		# Success! Clear selection or just refresh
		selected_doe = null
		selected_buck = null
		refresh_ui()

func _on_next_day_pressed() -> void:
	GoatManager.next_day()

func _on_day_advanced(day: int) -> void:
	day_label.text = "Day: %d" % day

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func toggle() -> void:
	visible = !visible
	get_tree().paused = visible
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		refresh_ui()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
