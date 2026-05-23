@tool
class_name NetModel
extends Node3D

## Net Model - Visual representation of capture nets
## 5x5 grid of nodes with 40 rope connections and 4 metal corner spheres

# Constants matching Capture.md spec
const GRID_SIZE: int = 5  # 5x5 grid of intersection points
const CORNER_OFFSET: float = 1.0  # Corner spheres offset from center
const ROPE_SEGMENT_LENGTH: float = 0.5  # Length between grid points

# Net states
enum NetState { DEPLOYED, COLLAPSED, STRETCHED }
var current_state: NetState = NetState.DEPLOYED

# Visual components
var corner_spheres: Array[MeshInstance3D] = []
var horizontal_ropes: Array[MeshInstance3D] = []
var vertical_ropes: Array[MeshInstance3D] = []
var grid_nodes: Array[Vector3] = []

# Materials
var metal_material: StandardMaterial3D
var rope_material: StandardMaterial3D

# Sub-resources for scene saving
var corner_sphere_mesh: SphereMesh
var rope_cylinder_mesh: CylinderMesh

func _enter_tree() -> void:
	# Editor-aware setup: prevent duplicate creation
	if get_child_count() > 0:
		_clear_mesh_children()
	
	_setup_materials()
	_generate_grid_nodes()
	_generate_corner_spheres()
	_generate_rope_grid()
	set_state(NetState.DEPLOYED)


func _clear_mesh_children() -> void:
	"""Remove all mesh children (for reinitialization in editor)."""
	var children_to_remove: Array[Node] = []
	for child in get_children():
		children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()


func _ready() -> void:
	# Normal runtime path - editor path handled in _enter_tree
	pass

func _setup_materials() -> void:
	"""Initialize materials for the net."""
	metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.25, 0.22, 0.2, 1)
	metal_material.metallic = 0.9
	metal_material.roughness = 0.4
	
	rope_material = StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.55, 0.45, 0.3, 1)
	rope_material.metallic = 0.0
	rope_material.roughness = 0.95
	
	# Create shared meshes
	corner_sphere_mesh = SphereMesh.new()
	corner_sphere_mesh.radius = 0.05
	corner_sphere_mesh.height = 0.1
	corner_sphere_mesh.radial_segments = 12
	corner_sphere_mesh.rings = 6
	
	rope_cylinder_mesh = CylinderMesh.new()
	rope_cylinder_mesh.top_radius = 0.008
	rope_cylinder_mesh.bottom_radius = 0.008
	rope_cylinder_mesh.height = 1.0
	rope_cylinder_mesh.radial_segments = 8

func _generate_grid_nodes() -> void:
	"""Generate 5x5 grid of node positions."""
	grid_nodes.clear()
	var spacing: float = ROPE_SEGMENT_LENGTH
	
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var x: float = (col - (GRID_SIZE - 1) / 2.0) * spacing
			var z: float = (row - (GRID_SIZE - 1) / 2.0) * spacing
			grid_nodes.append(Vector3(x, 0, z))

func _generate_corner_spheres() -> void:
	"""Create 4 metal spheres at the corners."""
	corner_spheres.clear()
	var offset: float = CORNER_OFFSET
	var corners: Array[Vector3] = [
		Vector3(-offset, 0, -offset),  # Top-left
		Vector3(offset, 0, -offset),   # Top-right
		Vector3(-offset, 0, offset),   # Bottom-left
		Vector3(offset, 0, offset)     # Bottom-right
	]
	
	var container: Node3D = Node3D.new()
	container.name = "CornerSpheres"
	add_child(container)
	
	for i in range(4):
		var sphere: MeshInstance3D = MeshInstance3D.new()
		sphere.name = "Corner_%d" % i
		sphere.mesh = corner_sphere_mesh
		sphere.material_override = metal_material
		sphere.transform.origin = corners[i]
		container.add_child(sphere)
		corner_spheres.append(sphere)

func _generate_rope_grid() -> void:
	"""Create 5x5 grid of ropes: 20 horizontal + 20 vertical = 40 segments."""
	horizontal_ropes.clear()
	vertical_ropes.clear()
	
	var horizontal_container: Node3D = Node3D.new()
	horizontal_container.name = "HorizontalRopes"
	add_child(horizontal_container)
	
	var vertical_container: Node3D = Node3D.new()
	vertical_container.name = "VerticalRopes"
	add_child(vertical_container)
	
	# Generate horizontal ropes (4 segments per row × 5 rows = 20)
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE - 1):
			var start_idx: int = row * GRID_SIZE + col
			var end_idx: int = start_idx + 1
			var rope: MeshInstance3D = _create_rope_segment(grid_nodes[start_idx], grid_nodes[end_idx])
			rope.name = "HRope_%d_%d" % [row, col]
			horizontal_container.add_child(rope)
			horizontal_ropes.append(rope)
	
	# Generate vertical ropes (5 segments per column × 4 columns = 20)
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE - 1):
			var start_idx: int = row * GRID_SIZE + col
			var end_idx: int = start_idx + GRID_SIZE
			var rope: MeshInstance3D = _create_rope_segment(grid_nodes[start_idx], grid_nodes[end_idx])
			rope.name = "VRope_%d_%d" % [row, col]
			vertical_container.add_child(rope)
			vertical_ropes.append(rope)

func _create_rope_segment(start: Vector3, end: Vector3) -> MeshInstance3D:
	"""Create a single rope cylinder connecting two points."""
	var rope: MeshInstance3D = MeshInstance3D.new()
	rope.mesh = rope_cylinder_mesh
	rope.material_override = rope_material
	
	var midpoint: Vector3 = (start + end) / 2.0
	var direction: Vector3 = end - start
	var length: float = direction.length()
	
	# Position at midpoint
	rope.transform.origin = midpoint
	
	# Rotate to align with direction
	if length > 0.001:
		var up: Vector3 = Vector3.UP
		var axis: Vector3 = up.cross(direction.normalized())
		if axis.length() > 0.001:
			var angle: float = up.angle_to(direction)
			rope.transform.basis = Basis(axis.normalized(), angle)
		# Scale to match segment length
		rope.mesh.height = length
	
	return rope

func set_state(state: NetState) -> void:
	"""Set the visual state of the net."""
	current_state = state
	
	match state:
		NetState.DEPLOYED:
			_transform_deployed()
		NetState.COLLAPSED:
			_transform_collapsed()
		NetState.STRETCHED:
			_transform_stretched()

func _transform_deployed() -> void:
	"""Restore net to flat deployed state."""
	var spacing: float = ROPE_SEGMENT_LENGTH
	var index: int = 0
	
	# Restore grid node positions
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var x: float = (col - (GRID_SIZE - 1) / 2.0) * spacing
			var z: float = (row - (GRID_SIZE - 1) / 2.0) * spacing
			grid_nodes[index] = Vector3(x, 0, z)
			index += 1
	
	_update_rope_positions()
	_restore_corner_spheres()

func _transform_collapsed() -> void:
	"""Collapse net into a tightly packed ball."""
	var collapse_radius: float = 0.1
	var index: int = 0
	
	# Gather grid nodes toward center
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var offset: Vector3 = Vector3(
				(col - (GRID_SIZE - 1) / 2.0) * 0.05,
				(row - (GRID_SIZE - 1) / 2.0) * 0.05,
				(row - (GRID_SIZE - 1) / 2.0) * 0.05
			)
			grid_nodes[index] = offset * collapse_radius
			index += 1
	
	_update_rope_positions()
	_collapse_corner_spheres()

func _transform_stretched() -> void:
	"""Stretch the net outward (visual only)."""
	var stretch_factor: float = 1.3
	var spacing: float = ROPE_SEGMENT_LENGTH * stretch_factor
	var index: int = 0
	
	# Expand grid node positions
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var x: float = (col - (GRID_SIZE - 1) / 2.0) * spacing
			var z: float = (row - (GRID_SIZE - 1) / 2.0) * spacing
			grid_nodes[index] = Vector3(x, 0, z)
			index += 1
	
	_update_rope_positions()
	_stretch_corner_spheres(stretch_factor)

func _update_rope_positions() -> void:
	"""Update all rope segments to match current grid node positions."""
	# Update horizontal ropes
	var h_index: int = 0
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE - 1):
			var start_idx: int = row * GRID_SIZE + col
			var end_idx: int = start_idx + 1
			_update_rope_segment(horizontal_ropes[h_index], grid_nodes[start_idx], grid_nodes[end_idx])
			h_index += 1
	
	# Update vertical ropes
	var v_index: int = 0
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE - 1):
			var start_idx: int = row * GRID_SIZE + col
			var end_idx: int = start_idx + GRID_SIZE
			_update_rope_segment(vertical_ropes[v_index], grid_nodes[start_idx], grid_nodes[end_idx])
			v_index += 1

func _update_rope_segment(rope: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	"""Update a single rope segment's position and orientation."""
	var midpoint: Vector3 = (start + end) / 2.0
	var direction: Vector3 = end - start
	var length: float = direction.length()
	
	rope.transform.origin = midpoint
	
	if length > 0.001:
		var up: Vector3 = Vector3.UP
		var axis: Vector3 = up.cross(direction.normalized())
		if axis.length() > 0.001:
			var angle: float = up.angle_to(direction)
			rope.transform.basis = Basis(axis.normalized(), angle)
		else:
			rope.transform.basis = Basis()
		rope.mesh.height = length

func _restore_corner_spheres() -> void:
	"""Restore corner spheres to deployed positions."""
	var offset: float = CORNER_OFFSET
	var corners: Array[Vector3] = [
		Vector3(-offset, 0, -offset),
		Vector3(offset, 0, -offset),
		Vector3(-offset, 0, offset),
		Vector3(offset, 0, offset)
	]
	
	for i in range(4):
		corner_spheres[i].transform.origin = corners[i]

func _collapse_corner_spheres() -> void:
	"""Collapse corner spheres toward center."""
	for sphere in corner_spheres:
		sphere.transform.origin = Vector3.ZERO

func _stretch_corner_spheres(factor: float) -> void:
	"""Expand corner spheres outward."""
	var offset: float = CORNER_OFFSET * factor
	var corners: Array[Vector3] = [
		Vector3(-offset, 0, -offset),
		Vector3(offset, 0, -offset),
		Vector3(-offset, 0, offset),
		Vector3(offset, 0, offset)
	]
	
	for i in range(4):
		corner_spheres[i].transform.origin = corners[i]

## Net Health System (per Capture.md spec)
var net_hp: int = 5  # HP for destruction
var net_ac: int = 10  # Armor class
var is_destroyed: bool = false

func take_damage(amount: int) -> bool:
	"""Apply damage to the net. Returns true if net is destroyed."""
	if is_destroyed:
		return true
	
	net_hp -= amount
	if net_hp <= 0:
		destroy_net()
		return true
	return false

func destroy_net() -> void:
	"""Destroy the net (breaks at random rope segments)."""
	is_destroyed = true
	set_state(NetState.COLLAPSED)
	# In a full implementation, we would hide/destroy individual rope segments
	# For now, visually collapse the entire net