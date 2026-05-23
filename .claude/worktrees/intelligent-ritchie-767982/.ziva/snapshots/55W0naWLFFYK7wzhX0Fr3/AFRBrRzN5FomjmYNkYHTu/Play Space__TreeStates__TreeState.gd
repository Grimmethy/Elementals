class_name TreeState
extends Node

var tree: TreeFeature

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func handle_element(_element: String, _direction: Vector3) -> bool:
	return false

func die(_is_fire: bool) -> void:
	pass

func _die_to_stump(is_fire: bool) -> void:
	# Only play fall sound for full trees dying
	if tree.current_state == TreeFeature.State.TREE and tree.audio_player:
		tree.audio_player.stream = load("res://assets/SoundFiles/Tree fall.mp3")
		tree.audio_player.play()
	
	# If the tile is on fire, we become a burnt stump regardless of how we died
	var parent = tree.get_parent()
	var tile_on_fire = parent is HexTile and parent.tile_type == HexTile.Type.FIRE
	var should_burn = is_fire or tile_on_fire

	if should_burn:
		tree.current_state = TreeFeature.State.BURNT_STUMP
	else:
		tree.current_state = TreeFeature.State.STUMP
	tree.health = tree.MAX_HEALTH

func on_damage(amount: float, is_fire: bool) -> void:
	tree.health -= amount
	tree._show_health()
	if tree.health <= 0:
		die(is_fire)
