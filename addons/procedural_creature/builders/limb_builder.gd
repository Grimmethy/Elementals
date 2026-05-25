class_name LimbBuilder

## Generates a tapered cylinder (frustum) mesh using SurfaceTool.
##
## Flat shading is achieved by giving every vertex of a face the same normal,
## computed from the face's cross product — NOT from Godot's calculate_normals().
## This is the most common failure point: calculate_normals() smooths across
## shared vertices and destroys the low-poly look. Never call it here.
##
## Used for all limb segments: upper arm, forearm, thigh, shin, neck.

## Build a tapered cylinder.
##   length        — total length of the segment along Y
##   radius_top    — radius at the top (y = length)
##   radius_bottom — radius at the base (y = 0)
##   sides         — number of faces around the circumference (4 / 6 / 8)
static func build(length: float, radius_top: float, radius_bottom: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Precompute vertex rings so we don't repeat trig per face
	var bottom_ring: Array[Vector3] = []
	var top_ring: Array[Vector3] = []
	for i in range(sides):
		var angle: float = i * TAU / sides
		var c: float = cos(angle)
		var s: float = sin(angle)
		bottom_ring.append(Vector3(c * radius_bottom, 0.0,    s * radius_bottom))
		top_ring.append(   Vector3(c * radius_top,    length, s * radius_top))

	# ------------------------------------------------------------------
	# Side faces
	# Winding order (CCW from outside) for outward normals: b0, t0, t1
	# Each face is a quad split into two triangles sharing the same normal.
	# ------------------------------------------------------------------
	for i in range(sides):
		var b0: Vector3 = bottom_ring[i]
		var b1: Vector3 = bottom_ring[(i + 1) % sides]
		var t0: Vector3 = top_ring[i]
		var t1: Vector3 = top_ring[(i + 1) % sides]

		# Face normal from the first triangle's edges.
		# For a frustum the quad IS planar, so this normal is exact for both tris.
		var normal: Vector3 = (t0 - b0).cross(t1 - b0).normalized()

		# Triangle 1
		st.set_normal(normal); st.add_vertex(b0)
		st.set_normal(normal); st.add_vertex(t0)
		st.set_normal(normal); st.add_vertex(t1)

		# Triangle 2
		st.set_normal(normal); st.add_vertex(b0)
		st.set_normal(normal); st.add_vertex(t1)
		st.set_normal(normal); st.add_vertex(b1)

	# ------------------------------------------------------------------
	# Bottom cap  — normal points DOWN (-Y)
	# Winding: centre, b[i], b[i+1]  (verified via cross product → -Y)
	# ------------------------------------------------------------------
	var bottom_center := Vector3.ZERO
	for i in range(sides):
		var b0: Vector3 = bottom_ring[i]
		var b1: Vector3 = bottom_ring[(i + 1) % sides]
		st.set_normal(Vector3.DOWN); st.add_vertex(bottom_center)
		st.set_normal(Vector3.DOWN); st.add_vertex(b0)
		st.set_normal(Vector3.DOWN); st.add_vertex(b1)

	# ------------------------------------------------------------------
	# Top cap  — normal points UP (+Y)
	# Winding: centre, t[i+1], t[i]  (reversed; verified via cross product → +Y)
	# ------------------------------------------------------------------
	var top_center := Vector3(0.0, length, 0.0)
	for i in range(sides):
		var t0: Vector3 = top_ring[i]
		var t1: Vector3 = top_ring[(i + 1) % sides]
		st.set_normal(Vector3.UP); st.add_vertex(top_center)
		st.set_normal(Vector3.UP); st.add_vertex(t1)
		st.set_normal(Vector3.UP); st.add_vertex(t0)

	return st.commit()

## Returns the correct side count for a given DetailLevel.
## Pass CreatureDefinition.DetailLevel.SIMPLE / MODERATE / COMPLEX.
static func resolve_sides(detail_level: int) -> int:
	match detail_level:
		CreatureDefinition.DetailLevel.SIMPLE:
			return 4
		CreatureDefinition.DetailLevel.COMPLEX:
			return 8
		_:
			return 6  # MODERATE
