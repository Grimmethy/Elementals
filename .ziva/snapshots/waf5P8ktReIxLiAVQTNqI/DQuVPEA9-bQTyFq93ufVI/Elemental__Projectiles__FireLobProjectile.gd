class_name FireLobProjectile
extends LobProjectile

func _init() -> void:
	element_type = "fire"
	sprite_base_modulate = Color(1.0, 0.4, 0.1)
	# Reuse the fire particle if possible, or just color it
	sprite_texture = preload("res://assets/generated/fire_particle_1774823455.png")
	wave_speed = 0.6
	wave_amplitude = 0.8
	wave_vertical_oscillation = 0.4
	wave_fwd_spacing = 0.3
