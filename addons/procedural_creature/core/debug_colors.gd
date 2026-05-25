class_name DebugColors

## Bold, distinct colors for each logical body-part group.
## Used in test scenes and in the ShapeAssembler's debug-draw mode.
## Every color is chosen so no two adjacent body parts look similar.

# --- Core body ---
const HEAD    := Color(0.95, 0.85, 0.00)  # Yellow
const NECK    := Color(1.00, 0.55, 0.05)  # Amber
const TORSO   := Color(0.90, 0.10, 0.10)  # Red
const MIDRIFF := Color(0.95, 0.40, 0.00)  # Orange

# --- Arms (left = cool, right = hot) ---
const ARM_L   := Color(0.00, 0.75, 0.95)  # Cyan
const ARM_R   := Color(0.82, 0.00, 0.90)  # Magenta

# --- Legs (left = green, right = gold) ---
const LEG_L   := Color(0.10, 0.85, 0.18)  # Green
const LEG_R   := Color(0.95, 0.62, 0.00)  # Gold

# --- Extremities (darker echo of parent limb) ---
const HAND_L  := Color(0.00, 0.45, 0.82)  # Deep cyan
const HAND_R  := Color(0.60, 0.00, 0.78)  # Deep magenta
const FOOT_L  := Color(0.00, 0.55, 0.18)  # Deep green
const FOOT_R  := Color(0.72, 0.38, 0.00)  # Deep gold

# --- Extras ---
const TAIL    := Color(0.00, 0.88, 0.78)  # Teal
const WING    := Color(0.55, 0.75, 1.00)  # Sky blue
const HORN    := Color(0.88, 0.88, 0.88)  # Light grey

## Build a flat StandardMaterial3D for a given debug color.
## Pass shade = false to make it fully unlit (normals won't affect it —
## useful for checking mesh coverage; leave true to verify shading is working).
static func make_mat(color: Color, shade: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if not shade:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
