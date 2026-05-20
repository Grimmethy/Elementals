class_name HexTile
extends StaticBody3D

enum State { GRASS, DIRT, MUD, FIRE, PUDDLE, STONE, TREE, BURNING_TREE, STUMP, BURNING_STUMP, BURNT_STUMP, BURNING_BURNT_STUMP }

@export var current_state: State = State.GRASS:
	set(value):
		current_state = value
		_update_appearance()

var fire_duration: float = 0.0
var fire_spread_triggered: bool = false
var mud_duration: float = 0.0
var puddle_duration: float = 0.0
var tree_burn_duration: float = 0.0
var stump_regrow_duration: float = 0.0
var stump_burn_duration: float = 0.0
var burnt_stump_burn_duration: float = 0.0
var neighbors: Array[HexTile] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var fire_particles: GPUParticles3D = $FireParticles
@onready var tree_sprite: Sprite3D = $TreeSprite
@onready var debug_label: Label3D = $DebugLabel

static var debug_enabled: bool = false

# Colors for states
const COLORS = {
	State.GRASS: Color(0.2, 0.6, 0.2),
	State.DIRT: Color(0.4, 0.3, 0.1),
	State.MUD: Color(0.25, 0.2, 0.15),
	State.FIRE: Color(1.0, 0.4, 0.0),
	State.PUDDLE: Color(0.2, 0.4, 0.8),
	State.STONE: Color(0.5, 0.5, 0.5),
	State.TREE: Color(0.1, 0.5, 0.1),
	State.BURNING_TREE: Color(1.0, 0.2, 0.0),
	State.STUMP: Color(0.3, 0.2, 0.1),
	State.BURNING_STUMP: Color(0.9, 0.3, 0.0),
	State.BURNT_STUMP: Color(0.1, 0.05, 0.0),
	State.BURNING_BURNT_STUMP: Color(0.8, 0.1, 0.0)
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
			
	elif current_state == State.MUD:
		if _has_adjacent_grass():
			mud_duration += delta
			if mud_duration >= 5.0:
				current_state = State.GRASS
				mud_duration = 0.0
		else:
			mud_duration = 0.0
	elif current_state == State.PUDDLE:
		var dirt_neighbor = _get_adjacent_dirt()
		if dirt_neighbor:
			puddle_duration += delta
			if puddle_duration >= 5.0:
				dirt_neighbor.current_state = State.MUD
				puddle_duration = 0.0
		else:
			puddle_duration = 0.0
	elif current_state == State.BURNING_TREE:
		tree_burn_duration += delta
		if tree_burn_duration >= 5.0:
			current_state = State.BURNT_STUMP
			tree_burn_duration = 0.0
	elif current_state == State.STUMP:
		stump_regrow_duration += delta
		if stump_regrow_duration >= 10.0:
			current_state = State.TREE
			stump_regrow_duration = 0.0
	elif current_state == State.BURNING_STUMP:
		stump_burn_duration += delta
		if stump_burn_duration >= 5.0:
			current_state = State.BURNT_STUMP
			stump_burn_duration = 0.0
	elif current_state == State.BURNING_BURNT_STUMP:
		burnt_stump_burn_duration += delta
		if burnt_stump_burn_duration >= 5.0:
			current_state = State.DIRT
			burnt_stump_burn_duration = 0.0
	
	_update_debug_label()

func _update_debug_label() -> void:
	if not debug_label:
		return
	
	if not debug_enabled:
		debug_label.visible = false
		return
	
	var text = ""
	match current_state:
		State.FIRE:
			text = "%d" % ceil(5.0 - fire_duration)
		State.MUD:
			if _has_adjacent_grass():
				text = "%d" % ceil(5.0 - mud_duration)
		State.DIRT:
			var max_p_dur = 0.0
			for n in neighbors:
				if n.current_state == State.PUDDLE and n._get_adjacent_dirt() == self:
					max_p_dur = max(max_p_dur, n.puddle_duration)
			if max_p_dur > 0:
				text = "%d" % ceil(5.0 - max_p_dur)
		State.BURNING_TREE:
			text = "%d" % ceil(5.0 - tree_burn_duration)
		State.STUMP:
			text = "%d" % ceil(10.0 - stump_regrow_duration)
		State.BURNING_STUMP:
			text = "%d" % ceil(5.0 - stump_burn_duration)
		State.BURNING_BURNT_STUMP:
			text = "%d" % ceil(5.0 - burnt_stump_burn_duration)
	
	if text == "":
		debug_label.visible = false
	else:
		debug_label.visible = true
		debug_label.text = text

func _has_adjacent_grass() -> bool:
	for neighbor in neighbors:
		if neighbor.current_state == State.GRASS:
			return true
	return false

func _get_adjacent_dirt() -> HexTile:
	for neighbor in neighbors:
		if neighbor.current_state == State.DIRT:
			return neighbor
	return null

func _update_appearance() -> void:
	if not is_inside_tree(): return
	
	if not mesh_instance: return
	
	var mat = mesh_instance.get_active_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, mat)
	
	mat.albedo_color = COLORS[current_state]
	
	if current_state == State.STONE:
		mesh_instance.scale.y = 10.0
		mesh_instance.position.y = 0.9
		if collision_shape:
			collision_shape.scale.y = 10.0
			collision_shape.position.y = 0.9
	else:
		mesh_instance.scale.y = 1.0
		mesh_instance.position.y = 0.0
		if collision_shape:
			collision_shape.scale.y = 1.0
			collision_shape.position.y = 0.0
	
	if tree_sprite:
		match current_state:
			State.TREE, State.BURNING_TREE:
				tree_sprite.visible = true
				tree_sprite.texture = load("res://assets/generated/tree_simple_frame_0_1774731893.png")
			State.STUMP, State.BURNING_STUMP:
				tree_sprite.visible = true
				tree_sprite.texture = load("res://assets/generated/stump_simple_frame_0_1774731902.png")
			State.BURNT_STUMP, State.BURNING_BURNT_STUMP:
				tree_sprite.visible = true
				tree_sprite.texture = load("res://assets/generated/burnt_stump_simple_frame_0_1774732189.png")
			_:
				tree_sprite.visible = false
	
	if fire_particles:
		fire_particles.emitting = (current_state == State.FIRE or current_state == State.BURNING_TREE or current_state == State.BURNING_STUMP or current_state == State.BURNING_BURNT_STUMP)

func apply_element(element: String) -> bool:
	match element:
		"fire":
			return apply_fire()
		"water":
			return apply_water()
	return false

func apply_fire() -> bool:
	match current_state:
		State.GRASS:
			current_state = State.FIRE
			fire_duration = 0.0
			fire_spread_triggered = false
			return true
		State.TREE:
			current_state = State.BURNING_TREE
			tree_burn_duration = 0.0
			return true
		State.MUD:
			current_state = State.DIRT
			return true
		State.PUDDLE:
			current_state = State.MUD
			return true
		State.STUMP:
			current_state = State.BURNING_STUMP
			stump_burn_duration = 0.0
			return true
		State.BURNT_STUMP:
			current_state = State.BURNING_BURNT_STUMP
			burnt_stump_burn_duration = 0.0
			return true
		State.FIRE, State.STONE, State.BURNING_TREE, State.BURNING_STUMP, State.BURNING_BURNT_STUMP:
			return false
	return false

func apply_water() -> bool:
	match current_state:
		State.FIRE:
			current_state = State.DIRT
			return true
		State.BURNING_TREE:
			current_state = State.STUMP
			stump_regrow_duration = 0.0
			return true
		State.BURNING_STUMP:
			current_state = State.STUMP
			stump_regrow_duration = 0.0
			return true
		State.BURNT_STUMP:
			current_state = State.STUMP
			stump_regrow_duration = 0.0
			return true
		State.BURNING_BURNT_STUMP:
			current_state = State.STUMP
			stump_regrow_duration = 0.0
			return true
		State.DIRT:
			current_state = State.MUD
			mud_duration = 0.0
			return true
		State.MUD:
			current_state = State.PUDDLE
			return true
		State.GRASS, State.STONE, State.PUDDLE, State.TREE, State.STUMP:
			return false
	return false


func _spread_fire() -> void:
	for neighbor in neighbors:
		if neighbor.current_state == State.GRASS:
			neighbor.apply_fire()
			# Only spread to one neighbor as per "a neighboring grass tile"
			break
