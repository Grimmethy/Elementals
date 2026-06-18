class_name HubScreen
extends Control

## The Hornbound hub. The "ranch between runs" screen.
##
## Layout (scaffold):
##   - TOP: title bar with day counter + gold + active herd count
##   - LEFT panel: Mission Board (lists current contracts)
##   - RIGHT panel: Building buttons (Breeding Pen, Apothecary, Lab, Forge)
##   - BOTTOM: Squad Picker + Depart button (only enabled if contract selected)
##
## Wire-up:
##   - Listens to HerdManager.mission_board.board_refreshed
##   - On contract pick → highlight selection
##   - On Depart → opens SquadPickerScreen
##   - On SquadPicker.squad_confirmed → calls mission_board.accept_contract()
##     and changes scene to the arena
##
## Visual styling is intentionally minimal — designers will polish in editor.
## All the routing / state is in this script.

signal departing(contract: Resource, squad: Array)

@onready var day_label: Label = $TopBar/DayLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var herd_label: Label = $TopBar/HerdLabel
@onready var traits_label: Label = $TopBar/TraitsLabel
@onready var contracts_list: VBoxContainer = $MainHBox/LeftPanel/LeftVBox/ScrollContainer/ContractList
@onready var depart_btn: Button = $BottomBar/DepartBtn
@onready var pick_squad_btn: Button = $BottomBar/PickSquadBtn
# Building buttons in the right panel.
@onready var breeding_btn: Button = $MainHBox/RightPanel/RightVBox/BreedingBtn
@onready var apothecary_btn: Button = $MainHBox/RightPanel/RightVBox/ApothecaryBtn
@onready var lab_btn: Button = $MainHBox/RightPanel/RightVBox/LabBtn
@onready var forge_btn: Button = $MainHBox/RightPanel/RightVBox/ForgeBtn
@onready var library_btn: Button = $MainHBox/RightPanel/RightVBox/LibraryBtn
@onready var leaderboards_btn: Button = $MainHBox/RightPanel/RightVBox/LeaderboardsBtn
@onready var starter_pen_btn: Button = $MainHBox/RightPanel/RightVBox/StarterPenBtn
@onready var dev_summon_btn: Button = $MainHBox/RightPanel/RightVBox/DevSummonBtn

var selected_contract = null
var selected_squad: Array = []

func _ready() -> void:
	if depart_btn:
		depart_btn.disabled = true
		depart_btn.pressed.connect(_on_depart_pressed)
	if pick_squad_btn:
		pick_squad_btn.disabled = true
		pick_squad_btn.text = "Pick Squad (select a contract first)"
		pick_squad_btn.pressed.connect(_on_pick_squad_pressed)

	# Building buttons — each opens a different sub-screen or shows a stub
	# message. Breeding routes to the existing Ranch scene; the rest are
	# placeholders that print a message until their UIs are authored.
	if breeding_btn:
		breeding_btn.pressed.connect(_on_breeding_pressed)
	if apothecary_btn:
		apothecary_btn.pressed.connect(_on_apothecary_pressed)
		apothecary_btn.tooltip_text = "Heal wounded monsters, revive recent corpses (coming soon)"
	if lab_btn:
		lab_btn.pressed.connect(_on_lab_pressed)
		lab_btn.tooltip_text = "Research traits, target mutations in breeding (coming soon)"
	if forge_btn:
		forge_btn.pressed.connect(_on_forge_pressed)
		forge_btn.tooltip_text = "Craft charms and capture gear (coming soon)"
	if library_btn:
		library_btn.pressed.connect(_on_library_pressed)
	if leaderboards_btn:
		leaderboards_btn.pressed.connect(_on_leaderboards_pressed)
	if starter_pen_btn:
		starter_pen_btn.pressed.connect(_on_starter_pen_pressed)
	if dev_summon_btn:
		dev_summon_btn.pressed.connect(_on_dev_summon_pressed)

	# Connect to mission board.
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm and "mission_board" in hm:
		var mb = hm.get("mission_board")
		if mb and mb.has_signal("board_refreshed"):
			mb.board_refreshed.connect(_refresh_contracts)

	# If this HubScreen is the current scene root (loaded via change_scene_to_file
	# from MainMenu's HUB button), auto-open. Otherwise stay hidden — caller will
	# invoke open() when ready (overlay usage from inside another scene).
	if get_tree() and get_tree().current_scene == self:
		open()
	else:
		hide()

## Show the hub. Refreshes all panels.
func open() -> void:
	_refresh_top_bar()
	# Ensure mission board is fresh for current day.
	var hm: Node = get_node_or_null("/root/HerdManager")
	var bm: Node = get_node_or_null("/root/BondManager")
	if hm and "mission_board" in hm:
		var mb = hm.get("mission_board")
		if mb and mb.has_method("ensure_fresh"):
			var day: int = 0
			if bm and "current_day" in bm:
				day = int(bm.get("current_day"))
			mb.call("ensure_fresh", day)
			_refresh_contracts(mb.get("current_contracts"))
	show()

func _refresh_top_bar() -> void:
	var hm: Node = get_node_or_null("/root/HerdManager")
	var bm: Node = get_node_or_null("/root/BondManager")
	var lib: Node = get_node_or_null("/root/TraitLibrary")
	if day_label and bm:
		day_label.text = "Day %d" % int(bm.get("current_day"))
	if gold_label and hm and "gold" in hm:
		gold_label.text = "%d gp" % int(hm.get("gold"))
	if herd_label and hm:
		var active: Array = hm.call("get_active_herd")
		var pension: Array = hm.call("get_pension")
		herd_label.text = "Herd %d/12  (+%d pension)" % [active.size(), pension.size()]
	if traits_label and lib:
		traits_label.text = "Traits known: %d" % int(lib.call("get_known_trait_count"))

func _refresh_contracts(contracts: Variant) -> void:
	if contracts_list == null:
		return
	for child in contracts_list.get_children():
		child.queue_free()
	if not (contracts is Array):
		_show_empty_board()
		return
	if (contracts as Array).is_empty():
		_show_empty_board()
		return
	for c in (contracts as Array):
		var btn := Button.new()
		btn.text = c.summary() if c.has_method("summary") else "Contract"
		btn.toggle_mode = true
		btn.set_meta("contract", c)
		btn.pressed.connect(_on_contract_picked.bind(c))
		contracts_list.add_child(btn)

## Shown when the mission board has no contracts to display — usually means
## the player hasn't been to the hub yet today, or board ensure_fresh hasn't
## refreshed the pool. A retry-refresh button is provided.
func _show_empty_board() -> void:
	var label := Label.new()
	label.text = "No contracts on the board yet."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contracts_list.add_child(label)
	var refresh_btn := Button.new()
	refresh_btn.text = "↻ Refresh Board"
	refresh_btn.pressed.connect(_force_refresh)
	contracts_list.add_child(refresh_btn)

func _force_refresh() -> void:
	var hm: Node = get_node_or_null("/root/HerdManager")
	var bm: Node = get_node_or_null("/root/BondManager")
	if hm and "mission_board" in hm:
		var mb = hm.get("mission_board")
		var day: int = 0
		if bm and "current_day" in bm:
			day = int(bm.get("current_day"))
		mb.call("refresh_board", day)
		_refresh_contracts(mb.get("current_contracts"))

func _on_contract_picked(contract) -> void:
	selected_contract = contract
	if pick_squad_btn:
		pick_squad_btn.disabled = false
		# Show the player which contract is selected via the button label.
		var contract_name: String = "selected"
		if contract and contract.has_method("get") and "contract_name" in contract:
			contract_name = String(contract.get("contract_name"))
		pick_squad_btn.text = "Pick Squad for: %s" % contract_name
	# Visually mark the selected button. Only one stays "pressed" at a time.
	for btn in contracts_list.get_children():
		if btn is Button:
			(btn as Button).button_pressed = (btn.has_meta("contract") and btn.get_meta("contract") == contract)

func _on_pick_squad_pressed() -> void:
	if selected_contract == null:
		return
	# Open the squad picker as a child overlay.
	var picker_scene: PackedScene = load("res://UI/SquadPickerScreen.tscn") as PackedScene
	if picker_scene == null:
		return
	var picker: Node = picker_scene.instantiate()
	add_child(picker)
	if picker.has_signal("squad_confirmed"):
		picker.connect("squad_confirmed", _on_squad_confirmed)
	if picker.has_method("open"):
		picker.call("open")

func _on_squad_confirmed(squad: Array) -> void:
	selected_squad = squad
	if depart_btn:
		depart_btn.disabled = false

func _on_depart_pressed() -> void:
	if selected_contract == null or selected_squad.is_empty():
		return
	# Accept the contract — sets pending_run_mode + advances day.
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm and "mission_board" in hm:
		var mb = hm.get("mission_board")
		if mb:
			mb.call("accept_contract", selected_contract)
	departing.emit(selected_contract, selected_squad)
	# Stash the squad on HerdManager so the arena can grab it. The arena's
	# _setup_dungeon_run_controller reads `pending_squad` and calls start_run.
	# pending_individual_creature is also set for the existing Play-As path
	# (so the lead becomes the controlled actor when the arena spawns).
	if hm:
		hm.set("pending_individual_creature", selected_squad[0])  # lead
		hm.set("pending_squad", selected_squad.duplicate())
	# Change scene to arena.
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")

# ============================================================================
# Building button handlers
# ============================================================================

## Breeding Pen — opens the existing Ranch scene (where the inspect/breed UI
## already lives). After the player breeds and returns, the hub will pick up
## any new kids automatically (HerdManager persistence handles it).
func _on_breeding_pressed() -> void:
	get_tree().change_scene_to_file("res://Components/BreedingComponents/Ranch/Ranch.tscn")

## Apothecary — heal wounded monsters, revive recent corpses. UI not yet built.
func _on_apothecary_pressed() -> void:
	_show_coming_soon("Apothecary", "Heal wounded monsters and revive recently-fallen packmates.")

## Lab — research traits, target mutations. UI not yet built.
func _on_lab_pressed() -> void:
	_show_coming_soon("Lab", "Research traits from monster parts. Target specific mutations when breeding.")

## Forge — craft charms and capture gear. UI not yet built.
func _on_forge_pressed() -> void:
	_show_coming_soon("Forge", "Craft consumable charms (run buffs) and better capture gear (stronger nets, ropes, chains).")

## Trait Library — open the persistent trait collection screen.
## Currently shows a simple inline summary; full library UI is a follow-up.
func _on_library_pressed() -> void:
	var lib: Node = get_node_or_null("/root/TraitLibrary")
	if lib == null:
		_show_coming_soon("Trait Library", "TraitLibrary autoload not available.")
		return
	var summary: String = "Traits known: %d\nSpecies captured: %d\n\nRecent: %s" % [
		int(lib.call("get_known_trait_count")),
		int(lib.call("get_captured_species_count")),
		str(lib.get("recent_additions"))
	]
	_show_dialog("Trait Library", summary)

## Leaderboards — open the leaderboard screen. Inline summary for MVP.
func _on_leaderboards_pressed() -> void:
	var lb: Node = get_node_or_null("/root/LeaderboardManager")
	if lb == null:
		_show_coming_soon("Leaderboards", "LeaderboardManager autoload not available.")
		return
	var lines: Array[String] = ["Personal Bests:"]
	for board_key in ["deepest_dive", "apex_bloodline", "contract_chain", "chimera_rating"]:
		var pb: float = float(lb.call("get_personal_best", board_key))
		var pb_str: String = "—" if is_nan(pb) else str(pb)
		lines.append("  %s: %s" % [board_key.capitalize(), pb_str])
	lines.append("")
	lines.append("Today's daily seed: %d" % int(LeaderboardManager.get_today_seed()))
	_show_dialog("Leaderboards", "\n".join(lines))

# ============================================================================
# Dialog helpers — minimal inline popups so building buttons feel responsive
# ============================================================================

func _show_coming_soon(title: String, body: String) -> void:
	_show_dialog(title, "%s\n\n(Coming soon — building UI not yet authored.)" % body)

func _show_dialog(title: String, body: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = body
	dlg.min_size = Vector2(420, 160)
	add_child(dlg)
	dlg.popup_centered()
	# Auto-cleanup when closed.
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)

# ============================================================================
# Starter Pen — wipe-recovery / new-player safety net
# ============================================================================
##
## Adopt a random common monster from the wild. Always available — players
## can never get permanently softlocked by a full-squad wipe under permadeath.
## Per the design (GameLoopIdea.md §6), starter monsters are intentionally
## lowest-quality: they refill the bench but are never the answer to hard
## content. Players who lean on the starter pen too much will hit a wall
## quickly, which is the design intent.
##
## Rolls from a small whitelist (Goat / Mushroom / Goblin / Mimic) — the
## four species that already have full ActorData subclasses with breeding
## support. Stat values come from each subclass's _init() default flow
## (which reads ActorTypeData defaults + applies render_seed + names).

const STARTER_SPECIES: Array[String] = ["Goat", "Mushroom", "Goblin", "Mimic"]

func _on_starter_pen_pressed() -> void:
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null:
		_show_dialog("Starter Pen", "HerdManager not available — can't add to herd.")
		return
	# Roll species + build a fresh ActorData of that subclass.
	var species_pick: String = STARTER_SPECIES[randi() % STARTER_SPECIES.size()]
	var data: ActorData = _make_starter_data(species_pick)
	if data == null:
		_show_dialog("Starter Pen", "Couldn't construct a %s — script may be missing." % species_pick)
		return
	# Add via HerdManager's canonical add path (handles signals + save).
	if hm.has_method("add_goat"):
		hm.call("add_goat", data)
	else:
		# Fallback — push into herd_manager directly.
		if "herd_manager" in hm and hm.get("herd_manager"):
			hm.get("herd_manager").call("add_member", data)
	# Refresh hub UI counts.
	_refresh_top_bar()
	# Brag about what they got.
	var display_name: String = _starter_display_name(data, species_pick)
	_show_dialog(
		"Welcome to the Herd",
		"%s has joined your ranch.\n\nSpecies: %s\nGender: %s\nSTR %d  DEX %d  CON %d\n\nThey'll never win you a championship, but they'll fight.\nUse Pick Squad to put them on a roster." % [
			display_name,
			species_pick,
			"♀" if data.gender == ActorData.Gender.FEMALE else "♂",
			_score_from_modifier(data.strength),
			_score_from_modifier(data.dexterity),
			_score_from_modifier(data.constitution),
		]
	)

## Build a fresh ActorData subclass instance for the given species. Returns
## null if the script can't be loaded (e.g. a renamed class). _init() does
## the work — render_seed, generated name, _apply_type_defaults.
func _make_starter_data(species: String) -> ActorData:
	match species:
		"Goat":
			return GoatData.new()
		"Mushroom":
			return MushroomData.new()
		"Goblin":
			return GoblinData.new()
		"Mimic":
			return MimicData.new()
	return null

func _starter_display_name(data: ActorData, species_fallback: String) -> String:
	if data == null:
		return species_fallback
	if "goat_name" in data:
		var n: String = String(data.get("goat_name"))
		if not n.is_empty():
			return n
	if "creature_name" in data:
		var n2: String = String(data.get("creature_name"))
		if not n2.is_empty():
			return n2
	return species_fallback

## Convert a stat modifier (float, 0.0 = baseline) to a D&D-style integer
## score for display (10 + modifier × 2).
func _score_from_modifier(mod: float) -> int:
	return 10 + int(round(mod * 2.0))

## Dev tool — open the monster preview dialog. Cycles through every species
## in ActorTypeData rendered via ProceduralCreatureBody. Useful for QA-ing
## that every D&D Monster Manual entry produces a sensible visual.
func _on_dev_summon_pressed() -> void:
	var scene: PackedScene = load("res://UI/DevMonsterPreview.tscn") as PackedScene
	if scene == null:
		_show_dialog("Dev Summon", "DevMonsterPreview.tscn missing.")
		return
	var dlg: Node = scene.instantiate()
	add_child(dlg)
