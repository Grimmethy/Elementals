## Test scene root — attach to the root Node3D in test_character_scene.tscn.
## Press F6 to run.
##
## Controls:  W/A/S/D or Arrows = move   Space = jump
##
## What to confirm:
##   • Character walks, hips bob, arms swing opposite to legs
##   • Head tilts into lateral acceleration (SecondaryMotionController)
##   • Generator rotates smoothly to face movement direction
##   • Stopping blends all swings back to rest pose without snapping
##   • Jumping knocks the secondary motion springs — head snaps slightly on land
extends Node3D

@onready var _player : CharacterBody3D = $Player
@onready var _camera : Camera3D        = $Camera3D

## World-space offset from the player that the camera tries to maintain.
const CAM_OFFSET     := Vector3(0.0, 3.5, 7.0)
## World-space point the camera looks at, relative to the player's origin.
const CAM_LOOK_LIFT  := Vector3(0.0, 1.0, 0.0)
## Follow smoothness — higher = snappier camera
const CAM_LERP_SPEED := 6.0


func _ready() -> void:
	print("WASD / Arrows = move  |  Space = jump")


func _process(delta: float) -> void:
	# Smooth-follow the player. The camera lerps toward the offset position and
	# always looks at a point slightly above the player's feet (torso height).
	var target_pos := _player.global_position + CAM_OFFSET
	_camera.global_position = _camera.global_position.lerp(
		target_pos, delta * CAM_LERP_SPEED
	)
	_camera.look_at(_player.global_position + CAM_LOOK_LIFT, Vector3.UP)
