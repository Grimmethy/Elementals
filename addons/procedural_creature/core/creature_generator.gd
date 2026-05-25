@tool
class_name CreatureGenerator
extends Node3D

## The live orchestration node for a procedural creature.
##
## Drop one of these into any scene, assign a CreatureDefinition .tres in the
## inspector, and the creature assembles itself — both at runtime and, because
## of @tool, immediately in the editor viewport.
##
## Typical editor workflow
## -----------------------
##   1. Add CreatureGenerator to scene.
##   2. Set definition = res://creatures/definitions/humanoid_base.tres.
##   3. Tweak values in the .tres inspector panel → the figure updates live.
##
## Runtime API
## -----------
##   rebuild()                       — force a full teardown + reassembly
##   set_detail_level(level)         — swap LOD without touching the .tres asset
##   clear_detail_override()         — return to the definition's own detail level
##
## The "rebuilt" signal fires at the end of every successful rebuild so other
## systems (HUD, IK solvers, animation state machines) can react.
##
## Child management
## ----------------
## All geometry lives under a single "_CreatureRig" child node so the generator
## never accidentally destroys nodes you add yourself (collision shapes, audio
## players, etc.). The rig is recreated on every rebuild; do not store references
## to its children across frames.
##
## Skeleton
## --------
## Phase 6: a Skeleton3D is inferred from the BoneAnchor hierarchy after every
## assembly and lives inside the rig. Access it via get_skeleton().

signal rebuilt

## Changing this in the inspector triggers an immediate rebuild.
@export var definition: CreatureDefinition:
	set(value):
		definition = value
		if is_node_ready():
			rebuild()

# --- private state ---

# -1 = use definition's own detail_level; any other value = runtime override
var _runtime_detail_level: int = -1
var _rig: Node3D = null
var _skeleton: Skeleton3D = null


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	rebuild()


# ==============================================================================
# Public API
# ==============================================================================

## Tear down the current rig and rebuild from the active definition.
## Safe to call at any time — in _ready, from a signal, from an editor button.
func rebuild() -> void:
	if definition == null:
		push_warning("CreatureGenerator: no definition assigned — nothing to build.")
		return
	_clear_rig()
	_rig = Node3D.new()
	_rig.name = "_CreatureRig"
	add_child(_rig)
	ShapeAssembler.assemble(_active_def(), _rig)
	_skeleton = SkeletonInferer.infer(_rig, _rig)
	rebuilt.emit()


## Override the detail level at runtime without modifying the .tres asset.
## Triggers a rebuild immediately.
func set_detail_level(level: CreatureDefinition.DetailLevel) -> void:
	_runtime_detail_level = level
	rebuild()


## Remove the runtime detail override and rebuild at the definition's own level.
func clear_detail_override() -> void:
	_runtime_detail_level = -1
	rebuild()


## Return the inferred Skeleton3D, or null if no build has completed yet.
## The skeleton is owned by the rig and is recreated on every rebuild —
## do not cache this reference across calls to rebuild() or set_detail_level().
func get_skeleton() -> Skeleton3D:
	return _skeleton


# ==============================================================================
# Private helpers
# ==============================================================================

## Returns the definition to use for the current build.
## If a runtime override is active, a temporary duplicate is returned
## (the original .tres is never modified).
func _active_def() -> CreatureDefinition:
	if _runtime_detail_level == -1:
		return definition
	var temp := definition.duplicate_definition()
	temp.detail_level = _runtime_detail_level
	return temp


## Free the existing rig immediately.
## The Skeleton3D lives inside the rig so it is freed automatically.
## Safe because the rig contains only static geometry — no connected signals,
## no physics, no animation tracks that could reference its nodes mid-frame.
func _clear_rig() -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.free()   # also frees _skeleton since it is a child of _rig
	_rig = null
	_skeleton = null
