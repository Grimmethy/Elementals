class_name GoatData
extends ActorData

enum HornType { NONE, SMALL, LARGE, SPIRAL }
enum BodyType { SMALL, MEDIUM, LARGE }
enum PatternType { SOLID, PIEBALD, SPOTTED }

@export_group("Identity")
@export var goat_name: String = "New Goat":
	set(v): 
		if goat_name == v: return
		goat_name = v
		stats_changed.emit()
@export var level: int = 1:
	set(v):
		if level == v: return
		level = v
		stats_changed.emit()

@export_group("Genetics")
@export var horn_type: HornType = HornType.NONE:
	set(v): 
		if horn_type == v: return
		horn_type = v
		stats_changed.emit()
@export var body_type: BodyType = BodyType.MEDIUM:
	set(v): 
		if body_type == v: return
		body_type = v
		stats_changed.emit()
@export var pattern_type: PatternType = PatternType.SOLID:
	set(v): 
		if pattern_type == v: return
		pattern_type = v
		stats_changed.emit()

func _init() -> void:
	strength = 1.0
	dexterity = 1.0
	constitution = 0.0
	intelligence = -4.0
	wisdom = 0.0
	charisma = -3.0
	if render_seed == 0:
		render_seed = randi()
	# Auto-name from render_seed — every fresh GoatData gets a unique fantasy
	# name instead of "New Goat" by default.
	goat_name = ActorData.generate_name_from_seed(render_seed)

# stamina_max, stamina_current, age_days, is_selected all live on ActorData
# base now — every herd member (goat, mimic, mushroom, goblin, hybrid)
# shares the same lifecycle fields so ProgressionComponent.advance_day can
# poll them polymorphically without GoatData-specific casts.

@export_group("Economy")
@export var gold_value: int = 50:
	set(v): 
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

## Creates offspring from this actor and a partner.
## Same species → bespoke Goat × Goat genome crossover (horn / body / pattern
## inheritance below). Cross species → ActorData.universal_crossover_breed,
## which 50/50-rolls the kid's species and transfers limbs / palette /
## mutations from the partner. That makes Goat × Mimic sometimes produce a
## Mimic kid with goat-tinted palette, and Mimic × Goat sometimes produce
## a Goat with mimic_blood + inherited skill chance.
func create_offspring(partner: ActorData) -> ActorData:
	if partner == null:
		return null
	if not (partner is GoatData):
		return ActorData.universal_crossover_breed(self, partner)
	var kid := GoatData.new()

	# Use reflection for goat-specific fields; partner may not be a GoatData,
	# so guard each access through `in partner` before reading.
	var partner_name: String = partner.goat_name if "goat_name" in partner else "Stranger"
	kid.goat_name = "Kid of " + (goat_name if "goat_name" in self else "Unknown") + " & " + partner_name
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE

	# Genetic inheritance with slight mutation
	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.pattern_color = pattern_color.lerp(partner.pattern_color, randf())
	# Goat-specific genes default to this parent's value unless partner has
	# the same field (hybrid crossover only triggers between two GoatData).
	if "horn_type" in partner:
		kid.horn_type = horn_type if randf() < 0.5 else partner.horn_type
	else:
		kid.horn_type = horn_type
	if "body_type" in partner:
		kid.body_type = body_type if randf() < 0.5 else partner.body_type
	else:
		kid.body_type = body_type
	if "pattern_type" in partner:
		kid.pattern_type = pattern_type if randf() < 0.5 else partner.pattern_type
	else:
		kid.pattern_type = pattern_type

	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)

	# Lineage: average mimic_blood and roll the skill-inheritance gate.
	# Centralized in ActorData.apply_mimic_lineage so MimicData / GoblinData /
	# FarmerData etc. all share the same probability table.
	ActorData.apply_mimic_lineage(kid, self, partner)

	return kid
