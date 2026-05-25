@tool
extends EditorNode3DGizmoPlugin

## Draws the creature's skeleton overlay in the 3D viewport when a
## CreatureGenerator node is selected.
##
## What is drawn (all rendered ON TOP of geometry so the skeleton is always
## readable even when the character mesh covers it):
##
##   Grey lines    — bones: each parent joint connected to its child joint
##   Yellow cross  — joint position marker (3 perpendicular short lines)
##   Green line    — local +Y direction of the bone (where the joint "points")
##
## The green axis lines make it immediately obvious which way each bone is
## oriented at rest — critical for understanding the PI-rotation on arms/legs.
##
## The gizmo updates automatically when the node is selected.  If you call
## rebuild() via the inspector button while selected, click elsewhere and back
## to force a gizmo refresh (standard Godot gizmo behaviour).

const BONE_LINE_COLOR  := Color(0.75, 0.75, 0.75, 0.70)  # grey  — bone connections
const JOINT_DOT_COLOR  := Color(1.00, 0.85, 0.20, 0.90)  # yellow — joint markers
const BONE_AXIS_COLOR  := Color(0.20, 0.90, 0.30, 0.90)  # green  — local +Y axis

const JOINT_CROSS_HALF := 0.035   # half-arm of the cross drawn at each joint
const BONE_AXIS_LENGTH := 0.10    # length of the local-Y direction indicator


func _init() -> void:
	# on_top = true so the gizmo is visible even when the mesh covers it.
	create_material("bone_line", BONE_LINE_COLOR, false, true)
	create_material("joint_dot", JOINT_DOT_COLOR, false, true)
	create_material("bone_axis", BONE_AXIS_COLOR, false, true)


func _has_gizmo(node: Node3D) -> bool:
	return node is CreatureGenerator


func _get_gizmo_name() -> String:
	return "CreatureGenerator"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var gen := gizmo.get_node_3d() as CreatureGenerator
	if gen == null:
		return

	# Rig container — all BoneAnchors live under this node
	var rig := gen.get_node_or_null("_CreatureRig") as Node3D
	if rig == null:
		return   # generator exists but hasn't built yet

	# Collect every BoneAnchor with a reference to its parent BoneAnchor
	var pairs: Array = []   # each element: [BoneAnchor, parent_BoneAnchor_or_null]
	_collect(rig, null, pairs)
	if pairs.is_empty():
		return

	# Lines are in the CreatureGenerator's LOCAL space
	var gen_inv        := gen.global_transform.inverse()
	var bone_lines     := PackedVector3Array()
	var joint_lines    := PackedVector3Array()
	var axis_lines     := PackedVector3Array()

	for pair in pairs:
		var anchor : BoneAnchor = pair[0]
		var parent : BoneAnchor = pair[1]

		var g_xform  := anchor.global_transform
		var pos      := gen_inv * g_xform.origin   # anchor centre in gen-local space

		# --- Bone connection line (parent → child) ---
		if parent != null:
			bone_lines.append(gen_inv * parent.global_transform.origin)
			bone_lines.append(pos)

		# --- Joint cross marker (3 perpendicular line segments) ---
		var h := JOINT_CROSS_HALF
		joint_lines.append(pos + Vector3(-h,  0,  0)); joint_lines.append(pos + Vector3( h,  0,  0))
		joint_lines.append(pos + Vector3( 0, -h,  0)); joint_lines.append(pos + Vector3( 0,  h,  0))
		joint_lines.append(pos + Vector3( 0,  0, -h)); joint_lines.append(pos + Vector3( 0,  0,  h))

		# --- Local +Y axis indicator ---
		# For upright spine bones this points up; for PI-rotated arm/leg roots it
		# points down, making the orientation immediately readable in the viewport.
		var axis_tip := gen_inv * (g_xform.origin + g_xform.basis.y * BONE_AXIS_LENGTH)
		axis_lines.append(pos)
		axis_lines.append(axis_tip)

	gizmo.add_lines(bone_lines,  get_material("bone_line", gizmo))
	gizmo.add_lines(joint_lines, get_material("joint_dot", gizmo))
	gizmo.add_lines(axis_lines,  get_material("bone_axis", gizmo))


# ==============================================================================
# Private
# ==============================================================================

## Depth-first collection of all [BoneAnchor, parent_BoneAnchor] pairs.
## Non-BoneAnchor nodes (MeshInstance3D etc.) are traversed but not recorded.
func _collect(node: Node3D, parent_anchor: BoneAnchor, out: Array) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		if child is BoneAnchor:
			out.append([child as BoneAnchor, parent_anchor])
			_collect(child as Node3D, child as BoneAnchor, out)
		else:
			_collect(child as Node3D, parent_anchor, out)
