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
	if fire_particles:
		fire_particles.emitting = false
		if not fire_particles.process_material:
			var material = ParticleProcessMaterial.new()
			material.direction = Vector3.UP
			material.spread = 40.0
			material.initial_velocity_min = 1.5
			material.initial_velocity_max = 2.5
			material.gravity = Vector3(0.0, 3.0, 0.0)
			material.scale_min = 0.2
			material.scale_max = 0.5
			material.color = Color(1.0, 0.4, 0.1)
			fire_particles.process_material = material
		if not fire_particles.draw_pass_1:
			var pass_mesh = QuadMesh.new()
			var p_mat = StandardMaterial3D.new()
			p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			p_mat.vertex_color_use_as_albedo = true
			p_mat.albedo_color = Color(1.0, 0.4, 0.1)
			pass_mesh.material = p_mat
			fire_particles.draw_pass_1 = pass_mesh

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
		State.PUDDLE:
			current_state = State.MUD
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
