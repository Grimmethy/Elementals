## Phase 5 / 6 test — attach to the root Node3D in test_creature_generator_scene.tscn.
## Press F6 to run.
##
## The CreatureGenerator child node assembles itself automatically — no code
## in _ready() required.  This script adds keyboard controls to verify the
## rebuild, detail-switching, and skeleton APIs at runtime.
##
## Controls:
##   1  — SIMPLE   (blocky, lowest poly)
##   2  — MODERATE (default)
##   3  — COMPLEX  (smoothest)
##   R  — force rebuild at current detail level
##   C  — clear runtime override (return to definition's detail level)
##   S  — print Skeleton3D bone list to Output panel
##
## Watch the Output panel: each action prints a one-line confirmation.
extends Node3D

@onready var generator: CreatureGenerator = $CreatureGenerator

func _ready() -> void:
	# Connect for future rebuilds (key presses 1/2/3/R/C).
	generator.rebuilt.connect(func(): _print_skeleton(generator.get_skeleton()))
	# CreatureGenerator._ready() already fired (children before parent), so
	# print the initial skeleton now rather than waiting for the next rebuild.
	_print_skeleton(generator.get_skeleton())

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_1:
			generator.set_detail_level(CreatureDefinition.DetailLevel.SIMPLE)
			print("Detail override → SIMPLE")
		KEY_2:
			generator.set_detail_level(CreatureDefinition.DetailLevel.MODERATE)
			print("Detail override → MODERATE")
		KEY_3:
			generator.set_detail_level(CreatureDefinition.DetailLevel.COMPLEX)
			print("Detail override → COMPLEX")
		KEY_R:
			generator.rebuild()
			print("Rebuilt")
		KEY_C:
			generator.clear_detail_override()
			print("Detail override cleared (using definition's level)")
		KEY_S:
			_print_skeleton(generator.get_skeleton())


func _print_skeleton(sk: Skeleton3D) -> void:
	if sk == null:
		print("Skeleton: (none)")
		return
	var count := sk.get_bone_count()
	print("── Skeleton3D  (%d bones) ──────────────────" % count)
	for i in range(count):
		var parent_idx : int    = sk.get_bone_parent(i)
		var parent_name: String = sk.get_bone_name(parent_idx) if parent_idx >= 0 else "root"
		var rest_pos   : Vector3 = sk.get_bone_rest(i).origin
		print("  [%02d] %-18s  parent=%-14s  rest_pos=(%.2f, %.2f, %.2f)" % [
			i,
			sk.get_bone_name(i),
			parent_name,
			rest_pos.x, rest_pos.y, rest_pos.z
		])
	print("────────────────────────────────────────────")
