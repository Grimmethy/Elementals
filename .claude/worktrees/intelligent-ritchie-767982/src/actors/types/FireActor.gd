class_name FireActor
extends Actor

const MANA_TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")

## Typed accessor mirroring `GoatActor.goat_data`. Optional — fire actors
## continue to work with `_data == null` (legacy spawn behaviour). When a
## designer assigns an ElementalData with `element_subtype = &"fire"`,
## `Actor._on_data_changed()` syncs ability scores from the resource.
var fire_data: ElementalData:
	get: return _data as ElementalData
	set(v): _data = v

func _init() -> void:
	projectile_scene = preload("res://scenes/projectiles/FireProjectile.tscn")
	lob_projectile_scene = preload("res://scenes/projectiles/FireLobProjectile.tscn")
	element_type = "fire"
	is_playable = false

func _ready() -> void:
	super._ready()
	if faction_component.faction == FactionComponent.Faction.NEUTRAL:
		faction_component.setup(FactionComponent.Faction.MONSTERS)
	if visual_component:
		visual_component.mana_particle_texture = MANA_TEXTURE
		visual_component.hide_body = true
		if visual_component.body:
			visual_component.body.visible = false
	
	if particle_component:
		particle_component.setup_mana_visuals(MANA_TEXTURE)

func get_actor_color() -> Color:
	return Color(1.0, 0.4, 0.1)

func die() -> void:
	if is_dead:
		return
	super.die()
	# Keep the persistent herd in sync if this elemental carries an
	# ElementalData resource. Legacy spawn paths leave `_data == null`.
	_remove_from_herd_if_present()

## See `GoblinMinion._remove_from_herd_if_present()` for rationale.
func _remove_from_herd_if_present() -> void:
	if _data != null and has_node("/root/HerdManager"):
		get_node("/root/HerdManager").remove_goat(_data)
