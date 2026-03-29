class_name FireProjectile
extends BaseProjectile

func _init() -> void:
	element_type = "fire"

func _do_projectile_effect(tile: HexTile) -> bool:
	return tile.apply_fire()
