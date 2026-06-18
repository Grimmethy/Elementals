class_name QuestTrackerHUD
extends Control

@onready var panel: PanelContainer = $QuestTrackerPanel
@onready var title_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var objective_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/ObjectiveLabel
@onready var gold_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/GoldLabel
@onready var message_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var message_timer: Timer = $MessageTimer

func _ready() -> void:
	# Styling applied at runtime
	if panel:
		panel.add_theme_stylebox_override("panel", UIStyle.make_main_panel_style())
	
	if message_timer:
		message_timer.timeout.connect(func() -> void: if message_label: message_label.text = "")
	
	_connect_signals()
	_update_all()

func _connect_signals() -> void:
	if QuestEvents.quest_log_changed.is_connected(_update_all) == false:
		QuestEvents.quest_log_changed.connect(_update_all)
	if QuestEvents.quest_message.is_connected(_show_message) == false:
		QuestEvents.quest_message.connect(_show_message)
	if QuestEvents.gold_changed.is_connected(_on_gold_changed) == false:
		QuestEvents.gold_changed.connect(_on_gold_changed)

func _update_all() -> void:
	if not gold_label: return

	gold_label.text = "Gold: %d" % QuestState.gold

	# Hornbound: prefer showing the accepted contract from HerdManager if
	# one is active. This is the player's CURRENT run objective, more
	# relevant than any background QuestState quest.
	if _show_hornbound_contract():
		return

	var active: Array = QuestState.get_active_quests()
	if active.is_empty():
		title_label.text = "Quest Tracker"
		objective_label.text = "No active quest. Open the Quest Board."
		return

	var quest: Dictionary = active[0] as Dictionary
	var quest_id: String = String(quest.get("id", ""))
	title_label.text = String(quest.get("title", quest_id))

	var lines: Array[String] = QuestState.get_objective_lines(quest_id)
	var joined: String = ""
	for line in lines:
		if not joined.is_empty():
			joined += "\n"
		joined += String(line)
	objective_label.text = joined

## Returns true if a Hornbound contract was found and displayed.
## Reads HerdManager.accepted_contract and writes the title + objective.
func _show_hornbound_contract() -> bool:
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null or not "accepted_contract" in hm:
		return false
	var contract = hm.get("accepted_contract")
	if contract == null:
		return false
	# Title.
	var contract_name: String = ""
	if "contract_name" in contract:
		contract_name = String(contract.get("contract_name"))
	if contract_name.is_empty():
		contract_name = "Active Contract"
	title_label.text = "📜 %s" % contract_name
	# Objective lines.
	var lines: Array[String] = []
	if contract.has_method("summary"):
		lines.append(String(contract.call("summary")))
	if "description" in contract:
		var desc: String = String(contract.get("description"))
		if not desc.is_empty():
			lines.append("")
			lines.append(desc)
	# Run progress — if a DungeonRunController is in the scene, show current room.
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if arena and "run_controller" in arena:
		var rc = arena.get("run_controller")
		if rc and "current_state" in rc:
			lines.append("")
			lines.append("Room: %s" % _state_name(int(rc.get("current_state"))))
	objective_label.text = "\n".join(lines)
	return true

func _state_name(state: int) -> String:
	match state:
		0: return "Preparing"
		1: return "Warm-up"
		2: return "Branch"
		3: return "Mid-Boss"
		4: return "Extract Point"
		5: return "Boss Push"
		6: return "Complete"
		7: return "Abandoned"
		8: return "Failed"
	return "Unknown"

func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % new_gold

func _show_message(text: String) -> void:
	if message_label:
		message_label.text = text
	if message_timer:
		message_timer.start()
