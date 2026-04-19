class_name HerdComponent
extends Node

signal herd_state_changed

var herd: Array[GoatData] = []
const MAX_TEAM_SIZE = 4

func initialize(initial_herd: Array[GoatData]) -> void:
	herd = initial_herd
	for goat in herd:
		goat.is_selected = false
		_connect_goat_signals(goat)

func add_goat(goat: GoatData) -> void:
	herd.append(goat)
	_connect_goat_signals(goat)
	GameEvents.herd_updated.emit()
	herd_state_changed.emit()

func remove_goat(goat: GoatData) -> void:
	herd.erase(goat)
	GameEvents.herd_updated.emit()
	herd_state_changed.emit()

func toggle_selection(goat: GoatData) -> bool:
	if goat.is_selected:
		goat.is_selected = false
		GameEvents.goat_selection_toggled.emit(goat, false)
		GameEvents.herd_updated.emit()
		herd_state_changed.emit()
		return true
	
	if goat.is_exhausted:
		return false
		
	var selected = get_selected_goats()
	if selected.size() < MAX_TEAM_SIZE:
		goat.is_selected = true
		GameEvents.goat_selection_toggled.emit(goat, true)
		GameEvents.herd_updated.emit()
		herd_state_changed.emit()
		return true
		
	return false

func get_selected_goats() -> Array[GoatData]:
	var selected: Array[GoatData] = []
	for g in herd:
		if g.is_selected:
			selected.append(g)
	return selected

func _connect_goat_signals(goat: GoatData) -> void:
	if not goat.stats_changed.is_connected(_on_goat_stats_changed):
		goat.stats_changed.connect(_on_goat_stats_changed)

func _on_goat_stats_changed() -> void:
	herd_state_changed.emit()

func generate_starter_herd() -> void:
	var names = ["Bessie", "Billy", "Daisy", "Gurt"]
	for i in range(4):
		var goat = GoatData.new()
		goat.goat_name = names[i]
		goat.gender = GoatData.Gender.DOE if i % 2 == 0 else GoatData.Gender.BUCK
		goat.base_color = Color(randf(), randf(), randf())
		add_goat(goat)
