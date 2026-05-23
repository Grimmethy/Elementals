## Represents a single hexagonal tile in the game world.
## Handles terrain state, elemental transitions (fire, water, mud), 
## and interactions with environmental features like trees.
class_name HexTile
extends StaticBody3D

## Possible terrain types for logical checks.
enum Type { GRASS, DIRT, FIRE, STONE, MUD, PUDDLE }
## Subtypes (placeholder for further variations).
enum SubType { DEFAULT }
## States that define both visual appearance and behavior.
enum State { GRASS, DIRT, MUD, FIRE, PUDDLE, STONE }

## The current state of the tile. Changing this triggers a visual update.
@export var current_state: State = State.GRASS:
	set(value):
		var changed = (current_state != value)
		current_state = value
		_sync_types_from_state() # Ensure logic type matches the new state
		_update_appearance()   # Update visuals (mesh, texture, particles)
		if changed:
			check_activeness()
			# When my state changes, my neighbors might change their active status too
			for n in neighbors:
				if is_instance_valid(n):
					n.check_activeness()

## Internal type used for behavior logic (synced from current_state).
var tile_type: Type = Type.GRASS

## Tracking variables for various state durations.
var fire_duration: float = 0.0
var fire_spread_triggered: bool = false
var mud_duration: float = 0.0
var puddle_duration: float = 0.0

## Cached list of adjacent tiles for spreading effects.
var neighbors: Array[HexTile] = []

var is_active: bool = false
var arena: Node3D # Will be cast to ArenaGrid

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var fire_particles: GPUParticles3D = $FireParticles
@onready var debug_label: Label3D = $DebugLabel

## Global debug toggle for all tiles.
static var debug_enabled: bool = false

## Color tints applied to tiles based on state (mostly White as textures provide color).
const COLORS = {
	State.GRASS: Color.WHITE,
	State.DIRT: Color.WHITE,
	State.MUD: Color.WHITE,
	State.FIRE: Color(1.0, 0.4, 0.0), # Orange tint for fire state
	State.PUDDLE: Color.WHITE,
	State.STONE: Color.WHITE,
}

## Textures for each terrain state.
const TEXTURES = {
	State.GRASS: preload("res://assets/generated/grass_hex_tile_frame_0_1774844697.png"),
	State.DIRT: preload("res://assets/generated/dirt_hex_tile_frame_0_1774844719.png"),
	State.MUD: preload("res://assets/generated/mud_hex_tile_frame_0_1774844756.png"),
	State.PUDDLE: preload("res://assets/generated/water_hex_tile_frame_0_1774844916.png"),
	State.STONE: preload("res://assets/generated/stone_hex_tile_frame_0_1774844738.png"),
	State.FIRE: preload("res://assets/generated/dirt_hex_tile_frame_0_1774844719.png"), # Fire uses dirt texture underneath
}

## Syncs the logic 'tile_type' with the visual 'current_state'.
func _sync_types_from_state() -> void:
	match current_state:
		State.GRASS: tile_type = Type.GRASS
		State.DIRT: tile_type = Type.DIRT
		State.MUD: tile_type = Type.MUD
		State.FIRE: tile_type = Type.FIRE
		State.PUDDLE: tile_type = Type.PUDDLE
		State.STONE: tile_type = Type.STONE

func _ready() -> void:
	# Initialize fire particles if they aren't configured
	_setup_fire_particles()
	
	# Initial sync and visual update
	_sync_types_from_state()
	_update_appearance()

## Configures the fire particles material and mesh if not already set.
func _setup_fire_particles() -> void:
	if not fire_particles: return
	
	Elemental.setup_gpu_particles(fire_particles, {
		"amount": 30,
		"spread": 40.0,
		"velocity_min": 1.5,
		"velocity_max": 2.5,
		"gravity": Vector3(0.0, 3.0, 0.0),
		"scale_min": 0.2,
		"scale_max": 0.5,
		"texture": "res://assets/generated/fire_particle_1774823455.png"
	})

func process_tile(delta: float) -> void:
	# State-based logic updates
	match tile_type:
		Type.FIRE:
			fire_duration += delta
			
			# Spread fire to one random neighbor after a delay
			if fire_duration >= 4.0 and not fire_spread_triggered:
				fire_spread_triggered = true
				_spread_fire()
				
			# Extinguish fire after its full duration, leaving behind dirt
			if fire_duration >= 5.0:
				fire_duration = 0.0
				fire_spread_triggered = false
				current_state = State.DIRT
				
		Type.MUD:
			# Mud eventually turns back to grass if it's near other grass (regrowth)
			if _has_adjacent_grass():
				mud_duration += delta
				if mud_duration >= 5.0:
					current_state = State.GRASS
					mud_duration = 0.0
			else:
				mud_duration = 0.0
				check_activeness() # No longer active if no grass neighbors
				
		Type.PUDDLE:
			# Puddles slowly turn adjacent dirt tiles into mud
			var dirt_neighbor = _get_adjacent_dirt()
			if dirt_neighbor:
				puddle_duration += delta
				if puddle_duration >= 5.0:
					dirt_neighbor.current_state = State.MUD
					puddle_duration = 0.0
			else:
				puddle_duration = 0.0
				check_activeness() # No longer active if no dirt neighbors
		
		Type.DIRT:
			# Only active for debug label update.
			# Re-evaluate to see if we should still be active (e.g. if puddle target changed)
			check_activeness()
	
	_update_debug_label()

## Evaluates whether this tile needs active processing.
## Tiles are active if they are FIRE, or MUD near GRASS, or PUDDLE near DIRT.
func check_activeness() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
		
	if not arena:
		arena = get_tree().get_first_node_in_group("arena")
		if not arena:
			return

	var should_be_active = false
	match tile_type:
		Type.FIRE:
			should_be_active = true
		Type.MUD:
			if _has_adjacent_grass():
				should_be_active = true
		Type.PUDDLE:
			if _get_adjacent_dirt():
				should_be_active = true
		Type.DIRT:
			if debug_enabled:
				for n in neighbors:
					# Check if any neighbor is a puddle and we are its current target
					if n.tile_type == Type.PUDDLE and n._get_adjacent_dirt() == self:
						should_be_active = true
						break
	
	if should_be_active != is_active:
		is_active = should_be_active
		if is_active:
			if arena.has_method("register_active_tile"):
				arena.call("register_active_tile", self)
		else:
			if arena.has_method("unregister_active_tile"):
				arena.call("unregister_active_tile", self)
			_update_debug_label()

## Updates the 3D debug text showing remaining time for state transitions.
func _update_debug_label() -> void:
	if not debug_label or not debug_enabled:
		if debug_label: debug_label.visible = false
		return
	
	var text = ""
	if tile_type == Type.FIRE:
		text = "%d" % ceil(5.0 - fire_duration)
	elif tile_type == Type.MUD and _has_adjacent_grass():
		text = "%d" % ceil(5.0 - mud_duration)
	elif tile_type == Type.DIRT:
		# Show mud conversion timer if being affected by a puddle
		var max_p_dur = 0.0
		for n in neighbors:
			if n.tile_type == Type.PUDDLE and n._get_adjacent_dirt() == self:
				max_p_dur = max(max_p_dur, n.puddle_duration)
		if max_p_dur > 0:
			text = "%d" % ceil(5.0 - max_p_dur)
	
	debug_label.text = text
	debug_label.visible = (text != "")

## Returns true if any neighboring tile is currently grass.
func _has_adjacent_grass() -> bool:
	for neighbor in neighbors:
		if neighbor.tile_type == Type.GRASS:
			return true
	return false

## Returns the first neighboring dirt tile found, or null.
func _get_adjacent_dirt() -> HexTile:
	for neighbor in neighbors:
		if neighbor.tile_type == Type.DIRT:
			return neighbor
	return null

## Updates the physical mesh and visual components to match the current state.
func _update_appearance() -> void:
	if not is_inside_tree() or not mesh_instance: return
	
	# Get or create material
	var mat = mesh_instance.get_active_material(0) as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh_instance.set_surface_override_material(0, mat)
	
	# Update material properties
	mat.albedo_color = COLORS[current_state]
	mat.albedo_texture = TEXTURES.get(current_state)
	
	# Handle Stone height (elevated walls)
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
	
	# Toggle fire particles based on state
	if fire_particles:
		fire_particles.emitting = (tile_type == Type.FIRE)

## Primary entry point for elemental interactions (projectiles, spells).
## Delegates to environmental features (trees, etc.) before processing tile state.
func apply_element(element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	# First, let child features (like TreeFeature) handle the element
	var feature_handled = false
	for child in get_children():
		if child.has_method("apply_element"):
			if child.apply_element(element, direction):
				feature_handled = true
	
	# Then handle tile state transitions
	match element:
		"fire":
			return apply_fire() or feature_handled
		"water":
			return apply_water() or feature_handled
	return feature_handled

## Logic for applying fire to this tile.
func apply_fire() -> bool:
	# Stone and already burning tiles are unaffected
	if tile_type == Type.FIRE or tile_type == Type.STONE:
		return false
		
	match tile_type:
		Type.GRASS:
			current_state = State.FIRE
			fire_duration = 0.0
			fire_spread_triggered = false
			return true
		Type.MUD:
			# Fire dries out mud back into dirt
			current_state = State.DIRT
			return true
		Type.PUDDLE:
			# Fire boils away puddles into mud
			current_state = State.MUD
			return true
	return false

## Logic for applying water to this tile.
func apply_water() -> bool:
	# Water extinguishes fire
	if tile_type == Type.FIRE:
		current_state = State.DIRT
		fire_spread_triggered = false
		fire_duration = 0.0
		return true
		
	match tile_type:
		Type.DIRT:
			# Dirt becomes mud when watered
			current_state = State.MUD
			mud_duration = 0.0
			return true
		Type.MUD:
			# Mud becomes a puddle when watered
			current_state = State.PUDDLE
			puddle_duration = 0.0
			return true
	return false

## Attempts to spread fire to one random neighbor.
func _spread_fire() -> void:
	var shuffled_neighbors = neighbors.duplicate()
	shuffled_neighbors.shuffle()
	for neighbor in shuffled_neighbors:
		# If a neighbor successfully catches fire, stop spreading from this tile for now
		if neighbor.apply_fire():
			break
