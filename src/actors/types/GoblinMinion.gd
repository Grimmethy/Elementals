class_name GoblinMinion
extends Actor

## Goblin Minion: Small Fey (Goblinoid), Chaotic Neutral
## AC 12, HP 2d6, Speed 3
## Nimble Escape: Disengage (dodge) or Hide (invisibility)

@export_group("Goblin Stats")
@export var stealth_modifier: int = 6
@export var passive_perception: int = 9

func _init() -> void:
	element_type = "goblin"
	_type_key = "Goblin"
	is_playable = false
	move_speed = 3.0
	actor_size = Size.SMALL

func _on_data_changed_impl() -> void:
	var type_config := ActorTypeData.get_defaults(_type_key)
	move_speed = type_config.get("fixed_move_speed", 3.0)

func _ready() -> void:
	_data = GoblinData.new()
	super._ready()

func on_equipment_built(armor_key: String) -> void:
	if _body is GoblinModel:
		var model := _body as GoblinModel
		match armor_key:
			"none":        model.set_armor_skin(GoblinModel.ArmorSkin.NONE)
			"leather":     model.set_armor_skin(GoblinModel.ArmorSkin.LEATHER)
			"chain shirt": model.set_armor_skin(GoblinModel.ArmorSkin.CHAIN)
