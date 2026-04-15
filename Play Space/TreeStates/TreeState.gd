class_name TreeState
extends Node

var tree: TreeFeature

func get_state_data() -> TreeStateData:
	if not tree.species: return null
	match tree.current_state:
		TreeFeature.State.PINECONE: return tree.species.pinecone_data
		TreeFeature.State.SAPLING: return tree.species.sapling_data
		TreeFeature.State.TREE: return tree.species.matured_data
		TreeFeature.State.STUMP: return tree.species.stump_data
		TreeFeature.State.BURNT_STUMP: return tree.species.burnt_stump_data
	return null

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
	var tile_on_fire = tree.tile and tree.tile.tile_type == TileConstants.Type.FIRE
	var should_burn = is_fire or tile_on_fire

	if should_burn:
		tree.current_state = TreeFeature.State.BURNT_STUMP
	else:
		tree.current_state = TreeFeature.State.STUMP
	
	if tree.health_component:
		tree.health_component.current_health = tree.health_component.max_health

func on_damage(amount: float, is_fire: bool) -> void:
	tree.take_damage(amount, is_fire)
