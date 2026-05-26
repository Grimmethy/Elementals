class_name InspectPopup
extends Control

## Fullscreen inspect overlay — pops up when the player clicks the [I] button
## on a creature card. Hosts the same procedural body the card preview shows,
## but inside a much larger viewport with a wide-range orbit camera so the
## player can spin, zoom way in to look at face details, or zoom way out to
## see overall silhouette.
##
## Dispatch matches CreaturePreview: ActorData with a stamped
## shared_body_plan.meta.species routes through ProceduralCreatureBody (the
## universal renderer); MimicData / MushroomData / GoblinData route to their
## own procedural body scripts; plain GoatData falls back to a placeholder.
##
## Usage:
##   var popup := load("res://UI/InspectPopup.tscn").instantiate() as InspectPopup
##   popup.actor_data = my_actor_data    # or popup.preview_plan = my_plan
##   popup.title = "Camel — Seed 42"
##   get_tree().root.add_child(popup)
##
## Dismissed by Esc, the corner X button, or clicking the dim backdrop.

const ProceduralMimicChestScript = preload("res://src/actors/types/ProceduralMimicChest.gd")
const ProceduralMushroomBodyScript = preload("res://src/actors/types/ProceduralMushroomBody.gd")
const ProceduralCreatureBodyScript = preload("res://src/actors/body/ProceduralCreatureBody.gd")

@onready var _viewport: SubViewport = $Panel/MarginContainer/VBox/PreviewBox/SubViewport
@onready var _creature_container: Node3D = $Panel/MarginContainer/VBox/PreviewBox/SubViewport/CreatureContainer
@onready var _title_label: Label = $Panel/MarginContainer/VBox/TitleLabel
@onready var _close_btn: Button = $CornerCloseBtn
@onready var _bg_dim: ColorRect = $Backdrop

## Either source can populate the popup. `actor_data` is preferred when we
## have a real herd member (lets us route per-type the same way the card does);
## `preview_plan` lets the dev tool inspect a not-yet-saved plan directly.
var actor_data: ActorData = null
var preview_plan: Dictionary = {}

## Title shown above the preview (defaults to species name if blank).
var title: String = ""

func _ready() -> void:
	# Make sure we cover the whole viewport so the backdrop dims everything.
	anchor_right = 1.0
	anchor_bottom = 1.0
	# Backdrop is click-through dismiss.
	if _bg_dim:
		_bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		_bg_dim.gui_input.connect(_on_backdrop_input)
	if _close_btn:
		_close_btn.pressed.connect(_close)
	# Trigger the spawn once children exist.
	_rebuild()

func _on_backdrop_input(event: InputEvent) -> void:
	# Single click on the dim area closes — common modal pattern.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.pressed and ek.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()

func _close() -> void:
	queue_free()

func _rebuild() -> void:
	if _creature_container == null:
		return
	# Clear any prior preview (synchronously — see CreaturePreview comment).
	for child in _creature_container.get_children():
		_creature_container.remove_child(child)
		child.free()
	# Resolve title — explicit override > actor name > species-from-plan > fallback.
	var resolved_title: String = title
	if resolved_title == "":
		if actor_data != null:
			if "goat_name" in actor_data:
				resolved_title = String(actor_data.goat_name)
			elif "creature_name" in actor_data:
				resolved_title = String(actor_data.creature_name)
		if resolved_title == "":
			resolved_title = _species_from_plan(_resolve_plan())
		if resolved_title == "":
			resolved_title = "Creature"
	if _title_label:
		_title_label.text = resolved_title
	# Spawn the right body.
	# Priority 1: if there's a stamped foreign body plan on the actor OR a
	# raw preview_plan was set, use the universal renderer.
	var plan: Dictionary = _resolve_plan()
	if not plan.is_empty():
		_spawn_universal(plan)
		return
	# Priority 2: subclass-specific renderers (matches CreaturePreview).
	if actor_data is MimicData:
		_spawn_mimic(actor_data as MimicData)
	elif actor_data is MushroomData:
		_spawn_mushroom(actor_data as MushroomData)
	else:
		# Fallback: neutral grey box. Better than an empty viewport — at least
		# the camera has something to orbit around.
		_spawn_placeholder()

func _resolve_plan() -> Dictionary:
	if not preview_plan.is_empty():
		return preview_plan
	if actor_data != null and actor_data.shared_body_plan is Dictionary:
		var p: Dictionary = actor_data.shared_body_plan
		if p.has("meta") and (p["meta"] is Dictionary) \
				and String((p["meta"] as Dictionary).get("species", "")) != "":
			return p
	return {}

func _species_from_plan(plan: Dictionary) -> String:
	if plan.has("meta") and (plan["meta"] is Dictionary):
		return String((plan["meta"] as Dictionary).get("species", ""))
	return ""

func _spawn_universal(plan: Dictionary) -> void:
	var body: Node = ProceduralCreatureBodyScript.new()
	body.name = "InspectUniversalBody"
	if actor_data != null:
		body.set("actor_data", actor_data)
	body.set("override_plan", plan)
	_creature_container.add_child(body)
	if body.has_method("rebuild_from_genome"):
		body.call("rebuild_from_genome", plan)

func _spawn_mimic(data: MimicData) -> void:
	var body = ProceduralMimicChestScript.new()
	body.name = "InspectMimicBody"
	body.mimic_data = data
	_creature_container.add_child(body)

func _spawn_mushroom(data: MushroomData) -> void:
	var body = ProceduralMushroomBodyScript.new()
	body.name = "InspectMushroomBody"
	body.mushroom_data = data
	_creature_container.add_child(body)

func _spawn_placeholder() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mesh.material_override = mat
	_creature_container.add_child(mesh)
