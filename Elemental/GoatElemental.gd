class_name GoatElemental
extends Elemental

func _init() -> void:
	element_type = "goat"
	# projectile_scene is left null

func _setup_elemental() -> void:
	# No specific particles for now
	pass

func get_elemental_color() -> Color:
	# A light brown/grey for the goat
	return Color(0.7, 0.6, 0.4)

func _process(delta: float) -> void:
	super._process(delta)
	_update_sprite_flip()

func _update_sprite_flip() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var cam_right = camera.global_transform.basis.x
		var move_dot_right = horizontal_velocity.dot(cam_right)
		
		var body = get_node_or_null("Body") as Sprite3D
		if body:
			# If move_dot_right > 0, it's moving towards screen-right
			# If move_dot_right < 0, it's moving towards screen-left
			# We assume the sprite faces right by default.
			if move_dot_right > 0.1:
				body.flip_h = false
			elif move_dot_right < -0.1:
				body.flip_h = true

func _do_tile_effect(_tile: HexTile) -> void:
	# Goats have no tile effect
	pass

func _launch_projectile() -> void:
	# Projectiles are disabled for goats
	pass

func launch_projectile_at(_target_position: Vector3) -> void:
	# Projectiles are disabled for goats
	pass
