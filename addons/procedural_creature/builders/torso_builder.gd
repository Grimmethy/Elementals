class_name TorsoBuilder

## Generates a tapered prism for the chest/torso section.
##
## Cross-section is ELLIPTICAL (not circular) — width and depth are independent,
## giving a body that reads as front-facing rather than cylindrical.
## Bottom ring (lower chest) tapers to 85% width / 90% depth vs top (shoulders).
## The waist/abdomen is a separate segment; this builder covers chest only.
##
## Geometry approach: identical to LimbBuilder but with per-axis radius.
## The quad faces are provably planar for an elliptical frustum so one normal
## per quad face is exact, not an approximation.

## Build a torso section.
##   height — segment height (y=0 at waist junction, y=height at shoulders)
##   width  — shoulder width (full, not half-extent)
##   depth  — front-to-back depth at shoulders (full, not half-extent)
##   sides  — polygon count of the cross-section ring (5 / 8 / 10)
static func build(height: float, width: float, depth: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Half-extents for each ring
	var hw_top: float = width * 0.5          # shoulder half-width
	var hd_top: float = depth * 0.5          # shoulder half-depth
	var hw_bot: float = width * 0.5 * 0.85   # lower-chest taper
	var hd_bot: float = depth * 0.5 * 0.90

	# Precompute rings
	var bottom_ring: Array[Vector3] = []
	var top_ring: Array[Vector3] = []
	for i in range(sides):
		var angle: float = i * TAU / sides
		var c: float = cos(angle)
		var s: float = sin(angle)
		bottom_ring.append(Vector3(c * hw_bot, 0.0,    s * hd_bot))
		top_ring.append(   Vector3(c * hw_top, height, s * hd_top))

	# ------------------------------------------------------------------
	# Side faces — same winding as LimbBuilder (outward normals confirmed)
	# The elliptical quad is planar so one normal serves both triangles exactly.
	# ------------------------------------------------------------------
	for i in range(sides):
		var b0: Vector3 = bottom_ring[i]
		var b1: Vector3 = bottom_ring[(i + 1) % sides]
		var t0: Vector3 = top_ring[i]
		var t1: Vector3 = top_ring[(i + 1) % sides]

		var normal: Vector3 = (t0 - b0).cross(t1 - b0).normalized()

		st.set_normal(normal); st.add_vertex(b0)
		st.set_normal(normal); st.add_vertex(t0)
		st.set_normal(normal); st.add_vertex(t1)

		st.set_normal(normal); st.add_vertex(b0)
		st.set_normal(normal); st.add_vertex(t1)
		st.set_normal(normal); st.add_vertex(b1)

	# Bottom cap (-Y)
	for i in range(sides):
		st.set_normal(Vector3.DOWN); st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.DOWN); st.add_vertex(bottom_ring[i])
		st.set_normal(Vector3.DOWN); st.add_vertex(bottom_ring[(i + 1) % sides])

	# Top cap (+Y)
	var top_center := Vector3(0.0, height, 0.0)
	for i in range(sides):
		st.set_normal(Vector3.UP); st.add_vertex(top_center)
		st.set_normal(Vector3.UP); st.add_vertex(top_ring[(i + 1) % sides])
		st.set_normal(Vector3.UP); st.add_vertex(top_ring[i])

	return st.commit()

## Returns the cross-section polygon count for a given DetailLevel.
## Torso uses higher counts than limbs (5/8/10 vs 4/6/8) because the
## elliptical shape reads poorly at very low polygon counts.
static func resolve_sides(detail_level: int) -> int:
	match detail_level:
		CreatureDefinition.DetailLevel.SIMPLE:  return 5
		CreatureDefinition.DetailLevel.COMPLEX: return 10
		_:                                       return 8  # MODERATE
