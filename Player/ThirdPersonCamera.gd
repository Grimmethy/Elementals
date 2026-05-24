class_name ThirdPersonCamera
extends Camera3D

## Orbit-style third-person camera. Activated and deactivated by ThirdPersonMode.
## Yaw  : horizontal orbit around the target (mouse X).
## Pitch : vertical orbit; 0 = level with pivot, positive = camera above looking down.

@export var arm_length: float = 4.0
@export var min_arm_length: float = 1.5
@export var max_arm_length: float = 12.0
@export var pitch_min: float = -10.0
@export var pitch_max: float = 75.0
@export var zoom_speed: float = 0.5
@export var pivot_height: float = 1.0   # Offset above actor origin for the look-at point.

var sensitivity_x: float = 0.3
var sensitivity_y: float = 0.3
var invert_y: bool = false

var _target: Node3D
var _yaw: float = 0.0
var _pitch: float = 20.0
var _current_arm_length: float

func _ready() -> void:
	_current_arm_length = arm_length

func activate(target: Node3D) -> void:
	_target = target
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	make_current()

func deactivate() -> void:
	_target = null
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## Returns the world-space point the center of the screen is aimed at.
## Used by ThirdPersonMode.get_aim_target().
func get_aim_target_world() -> Vector3:
	var viewport := get_viewport()
	var screen_center := viewport.get_visible_rect().size * 0.5
	var ray_origin := project_ray_origin(screen_center)
	var ray_dir := project_ray_normal(screen_center)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	if is_instance_valid(_target) and _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]
	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		return result.position

	return ray_origin + ray_dir * 50.0

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_target):
		return

	if event is InputEventMouseMotion:
		_yaw += event.relative.x * sensitivity_x
		# Mouse up (negative relative.y) increases pitch so camera orbits higher.
		var pitch_input := -event.relative.y if invert_y else event.relative.y
		_pitch = clamp(_pitch - pitch_input * sensitivity_y, pitch_min, pitch_max)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_arm_length = clamp(_current_arm_length - zoom_speed, min_arm_length, max_arm_length)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_arm_length = clamp(_current_arm_length + zoom_speed, min_arm_length, max_arm_length)

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return

	var pivot := _target.global_transform.origin + Vector3(0.0, pivot_height, 0.0)

	var yaw_rad := deg_to_rad(_yaw)
	var pitch_rad := deg_to_rad(_pitch)
	var cos_pitch := cos(pitch_rad)

	# Positive pitch = camera above the pivot plane, looking down.
	var offset := Vector3(
		sin(yaw_rad) * cos_pitch,
		sin(pitch_rad),
		cos(yaw_rad) * cos_pitch
	) * _current_arm_length

	global_transform.origin = pivot + offset

	if not global_transform.origin.is_equal_approx(pivot):
		look_at(pivot, Vector3.UP)
