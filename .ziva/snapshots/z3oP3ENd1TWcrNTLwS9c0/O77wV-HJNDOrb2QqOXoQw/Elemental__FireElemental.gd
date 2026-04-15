class_name FireElemental
extends Elemental

const MANA_TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")

func _init() -> void:
	projectile_scene = preload("res://Elemental/Projectiles/FireProjectile.tscn")
	lob_projectile_scene = preload("res://Elemental/Projectiles/FireLobProjectile.tscn")
	element_type = "fire"

func _setup_elemental() -> void:
	# Hide the body mesh so the elemental is only represented by particles
	if _body:
		_body.visible = false

func _get_mana_particle_texture() -> Texture2D:
	return MANA_TEXTURE

func get_elemental_color() -> Color:
	return Color(1.0, 0.4, 0.1)

func _do_tile_effect(tile: HexTile) -> void:
	if tile.apply_fire():
		if tile.current_state == HexTile.State.FIRE:
			current_mana = min(current_mana + 1.0, max_mana)
