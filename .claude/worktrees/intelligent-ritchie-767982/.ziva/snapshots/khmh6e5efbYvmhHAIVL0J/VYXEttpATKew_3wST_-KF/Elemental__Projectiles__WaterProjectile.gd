class_name WaterProjectile
extends BaseProjectile

func _init() -> void:
	element_type = "water"

func _do_projectile_effect(tile: HexTile) -> bool:
	return tile.apply_water()
