class_name GoblinData
extends ActorData

## Minimal data carrier for Goblin creatures.
## Used as a TYPE TAG for breeding probability gates and as a herd entry for
## captured/spawned goblins. Stats mirror GoblinMinion (Small Fey, AC 12,
## STR -1 / DEX +2.5 / etc).

@export_group("Identity")
@export var creature_name: String = "Goblin":
	set(v):
		if creature_name == v: return
		creature_name = v
		stats_changed.emit()
@export var level: int = 1:
	set(v):
		if level == v: return
		level = v
		stats_changed.emit()

@export_group("Economy")
@export var gold_value: int = 65:
	set(v):
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

func _init() -> void:
	_apply_type_defaults("Goblin")
	base_color = Color(0.42, 0.66, 0.28)
	pattern_color = Color(0.20, 0.36, 0.14)
	if render_seed == 0:
		render_seed = randi()
	# Auto-name from the render_seed.
	creature_name = ActorData.generate_name_from_seed(render_seed)

func create_offspring(partner: ActorData) -> ActorData:
	# Same species → species-specific crossover. Everything else → universal
	# cross-species path on ActorData. No bespoke per-pair hybrid functions.
	if partner == null:
		return null
	if partner is GoblinData:
		var kid := GoblinData.new()
		var partner_g: GoblinData = partner as GoblinData
		kid.creature_name = "Goblin Whelp"
		kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
		kid.base_color = base_color.lerp(partner_g.base_color, randf())
		kid.pattern_color = pattern_color.lerp(partner_g.pattern_color, randf())
		kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
		kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
		kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
		kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
		kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
		kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)
		ActorData.apply_mimic_lineage(kid, self, partner)
		return kid
	return ActorData.universal_crossover_breed(self, partner)

func get_actor_type() -> String:
	return "GoblinData"
