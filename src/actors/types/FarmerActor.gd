class_name FarmerActor
extends Actor

## How fast the creature visual rotates to face the movement direction (rad/s
## equivalent — passed as weight to interpolate_with, so 10 = snappy, 4 = lazy).
const TURN_SPEED : float = 8.0

@onready var _generator  : CreatureGenerator         = get_node_or_null("CreatureGenerator")
@onready var _loco       : LocomotionController      = get_node_or_null("CreatureGenerator/LocomotionController")
@onready var _secondary  : SecondaryMotionController = get_node_or_null("CreatureGenerator/SecondaryMotionController")
@onready var _ragdoll    : RagdollController         = get_node_or_null("CreatureGenerator/RagdollController")

func _init() -> void:
	element_type = "farmer"
	should_bob = false
	max_hp = 4
	move_speed = 3.0

func _ready() -> void:
	super._ready()
	faction_component.setup(FactionComponent.Faction.FARMSTEAD)
	# Commoner stats (0 = base multiplier)
	ability_scores_component.strength = 0
	ability_scores_component.dexterity = 0
	ability_scores_component.constitution = 0
	ability_scores_component.intelligence = 0
	ability_scores_component.wisdom = 0
	ability_scores_component.charisma = 0

func _physics_process(delta: float) -> void:
	# ── Ragdoll gravity pass ───────────────────────────────────────────────────
	# Actor._physics_process returns immediately when is_dead, so gravity and
	# move_and_slide stop running.  We take them over here so the body falls to
	# the floor while the ragdoll bone simulation plays out.
	# Once the ragdoll settles (or the safety timeout fires), we stop entirely.
	if is_dead:
		if _ragdoll != null and _ragdoll.enabled:
			if not is_on_floor():
				velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * delta
			else:
				# Bleed off any residual horizontal slide so we don't drift.
				velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
				velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
			move_and_slide()
		return

	super._physics_process(delta)   # applies gravity + move_and_slide()

	if _loco == null:
		return

	# ── Sync velocity → LocomotionController ─────────────────────────────────
	# velocity is the post-collision value from move_and_slide().
	# SecondaryMotionController auto-reads from the sibling loco — no extra call.
	_loco.velocity = velocity

	# ── Rotate CreatureGenerator to face movement direction ───────────────────
	# Only update when actually moving to avoid jitter at rest.
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length_squared() > 0.04 and _generator != null:
		var look_target := _generator.global_transform.looking_at(
			_generator.global_position + horiz, Vector3.UP
		)
		_generator.global_transform = _generator.global_transform.interpolate_with(
			look_target, minf(delta * TURN_SPEED, 1.0)
		)

func die() -> void:
	super.die()   # sets is_dead, disables MovementComponent, calls visual_component.fall_over()

	# ── Collision shape: keep active during ragdoll ───────────────────────────
	# _disable_living_components() queues collision.set_deferred("disabled", true).
	# We immediately queue a counter-call so the shape stays enabled while the
	# ragdoll needs is_on_floor() and move_and_slide() to work.
	# When the ragdoll settles, _on_ragdoll_settled() disables it for real.
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", false)

	# ── Stop PCF walk animation ───────────────────────────────────────────────
	# _disable_living_components() has no knowledge of the PCF controllers, so
	# we halt them explicitly before the ragdoll takes ownership of the bones.
	if _loco != null:
		_loco.velocity = Vector3.ZERO
		_loco.enabled  = false
	if _secondary != null:
		_secondary.enabled = false

	# ── Ragdoll ───────────────────────────────────────────────────────────────
	# Activate bone-level ragdoll.  Each BoneAnchor gets a random angular impulse
	# that decays under damping.  Passing `self` tells the controller to wait
	# until is_on_floor() before locking the final pose ("settles on ground").
	if _ragdoll != null:
		_ragdoll.activate(1.5, self)
		_ragdoll.settled.connect(_on_ragdoll_settled, CONNECT_ONE_SHOT)

	# ── Body tip-over ─────────────────────────────────────────────────────────
	# Rotate the entire generator sideways so the body visually falls over.
	# Bones flail on top of this in their local space, combining for a full
	# ragdoll look: body tips while limbs tumble independently.
	if _generator != null:
		var tween := create_tween()
		tween.tween_property(_generator, "rotation:z", PI / 2.0, 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_ragdoll_settled() -> void:
	# Ragdoll has frozen — now it's safe to disable the collision shape.
	# The body is on the floor and fully still, so we no longer need physics.
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", true)

func _create_controller() -> ActorAIController:
	return FarmerController.new()

func get_actor_color() -> Color:
	return Color.YELLOW_GREEN

func herd_goat(goat: GoatActor) -> void:
	if goat.has_method("_scream"):
		goat.call("_scream")
	if goat.movement_component and controller:
		var center = (controller as FarmerController).farm_center
		var push_dir = (center - goat.global_position).normalized()
		goat.movement_component.apply_external_force(push_dir * 5.0)
