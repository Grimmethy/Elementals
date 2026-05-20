## Procedural data resource for Elemental breeding (Fire / Water).
##
## A single class covers both elemental species. The `element_subtype` field
## drives `get_actor_type()` so the same resource type can key into either
## "fire" or "water" branches of ActorFactory / MainMenu.CHARACTER_EQUIPMENT
## without needing two separate scripts.
##
## Asexual-style inheritance: offspring inherits the parent's element_subtype
## rather than blending it. Cross-element breeding (Fire + Water → Steam) is
## documented as a future feature in Markdowns/Breeding.md §Future and is
## intentionally out of scope for this patch.
##
## This resource is OPTIONAL for FireActor / WaterActor — they continue to
## work with `_data == null`. When assigned, `Actor._on_data_changed()`
## syncs the ability scores into the actor's ability_scores_component.
class_name ElementalData
extends ActorData

@export_group("Identity")
@export var elemental_name: StringName = &"Elemental":
	set(v):
		if elemental_name == v: return
		elemental_name = v
		stats_changed.emit()
## Lowercase canonical subtype key. Currently "fire" or "water". Drives
## get_actor_type() so this one class keys into both factory entries.
@export var element_subtype: StringName = &"fire":
	set(v):
		if element_subtype == v: return
		element_subtype = v
		stats_changed.emit()

@export_group("Genetics")
## How brightly the elemental glows. Blended at breed time.
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 1.0:
	set(v):
		if glow_intensity == v: return
		glow_intensity = v
		stats_changed.emit()

func _init() -> void:
	# Lightly statted baseline. Designers tune per .tres.
	strength = 0.5
	dexterity = 1.0
	constitution = 0.5
	intelligence = 0.5
	wisdom = 0.5
	charisma = 0.0
	# Default palette = fire. Override per-subtype by setting element_subtype
	# + base_color in the editor or via subclass templates.
	base_color = Color(1.0, 0.4, 0.1)
	pattern_color = Color(1.0, 0.85, 0.3)

## Returns the lowercase subtype ("fire" or "water") directly so the same
## class can serve both factory keys.
func get_actor_type() -> String:
	return String(element_subtype)

func get_display_name() -> String:
	return String(elemental_name)

func set_display_name(new_name: String) -> void:
	elemental_name = StringName(new_name)

## Sexual reproduction. Offspring inherits THIS parent's element_subtype
## (a fire mom always bears a fire kid). Stats and visuals blend normally.
## Cross-element fusion (fire+water=steam) is a future feature — see
## Markdowns/Breeding.md §Steam Elemental.
func create_offspring(partner: ActorData) -> ActorData:
	var kid: ElementalData = ElementalData.new()
	kid.elemental_name = StringName("Spark of " + String(elemental_name))
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	kid.element_subtype = element_subtype

	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.pattern_color = pattern_color.lerp(partner.pattern_color, randf())

	var elem_partner: ElementalData = partner as ElementalData
	if elem_partner:
		kid.glow_intensity = clampf(
			(glow_intensity + elem_partner.glow_intensity) * 0.5 * randf_range(0.9, 1.1),
			0.0, 2.0
		)
	else:
		kid.glow_intensity = glow_intensity

	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)

	return kid
