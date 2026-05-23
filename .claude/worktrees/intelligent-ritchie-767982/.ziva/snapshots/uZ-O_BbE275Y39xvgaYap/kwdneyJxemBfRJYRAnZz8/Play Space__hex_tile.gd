class_name HexTile
extends StaticBody3D

enum Type { GRASS, DIRT, FIRE, STONE, MUD, PUDDLE }
enum SubType { DEFAULT, TREE, STUMP, BURNT_STUMP }
enum State { GRASS, DIRT, MUD, FIRE, PUDDLE, STONE, TREE, BURNING_TREE, STUMP, BURNING_STUMP, BURNT_STUMP, BURNING_BURNT_STUMP }

@export var current_state: State = State.GRASS:
	set(value):
		current_state = value
		_sync_types_from_state()
		_update_appearance()

var tile_type: Type = Type.GRASS
var tile_subtype: SubType = SubType.DEFAULT

var fire_duration: float = 0.0
var fire_spread_triggered: bool = false
var mud_duration: float = 0.0
var puddle_duration: float = 0.0
var regrow_duration: float = 0.0
var neighbors: Array[HexTile] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var fire_particles: GPUParticles3D = $FireParticles
@onready var tree_sprite: Sprite3D = $TreeSprite
@onready var debug_label: Label3D = $DebugLabel

static var debug_enabled: bool = false

# Colors for base types (with some variations for subtypes)
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

func _sync_types_from_state() -> void:
	match current_state:
		State.GRASS: 
			tile_type = Type.GRASS; tile_subtype = SubType.DEFAULT
		State.DIRT: 
			tile_type = Type.DIRT; tile_subtype = SubType.DEFAULT
		State.MUD: 
			tile_type = Type.MUD; tile_subtype = SubType.DEFAULT
		State.FIRE: 
			tile_type = Type.FIRE; tile_subtype = SubType.DEFAULT
		State.PUDDLE: 
			tile_type = Type.PUDDLE; tile_subtype = SubType.DEFAULT
		State.STONE: 
			tile_type = Type.STONE; tile_subtype = SubType.DEFAULT
		State.TREE: 
			tile_type = Type.GRASS; tile_subtype = SubType.TREE
		State.BURNING_TREE: 
			tile_type = Type.FIRE; tile_subtype = SubType.TREE
		State.STUMP: 
			tile_type = Type.GRASS; tile_subtype = SubType.STUMP
		State.BURNING_STUMP: 
			tile_type = Type.FIRE; tile_subtype = SubType.STUMP
		State.BURNT_STUMP: 
			tile_type = Type.DIRT; tile_subtype = SubType.BURNT_STUMP
		State.BURNING_BURNT_STUMP: 
			tile_type = Type.FIRE; tile_subtype = SubType.BURNT_STUMP

func _sync_state_from_types() -> void:
	match tile_type:
		Type.GRASS:
			match tile_subtype:
				SubType.TREE: current_state = State.TREE
				SubType.STUMP: current_state = State.STUMP
				_: current_state = State.GRASS
		Type.DIRT:
			match tile_subtype:
				SubType.BURNT_STUMP: current_state = State.BURNT_STUMP
				_: current_state = State.DIRT
		Type.FIRE:
			match tile_subtype:
				SubType.TREE: current_state = State.BURNING_TREE
				SubType.STUMP: current_state = State.BURNING_STUMP
				SubType.BURNT_STUMP: current_state = State.BURNING_BURNT_STUMP
				_: current_state = State.FIRE
		Type.STONE: current_state = State.STONE
		Type.MUD: current_state = State.MUD
		Type.PUDDLE: current_state = State.PUDDLE

func _ready() -> void:
	_sync_types_from_state()
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
	if tile_type == Type.FIRE:
		fire_duration += delta
		
		# Spread fire after 4 seconds to a random grass/tree neighbor
		if fire_duration >= 4.0 and not fire_spread_triggered:
			fire_spread_triggered = true
			_spread_fire()
			
		# Extinguish/Transition after 5 seconds
		if fire_duration >= 5.0:
			fire_duration = 0.0
			fire_spread_triggered = false
			match tile_subtype:
				SubType.DEFAULT: # Burning Grass
					current_state = State.DIRT
				SubType.TREE, SubType.STUMP: # Burning Tree or Stump
					current_state = State.BURNT_STUMP
				SubType.BURNT_STUMP: # Burning Burnt Stump
					current_state = State.DIRT
			
	elif tile_type == Type.MUD:
		if _has_adjacent_grass():
			mud_duration += delta
			if mud_duration >= 5.0:
				current_state = State.GRASS
				mud_duration = 0.0
		else:
			mud_duration = 0.0
			
	elif tile_type == Type.PUDDLE:
		var dirt_neighbor = _get_adjacent_dirt()
		if dirt_neighbor:
			puddle_duration += delta
			if puddle_duration >= 5.0:
				dirt_neighbor.current_state = State.MUD
				puddle_duration = 0.0
		else:
			puddle_duration = 0.0
			
	elif tile_type == Type.GRASS and tile_subtype == SubType.STUMP:
		regrow_duration += delta
		if regrow_duration >= 10.0:
			current_state = State.TREE
			regrow_duration = 0.0
	
	_update_debug_label()

func _update_debug_label() -> void:
	if not debug_label:
		return
	
	if not debug_enabled:
		debug_label.visible = false
		return
	
	var text = ""
	if tile_type == Type.FIRE:
		text = "%d" % ceil(5.0 - fire_duration)
	elif tile_type == Type.MUD:
		if _has_adjacent_grass():
			text = "%d" % ceil(5.0 - mud_duration)
	elif tile_type == Type.DIRT and tile_subtype == SubType.DEFAULT:
		var max_p_dur = 0.0
		for n in neighbors:
			if n.tile_type == Type.PUDDLE and n._get_adjacent_dirt() == self:
				max_p_dur = max(max_p_dur, n.puddle_duration)
		if max_p_dur > 0:
			text = "%d" % ceil(5.0 - max_p_dur)
	elif tile_type == Type.GRASS and tile_subtype == SubType.STUMP:
		text = "%d" % ceil(10.0 - regrow_duration)
	
	if text == "":
		debug_label.visible = false
	else:
		debug_label.visible = true
		debug_label.text = text

func _has_adjacent_grass() -> bool:
	for neighbor in neighbors:
		if neighbor.tile_type == Type.GRASS:
			return true
	return false

func _get_adjacent_dirt() -> HexTile:
	for neighbor in neighbors:
		if neighbor.tile_type == Type.DIRT and neighbor.tile_subtype == SubType.DEFAULT:
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
	
	if tile_type == Type.STONE:
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
		match tile_subtype:
			SubType.TREE:
				tree_sprite.visible = true
				tree_sprite.texture = load("res://assets/generated/tree_simple_frame_0_1774734106.png")
			SubType.STUMP:
				tree_sprite.visible = true
				tree_sprite.texture = load("res://assets/generated/stump_simple_frame_0_1774734105.png")
			SubType.BURNT_STUMP:
				tree_sprite.visible = true
				tree_sprite.texture = load("res://assets/generated/burnt_stump_simple_frame_0_1774734102.png")
			_:
				tree_sprite.visible = false
	
	if fire_particles:
		fire_particles.emitting = (tile_type == Type.FIRE)

func apply_element(element: String) -> bool:
	match element:
		"fire":
			return apply_fire()
		"water":
			return apply_water()
	return false

func apply_fire() -> bool:
	if tile_type == Type.FIRE or tile_type == Type.STONE:
		return false
		
	match tile_type:
		Type.GRASS:
			if tile_subtype == SubType.TREE:
				current_state = State.BURNING_TREE
			elif tile_subtype == SubType.STUMP:
				current_state = State.BURNING_STUMP
			else:
				current_state = State.FIRE
			fire_duration = 0.0
			fire_spread_triggered = false
			return true
		Type.DIRT:
			if tile_subtype == SubType.BURNT_STUMP:
				current_state = State.BURNING_BURNT_STUMP
			else:
				current_state = State.FIRE
			fire_duration = 0.0
			fire_spread_triggered = false
			return true
		Type.MUD:
			current_state = State.DIRT
			return true
		Type.PUDDLE:
			current_state = State.MUD
			return true
	return false

func apply_water() -> bool:
	if tile_type == Type.FIRE:
		current_state = State.STUMP
		regrow_duration = 0.0
		fire_spread_triggered = false
		fire_duration = 0.0
		return true
		
	match tile_type:
		Type.DIRT:
			if tile_subtype == SubType.BURNT_STUMP:
				current_state = State.STUMP
				regrow_duration = 0.0
			else:
				current_state = State.MUD
				mud_duration = 0.0
			return true
		Type.MUD:
			current_state = State.PUDDLE
			puddle_duration = 0.0
			return true
	return false


func _spread_fire() -> void:
	var shuffled_neighbors = neighbors.duplicate()
	shuffled_neighbors.shuffle()
	for neighbor in shuffled_neighbors:
		if neighbor.apply_fire():
			break
