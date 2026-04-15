extends Control

@onready var goat_data: GoatData = $Goat/GeneticComponent.goat_data
@onready var slider: HSlider = $VBoxContainer/HSlider
@onready var label: Label = $VBoxContainer/Label

func _ready() -> void:
	slider.value_changed.connect(_on_slider_value_changed)
	_on_slider_value_changed(slider.value)

func _on_slider_value_changed(value: float) -> void:
	# Convert slider value (0-1) to a hue
	var color = Color.from_hsv(value, 0.6, 1.0)
	goat_data.base_color = color
	label.text = "Goat Color Hue: %.2f" % value
