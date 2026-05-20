class_name WaterProjectile
extends BaseProjectile

func _do_projectile_effect(tile: HexTile) -> bool:
	return tile.apply_water()
