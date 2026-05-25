class_name SkeletonInferer

## Converts a BoneAnchor scene tree into a Godot Skeleton3D.
##
## Called automatically by CreatureGenerator after ShapeAssembler places the
## geometry.  The resulting Skeleton3D lives inside the _CreatureRig node so
## its lifetime is tied to the rig — no separate cleanup required.
##
## How rest poses are computed
## ---------------------------
## Each BoneAnchor's LOCAL transform (position + rotation relative to its
## parent Node3D) becomes the bone's rest pose in the Skeleton3D.  Because
## the bone hierarchy mirrors the BoneAnchor hierarchy exactly, Godot can
## compute the correct world-space pose for every bone by chaining transforms
## up the skeleton — the same way it would for a hand-authored skeleton.
##
## Downward-hanging limbs (arms, legs) have rotation.z = PI on their root
## anchor; this is captured in the rest pose so the animation system sees
## the bone's axis pointing toward the child joint even though that direction
## is world -Y at rest.
##
## Usage
## -----
##   var skeleton := SkeletonInferer.infer(rig, rig)
##
##   # Look up a bone index by name after the fact:
##   var map := SkeletonInferer.build_bone_map(skeleton)
##   var hips_idx: int = map["Hips"]


## Walk the BoneAnchor children of [rig] and produce a Skeleton3D.
##
## rig            — the _CreatureRig Node3D whose children are BoneAnchors
## skeleton_parent — where to add_child the new Skeleton3D
##                   (pass [rig] itself so it is freed with the rig)
static func infer(rig: Node3D, skeleton_parent: Node3D) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"

	var idx_map: Dictionary = {}   # BoneAnchor instance → bone index (int)

	for child in rig.get_children():
		if child is Node3D:
			_walk(child as Node3D, -1, sk, idx_map)

	skeleton_parent.add_child(sk)
	return sk


## Return a Dictionary mapping bone name → bone index for convenient lookup.
## Useful for animation controllers and IK solvers that need to address bones
## by name without re-walking the scene tree.
static func build_bone_map(skeleton: Skeleton3D) -> Dictionary:
	var map: Dictionary = {}
	for i in range(skeleton.get_bone_count()):
		map[skeleton.get_bone_name(i)] = i
	return map


# ==============================================================================
# Private
# ==============================================================================

## Depth-first pre-order walk.
## Only BoneAnchor nodes produce a bone; all other Node3D types are traversed
## transparently (so MeshInstance3D children are skipped without breaking the
## search for nested BoneAnchors).
static func _walk(
		node       : Node3D,
		parent_idx : int,
		sk         : Skeleton3D,
		idx_map    : Dictionary) -> void:

	if node is BoneAnchor:
		var anchor   := node as BoneAnchor
		var bname    := anchor.bone_name if not anchor.bone_name.is_empty() else node.name
		var bone_idx : int = sk.add_bone(bname)

		if parent_idx >= 0:
			sk.set_bone_parent(bone_idx, parent_idx)

		# Rest pose = local transform of this BoneAnchor in its parent's space.
		# This captures both positional offsets and any orientation baked in
		# (e.g. the PI-on-Z rotation that makes limbs hang downward).
		sk.set_bone_rest(bone_idx, node.transform)

		idx_map[node] = bone_idx

		for child in node.get_children():
			if child is Node3D:
				_walk(child as Node3D, bone_idx, sk, idx_map)
	else:
		# Non-BoneAnchor node — don't create a bone but keep searching
		# children so we don't miss any BoneAnchors nested deeper.
		for child in node.get_children():
			if child is Node3D:
				_walk(child as Node3D, parent_idx, sk, idx_map)
