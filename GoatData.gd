class_name GoatData
extends Resource

signal stats_changed

enum HornType { NONE, SMALL, LARGE, SPIRAL }
enum BodyType { SMALL, MEDIUM, LARGE }
enum PatternType { SOLID, PIEBALD, SPOTTED }
enum Gender { DOE, BUCK }

@export_group("Identity")
@export var goat_name: String = "New Goat":
	set(v): goat_name = v; stats_changed.emit()
@export var gender: Gender = Gender.DOE:
	set(v): gender = v; stats_changed.emit()

@export_group("Genetics")
@export var horn_type: HornType = HornType.NONE:
	set(v): horn_type = v; stats_changed.emit()
@export var body_type: BodyType = BodyType.MEDIUM:
	set(v): body_type = v; stats_changed.emit()
@export var pattern_type: PatternType = PatternType.SOLID:
	set(v): pattern_type = v; stats_changed.emit()
@export var base_color: Color = Color.WHITE:
	set(v): base_color = v; stats_changed.emit()
@export var pattern_color: Color = Color.GRAY:
	set(v): pattern_color = v; stats_changed.emit()

@export_group("Performance Stats")
@export var strength: float = 1.0: # Influences charge/knockback
	set(v): strength = v; stats_changed.emit()
@export var toughness: float = 1.0: # Influences HP
	set(v): toughness = v; stats_changed.emit()
@export var speed: float = 1.0: # Influences move speed
	set(v): speed = v; stats_changed.emit()
@export var stamina_max: float = 100.0:
	set(v): stamina_max = v; stats_changed.emit()
@export var stamina_current: float = 100.0:
	set(v): stamina_current = v; stats_changed.emit()

@export_group("Lifecycle")
@export var age_days: int = 0:
	set(v): age_days = v; stats_changed.emit()
@export var is_pregnant: bool = false:
	set(v): is_pregnant = v; stats_changed.emit()
@export var pregnancy_timer: int = 0:
	set(v): pregnancy_timer = v; stats_changed.emit()
@export var is_exhausted: bool = false:
	set(v): is_exhausted = v; stats_changed.emit()
@export var is_selected: bool = false:
	set(v): is_selected = v; stats_changed.emit()

@export_group("Economy")
@export var gold_value: int = 50:
	set(v): gold_value = v; stats_changed.emit()

## Helper to create a child from two parents (simplified genetics)
static func create_offspring(doe: GoatData, buck: GoatData) -> GoatData:
	var kid = GoatData.new()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	kid.goat_name = "Kid of " + doe.goat_name
	kid.gender = Gender.DOE if rng.randf() > 0.5 else Gender.BUCK
	
	# Genetic inheritance with slight mutation
	kid.base_color = doe.base_color.lerp(buck.base_color, rng.randf())
	kid.horn_type = doe.horn_type if rng.randf() > 0.5 else buck.horn_type
	kid.body_type = doe.body_type if rng.randf() > 0.5 else buck.body_type
	
	kid.strength = (doe.strength + buck.strength) * 0.5 * rng.randf_range(0.9, 1.1)
	kid.toughness = (doe.toughness + buck.toughness) * 0.5 * rng.randf_range(0.9, 1.1)
	kid.speed = (doe.speed + buck.speed) * 0.5 * rng.randf_range(0.9, 1.1)
	
	return kid
