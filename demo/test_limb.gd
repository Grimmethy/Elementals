## Phase 2 test — attach to a Node3D in a blank 3D scene.
## Spawns three limb segments side by side so you can compare side counts
## and confirm flat shading is working on all three.
##
## Expected result:
##   Left  (4 sides) — chunky angular prism, very low-poly
##   Centre (6 sides) — recognisable cylinder, MODERATE default
##   Right  (8 sides) — smoother, COMPLEX default
##
## Flat shading is working correctly when each face reads as a single solid
## polygon with a hard edge between faces. If the surface looks smooth or
## rounded, calculate_normals() has been called somewhere — it hasn't been,
## but this is the thing to check first if shading looks wrong.
extends Node3D

func _ready() -> void:
	# Each detail level gets a distinct arm color so they're immediately distinguishable
	_spawn_limb(-1.2, 1.0, 0.12, 0.08, 4, DebugColors.ARM_L)   # SIMPLE  — cyan family
	_spawn_limb( 0.0, 1.0, 0.12, 0.08, 6, DebugColors.ARM_R)   # MODERATE — magenta family
	_spawn_limb( 1.2, 1.0, 0.12, 0.08, 8, DebugColors.LEG_L)   # COMPLEX  — green family

func _spawn_limb(x_offset: float, length: float, radius_bottom: float, radius_top: float, sides: int, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = LimbBuilder.build(length, radius_top, radius_bottom, sides)
	mesh_instance.material_override = DebugColors.make_mat(color)
	mesh_instance.position.x = x_offset
	add_child(mesh_instance)
