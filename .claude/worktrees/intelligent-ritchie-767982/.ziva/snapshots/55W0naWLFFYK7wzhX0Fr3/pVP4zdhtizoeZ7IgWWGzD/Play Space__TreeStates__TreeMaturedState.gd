class_name TreeMaturedState
extends TreeState

func enter() -> void:
	tree.sprite.texture = tree.TEXTURES[TreeFeature.State.TREE]
	tree.sprite.scale = Vector3.ONE * 4.5
	tree.sprite.position.y = 2.0
	if tree.health_label: tree.health_label.position.y = 7.0
	tree.timer = 10.0
	tree.grass_spread_timer = 5.0
	tree._update_collision()

func update(delta: float) -> void:
	tree.timer -= delta
	if tree.timer <= 0:
		tree._spawn_pinecone()
		tree.timer = 10.0
	
	var parent = tree.get_parent()
	if parent is HexTile:
		if parent.current_state != HexTile.State.GRASS:
			tree.grass_spread_timer -= delta
			if tree.grass_spread_timer <= 0:
				parent.current_state = HexTile.State.GRASS
				tree.grass_spread_timer = 5.0
		else:
			tree.grass_spread_timer = 5.0

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
