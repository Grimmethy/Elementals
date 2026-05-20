class_name ActorCard
extends DisplayCardBase

@onready var actor_renderer: ActorCardRenderer = $VBoxContainer/ActorCardRenderer
@onready var name_edit: LineEdit = $VBoxContainer/TopRow/NameEdit
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var str_label: Label = $VBoxContainer/StatsGrid/StrLabel
@onready var dex_label: Label = $VBoxContainer/StatsGrid/DexLabel
@onready var con_label: Label = $VBoxContainer/StatsGrid/ConLabel
@onready var int_label: Label = $VBoxContainer/StatsGrid/IntLabel
@onready var wis_label: Label = $VBoxContainer/StatsGrid/WisLabel
@onready var cha_label: Label = $VBoxContainer/StatsGrid/ChaLabel
@onready var ac_label: Label = $VBoxContainer/ACLabel
@onready var arena_checkbox: CheckBox = $VBoxContainer/ArenaCheckBox

## Primary card API — accepts any ActorData subclass and drives UI through
## the polymorphic virtuals on ActorData (`get_display_name`,
## `get_info_line`, `set_display_name`).
var actor_data: ActorData:
	get:
		return data_resource as ActorData
	set(v):
		setup(v)

## Typed alias preserved for read-side legacy callers. The setter parameter
## is typed `GoatData` (inferred from the var type) so writing a non-goat
## ActorData here would be rejected by the Godot runtime — use the
## `actor_data` setter instead for any non-goat path. Today no live code
## writes through this alias (Ranch.gd was migrated to `card.actor_data`),
## so the alias survives purely as a defensive getter for future callers
## that want a typed GoatData read with null-on-mismatch semantics.
var goat_data: GoatData:
	get: return data_resource as GoatData
	set(v): actor_data = v

## Back-compat alias — older internal code referenced `actor_resource`.
## Reads through `actor_data` so we don't have three concurrent names.
var actor_resource: ActorData:
	get: return actor_data
	set(v): actor_data = v

var _actor: Actor

func set_actor(p_actor: Actor) -> void:
	if _actor:
		if _actor.health_component and _actor.health_component.health_changed.is_connected(_on_actor_stats_changed):
			_actor.health_component.health_changed.disconnect(_on_actor_stats_changed)
		if _actor.mana_changed.is_connected(_on_actor_mana_changed):
			_actor.mana_changed.disconnect(_on_actor_mana_changed)
	
	_actor = p_actor

	if _actor:
		# Any Actor with an assigned ActorData drives card via the resource
		# path (preserves goat behaviour; opens the door for goblin/farmer/
		# elemental cards when those actors get a *Data assigned).
		var data_on_actor: ActorData = _actor._data
		if data_on_actor:
			setup(data_on_actor)
		else:
			data_resource = null
			if _actor.health_component:
				_actor.health_component.health_changed.connect(_on_actor_stats_changed)
			_actor.mana_changed.connect(_on_actor_mana_changed)
			_update_ui()

func _on_actor_stats_changed(_hp: float, _mhp: float) -> void:
	_update_ui()

func _on_actor_mana_changed(_m: float, _mm: float) -> void:
	_update_ui()

func setup(p_data: Resource) -> void:
	if actor_data:
		if actor_data.stats_changed.is_connected(_update_ui):
			actor_data.stats_changed.disconnect(_update_ui)

	super.setup(p_data)

	if actor_data:
		actor_data.stats_changed.connect(_update_ui)

func _ready() -> void:
	super._ready()
	_update_ui()
	arena_checkbox.toggled.connect(_on_arena_toggled)
	
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)

func _update_ui() -> void:
	if not is_node_ready(): return

	if actor_data:
		_update_resource_ui()
	elif _actor:
		_update_node_ui()
	else:
		visible = false

func _update_resource_ui() -> void:
	# Renderer accepts any ActorData via `actor_data`. It dispatches
	# internally to a goat-specific scale+tint path or a generic placeholder
	# for other subclasses — see UI/ActorCardRenderer.gd. The pre-Patch-3
	# `if actor_data is GoatData:` gate is gone (R6).
	actor_renderer.visible = true
	actor_renderer.actor_data = actor_data

	if not name_edit.has_focus():
		name_edit.text = actor_data.get_display_name()

	info_label.text = actor_data.get_info_line()

	if actor_data.is_pregnant:
		info_label.text += " [P]"
	if actor_data.is_exhausted:
		info_label.text += " [E]"

	_display_ability_scores(
		actor_data.strength,
		actor_data.dexterity,
		actor_data.constitution,
		actor_data.intelligence,
		actor_data.wisdom,
		actor_data.charisma
	)

	# Actors in resource form usually don't have armor components, so we show base AC
	var dex_mod = int(actor_data.dexterity)
	ac_label.text = "AC: %d (Base)" % (10 + dex_mod)

	arena_checkbox.visible = true
	arena_checkbox.set_pressed_no_signal(actor_data.is_selected)
	arena_checkbox.disabled = actor_data.is_exhausted and not actor_data.is_selected

	update_visual_state()

func _update_node_ui() -> void:
	actor_renderer.visible = false
	
	if not name_edit.has_focus():
		name_edit.text = _actor.name
	
	var hp = 0.0
	var mhp = 0.0
	if _actor.health_component:
		hp = _actor.health_component.current_health
		mhp = _actor.health_component.max_health
		
	info_label.text = "HP: %d/%d | MP: %d/%d" % [int(hp), int(mhp), int(_actor.current_mana), int(_actor.max_mana)]
	
	if _actor.ability_scores_component:
		var asc = _actor.ability_scores_component
		_display_ability_scores(asc.strength, asc.dexterity, asc.constitution, asc.intelligence, asc.wisdom, asc.charisma)
	
	if _actor.armor_class_component:
		var acc = _actor.armor_class_component
		var ac = acc.calculate_ac()
		var armor_name = "None"
		if acc.equipped_armor:
			armor_name = acc.equipped_armor.name
		elif acc.armor_type != ArmorClassComponent.ArmorType.NONE:
			armor_name = ArmorClassComponent.ArmorType.keys()[acc.armor_type]
		
		if acc.equipped_shield or acc.has_shield:
			armor_name += " + Shield"
			
		ac_label.text = "AC: %d (%s)" % [ac, armor_name]
	else:
		ac_label.text = "AC: %d" % _actor.armor_class
		
	arena_checkbox.visible = false
	modulate = base_color

func _display_ability_scores(p_str: float, p_dex: float, p_con: float, p_int: float, p_wis: float, p_cha: float) -> void:
	str_label.text = "STR: %d" % int(p_str)
	dex_label.text = "DEX: %d" % int(p_dex)
	con_label.text = "CON: %d" % int(p_con)
	int_label.text = "INT: %d" % int(p_int)
	wis_label.text = "WIS: %d" % int(p_wis)
	cha_label.text = "CHA: %d" % int(p_cha)

func _is_selected() -> bool:
	return actor_data and actor_data.is_selected

func update_visual_state() -> void:
	if not actor_data: return

	if actor_data.is_selected:
		modulate = highlight_color
	else:
		modulate = Color(0.7, 0.7, 0.7) if actor_data.is_exhausted else base_color

func _on_arena_toggled(pressed: bool) -> void:
	if not actor_data: return
	if pressed != actor_data.is_selected:
		_toggle_arena_selection()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if name_edit.get_global_rect().has_point(event.global_position):
			return
		if arena_checkbox.get_global_rect().has_point(event.global_position):
			return

		_handle_selection()
		accept_event()

func _handle_selection() -> void:
	super._handle_selection()

func _toggle_arena_selection() -> void:
	HerdManager.toggle_selection(actor_data)

func _on_name_submitted(new_text: String) -> void:
	# Polymorphic write — ActorData.set_display_name() is a no-op default;
	# GoatData / GoblinData / FarmerData / ElementalData override it.
	if actor_data:
		actor_data.set_display_name(new_text)
	name_edit.release_focus()

func _on_name_focus_exited() -> void:
	if actor_data:
		actor_data.set_display_name(name_edit.text)
