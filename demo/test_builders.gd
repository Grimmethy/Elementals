## Phase 3 test — attach to a Node3D in a blank 3D scene.
##
## Layout (viewed from front):
##
##   Far left   — Torso: SIMPLE / MODERATE / COMPLEX  (RED)
##   Centre     — Head: ROUND / ANGULAR / ELONGATED / FLAT / SIMPLE-override  (YELLOW)
##   Far right  — Tail: 5-segment chain  (TEAL)
##
## What to confirm:
##   Torso: elliptical cross-section (wider in X than Z), hard face edges
##   Head ROUND: faceted low-poly sphere, no smooth shading
##   Head ANGULAR: clean flat-faced box
##   Head ELONGATED: visibly taller than ANGULAR
##   Head FLAT: visibly wider and shorter than ANGULAR
##   Head SIMPLE: box regardless of shape (5th mesh, same as ANGULAR)
##   Tail: each segment narrower than the last, root at bottom tip at top
##
## Colors are drawn from DebugColors so they match what the ShapeAssembler
## will use when the full character is assembled in Phase 4+.
extends Node3D

func _ready() -> void:
	_spawn_torsos()
	_spawn_heads()
	_spawn_tail()

func _spawn_torsos() -> void:
	var configs := [
		[CreatureDefinition.DetailLevel.SIMPLE,   -3.5],
		[CreatureDefinition.DetailLevel.MODERATE, -2.8],
		[CreatureDefinition.DetailLevel.COMPLEX,  -2.1],
	]
	for cfg in configs:
		var level: int   = cfg[0]
		var x_pos: float = cfg[1]
		var mi := MeshInstance3D.new()
		mi.mesh              = TorsoBuilder.build(0.6, 0.4, 0.25, TorsoBuilder.resolve_sides(level))
		mi.material_override = DebugColors.make_mat(DebugColors.TORSO)
		mi.position          = Vector3(x_pos, 0.0, 0.0)
		add_child(mi)

func _spawn_heads() -> void:
	var shapes := [
		[CreatureDefinition.HeadShape.ROUND,     -0.8],
		[CreatureDefinition.HeadShape.ANGULAR,    0.0],
		[CreatureDefinition.HeadShape.ELONGATED,  0.8],
		[CreatureDefinition.HeadShape.FLAT,       1.6],
	]
	for cfg in shapes:
		var shape: int   = cfg[0]
		var x_pos: float = cfg[1]
		var mi := MeshInstance3D.new()
		mi.mesh              = HeadBuilder.build(0.12, 0.15, 0.12, shape, CreatureDefinition.DetailLevel.MODERATE)
		mi.material_override = DebugColors.make_mat(DebugColors.HEAD)
		mi.position          = Vector3(x_pos, 0.8, 0.0)
		add_child(mi)

	# SIMPLE override — should always be a box regardless of shape enum passed
	var mi_simple := MeshInstance3D.new()
	mi_simple.mesh              = HeadBuilder.build(0.12, 0.15, 0.12, CreatureDefinition.HeadShape.ROUND, CreatureDefinition.DetailLevel.SIMPLE)
	mi_simple.material_override = DebugColors.make_mat(DebugColors.HEAD)
	mi_simple.position          = Vector3(2.4, 0.8, 0.0)
	add_child(mi_simple)

func _spawn_tail() -> void:
	var segments: Array[ArrayMesh] = ExtrasBuilder.build_tail(
		5, 0.8, 0.06, CreatureDefinition.DetailLevel.MODERATE
	)
	for i in range(segments.size()):
		var mi := MeshInstance3D.new()
		mi.mesh              = segments[i]
		mi.material_override = DebugColors.make_mat(DebugColors.TAIL)
		# Stack vertically — root at bottom, tip at top, taper reads clearly
		mi.position          = Vector3(3.5, float(i) * 0.17, 0.0)
		add_child(mi)
