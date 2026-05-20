class_name HexTile
extends StaticBody3D

enum State { GRASS, DIRT, MUD, FIRE, PUDDLE }

@export var current_state: State = State.GRASS:
	set(value):
		current_state = value
		_update_appearance()

var fire_duration: float = 0.0
var fire_spread_triggered: bool = false
var neighbors: Array[HexTile] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var fire_particles: GPUParticles3D = $FireParticles

# Colors for states
const COLORS = {
	State.GRASS: Color(0.2, 0.6, 0.2),
	State.DIRT: Color(0.4, 0.3, 0.1),
	State.MUD: Color(0.25, 0.2, 0.15),
	State.FIRE: Color(1.0, 0.4, 0.0),
	State.PUDDLE: Color(0.2, 0.4, 0.8)
}

func _ready() -> void:
	_update_appearance()
	fire_particles.emitting = false

func _process(delta: float) -> void:
	if current_state == State.FIRE:
		fire_duration += delta
		
		# Spread fire after 4 seconds to a random grass neighbor
		if fire_duration >= 4.0 and not fire_spread_triggered:
			fire_spread_triggered = true
			_spread_fire()
			
		# Extinguish after 5 seconds
		if fire_duration >= 5.0:
			current_state = State.DIRT
			fire_duration = 0.0
			fire_spread_triggered = false

func _update_appearance() -> void:
	if not is_inside_tree(): return
	
	if not mesh_instance: return
	
	var mat = mesh_instance.get_active_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, mat)
	
	mat.albedo_color = COLORS[current_state]
	
	if fire_particles:
		fire_particles.emitting = (current_state == State.FIRE)

func apply_fire() -> void:
	match current_state:
		State.GRASS:
			current_state = State.FIRE
			fire_duration = 0.0
			fire_spread_triggered = false
		State.MUD:
			current_state = State.DIRT
		State.FIRE:
			fire_duration = 0.0 # Reset fire timer

func apply_water() -> void:
	match current_state:
		State.FIRE:
			current_state = State.DIRT
		State.DIRT:
			current_state = State.MUD
		State.MUD:
			current_state = State.PUDDLE


func _spread_fire() -> void:
	for neighbor in neighbors:
		if neighbor.current_state == State.GRASS:
			neighbor.apply_fire()
			# Only spread to one neighbor as per "a neighboring grass tile"
			break
