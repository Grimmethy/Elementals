class_name TreePineconeState
extends TreeState

func enter() -> void:
	tree.sprite.texture = tree.TEXTURES[TreeFeature.State.PINECONE]
	tree.sprite.scale = Vector3.ONE * 1.0
	tree.sprite.position.y = 0.2
	if tree.health_component: tree.health_component.bar_offset.y = 1.0
	tree.timer = 10.0
	tree._update_collision()

func update(delta: float) -> void:
	if tree.is_moving:
		tree._handle_movement(delta)
		return
	
	tree.timer -= delta
	if tree.timer <= 0:
		if not tree._is_on_tree_tile():
			tree.current_state = TreeFeature.State.SAPLING
		else:
			tree.timer = 10.0

func handle_element(element: String, direction: Vector3) -> bool:
	if element == "water" or element == "headbutt":
		tree._push_pinecone(direction)
		return true
	if element == "fire":
		tree.take_damage(5.0, true)
		return true
	return false

func die(_is_fire: bool) -> void:
	tree.queue_free()
