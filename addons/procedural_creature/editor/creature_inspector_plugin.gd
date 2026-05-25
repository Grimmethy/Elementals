@tool
extends EditorInspectorPlugin

## Adds tool buttons at the top of the inspector whenever a CreatureGenerator
## node is selected.
##
## Row 1 — LOD quick-switch:  [SIMPLE]  [MODERATE]  [COMPLEX]
## Row 2 — Rebuild:           [↺ Rebuild Creature]
##
## The LOD buttons call set_detail_level() — a runtime override that does NOT
## dirty the .tres asset.  The Rebuild button is a convenience shortcut for
## when you have tweaked the .tres in a text editor and want a forced refresh.


func _can_handle(object: Object) -> bool:
	return object is CreatureGenerator


func _parse_begin(object: Object) -> void:
	var gen := object as CreatureGenerator

	# --- LOD quick-switch row -----------------------------------------------
	var lod_row := HBoxContainer.new()
	lod_row.add_child(_lod_button(gen, "SIMPLE",   CreatureDefinition.DetailLevel.SIMPLE))
	lod_row.add_child(_lod_button(gen, "MODERATE", CreatureDefinition.DetailLevel.MODERATE))
	lod_row.add_child(_lod_button(gen, "COMPLEX",  CreatureDefinition.DetailLevel.COMPLEX))
	add_custom_control(lod_row)

	# --- Rebuild button ------------------------------------------------------
	var rebuild_btn := Button.new()
	rebuild_btn.text         = "↺  Rebuild Creature"
	rebuild_btn.tooltip_text = "Tear down and reassemble geometry from the current definition."
	rebuild_btn.pressed.connect(gen.rebuild)
	add_custom_control(rebuild_btn)

	# Thin separator so the tool buttons are visually distinct from the
	# exported properties below them.
	add_custom_control(HSeparator.new())


# Build a single LOD button.  Each button gets its own lambda so the level
# value is captured per-call, not as a shared loop variable.
func _lod_button(gen: CreatureGenerator, label: String, level: int) -> Button:
	var btn := Button.new()
	btn.text            = label
	btn.tooltip_text    = "Set detail level to %s (runtime override — does not modify the .tres)." % label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): gen.set_detail_level(level))
	return btn
