class_name GoatRenderer
extends Control

@export var goat_data: GoatData:
	set(v):
		if goat_data:
			if goat_data.stats_changed.is_connected(update_visuals):
				goat_data.stats_changed.disconnect(update_visuals)
		goat_data = v
		if goat_data:
			goat_data.stats_changed.connect(update_visuals)
		update_visuals()

@onready var body_rect: TextureRect = $Body
@onready var pattern_rect: TextureRect = $Pattern
@onready var horn_rect: TextureRect = $Horns

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

func update_visuals() -> void:
	if not is_node_ready() or not goat_data:
		return
	
	# Body
	body_rect.texture = ASSETS["body"]
	body_rect.self_modulate = goat_data.base_color
	
	# Pattern
	var p_tex = ASSETS["patterns"].get(goat_data.pattern_type)
	pattern_rect.texture = p_tex
	pattern_rect.visible = p_tex != null
	pattern_rect.self_modulate = goat_data.pattern_color
	
	# Horns
	var h_tex = ASSETS["horns"].get(goat_data.horn_type)
	horn_rect.texture = h_tex
	horn_rect.visible = h_tex != null
	# Horns usually aren't tinted by body color, or maybe they are? 
	# Let's keep them as-is or slightly off-white
	horn_rect.self_modulate = Color(0.9, 0.9, 0.8) 
	
	# Body Type Scaling
	var scale_factor = 1.0
	match goat_data.body_type:
		GoatData.BodyType.SMALL: scale_factor = 0.8
		GoatData.BodyType.MEDIUM: scale_factor = 1.0
		GoatData.BodyType.LARGE: scale_factor = 1.2
	
	custom_minimum_size = Vector2(128, 128) * scale_factor
	pivot_offset = size / 2.0
	scale = Vector2.ONE * scale_factor
