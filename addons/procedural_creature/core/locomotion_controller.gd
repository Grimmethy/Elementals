class_name LocomotionController
extends Node

## Drives the parent CreatureGenerator's BoneAnchor hierarchy with procedural
## walk animation.  No keyframes — all motion is derived from a single phase
## scalar and the CreatureDefinition's parameters.
##
## ── Why BoneAnchors, not Skeleton3D ──────────────────────────────────────────
## The MeshInstance3D segments are children of BoneAnchor nodes in the scene
## tree.  They are NOT skinned to the Skeleton3D (that is a Phase 12 concern).
## Skeleton3D.set_bone_pose_* only affects skinned vertices; it has no effect on
## scene-node children.  Animating the BoneAnchor transforms directly causes
## the mesh children to follow through normal parent-child propagation.
##
## ── Setup ─────────────────────────────────────────────────────────────────────
##   1. Add as a DIRECT child of a CreatureGenerator node.
##   2. Set `velocity` every frame from your CharacterBody3D (world-space m/s).
##   3. Done — walk blend, phase, and all bone rotations update automatically.
##
## ── Rotation convention ───────────────────────────────────────────────────────
## Spine bones (Midriff, Chest, Neck, Head) have IDENTITY rest rotation.
##   rotation.x > 0  →  +Y tips toward +Z  →  FORWARD lean  ✓
##
## Limb root bones (ShoulderL/R, HipJointL/R) have rotation.z = PI at rest.
##   rotation.x > 0  →  limb tip moves toward world −Z  →  BACKWARD swing
##   rotation.x < 0  →  limb tip moves toward world +Z  →  FORWARD swing
##
## ── Natural gait phase ────────────────────────────────────────────────────────
##   sin(ph)       → left leg BACK  at ph = π/2, FORWARD at ph = 3π/2
##   sin(ph + PI)  → right leg BACK at ph = π/2  (contralateral)
##   Arms are opposite: ShoulderL = sin(ph+π), ShoulderR = sin(ph)

## World-space velocity in m/s.  Set every frame from your character controller.
var velocity: Vector3 = Vector3.ZERO

@export var enabled: bool = true


# ---------------------------------------------------------------------------
# Cached BoneAnchor references — rebuilt on every generator rebuild
# ---------------------------------------------------------------------------
var _gen        : CreatureGenerator = null
var _hips       : BoneAnchor = null
var _midriff    : BoneAnchor = null
var _chest      : BoneAnchor = null
var _head       : BoneAnchor = null
var _shoulder_l : BoneAnchor = null
var _shoulder_r : BoneAnchor = null
var _hip_l      : BoneAnchor = null
var _hip_r      : BoneAnchor = null

var _phase      : float = 0.0
var _walk_blend : float = 0.0


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_gen = get_parent() as CreatureGenerator
	if _gen == null:
		push_error("LocomotionController must be a direct child of a CreatureGenerator.")
		set_process(false)
		return
	_gen.rebuilt.connect(_refresh_refs)
	_refresh_refs()


func _process(delta: float) -> void:
	if not enabled or _hips == null:
		return
	var def := _gen.definition
	if def == null:
		return

	var speed := velocity.length()

	# Phase tempo: 1.4 strides/sec at walk_speed = 1.0 (~natural human cadence)
	_phase = fmod(_phase + delta * TAU * def.walk_speed * 1.4, TAU)

	# Blend in/out smoothly so the character doesn't snap to rest when stopping
	var target_blend := clampf(speed / maxf(def.walk_speed, 0.01), 0.0, 1.0) \
		if speed > 0.02 else 0.0
	_walk_blend = lerpf(_walk_blend, target_blend, delta * 8.0)

	_animate(def)


# ==============================================================================
# Animation — directly drives BoneAnchor transforms
# ==============================================================================

func _animate(def: CreatureDefinition) -> void:
	var b  := _walk_blend
	var ph := _phase

	# All amplitudes multiply by blend — everything fades cleanly to rest at b = 0
	var arm_swing := 0.35 * b
	var leg_swing := 0.28 * b
	var hip_bob   := def.bounce_amount * b
	var hip_sway  := def.bounce_amount * 0.6 * b
	var lean      := clampf(velocity.length() / maxf(def.walk_speed, 0.01), 0.0, 1.0) * 0.12 * b

	# ── Hips position ─────────────────────────────────────────────────────────
	# Restore the ShapeAssembler rest Y (leg_length) then add bob and sway.
	# cos(2ph) peaks twice per stride; sin(ph) sways once per stride.
	_hips.position = Vector3(
		sin(ph)       * hip_sway,
		def.leg_length + cos(ph * 2.0) * hip_bob,
		0.0
	)

	# ── Spine lean ────────────────────────────────────────────────────────────
	# IDENTITY-rest bones: rotation.x > 0 tilts +Y toward +Z (forward lean).
	if _chest:
		_chest.rotation.x   = lean
	if _midriff:
		_midriff.rotation.x = lean * 0.5

	# ── Legs ──────────────────────────────────────────────────────────────────
	# PI-on-Z rest bones: rotation.x > 0 → limb swings backward.
	# sin(ph) for left, sin(ph+π) for right → contralateral stride.
	if _hip_l:
		_hip_l.rotation.x = sin(ph)      * leg_swing
	if _hip_r:
		_hip_r.rotation.x = sin(ph + PI) * leg_swing

	# ── Arms ──────────────────────────────────────────────────────────────────
	# Opposite phase to contralateral leg (natural human gait).
	if _shoulder_l:
		_shoulder_l.rotation.x = sin(ph + PI) * arm_swing
	if _shoulder_r:
		_shoulder_r.rotation.x = sin(ph)      * arm_swing

	# ── Head ──────────────────────────────────────────────────────────────────
	# Subtle nod at 2× stride frequency — positive = tips forward.
	if _head:
		_head.rotation.x = sin(ph * 2.0) * 0.04 * b


# ==============================================================================
# Private helpers
# ==============================================================================

func _refresh_refs() -> void:
	var rig := _gen.get_node_or_null("_CreatureRig") as Node3D
	if rig == null:
		_clear_refs()
		return
	# find_child(name, recursive=true, owned=false) — nodes are unowned (procedural)
	_hips       = rig.find_child("Hips",       true, false) as BoneAnchor
	_midriff    = rig.find_child("Midriff",    true, false) as BoneAnchor
	_chest      = rig.find_child("Chest",      true, false) as BoneAnchor
	_head       = rig.find_child("Head",       true, false) as BoneAnchor
	_shoulder_l = rig.find_child("ShoulderL",  true, false) as BoneAnchor
	_shoulder_r = rig.find_child("ShoulderR",  true, false) as BoneAnchor
	_hip_l      = rig.find_child("HipJointL",  true, false) as BoneAnchor
	_hip_r      = rig.find_child("HipJointR",  true, false) as BoneAnchor


func _clear_refs() -> void:
	_hips = null; _midriff = null; _chest = null; _head = null
	_shoulder_l = null; _shoulder_r = null; _hip_l = null; _hip_r = null
