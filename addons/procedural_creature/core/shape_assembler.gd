class_name ShapeAssembler

## Assembles a full creature scene tree from a CreatureDefinition.
##
## Every logical body segment becomes a BoneAnchor node (for Phase 6 skeleton
## inference) with a MeshInstance3D child (the visible geometry).
## DebugColors are applied per body-part group so the assembled figure is
## immediately readable in the editor viewport.
##
## assemble() is fully deterministic: identical CreatureDefinitions produce
## identical scene trees with no randomness or global state.
##
## Phase 4: BIPED body plan only. Other plans warn and fall back to BIPED.
## Phase 5 will add QUADRUPED / SERPENTINE routing.
##
## Orientation convention
## ----------------------
## All builders place geometry from y=0 (proximal / root attachment) to
## y=height (distal / tip). Spine segments build straight upward — natural.
## Limbs that hang downward (arms, legs) use a PI rotation on Z at their
## root anchor so local +Y maps to world -Y. All descendant anchors inherit
## this orientation, so child positions (0, length, 0) in local space always
## step toward the distal end regardless of which way the limb points.

static func assemble(def: CreatureDefinition, parent: Node3D) -> BoneAnchor:
	match def.body_plan:
		CreatureDefinition.BodyPlan.BIPED:
			return _assemble_biped(def, parent)
		_:
			push_warning(
				"ShapeAssembler: body_plan %d not yet implemented — falling back to BIPED." \
				% def.body_plan
			)
			return _assemble_biped(def, parent)


# ==============================================================================
# Biped assembly
# ==============================================================================

static func _assemble_biped(def: CreatureDefinition, parent: Node3D) -> BoneAnchor:
	var sides   : int   = LimbBuilder.resolve_sides(def.detail_level)
	var t_sides : int   = TorsoBuilder.resolve_sides(def.detail_level)
	var r       : float = def.limb_thickness * 0.5   # base limb radius

	# --- Proportional splits --------------------------------------------------
	# Torso
	var chest_h   : float = def.torso_height * 0.65
	var midriff_h : float = def.torso_height * 0.35

	# Arms  (total = arm_length)
	var upper_arm : float = def.arm_length * 0.43
	var forearm   : float = def.arm_length * 0.38
	var hand_l    : float = def.arm_length * 0.19

	# Legs  (total = leg_length → hip_y == leg_length exactly)
	var thigh   : float = def.leg_length * 0.45
	var shin    : float = def.leg_length * 0.40
	var foot_l  : float = def.leg_length * 0.15
	var hip_y   : float = def.leg_length

	# Head / neck
	var neck_l  : float = 0.15 * def.head_scale
	var head_sx : float = 0.14 * def.head_scale
	var head_sy : float = 0.16 * def.head_scale
	var head_sz : float = 0.12 * def.head_scale

	# Lateral offsets
	var shoulder_x : float = def.torso_width * 0.50   # arm root from centreline
	var leg_x      : float = def.torso_width * 0.22   # leg root from centreline

	# ==========================================================================
	# Hips — skeleton root; elevated to top-of-leg height so the figure stands
	# on y = 0.
	# ==========================================================================
	var hips := _make_anchor("Hips")
	hips.position = Vector3(0.0, hip_y, 0.0)
	parent.add_child(hips)

	# --------------------------------------------------------------------------
	# Spine chain  (each segment builds upward from its anchor origin)
	# --------------------------------------------------------------------------

	# Midriff — waist section; narrower than chest
	var midriff := _make_anchor("Midriff")
	midriff.position = Vector3.ZERO   # sits exactly at hip level
	hips.add_child(midriff)
	_add_mesh(midriff,
		TorsoBuilder.build(midriff_h, def.torso_width * 0.82, def.torso_depth * 0.78, t_sides),
		DebugColors.MIDRIFF)

	# Chest — main torso mass
	var chest := _make_anchor("Chest")
	chest.position = Vector3(0.0, midriff_h, 0.0)
	midriff.add_child(chest)
	_add_mesh(chest,
		TorsoBuilder.build(chest_h, def.torso_width, def.torso_depth, t_sides),
		DebugColors.TORSO)

	# Neck — short column bridging chest to head
	var neck := _make_anchor("Neck")
	neck.position = Vector3(0.0, chest_h, 0.0)
	chest.add_child(neck)
	_add_mesh(neck,
		LimbBuilder.build(neck_l, r * 0.60, r * 0.75, sides),
		DebugColors.NECK)

	# Head
	var head := _make_anchor("Head")
	head.position = Vector3(0.0, neck_l, 0.0)
	neck.add_child(head)
	_add_mesh(head,
		HeadBuilder.build(head_sx, head_sy, head_sz, def.head_shape, def.detail_level),
		DebugColors.HEAD)

	# --------------------------------------------------------------------------
	# Arms and legs  (helpers apply the PI-on-Z rotation so limbs hang downward)
	# --------------------------------------------------------------------------
	_build_arm(chest, chest_h, shoulder_x, upper_arm, forearm, hand_l, r, sides, true)
	_build_arm(chest, chest_h, shoulder_x, upper_arm, forearm, hand_l, r, sides, false)

	_build_leg(hips, thigh, shin, foot_l, r * 1.3, leg_x, sides, true)
	_build_leg(hips, thigh, shin, foot_l, r * 1.3, leg_x, sides, false)

	return hips


# ==============================================================================
# Limb helpers
# ==============================================================================

## Arms hang downward from the shoulder joint.
## The ShoulderL/R anchor is rotated PI on Z so its local +Y points world -Y.
## All descendants inherit this orientation; stepping (0, length, 0) in local
## space always moves toward the hand.
static func _build_arm(
		chest      : BoneAnchor,
		chest_h    : float,
		shoulder_x : float,
		upper_arm  : float,
		forearm    : float,
		hand_l     : float,
		r          : float,
		sides      : int,
		is_left    : bool) -> void:

	var side       := -1.0 if is_left else 1.0
	var suffix     := "L"  if is_left else "R"
	var arm_color  := DebugColors.ARM_L  if is_left else DebugColors.ARM_R
	var hand_color := DebugColors.HAND_L if is_left else DebugColors.HAND_R

	# Shoulder — at top-of-chest level, flipped so the limb hangs downward
	var shoulder := _make_anchor("Shoulder" + suffix)
	shoulder.position   = Vector3(side * shoulder_x, chest_h, 0.0)
	shoulder.rotation.z = PI   # local +Y → world -Y
	chest.add_child(shoulder)

	# Upper arm: radius_bottom at shoulder (wider), radius_top at elbow (narrower)
	_add_mesh(shoulder,
		LimbBuilder.build(upper_arm, r * 0.82, r, sides),
		arm_color)

	# Elbow — step (0, upper_arm, 0) in the flipped space = move downward
	var elbow := _make_anchor("Elbow" + suffix)
	elbow.position = Vector3(0.0, upper_arm, 0.0)
	shoulder.add_child(elbow)
	_add_mesh(elbow,
		LimbBuilder.build(forearm, r * 0.70, r * 0.85, sides),
		arm_color)

	# Wrist
	var wrist := _make_anchor("Wrist" + suffix)
	wrist.position = Vector3(0.0, forearm, 0.0)
	elbow.add_child(wrist)
	_add_mesh(wrist,
		LimbBuilder.build(hand_l, r * 0.52, r * 0.68, sides),
		hand_color)


## Legs hang downward from the hip joint.  Same PI-on-Z rotation convention.
static func _build_leg(
		hips   : BoneAnchor,
		thigh  : float,
		shin   : float,
		foot_l : float,
		r      : float,
		leg_x  : float,
		sides  : int,
		is_left: bool) -> void:

	var side       := -1.0 if is_left else 1.0
	var suffix     := "L"  if is_left else "R"
	var leg_color  := DebugColors.LEG_L  if is_left else DebugColors.LEG_R
	var foot_color := DebugColors.FOOT_L if is_left else DebugColors.FOOT_R

	# HipJoint — offset laterally, then flipped downward
	var hip_joint := _make_anchor("HipJoint" + suffix)
	hip_joint.position   = Vector3(side * leg_x, 0.0, 0.0)
	hip_joint.rotation.z = PI   # local +Y → world -Y
	hips.add_child(hip_joint)

	# Thigh: wider at hip, narrower at knee
	_add_mesh(hip_joint,
		LimbBuilder.build(thigh, r * 0.82, r, sides),
		leg_color)

	# Knee
	var knee := _make_anchor("Knee" + suffix)
	knee.position = Vector3(0.0, thigh, 0.0)
	hip_joint.add_child(knee)
	_add_mesh(knee,
		LimbBuilder.build(shin, r * 0.68, r * 0.85, sides),
		leg_color)

	# Ankle
	var ankle := _make_anchor("Ankle" + suffix)
	ankle.position = Vector3(0.0, shin, 0.0)
	knee.add_child(ankle)
	_add_mesh(ankle,
		LimbBuilder.build(foot_l, r * 0.55, r * 0.72, sides),
		foot_color)


# ==============================================================================
# Shared utilities
# ==============================================================================

## Create a BoneAnchor with bone_name and node name both set to bname.
static func _make_anchor(bname: String) -> BoneAnchor:
	var a := BoneAnchor.new()
	a.bone_name = bname
	a.name      = bname
	return a


## Create a MeshInstance3D from mesh + debug color and add it to parent.
static func _add_mesh(parent: Node3D, mesh: ArrayMesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh              = mesh
	mi.material_override = DebugColors.make_mat(color)
	parent.add_child(mi)
	return mi
