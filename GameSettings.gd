extends Node

var selected_elemental_type: String = "fire" # "fire", "water", or "goat"
var grid_width: int = 20
var grid_height: int = 20
var fire_count: int = 1
var water_count: int = 1
var goat_count: int = 1

var noise_seed: int = 0
var noise_frequency: float = 0.05
var height_step: float = 1.0
