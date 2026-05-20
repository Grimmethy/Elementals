## Procedural data resource for the Mimic creature.
##
## Inherits the ability-scores, breeding, and visual fields from ActorData.
## Mimic-specific fields drive the scan / morph / skill-copy loop in
## `src/actors/types/MimicController.gd`. Every value is `@export`-tunable so
## designers can author Mimic variants as `.tres` resources without touching
## scripts.
##
## Reproduction: Mimics reproduce asexually (budding). `create_offspring()`
## ignores the partner and returns a near-clone with slight color +
## aggression mutation. Note that the wider `HerdManager.next_day()` still
## drops non-`GoatData` kids — Mimic breeding is gated on B7 generalization
## (see docs/AGENT_1_IMPLEMENTATION_REQUIREMENTS.md §6.1 MM11).
class_name MimicData
extends ActorData

@export_group("Identity")
## Display name for this Mimic. Shown in UI panels and debug labels.
@export var mimic_name: StringName = &"Mimic"

@export_group("Behavior")
## Probability (0-1) that the Mimic will engage a perceived target instead of
## continuing to roam. Higher values = more aggressive pack behavior.
@export_range(0.0, 1.0, 0.05) var aggression: float = 0.6
## Hex radius scanned each tick for morph + skill-copy candidates.
## Routed through TileSignalComponent — do NOT compute distance manually.
@export_range(1, 12, 1) var scan_radius: int = 4
## Seconds between scan ticks. Routed through GameClockComponent.register_tick.
## 0.5 (2Hz) keeps load low while staying responsive.
@export_range(0.1, 5.0, 0.1) var scan_interval: float = 0.5
## Seconds the Mimic stays morphed before reverting to base form.
@export_range(1.0, 60.0, 0.5) var morph_duration: float = 8.0
## Maximum number of stolen AbilityActions the Mimic carries at once.
## Lower values protect the player from too-strong copy bursts.
@export_range(0, 8, 1) var skill_copy_limit: int = 2

@export_group("Targeting")
## Actor types the Mimic refuses to copy or morph into. Avoids feedback loops
## (mimic copying mimic) and inert objects (scarecrow). Anything not listed
## here is fair game — Goblin, Goat, Farmer, Fire, Water, etc.
## Initialized in `_init()` because typed-array @export initializers do not
## accept StringName literals in Godot 4.6.
@export var disallowed_target_types: Array[StringName] = []

func _init() -> void:
	# Reasonable base stat block — slightly less hardy than a Goblin but
	# above an unranked actor. Designers can override via inspector.
	strength = 0.5
	dexterity = 1.5
	constitution = 0.0
	intelligence = 0.5
	wisdom = 1.0
	charisma = -1.0
	base_color = Color(0.35, 0.20, 0.55)  # Default mimic violet.
	pattern_color = Color(0.85, 0.85, 0.10)
	# Populate the disallowed-target list here so StringName literals work.
	if disallowed_target_types.is_empty():
		disallowed_target_types = [&"mimic", &"scarecrow"]

## Mimic actor-type identifier consumed by the ActorFactory and the
## perceived-actor filter inside MimicController.
func get_actor_type() -> String:
	return "mimic"

## Asexual budding. Ignores `partner`; the kid is a near-clone with a small
## color drift and an aggression mutation. Stats jitter +/- 10% so the
## bloodline can drift over many generations without a dedicated trait engine.
func create_offspring(_partner: ActorData) -> ActorData:
	var kid: MimicData = MimicData.new()
	kid.mimic_name = mimic_name
	kid.gender = gender
	kid.aggression = clampf(aggression + randf_range(-0.05, 0.05), 0.0, 1.0)
	kid.scan_radius = scan_radius
	kid.scan_interval = scan_interval
	kid.morph_duration = morph_duration
	kid.skill_copy_limit = skill_copy_limit
	kid.disallowed_target_types = disallowed_target_types.duplicate()
	# Slight color drift so generations are visually distinguishable.
	kid.base_color = Color(
		clampf(base_color.r + randf_range(-0.05, 0.05), 0.0, 1.0),
		clampf(base_color.g + randf_range(-0.05, 0.05), 0.0, 1.0),
		clampf(base_color.b + randf_range(-0.05, 0.05), 0.0, 1.0),
	)
	kid.pattern_color = pattern_color
	# Stat mutation in the same shape as GoatData.create_offspring().
	kid.strength = strength * randf_range(0.9, 1.1)
	kid.dexterity = dexterity * randf_range(0.9, 1.1)
	kid.constitution = constitution * randf_range(0.9, 1.1)
	kid.intelligence = intelligence * randf_range(0.9, 1.1)
	kid.wisdom = wisdom * randf_range(0.9, 1.1)
	kid.charisma = charisma * randf_range(0.9, 1.1)
	return kid
