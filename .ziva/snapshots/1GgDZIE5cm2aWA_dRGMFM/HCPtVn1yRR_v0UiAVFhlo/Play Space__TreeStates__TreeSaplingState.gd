class_name TreeSaplingState
extends TreeState

func enter() -> void:
	tree.sprite.texture = tree.TEXTURES[TreeFeature.State.SAPLING]
	tree.sprite.scale = Vector3.ONE * 1.5
	tree.sprite.position.y = 1.0
	if tree.health_component: tree.health_component.bar_offset.y = 2.5
	tree.timer = 10.0
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
	if element == "fire":
		tree.take_damage(5.0, true)
		return true
	return false

func die(_is_fire: bool) -> void:
	tree.queue_free()
