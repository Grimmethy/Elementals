class_name CharacterSelectCard
extends Control

signal character_selected(actor_name: String)
signal equipment_changed(actor_name: String, weapon_index: int, ability_index: int, armor_index: int)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var model_container: CreaturePreview = $VBoxContainer/ModelContainer
@onready var weapon_button: Button = $VBoxContainer/WeaponButton
@onready var ability_button: Button = $VBoxContainer/AbilityButton
@onready var armor_button: Button = $VBoxContainer/ArmorButton
@onready var info_button: Button = $VBoxContainer/InfoButton
@onready var stats_container: Control = $VBoxContainer/StatsContainer
@onready var selection_indicator: Control = $SelectionIndicator

var actor_name: String = ""

# Cycling state using stationary cyclers (from CyclingComponent autoload)
var _weapon_cycler: CyclingComponent.StationaryCycler = CyclingComponent.StationaryCycler.new()
var _ability_cycler: CyclingComponent.StationaryCycler = CyclingComponent.StationaryCycler.new()
var _armor_cycler: CyclingComponent.StationaryCycler = CyclingComponent.StationaryCycler.new()

# Expose current indices for external access (read-only via getters)
var current_weapon_index: int:
	get: return _weapon_cycler.current_index
var current_ability_index: int:
	get: return _ability_cycler.current_index
var current_armor_index: int:
	get: return _armor_cycler.current_index

## Actor types that use the PCF and can be visually customized.
## Extend this array as more actors get a CreatureGenerator.
const PCF_ACTOR_TYPES : Array[String] = ["farmer"]

var _customize_button : Button = null
var _customizer_panel : CharacterCustomizerPanel = null

var is_selected_card: bool = false:
	set(v):
		is_selected_card = v
		_update_selection_style()

var show_stats: bool = false:
	set(v):
		show_stats = v
		_update_stats_visibility()

# Stats for display when info is shown
var hp: float = 0.0
var max_hp: float = 0.0
var mana: float = 0.0
var max_mana: float = 0.0
var armor_class: int = 10
var stealth: int = 0
var passive_perception: int = 10
var strength: int = 0
var dexterity: int = 0
var constitution: int = 0
var intelligence: int = 0
var wisdom: int = 0
var charisma: int = 0

func _ready() -> void:
	weapon_button.pressed.connect(_on_weapon_pressed)
	ability_button.pressed.connect(_on_ability_pressed)
	armor_button.pressed.connect(_on_armor_pressed)
	info_button.pressed.connect(_on_info_pressed)
	
	# Connect click to select (handles left/right click for cycling)
	gui_input.connect(_on_card_input)
	
	# Make ModelContainer also handle selection clicks
	model_container.gui_input.connect(_on_model_container_input)
	
	_update_display()
	_update_selection_style()

func setup(p_actor_name: String, p_weapons, p_abilities, p_armor, p_selected: bool = false, p_weapon_index: int = 0, p_ability_index: int = 0, p_armor_index: int = 0) -> void:
	actor_name = p_actor_name
	name_label.text = actor_name.capitalize()
	
	# Initialize cyclers with items and saved indices
	_weapon_cycler.set_items(p_weapons)
	_weapon_cycler.set_index(clampi(p_weapon_index, 0, max(0, _weapon_cycler.items.size() - 1)))
	
	_ability_cycler.set_items(p_abilities)
	_ability_cycler.set_index(clampi(p_ability_index, 0, max(0, _ability_cycler.items.size() - 1)))
	
	_armor_cycler.set_items(p_armor)
	_armor_cycler.set_index(clampi(p_armor_index, 0, max(0, _armor_cycler.items.size() - 1)))
	
	_setup_model_preview()
	_update_display()
	_setup_customize_button()

## Populate the 3D model preview for this card's actor type.
##
## PCF actors (farmer, and future additions listed in PCF_ACTOR_TYPES) get a
## live CreatureGenerator body driven by their CreatureDefinition — or the
## player's saved customization if they've visited the customizer.
##
## All other actors get a coloured humanoid-silhouette placeholder so the
## preview slot is never empty, matching the breeding-UI convention.
func _setup_model_preview() -> void:
	if model_container == null:
		return

	var clean_name := actor_name.strip_edges().to_lower()

	match clean_name:
		"farmer":
			# Use the player's custom definition if one is saved and matches
			# the currently selected actor; otherwise fall back to humanoid_base.
			var def: CreatureDefinition
			if (GameSettings.selected_creature_definition != null
					and GameSettings.selected_actor_type == "farmer"):
				def = GameSettings.selected_creature_definition
			else:
				def = load("res://creatures/definitions/humanoid_base.tres") as CreatureDefinition
			model_container.set_definition(def)

		# Non-PCF actors: coloured silhouette placeholder.
		# Colours are chosen to evoke each character's visual identity.
		"goat":
			model_container.spawn_placeholder(Color(0.72, 0.60, 0.42))
		"goblin":
			model_container.spawn_placeholder(Color(0.32, 0.52, 0.22))
		"fire":
			model_container.spawn_placeholder(Color(0.95, 0.42, 0.12))
		"water":
			model_container.spawn_placeholder(Color(0.22, 0.52, 0.88))
		"mimic":
			model_container.spawn_placeholder(Color(0.62, 0.42, 0.22))
		"mushroom":
			model_container.spawn_placeholder(Color(0.48, 0.68, 0.30))
		"scarecrow":
			model_container.spawn_placeholder(Color(0.80, 0.70, 0.40))
		_:
			model_container.spawn_placeholder(Color(0.55, 0.55, 0.55))

func _update_display() -> void:
	_update_weapon_button()
	_update_ability_button()
	_update_armor_button()
	_update_stats_visibility()

func _update_weapon_button() -> void:
	var items = _weapon_cycler.items
	var idx = _weapon_cycler.current_index
	if items.size() > 0:
		weapon_button.text = "<< %s >>" % items[idx]
		weapon_button.disabled = items.size() <= 1
	else:
		weapon_button.text = "<< No Weapons >>"
		weapon_button.disabled = true

func _update_ability_button() -> void:
	var items = _ability_cycler.items
	var idx = _ability_cycler.current_index
	if items.size() > 0:
		ability_button.text = "<< %s >>" % items[idx]
		ability_button.disabled = items.size() <= 1
	else:
		ability_button.text = "<< No Abilities >>"
		ability_button.disabled = true

func _update_armor_button() -> void:
	var items = _armor_cycler.items
	var idx = _armor_cycler.current_index
	if items.size() > 0:
		armor_button.text = "<< %s >>" % items[idx]
		armor_button.disabled = items.size() <= 1
	else:
		armor_button.text = "<< No Armor >>"
		armor_button.disabled = true

func _update_stats_visibility() -> void:
	stats_container.visible = show_stats

func _update_selection_style() -> void:
	if selection_indicator:
		selection_indicator.visible = is_selected_card
	
	if is_selected_card:
		modulate = Color(1.2, 1.2, 1.0)  # Slightly brighter when selected
	else:
		modulate = Color(1.0, 1.0, 1.0)

func _update_stats_display() -> void:
	if not is_node_ready(): return
	
	var hp_label = $VBoxContainer/StatsContainer/HPLabel as Label
	var ac_label = $VBoxContainer/StatsContainer/ACLabel as Label
	
	if hp_label:
		hp_label.text = "HP: %.0f/%.0f" % [hp, max_hp]
	if ac_label:
		ac_label.text = "AC: %d" % armor_class
	
	# Update special stats
	var stealth_label = $VBoxContainer/StatsContainer/StealthLabel as Label
	var perception_label = $VBoxContainer/StatsContainer/PerceptionLabel as Label
	if stealth_label:
		stealth_label.text = "Stealth: +%d" % stealth if stealth >= 0 else "Stealth: %d" % stealth
	if perception_label:
		perception_label.text = "Perception: %d" % passive_perception
	
	var stats_grid = $VBoxContainer/StatsContainer/StatsGrid
	if stats_grid:
		var str_label = stats_grid.get_node_or_null("StrLabel") as Label
		var dex_label = stats_grid.get_node_or_null("DexLabel") as Label
		var con_label = stats_grid.get_node_or_null("ConLabel") as Label
		var int_label = stats_grid.get_node_or_null("IntLabel") as Label
		var wis_label = stats_grid.get_node_or_null("WisLabel") as Label
		var cha_label = stats_grid.get_node_or_null("ChaLabel") as Label
		
		if str_label: str_label.text = "STR: %+d" % strength
		if dex_label: dex_label.text = "DEX: %+d" % dexterity
		if con_label: con_label.text = "CON: %+d" % constitution
		if int_label: int_label.text = "INT: %+d" % intelligence
		if wis_label: wis_label.text = "WIS: %+d" % wisdom
		if cha_label: cha_label.text = "CHA: %+d" % charisma

func set_stats(p_stats: Dictionary) -> void:
	hp = p_stats.get("hp", 0.0)
	max_hp = p_stats.get("max_hp", 0.0)
	armor_class = p_stats.get("ac", 10)
	stealth = p_stats.get("stealth", 0)
	passive_perception = p_stats.get("perception", 10)
	strength = p_stats.get("strength", 10)
	dexterity = p_stats.get("dexterity", 10)
	constitution = p_stats.get("constitution", 10)
	intelligence = p_stats.get("intelligence", 10)
	wisdom = p_stats.get("wisdom", 10)
	charisma = p_stats.get("charisma", 10)
	_update_stats_display()

func _on_weapon_pressed() -> void:
	cycle_weapon()

func _on_ability_pressed() -> void:
	cycle_ability()

func _on_armor_pressed() -> void:
	cycle_armor()

func _on_info_pressed() -> void:
	show_stats = !show_stats

func _on_weapon_meta_pressed() -> void:
	# Meta button (right click) cycles backward
	_weapon_cycler.cycle_backward()
	_update_weapon_button()
	_emit_equipment_changed()

func _on_ability_meta_pressed() -> void:
	_ability_cycler.cycle_backward()
	_update_ability_button()
	_emit_equipment_changed()

func _on_armor_meta_pressed() -> void:
	_armor_cycler.cycle_backward()
	_update_armor_button()
	_emit_equipment_changed()

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			character_selected.emit(actor_name)

func _on_model_container_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			character_selected.emit(actor_name)

func cycle_weapon() -> void:
	if _weapon_cycler.cycle_forward():
		_update_weapon_button()
		_emit_equipment_changed()

func cycle_ability() -> void:
	if _ability_cycler.cycle_forward():
		_update_ability_button()
		_emit_equipment_changed()

func cycle_armor() -> void:
	if _armor_cycler.cycle_forward():
		_update_armor_button()
		_emit_equipment_changed()

func _emit_equipment_changed() -> void:
	equipment_changed.emit(
		actor_name.to_lower(),
		_weapon_cycler.current_index,
		_ability_cycler.current_index,
		_armor_cycler.current_index
	)

func get_selected_equipment() -> Dictionary:
	return {
		"weapon_index": current_weapon_index,
		"ability_index": current_ability_index,
		"armor_index": current_armor_index
	}


# ==============================================================================
# PCF Appearance Customizer
# ==============================================================================

## Show the Customize button only for actor types that have a PCF body.
## The button is created dynamically so non-PCF cards are completely unaffected.
func _setup_customize_button() -> void:
	var is_pcf := PCF_ACTOR_TYPES.has(actor_name.strip_edges().to_lower())
	if not is_pcf:
		if is_instance_valid(_customize_button):
			_customize_button.hide()
		return

	if not is_instance_valid(_customize_button):
		_customize_button = Button.new()
		_customize_button.name = "CustomizeButton"
		_customize_button.text = "Customize"
		_customize_button.pressed.connect(_on_customize_pressed)
		var vbox := get_node_or_null("VBoxContainer") as VBoxContainer
		if vbox and is_instance_valid(info_button):
			vbox.add_child(_customize_button)
			# Place directly after the info button so it flows naturally
			vbox.move_child(_customize_button, info_button.get_index() + 1)

	_customize_button.show()


func _on_customize_pressed() -> void:
	# Find the panel already in the tree, or instantiate it fresh.
	_customizer_panel = get_tree().root.get_node_or_null(
		"CharacterCustomizerPanel"
	) as CharacterCustomizerPanel

	if not is_instance_valid(_customizer_panel):
		_customizer_panel = (preload("res://UI/CharacterCustomizerPanel.tscn")
				as PackedScene).instantiate() as CharacterCustomizerPanel
		_customizer_panel.name = "CharacterCustomizerPanel"
		get_tree().root.add_child(_customizer_panel)

	# Always reconnect confirmed with one-shot to avoid stacking handlers
	# when the same card is opened multiple times.
	if _customizer_panel.confirmed.is_connected(_on_customizer_confirmed):
		_customizer_panel.confirmed.disconnect(_on_customizer_confirmed)
	_customizer_panel.confirmed.connect(_on_customizer_confirmed, CONNECT_ONE_SHOT)

	# Start from the player's saved customization if it exists and matches
	# the currently selected actor; otherwise fall back to the default .tres.
	var base_def : CreatureDefinition
	if (GameSettings.selected_creature_definition != null
			and GameSettings.selected_actor_type == actor_name.strip_edges().to_lower()):
		base_def = GameSettings.selected_creature_definition
	else:
		base_def = load("res://creatures/definitions/humanoid_base.tres") as CreatureDefinition

	_customizer_panel.open(base_def)


func _on_customizer_confirmed(def: CreatureDefinition) -> void:
	GameSettings.selected_actor_type = actor_name.strip_edges().to_lower()
	GameSettings.selected_creature_definition = def
	GameSettings.save_creature_customization()
	# Refresh the card preview so the new look is visible immediately.
	_setup_model_preview()
