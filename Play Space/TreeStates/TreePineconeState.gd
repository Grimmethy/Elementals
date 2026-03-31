class_name TreePineconeState
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
	if tree.is_moving:
		tree._handle_movement(delta)
		return
	
	tree.timer -= delta
	if tree.timer <= 0:
		if not tree._is_on_tree_tile():
			tree.current_state = TreeFeature.State.SAPLING
		else:
			var data = get_state_data()
			tree.timer = data.state_duration if data else 10.0

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
