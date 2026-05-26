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
@onready var category_filter: OptionButton = $Panel/HBox/ControlsScroll/Controls/CategoryFilter
## Species dropdown — jump straight to any creature in the current category
## without having to spam Random / Next. Auto-rebuilt when CategoryFilter
## changes. Selecting a species re-renders immediately.
@onready var species_filter: OptionButton = $Panel/HBox/ControlsScroll/Controls/SpeciesFilter
@onready var species_label: Label = $Panel/HBox/ControlsScroll/Controls/SpeciesLabel
@onready var category_label: Label = $Panel/HBox/ControlsScroll/Controls/CategoryLabel
@onready var seed_label: Label = $Panel/HBox/ControlsScroll/Controls/SeedLabel
@onready var stats_label: Label = $Panel/HBox/ControlsScroll/Controls/StatsLabel
@onready var random_btn: Button = $Panel/HBox/ControlsScroll/Controls/RandomBtn
@onready var next_btn: Button = $Panel/HBox/ControlsScroll/Controls/NextBtn
@onready var reroll_btn: Button = $Panel/HBox/ControlsScroll/Controls/RerollBtn
## "[I] Inspect" — opens a big fullscreen popup with the same orbit
## controls so the player can spin/zoom freely. The in-panel preview is
## sized for the dev menu; this is for actually looking at the model.
@onready var inspect_btn: Button = $Panel/HBox/ControlsScroll/Controls/InspectBtn
## Explicit gender Keep buttons — coin-flip gender meant a player could Keep
## five exotics and roll five females, with no way to breed them. Splitting
## into ♀/♂/Pair guarantees the player can populate both halves of the breeding
## UI deterministically.
@onready var keep_female_btn: Button = $Panel/HBox/ControlsScroll/Controls/KeepFemaleBtn
@onready var keep_male_btn: Button = $Panel/HBox/ControlsScroll/Controls/KeepMaleBtn
## One-click pair drop — spawns BOTH a male and a female of the current
## species with the same body plan + a fresh seed each, so a breeding pair
## is ready immediately. Saves the "Keep, reroll seed, Keep again" loop.
@onready var keep_pair_btn: Button = $Panel/HBox/ControlsScroll/Controls/KeepPairBtn
@onready var keep_feedback: Label = $Panel/HBox/ControlsScroll/Controls/KeepFeedback
@onready var close_btn: Button = $Panel/HBox/ControlsScroll/Controls/CloseBtn
## Always-visible X in the top-right corner of the screen. The bottom Close
## button can get pushed offscreen by a long Controls VBox; this is the
## belt-and-suspenders fallback so dev can always escape.
@onready var corner_close_btn: Button = $CornerCloseBtn

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
	if inspect_btn:
		inspect_btn.pressed.connect(_on_inspect)
	if keep_female_btn:
		keep_female_btn.pressed.connect(_on_keep_female)
	if keep_male_btn:
		keep_male_btn.pressed.connect(_on_keep_male)
	if keep_pair_btn:
		keep_pair_btn.pressed.connect(_on_keep_pair)
	if close_btn:
		close_btn.pressed.connect(_on_close)
	if corner_close_btn:
		corner_close_btn.pressed.connect(_on_close)
	# Make sure the dev panel can be dismissed with Esc — players (and devs
	# in a fullscreen editor run) instinctively reach for Escape and shouldn't
	# need to hunt for either of the two Close buttons.
	set_process_input(true)
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

## Build a GoatData wrapper around the currently-previewed species/plan.
## Returns the data resource (not yet added to herd) so callers can choose
## to use a passed-in seed (so a Pair drop can share a plan across genders).
## See HerdManager._build_captured_data — same convention as wild captures.
func _build_kept_data(forced_gender: int, seed_override: int) -> GoatData:
	var species: String = _filtered_species[_current_index]
	var defaults: Dictionary = ActorTypeData.get_defaults(species)
	var data := GoatData.new()
	data.goat_name = "(Dev) " + species
	data.gender = forced_gender
	data.is_selected = false
	data.is_exhausted = false
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
	data.render_seed = seed_override
	# Generate a fresh plan for THIS seed instead of cloning override_plan —
	# this lets the Pair button hand each half its own seed and still get a
	# species-correct body plan. (For the single Keep buttons it reuses
	# _current_seed, so the visual matches what's on screen.)
	var plan: Dictionary = ActorBodyPlanGenerator.generate(species, seed_override)
	data.shared_body_plan = plan
	return data

func _on_keep_female() -> void:
	if _filtered_species.is_empty():
		return
	var data: GoatData = _build_kept_data(ActorData.Gender.FEMALE, _current_seed)
	HerdManager.add_goat(data)
	if keep_feedback:
		keep_feedback.text = "Added ♀ %s to herd" % data.goat_name
	print("[DevMonsterPreview] Kept ♀ %s (seed %d)." % [data.goat_name, _current_seed])

func _on_keep_male() -> void:
	if _filtered_species.is_empty():
		return
	var data: GoatData = _build_kept_data(ActorData.Gender.MALE, _current_seed)
	HerdManager.add_goat(data)
	if keep_feedback:
		keep_feedback.text = "Added ♂ %s to herd" % data.goat_name
	print("[DevMonsterPreview] Kept ♂ %s (seed %d)." % [data.goat_name, _current_seed])

## One-shot breeding-pair drop — populates the herd with both a female AND
## a male of the current species at once. Each gets its own render_seed so
## they're visually distinct individuals of the same species, ready to breed.
func _on_keep_pair() -> void:
	if _filtered_species.is_empty():
		return
	var seed_f: int = _current_seed
	var seed_m: int = randi()
	if seed_m == seed_f:
		seed_m = seed_f + 1
	var female: GoatData = _build_kept_data(ActorData.Gender.FEMALE, seed_f)
	var male: GoatData = _build_kept_data(ActorData.Gender.MALE, seed_m)
	HerdManager.add_goat(female)
	HerdManager.add_goat(male)
	if keep_feedback:
		keep_feedback.text = "Added ♀+♂ %s pair to herd" % female.goat_name.trim_prefix("(Dev) ")
	print("[DevMonsterPreview] Kept BREEDING PAIR %s (♀ seed %d, ♂ seed %d)." % [
		female.goat_name, seed_f, seed_m
	])

func _input(event: InputEvent) -> void:
	# Esc dismisses the panel regardless of which button has focus.
	if event is InputEventKey \
			and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_close()

## Open a big fullscreen Inspect popup for the currently-previewed creature.
## Routes through preview_plan rather than actor_data because we don't have
## an ActorData yet (the user hasn't kept this creature) — the popup spawns
## a ProceduralCreatureBody directly off the plan.
func _on_inspect() -> void:
	if _filtered_species.is_empty():
		return
	var species: String = _filtered_species[_current_index]
	var plan: Dictionary = ActorBodyPlanGenerator.generate(species, _current_seed)
	if _current_body and _current_body.override_plan is Dictionary \
			and not (_current_body.override_plan as Dictionary).is_empty():
		# Prefer the live plan currently rendering — guarantees the inspect
		# view matches exactly what's on screen even if generate() ever
		# diverges from what was used to spawn the in-card body.
		plan = (_current_body.override_plan as Dictionary).duplicate(true)
	var popup_scene: PackedScene = load("res://UI/InspectPopup.tscn") as PackedScene
	if popup_scene == null:
		return
	var popup: Node = popup_scene.instantiate()
	popup.set("preview_plan", plan)
	popup.set("title", "%s   (seed %d)" % [species, _current_seed])
	get_tree().root.add_child(popup)

func _on_close() -> void:
	queue_free()
