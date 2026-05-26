class_name CreaturePreview
extends SubViewportContainer

## A 3D preview of a creature shown in the breeding/herd UI. Renders the
## actual procedural body that would spawn in the arena, so the player can
## see exactly which features they're combining when picking a breeding pair.
##
## Supported types:
##   MimicData      → ProceduralMimicChest (chest/vase/casket/barrel/crate)
##   MushroomData   → ProceduralMushroomBody (cap + stem + optional limbs)
##   GoblinData     → simple placeholder cube (goblin model not yet exposed)
##   GoatData       → simple placeholder cube (existing GoatRenderer covers
##                    goat cards in the legacy code path)
##   Any other      → hidden
##
## The preview rebuilds whenever `actor_data` is reassigned, so a card that
## switches resources (e.g., when re-bound to a fresh herd entry on
## refresh_ui) shows the new creature without leaks.

const ProceduralMimicChestScript = preload("res://src/actors/types/ProceduralMimicChest.gd")
const ProceduralMushroomBodyScript = preload("res://src/actors/types/ProceduralMushroomBody.gd")
const ProceduralCreatureBodyScript = preload("res://src/actors/body/ProceduralCreatureBody.gd")

@onready var _viewport: SubViewport = $SubViewport
@onready var _creature_container: Node3D = $SubViewport/CreatureContainer
@onready var _camera: Camera3D = $SubViewport/Camera3D
@onready var _key_light: DirectionalLight3D = $SubViewport/KeyLight

var actor_data: ActorData:
	set(v):
		if actor_data == v:
			return
		actor_data = v
		_rebuild()

## Rotation applied to the displayed creature so the player sees the front
## (where eyes/teeth/face live). For all our procedural bodies, the face is
## on the +Z side. Camera looks down -Z, so a rotation of 0 around Y is
## front-facing. Drift this slightly for a more dynamic 3/4 view.
@export_range(-180, 180, 5) var preview_yaw_degrees: float = 18.0

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_node_ready():
		return
	# Clear previous creature IMMEDIATELY. queue_free() is deferred to
	# end-of-frame, which left the previous procedural body still in the
	# SubViewport alongside the new one — the player saw "stacked models"
	# until the next frame. free() removes the node + all its descendants
	# synchronously so the next spawn renders cleanly.
	#
	# Safe here because the procedural body meshes are self-contained
	# (no external signal connections, no tick registrations).
	for child in _creature_container.get_children():
		_creature_container.remove_child(child)
		child.free()
	if actor_data == null:
		return
	# Build the matching procedural body.
	# FIRST: if the actor_data carries a populated shared_body_plan with a
	# species stamped in meta (i.e., it was captured / dev-kept from another
	# species and pretends to be a GoatData for breeding compat), route it
	# through the universal ProceduralCreatureBody so it actually RENDERS as
	# the species it carries instead of the goat-tan-cube placeholder.
	# This is what makes the "Keep for Breeding" dev tool show real visuals
	# in the herd / ranch cards.
	if _has_universal_body_plan(actor_data):
		_spawn_universal_creature(actor_data)
		return
	if actor_data is MimicData:
		_spawn_mimic_preview(actor_data as MimicData)
	elif actor_data is MushroomData:
		_spawn_mushroom_preview(actor_data as MushroomData)
	elif actor_data is GoatData:
		_spawn_goat_placeholder(actor_data as GoatData)
	elif actor_data is GoblinData:
		_spawn_goblin_placeholder(actor_data as GoblinData)
	else:
		# Unknown type — show a neutral block so the slot isn't empty.
		_spawn_generic_placeholder()

## True if this actor_data has a shared_body_plan that was filled in by
## ActorBodyPlanGenerator (i.e., has a meta.species stamped). The default
## empty plan returned by ActorData.default_shared_body_plan() has no meta
## key, so the absence of meta is the bright-line for "render as goat".
func _has_universal_body_plan(data: ActorData) -> bool:
	if data == null:
		return false
	if not (data.shared_body_plan is Dictionary):
		return false
	var plan: Dictionary = data.shared_body_plan
	if not plan.has("meta"):
		return false
	var meta_var: Variant = plan["meta"]
	if not (meta_var is Dictionary):
		return false
	var species_str: String = String((meta_var as Dictionary).get("species", ""))
	return species_str != ""

## Spawn the universal procedural body, the same code path the arena uses.
## Routing through this for dev-kept exotics means the herd card preview
## matches exactly what the player saw on the Dev Summoner screen.
func _spawn_universal_creature(data: ActorData) -> void:
	var body: Node = ProceduralCreatureBodyScript.new()
	body.name = "UniversalPreviewBody"
	# ProceduralCreatureBody supports `override_plan` for previews where
	# actor_data isn't directly assigned, but here we have a full ActorData
	# so the natural path is to assign it and let rebuild_from_genome pick
	# up the plan via actor_data.shared_body_plan.
	body.set("actor_data", data)
	body.set("override_plan", data.shared_body_plan)
	# Position + yaw so the face is camera-facing (consistent with the
	# Mimic / Mushroom previews above).
	if body is Node3D:
		var node3d := body as Node3D
		node3d.position = Vector3(0, -0.30, 0)
		node3d.rotation_degrees = Vector3(0, preview_yaw_degrees, 0)
	_creature_container.add_child(body)
	# Force a rebuild now that the body is in the tree, so the preview
	# renders before the next frame (matches the DevMonsterPreview flow).
	if body.has_method("rebuild_from_genome"):
		body.call("rebuild_from_genome", data.shared_body_plan)

# --- Spawners --------------------------------------------------------------

func _spawn_mimic_preview(data: MimicData) -> void:
	# ProceduralMimicChestScript.new() instantiates a Node3D with the script
	# fully initialized (member vars, _init), unlike set_script which leaves
	# them at defaults until _ready. Cleaner + avoids the double-rebuild
	# (assign data BEFORE add_child so the setter's is_inside_tree check
	# skips rebuild, then _ready does the single canonical rebuild).
	var body = ProceduralMimicChestScript.new()
	body.name = "MimicPreviewBody"
	body.position = Vector3(0, -0.30, 0)
	body.rotation_degrees = Vector3(0, preview_yaw_degrees, 0)
	body.mimic_data = data
	_creature_container.add_child(body)

func _spawn_mushroom_preview(data: MushroomData) -> void:
	var body = ProceduralMushroomBodyScript.new()
	body.name = "MushroomPreviewBody"
	body.position = Vector3(0, -0.30, 0)
	body.rotation_degrees = Vector3(0, preview_yaw_degrees, 0)
	body.mushroom_data = data
	_creature_container.add_child(body)

func _spawn_goblin_placeholder(_data: GoblinData) -> void:
	# Goblin doesn't have a procedural body class yet — render a green cube
	# tinted by the goblin's base_color so the preview still varies per
	# creature. A proper GoblinModel-based preview can replace this later.
	var mesh := MeshInstance3D.new()
	mesh.name = "GoblinPlaceholder"
	var box := BoxMesh.new()
	box.size = Vector3(0.30, 0.55, 0.25)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _data.base_color
	mat.roughness = 0.85
	mesh.material_override = mat
	mesh.position = Vector3(0, -0.02, 0)
	mesh.rotation_degrees = Vector3(0, preview_yaw_degrees, 0)
	_creature_container.add_child(mesh)

func _spawn_goat_placeholder(_data: GoatData) -> void:
	# Goat cards still use the legacy 2D GoatRenderer; this preview node is
	# usually hidden for goats. If something forces it visible, draw a tan
	# cube as a fallback so we don't render an empty viewport.
	var mesh := MeshInstance3D.new()
	mesh.name = "GoatPlaceholder"
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.35, 0.25)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _data.base_color if _data.base_color != Color.WHITE else Color(0.70, 0.60, 0.40)
	mesh.material_override = mat
	mesh.position = Vector3(0, -0.10, 0)
	mesh.rotation_degrees = Vector3(0, preview_yaw_degrees, 0)
	_creature_container.add_child(mesh)

func _spawn_generic_placeholder() -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "UnknownCreature"
	var box := BoxMesh.new()
	box.size = Vector3(0.30, 0.30, 0.30)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mesh.material_override = mat
	_creature_container.add_child(mesh)
