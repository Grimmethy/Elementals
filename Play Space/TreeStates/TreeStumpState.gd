class_name TreeStumpState
extends TreeState

func enter() -> void:
	var data = get_state_data()
	if data:
		tree.sprite.texture = data.texture
		tree.sprite.scale = data.scale
		tree.sprite.position.y = data.sprite_y_offset
		if tree.health_component: 
			tree.health_component.bar_offset.y = data.health_bar_y_offset
		tree.timer = data.state_duration
	tree._update_collision()

func update(delta: float) -> void:
	tree.timer -= delta
	if tree.timer <= 0:
		tree.current_state = TreeFeature.State.TREE
		if tree.health_component:
			tree.health_component.current_health = tree.health_component.max_health

func handle_element(element: String, _direction: Vector3) -> bool:
	if element == "water":
		tree.timer *= 0.5
		return true
	if element == "headbutt":
		tree.take_damage(1.0, false)
		# Shake visual
		var tween = tree.create_tween()
		tween.tween_property(tree.sprite, "position:x", 0.1, 0.05)
		tween.tween_property(tree.sprite, "position:x", -0.1, 0.05)
		tween.tween_property(tree.sprite, "position:x", 0, 0.05)
		return true
	if element == "fire":
		tree.take_damage(1.0, true)
		return true
	return false

func die(is_fire: bool) -> void:
	_die_to_stump(is_fire)
