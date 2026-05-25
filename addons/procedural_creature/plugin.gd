@tool
extends EditorPlugin

## Main entry point for the Procedural Creature addon.
##
## On enable:
##   • Registers CreatureGenerator as a recognised editor node type with a
##     custom icon so it appears correctly in the Add Node dialog and scene tree.
##   • Installs the inspector plugin that adds Rebuild / LOD buttons to the
##     inspector whenever a CreatureGenerator is selected.
##   • Installs the gizmo plugin that draws the skeleton overlay in the 3D
##     viewport (grey bone lines, yellow joint crosses, green +Y axis ticks).
##
## To activate: Project → Project Settings → Plugins → "Procedural Creature" → Enable
##
## After enabling, CreatureGenerator appears in Add Node under Node3D children.
## Select any CreatureGenerator to see the inspector tool buttons and the
## skeleton gizmo in the viewport.

const _INSPECTOR_PLUGIN_PATH := \
	"res://addons/procedural_creature/editor/creature_inspector_plugin.gd"
const _GIZMO_PLUGIN_PATH := \
	"res://addons/procedural_creature/editor/creature_gizmo_plugin.gd"
const _GENERATOR_SCRIPT_PATH := \
	"res://addons/procedural_creature/core/creature_generator.gd"
const _ICON_PATH := \
	"res://addons/procedural_creature/icons/creature_generator.svg"

var _inspector_plugin : EditorInspectorPlugin  = null
var _gizmo_plugin     : EditorNode3DGizmoPlugin = null


func _enter_tree() -> void:
	# Register the node type.  The icon is loaded at runtime so a missing file
	# degrades gracefully (Godot uses the Node3D icon as fallback).
	var script : Script    = load(_GENERATOR_SCRIPT_PATH)
	var icon   : Texture2D = _load_icon()
	add_custom_type("CreatureGenerator", "Node3D", script, icon)

	# Install inspector plugin.
	var inspector_script := load(_INSPECTOR_PLUGIN_PATH) as GDScript
	if inspector_script:
		_inspector_plugin = inspector_script.new() as EditorInspectorPlugin
		add_inspector_plugin(_inspector_plugin)
	else:
		push_warning("PCF: inspector plugin script not found at %s" % _INSPECTOR_PLUGIN_PATH)

	# Install gizmo plugin.
	var gizmo_script := load(_GIZMO_PLUGIN_PATH) as GDScript
	if gizmo_script:
		_gizmo_plugin = gizmo_script.new() as EditorNode3DGizmoPlugin
		add_node_3d_gizmo_plugin(_gizmo_plugin)
	else:
		push_warning("PCF: gizmo plugin script not found at %s" % _GIZMO_PLUGIN_PATH)


func _exit_tree() -> void:
	remove_custom_type("CreatureGenerator")

	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	if _gizmo_plugin != null:
		remove_node_3d_gizmo_plugin(_gizmo_plugin)
		_gizmo_plugin = null


# ==============================================================================
# Private
# ==============================================================================

func _load_icon() -> Texture2D:
	if ResourceLoader.exists(_ICON_PATH):
		return load(_ICON_PATH) as Texture2D
	push_warning("PCF: icon not found at %s — using Node3D fallback." % _ICON_PATH)
	return null
