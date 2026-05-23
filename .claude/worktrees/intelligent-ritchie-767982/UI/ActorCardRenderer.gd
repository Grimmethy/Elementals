class_name ActorCardRenderer
extends Control

## Card-side renderer that dispatches on `ActorData` subclass. The legacy
## `GoatRenderer` was renamed in Patch 3 and gained a polymorphic
## `update_visuals()` so non-goat actor cards stop falling back to a hidden
## renderer. Goats render exactly as before; other types fall back to a
## tinted placeholder Body + name label until per-type renderers ship.

## Primary API — accepts any ActorData subclass and dispatches on type.
@export var actor_data: ActorData:
	set(v):
		if actor_data:
			if actor_data.stats_changed.is_connected(update_visuals):
				actor_data.stats_changed.disconnect(update_visuals)
		actor_data = v
		if actor_data:
			actor_data.stats_changed.connect(update_visuals)
		update_visuals()

## Defensive typed alias — preserves the Patch 2 read-side `goat_data`
## accessor pattern. Reads return `actor_data` narrowed to `GoatData`
## (null for non-goat). Writes route through `actor_data` for back-compat
## with any caller that still touches `renderer.goat_data = some_goat`.
var goat_data: GoatData:
	get: return actor_data as GoatData
	set(v): actor_data = v

const ASSETS = {
	"body": preload("res://assets/experimental/goat_body_quadruped_frame_0_1775009982.png"),
	"patterns": {
		GoatData.PatternType.SOLID: null,
		GoatData.PatternType.PIEBALD: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_1_1775090983.png"), # Placeholder
		GoatData.PatternType.SPOTTED: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_2_1775090983.png"), # Placeholder
	},
	"horns": {
		GoatData.HornType.NONE: null,
		GoatData.HornType.SMALL: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_0_1775090983.png"), # Placeholder
		GoatData.HornType.LARGE: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_0_1775090983.png"), # Placeholder
		GoatData.HornType.SPIRAL: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_3_1775090983.png"), # Placeholder
	}
}

func _ready() -> void:
	update_visuals()

## Polymorphic per-type dispatch. Preserves the goat-only scale logic for
## byte-exact goat regression. Other ActorData subclasses fall through to a
## generic placeholder that tints the Body rect by `base_color` so the card
## is at least visually distinct — full per-type render scenes are a future
## patch.
func update_visuals() -> void:
	if not is_node_ready() or not actor_data:
		return

	if actor_data is GoatData:
		_apply_goat_visuals(actor_data as GoatData)
	else:
		_apply_generic_visuals(actor_data)

## Goat-specific renderer — preserves the pre-Patch-3 byte-exact behavior
## (size+pivot+scale only; ASSETS dict is currently unused but kept for
## the per-type-renderer follow-up patch).
func _apply_goat_visuals(goat: GoatData) -> void:
	var scale_factor := 1.0
	match goat.body_type:
		GoatData.BodyType.SMALL: scale_factor = 0.8
		GoatData.BodyType.MEDIUM: scale_factor = 1.0
		GoatData.BodyType.LARGE: scale_factor = 1.2

	custom_minimum_size = Vector2(128, 128) * scale_factor
	pivot_offset = size / 2.0
	scale = Vector2.ONE * scale_factor

	# Re-tint Body to the goat's color so the placeholder body sprite picks
	# up the genetic color. Pattern/Horns are left to a future per-type
	# render pass (the assets are placeholders today).
	var body := get_node_or_null("Body") as TextureRect
	if body:
		body.modulate = goat.base_color

## Generic placeholder for any non-goat ActorData. Hides the goat-specific
## Pattern/Horns sub-rects (they reference goat-only assets) and tints the
## Body rect by `base_color` so different creature types are at least
## visually distinct on the card. Per-type renderer scenes (a Goblin
## silhouette, an Elemental glow, etc.) are deferred — this keeps the card
## legible until those land.
func _apply_generic_visuals(data: ActorData) -> void:
	# Reset to the default 64x64 footprint so the card layout doesn't
	# inherit a stale scale from a prior goat render.
	custom_minimum_size = Vector2(64, 64)
	pivot_offset = size / 2.0
	scale = Vector2.ONE

	var body := get_node_or_null("Body") as TextureRect
	if body:
		body.modulate = data.base_color

	var pattern := get_node_or_null("Pattern") as TextureRect
	if pattern:
		pattern.visible = false

	var horns := get_node_or_null("Horns") as TextureRect
	if horns:
		horns.visible = false
