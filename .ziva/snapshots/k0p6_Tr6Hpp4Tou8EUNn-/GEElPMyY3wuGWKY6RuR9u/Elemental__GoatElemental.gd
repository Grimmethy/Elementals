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

func _unhandled_input(event: InputEvent) -> void:
	if is_controlled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_scream()

func _scream() -> void:
	print("Goat is screaming!")
	var player = get_node_or_null("ScreamPlayer") as AudioStreamPlayer3D
	if player and player.stream:
		player.play()
	
	_show_scream_visual()

func _show_scream_visual() -> void:
	var sprite = Sprite3D.new()
	# Use the newly generated comic book bubble
	var texture_path = "res://assets/generated/scream_bubble_frame_0_1774821924.png"
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
		sprite.pixel_size = 0.02 # Slightly larger for comic effect
	else:
		print("Warning: Scream bubble texture not found at ", texture_path)
		_show_scream_text()
		return
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Vector3(0, 1.6, 0.1) # Positioned above the head
	sprite.modulate = Color.WHITE
	add_child(sprite)
	
	# Comic book style pop-in animation
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	# Pop in quickly with a little bounce
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2, 0.15)
	
	# Shake effect
	for i in range(4):
		var shake_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
		tween.tween_property(sprite, "position", Vector3(0, 1.6, 0.1) + shake_offset, 0.05)
	
	# Return to center and then float/fade
	tween.tween_property(sprite, "position", Vector3(0, 1.6, 0.1), 0.05)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", 2.2, 0.4).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _show_scream_text() -> void:
	var label = Label3D.new()
	label.text = "BAAAAAA!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.5, 0)
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", 2.5, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func launch_projectile_at(_target_position: Vector3) -> void:
	# Projectiles are disabled for goats
	pass
