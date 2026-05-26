class_name CharacterCustomizerPanel
extends Control

## In-game character appearance customizer.
##
## Opened as a modal overlay when the player clicks "Customize" on a PCF-enabled
## CharacterSelectCard.  The player sees a live 3D preview of their character
## while they tweak six curated controls:
##
##   • Skin color / Accent color / Eye color  (ColorPickerButton)
##   • Build                                  (HSlider: Slim ← → Stocky)
##   • Head shape                             (OptionButton enum)
##
## All edits are applied to a working copy of the definition; the original is
## untouched until the player presses Confirm.  Cancel discards all changes.
##
## ── Integration ───────────────────────────────────────────────────────────────
##   CharacterSelectCard.gd creates/finds this panel at root and calls open().
##   On confirmation, GameSettings.selected_creature_definition is updated and
##   saved to user://creature_customization.tres.
##   FarmerActor._ready() reads that slot and applies it to its generator.

signal confirmed(definition: CreatureDefinition)
signal cancelled

# ── Scene references (via unique-name % shorthand) ────────────────────────────
@onready var _creature_container : Node3D            = %CreatureContainer
@onready var _body_color_picker  : ColorPickerButton = %BodyColorPicker
@onready var _accent_color_picker: ColorPickerButton = %AccentColorPicker
@onready var _eye_color_picker   : ColorPickerButton = %EyeColorPicker
@onready var _build_slider       : HSlider           = %BuildSlider
@onready var _head_shape_option  : OptionButton      = %HeadShapeOption
@onready var _confirm_button     : Button            = %ConfirmButton
@onready var _cancel_button      : Button            = %CancelButton

# ── Build slider: three-point preset blend ────────────────────────────────────
# Slider value 0.0 = Slim | 0.5 = Balanced (humanoid_base defaults) | 1.0 = Stocky
# Each key maps to a CreatureDefinition @export property name.
const _BUILD_SLIM : Dictionary = {
	"torso_width"     : 0.75,
	"torso_height"    : 1.10,
	"leg_length"      : 1.15,
	"arm_length"      : 1.15,
	"limb_thickness"  : 0.14,
}
const _BUILD_DEFAULT : Dictionary = {
	"torso_width"     : 1.00,
	"torso_height"    : 1.00,
	"leg_length"      : 1.00,
	"arm_length"      : 1.00,
	"limb_thickness"  : 0.18,
}
const _BUILD_STOCKY : Dictionary = {
	"torso_width"     : 1.35,
	"torso_height"    : 0.90,
	"leg_length"      : 0.85,
	"arm_length"      : 0.90,
	"limb_thickness"  : 0.24,
}

# ── Internal state ─────────────────────────────────────────────────────────────
## Working copy — all edits land here; only written to GameSettings on Confirm.
var _working_def : CreatureDefinition = null
var _generator   : CreatureGenerator  = null
## True while syncing controls → def so we don't trigger recursive rebuilds.
var _syncing     : bool = false


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	hide()   # invisible until open() is called

	_populate_head_shapes()

	_build_slider.min_value = 0.0
	_build_slider.max_value = 1.0
	_build_slider.step      = 0.01

	_body_color_picker.color_changed.connect(_on_body_color_changed)
	_accent_color_picker.color_changed.connect(_on_accent_color_changed)
	_eye_color_picker.color_changed.connect(_on_eye_color_changed)
	_build_slider.value_changed.connect(_on_build_changed)
	_head_shape_option.item_selected.connect(_on_head_shape_selected)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


# ==============================================================================
# Public API
# ==============================================================================

## Show the panel and populate controls from `base_def`.
## Pass a duplicate if you want the original unchanged on Cancel.
func open(base_def: CreatureDefinition) -> void:
	_working_def = base_def.duplicate_definition()
	_sync_controls_from_def()
	_rebuild_preview()
	show()


# ==============================================================================
# Control → definition synchronization
# ==============================================================================

func _sync_controls_from_def() -> void:
	_syncing = true

	_body_color_picker.color   = _working_def.body_color
	_accent_color_picker.color = _working_def.accent_color
	_eye_color_picker.color    = _working_def.eye_color
	_head_shape_option.selected = int(_working_def.head_shape)

	# Reverse-map torso_width back to the build slider value.
	# Between 0 and 0.5: lerp from SLIM to DEFAULT. Between 0.5 and 1: DEFAULT to STOCKY.
	var tw         : float = _working_def.torso_width
	var slim_tw    : float = _BUILD_SLIM["torso_width"]
	var default_tw : float = _BUILD_DEFAULT["torso_width"]
	var stocky_tw  : float = _BUILD_STOCKY["torso_width"]

	var slider_val : float
	if tw <= default_tw:
		slider_val = remap(tw, slim_tw, default_tw, 0.0, 0.5)
	else:
		slider_val = remap(tw, default_tw, stocky_tw, 0.5, 1.0)
	_build_slider.set_value_no_signal(clampf(slider_val, 0.0, 1.0))

	_syncing = false


func _apply_build_to_def(slider_value: float) -> void:
	for key: String in _BUILD_DEFAULT:
		var slim_v    : float = _BUILD_SLIM[key]
		var default_v : float = _BUILD_DEFAULT[key]
		var stocky_v  : float = _BUILD_STOCKY[key]

		var result : float
		if slider_value <= 0.5:
			result = lerpf(slim_v, default_v, slider_value * 2.0)
		else:
			result = lerpf(default_v, stocky_v, (slider_value - 0.5) * 2.0)

		_working_def.set(key, result)


# ==============================================================================
# 3D preview
# ==============================================================================

func _rebuild_preview() -> void:
	# Free any existing generator synchronously to avoid stacked previews.
	for child in _creature_container.get_children():
		_creature_container.remove_child(child)
		child.free()
	_generator = null

	if _working_def == null:
		return

	# Set definition BEFORE add_child so the setter's is_node_ready() guard
	# skips the pre-tree rebuild — CreatureGenerator._ready() does one rebuild.
	var gen := CreatureGenerator.new()
	gen.name       = "PreviewGenerator"
	gen.definition = _working_def
	_creature_container.add_child(gen)
	_generator = gen


func _refresh_preview() -> void:
	if _generator != null:
		_generator.rebuild()


# ==============================================================================
# Signal handlers — controls
# ==============================================================================

func _on_body_color_changed(color: Color) -> void:
	if _syncing or _working_def == null: return
	_working_def.body_color = color
	_refresh_preview()

func _on_accent_color_changed(color: Color) -> void:
	if _syncing or _working_def == null: return
	_working_def.accent_color = color
	_refresh_preview()

func _on_eye_color_changed(color: Color) -> void:
	if _syncing or _working_def == null: return
	_working_def.eye_color = color
	_refresh_preview()

func _on_build_changed(value: float) -> void:
	if _syncing or _working_def == null: return
	_apply_build_to_def(value)
	_refresh_preview()

func _on_head_shape_selected(index: int) -> void:
	if _syncing or _working_def == null: return
	_working_def.head_shape = index as CreatureDefinition.HeadShape
	_refresh_preview()


# ==============================================================================
# Signal handlers — buttons
# ==============================================================================

func _on_confirm_pressed() -> void:
	confirmed.emit(_working_def)
	hide()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()


# ==============================================================================
# Helpers
# ==============================================================================

func _populate_head_shapes() -> void:
	_head_shape_option.clear()
	_head_shape_option.add_item("Round")
	_head_shape_option.add_item("Angular")
	_head_shape_option.add_item("Elongated")
	_head_shape_option.add_item("Flat")
	_head_shape_option.add_item("Horned")
