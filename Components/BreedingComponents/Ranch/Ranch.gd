class_name Ranch
extends Control

@onready var does_container: GridContainer = %DoesContainer
@onready var bucks_container: GridContainer = %BucksContainer
@onready var selected_doe_card: Control = %SelectedDoeCard
@onready var selected_buck_card: Control = %SelectedBuckCard
@onready var breed_button: Button = %BreedButton
@onready var next_day_button: Button = %NextDayButton
@onready var back_button: Button = %BackButton
@onready var gold_label: Label = %GoldLabel
@onready var day_label: Label = %DayLabel
@onready var cheat_button: Button = %CheatButton
@onready var cheat_panel: Control = %CheatPanel
@onready var max_level_goat_button: Button = %MaxLevelGoatButton
@onready var spawn_mimic_button: Button = %SpawnMimicButton
@onready var spawn_mushroom_button: Button = %SpawnMushroomButton
@onready var spawn_goblin_button: Button = %SpawnGoblinButton
@onready var complete_all_pregnancies_button: Button = %CompleteAllPregnanciesButton
@onready var clear_herd_button: Button = %ClearHerdButton
@onready var close_cheat_button: Button = %CloseCheatButton

## Now typed as ActorData (was GoatData) — the breeding flow accepts any
## ActorData subclass thanks to polymorphic create_offspring + add_goat.
var selected_doe: ActorData
var selected_buck: ActorData

## Polymorphic display-name lookup matching ActorCard's logic. GoatData uses
## goat_name; MimicData / MushroomData / GoblinData use creature_name.
func _display_name_of(actor: ActorData) -> String:
	if actor == null:
		return ""
	if "goat_name" in actor:
		return String(actor.goat_name)
	if "creature_name" in actor:
		return String(actor.creature_name)
	return actor.get_actor_type()

func _ready() -> void:
	GameEvents.herd_updated.connect(refresh_ui)
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.gold_changed.connect(_on_gold_changed)
	
	breed_button.pressed.connect(_on_breed_pressed)
	next_day_button.text = "Enter Arena"
	next_day_button.pressed.connect(_on_enter_arena_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	cheat_button.pressed.connect(func(): cheat_panel.visible = true)
	close_cheat_button.pressed.connect(func(): cheat_panel.visible = false)
	max_level_goat_button.pressed.connect(_on_max_level_goat_pressed)
	if spawn_mimic_button:
		spawn_mimic_button.pressed.connect(_on_spawn_mimic_pressed)
	if spawn_mushroom_button:
		spawn_mushroom_button.pressed.connect(_on_spawn_mushroom_pressed)
	if spawn_goblin_button:
		spawn_goblin_button.pressed.connect(_on_spawn_goblin_pressed)
	if complete_all_pregnancies_button:
		complete_all_pregnancies_button.pressed.connect(_on_complete_all_pregnancies_pressed)
	if clear_herd_button:
		clear_herd_button.pressed.connect(_on_clear_herd_pressed)
	
	refresh_ui()
	_on_gold_changed(HerdManager.gold)
	_on_day_advanced(HerdManager.current_day)
	
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func refresh_ui() -> void:
	_clear_containers()

	# Sort herd by display name for stability. Use polymorphic name lookup so
	# non-Goat herd members (Mimic / Mushroom / Goblin from the cheat menu,
	# or hybrid offspring) sort cleanly alongside goats.
	var sorted_herd = HerdManager.herd.duplicate()
	sorted_herd.sort_custom(func(a, b):
		return _display_name_of(a) < _display_name_of(b)
	)
	
	for goat in sorted_herd:
		var card = preload("res://UI/DisplayCard/ActorCard.tscn").instantiate()
		card.goat_data = goat
		card.selected.connect(_on_goat_selected)
		
		if goat.gender == ActorData.Gender.FEMALE:
			does_container.add_child(card)
		else:
			bucks_container.add_child(card)
	
	_update_breeding_selection()

func _clear_containers() -> void:
	for child in does_container.get_children():
		child.queue_free()
	for child in bucks_container.get_children():
		child.queue_free()
	for child in selected_doe_card.get_children():
		child.queue_free()
	for child in selected_buck_card.get_children():
		child.queue_free()

func _on_goat_selected(goat: ActorData) -> void:
	if goat.gender == ActorData.Gender.FEMALE:
		if selected_doe == goat:
			selected_doe = null
		else:
			selected_doe = goat
	else:
		if selected_buck == goat:
			selected_buck = null
		else:
			selected_buck = goat
	refresh_ui()

func _update_breeding_selection() -> void:
	if selected_doe:
		var card = preload("res://UI/DisplayCard/ActorCard.tscn").instantiate()
		card.goat_data = selected_doe
		selected_doe_card.add_child(card)
		
	if selected_buck:
		var card = preload("res://UI/DisplayCard/ActorCard.tscn").instantiate()
		card.goat_data = selected_buck
		selected_buck_card.add_child(card)
	
	breed_button.disabled = not (selected_doe and selected_buck)
	
	var selected = HerdManager.get_selected_goats()
	# next_day_button.disabled = selected.is_empty() # Allow entering without goats
	# Accessing MAX_TEAM_SIZE from HerdManager autoload instance
	next_day_button.text = "Enter Arena (%d/%d)" % [selected.size(), HerdManager.MAX_TEAM_SIZE]

func _on_enter_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")

func _on_breed_pressed() -> void:
	if HerdManager.breed(selected_doe, selected_buck):
		selected_doe = null
		selected_buck = null
		refresh_ui()

func _on_next_day_pressed() -> void:
	HerdManager.next_day()

func _on_day_advanced(day: int) -> void:
	day_label.text = "Day: %d" % day

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_max_level_goat_pressed() -> void:
	var max_goat = GoatData.new()
	# Keep the generated fantasy name from _init but tag it as "Mega" so
	# cheat-spawned max-level units are still identifiable in the herd.
	max_goat.goat_name = "Mega " + max_goat.goat_name
	max_goat.level = 20
	max_goat.gender = ActorData.Gender.MALE if randf() < 0.5 else ActorData.Gender.FEMALE
	max_goat.strength = 20.0
	max_goat.dexterity = 20.0
	max_goat.constitution = 20.0
	max_goat.intelligence = 20.0
	max_goat.wisdom = 20.0
	max_goat.charisma = 20.0
	
	HerdManager.add_goat(max_goat)
	cheat_panel.visible = false
	refresh_ui()

func _on_complete_all_pregnancies_pressed() -> void:
	# Force every pregnant herd member to deliver on the next next_day() tick by
	# clamping pregnancy_timer to 1, then advancing one day so the breeding
	# manager's process_pregnancy decrements it to 0 and spawns the kid via the
	# normal polymorphic path (preserves mimic_blood + hybrid skill rolls).
	var pregnant_count: int = 0
	for actor in HerdManager.herd:
		if actor is ActorData and actor.is_pregnant:
			actor.pregnancy_timer = 1
			pregnant_count += 1
	if pregnant_count == 0:
		print("[Cheat] No pregnancies to complete.")
		cheat_panel.visible = false
		return
	print("[Cheat] Completing %d pregnancies via next_day()." % pregnant_count)
	HerdManager.next_day()
	cheat_panel.visible = false
	refresh_ui()

func _on_spawn_mimic_pressed() -> void:
	var mimic := MimicData.new()
	# Generator already gave it a fantasy name in _init; mark as max-level.
	mimic.creature_name = "Mega " + mimic.creature_name
	mimic.level = 20
	mimic.gender = ActorData.Gender.MALE if randf() < 0.5 else ActorData.Gender.FEMALE
	mimic.strength = 20.0
	mimic.dexterity = 20.0
	mimic.constitution = 20.0
	mimic.intelligence = 20.0
	mimic.wisdom = 20.0
	mimic.charisma = 20.0
	# Roll a fresh genome so the cheat-spawned mimic isn't the default chest.
	mimic.randomize_genome()
	HerdManager.add_goat(mimic)
	print("[Cheat] Spawned max-level Mimic (%s)." % String(mimic.genome.get("body", {}).get("shape", "?")))
	cheat_panel.visible = false
	refresh_ui()

func _on_spawn_mushroom_pressed() -> void:
	var mushroom := MushroomData.new()
	mushroom.creature_name = "Mega " + mushroom.creature_name
	mushroom.level = 20
	mushroom.gender = ActorData.Gender.MALE if randf() < 0.5 else ActorData.Gender.FEMALE
	mushroom.strength = 20.0
	mushroom.dexterity = 20.0
	mushroom.constitution = 20.0
	mushroom.intelligence = 20.0
	mushroom.wisdom = 20.0
	mushroom.charisma = 20.0
	# Roll a fresh genome so each spawned mushroom has unique cap/spots/etc.
	mushroom.randomize()
	HerdManager.add_goat(mushroom)
	print("[Cheat] Spawned max-level Mushroom.")
	cheat_panel.visible = false
	refresh_ui()

func _on_spawn_goblin_pressed() -> void:
	var goblin := GoblinData.new()
	goblin.creature_name = "Mega " + goblin.creature_name
	goblin.level = 20
	goblin.gender = ActorData.Gender.MALE if randf() < 0.5 else ActorData.Gender.FEMALE
	goblin.strength = 20.0
	goblin.dexterity = 20.0
	goblin.constitution = 20.0
	goblin.intelligence = 20.0
	goblin.wisdom = 20.0
	goblin.charisma = 20.0
	HerdManager.add_goat(goblin)
	print("[Cheat] Spawned max-level Goblin.")
	cheat_panel.visible = false
	refresh_ui()

func _on_clear_herd_pressed() -> void:
	# Duplicate the herd snapshot first — remove_goat mutates the underlying
	# Array, so iterating the live herd would skip entries.
	var snapshot: Array = HerdManager.herd.duplicate()
	var removed: int = 0
	for actor in snapshot:
		if actor == null:
			continue
		HerdManager.remove_goat(actor)
		removed += 1
	# Drop any stale breeding selections — those references now point to freed data.
	selected_doe = null
	selected_buck = null
	print("[Cheat] Cleared %d creature(s) from the herd." % removed)
	cheat_panel.visible = false
	refresh_ui()
