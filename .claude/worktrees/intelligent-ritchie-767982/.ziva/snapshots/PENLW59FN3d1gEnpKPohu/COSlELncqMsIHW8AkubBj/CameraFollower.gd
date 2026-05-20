class_name CameraFollower
extends Camera3D

@export var follow_offset: Vector3 = Vector3(0.0, 50.0, -12.0)

var _follow_target: Node3D

func set_target(target: Node3D) -> void:
	_follow_target = target

func _process(delta: float) -> void:
	if not _follow_target:
		return
	var target_position = _follow_target.global_transform.origin
	global_transform.origin = target_position + follow_offset
	look_at(target_position, Vector3.UP)
