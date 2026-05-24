class_name ControllerModeBase
extends Resource

@export var sensitivity_x: float = 0.3
@export var sensitivity_y: float = 0.3
@export var invert_y: bool = false

func process_input(_actor: Node3D, _camera: Camera3D, _delta: float) -> void:
	pass

func get_aim_target(_actor: Node3D, _camera: Camera3D) -> Vector3:
	return Vector3.ZERO

func on_mode_entered(_actor: Node3D, _camera: Camera3D) -> void:
	pass

func on_mode_exited(_actor: Node3D, _camera: Camera3D) -> void:
	pass
