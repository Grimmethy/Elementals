class_name HeadBuilder

## Generates head geometry, routed by HeadShape and DetailLevel.
##
## All shapes produce a mesh from y=0 (neck attachment point) to y=2*sy (crown).
## This keeps the attachment convention consistent with LimbBuilder and TorsoBuilder
## so ShapeAssembler can stack parts without special-casing the head.
##
## Detail routing:
##   SIMPLE              → box always, regardless of head_shape
##   MODERATE / COMPLEX  → shape-matched geometry (sphere, box variants)
##
## build() takes explicit half-extents (sx, sy, sz) rather than a raw scale
## multiplier so ShapeAssembler has full control over head dimensions.
## A typical MODERATE human head: sx=0.12, sy=0.15, sz=0.12.

## Build a head mesh.
##   sx, sy, sz   — half-extents: total head size = (2*sx, 2*sy, 2*sz)
##   head_shape   — CreatureDefinition.HeadShape enum value
##   detail_level — CreatureDefinition.DetailLevel enum value
static func build(sx: float, sy: float, sz: float, head_shape: int, detail_level: int) -> ArrayMesh:
	# SIMPLE always returns a plain box — readable at distance, minimal cost.
	if detail_level == CreatureDefinition.DetailLevel.SIMPLE:
		return _build_box(sx, sy, sz)

	match head_shape:
		CreatureDefinition.HeadShape.ROUND:
			var lat: int = 3 if detail_level == CreatureDefinition.DetailLevel.MODERATE else 5
			var lon: int = 6 if detail_level == CreatureDefinition.DetailLevel.MODERATE else 8
			return _build_sphere(sx, sy, sz, lat, lon)
		CreatureDefinition.HeadShape.ELONGATED:
			# Taller than wide — elongated cranium
			return _build_box(sx, sy * 1.4, sz)
		CreatureDefinition.HeadShape.FLAT:
			# Wider and shallower — flat-faced, broad
			return _build_box(sx * 1.2, sy * 0.7, sz)
		_:
			# ANGULAR, HORNED (horns added by ExtrasBuilder on top), default
			return _build_box(sx, sy, sz)

# ------------------------------------------------------------------
# Internal: Box
# Vertices from y=0 (bottom) to y=2*hy (top), centered in X and Z.
# All 6 faces flat-shaded. Winding orders verified via cross product.
# ------------------------------------------------------------------
static func _build_box(hx: float, hy: float, hz: float) -> ArrayMesh:
	var o := Vector3(0.0, hy, 0.0)  # offset so the box sits on y=0
	var nnn := Vector3(-hx, -hy, -hz) + o
	var pnn := Vector3( hx, -hy, -hz) + o
	var npn := Vector3(-hx,  hy, -hz) + o
	var ppn := Vector3( hx,  hy, -hz) + o
	var nnp := Vector3(-hx, -hy,  hz) + o
	var pnp := Vector3( hx, -hy,  hz) + o
	var npp := Vector3(-hx,  hy,  hz) + o
	var ppp := Vector3( hx,  hy,  hz) + o

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, nnp, pnp, ppp, npp)  # +Z front
	_add_quad(st, pnn, nnn, npn, ppn)  # -Z back
	_add_quad(st, npn, npp, ppp, ppn)  # +Y top
	_add_quad(st, nnn, pnn, pnp, nnp)  # -Y bottom
	_add_quad(st, pnn, ppn, ppp, pnp)  # +X right
	_add_quad(st, nnn, nnp, npp, npn)  # -X left
	return st.commit()

# ------------------------------------------------------------------
# Internal: Sphere
# Latitude/longitude sphere with flat-shaded faces.
# Sits on y=0 (bottom pole) to y=2*sy (top pole).
# lat_segs: rings between the poles. lon_segs: slices around.
# Winding orders verified via cross product for all three regions.
# ------------------------------------------------------------------
static func _build_sphere(sx: float, sy: float, sz: float, lat_segs: int, lon_segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build vertex rows:
	#   rows[0]            = [top pole]   at y = 2*sy
	#   rows[1..lat_segs]  = intermediate rings
	#   rows[lat_segs+1]   = [bottom pole] at y = 0
	var rows: Array = []
	rows.append([Vector3(0.0, sy * 2.0, 0.0)])
	for lat in range(1, lat_segs + 1):
		var theta: float = lat * PI / (lat_segs + 1)
		var sin_t: float = sin(theta)
		var cos_t: float = cos(theta)
		var ring: Array[Vector3] = []
		for lon in range(lon_segs):
			var phi: float = lon * TAU / lon_segs
			# sy*(1 + cos_t) offsets the sphere so the bottom pole lands at y=0
			ring.append(Vector3(
				sx * sin_t * cos(phi),
				sy * (1.0 + cos_t),
				sz * sin_t * sin(phi)
			))
		rows.append(ring)
	rows.append([Vector3(0.0, 0.0, 0.0)])

	# Top cap — winding (pole, v2, v1) gives outward normal (verified)
	var top_pole: Vector3 = rows[0][0]
	var first_ring: Array = rows[1]
	for lon in range(lon_segs):
		var v1: Vector3 = first_ring[lon]
		var v2: Vector3 = first_ring[(lon + 1) % lon_segs]
		var n: Vector3 = (v2 - top_pole).cross(v1 - top_pole).normalized()
		st.set_normal(n); st.add_vertex(top_pole)
		st.set_normal(n); st.add_vertex(v2)
		st.set_normal(n); st.add_vertex(v1)

	# Middle bands — winding (a0,a1,b0) and (a1,b1,b0) gives outward normal (verified)
	for lat in range(1, lat_segs):
		var ring_a: Array = rows[lat]
		var ring_b: Array = rows[lat + 1]
		for lon in range(lon_segs):
			var a0: Vector3 = ring_a[lon]
			var a1: Vector3 = ring_a[(lon + 1) % lon_segs]
			var b0: Vector3 = ring_b[lon]
			var b1: Vector3 = ring_b[(lon + 1) % lon_segs]
			var n: Vector3 = (a1 - a0).cross(b0 - a0).normalized()
			st.set_normal(n); st.add_vertex(a0)
			st.set_normal(n); st.add_vertex(a1)
			st.set_normal(n); st.add_vertex(b0)
			st.set_normal(n); st.add_vertex(a1)
			st.set_normal(n); st.add_vertex(b1)
			st.set_normal(n); st.add_vertex(b0)

	# Bottom cap — winding (pole, v1, v2) gives outward normal (verified)
	var bot_pole: Vector3 = rows[rows.size() - 1][0]
	var last_ring: Array = rows[rows.size() - 2]
	for lon in range(lon_segs):
		var v1: Vector3 = last_ring[lon]
		var v2: Vector3 = last_ring[(lon + 1) % lon_segs]
		var n: Vector3 = (v1 - bot_pole).cross(v2 - bot_pole).normalized()
		st.set_normal(n); st.add_vertex(bot_pole)
		st.set_normal(n); st.add_vertex(v1)
		st.set_normal(n); st.add_vertex(v2)

	return st.commit()

# ------------------------------------------------------------------
# Internal: Quad helper
# v0→v1→v2→v3 must be CCW when viewed from outside.
# Normal is computed from the first triangle and applied to all 6 vertices.
# ------------------------------------------------------------------
static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	var n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
	st.set_normal(n); st.add_vertex(v0)
	st.set_normal(n); st.add_vertex(v1)
	st.set_normal(n); st.add_vertex(v2)
	st.set_normal(n); st.add_vertex(v0)
	st.set_normal(n); st.add_vertex(v2)
	st.set_normal(n); st.add_vertex(v3)
