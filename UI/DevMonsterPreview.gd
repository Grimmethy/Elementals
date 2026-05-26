class_name DevMonsterPreview
extends Control

## Dev / QA tool — randomly summon ANY of the 600+ monsters in ActorTypeData
## and render them via the universal ProceduralCreatureBody. Cycle through
## one at a time to verify every species/category produces a recognizable
## visual.
##
## Surfaced via a button on HubScreen. NOT exposed to players (it's a
## development tool — name + category labels reveal authoring data).

@onready var viewport: SubViewport = $Panel/HBox/PreviewBox/SubViewport
@onready var creature_container: Node3D = $Panel/HBox/PreviewBox/SubViewport/CreatureContainer
@onready var category_filter: OptionButton = $Panel/HBox/Controls/CategoryFilter
## Species dropdown — jump straight to any creature in the current category
## without having to spam Random / Next. Auto-rebuilt when CategoryFilter
## changes. Selecting a species re-renders immediately.
@onready var species_filter: OptionButton = $Panel/HBox/Controls/SpeciesFilter
@onready var species_label: Label = $Panel/HBox/Controls/SpeciesLabel
@onready var category_label: Label = $Panel/HBox/Controls/CategoryLabel
@onready var seed_label: Label = $Panel/HBox/Controls/SeedLabel
@onready var stats_label: Label = $Panel/HBox/Controls/StatsLabel
@onready var random_btn: Button = $Panel/HBox/Controls/RandomBtn
@onready var next_btn: Button = $Panel/HBox/Controls/NextBtn
@onready var reroll_btn: Button = $Panel/HBox/Controls/RerollBtn
## Stamps the currently-previewed species + body plan into a GoatData and
## drops it in the herd so the player can breed-test the variant they liked.
@onready var keep_btn: Button = $Panel/HBox/Controls/KeepBtn
@onready var keep_feedback: Label = $Panel/HBox/Controls/KeepFeedback
@onready var close_btn: Button = $Panel/HBox/Controls/CloseBtn

var _all_species: Array[String] = []
var _filtered_species: Array[String] = []
var _current_index: int = 0
var _current_seed: int = 0
var _current_body: ProceduralCreatureBody = null
var _selected_category: String = "All"

func _ready() -> void:
	_all_species = ActorTypeData.get_all_types()
	_populate_category_filter()
	_apply_category_filter()
	_populate_species_filter()
	if random_btn:
		random_btn.pressed.connect(_on_random)
	if next_btn:
		next_btn.pressed.connect(_on_next)
	if reroll_btn:
		reroll_btn.pressed.connect(_on_reroll)
	if keep_btn:
		keep_btn.pressed.connect(_on_keep_for_breeding)
	if close_btn:
		close_btn.pressed.connect(_on_close)
	if category_filter:
		category_filter.item_selected.connect(_on_category_changed)
	if species_filter:
		species_filter.item_selected.connect(_on_species_picked)
	# Render the first one immediately.
	_on_random()

func _populate_category_filter() -> void:
	if category_filter == null:
		return
	category_filter.clear()
	category_filter.add_item("All")
	for cat in ActorTypeData.get_all_categories():
		category_filter.add_item(cat)

func _on_category_changed(idx: int) -> void:
	_selected_category = category_filter.get_item_text(idx)
	_apply_category_filter()
	_populate_species_filter()
	_on_random()

func _apply_category_filter() -> void:
	if _selected_category == "All":
		_filtered_species = _all_species.duplicate()
	else:
		_filtered_species = []
		for s in _all_species:
			if ActorTypeData.get_category(s) == _selected_category:
				_filtered_species.append(s)
	_filtered_species.sort()

## Rebuild the species dropdown with the currently filtered species so a user
## can jump straight to e.g. "Pig" without spamming the Random button.
func _populate_species_filter() -> void:
	if species_filter == null:
		return
	species_filter.clear()
	for s in _filtered_species:
		species_filter.add_item(s)
	# Keep the dropdown text in sync with the current creature (if it's still in
	# the filtered list — otherwise default to the first entry).
	if not _filtered_species.is_empty():
		var idx: int = _current_index
		if idx < 0 or idx >= _filtered_species.size():
			idx = 0
		species_filter.select(idx)

## User picked a species from the dropdown — jump to it and re-render.
func _on_species_picked(idx: int) -> void:
	if idx < 0 or idx >= _filtered_species.size():
		return
	_current_index = idx
	_current_seed = randi()
	_render_current()

func _on_random() -> void:
	if _filtered_species.is_empty():
		return
	_current_index = randi() % _filtered_species.size()
	_current_seed = randi()
	_render_current()

func _on_next() -> void:
	if _filtered_species.is_empty():
		return
	_current_index = (_current_index + 1) % _filtered_species.size()
	_current_seed = randi()
	_render_current()

## Re-roll the same species with a fresh seed — useful for seeing how the
## procedural variation looks across multiple rolls of the same monster.
func _on_reroll() -> void:
	if _filtered_species.is_empty():
		return
	_current_seed = randi()
	_render_current()

func _render_current() -> void:
	if _filtered_species.is_empty() or creature_container == null:
		return
	var species: String = _filtered_species[_current_index]
	var category: String = ActorTypeData.get_category(species)
	# Keep the species dropdown selection in sync with whatever was just rendered
	# (so Random/Next still update the dropdown for visual feedback).
	if species_filter and species_filter.item_count > 0 \
			and _current_index >= 0 and _current_index < species_filter.item_count:
		species_filter.select(_current_index)
	# Tear down previous body.
	if is_instance_valid(_current_body):
		_current_body.queue_free()
	# Generate body plan + spawn.
	var plan: Dictionary = ActorBodyPlanGenerator.generate(species, _current_seed)
	_current_body = ProceduralCreatureBody.new()
	_current_body.override_plan = plan
	creature_container.add_child(_current_body)
	# Force rebuild after adding to tree (ensures _ready ran).
	_current_body.rebuild_from_genome(plan)
	# Update labels.
	if species_label:
		species_label.text = "Species: %s   (%d/%d)" % [species, _current_index + 1, _filtered_species.size()]
	if category_label:
		category_label.text = "Category: %s" % category
	if seed_label:
		seed_label.text = "Seed: %d" % _current_seed
	if stats_label:
		var d: Dictionary = ActorTypeData.get_defaults(species)
		stats_label.text = "HP %s · AC %s · STR %.1f DEX %.1f CON %.1f · Capture: %s" % [
			d.get("max_health", "?"),
			d.get("armor_class", "?"),
			float(d.get("strength", 0.0)),
			float(d.get("dexterity", 0.0)),
			float(d.get("constitution", 0.0)),
			ActorTypeData.get_capture_archetype(species),
		]

## "Keep for Breeding" — stamp the current previewed species (its plan + seed
## + stat block) into a GoatData and drop it in the herd so the player can
## bring two of them together in the Ranch to test breeding. We use GoatData
## (rather than the species' own subclass) because the captured-from-wild
## path in HerdManager._build_captured_data established the convention that
## non-goat species ride into the herd as a GoatData with the species' visual
## config stamped on — so this lines up cleanly with breeding/UI code that
## already handles "GoatData carrying foreign-species body plans."
func _on_keep_for_breeding() -> void:
	if _filtered_species.is_empty():
		return
	var species: String = _filtered_species[_current_index]
	var defaults: Dictionary = ActorTypeData.get_defaults(species)
	var data := GoatData.new()
	data.goat_name = "(Dev) " + species
	# Genders alternate by call-count would be confusing; coin-flip per spawn
	# so a player who hits Keep twice has a chance at a breeding pair.
	data.gender = ActorData.Gender.MALE if randf() < 0.5 else ActorData.Gender.FEMALE
	data.is_selected = false
	data.is_exhausted = false
	# Stamp stats from the species' ActorTypeData entry so the kept creature
	# matches the stat block shown in the preview's StatsLabel.
	if not defaults.is_empty():
		data.strength = float(defaults.get("strength", data.strength))
		data.dexterity = float(defaults.get("dexterity", data.dexterity))
		data.constitution = float(defaults.get("constitution", data.constitution))
		data.intelligence = float(defaults.get("intelligence", data.intelligence))
		data.wisdom = float(defaults.get("wisdom", data.wisdom))
		data.charisma = float(defaults.get("charisma", data.charisma))
		var hp_val: Variant = defaults.get("max_health", null)
		if hp_val != null and "max_health" in data:
			data.set("max_health", float(hp_val))
	# Render config — the herd-card / Ranch / arena previews all rebuild from
	# shared_body_plan + render_seed, so copying both makes the kept creature
	# visually identical to what's on screen right now.
	data.render_seed = _current_seed
	if _current_body and _current_body.override_plan is Dictionary \
			and not (_current_body.override_plan as Dictionary).is_empty():
		data.shared_body_plan = (_current_body.override_plan as Dictionary).duplicate(true)
	# Hand it to the herd via the singleton — same path the cheat panel uses.
	HerdManager.add_goat(data)
	# UI feedback — a tiny line under the button so the dev knows it landed
	# (we don't tear down the preview; the user may want to keep several).
	if keep_feedback:
		var gender_marker: String = "♂" if data.gender == ActorData.Gender.MALE else "♀"
		keep_feedback.text = "Added %s %s to herd" % [gender_marker, data.goat_name]
	print("[DevMonsterPreview] Kept %s (seed %d) for breeding." % [species, _current_seed])

func _on_close() -> void:
	queue_free()
