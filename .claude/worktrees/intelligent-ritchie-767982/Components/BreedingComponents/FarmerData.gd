## Procedural data resource for Farmer breeding.
##
## Mirrors GoatData / GoblinData: an identity field, a small genetic knob,
## and a `create_offspring()` that blends colours, picks 50/50 categorical
## for enum fields, and mean-blends stats with mild mutation.
##
## This resource is OPTIONAL for FarmerActor — actors still work when
## `_data == null`. When assigned, `Actor._on_data_changed()` syncs the
## ability scores into the FarmerActor's ability_scores_component.
## FarmerActor._ready() gates its hardcoded stat block on `_data == null`.
class_name FarmerData
extends ActorData

@export_group("Identity")
@export var farmer_name: StringName = &"Farmer":
	set(v):
		if farmer_name == v: return
		farmer_name = v
		stats_changed.emit()

@export_group("Genetics")
## Farmer's straw-hat tint. Blended at breed time.
@export var hat_color: Color = Color(0.85, 0.7, 0.3):
	set(v):
		if hat_color == v: return
		hat_color = v
		stats_changed.emit()

func _init() -> void:
	# Commoner stat block — mirrors FarmerActor._ready() hardcodes.
	strength = 0.0
	dexterity = 0.0
	constitution = 0.0
	intelligence = 0.0
	wisdom = 0.0
	charisma = 0.0
	base_color = Color(0.95, 0.85, 0.7)
	pattern_color = Color(0.6, 0.45, 0.3)

func get_actor_type() -> String:
	return "farmer"

func get_display_name() -> String:
	return String(farmer_name)

func set_display_name(new_name: String) -> void:
	farmer_name = StringName(new_name)

func create_offspring(partner: ActorData) -> ActorData:
	var kid: FarmerData = FarmerData.new()
	kid.farmer_name = StringName("Child of " + String(farmer_name))
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE

	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.pattern_color = pattern_color.lerp(partner.pattern_color, randf())

	# Farmer-only hat tint: blend only if partner is also a farmer.
	var farmer_partner: FarmerData = partner as FarmerData
	if farmer_partner:
		kid.hat_color = hat_color.lerp(farmer_partner.hat_color, randf())
	else:
		kid.hat_color = hat_color

	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)

	return kid
