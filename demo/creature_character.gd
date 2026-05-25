## Reusable CharacterBody3D controller that drives a PCF creature.
##
## ── Scene structure ────────────────────────────────────────────────────────────
##   CharacterBody3D  (this script)
##     CollisionShape3D  (CapsuleShape3D  radius=0.3  height=1.8)
##     CreatureGenerator (Node3D)
##       LocomotionController
##       SecondaryMotionController
##
## ── Controls ──────────────────────────────────────────────────────────────────
##   W / ↑   Move forward  (world −Z)
##   S / ↓   Move backward (world +Z)
##   A / ←   Move left     (world −X)
##   D / →   Move right    (world +X)
##   Space   Jump
##
## ── Data flow ─────────────────────────────────────────────────────────────────
##   CharacterBody3D.velocity  →  LocomotionController.velocity  (set each frame)
##   SecondaryMotionController auto-reads velocity from its sibling Loco.
##
## ── Facing ────────────────────────────────────────────────────────────────────
##   CreatureGenerator rotates to face the horizontal velocity direction.
##   CharacterBody3D itself never rotates — the physics capsule stays upright.
extends CharacterBody3D

@export_group("Movement")
@export var move_speed   : float = 4.0    ## m/s horizontal top speed
@export var turn_speed   : float = 10.0   ## rot/s — how fast the visual turns to face velocity
@export var jump_velocity: float = 5.0    ## m/s initial upward impulse

var gravity: float = ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8) as float

@onready var generator  : CreatureGenerator    = $CreatureGenerator
@onready var controller : LocomotionController = $CreatureGenerator/LocomotionController


# ==============================================================================
# Physics loop
# ==============================================================================

func _physics_process(delta: float) -> void:
	# ── Gravity ────────────────────────────────────────────────────────────────
	if not is_on_floor():
		velocity.y -= gravity * delta

	# ── Jump ──────────────────────────────────────────────────────────────────
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	# ── Horizontal input ──────────────────────────────────────────────────────
	# Movement is world-axis aligned so it works without rotating the rigid body.
	# W/↑ → −Z  |  S/↓ → +Z  |  A/← → −X  |  D/→ → +X
	var input_x := Input.get_axis("ui_left",  "ui_right")   # A=−1  D=+1
	var input_z := Input.get_axis("ui_up",    "ui_down")    # W=−1  S=+1
	var wish_dir := Vector3(input_x, 0.0, input_z)
	if wish_dir.length_squared() > 1.0:
		wish_dir = wish_dir.normalized()

	velocity.x = wish_dir.x * move_speed
	velocity.z = wish_dir.z * move_speed

	move_and_slide()

	# ── Rotate CreatureGenerator to face movement direction (smooth) ──────────
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length_squared() > 0.04:
		# Build a target transform that faces horiz, then slerp toward it.
		# global_transform.looking_at(pos + dir) → -Z axis faces dir.
		var look_at_pos := generator.global_position + horiz
		var target := generator.global_transform.looking_at(look_at_pos, Vector3.UP)
		generator.global_transform = generator.global_transform.interpolate_with(
			target, minf(delta * turn_speed, 1.0)
		)

	# ── Sync velocity to the locomotion controller ────────────────────────────
	# Pass world-space velocity so the loco controller can calculate speed and
	# the secondary controller can compute lateral lag in local space.
	controller.velocity = velocity
