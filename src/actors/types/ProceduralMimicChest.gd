class_name ProceduralMimicChest
extends Node3D

## Procedural Mimic body generator. Reads MimicData.genome and assembles a
## disguised-furniture body: treasure chest, wooden box, vase, casket, barrel,
## or crate. Decorations (bands, clasps, gems, locks, handles) layer on top
## of whatever shape the genome picks.
##
## Pure mimics NEVER have legs/arms — the limbs slot is wired but stays empty
## unless a hybrid breeding pipeline explicitly flips has_legs / has_arms.
##
## Architecture mirrors ProceduralMushroomBody:
##   - mimic_data setter triggers rebuild_from_genome() on the next tick
##   - sub-roots (_body_root / _lid_pivot / _face_root / _decorations_root /
##     _limbs_root) are torn down + rebuilt without nuking sibling components
##   - all coordinates are in WORLD UNITS (meters). No more voxel scaling —
##     the genome stores real dimensions so cross-shape breeding stays sane.

# === Genome-driven path ====================================================

@export var mimic_data: MimicData = null:
	set(v):
		if mimic_data == v:
			return
		mimic_data = v
		if is_inside_tree():
			rebuild_from_genome()

# === Legacy fallback exports (used only when mimic_data is null) ===========
# These keep the .tscn's default chest spawning gracefully when the actor
# script hasn't yet assigned a MimicData (e.g. in editor preview, or if a
# capture / breed flow forgot to set genome).

@export_group("Legacy Fallback")
@export var use_legacy_variation: bool = true
@export var legacy_seed: int = 0

@export_group("Animation Tuning")
@export var bite_open_angle: float = 65.0
@export var bite_closed_angle: float = 5.0
@export var bite_duration: float = 0.22

# === Internal state ========================================================

var _rng := RandomNumberGenerator.new()
var _body_root: Node3D = null
var _lid_pivot: Node3D = null   # lid + lid-mounted eyes parent to this
var _face_root: Node3D = null   # body-mounted eyes / teeth / tongue
var _tongue_root: Node3D = null
var _decorations_root: Node3D = null
var _limbs_root: Node3D = null

# Cached genome dimensions (world units).
var _W: float = 0.70  # width  (X)
var _H: float = 0.55  # height (Y)
var _D: float = 0.45  # depth  (Z)
var _shape: String = "wooden_box"
var _lid_variant: String = "flat"
var _lid_idle_min_angle: float = 12.0
var _lid_idle_max_angle: float = 28.0
var _lid_idle_speed: float = 1.4
var _lid_base_rotation_x: float = 0.0
var _tongue_protrude: float = 0.35      # 0 retracted .. 1 fully extended
var _tongue_wiggle_speed: float = 3.0
var _tongue_wiggle_amplitude: float = 0.04
var _tongue_length: float = 0.14
# Tongue orientation. For mouth-on-front shapes (box/chest/casket/crate)
# the tongue extends along +Z. For mouth-on-top shapes (vase/barrel) it
# extends along +Y. Set during _add_tongue based on shape.
var _tongue_axis: Vector3 = Vector3(0, 0, 1)
var _tongue_base_pos: Vector3 = Vector3.ZERO
var _bite_time_left: float = 0.0

# === Lifecycle =============================================================

func _ready() -> void:
	_rng.randomize()
	if legacy_seed != 0:
		_rng.seed = legacy_seed
	# Same pattern as ProceduralMushroomBody: don't auto-create a default
	# MimicData here. MimicActor pushes the randomized genome via
	# call_deferred("_push_genome_to_body") on the next frame. Without this
	# guard the body would render a DIFFERENT random chest for 1 frame, then
	# get replaced by the actor's chest — visually noisy.
	#
	# For editor preview of MimicActor.tscn in isolation, manually assign a
	# MimicData resource to the Body's `mimic_data` field in the inspector.
	if mimic_data:
		rebuild_from_genome()

func _process(delta: float) -> void:
	if mimic_data == null:
		return

	var in_object_form: bool = false
	var owner_actor: Node = get_parent()
	if owner_actor:
		in_object_form = bool(owner_actor.get_meta("mimic_object_form", false))

	# Lid animation (only shapes with lids).
	if _lid_pivot:
		if in_object_form:
			# Disguise mode: lid sealed shut with a tiny gap.
			_lid_pivot.rotation_degrees.x = _lid_base_rotation_x - 4.0
		elif _bite_time_left > 0.0:
			_bite_time_left -= delta
			var t: float = clampf(1.0 - (_bite_time_left / bite_duration), 0.0, 1.0)
			var bite_curve: float = pow(1.0 - t, 3.0)
			var angle: float = lerpf(bite_closed_angle, bite_open_angle, bite_curve)
			_lid_pivot.rotation_degrees.x = _lid_base_rotation_x - angle
		else:
			# Idle bob between min and max angles, ADDING to the base — not
			# overwriting it (mushroom-bug lesson applied here too).
			var open_amount: float = sin(Time.get_ticks_msec() / 1000.0 * _lid_idle_speed) * 0.5 + 0.5
			var lid_angle: float = lerpf(_lid_idle_min_angle, _lid_idle_max_angle, open_amount)
			_lid_pivot.rotation_degrees.x = _lid_base_rotation_x - lid_angle

	# Tongue wiggle (always animates, even in disguise it stays inside mouth).
	if _tongue_root and not in_object_form:
		var wiggle: float = sin(Time.get_ticks_msec() / 1000.0 * _tongue_wiggle_speed) * _tongue_wiggle_amplitude
		# Wiggle ADDS to the stored base, doesn't overwrite it. Lessons from
		# the Mushroom bob bug applied: never assign `position.<axis> = wiggle`.
		_tongue_root.position = _tongue_base_pos + _tongue_axis * wiggle

func trigger_bite() -> void:
	_bite_time_left = bite_duration

func rebuild_with_seed(new_seed: int) -> void:
	legacy_seed = new_seed
	_rng.seed = new_seed
	if mimic_data == null:
		mimic_data = MimicData.new()
	mimic_data.randomize_genome()
	rebuild_from_genome()

# === Public API ============================================================

func rebuild_from_genome() -> void:
	_clear_built_children()
	if mimic_data == null:
		return
	# Seed the body RNG with the kid's stable identity so all the randi/randf
	# calls in this rebuild (tooth jitter, lower-tooth-count variation, spot
	# placement, etc.) produce the SAME visual every time. Without this, the
	# creature's body would visibly change every time the card refreshed.
	if mimic_data.render_seed != 0:
		_rng.seed = mimic_data.render_seed
	var g: Dictionary = mimic_data.genome
	var body_slot: Dictionary = g.get("body", {})
	var lid_slot: Dictionary = g.get("lid", {})
	var face_slot: Dictionary = g.get("face", {})
	var palette_slot: Dictionary = g.get("palette", MimicData.default_genome()["palette"])
	var decorations_slot: Dictionary = g.get("decorations", {})
	var limbs_slot: Dictionary = g.get("limbs", {})
	var animation_slot: Dictionary = g.get("animation", {})

	_W = float(body_slot.get("width", 0.70))
	_H = float(body_slot.get("height", 0.55))
	_D = float(body_slot.get("depth", 0.45))
	_shape = String(body_slot.get("shape", "wooden_box"))
	_lid_variant = String(lid_slot.get("variant", "flat"))
	# Clamp lid idle min angle to at least 20° so the lid bobs open enough
	# for the upward-extending tongue to clear the lid underside without
	# clipping. At ≤10° the lid sits almost flat on the body and the tongue
	# tip would punch through it.
	_lid_idle_min_angle = maxf(20.0, float(lid_slot.get("open_angle_idle", 18.0)) * 0.45)
	_lid_idle_max_angle = maxf(35.0, float(lid_slot.get("open_angle_idle", 18.0)) * 1.40)
	_lid_idle_speed = float(animation_slot.get("lid_idle_speed", 1.4))
	_tongue_protrude = clampf(float(face_slot.get("tongue_protrude", 0.35)), 0.0, 1.0)
	_tongue_length = float(face_slot.get("tongue_length", 0.14))
	_tongue_wiggle_speed = float(animation_slot.get("tongue_wiggle_speed", 3.0))
	_tongue_wiggle_amplitude = float(animation_slot.get("tongue_wiggle_amplitude", 0.04))

	# 1) Body shape
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	_build_body_for_shape(_shape, body_slot, palette_slot)

	# 2) Lid (if shape supports one)
	if _lid_variant != "none":
		_lid_pivot = _build_lid(lid_slot, body_slot, palette_slot)
		add_child(_lid_pivot)

	# 3) Face — eyes/teeth/tongue. Eyes either on lid or on body front.
	_face_root = Node3D.new()
	_face_root.name = "Face"
	add_child(_face_root)
	_add_teeth(face_slot, palette_slot)
	_add_tongue(face_slot, palette_slot)
	var eyes_on_lid: bool = bool(face_slot.get("eyes_on_lid", false))
	if eyes_on_lid and _lid_pivot:
		_add_eyes_on_lid(face_slot, palette_slot)
	else:
		_add_eyes_on_body(face_slot, palette_slot)

	# 4) Decorations
	_decorations_root = Node3D.new()
	_decorations_root.name = "Decorations"
	add_child(_decorations_root)
	_add_decorations(decorations_slot, palette_slot)

	# 5) Limbs (only if explicitly enabled — pure mimics never have these)
	_limbs_root = Node3D.new()
	_limbs_root.name = "Limbs"
	add_child(_limbs_root)
	if bool(limbs_slot.get("has_legs", false)) or bool(limbs_slot.get("has_arms", false)):
		_add_limbs(limbs_slot, palette_slot)

	# 6) Mutation overlays
	_apply_mutations(g.get("mutation", {}), palette_slot)
	# 7) FRANKENSTEIN GRAFT: cross-species body parts inherited via breeding.
	# Adds a visible mushroom cap on top of the lid (for Mimic × Mushroom
	# kids), or goblin/goat skin tints, depending on the secondary parent.
	if g.has("grafted"):
		_apply_cross_species_graft(g["grafted"])

func _clear_built_children() -> void:
	# IMMEDIATE free, not queue_free. queue_free is deferred to end-of-frame,
	# so if rebuild_from_genome fires twice rapidly the OLD scaffolding
	# (including old tongue) stays in the scene tree alongside the NEW
	# one — user saw "3 tongues" because three rebuilds had stacked face
	# roots in the same frame. Immediate free + manual remove_child clears
	# them synchronously.
	for child in [_body_root, _lid_pivot, _face_root, _decorations_root, _limbs_root]:
		if child and is_instance_valid(child):
			if child.get_parent() == self:
				remove_child(child)
			child.free()
	_body_root = null
	_lid_pivot = null
	_face_root = null
	_tongue_root = null
	_decorations_root = null
	_limbs_root = null

# === Body shape dispatch ===================================================

func _build_body_for_shape(shape: String, body_slot: Dictionary, palette: Dictionary) -> void:
	match shape:
		"treasure_chest": _build_chest_body(body_slot, palette)
		"vase":           _build_vase_body(body_slot, palette)
		"casket":         _build_casket_body(body_slot, palette)
		"barrel":         _build_barrel_body(body_slot, palette)
		"crate":          _build_crate_body(body_slot, palette)
		_:                _build_wooden_box_body(body_slot, palette)

func _build_wooden_box_body(_body_slot: Dictionary, palette: Dictionary) -> void:
	# Plain rectangular box from y=0 to y=_H*0.70 (lid takes the upper portion).
	var body_h: float = _H * 0.70
	_add_box(_body_root, Vector3(0, body_h * 0.5, 0), Vector3(_W, body_h, _D), palette["body_color"], 0.78, 0.02)

func _build_chest_body(_body_slot: Dictionary, palette: Dictionary) -> void:
	# Standard chest body — same as wooden box but the lid is bigger / rounded.
	var body_h: float = _H * 0.65
	_add_box(_body_root, Vector3(0, body_h * 0.5, 0), Vector3(_W, body_h, _D), palette["body_color"], 0.78, 0.02)

func _build_vase_body(body_slot: Dictionary, palette: Dictionary) -> void:
	# Vase: stacked cylinders. Wide base + narrow neck + flared opening.
	var neck_ratio: float = clampf(float(body_slot.get("neck_ratio", 0.55)), 0.40, 0.80)
	var neck_radius_ratio: float = clampf(float(body_slot.get("neck_radius_ratio", 0.45)), 0.30, 0.70)
	var base_radius: float = _W * 0.5
	var neck_radius: float = base_radius * neck_radius_ratio
	# Bulbous base section.
	var base_height: float = _H * neck_ratio
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = base_radius * 0.65
	base_cyl.bottom_radius = base_radius * 0.85
	base_cyl.height = base_height
	base_cyl.radial_segments = 20
	_add_mesh(_body_root, base_cyl, Vector3(0, base_height * 0.5, 0), palette["body_color"], 0.80, 0.03)
	# Narrower neck above.
	var neck_height: float = _H * (1.0 - neck_ratio) * 0.75
	var neck_cyl := CylinderMesh.new()
	neck_cyl.top_radius = neck_radius * 1.15  # flare at opening
	neck_cyl.bottom_radius = base_radius * 0.65
	neck_cyl.height = neck_height
	neck_cyl.radial_segments = 20
	_add_mesh(_body_root, neck_cyl, Vector3(0, base_height + neck_height * 0.5, 0), palette["body_color"], 0.80, 0.03)
	# Lip ring at the top (slightly accented).
	var lip_h: float = _H * 0.04
	var lip_cyl := CylinderMesh.new()
	lip_cyl.top_radius = neck_radius * 1.30
	lip_cyl.bottom_radius = neck_radius * 1.15
	lip_cyl.height = lip_h
	lip_cyl.radial_segments = 20
	_add_mesh(_body_root, lip_cyl, Vector3(0, base_height + neck_height + lip_h * 0.5, 0), palette["accent_color"], 0.55, 0.30)

func _build_casket_body(body_slot: Dictionary, palette: Dictionary) -> void:
	# Long low casket: stretch the X axis.
	var stretch: float = clampf(float(body_slot.get("length_stretch", 1.0)), 1.0, 1.30)
	var body_h: float = _H * 0.78
	var body_w: float = _W * stretch
	_add_box(_body_root, Vector3(0, body_h * 0.5, 0), Vector3(body_w, body_h, _D), palette["body_color"], 0.65, 0.05)
	# Decorative trim along the bottom edge (looks like a casket's foot rail).
	var trim_h: float = _H * 0.05
	_add_box(_body_root, Vector3(0, trim_h * 0.5, _D * 0.5 + 0.005), Vector3(body_w * 1.02, trim_h, 0.02), palette["accent_color"], 0.55, 0.30)
	_add_box(_body_root, Vector3(0, trim_h * 0.5, -_D * 0.5 - 0.005), Vector3(body_w * 1.02, trim_h, 0.02), palette["accent_color"], 0.55, 0.30)

func _build_barrel_body(body_slot: Dictionary, palette: Dictionary) -> void:
	# Barrel: stout cylinder with bulging middle, banded with metal hoops.
	# Use a single CylinderMesh as the main barrel form (bands added later).
	var radius: float = _W * 0.5
	var mid_radius: float = radius * 1.08  # subtle bulge feel
	var top_h: float = _H * 0.85
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = radius * 0.92  # taper slightly inward at the top
	top_cyl.bottom_radius = radius * 0.92
	top_cyl.height = top_h
	top_cyl.radial_segments = 22
	_add_mesh(_body_root, top_cyl, Vector3(0, top_h * 0.5, 0), palette["body_color"], 0.82, 0.04)
	# Inner "rim" cap at top — slightly darker, suggests a recessed lid surface.
	var rim_cyl := CylinderMesh.new()
	rim_cyl.top_radius = radius * 0.88
	rim_cyl.bottom_radius = radius * 0.88
	rim_cyl.height = _H * 0.04
	rim_cyl.radial_segments = 22
	_add_mesh(_body_root, rim_cyl, Vector3(0, top_h - _H * 0.02, 0), palette["body_color"].darkened(0.25), 0.85, 0.02)
	# Plank count drives subtle vertical stave lines via thin dark stripes.
	var plank_count: int = int(body_slot.get("plank_count", 10))
	for i in range(plank_count):
		var theta: float = (float(i) / float(plank_count)) * TAU
		var stave_w: float = 0.012
		var stave := BoxMesh.new()
		stave.size = Vector3(stave_w, top_h * 0.95, 0.008)
		var stave_mesh := MeshInstance3D.new()
		stave_mesh.mesh = stave
		stave_mesh.position = Vector3(cos(theta) * (mid_radius * 0.93), top_h * 0.5, sin(theta) * (mid_radius * 0.93))
		stave_mesh.rotation = Vector3(0, -theta + PI * 0.5, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette["body_color"].darkened(0.35)
		mat.roughness = 0.9
		stave_mesh.material_override = mat
		_body_root.add_child(stave_mesh)

func _build_crate_body(body_slot: Dictionary, palette: Dictionary) -> void:
	# Crate: box body with visible plank divisions (4-5 horizontal planks per face).
	var body_h: float = _H * 0.80
	_add_box(_body_root, Vector3(0, body_h * 0.5, 0), Vector3(_W, body_h, _D), palette["body_color"], 0.92, 0.0)
	var plank_count: int = int(body_slot.get("plank_count", 4))
	var plank_h: float = body_h / float(plank_count)
	var gap: float = 0.008
	for i in range(plank_count - 1):
		var y: float = (i + 1) * plank_h
		# Slight dark line at each plank seam — purely decorative thin box on the surface.
		_add_box(_body_root, Vector3(0, y, _D * 0.5 + 0.003), Vector3(_W * 1.005, gap, 0.005), palette["body_color"].darkened(0.45), 1.0, 0.0)
		_add_box(_body_root, Vector3(0, y, -_D * 0.5 - 0.003), Vector3(_W * 1.005, gap, 0.005), palette["body_color"].darkened(0.45), 1.0, 0.0)
		_add_box(_body_root, Vector3(_W * 0.5 + 0.003, y, 0), Vector3(0.005, gap, _D * 1.005), palette["body_color"].darkened(0.45), 1.0, 0.0)
		_add_box(_body_root, Vector3(-_W * 0.5 - 0.003, y, 0), Vector3(0.005, gap, _D * 1.005), palette["body_color"].darkened(0.45), 1.0, 0.0)

# === Lid ===================================================================

func _build_lid(lid_slot: Dictionary, body_slot: Dictionary, palette: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "LidPivot"
	# Hinge along the back-top edge of the body.
	var body_top_y: float = _body_top_world_y()
	pivot.position = Vector3(0, body_top_y, -_D * 0.5)
	var thickness: float = float(lid_slot.get("thickness", 0.06))
	var variant: String = String(lid_slot.get("variant", "flat"))
	# Lid mesh positioned RELATIVE to the pivot so the hinge sits at the
	# back edge (z = -depth/2 in body coords, which is z=0 in pivot coords).
	match variant:
		"rounded":
			_build_rounded_lid_mesh(pivot, palette)
		"peaked":
			_build_peaked_lid_mesh(pivot, palette, thickness)
		_:  # "flat"
			_build_flat_lid_mesh(pivot, palette, thickness)
	_lid_base_rotation_x = 0.0
	pivot.rotation_degrees.x = -_lid_idle_min_angle
	return pivot

func _build_flat_lid_mesh(pivot: Node3D, palette: Dictionary, thickness: float) -> void:
	var lid_w: float = _W
	var lid_d: float = _D
	# Lid sits forward of the hinge by lid_depth/2 so the back edge meets the
	# pivot.
	_add_box(pivot, Vector3(0, thickness * 0.5, lid_d * 0.5), Vector3(lid_w, thickness, lid_d), palette["body_color"], 0.78, 0.02)
	# Decorative front-edge metal band.
	_add_box(pivot, Vector3(0, thickness * 0.55, lid_d - 0.005), Vector3(lid_w * 1.005, thickness * 0.6, 0.012), palette["accent_color"], 0.55, 0.30)

func _build_peaked_lid_mesh(pivot: Node3D, palette: Dictionary, thickness: float) -> void:
	# Two slanted boxes meeting at a ridge along X axis — coffin / pagoda look.
	var lid_w: float = _W
	var lid_d: float = _D
	var peak_h: float = thickness * 2.5
	# Front slab.
	var front := MeshInstance3D.new()
	var front_box := BoxMesh.new()
	front_box.size = Vector3(lid_w, thickness, lid_d * 0.55)
	front.mesh = front_box
	front.position = Vector3(0, peak_h * 0.5, lid_d * 0.75)
	front.rotation_degrees = Vector3(-25.0, 0, 0)  # tilt down toward front
	_apply_albedo_material(front, palette["body_color"], 0.78, 0.02)
	pivot.add_child(front)
	# Back slab.
	var back := MeshInstance3D.new()
	var back_box := BoxMesh.new()
	back_box.size = Vector3(lid_w, thickness, lid_d * 0.55)
	back.mesh = back_box
	back.position = Vector3(0, peak_h * 0.5, lid_d * 0.25)
	back.rotation_degrees = Vector3(25.0, 0, 0)
	_apply_albedo_material(back, palette["body_color"], 0.78, 0.02)
	pivot.add_child(back)
	# Ridge cap.
	_add_box(pivot, Vector3(0, peak_h, lid_d * 0.5), Vector3(lid_w * 1.01, 0.018, 0.025), palette["accent_color"], 0.50, 0.35)

func _build_rounded_lid_mesh(pivot: Node3D, palette: Dictionary) -> void:
	# TRUE half-cylinder lid: upper semicircle cross-section + flat bottom
	# face + two semicircular end caps. Built via SurfaceTool.
	#
	# DEFENSIVE: the lid material has cull_mode=DISABLED. SurfaceTool winding
	# is fiddly enough that an off-by-one in any of three surfaces (curved,
	# bottom, two caps) makes the player see THROUGH the half-cylinder. With
	# double-sided rendering, both faces of every triangle render, so the
	# lid is guaranteed solid regardless of which way the winding cross-
	# product points. Tiny perf cost (~22 extra triangles drawn per lid) is
	# trivial compared to the "transparent treasure chest" failure mode.
	var radius: float = _D * 0.5
	var length: float = _W
	var half_cyl_mesh: ArrayMesh = _build_half_cylinder_mesh(radius, length, 22)
	var lid_dome := MeshInstance3D.new()
	lid_dome.name = "LidDome"
	lid_dome.mesh = half_cyl_mesh
	lid_dome.position = Vector3(0, 0, _D * 0.5)
	# Build the material manually so we can flip cull_mode.
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = palette["body_color"]
	lid_mat.roughness = 0.78
	lid_mat.metallic = 0.02
	lid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lid_dome.material_override = lid_mat
	pivot.add_child(lid_dome)
	# Front-edge accent rings — one at each end, hugging the half-circle.
	var band_t := TorusMesh.new()
	band_t.inner_radius = radius * 0.95
	band_t.outer_radius = radius * 1.02
	band_t.ring_segments = 18
	band_t.rings = 36
	for side in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		band.mesh = band_t
		band.position = Vector3(side * (_W * 0.5 - 0.012), 0, _D * 0.5)
		band.rotation_degrees = Vector3(0, 0, 90)
		_apply_albedo_material(band, palette["accent_color"], 0.45, 0.45)
		pivot.add_child(band)

## Build a half-cylinder mesh: upper semicircle running along X axis, flat
## bottom face at y=0, and two semicircular end caps. Returns an ArrayMesh
## with correct normals so lighting reads naturally.
##
## Layout (lid-local coordinates):
##   - Axis along X, length spans [-length/2, +length/2]
##   - Cross-section: upper semicircle in YZ plane, radius `radius`
##   - At theta=0:    y=0, z=+radius  (front edge of base)
##     At theta=PI/2: y=radius, z=0   (apex)
##     At theta=PI:   y=0, z=-radius  (back edge of base)
func _build_half_cylinder_mesh(radius: float, length: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_length: float = length * 0.5

	# --- Curved upper surface ---
	# For each pair of adjacent theta angles, lay down two triangles spanning
	# the full length along X. Normals point radially outward.
	for i in range(segments):
		var theta_a: float = float(i) / float(segments) * PI
		var theta_b: float = float(i + 1) / float(segments) * PI
		var y_a: float = sin(theta_a) * radius
		var z_a: float = cos(theta_a) * radius
		var y_b: float = sin(theta_b) * radius
		var z_b: float = cos(theta_b) * radius
		var n_a := Vector3(0, sin(theta_a), cos(theta_a))
		var n_b := Vector3(0, sin(theta_b), cos(theta_b))
		var v1 := Vector3(-half_length, y_a, z_a)
		var v2 := Vector3(+half_length, y_a, z_a)
		var v3 := Vector3(+half_length, y_b, z_b)
		var v4 := Vector3(-half_length, y_b, z_b)
		# Triangle 1
		st.set_normal(n_a); st.add_vertex(v1)
		st.set_normal(n_a); st.add_vertex(v2)
		st.set_normal(n_b); st.add_vertex(v3)
		# Triangle 2
		st.set_normal(n_a); st.add_vertex(v1)
		st.set_normal(n_b); st.add_vertex(v3)
		st.set_normal(n_b); st.add_vertex(v4)

	# --- Flat bottom face (rectangle, normal pointing -Y) ---
	var bn := Vector3(0, -1, 0)
	st.set_normal(bn); st.add_vertex(Vector3(-half_length, 0, +radius))
	st.set_normal(bn); st.add_vertex(Vector3(-half_length, 0, -radius))
	st.set_normal(bn); st.add_vertex(Vector3(+half_length, 0, -radius))
	st.set_normal(bn); st.add_vertex(Vector3(-half_length, 0, +radius))
	st.set_normal(bn); st.add_vertex(Vector3(+half_length, 0, -radius))
	st.set_normal(bn); st.add_vertex(Vector3(+half_length, 0, +radius))

	# --- End caps (semicircular discs) ---
	# Fan triangulation from each cap's center to the perimeter. The
	# winding here is what causes "transparent half-cylinder" reports — if
	# the geometric normal (computed from vertex order via cross product)
	# points OPPOSITE to the assigned normal, Godot back-face culls the cap
	# from the outside view. Empirically verified order:
	#   side=+1 (right cap, normal +X)  → (center, p_b, p_a)
	#   side=-1 (left cap,  normal -X)  → (center, p_a, p_b)
	# Both windings now match Godot's CCW-front convention for their normal.
	for side in [-1.0, 1.0]:
		var x: float = side * half_length
		var cap_n := Vector3(side, 0, 0)
		var center := Vector3(x, 0, 0)
		for i in range(segments):
			var theta_a: float = float(i) / float(segments) * PI
			var theta_b: float = float(i + 1) / float(segments) * PI
			var p_a := Vector3(x, sin(theta_a) * radius, cos(theta_a) * radius)
			var p_b := Vector3(x, sin(theta_b) * radius, cos(theta_b) * radius)
			if side > 0:
				st.set_normal(cap_n); st.add_vertex(center)
				st.set_normal(cap_n); st.add_vertex(p_b)
				st.set_normal(cap_n); st.add_vertex(p_a)
			else:
				st.set_normal(cap_n); st.add_vertex(center)
				st.set_normal(cap_n); st.add_vertex(p_a)
				st.set_normal(cap_n); st.add_vertex(p_b)

	return st.commit()

# === Face: eyes, teeth, tongue =============================================

func _add_teeth(face_slot: Dictionary, palette: Dictionary) -> void:
	# Teeth ring the mouth opening. Mouth Y depends on shape — for chests/
	# boxes it's at the lid-body seam, for vases/barrels it's at the rim.
	var tooth_count: int = int(face_slot.get("tooth_count", 8))
	var tooth_size: float = float(face_slot.get("tooth_size", 0.04))
	var mouth_w: float = _mouth_width()
	var mouth_y_upper: float = _mouth_y_top()
	var mouth_y_lower: float = _mouth_y_bottom()
	var mouth_z: float = _mouth_z()
	# Upper row (attached to lid pivot if lid exists, so teeth swing with the lid).
	var upper_parent: Node3D = _lid_pivot if _lid_pivot else _face_root
	var upper_y: float = mouth_y_upper - (_body_top_world_y() if _lid_pivot else 0.0)
	var upper_z: float = mouth_z - (-_D * 0.5 if _lid_pivot else 0.0)
	_add_tooth_row(upper_parent, tooth_count, mouth_w, upper_y, upper_z, tooth_size, true, palette["tooth_color"])
	# Lower row (always on body). Use the SEEDED _rng (not the global
	# randi_range) so this number is stable across rebuilds.
	var lower_count: int = maxi(3, tooth_count - _rng.randi_range(1, 2))
	_add_tooth_row(_face_root, lower_count, mouth_w, mouth_y_lower, mouth_z, tooth_size, false, palette["tooth_color"])

func _add_tooth_row(parent: Node3D, count: int, mouth_w: float, y: float, z: float, size: float, pointing_down: bool, color: Color) -> void:
	if count <= 0:
		return
	var spacing: float = mouth_w / float(count + 1)
	for i in range(count):
		var x: float = -mouth_w * 0.5 + spacing * float(i + 1)
		x += _rng.randf_range(-spacing * 0.10, spacing * 0.10)
		var h: float = size * _rng.randf_range(0.75, 1.20)
		var tooth := MeshInstance3D.new()
		tooth.name = "Tooth"
		# Tooth as a small inverted cone (cylinder with top=tip).
		var cone := CylinderMesh.new()
		if pointing_down:
			cone.top_radius = size * 0.45
			cone.bottom_radius = size * 0.05
		else:
			cone.top_radius = size * 0.05
			cone.bottom_radius = size * 0.45
		cone.height = h
		cone.radial_segments = 8
		tooth.mesh = cone
		var y_offset: float = -h * 0.5 if pointing_down else h * 0.5
		tooth.position = Vector3(x, y + y_offset, z)
		_apply_albedo_material(tooth, color, 0.6, 0.0)
		parent.add_child(tooth)

func _add_tongue(face_slot: Dictionary, palette: Dictionary) -> void:
	_tongue_root = Node3D.new()
	_tongue_root.name = "TongueRoot"
	_face_root.add_child(_tongue_root)
	# All mimic shapes have the tongue emerge UPWARD through the body's top
	# opening — the lid-hinge gap on chests/boxes/caskets/crates, the
	# permanent opening on vases/barrels. That's the actual "mouth" of a
	# D&D mimic: the lid lifts and the tongue lashes up out of the interior.
	# Earlier code mistakenly extended the tongue forward through the front
	# face, which collided with the front-mounted teeth.
	_tongue_axis = Vector3(0, 1, 0)
	_tongue_root.rotation = Vector3(-PI * 0.5, 0, 0)  # mesh-local +Z -> world +Y
	_tongue_base_pos = _compute_tongue_base_pos()
	_tongue_root.position = _tongue_base_pos
	# Segmented snake-style tongue (chain of tapering sphere segments +
	# forked tip), pointing upward by virtue of the root rotation above.
	var thickness: float = float(face_slot.get("tongue_thickness", 0.04))
	_build_snake_tongue(_tongue_root, _tongue_length, thickness, palette["tongue_color"])

## Build a segmented snake-style tongue inside `parent`, extending along +Z
## in parent-local coordinates. Five overlapping sphere segments taper from
## thick base to slim tip, followed by a SHORT forked split (two tiny cones
## splaying outward at ~12° from center). The fork is intentionally subtle —
## previously a 25° splay read visually as "two extra tongues sticking out
## from a main one." Now the prongs hug close to the centerline.
func _build_snake_tongue(parent: Node3D, length: float, base_thickness: float, color: Color) -> void:
	# Reserve a SMALLER tail section for the forked tip so it reads as a
	# split-tongue rather than a triple appendage.
	var fork_length: float = length * 0.12
	var body_length: float = length - fork_length
	var segment_count: int = 5

	# Shared body material.
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.roughness = 0.85
	body_mat.metallic = 0.0

	# Sphere chain — each segment slightly smaller than the last, positioned
	# so consecutive segments overlap by ~30% of their diameter for a
	# continuous serpentine look.
	for i in range(segment_count):
		var t: float = float(i) / float(maxi(1, segment_count - 1))
		var seg_radius: float = lerpf(base_thickness * 0.85, base_thickness * 0.48, t)
		var seg := MeshInstance3D.new()
		seg.name = "TongueSeg_%d" % i
		var sph := SphereMesh.new()
		sph.radius = seg_radius
		sph.height = seg_radius * 2.0
		seg.mesh = sph
		seg.material_override = body_mat
		# Distribute segments along the body length so the first segment's
		# center sits one radius into the mouth and the last sits near the
		# start of the fork.
		var z: float = lerpf(seg_radius, body_length - seg_radius * 0.5, t)
		seg.position = Vector3(0, 0, z)
		# Subtle flattening for a "muscular" oval cross-section (mimics a
		# real tongue's slight squash).
		seg.scale = Vector3(1.15, 0.78, 1.0)
		parent.add_child(seg)

	# Fork: two thin cones splaying outward in the XZ plane. The fork pivot
	# anchors at the end of the body section; each prong rotates ±25° around
	# Y so the tips spread apart.
	var fork_start_z: float = body_length - base_thickness * 0.20
	var fork_radius_base: float = base_thickness * 0.45
	var fork_mat := StandardMaterial3D.new()
	fork_mat.albedo_color = color.darkened(0.08)
	fork_mat.roughness = 0.80
	# Splay reduced from 25° to 12° so the prongs hug the main tongue body
	# instead of reading as two extra tongues sticking out.
	var fork_angle_deg: float = 12.0
	for side in [-1.0, 1.0]:
		var prong := Node3D.new()
		prong.name = "Fork_%s" % ("L" if side < 0 else "R")
		prong.position = Vector3(0, 0, fork_start_z)
		prong.rotation_degrees = Vector3(0, side * fork_angle_deg, 0)
		var prong_mesh := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = base_thickness * 0.04   # near-point at tip
		cone.bottom_radius = fork_radius_base
		cone.height = fork_length
		cone.radial_segments = 8
		prong_mesh.mesh = cone
		prong_mesh.material_override = fork_mat
		# CylinderMesh's axis defaults to +Y; rotate so it points along +Z
		# in prong-local space. After the prong's own Y rotation, the tip
		# ends up splayed outward in XZ.
		prong_mesh.rotation = Vector3(PI * 0.5, 0, 0)
		prong_mesh.position = Vector3(0, 0, fork_length * 0.5)
		prong.add_child(prong_mesh)
		parent.add_child(prong)

## Compute where the tongue's BASE should sit. The tongue emerges UP through
## the body's top opening — dead-center on the X/Z plane of the chest, with
## the base anchored inside the body and the tip protruding past the body's
## top face into the hinged gap.
##
## Geometry (all shapes):
##   - At protrude=0: tongue base sits half a tongue-length BELOW the body's
##     top face. The forward (upper) half of the segmented tongue + forked
##     tip emerges above the top opening, visible in the gap when the lid
##     bobs open during idle. The base half stays inside, hidden by the body.
##   - At protrude=1: base sits AT the top face. The entire tongue length
##     lashes upward like a striking snake.
##
## X=0 and Z=0 center the tongue on the chest's vertical axis — "the dead
## center of the top of the lower piece inside the hinged area" per spec.
func _compute_tongue_base_pos() -> Vector3:
	var opening_y: float = _mouth_y_top()
	var deep_y: float = opening_y - _tongue_length * 0.5
	var lip_y: float = opening_y
	var y: float = lerpf(deep_y, lip_y, _tongue_protrude)
	return Vector3(0, y, 0)

func _add_eyes_on_body(face_slot: Dictionary, palette: Dictionary) -> void:
	var eye_count: int = int(face_slot.get("eye_count", 2))
	var eye_radius: float = float(face_slot.get("eye_radius", 0.04))
	var eye_spread: float = float(face_slot.get("eye_spread", 0.22))
	var glow: bool = bool(face_slot.get("eye_glow", true))
	# Eyes sit on the upper-front face of the body, above the mouth.
	var eye_y: float = _eye_band_y()
	var eye_z: float = _D * 0.5 + 0.002
	_distribute_eyes(_face_root, eye_count, eye_radius, eye_spread, palette["eye_color"], glow, eye_y, eye_z)

func _add_eyes_on_lid(face_slot: Dictionary, palette: Dictionary) -> void:
	var eye_count: int = int(face_slot.get("eye_count", 2))
	var eye_radius: float = float(face_slot.get("eye_radius", 0.04))
	var eye_spread: float = float(face_slot.get("eye_spread", 0.22))
	var glow: bool = bool(face_slot.get("eye_glow", true))
	if _lid_pivot == null:
		_add_eyes_on_body(face_slot, palette)
		return
	# Lid-local coordinates: pivot is at body's back-top edge. Lid extends
	# forward (+Z) by _D. Positioning per lid variant:
	#   - rounded: eyes ride the curved dome facing forward
	#   - peaked:  eyes on the front-facing slab between ridge and front edge
	#   - flat:    eyes perched on the TOP surface, peering forward over the
	#              front edge (so they're visible from in front even when the
	#              lid is mostly closed during idle)
	var eye_y: float = 0.0
	var eye_z: float = 0.0
	match _lid_variant:
		"rounded":
			eye_y = _D * 0.25
			eye_z = _D * 0.92
		"peaked":
			eye_y = _D * 0.18
			eye_z = _D * 0.65
		_:  # "flat"
			# Top of the flat-lid pancake is at y ≈ thickness (0.06ish). Lift
			# the eye spheres so they bulge above the lid surface and read as
			# "watching from on top of the lid." Front edge of lid is at z=_D.
			var lid_top_y: float = 0.06 + eye_radius * 0.4
			eye_y = lid_top_y
			eye_z = _D * 0.78
	_distribute_eyes(_lid_pivot, eye_count, eye_radius, eye_spread, palette["eye_color"], glow, eye_y, eye_z)

func _distribute_eyes(parent: Node3D, eye_count: int, eye_radius: float, eye_spread: float, eye_color: Color, glow: bool, y: float, z: float) -> void:
	for i in range(eye_count):
		var t: float = 0.0
		if eye_count > 1:
			t = (float(i) - (float(eye_count - 1) * 0.5)) / float(eye_count)
		var x: float = t * eye_spread
		# Eye whites (slightly larger sphere behind iris)
		var eye := MeshInstance3D.new()
		eye.name = "Eye_%d" % i
		var sph := SphereMesh.new()
		sph.radius = eye_radius
		sph.height = eye_radius * 2.0
		eye.mesh = sph
		eye.position = Vector3(x, y, z)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = eye_color
		if glow:
			mat.emission_enabled = true
			mat.emission = eye_color
			mat.emission_energy_multiplier = 1.4
		mat.roughness = 0.30
		eye.material_override = mat
		parent.add_child(eye)
		# Pupil (small black dot)
		var pupil := MeshInstance3D.new()
		pupil.name = "Pupil_%d" % i
		var psph := SphereMesh.new()
		psph.radius = eye_radius * 0.42
		psph.height = eye_radius * 0.84
		pupil.mesh = psph
		pupil.position = Vector3(x, y, z + eye_radius * 0.6)
		_apply_albedo_material(pupil, Color.BLACK, 0.4, 0.0)
		parent.add_child(pupil)

# === Decorations ===========================================================

func _add_decorations(deco_slot: Dictionary, palette: Dictionary) -> void:
	var band_count: int = int(deco_slot.get("band_count", 0))
	var clasp_count: int = int(deco_slot.get("clasp_count", 0))
	var gem_count: int = int(deco_slot.get("gem_count", 0))
	var lock_present: bool = bool(deco_slot.get("lock_present", false))
	var handle_present: bool = bool(deco_slot.get("handle_present", false))
	if band_count > 0:
		_add_bands(band_count, palette["accent_color"])
	if clasp_count > 0:
		_add_clasps(clasp_count, palette["accent_color"])
	if gem_count > 0:
		_add_gems(gem_count, palette["eye_color"])  # gems echo eye color
	if lock_present:
		_add_lock(palette["accent_color"])
	if handle_present:
		_add_handles(palette["accent_color"])

func _add_bands(count: int, color: Color) -> void:
	# Horizontal metal bands wrapping the body. Shape-aware: cylinders for
	# barrel/vase, rectangular wraps for boxes.
	for i in range(count):
		var t: float = (float(i) + 1.0) / float(count + 1)
		var y: float = _H * t * 0.78  # within the body's height
		match _shape:
			"vase":
				# Decorative ring on the vase (slightly raised).
				var ring := TorusMesh.new()
				ring.inner_radius = _W * 0.50
				ring.outer_radius = _W * 0.55
				ring.ring_segments = 14
				ring.rings = 28
				var m := MeshInstance3D.new()
				m.mesh = ring
				m.position = Vector3(0, y, 0)
				m.rotation_degrees = Vector3(90, 0, 0)
				_apply_albedo_material(m, color, 0.50, 0.30)
				_decorations_root.add_child(m)
			"barrel":
				# Iron hoop — slightly outset cylinder slice.
				var hoop := TorusMesh.new()
				hoop.inner_radius = _W * 0.49
				hoop.outer_radius = _W * 0.53
				hoop.ring_segments = 14
				hoop.rings = 26
				var hm := MeshInstance3D.new()
				hm.mesh = hoop
				hm.position = Vector3(0, y, 0)
				hm.rotation_degrees = Vector3(90, 0, 0)
				_apply_albedo_material(hm, color, 0.45, 0.55)
				_decorations_root.add_child(hm)
			_:
				# Rectangular wrap: thin boxes on the front, back, and sides.
				var band_h: float = 0.025
				_add_box(_decorations_root, Vector3(0, y, _D * 0.5 + 0.003), Vector3(_W * 1.01, band_h, 0.012), color, 0.50, 0.35)
				_add_box(_decorations_root, Vector3(0, y, -_D * 0.5 - 0.003), Vector3(_W * 1.01, band_h, 0.012), color, 0.50, 0.35)
				_add_box(_decorations_root, Vector3(_W * 0.5 + 0.003, y, 0), Vector3(0.012, band_h, _D * 1.01), color, 0.50, 0.35)
				_add_box(_decorations_root, Vector3(-_W * 0.5 - 0.003, y, 0), Vector3(0.012, band_h, _D * 1.01), color, 0.50, 0.35)

func _add_clasps(count: int, color: Color) -> void:
	# Clasps cluster along the front lid-body seam (chest / box / casket).
	# For vase/barrel which lack a seam, skip.
	if _shape in ["vase", "barrel"]:
		return
	var seam_y: float = _body_top_world_y() - 0.02
	for i in range(count):
		var t: float = 0.0
		if count > 1:
			t = (float(i) - (float(count - 1) * 0.5)) / float(count)
		var x: float = t * _W * 0.5
		# Clasp = small protruding bar with a hinge nub.
		_add_box(_decorations_root, Vector3(x, seam_y, _D * 0.5 + 0.012), Vector3(0.05, 0.04, 0.025), color, 0.40, 0.55)
		# Hinge nub on top.
		_add_box(_decorations_root, Vector3(x, seam_y + 0.025, _D * 0.5 + 0.015), Vector3(0.03, 0.02, 0.018), color.darkened(0.15), 0.40, 0.55)

func _add_gems(count: int, color: Color) -> void:
	# Gem rosettes on the front face. Small emissive spheres.
	for i in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(_W * 0.10, _W * 0.30)
		var x: float = cos(angle) * radius * 0.5
		var y: float = _H * _rng.randf_range(0.25, 0.55)
		var gem := MeshInstance3D.new()
		gem.name = "Gem_%d" % i
		var sph := SphereMesh.new()
		sph.radius = 0.020
		sph.height = 0.040
		gem.mesh = sph
		gem.position = Vector3(x, y, _D * 0.5 + 0.010)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.6
		mat.metallic = 0.6
		mat.roughness = 0.10
		gem.material_override = mat
		_decorations_root.add_child(gem)

func _add_lock(color: Color) -> void:
	if _shape in ["vase", "barrel"]:
		return
	# Lock plate centered on the front, just below the lid seam.
	var lock_y: float = _body_top_world_y() - 0.07
	# Plate.
	_add_box(_decorations_root, Vector3(0, lock_y, _D * 0.5 + 0.012), Vector3(0.10, 0.08, 0.018), color, 0.40, 0.55)
	# Keyhole (small black box).
	_add_box(_decorations_root, Vector3(0, lock_y, _D * 0.5 + 0.024), Vector3(0.02, 0.035, 0.005), Color(0.02, 0.02, 0.02), 1.0, 0.0)

func _add_handles(color: Color) -> void:
	# Side handles — small U-shapes on the left and right faces.
	var y: float = _H * 0.40
	for side in [-1.0, 1.0]:
		var handle := TorusMesh.new()
		handle.inner_radius = 0.025
		handle.outer_radius = 0.038
		handle.ring_segments = 8
		handle.rings = 14
		var hm := MeshInstance3D.new()
		hm.mesh = handle
		hm.position = Vector3(side * (_W * 0.5 + 0.018), y, 0)
		hm.rotation_degrees = Vector3(0, 0, 90)
		_apply_albedo_material(hm, color, 0.45, 0.55)
		_decorations_root.add_child(hm)

# === Limbs (hybrid-only) ===================================================

func _add_limbs(limbs_slot: Dictionary, palette: Dictionary) -> void:
	# Only invoked when has_arms or has_legs is true (hybrid offspring).
	# Color blends body + accent to suggest the limbs are "mimic flesh" coming
	# out of the disguise.
	var limb_color: Color = palette["body_color"].lerp(palette["tongue_color"], 0.4)
	var limb_mat := StandardMaterial3D.new()
	limb_mat.albedo_color = limb_color
	limb_mat.roughness = 0.7
	if bool(limbs_slot.get("has_arms", false)):
		var arm_length: float = float(limbs_slot.get("arm_length", 0.22))
		var arm_radius: float = float(limbs_slot.get("arm_radius", 0.04))
		var arm_y: float = float(limbs_slot.get("arm_y_offset", 0.30))
		var arm_droop: float = clampf(float(limbs_slot.get("arm_droop", 0.4)), -1.0, 1.0)
		for side in [-1.0, 1.0]:
			var arm_pivot := Node3D.new()
			arm_pivot.name = "Arm_%s" % ("L" if side < 0 else "R")
			arm_pivot.position = Vector3(side * (_W * 0.5 + arm_radius * 0.5), arm_y, 0)
			var base_rot: float = -PI * 0.5 if side > 0 else PI * 0.5
			var droop_rot: float = arm_droop * (PI * 0.5)
			arm_pivot.rotation = Vector3(0, 0, base_rot - side * droop_rot)
			var arm := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = arm_radius * 0.75
			cyl.bottom_radius = arm_radius
			cyl.height = arm_length
			arm.mesh = cyl
			arm.material_override = limb_mat
			arm.transform.origin = Vector3(0, arm_length * 0.5, 0)
			arm_pivot.add_child(arm)
			var hand := MeshInstance3D.new()
			var hand_mesh := SphereMesh.new()
			hand_mesh.radius = arm_radius * 1.3
			hand_mesh.height = arm_radius * 2.6
			hand.mesh = hand_mesh
			hand.material_override = limb_mat
			hand.transform.origin = Vector3(0, arm_length, 0)
			arm_pivot.add_child(hand)
			_limbs_root.add_child(arm_pivot)
	if bool(limbs_slot.get("has_legs", false)):
		var leg_length: float = float(limbs_slot.get("leg_length", 0.18))
		var leg_radius: float = float(limbs_slot.get("leg_radius", 0.05))
		var leg_spread: float = float(limbs_slot.get("leg_spread", 0.12))
		var foot_size: float = float(limbs_slot.get("foot_size", 0.07))
		# Note: when legs are present, the body itself should sit ATOP the legs
		# so feet rest at floor level. The actor's collision capsule is fixed,
		# so we don't lift the whole body here — instead the legs droop BELOW
		# the body's y=0 plane (which is the actor's foot level). Feet end up
		# slightly below the floor, but the body silhouette remains coherent.
		# A proper fix would re-anchor the actor; deferred to a follow-up.
		for side in [-1.0, 1.0]:
			var leg_pivot := Node3D.new()
			leg_pivot.name = "Leg_%s" % ("L" if side < 0 else "R")
			leg_pivot.position = Vector3(side * leg_spread, 0, 0)
			var leg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = leg_radius
			cyl.bottom_radius = leg_radius * 0.85
			cyl.height = leg_length
			leg.mesh = cyl
			leg.material_override = limb_mat
			leg.rotation = Vector3(PI, 0, 0)
			leg.transform.origin = Vector3(0, -leg_length * 0.5, 0)
			leg_pivot.add_child(leg)
			var foot := MeshInstance3D.new()
			var foot_mesh := SphereMesh.new()
			foot_mesh.radius = foot_size
			foot_mesh.height = foot_size * 1.2
			foot.mesh = foot_mesh
			foot.material_override = limb_mat
			foot.transform.origin = Vector3(0, -leg_length, foot_size * 0.4)
			foot.scale = Vector3(1.0, 0.5, 1.4)
			leg_pivot.add_child(foot)
			_limbs_root.add_child(leg_pivot)

# === Mutations =============================================================

func _apply_mutations(mutation_slot: Dictionary, palette: Dictionary) -> void:
	if bool(mutation_slot.get("cursed_glow", false)):
		var light := OmniLight3D.new()
		light.name = "CursedGlow"
		var glow_color: Color = Color(mutation_slot.get("glow_color", Color(0.85, 0.20, 0.55)))
		light.light_color = glow_color
		light.light_energy = 1.8
		light.omni_range = 3.5
		light.position = Vector3(0, _H * 0.5, 0)
		add_child(light)
	if bool(mutation_slot.get("blood_stained", false)):
		# Splash a few dark red boxes around the body.
		var stain_color: Color = Color(0.45, 0.05, 0.05)
		for i in range(4):
			var x: float = _rng.randf_range(-_W * 0.4, _W * 0.4)
			var y: float = _rng.randf_range(_H * 0.1, _H * 0.55)
			_add_box(_decorations_root, Vector3(x, y, _D * 0.5 + 0.004), Vector3(_rng.randf_range(0.03, 0.08), _rng.randf_range(0.03, 0.07), 0.005), stain_color, 0.9, 0.0)

# === Coordinate helpers ====================================================

func _body_top_world_y() -> float:
	# Y where the body ends and the lid begins.
	match _shape:
		"vase":
			return _H * 0.95  # vase opening is near the top
		"barrel":
			return _H * 0.88
		"casket":
			return _H * 0.78
		"crate", "wooden_box":
			return _H * 0.70
		"treasure_chest":
			return _H * 0.65
		_:
			return _H * 0.70

func _mouth_z() -> float:
	# Z of the front face where the mouth opens.
	match _shape:
		"vase", "barrel":
			# Mouth at the top opening — point straight up. Use Z=0 since
			# the opening is centered.
			return 0.0
		_:
			return _D * 0.5

func _mouth_y_top() -> float:
	match _shape:
		"vase", "barrel":
			return _H * 0.95
		_:
			return _body_top_world_y() - 0.005

func _mouth_y_bottom() -> float:
	match _shape:
		"vase", "barrel":
			return _H * 0.92
		_:
			return _body_top_world_y() - _H * 0.20

func _mouth_y_center() -> float:
	return (_mouth_y_top() + _mouth_y_bottom()) * 0.5

func _mouth_width() -> float:
	match _shape:
		"vase":
			return _W * 0.55   # narrow opening
		"barrel":
			return _W * 0.70
		"casket":
			return _W * 0.55
		_:
			return _W * 0.72

func _eye_band_y() -> float:
	match _shape:
		"vase":
			return _H * 0.55  # on the bulbous body
		"barrel":
			return _H * 0.50
		"casket":
			return _H * 0.62
		_:
			return _H * 0.55

# === Mesh helpers ==========================================================

func _add_box(parent: Node3D, center: Vector3, size: Vector3, color: Color, roughness: float = 0.78, metallic: float = 0.02) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Part"
	mesh.position = center
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	_apply_albedo_material(mesh, color, roughness, metallic)
	parent.add_child(mesh)
	return mesh

func _add_mesh(parent: Node3D, mesh: Mesh, position: Vector3, color: Color, roughness: float = 0.78, metallic: float = 0.02) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = position
	_apply_albedo_material(mi, color, roughness, metallic)
	parent.add_child(mi)
	return mi

func _apply_albedo_material(mesh: MeshInstance3D, color: Color, roughness: float, metallic: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mesh.material_override = mat

# === Cross-species graft rendering ========================================
#
# Renders body parts inherited from the OTHER parent during hybrid breeding,
# so a Mimic × Mushroom kid actually LOOKS like a Frankenstein hybrid (chest
# with a mushroom cap on its lid) instead of a plain Mimic with re-tinted
# colors. Data comes from genome["grafted"] which the universal breeder
# populates with the secondary parent's distinctive features.

func _apply_cross_species_graft(grafted: Dictionary) -> void:
	var source: String = String(grafted.get("source_species", ""))
	print("[Graft][Mimic] source='%s' cap=%s spots=%s eyes=%s antenna=%s extra_eye_n=%s" % [
		source,
		grafted.get("has_cap_graft", false),
		grafted.get("has_spots_on_body", false),
		grafted.get("has_extra_eyes_on_cap", false),
		grafted.get("has_stem_antenna", false),
		grafted.get("extra_eye_count", 0)
	])
	if source.is_empty():
		return
	match source:
		"mushroom":
			# Roll each compound feature independently — sibling hybrids
			# get visibly different combinations every spawn.
			if bool(grafted.get("has_cap_graft", false)):
				_graft_mushroom_features(grafted)
			if bool(grafted.get("has_spots_on_body", false)):
				_graft_mushroom_spots_on_body(grafted)
			if bool(grafted.get("has_extra_eyes_on_cap", false)):
				_graft_extra_eyes_on_cap(grafted)
			if bool(grafted.get("has_stem_antenna", false)):
				_graft_stem_antenna(grafted)
		"goblin":
			_graft_goblin_tint(grafted)
		"goat":
			_graft_goat_features(grafted)

## Mushroom-source: spawn a LARGE mushroom cap mesh on top of the Mimic
## lid, with spots and a connector stem so the player can't miss it. Always
## rendered for any Mimic kid whose source_species is "mushroom".
func _graft_mushroom_features(grafted: Dictionary) -> void:
	# Force a minimum cap radius even if the source had a tiny cap. Hybrids
	# should be unambiguously visible — the cap is meant to read as "this
	# chest is wearing a mushroom hat" not as a subtle hint.
	var raw_radius: float = float(grafted.get("mushroom_cap_radius", 0.0))
	var cap_radius: float = maxf(raw_radius, 0.18)
	# Scale cap radius up by 1.4x so it's clearly larger than a "decoration"
	# and definitively reads as a body part graft.
	cap_radius *= 1.4
	var cap_height: float = maxf(float(grafted.get("mushroom_cap_height", 0.18)), 0.14) * 1.4
	var cap_color: Color = Color(grafted.get("mushroom_cap_color", Color(0.86, 0.25, 0.25)))
	var spot_count: int = maxi(int(grafted.get("mushroom_spot_count", 5)), 4)
	var spot_radius: float = maxf(float(grafted.get("mushroom_spot_radius", 0.04)), 0.035)
	var spot_color: Color = Color(grafted.get("mushroom_spot_color", Color(0.95, 0.95, 0.88)))
	var profile: String = String(grafted.get("mushroom_cap_profile", "dome"))
	# Parent to ourselves (body) so the cap stays fixed when the lid bobs.
	# Lift the cap HIGH enough that the sphere's bottom hemisphere is above
	# the lid — previously the bottom of the cap dome was dipping below
	# body_top and covering the lower-row teeth on the chest front.
	var graft_parent: Node3D = self
	var graft_root := Node3D.new()
	graft_root.name = "GraftedMushroomCap"
	# Tall connector lifts the cap clearly above the lid. graft_root sits at
	# body_top + 0.08 (just above lid), and the cap mesh inside graft_root
	# is offset by dome_h*0.5 so the sphere's bottom hemisphere starts AT
	# graft_root.y (= body_top + 0.08 + connector_h) and the dome rises
	# from there. No part of the cap dips below body_top.
	var connector_h: float = 0.20
	var top_y: float = _body_top_world_y() + 0.08
	graft_root.position = Vector3(0, top_y + connector_h, 0)
	graft_parent.add_child(graft_root)
	# Connector stem mesh (tan/wood-tinted to read as fungal stem).
	var connector := MeshInstance3D.new()
	connector.name = "GraftConnector"
	var conn_cyl := CylinderMesh.new()
	conn_cyl.top_radius = cap_radius * 0.18
	conn_cyl.bottom_radius = cap_radius * 0.22
	conn_cyl.height = connector_h
	conn_cyl.radial_segments = 14
	connector.mesh = conn_cyl
	var conn_mat := StandardMaterial3D.new()
	conn_mat.albedo_color = Color(0.93, 0.88, 0.74)
	conn_mat.roughness = 0.82
	connector.material_override = conn_mat
	connector.position = Vector3(0, -connector_h * 0.5, 0)
	graft_root.add_child(connector)
	# Cap mesh — use a full sphere centered just above the attachment point
	# so the dome rises and the bottom flange hides into the lid surface.
	var cap_mesh := MeshInstance3D.new()
	cap_mesh.name = "GraftedCapMesh"
	var dome_h: float = maxf(cap_height * 1.8, cap_radius * 1.4)
	match profile:
		"flat":
			var cyl := CylinderMesh.new()
			cyl.top_radius = cap_radius * 0.95
			cyl.bottom_radius = cap_radius
			cyl.height = maxf(cap_height * 0.55, 0.06)
			cyl.radial_segments = 18
			cap_mesh.mesh = cyl
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = cap_radius * 0.05
			cone.bottom_radius = cap_radius
			cone.height = cap_height * 1.5
			cone.radial_segments = 18
			cap_mesh.mesh = cone
		_:  # "dome" / "bell"
			var sph := SphereMesh.new()
			sph.radius = cap_radius
			sph.height = dome_h
			cap_mesh.mesh = sph
	_apply_albedo_material(cap_mesh, cap_color, 0.85, 0.0)
	# Offset the sphere CENTER to dome_h*0.5 above graft_root so the sphere's
	# bottom hemisphere sits AT graft_root.y (= top of connector) and the
	# upper hemisphere rises above. No part of the cap dips below the
	# connector — fixes the lower-teeth occlusion the user reported.
	cap_mesh.position = Vector3(0, dome_h * 0.5, 0)
	graft_root.add_child(cap_mesh)
	# Spots scattered across the upper hemisphere of the grafted cap.
	if spot_count > 0 and profile != "cone":
		var spot_mat := StandardMaterial3D.new()
		spot_mat.albedo_color = spot_color
		spot_mat.roughness = 0.85
		for i in range(spot_count):
			var spot := MeshInstance3D.new()
			spot.name = "GraftedSpot_%d" % i
			var sph_s := SphereMesh.new()
			sph_s.radius = spot_radius
			sph_s.height = spot_radius * 2.0
			spot.mesh = sph_s
			spot.material_override = spot_mat
			var theta: float = (float(i) / float(spot_count)) * TAU + sin(float(i) * 1.7) * 0.3
			var phi: float = lerpf(0.15, PI * 0.42, fmod(float(i) * 0.37 + 0.13, 1.0))
			var x: float = cos(theta) * cap_radius * sin(phi) * 0.94
			var z: float = sin(theta) * cap_radius * sin(phi) * 0.94
			# Sphere center is now at dome_h*0.5 (lifted so bottom sits at
			# graft_root). Spots track the upper hemisphere of that sphere.
			var y: float = dome_h * 0.5 + (dome_h * 0.5) * cos(phi) * 0.96
			spot.transform.origin = Vector3(x, y, z)
			graft_root.add_child(spot)

## Compound feature: mushroom-style spots painted onto the chest's front
## face. Independent roll from the cap graft — a hybrid might have spots
## but no cap, or both, or neither, depending on the rolls.
func _graft_mushroom_spots_on_body(grafted: Dictionary) -> void:
	if _body_root == null:
		return
	# Use the SEEDED _rng so spot count + positions are stable across rebuilds.
	var spot_count: int = maxi(int(grafted.get("mushroom_spot_count", 5)), 4) + _rng.randi_range(0, 4)
	var spot_radius: float = maxf(float(grafted.get("mushroom_spot_radius", 0.04)), 0.035)
	var spot_color: Color = Color(grafted.get("mushroom_spot_color", Color(0.95, 0.95, 0.88)))
	var spot_mat := StandardMaterial3D.new()
	spot_mat.albedo_color = spot_color
	spot_mat.roughness = 0.85
	for i in range(spot_count):
		var spot := MeshInstance3D.new()
		spot.name = "GraftedBodySpot_%d" % i
		var sph := SphereMesh.new()
		sph.radius = spot_radius
		sph.height = spot_radius * 2.0
		spot.mesh = sph
		spot.material_override = spot_mat
		# Scatter spots across the front face of the body — seeded for stability.
		var x: float = _rng.randf_range(-_W * 0.40, _W * 0.40)
		var y: float = _rng.randf_range(_H * 0.10, _H * 0.55)
		spot.position = Vector3(x, y, _D * 0.5 + spot_radius * 0.3)
		_body_root.add_child(spot)

## Compound feature: extra glowing mushroom-style eyes placed ON the grafted
## mushroom cap (if there is one). Eyes use the secondary parent's eye color
## with bright emission so they read as "mimic-style glowing eyes embedded
## in the mushroom hat" — a signature cross-species combination.
func _graft_extra_eyes_on_cap(grafted: Dictionary) -> void:
	# Need either a cap graft to put eyes on, OR we just dot them on the lid.
	var eye_count: int = clampi(int(grafted.get("extra_eye_count", 4)), 1, 12)
	var eye_radius: float = maxf(float(grafted.get("extra_eye_radius", 0.04)), 0.035)
	var eye_color: Color = Color(grafted.get("mushroom_eye_color", Color(0.95, 0.7, 0.2)))
	var glow: bool = bool(grafted.get("extra_eye_glow", true))
	# Parent the extra eyes to the lid pivot if it exists, otherwise to the
	# body — they sit ABOVE the normal lid eyes near the top of the head.
	var eye_parent: Node3D = _lid_pivot if _lid_pivot else _body_root
	if eye_parent == null:
		return
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	if glow:
		eye_mat.emission_enabled = true
		eye_mat.emission = eye_color
		eye_mat.emission_energy_multiplier = 1.8
	eye_mat.roughness = 0.30
	# If there's a cap graft, distribute eyes across the cap dome surface.
	# Otherwise scatter them along the lid in a wider band.
	var cap_radius: float = float(grafted.get("mushroom_cap_radius", 0.0))
	var has_cap: bool = bool(grafted.get("has_cap_graft", false)) and cap_radius > 0.01
	for i in range(eye_count):
		var eye := MeshInstance3D.new()
		eye.name = "GraftedExtraEye_%d" % i
		var sph := SphereMesh.new()
		sph.radius = eye_radius
		sph.height = eye_radius * 2.0
		eye.mesh = sph
		eye.material_override = eye_mat
		var theta: float = (float(i) / float(eye_count)) * TAU
		if has_cap:
			# Distribute eyes around the grafted mushroom cap's upper hemisphere.
			var phi: float = lerpf(0.20, PI * 0.40, fmod(float(i) * 0.31, 1.0))
			var ring_r: float = cap_radius * 1.4 * sin(phi) * 0.85
			var x: float = cos(theta) * ring_r
			var z: float = sin(theta) * ring_r
			# Match the cap-graft geometry: graft_root at body_top+0.08+connector_h
			# (= body_top+0.28 with connector_h=0.20). Sphere center inside
			# graft_root at dome_h*0.5. Sphere y-radius = dome_h*0.5.
			var connector_h: float = 0.20
			var dome_h: float = maxf(float(grafted.get("mushroom_cap_height", 0.18)) * 1.4 * 1.8, cap_radius * 1.4 * 1.4)
			var cap_center_world: float = _body_top_world_y() + 0.08 + connector_h + dome_h * 0.5
			var y: float = cap_center_world + (dome_h * 0.5) * cos(phi) * 0.94
			if _lid_pivot:
				# Convert world Y back into lid-local since we parent to lid_pivot.
				var pivot_y: float = _body_top_world_y()
				eye.position = Vector3(x, y - pivot_y, z + _D * 0.5)
			else:
				eye.position = Vector3(x, y, z)
		else:
			# No cap — scatter eyes across the lid's top surface in a ring.
			var lid_thickness: float = 0.06
			var ring_r2: float = _W * 0.30
			var x2: float = cos(theta) * ring_r2
			var z2: float = sin(theta) * ring_r2
			if _lid_pivot:
				eye.position = Vector3(x2, lid_thickness + eye_radius, _D * 0.5 + z2 * 0.3)
			else:
				eye.position = Vector3(x2, _body_top_world_y() + eye_radius, z2 * 0.3)
		eye_parent.add_child(eye)

## Compound feature: a thin mushroom stem antenna sticking straight up from
## the lid (instead of or in addition to the full cap graft). Looks like
## the mushroom parent's stem is poking out of the chest's top.
func _graft_stem_antenna(grafted: Dictionary) -> void:
	var antenna_parent: Node3D = _lid_pivot if _lid_pivot else _body_root
	if antenna_parent == null:
		return
	var antenna := MeshInstance3D.new()
	antenna.name = "GraftedStemAntenna"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.035
	cyl.height = 0.22
	cyl.radial_segments = 12
	antenna.mesh = cyl
	var stem_color: Color = Color(grafted.get("mushroom_cap_color", Color(0.86, 0.25, 0.25))).lerp(Color(0.93, 0.88, 0.74), 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stem_color
	mat.roughness = 0.85
	antenna.material_override = mat
	if _lid_pivot:
		antenna.position = Vector3(0, 0.06 + 0.11, _D * 0.5)
	else:
		antenna.position = Vector3(0, _body_top_world_y() + 0.11, 0)
	antenna_parent.add_child(antenna)
	# Tiny knob on top of the antenna for character.
	var knob := MeshInstance3D.new()
	knob.name = "AntennaKnob"
	var sph_k := SphereMesh.new()
	sph_k.radius = 0.045
	sph_k.height = 0.09
	knob.mesh = sph_k
	var knob_mat := StandardMaterial3D.new()
	knob_mat.albedo_color = Color(grafted.get("mushroom_cap_color", Color(0.86, 0.25, 0.25)))
	knob_mat.roughness = 0.80
	knob.material_override = knob_mat
	if _lid_pivot:
		knob.position = Vector3(0, 0.06 + 0.22, _D * 0.5)
	else:
		knob.position = Vector3(0, _body_top_world_y() + 0.22, 0)
	antenna_parent.add_child(knob)

## Goblin-source: tint the chest body to match the goblin parent's skin.
func _graft_goblin_tint(grafted: Dictionary) -> void:
	if _body_root == null:
		return
	var skin: Color = Color(grafted.get("goblin_skin_color", Color(0.42, 0.66, 0.28)))
	# Add a thin overlay box on the front of the chest tinted goblin-green,
	# visible as a "stain" patch of mimic chest with goblin skin tissue.
	var stain := MeshInstance3D.new()
	stain.name = "GraftedGoblinStain"
	var box := BoxMesh.new()
	box.size = Vector3(_W * 0.40, _H * 0.30, 0.012)
	stain.mesh = box
	_apply_albedo_material(stain, skin, 0.9, 0.0)
	stain.position = Vector3(-_W * 0.18, _H * 0.30, _D * 0.5 + 0.008)
	_body_root.add_child(stain)

## Goat-source: small horn protrusions emerging from the lid corners.
func _graft_goat_features(grafted: Dictionary) -> void:
	if not bool(grafted.get("goat_horn_present", false)):
		return
	var horn_parent: Node3D = _lid_pivot if _lid_pivot else _body_root
	if horn_parent == null:
		return
	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		horn.name = "GraftedHorn_%s" % ("L" if side < 0 else "R")
		var cone := CylinderMesh.new()
		cone.top_radius = 0.012
		cone.bottom_radius = 0.025
		cone.height = 0.12
		horn.mesh = cone
		_apply_albedo_material(horn, Color(0.55, 0.40, 0.25), 0.8, 0.0)
		if _lid_pivot:
			horn.position = Vector3(side * (_W * 0.35), 0.06, _D * 0.45)
			horn.rotation_degrees = Vector3(side * 12.0, 0, side * -8.0)
		else:
			horn.position = Vector3(side * (_W * 0.35), _body_top_world_y() + 0.06, _D * 0.30)
		horn_parent.add_child(horn)
