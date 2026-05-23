class_name GoatData
extends Resource

signal stats_changed

@export var base_color: Color = Color.WHITE:
	set(value):
		base_color = value
		stats_changed.emit()
