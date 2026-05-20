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
