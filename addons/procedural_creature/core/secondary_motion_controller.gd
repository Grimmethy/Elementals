class_name SecondaryMotionController
extends Node

## Adds spring-damped secondary motion on top of LocomotionController poses.
##
## ── What it drives ────────────────────────────────────────────────────────────
##   Chest  rotation.z   Idle breath — always active, even when standing still
##   Head   rotation.y   Yaw lag — head momentarily faces old direction on turns
##   Head   rotation.z   Roll lag — head tilts into lateral movement
##   Neck   rotation.z   Follows head roll with extra lag
##
## ── Why only Y and Z axes ────────────────────────────────────────────────────
## LocomotionController owns the X axis on every bone it animates (fore/aft
## swing and forward lean).  Driving only Y and Z here means both controllers
## can run in any order with no conflict and no double-writes.
##
## ── Velocity sync ─────────────────────────────────────────────────────────────
## If a sibling LocomotionController is present the velocity is read from it
## automatically — no manual syncing needed in the test script or character
## controller.  Set `velocity` directly only if there is no sibling loco.
##
## ── Setup ─────────────────────────────────────────────────────────────────────
##   Add as a direct child of CreatureGenerator, alongside LocomotionController.

# ---------------------------------------------------------------------------
# Inner spring — simple critically-underdamped spring-damper
# ---------------------------------------------------------------------------
class Spring:
	var value    : float = 0.0
	var velocity : float = 0.0

	## Advance one frame.  Returns the new value.
	func tick(target: float, stiffness: float, damping: float, dt: float) -> float:
		var force  := (target - value) * stiffness - velocity * damping
		velocity   += force  * dt
		value      += velocity * dt
		return value

	func reset() -> void:
		value    = 0.0
		velocity = 0.0


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

## World-space velocity in m/s.  Auto-filled from a sibling LocomotionController
## if one exists; otherwise set this manually each frame.
var velocity: Vector3 = Vector3.ZERO

@export var enabled: bool = true

@export_group("Head Springs")
@export var head_stiffness : float = 6.0
@export var head_damping   : float = 3.5

@export_group("Neck Spring")
@export var neck_stiffness : float = 10.0
@export var neck_damping   : float = 5.0

@export_group("Breath")
@export var breath_rate      : float = 0.25    ## Hz — cycles per second
@export var breath_amplitude : float = 0.015   ## radians (~0.85 degrees)


# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _gen   : CreatureGenerator   = null
var _loco  : LocomotionController = null   # sibling, if any

var _head  : BoneAnchor = null
var _neck  : BoneAnchor = null
var _chest : BoneAnchor = null

var _head_yaw  : Spring = Spring.new()   # head.rotation.y
var _head_roll : Spring = Spring.new()   # head.rotation.z
var _neck_roll : Spring = Spring.new()   # neck.rotation.z

var _prev_velocity : Vector3 = Vector3.ZERO
var _breath_phase  : float   = 0.0


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_gen = get_parent() as CreatureGenerator
	if _gen == null:
		push_error("SecondaryMotionController must be a direct child of a CreatureGenerator.")
		set_process(false)
		return

	# Auto-find sibling LocomotionController for velocity sync
	for sibling in get_parent().get_children():
		if sibling is LocomotionController and sibling != self:
			_loco = sibling as LocomotionController
			break

	_gen.rebuilt.connect(_refresh_refs)
	_refresh_refs()


func _process(delta: float) -> void:
	if not enabled:
		return

	# Sync velocity from sibling loco if available
	if _loco != null:
		velocity = _loco.velocity

	# ── Idle breath ───────────────────────────────────────────────────────────
	# Always active — the character breathes even when standing still.
	# Drives chest.rotation.z (side wobble) at tiny amplitude so it doesn't
	# conflict with LocomotionController's chest.rotation.x (forward lean).
	_breath_phase = fmod(_breath_phase + delta * TAU * breath_rate, TAU)
	if _chest != null:
		_chest.rotation.z = sin(_breath_phase) * breath_amplitude

	if _gen.definition == null:
		return

	# ── Convert velocity to generator-local space ─────────────────────────────
	# This makes the lag correct regardless of which direction the generator
	# node is facing in the world.
	var basis_inv  := _gen.global_transform.basis.inverse()
	var local_vel  := basis_inv * velocity
	var local_prev := basis_inv * _prev_velocity
	var accel      := (local_vel - local_prev) / maxf(delta, 0.001)
	_prev_velocity  = velocity

	# ── Spring targets ────────────────────────────────────────────────────────
	# Head yaw: lag in the opposite direction of lateral movement.
	# Head roll: tilt into the lateral movement (like a motorbike lean).
	# Acceleration spikes at the moment of direction change give the snap feel.
	var target_yaw  := -local_vel.x * 0.12  - accel.x * 0.008
	var target_roll :=  local_vel.x * 0.08  + accel.x * 0.005

	# ── Drive bones ───────────────────────────────────────────────────────────
	if _head != null:
		_head.rotation.y = _head_yaw.tick( target_yaw,           head_stiffness, head_damping, delta)
		_head.rotation.z = _head_roll.tick(target_roll,           head_stiffness, head_damping, delta)

	if _neck != null:
		_neck.rotation.z = _neck_roll.tick(target_roll * 0.5,    neck_stiffness, neck_damping, delta)


# ==============================================================================
# Private helpers
# ==============================================================================

func _refresh_refs() -> void:
	var rig := _gen.get_node_or_null("_CreatureRig") as Node3D
	if rig == null:
		_head = null; _neck = null; _chest = null
		_head_yaw.reset(); _head_roll.reset(); _neck_roll.reset()
		return

	_head  = rig.find_child("Head",  true, false) as BoneAnchor
	_neck  = rig.find_child("Neck",  true, false) as BoneAnchor
	_chest = rig.find_child("Chest", true, false) as BoneAnchor

	# Reset spring state so there's no pop when the skeleton is rebuilt
	_head_yaw.reset(); _head_roll.reset(); _neck_roll.reset()
	_prev_velocity = Vector3.ZERO
