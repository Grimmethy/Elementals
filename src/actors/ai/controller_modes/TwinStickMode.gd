class_name TwinStickMode
extends ControllerModeBase

var _capture_c_was_pressed: bool = false

func process_input(actor: Node3D, camera: Camera3D, delta: float) -> void:
	if not camera:
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

	var cam_basis := camera.global_transform.basis
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

	# Fallback polling for C key — catches cases where _unhandled_input is consumed upstream.
	var capture_pressed := Input.is_key_pressed(KEY_C)
	if capture_pressed and not _capture_c_was_pressed:
		var wc := actor.get("weapon_component") as WeaponComponent
		if is_instance_valid(wc) and wc.has_method("use_net_close_at"):
			wc.use_net_close_at(actor.global_position)
	_capture_c_was_pressed = capture_pressed

func get_aim_target(actor: Node3D, camera: Camera3D) -> Vector3:
	if not camera or not is_instance_valid(actor):
		return Vector3.ZERO

	var mouse_pos := camera.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var space_state := actor.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		return result.position

	if abs(ray_dir.y) < 1e-6:
		return Vector3.ZERO

	var t := -ray_origin.y / ray_dir.y
	return ray_origin + ray_dir * t
