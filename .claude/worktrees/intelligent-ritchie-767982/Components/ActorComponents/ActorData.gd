class_name ActorData
extends Resource

## Base resource for actor data, holding standard ability scores and common attributes.
## Used to drive actor stats and visual variations.

signal stats_changed

@export_group("Ability Scores")
@export var strength: float = 1.0:
	set(v):
		if strength == v: return
		strength = v
		stats_changed.emit()

@export var dexterity: float = 1.0:
	set(v):
		if dexterity == v: return
		dexterity = v
		stats_changed.emit()

@export var constitution: float = 1.0:
	set(v):
		if constitution == v: return
		constitution = v
		stats_changed.emit()

@export var intelligence: float = 1.0:
	set(v):
		if intelligence == v: return
		intelligence = v
		stats_changed.emit()

@export var wisdom: float = 1.0:
	set(v):
		if wisdom == v: return
		wisdom = v
		stats_changed.emit()

@export var charisma: float = 1.0:
	set(v):
		if charisma == v: return
		charisma = v
		stats_changed.emit()

@export_group("Breeding")
enum Gender { MALE, FEMALE }
@export var gender: Gender = Gender.FEMALE:
	set(v):
		if gender == v: return
		gender = v
		stats_changed.emit()
@export var is_pregnant: bool = false:
	set(v):
		if is_pregnant == v: return
		is_pregnant = v
		stats_changed.emit()
@export var pregnancy_timer: int = 0:
	set(v):
		if pregnancy_timer == v: return
		pregnancy_timer = v
		stats_changed.emit()
@export var pregnancy_father: ActorData = null:
	set(v):
		if pregnancy_father == v: return
		pregnancy_father = v
		stats_changed.emit()
@export var is_exhausted: bool = false:
	set(v):
		if is_exhausted == v: return
		is_exhausted = v
		stats_changed.emit()
## Whether this actor is currently selected for the arena team.
## Lifted from GoatData so HerdComponent.toggle_selection() and ActorCard
## can operate on any ActorData subclass without subclass casts.
@export var is_selected: bool = false:
	set(v):
		if is_selected == v: return
		is_selected = v
		stats_changed.emit()

@export_group("Visual")
@export var base_color: Color = Color.WHITE:
	set(v):
		if base_color == v: return
		base_color = v
		stats_changed.emit()
@export var pattern_color: Color = Color.GRAY:
	set(v):
		if pattern_color == v: return
		pattern_color = v
		stats_changed.emit()

## Per-day lifecycle hook. Called once per herd member by
## `ProgressionComponent.advance_day()` so each ActorData subclass owns its
## own day-transition logic.
##
## Default behavior: clear the cross-cutting `is_selected` and `is_exhausted`
## flags so any ActorData subclass deselects + recovers at the day boundary
## without subclass code. Subclasses MUST call `super.tick_day(day)` first
## to inherit this behavior, then layer subclass-specific work (e.g. aging,
## stamina restoration) on top. See `GoatData.tick_day()` for the goat
## reference impl.
func tick_day(_day: int) -> void:
	is_selected = false
	is_exhausted = false

## Returns the gold the economy gains when this actor is sold via
## `HerdManager.sell_goat()`. Default is `0` so an unconfigured subclass
## yields no payout (no crash, no free money). `GoatData` overrides to
## return its existing `gold_value` field; other subclasses can override
## later when designers add per-species economy.
func get_sell_value() -> int:
	return 0

## Override in subclasses to create offspring with proper genetic mixing
func create_offspring(partner: ActorData) -> ActorData:
	push_error("ActorData.create_offspring() must be overridden by subclass")
	return null

## Returns the canonical lowercase type identifier (e.g. "goat", "goblin",
## "fire"). Subclasses MUST override to match their actor's `element_type`
## and the registry keys used by `ActorFactory` / `MainMenu.CHARACTER_EQUIPMENT`.
##
## The default body is intentionally loud: instead of silently reflecting the
## script's class_name (which produced misleading keys like `"GoatData"`),
## it pushes a warning and returns `""`. All five current subclasses
## (`GoatData`, `GoblinData`, `FarmerData`, `ElementalData`, `MimicData`)
## override this method, so the warning only fires if a future subclass
## forgets to override.
func get_actor_type() -> String:
	push_warning("ActorData.get_actor_type() not overridden by %s — returning empty string"
		% (get_script().resource_path if get_script() else "<unknown>"))
	return ""

## Returns the display name shown by UI cards and herd lists.
## Default returns the actor-type string so a card never blanks out.
## Subclasses with an identity field (e.g. GoatData.goat_name) should
## override this to surface that field.
func get_display_name() -> String:
	return get_actor_type()

## Returns the short info line shown under the name on actor cards.
## Default returns a human-readable gender string so the card stays
## legible for any ActorData subclass. Subclasses with richer identity
## (e.g. GoatData level + age) should override to format their own line.
func get_info_line() -> String:
	return "Female" if gender == Gender.FEMALE else "Male"

## Writes the actor's display name. Default is a no-op so the name-edit
## field on ActorCard fails silently for subclasses without an identity
## field. GoatData overrides this to write through to `goat_name`; other
## subclasses can override when they add their own naming.
func set_display_name(_new_name: String) -> void:
	pass
