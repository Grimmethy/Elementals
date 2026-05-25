class_name RagdollController
extends Node

## Simulated ragdoll for PCF creatures.
##
## Place as a direct child of CreatureGenerator, alongside LocomotionController
## and SecondaryMotionController.
##
## ── Usage ─────────────────────────────────────────────────────────────────────
##   1. Call activate(impulse_strength, host) when the actor dies.
##      `host` is the CharacterBody3D — ragdoll waits for it to be on_floor()
##      before declaring the pose "settled".
##   2. The controller turns itself off after settling (or after MAX_RAGDOLL_TIME
##      seconds as a safety fallback) and emits the `settled` signal.
##
## ── What it drives ────────────────────────────────────────────────────────────
##   Every BoneAnchor found under _CreatureRig gets:
##     • A random angular impulse on all three local axes (scaled by impulse_strength)
##     • A per-bone gravity torque on the local X axis  (causes organic drooping)
##     • Exponential angular damping that brings motion to rest
##   Bone rotations are clamped to ±2π to prevent runaway spinning.
##
## ── Why local-space ────────────────────────────────────────────────────────────
##   Driving BoneAnchor.rotation (local) is the same approach used by
##   LocomotionController and SecondaryMotionController — it propagates through
##   the scene tree so mesh children follow automatically.
##   World-gravity accuracy is traded for simplicity; the result looks organic
##   because local-gravity still creates directional drooping per limb.

signal settled

## Set false to halt simulation externally (e.g. on resurrect).
@export var enabled : bool = false

# ── Simulation tuning ─────────────────────────────────────────────────────────
## Exponential angular drag coefficient (rad/s per rad/s, applied per second).
## Higher = bones stop faster.  2.5 ≈ 92 % velocity loss per second.
const DAMPING          : float = 2.5

## |angular_velocity|² below this value → bone considered "at rest".
const SETTLE_THRESHOLD : float = 0.005

## Number of consecutive frames all bones must be at rest before freeze() fires.
## At 60 fps: 24 frames ≈ 0.4 s of confirmed stillness.
const SETTLE_FRAMES    : int   = 24

## Absolute time limit; freeze() is forced after this many seconds even if
## bones haven't fully settled (safety net for degenerate configurations).
const MAX_RAGDOLL_TIME : float = 1.0

## Clamp applied to each rotation axis to stop bones spinning past one full turn.
const MAX_BONE_ROT     : float = TAU

# ── Per-bone gravity torque (rad/s²) on local X axis ─────────────────────────
## Positive X → tip toward +Z in the bone's local frame.
## Spine bones (identity rest): positive X = forward lean = natural slump.
## Limb root bones (rotation.z = PI at rest): positive X = backward swing;
##   use negative values so arms/legs drop outward/downward naturally.
const _GRAVITY_BIAS : Dictionary = {
	"Hips"      :  0.0,   # position handled by CharacterBody3D; no rotation bias
	"Midriff"   :  1.2,
	"Chest"     :  1.0,
	"Neck"      :  0.6,
	"Head"      :  1.8,   # heaviest — drops furthest
	"ShoulderL" : -1.2,   # PI-Z rest: negative = arm drops outward
	"ShoulderR" : -1.2,
	"ForearmL"  : -1.8,
	"ForearmR"  : -1.8,
	"HipJointL" :  0.6,
	"HipJointR" :  0.6,
	"ShinL"     :  0.8,
	"ShinR"     :  0.8,
}
const _DEFAULT_GRAVITY_BIAS : float = 0.8


# ── Internal per-bone simulation state ───────────────────────────────────────
class _BoneSim:
	var anchor       : BoneAnchor
	var ang_vel      : Vector3 = Vector3.ZERO
	var gravity_bias : float   = 0.8


var _sims         : Array[_BoneSim] = []
var _gen          : CreatureGenerator = null
var _host         : CharacterBody3D   = null   ## set in activate(); null = no floor check
var _settle_count : int   = 0
var _elapsed      : float = 0.0
var is_settled    : bool  = false


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_gen = get_parent() as CreatureGenerator
	if _gen == null:
		push_error("RagdollController must be a direct child of a CreatureGenerator.")
	set_process(false)


# ==============================================================================
# Public API
# ==============================================================================

## Activate the ragdoll.
##
## impulse_strength — magnitude of the initial angular velocity burst.
##   1.0  = gentle wobble,  1.5  = typical death throw,  3.0+ = dramatic launch
##
## host — optional CharacterBody3D whose is_on_floor() is checked before the
##   pose is frozen.  Pass null to settle on angular velocity alone.
func activate(impulse_strength: float = 1.5, host: CharacterBody3D = null) -> void:
	if _gen == null:
		return
	var rig := _gen.get_node_or_null("_CreatureRig") as Node3D
	if rig == null:
		push_warning("RagdollController.activate — _CreatureRig not found; was CreatureGenerator built?")
		return

	_host         = host
	_settle_count = 0
	_elapsed      = 0.0
	is_settled    = false
	_sims.clear()

	_collect_anchors(rig, impulse_strength)

	if _sims.is_empty():
		push_warning("RagdollController.activate — no BoneAnchors found in rig.")
		return

	enabled = true
	set_process(true)


## Immediately stop simulation and hold the current pose.
## Emits `settled`.  Safe to call more than once.
func freeze() -> void:
	enabled    = false
	is_settled = true
	set_process(false)
	settled.emit()


# ==============================================================================
# Simulation
# ==============================================================================

func _process(delta: float) -> void:
	if not enabled:
		return

	# ── Safety timeout ────────────────────────────────────────────────────────
	_elapsed += delta
	if _elapsed >= MAX_RAGDOLL_TIME:
		freeze()
		return

	# ── Per-bone physics ──────────────────────────────────────────────────────
	var all_angular_still := true

	for sim in _sims:
		if not is_instance_valid(sim.anchor):
			continue

		# Gravity torque on the bone's local X axis (causes organic drooping).
		sim.ang_vel.x += sim.gravity_bias * delta

		# Exponential angular drag — energy drains out over time.
		sim.ang_vel -= sim.ang_vel * (DAMPING * delta)

		# Integrate: rotate the anchor by angular velocity.
		sim.anchor.rotation += sim.ang_vel * delta

		# Clamp to prevent runaway spinning (one full revolution max per axis).
		sim.anchor.rotation.x = clampf(sim.anchor.rotation.x, -MAX_BONE_ROT, MAX_BONE_ROT)
		sim.anchor.rotation.y = clampf(sim.anchor.rotation.y, -MAX_BONE_ROT, MAX_BONE_ROT)
		sim.anchor.rotation.z = clampf(sim.anchor.rotation.z, -MAX_BONE_ROT, MAX_BONE_ROT)

		if sim.ang_vel.length_squared() > SETTLE_THRESHOLD:
			all_angular_still = false

	# ── Settle check ──────────────────────────────────────────────────────────
	# Require both angular stillness AND (optionally) the host being on the floor.
	# This means the pose locks in exactly when the body touches the ground.
	var on_ground := (_host == null) or _host.is_on_floor()

	if all_angular_still and on_ground:
		_settle_count += 1
		if _settle_count >= SETTLE_FRAMES:
			freeze()
	else:
		_settle_count = 0


# ==============================================================================
# Private helpers
# ==============================================================================

## Recursively walk the rig hierarchy, create a _BoneSim for every BoneAnchor.
func _collect_anchors(node: Node, impulse_strength: float) -> void:
	for child in node.get_children():
		if child is BoneAnchor:
			var sim          := _BoneSim.new()
			sim.anchor        = child as BoneAnchor
			sim.gravity_bias  = _GRAVITY_BIAS.get(sim.anchor.bone_name, _DEFAULT_GRAVITY_BIAS)

			# Random angular impulse — strongest on X (fore/aft) and Z (side twist),
			# subtler on Y (axial spin) so bones look floppy rather than drill-like.
			sim.ang_vel = Vector3(
				randf_range(-1.0,  1.0),
				randf_range(-0.3,  0.3),
				randf_range(-0.8,  0.8)
			) * impulse_strength

			_sims.append(sim)

		# Recurse into all children (BoneAnchors nest inside other BoneAnchors;
		# MeshInstance3D siblings are leaves with no children so cost is minimal).
		if child.get_child_count() > 0:
			_collect_anchors(child, impulse_strength)
