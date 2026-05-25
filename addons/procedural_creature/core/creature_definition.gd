class_name CreatureDefinition
extends Resource

enum DetailLevel {
	SIMPLE,    ## Background NPCs, crowds, distant enemies
	MODERATE,  ## Standard enemies, secondary characters
	COMPLEX    ## Player character, bosses, hero NPCs, cinematics
}

enum BodyPlan {
	BIPED,
	QUADRUPED,
	SERPENTINE,
	CUSTOM
}

enum HeadShape {
	ROUND,
	ANGULAR,
	ELONGATED,
	FLAT,
	HORNED
}

## --- Detail Level ---
@export var detail_level: DetailLevel = DetailLevel.MODERATE

## --- Archetype ---
@export var body_plan: BodyPlan = BodyPlan.BIPED

## --- Proportions ---
@export_group("Proportions")
@export var torso_height: float = 1.0
@export var torso_width: float = 1.0
@export var torso_depth: float = 0.6
@export var limb_thickness: float = 0.18
@export var arm_length: float = 1.0
@export var leg_length: float = 1.0
@export var head_scale: float = 1.0

## --- Posture ---
@export_group("Posture")
@export var spine_bend: float = 0.0       ## degrees; negative = hunch forward
@export var neck_angle: float = 0.0       ## degrees; tilt
@export var shoulder_droop: float = 0.0   ## degrees

## --- Head & Face ---
@export_group("Head")
@export var head_shape: HeadShape = HeadShape.ROUND
@export var snout_length: float = 0.0     ## 0 = flat face, 1 = full snout
@export var eye_size: float = 1.0
@export var eye_spacing: float = 1.0
@export var jaw_width: float = 1.0

## --- Extras ---
@export_group("Extras")
@export var has_tail: bool = false
@export var tail_segments: int = 6
@export var tail_length: float = 1.0
@export var has_wings: bool = false
@export var horn_count: int = 0

## --- Appearance ---
@export_group("Appearance")
@export var body_color: Color = Color(0.6, 0.55, 0.5)
@export var accent_color: Color = Color(0.3, 0.25, 0.2)
@export var eye_color: Color = Color(0.1, 0.6, 0.9)
@export var roughness: float = 0.85

## --- Animation Feel ---
@export_group("Animation")
@export var walk_speed: float = 1.0
@export var bounce_amount: float = 0.06
@export var secondary_motion_strength: float = 1.0
@export var step_height: float = 0.18

func duplicate_definition() -> CreatureDefinition:
	return duplicate(true) as CreatureDefinition
