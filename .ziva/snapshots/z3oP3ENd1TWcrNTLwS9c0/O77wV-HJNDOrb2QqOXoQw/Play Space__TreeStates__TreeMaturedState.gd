class_name TreeMaturedState
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
	tree.grass_spread_timer = tree.species.grass_spread_time if tree.species else 5.0
	tree._update_collision()

func update(delta: float) -> void:
	tree.timer -= delta
	if tree.timer <= 0:
		tree._spawn_pinecone()
		var data = get_state_data()
		tree.timer = data.state_duration if data else 10.0
	
	var parent = tree.get_parent()
	if parent is HexTile:
		if parent.current_state != HexTile.State.GRASS:
			tree.grass_spread_timer -= delta
			if tree.grass_spread_timer <= 0:
				parent.current_state = HexTile.State.GRASS
				tree.grass_spread_timer = tree.species.grass_spread_time if tree.species else 5.0
		else:
			tree.grass_spread_timer = tree.species.grass_spread_time if tree.species else 5.0

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
