class_name ExtractScreen
extends Control

## UI shown at the extract point (after the mid-boss). Three buttons:
##
##   LEAVE  — bank the run's loot, return to hub (safe, guaranteed)
##   PUSH   — one more harder room with bigger rewards (risk)
##   ABANDON — exit immediately, lose all loot, keep your monsters (eject)
##
## This is the heart of the Hornbound run — greed is the most engaging form
## of decision-making, and this screen forces it.
##
## Wire up: instance this scene in Arena UI, listen for the run controller's
## `extract_point_reached` signal, call `show_for_run(controller)` to display.

signal option_chosen(option: String)

@onready var leave_btn: Button = $Panel/VBox/LeaveBtn
@onready var push_btn: Button = $Panel/VBox/PushBtn
@onready var abandon_btn: Button = $Panel/VBox/AbandonBtn
@onready var summary_label: Label = $Panel/VBox/Summary

var _run_controller: Node = null

func _ready() -> void:
	hide()
	if leave_btn:
		leave_btn.pressed.connect(_on_leave)
	if push_btn:
		push_btn.pressed.connect(_on_push)
	if abandon_btn:
		abandon_btn.pressed.connect(_on_abandon)

## Show the extract screen for a given run, populating the summary with
## the rewards accumulated so far.
func show_for_run(run_controller: Node) -> void:
	_run_controller = run_controller
	_populate_summary()
	show()

func _populate_summary() -> void:
	if _run_controller == null or summary_label == null:
		return
	var rewards: Variant = _run_controller.get("pending_rewards")
	if not (rewards is Dictionary):
		return
	var d: Dictionary = rewards
	var lines: Array[String] = []
	lines.append("== This run's haul ==")
	lines.append("Gold: %d" % int(d.get("gold", 0)))
	lines.append("Parts: %d" % (d.get("parts", []) as Array).size())
	lines.append("Captured: %d" % (d.get("captured", []) as Array).size())
	lines.append("Traits learned: %d" % (d.get("traits_learned", []) as Array).size())
	lines.append("")
	lines.append("LEAVE — bank this haul.")
	lines.append("PUSH  — one more room, harder, bigger reward.")
	lines.append("ABANDON — exit now, lose all loot.")
	summary_label.text = "\n".join(lines)

func _on_leave() -> void:
	option_chosen.emit("leave")
	if _run_controller:
		_run_controller.call("choose_extract_option", "leave")
	hide()

func _on_push() -> void:
	option_chosen.emit("push")
	if _run_controller:
		_run_controller.call("choose_extract_option", "push")
	hide()

func _on_abandon() -> void:
	option_chosen.emit("abandon")
	if _run_controller:
		_run_controller.call("choose_extract_option", "abandon")
	hide()
