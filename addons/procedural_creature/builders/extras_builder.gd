class_name ExtrasBuilder

## Generates optional body extras: tail, wings, horns.
##
## Returns Array[ArrayMesh] — one mesh per segment — so ShapeAssembler
## can parent each segment to its own BoneAnchor node for animation.
## Segments are ordered root → tip.
##
## Phase 3 scope: tail only. Wings and horns are stubs returning [].

## Build a tail as a chain of tapered segments.
##   segments     — number of bone segments (4 at MODERATE, full value at COMPLEX)
##   total_length — full tail length in metres
##   base_radius  — radius at the root where the tail meets the hips
##   detail_level — controls segment count and sides per LimbBuilder
static func build_tail(
		segments: int,
		total_length: float,
		base_radius: float,
		detail_level: int) -> Array[ArrayMesh]:

	var meshes: Array[ArrayMesh] = []
	if segments <= 0:
		return meshes

	# At MODERATE, cap to 4 segments regardless of definition value
	var actual_segments: int = segments
	if detail_level == CreatureDefinition.DetailLevel.MODERATE:
		actual_segments = mini(segments, 4)

	var sides: int = LimbBuilder.resolve_sides(detail_level)
	var seg_len: float = total_length / float(actual_segments)

	for i in range(actual_segments):
		# t goes from 0 (root) to 1 (tip)
		var t_root: float = float(i)       / float(actual_segments)
		var t_tip:  float = float(i + 1)   / float(actual_segments)
		# Taper to 35% of base radius by the tip — feels natural, not too pointy
		var r_root: float = base_radius * (1.0 - t_root * 0.65)
		var r_tip:  float = maxf(base_radius * (1.0 - t_tip * 0.65), 0.008)
		meshes.append(LimbBuilder.build(seg_len, r_tip, r_root, sides))

	return meshes

## Wings — stub. Returns empty array. Implement post-Phase 9.
static func build_wings(_span: float, _detail_level: int) -> Array[ArrayMesh]:
	return []

## Horns — stub. Returns empty array. Implement post-Phase 9.
static func build_horns(_count: int, _detail_level: int) -> Array[ArrayMesh]:
	return []
