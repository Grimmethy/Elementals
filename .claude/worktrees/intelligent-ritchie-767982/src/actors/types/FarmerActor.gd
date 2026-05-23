class_name FarmerActor
extends Actor

## Typed accessor mirroring `GoatActor.goat_data`. Optional — farmers still
## spawn fine with `_data == null` (legacy behaviour, hardcoded stats below).
## When a FarmerData is assigned, `Actor._on_data_changed()` syncs ability
## scores BEFORE `_ready()` reaches the gated hardcode block.
var farmer_data: FarmerData:
	get: return _data as FarmerData
	set(v): _data = v

func _init() -> void:
	element_type = "farmer"
	should_bob = false
	max_hp = 4
	move_speed = 3.0

func _ready() -> void:
	super._ready()
	faction_component.setup(FactionComponent.Faction.FARMSTEAD)
	# Commoner stats (0 = base multiplier) — only when no FarmerData was
	# assigned. Otherwise `_on_data_changed()` already wrote the scores
	# and we must not clobber them.
	if _data == null:
		ability_scores_component.strength = 0
		ability_scores_component.dexterity = 0
		ability_scores_component.constitution = 0
		ability_scores_component.intelligence = 0
		ability_scores_component.wisdom = 0
		ability_scores_component.charisma = 0

func _create_controller() -> ActorAIController:
	return FarmerController.new()

func die() -> void:
	if is_dead:
		return
	super.die()
	# Keep the persistent herd in sync if this farmer carries a FarmerData
	# resource. Legacy spawn paths leave `_data == null` and skip cleanly.
	_remove_from_herd_if_present()

## See `GoblinMinion._remove_from_herd_if_present()` for rationale.
func _remove_from_herd_if_present() -> void:
	if _data != null and has_node("/root/HerdManager"):
		get_node("/root/HerdManager").remove_goat(_data)

func get_actor_color() -> Color:
	return Color.YELLOW_GREEN

func herd_goat(goat: GoatActor) -> void:
	if goat.has_method("_scream"):
		goat.call("_scream")
	if goat.movement_component and controller:
		var center = (controller as FarmerController).farm_center
		var push_dir = (center - goat.global_position).normalized()
		goat.movement_component.apply_external_force(push_dir * 5.0)
