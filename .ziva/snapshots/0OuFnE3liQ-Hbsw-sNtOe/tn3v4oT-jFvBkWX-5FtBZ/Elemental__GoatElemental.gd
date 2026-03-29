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

func _do_tile_effect(_tile: HexTile) -> void:
	# Goats have no tile effect
	pass

func _launch_projectile() -> void:
	# Projectiles are disabled for goats
	pass

func launch_projectile_at(_target_position: Vector3) -> void:
	# Projectiles are disabled for goats
	pass
