class_name ActorCard
extends DisplayCardBase

@onready var actor_renderer: GoatRenderer = $VBoxContainer/GoatRenderer
@onready var creature_preview: CreaturePreview = $VBoxContainer/CreaturePreview
@onready var name_edit: LineEdit = $VBoxContainer/TopRow/NameEdit
## Tiny "[I]" button next to the name. Opens an InspectPopup hosting a
## big orbit-camera view of this card's creature so the player can spin,
## zoom in to face detail, or zoom way out to read the silhouette — the
## in-card preview is too small + fixed-camera for that.
@onready var inspect_button: Button = $VBoxContainer/TopRow/InspectBtn
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var str_label: Label = $VBoxContainer/StatsGrid/StrLabel
@onready var dex_label: Label = $VBoxContainer/StatsGrid/DexLabel
@onready var con_label: Label = $VBoxContainer/StatsGrid/ConLabel
@onready var int_label: Label = $VBoxContainer/StatsGrid/IntLabel
@onready var wis_label: Label = $VBoxContainer/StatsGrid/WisLabel
@onready var cha_label: Label = $VBoxContainer/StatsGrid/ChaLabel
@onready var ac_label: Label = $VBoxContainer/ACLabel
@onready var arena_checkbox: CheckBox = $VBoxContainer/ArenaCheckBox
@onready var play_as_button: Button = $VBoxContainer/PlayAsButton

## Accepts ANY ActorData subclass (GoatData / MimicData / MushroomData /
## GoblinData / hybrid) so cheat-spawned and bred creatures all show up in
## the Ranch herd UI without crashing. Display name, age, and stats are
## resolved polymorphically via property existence checks.
var actor_resource: ActorData:
	get:
		return data_resource as ActorData
	set(v):
		setup(v)

# Alias for compatibility with existing code (Ranch.gd still writes
# `card.goat_data = goat`). Accepts any ActorData under the hood.
var goat_data: ActorData:
	get: return actor_resource
	set(v): actor_resource = v

var _actor: Actor

func set_actor(p_actor: Actor) -> void:
	if _actor:
		if _actor.health_component and _actor.health_component.health_changed.is_connected(_on_actor_stats_changed):
			_actor.health_component.health_changed.disconnect(_on_actor_stats_changed)
		if _actor.mana_changed.is_connected(_on_actor_mana_changed):
			_actor.mana_changed.disconnect(_on_actor_mana_changed)
	
	_actor = p_actor
	
	if _actor:
		if _actor is GoatActor:
			setup(_actor.goat_data)
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
	if actor_resource:
		if actor_resource.stats_changed.is_connected(_update_ui):
			actor_resource.stats_changed.disconnect(_update_ui)
	
	super.setup(p_data)
	
	if actor_resource:
		actor_resource.stats_changed.connect(_update_ui)

func _ready() -> void:
	super._ready()
	_update_ui()
	arena_checkbox.toggled.connect(_on_arena_toggled)
	if play_as_button:
		play_as_button.pressed.connect(_on_play_as_pressed)
	if inspect_button:
		inspect_button.pressed.connect(_on_inspect_pressed)
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)

## "[I]" inspect button — spawn an InspectPopup overlay parented at the
## scene-tree root so it covers the whole screen (parenting under the card
## would clip it to ~160px). Pass the card's actor_resource so the popup
## resolves the same body (universal procedural for foreign-species GoatData,
## per-subclass body otherwise). Multiple cards can each open their own
## popup; the popup queue_free()s itself on close.
func _on_inspect_pressed() -> void:
	if actor_resource == null:
		return
	var popup_scene: PackedScene = load("res://UI/InspectPopup.tscn") as PackedScene
	if popup_scene == null:
		push_warning("[ActorCard] InspectPopup.tscn missing — inspect button no-op.")
		return
	var popup: Node = popup_scene.instantiate()
	popup.set("actor_data", actor_resource)
	# Resolve a title — display name if present, else species, else type.
	var t: String = ""
	if "goat_name" in actor_resource:
		t = String(actor_resource.goat_name)
	elif "creature_name" in actor_resource:
		t = String(actor_resource.creature_name)
	if t == "":
		t = actor_resource.get_actor_type()
	popup.set("title", t)
	get_tree().root.add_child(popup)

## Solo arena entry — store the creature's data on HerdManager so the
## ArenaSpawner picks it up as the player-controlled actor (no group spawn),
## then change scene to the arena. ArenaSpawner clears the field after spawn.
func _on_play_as_pressed() -> void:
	if actor_resource == null:
		return
	if has_node("/root/HerdManager"):
		var hm: Node = get_node("/root/HerdManager")
		hm.set("pending_individual_creature", actor_resource)
		print("[Ranch] Solo entry: launching arena as %s." % actor_resource.get_actor_type())
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")

func _update_ui() -> void:
	if not is_node_ready(): return
	
	if actor_resource:
		_update_resource_ui()
	elif _actor:
		_update_node_ui()
	else:
		visible = false

func _update_resource_ui() -> void:
	# Render the preview using whichever renderer fits the resource type.
	# GoatData -> legacy 2D GoatRenderer (sprites). Everything else (Mimic /
	# Mushroom / Goblin / hybrid) -> CreaturePreview, which spawns the actual
	# procedural body in a SubViewport so the player can SEE what they're
	# picking to breed (chest shape, mushroom limbs, goblin tint, etc.).
	#
	# EXCEPTION: a GoatData carrying a foreign-species shared_body_plan (i.e.,
	# a wild-captured or dev-summoned exotic that was wrapped in GoatData for
	# breeding compatibility) skips the goat sprite and goes through
	# CreaturePreview so the card shows the actual 3D species, not a tan goat.
	# CreaturePreview's own dispatch handles the universal-renderer path.
	if actor_resource is GoatData and not _is_foreign_species_goat(actor_resource as GoatData):
		actor_renderer.visible = true
		actor_renderer.goat_data = actor_resource as GoatData
		if creature_preview:
			creature_preview.visible = false
			creature_preview.actor_data = null
	else:
		actor_renderer.visible = false
		if creature_preview:
			creature_preview.visible = true
			creature_preview.actor_data = actor_resource

	# Polymorphic display name: GoatData uses goat_name, all other ActorData
	# subclasses (MimicData / MushroomData / GoblinData) use creature_name.
	# Fall back to the type tag if neither field is present.
	var display_name: String = ""
	if "goat_name" in actor_resource:
		display_name = String(actor_resource.goat_name)
	elif "creature_name" in actor_resource:
		display_name = String(actor_resource.creature_name)
	else:
		display_name = actor_resource.get_actor_type()
	if not name_edit.has_focus():
		name_edit.text = display_name

	var gender_str = "Female" if actor_resource.gender == ActorData.Gender.FEMALE else "Male"
	var level_value: int = int(actor_resource.level) if "level" in actor_resource else 1
	var age_value: int = int(actor_resource.age_days) if "age_days" in actor_resource else 0
	info_label.text = "%s - Lvl: %d - Age: %d" % [gender_str, level_value, age_value]

	if actor_resource.is_pregnant:
		info_label.text += " [P]"
	if actor_resource.is_exhausted:
		info_label.text += " [E]"
		
	_display_ability_scores(
		actor_resource.strength, 
		actor_resource.dexterity, 
		actor_resource.constitution,
		actor_resource.intelligence, 
		actor_resource.wisdom, 
		actor_resource.charisma
	)
	
	# Goats in resource form usually don't have armor components, so we show base AC
	var dex_mod = int(actor_resource.dexterity)
	ac_label.text = "AC: %d (Base)" % (10 + dex_mod)
	
	arena_checkbox.visible = true
	arena_checkbox.set_pressed_no_signal(actor_resource.is_selected)
	arena_checkbox.disabled = actor_resource.is_exhausted and not actor_resource.is_selected
	
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
	return actor_resource and actor_resource.is_selected

func update_visual_state() -> void:
	if not actor_resource: return
	
	if actor_resource.is_selected:
		modulate = highlight_color
	else:
		modulate = Color(0.7, 0.7, 0.7) if actor_resource.is_exhausted else base_color

func _on_arena_toggled(pressed: bool) -> void:
	if not actor_resource: return
	if pressed != actor_resource.is_selected:
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
	HerdManager.toggle_selection(actor_resource)

func _on_name_submitted(new_text: String) -> void:
	if actor_resource:
		_set_display_name(new_text)
	name_edit.release_focus()

func _on_name_focus_exited() -> void:
	if actor_resource:
		_set_display_name(name_edit.text)

## Write the new display name into whichever field the resource has —
## goat_name for GoatData, creature_name for the other ActorData subclasses.
func _set_display_name(new_name: String) -> void:
	if actor_resource == null:
		return
	if "goat_name" in actor_resource:
		actor_resource.goat_name = new_name
	elif "creature_name" in actor_resource:
		actor_resource.creature_name = new_name

## True if this GoatData is actually a wrapped foreign species (wild-captured
## exotic or dev-summoned monster carrying its own body plan). Detection:
## the shared_body_plan has a meta.species stamped — a fresh GoatData's
## default plan has no meta key. Used to route those cards through the 3D
## CreaturePreview instead of the legacy 2D goat sprite.
func _is_foreign_species_goat(g: GoatData) -> bool:
	if g == null:
		return false
	if not (g.shared_body_plan is Dictionary):
		return false
	var plan: Dictionary = g.shared_body_plan
	if not plan.has("meta"):
		return false
	var meta_var: Variant = plan["meta"]
	if not (meta_var is Dictionary):
		return false
	return String((meta_var as Dictionary).get("species", "")) != ""
