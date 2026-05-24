class_name ThirdPersonMode
extends ControllerModeBase

var _tp_camera: ThirdPersonCamera = null
var _old_camera: Camera3D = null

func on_mode_entered(actor: Node3D, current_cam: Camera3D) -> void:
	# Stash and disable the existing camera so it stops processing.
	_old_camera = current_cam
	if is_instance_valid(_old_camera):
		_old_camera.process_mode = Node.PROCESS_MODE_DISABLED

	# Add ThirdPersonCamera as a sibling of the actor, reusing it if it already exists.
	var parent := actor.get_parent()
	if not parent:
		return

	_tp_camera = parent.get_node_or_null("ThirdPersonCamera") as ThirdPersonCamera
	if not _tp_camera:
		_tp_camera = ThirdPersonCamera.new()
		_tp_camera.name = "ThirdPersonCamera"
		parent.add_child(_tp_camera)

	_tp_camera.sensitivity_x = sensitivity_x
	_tp_camera.sensitivity_y = sensitivity_y
	_tp_camera.invert_y = invert_y
	_tp_camera.process_mode = Node.PROCESS_MODE_INHERIT
	_tp_camera.activate(actor)

func on_mode_exited(_actor: Node3D, _camera: Camera3D) -> void:
	if is_instance_valid(_tp_camera):
		_tp_camera.deactivate()
		_tp_camera.process_mode = Node.PROCESS_MODE_DISABLED

	if is_instance_valid(_old_camera):
		_old_camera.process_mode = Node.PROCESS_MODE_INHERIT
		_old_camera.make_current()

	_tp_camera = null
	_old_camera = null

func process_input(actor: Node3D, camera: Camera3D, delta: float) -> void:
	var tp_cam := camera as ThirdPersonCamera
	if not is_instance_valid(tp_cam):
		return

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	# Camera-relative movement — identical math to TwinStickMode / original ActorController.
	var cam_basis := tp_cam.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction := (forward * (-input_dir.y) + right * input_dir.x).normalized()

	var mc := actor.get("movement_component") as MovementComponent
	if mc:
		mc.move(direction, delta)
		mc.apply_gravity(delta)

	if Input.is_key_pressed(KEY_SPACE) and mc:
		mc.jump()

func get_aim_target(actor: Node3D, camera: Camera3D) -> Vector3:
	var tp_cam := camera as ThirdPersonCamera
	if is_instance_valid(tp_cam):
		return tp_cam.get_aim_target_world()
	return actor.global_position if is_instance_valid(actor) else Vector3.ZERO
