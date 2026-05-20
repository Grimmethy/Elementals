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

@export_group("Performance Stats")
@export var stamina_max: float = 100.0:
	set(v): 
		if stamina_max == v: return
		stamina_max = v
		stats_changed.emit()
@export var stamina_current: float = 100.0:
	set(v): 
		if stamina_current == v: return
		stamina_current = v
		stats_changed.emit()

@export_group("Lifecycle")
@export var age_days: int = 0:
	set(v):
		if age_days == v: return
		age_days = v
		stats_changed.emit()
# NOTE: `is_selected` was lifted to ActorData so any actor type can be
# selected by HerdComponent. Do not re-add it here.

@export_group("Economy")
@export var gold_value: int = 50:
	set(v): 
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

## Canonical lowercase actor key — matches `GoatActor.element_type` and the
## key registered with `ActorFactory` / `MainMenu.CHARACTER_EQUIPMENT`.
func get_actor_type() -> String:
	return "goat"

## Display name for UI cards. Sources the goat's identity field.
func get_display_name() -> String:
	return goat_name

## Info line shown under the name on ActorCard. Goats have a level and an
## age, so we surface both here. Format matches the previous hardcoded
## string in ActorCard._update_resource_ui() for visual continuity.
func get_info_line() -> String:
	return "Lvl: %d - Age: %d" % [level, age_days]

## Lets ActorCard's name-edit field write through to `goat_name` without
## needing to type-check at the UI layer.
func set_display_name(new_name: String) -> void:
	goat_name = new_name

## Per-day lifecycle for goats. Calls super first so the base ActorData
## clears `is_selected` and `is_exhausted` for ALL ActorData subclasses,
## then layers goat-specific aging + stamina restoration on top.
##
## NOTE: this is a deliberate simplification of the pre-Patch-3 body. The
## old `ProgressionComponent.advance_day()` flipped a selected goat to
## `is_exhausted = true` for the next day. After lifting the cross-cutting
## deselect into `ActorData.tick_day()` (per Agent 1 R2), exhaustion is now
## driven only by `BreedingComponent.breed()` and clears at day boundary.
## Selecting a goat for the arena no longer auto-exhausts it.
func tick_day(day: int) -> void:
	super.tick_day(day)
	age_days += 1
	stamina_current = stamina_max

## Goats sell for their `gold_value` (the existing economy field). Default
## `ActorData.get_sell_value()` returns 0 for any subclass that hasn't
## opted into a per-species sell price.
func get_sell_value() -> int:
	return gold_value

## Creates offspring from this actor and a partner
func create_offspring(partner: ActorData) -> ActorData:
	var kid = GoatData.new()
	
	# Use reflection for goat-specific fields
	kid.goat_name = "Kid of " + (goat_name if "goat_name" in self else "Unknown")
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	
	# Genetic inheritance with slight mutation
	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.horn_type = horn_type if randf() < 0.5 else partner.horn_type
	kid.body_type = body_type if randf() < 0.5 else partner.body_type
	
	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)
	
	return kid
