class_name TreeBurntStumpState
extends TreeState

func enter() -> void:
	tree.sprite.texture = tree.TEXTURES[TreeFeature.State.BURNT_STUMP]
	tree.sprite.scale = Vector3.ONE * 1.5
	tree.sprite.position.y = 0.5
	if tree.health_label: tree.health_label.position.y = 2.5
	tree.timer = 10.0
	tree._update_collision()

func update(delta: float) -> void:
	# Burnt stumps don't grow back on their own
	tree.timer = 10.0

func handle_element(element: String, _direction: Vector3) -> bool:
	if element == "water":
		tree.set_state_node(TreeFeature.State.STUMP)
		tree.health = tree.MAX_HEALTH
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
