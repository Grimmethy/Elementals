class_name FireProjectile
extends BaseProjectile

func _do_projectile_effect(tile: HexTile) -> bool:
	return tile.apply_fire()
