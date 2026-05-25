extends Node

const SAVE_PATH = "user://settings.cfg"

var selected_actor_type: String = "fire" # "fire", "water", "goat", "goblin", or "mimic"
var selected_weapon_index: int = 0
var selected_ability_index: int = 0
var selected_armor_index: int = 0
## 0 = Top-Down (Twin-Stick), 1 = Over-the-Shoulder, 2 = First Person, 3 = RTS
var selected_control_mode: int = 0
var invert_look_x: bool = false
var invert_look_y: bool = false
var grid_width: int = 20
var grid_height: int = 20
var fire_count: int = 1
var water_count: int = 1
var goat_count: int = 1

var noise_seed: int = 0
var noise_frequency: float = 0.05
var height_step: float = 1.0
var dirt_threshold: float = 0.2
var master_volume: float = 1.0
## Screen brightness multiplier. 1.0 = no change; <1.0 darkens; >1.0 brightens.
## Applied via a global CanvasLayer overlay (works regardless of scene's
## WorldEnvironment), so the slider takes effect immediately on every scene.
## Default 0.85 because the project ships with no WorldEnvironment and the
## fallback Godot env over-exposes the scene — see _ensure_global_environment
## for the upstream fix; the slider lets the user push further if needed.
var brightness: float = 0.85

const CHARACTER_EQUIPMENT: Dictionary = {
	"goblin": {
		"weapons": ["Dagger", "Scimitar", "Shortbow"],
		"abilities": ["Nimble Escape", "Redirect Attack"],
		"armor": ["None", "Leather", "Chain Shirt"]
	},
	"farmer": {
		"weapons": ["Pitchfork", "Shovel", "None"],
		"abilities": ["Repair", "Calm Animal"],
		"armor": ["Clothes", "Leather Apron"]
	},
	"goat": {
		"weapons": ["Headbutt"],
		"abilities": ["Charge", "Intimidating Presence"],
		"armor": ["Fur"]
	},
	"scarecrow": {
		"weapons": ["Scythe", "Pitchfork"],
		"abilities": ["Intimidate", "Scare"],
		"armor": ["Straw"]
	},
	"fire": {
		"weapons": ["Flame Burst"],
		"abilities": ["Fireball", "Flame Wall"],
		"armor": ["Magma Shell"]
	},
	"water": {
		"weapons": ["Water Jet"],
		"abilities": ["Tidal Wave", "Healing Waters"],
		"armor": ["Water Shield"]
	},
	"mimic": {
		"weapons": ["Unarmed strike"],
		"abilities": ["Transmorph", "Adhesive Bite"],
		"armor": ["Natural Armor"]
	}
}

func _ready() -> void:
	load_settings()
	_apply_volume(master_volume)
	# Defer the overlays/env install to the next frame so the root viewport
	# is ready before we add a global CanvasLayer / set world_3d.environment.
	call_deferred("_ensure_global_environment")
	call_deferred("_ensure_brightness_overlay")
	call_deferred("apply_brightness", brightness)

func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

# === Brightness overlay ====================================================
# A global CanvasLayer with a full-screen ColorRect that we tint to darken
# (alpha) or brighten (additive blend) the entire screen. Works on every
# scene without needing per-scene WorldEnvironment setup.

var _brightness_layer: CanvasLayer = null
var _brightness_rect: ColorRect = null

# === Global 3D Environment (upstream fix for over-exposed scenes) ===========
# The project ships with no WorldEnvironment and no project-level default env,
# so Godot falls back to an untonemapped environment that over-exposes the
# DirectionalLight + sky combo (grass blows out into white speckle, colors
# wash). We install a filmic-tonemapped Environment on the ROOT viewport's
# World3D — every scene that doesn't have its own WorldEnvironment node now
# inherits this. Scenes that DO have their own WorldEnvironment win, so this
# is non-destructive to any per-scene art direction added later.
var _global_env: Environment = null

func _ensure_global_environment() -> void:
	var root: Window = get_tree().root
	if root == null:
		return
	var world: World3D = root.world_3d
	if world == null:
		return
	# Honor any environment a scene has already set via WorldEnvironment.
	if world.environment != null and world.environment != _global_env:
		return
	if _global_env == null:
		var env := Environment.new()
		# Background: clear color so any 2D background / fog can show through.
		env.background_mode = Environment.BG_CLEAR_COLOR
		# Filmic tonemap is the key fix — without this, Godot 4's default
		# linear "pass-through" tonemap produces blown highlights on anything
		# above mid-gray. Filmic compresses the top end like a film curve.
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		# Pull exposure down a notch — the scene's directional light is at
		# default energy (1.0) which adds up to plenty of light once the
		# tonemap is in place.
		env.tonemap_exposure = 0.85
		# Use a fixed cool-gray ambient so shadows aren't pitch black after
		# we lower exposure. AMBIENT_SOURCE_BG would re-use the (now clear)
		# background and produce no fill at all.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.42, 0.46, 0.55)
		env.ambient_light_energy = 0.45
		_global_env = env
	world.environment = _global_env

func _ensure_brightness_overlay() -> void:
	if is_instance_valid(_brightness_layer):
		return
	var root: Window = get_tree().root
	if root == null:
		return
	_brightness_layer = CanvasLayer.new()
	_brightness_layer.name = "BrightnessOverlay"
	_brightness_layer.layer = 128  # very top, above all gameplay layers
	root.add_child(_brightness_layer)
	_brightness_rect = ColorRect.new()
	_brightness_rect.name = "BrightnessRect"
	_brightness_rect.anchor_right = 1.0
	_brightness_rect.anchor_bottom = 1.0
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_rect.color = Color(0, 0, 0, 0)
	_brightness_layer.add_child(_brightness_rect)

## Apply a brightness multiplier. 1.0 = no overlay. <1.0 darkens via alpha
## black overlay; >1.0 brightens via additive white overlay. Range extended
## down to 0.25 so the user can heavily dim an over-exposed scene.
func apply_brightness(value: float) -> void:
	brightness = clampf(value, 0.25, 1.6)
	_ensure_brightness_overlay()
	if not is_instance_valid(_brightness_rect):
		return
	if brightness < 1.0:
		# Dark overlay — alpha scales with how far below 1.0 we are.
		# At 0.25 (min), alpha=0.82 (very heavy darken — for rescuing scenes
		# whose environment is blown out). At 0.99, alpha~0.01.
		var dark_alpha: float = clampf((1.0 - brightness) * 1.10, 0.0, 0.85)
		_brightness_rect.color = Color(0, 0, 0, dark_alpha)
		_brightness_rect.material = null
	else:
		# Bright overlay — additive white tint.
		# At 1.0, alpha=0 (no effect). At 1.6, alpha=0.5.
		var bright_alpha: float = clampf((brightness - 1.0) * 0.85, 0.0, 0.5)
		_brightness_rect.color = Color(1, 1, 1, bright_alpha)
		# Use additive blend so we brighten instead of just adding a white film.
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_brightness_rect.material = mat

func save_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("General", "selected_actor_type", selected_actor_type)
	config.set_value("General", "selected_weapon_index", selected_weapon_index)
	config.set_value("General", "selected_ability_index", selected_ability_index)
	config.set_value("General", "selected_armor_index", selected_armor_index)
	config.set_value("General", "selected_control_mode", selected_control_mode)
	config.set_value("General", "invert_look_x", invert_look_x)
	config.set_value("General", "invert_look_y", invert_look_y)
	config.set_value("General", "grid_width", grid_width)
	config.set_value("General", "grid_height", grid_height)
	
	config.set_value("NPCs", "fire_count", fire_count)
	config.set_value("NPCs", "water_count", water_count)
	config.set_value("NPCs", "goat_count", goat_count)
	
	config.set_value("WorldGen", "noise_seed", noise_seed)
	config.set_value("WorldGen", "noise_frequency", noise_frequency)
	config.set_value("WorldGen", "height_step", height_step)
	config.set_value("WorldGen", "dirt_threshold", dirt_threshold)
	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Video", "brightness", brightness)

	var err = config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save settings to %s" % SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return # No settings file exists yet, using defaults
	
	selected_actor_type = config.get_value("General", "selected_actor_type", selected_actor_type)
	selected_weapon_index = config.get_value("General", "selected_weapon_index", selected_weapon_index)
	selected_ability_index = config.get_value("General", "selected_ability_index", selected_ability_index)
	selected_armor_index = config.get_value("General", "selected_armor_index", selected_armor_index)
	selected_control_mode = config.get_value("General", "selected_control_mode", selected_control_mode)
	invert_look_x = config.get_value("General", "invert_look_x", invert_look_x)
	invert_look_y = config.get_value("General", "invert_look_y", invert_look_y)
	grid_width = config.get_value("General", "grid_width", grid_width)
	grid_height = config.get_value("General", "grid_height", grid_height)
	
	fire_count = config.get_value("NPCs", "fire_count", fire_count)
	water_count = config.get_value("NPCs", "water_count", water_count)
	goat_count = config.get_value("NPCs", "goat_count", goat_count)
	
	noise_seed = config.get_value("WorldGen", "noise_seed", noise_seed)
	noise_frequency = config.get_value("WorldGen", "noise_frequency", noise_frequency)
	height_step = config.get_value("WorldGen", "height_step", height_step)
	dirt_threshold = config.get_value("WorldGen", "dirt_threshold", dirt_threshold)
	master_volume = config.get_value("Audio", "master_volume", master_volume)
	brightness = config.get_value("Video", "brightness", brightness)
