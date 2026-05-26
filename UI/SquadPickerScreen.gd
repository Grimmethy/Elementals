class_name SquadPickerScreen
extends Control

## The squad picker UI. Shown at the hub before the player departs on a run.
##
## Layout:
##   - LEFT column: list of active herd members (up to 12)
##   - MIDDLE column: 4 squad slots (lead + 3 packmates)
##   - RIGHT column: pension members + "Restore to Active" button
##   - BOTTOM: 3 loadout buttons (A/B/C) for save/load, plus DEPART button
##
## Scene structure is scaffolded — designers can lay out the actual visuals.
## All behavior is wired in this script.

signal squad_confirmed(squad: Array)
signal cancelled()

## The currently-selected squad. Up to 4 ActorData entries. Index 0 = lead.
var current_squad: Array = [null, null, null, null]

## The "highlighted" herd member — the one the player has selected from the
## active or pension list, ready to be placed into a slot. Null = nothing
## picked yet. Click a slot to place the highlighted member there, or click
## another herd member to change the highlight.
var _picked_member: ActorData = null

## Slot labels in the player-facing language. Index 0 = Lead.
const SLOT_LABELS: Array[String] = ["⭐ LEAD", "Pack 1", "Pack 2", "Pack 3"]

## Cached UI nodes. Paths match SquadPickerScreen.tscn layout.
@onready var active_list: VBoxContainer = $Panel/Margin/VBox/HBox/ActiveColumn/ScrollContainer/VBoxContainer
@onready var pension_list: VBoxContainer = $Panel/Margin/VBox/HBox/PensionColumn/ScrollContainer/VBoxContainer
@onready var slot_a: Button = $Panel/Margin/VBox/HBox/SquadColumn/SlotA
@onready var slot_b: Button = $Panel/Margin/VBox/HBox/SquadColumn/SlotB
@onready var slot_c: Button = $Panel/Margin/VBox/HBox/SquadColumn/SlotC
@onready var slot_d: Button = $Panel/Margin/VBox/HBox/SquadColumn/SlotD
@onready var loadout_a_btn: Button = $Panel/Margin/VBox/BottomRow/LoadoutA
@onready var loadout_b_btn: Button = $Panel/Margin/VBox/BottomRow/LoadoutB
@onready var loadout_c_btn: Button = $Panel/Margin/VBox/BottomRow/LoadoutC
@onready var depart_btn: Button = $Panel/Margin/VBox/BottomRow/DepartBtn
@onready var cancel_btn: Button = $Panel/Margin/VBox/BottomRow/CancelBtn

func _ready() -> void:
	hide()
	if depart_btn:
		depart_btn.pressed.connect(_on_depart)
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel)
	if loadout_a_btn:
		loadout_a_btn.pressed.connect(_on_load_loadout.bind("Loadout A"))
	if loadout_b_btn:
		loadout_b_btn.pressed.connect(_on_load_loadout.bind("Loadout B"))
	if loadout_c_btn:
		loadout_c_btn.pressed.connect(_on_load_loadout.bind("Loadout C"))
	# Wire slot buttons. Clicking a slot places the picked member there, OR
	# (if no member is picked AND the slot has an occupant) clears the slot.
	var slots: Array[Button] = [slot_a, slot_b, slot_c, slot_d]
	for i in range(4):
		if slots[i]:
			slots[i].pressed.connect(_on_slot_clicked.bind(i))

## Show the picker. Re-populates from HerdManager.
func open() -> void:
	_refresh_active_list()
	_refresh_pension_list()
	_refresh_squad_slots()
	show()

func _refresh_active_list() -> void:
	if active_list == null:
		return
	for child in active_list.get_children():
		child.queue_free()
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null:
		return
	var active: Array = hm.call("get_active_herd")
	for member in active:
		var btn := _make_member_button(member)
		btn.pressed.connect(_on_active_member_picked.bind(member))
		active_list.add_child(btn)

func _refresh_pension_list() -> void:
	if pension_list == null:
		return
	for child in pension_list.get_children():
		child.queue_free()
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null:
		return
	var pension: Array = hm.call("get_pension")
	for member in pension:
		var btn := _make_member_button(member)
		btn.pressed.connect(_on_pension_member_picked.bind(member))
		pension_list.add_child(btn)

func _refresh_squad_slots() -> void:
	var slots: Array[Button] = [slot_a, slot_b, slot_c, slot_d]
	for i in range(4):
		var slot_btn: Button = slots[i]
		if slot_btn == null:
			continue
		var member: ActorData = current_squad[i] if i < current_squad.size() else null
		# Lead slot (index 0) gets a star + amber tint; pack slots are plain.
		var is_lead: bool = (i == 0)
		if member:
			var verb: String = "you play as" if is_lead else "in your pack"
			slot_btn.text = "%s: %s   ✕" % [SLOT_LABELS[i], _label_for(member)]
			slot_btn.tooltip_text = "%s — %s. Click again to remove." % [_label_for(member), verb]
		else:
			if _picked_member != null:
				var role: String = "as your LEAD (you'll play this monster)" if is_lead else "into pack slot %d" % i
				slot_btn.text = "%s: ← place %s here" % [SLOT_LABELS[i], _label_for(_picked_member)]
				slot_btn.tooltip_text = "Place %s %s." % [_label_for(_picked_member), role]
			else:
				slot_btn.text = "%s: (empty)" % SLOT_LABELS[i]
				slot_btn.tooltip_text = "Click a herd member on the left, then click here to assign them."

func _make_member_button(member: ActorData) -> Button:
	var btn := Button.new()
	btn.text = _label_for(member)
	btn.toggle_mode = true
	# Track which member this button represents, so we can highlight only one.
	btn.set_meta("member", member)
	# Show "currently picked" state if this is the highlighted member.
	if member == _picked_member:
		btn.button_pressed = true
	return btn

func _label_for(member: ActorData) -> String:
	if member == null:
		return "(empty)"
	var name_str: String = ""
	if "goat_name" in member:
		name_str = String(member.get("goat_name"))
	elif "creature_name" in member:
		name_str = String(member.get("creature_name"))
	if name_str.is_empty():
		name_str = member.get_actor_type()
	# Show grief flag if applicable.
	var bm: Node = get_node_or_null("/root/BondManager")
	if bm and bm.call("is_grieving", member):
		name_str += " 💔"
	return name_str

## New 2-click model: clicking an active herd member HIGHLIGHTS them (sets
## _picked_member). They get placed into the squad when the player then
## clicks a slot. Same monster clicked twice → unselects.
func _on_active_member_picked(member: ActorData) -> void:
	if _picked_member == member:
		_picked_member = null  # toggle off
	else:
		_picked_member = member
	_refresh_squad_slots()
	# Refresh both lists so the toggle state is correct (only one button stays
	# pressed at a time across active + pension).
	_refresh_active_list()
	_refresh_pension_list()

## Picking from pension promotes the monster to active first (if there's
## room), then highlights it. If active is full, prompt the player to
## clear an active slot first.
func _on_pension_member_picked(member: ActorData) -> void:
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm:
		var ok: bool = bool(hm.call("restore_from_pension", member))
		if not ok:
			# Active is full — pull the most-recently-added active member
			# into pension to make room (cheap UX win for MVP).
			var active: Array = hm.call("get_active_herd")
			if not active.is_empty():
				hm.call("swap_active_with_pension", active.back(), member)
		_refresh_active_list()
		_refresh_pension_list()
	# Same toggle-highlight behavior as active.
	_on_active_member_picked(member)

## Click a squad slot: places the highlighted member there. If no member is
## picked AND the slot is occupied, clears the slot.
func _on_slot_clicked(slot_index: int) -> void:
	if _picked_member != null:
		# Remove this member from any other slot first.
		for i in range(4):
			if current_squad[i] == _picked_member:
				current_squad[i] = null
		current_squad[slot_index] = _picked_member
		_picked_member = null  # clear after placement
		_refresh_squad_slots()
		_refresh_active_list()
		_refresh_pension_list()
		return
	# No member picked → clicking an occupied slot clears it.
	if current_squad[slot_index] != null:
		current_squad[slot_index] = null
		_refresh_squad_slots()

func _on_load_loadout(loadout_name: String) -> void:
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null:
		return
	var loaded: Array = hm.call("load_loadout", loadout_name)
	# Pad / truncate to 4.
	while loaded.size() < 4:
		loaded.append(null)
	current_squad = loaded.slice(0, 4)
	_refresh_squad_slots()

func _on_depart() -> void:
	# Filter null slots.
	var final_squad: Array = []
	for m in current_squad:
		if m != null:
			final_squad.append(m)
	if final_squad.is_empty():
		# Don't allow empty squads.
		return
	squad_confirmed.emit(final_squad)
	hide()

func _on_cancel() -> void:
	cancelled.emit()
	hide()
