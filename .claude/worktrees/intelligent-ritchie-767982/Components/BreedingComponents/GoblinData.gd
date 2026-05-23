## Procedural data resource for Goblin breeding.
##
## Mirrors the GoatData pattern: identity field + a couple of @export
## genetic knobs + a `create_offspring()` that blends colours, picks a
## 50/50 categorical for enum fields, and mean-blends stats with a small
## mutation. Designed to be authored as `.tres` files without scripts.
##
## This resource is OPTIONAL for GoblinMinion — actors continue to work
## when `_data == null` (legacy spawn behaviour preserved). When a designer
## assigns a GoblinData, `Actor._on_data_changed()` syncs the ability scores
## into the GoblinMinion's ability_scores_component and GoblinMinion._ready()
## gates its hardcoded stat block on `if _data == null` so the resource
## values win.
class_name GoblinData
extends ActorData

enum EarType { POINTED, ROUND, DROOPY }

@export_group("Identity")
@export var goblin_name: StringName = &"Goblin":
	set(v):
		if goblin_name == v: return
		goblin_name = v
		stats_changed.emit()

@export_group("Genetics")
## Goblin tribe / clan tint. Blended at breed time.
@export var tribe_color: Color = Color(0.4, 0.6, 0.3):
	set(v):
		if tribe_color == v: return
		tribe_color = v
		stats_changed.emit()
## Ear shape passes 50/50 from one parent.
@export var ear_type: EarType = EarType.POINTED:
	set(v):
		if ear_type == v: return
		ear_type = v
		stats_changed.emit()

func _init() -> void:
	# Baseline goblin stat block — mirrors GoblinMinion._ready() hardcodes.
	# Designers can override per-resource in the inspector.
	strength = -1.0
	dexterity = 2.5
	constitution = 0.0
	intelligence = 0.0
	wisdom = -1.0
	charisma = -1.0
	base_color = Color(0.4, 0.55, 0.35)
	pattern_color = Color(0.2, 0.3, 0.15)

## Canonical lowercase key — matches GoblinMinion.element_type and the
## ActorFactory registry key &"goblin".
func get_actor_type() -> String:
	return "goblin"

func get_display_name() -> String:
	return String(goblin_name)

func set_display_name(new_name: String) -> void:
	goblin_name = StringName(new_name)

## Sexual reproduction. Returns a GoblinData kid blending both parents.
## Falls back gracefully if `partner` is some other ActorData subtype:
## we still produce a GoblinData (a goblin can't bear a non-goblin kid)
## but we only mix the fields that exist on the partner.
func create_offspring(partner: ActorData) -> ActorData:
	var kid: GoblinData = GoblinData.new()
	kid.goblin_name = StringName("Whelp of " + String(goblin_name))
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE

	# Visual lerp — uses ActorData base_color so the blend works against
	# any partner subtype.
	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.pattern_color = pattern_color.lerp(partner.pattern_color, randf())

	# Goblin-only genetics: only blend if the partner is also a goblin.
	# Otherwise inherit straight from this parent (the canonical-goblin one).
	var goblin_partner: GoblinData = partner as GoblinData
	if goblin_partner:
		kid.tribe_color = tribe_color.lerp(goblin_partner.tribe_color, randf())
		kid.ear_type = ear_type if randf() < 0.5 else goblin_partner.ear_type
	else:
		kid.tribe_color = tribe_color
		kid.ear_type = ear_type

	# Stats: mean ± 10% mutation. Mirrors GoatData.create_offspring shape.
	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)

	return kid
