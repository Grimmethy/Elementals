## Phase 9 test — attach to the root Node3D in test_locomotion_scene.tscn.
## Press F6 to run.
##
## The character walks in-place so you can observe all locomotion components
## without needing a CharacterBody3D or navigation.
##
## Controls:
##   Space       — toggle walking velocity on / off
##   1 / 2 / 3  — switch detail level (SIMPLE / MODERATE / COMPLEX)
##   ↑ / ↓      — increase / decrease walk speed (tweaks the definition copy)
##
## What to confirm:
##   • Arms swing opposite to the contralateral leg (left arm / right leg forward)
##   • Hips bob up/down twice per stride and sway laterally once per stride
##   • Chest leans slightly forward while walking, snaps back when stopped
##   • Stopping smoothly blends all swings back to rest — no sudden snap
##   • Switching detail level mid-walk re-assembles the skeleton and resumes
##     the walk cycle without freezing (LocomotionController reconnects via signal)
extends Node3D

@onready var generator  : CreatureGenerator   = $CreatureGenerator
@onready var controller : LocomotionController = $CreatureGenerator/LocomotionController

var _walking      : bool  = true
var _walk_speed   : float = 1.0   # local copy so we can tweak it live

func _ready() -> void:
	_apply_velocity()
	print("Space = toggle walk | 1/2/3 = detail level | Up/Down = speed")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_SPACE:
			_walking = not _walking
			_apply_velocity()
			print("Walking: ", _walking)
		KEY_1:
			generator.set_detail_level(CreatureDefinition.DetailLevel.SIMPLE)
			print("Detail → SIMPLE")
		KEY_2:
			generator.set_detail_level(CreatureDefinition.DetailLevel.MODERATE)
			print("Detail → MODERATE")
		KEY_3:
			generator.set_detail_level(CreatureDefinition.DetailLevel.COMPLEX)
			print("Detail → COMPLEX")
		KEY_UP:
			_walk_speed = clampf(_walk_speed + 0.25, 0.25, 4.0)
			_apply_velocity()
			print("Walk speed: %.2f" % _walk_speed)
		KEY_DOWN:
			_walk_speed = clampf(_walk_speed - 0.25, 0.25, 4.0)
			_apply_velocity()
			print("Walk speed: %.2f" % _walk_speed)

func _apply_velocity() -> void:
	# Walk "into" the screen (+Z world direction) so arm/leg swing is visible
	# from the default front-facing camera.
	controller.velocity = Vector3(0.0, 0.0, _walk_speed) if _walking else Vector3.ZERO
