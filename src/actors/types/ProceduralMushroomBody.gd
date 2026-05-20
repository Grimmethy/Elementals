class_name ProceduralMushroomBody
extends Node3D

## Procedurally assembles a Mushroom Monster body from a MushroomData.genome.
##
## v1 reads three slots: cap, body, face.
## All other slots (surface, palette, limbs, animation, attack, mutation) are
## intentionally inert here — future generators plug in by reading their
## respective slot WITHOUT touching this file's contract with the data class.
##
## The generator follows the SAME pattern as ProceduralMimicChest: rebuild()
## clears children, then composes Mesh primitives whose dimensions come from
## the genome. Colors come from genome["palette"], so swapping the palette
## reskins the whole creature without re-meshing.

@export var mushroom_data: MushroomData = null:
	set(v):
		if mushroom_data == v:
			return
		mushroom_data = v
		if is_inside_tree():
			rebuild_from_genome()

# Sub-roots so rebuilds can clear known scaffolding without nuking siblings.
var _cap_root: Node3D = null
var _stem_root: Node3D = null
var _face_root: Node3D = null
var _limbs_root: Node3D = null
var _bob_time: float = 0.0
# Cap's correct elevated position (stored at rebuild time so the per-frame
# bob animation can ADD to it instead of OVERWRITING it). Without this,
# `_cap_root.position.y = sin(...) * amp` would collapse the cap to floor
# level every frame, while the stem stayed in place — making the mushroom
# look upside-down.
var _cap_base_y: float = 0.0
var _idle_lean_phase: float = 0.0
## Seeded RNG used by every rendering randf/randi call so the procedural
## body produces identical visuals for the same MushroomData.render_seed.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Don't auto-create a default MushroomData here. The owning MushroomActor
	# pushes its randomized genome via call_deferred("_push_genome_to_body"),
	# and rebuild_from_genome() short-circuits on null data. This avoids the
	# 1-frame flash of a default red mushroom before the randomized version
	# rebuilds.
	if mushroom_data:
		rebuild_from_genome()

func _process(delta: float) -> void:
	if mushroom_data == null or not mushroom_data.genome.has("animation"):
		return
	var anim: Dictionary = mushroom_data.genome["animation"]
	var bob_speed: float = float(anim.get("bob_speed", 1.6))
	var bob_amp: float = float(anim.get("bob_amplitude", 0.04))
	var lean_speed: float = float(anim.get("idle_lean_speed", 0.8))
	var lean_amp: float = float(anim.get("idle_lean_amplitude", 2.5))
	_bob_time += delta * bob_speed
	_idle_lean_phase += delta * lean_speed
	if _cap_root:
		# CRITICAL: add bob_amp to the cap's stored base Y, do NOT overwrite.
		# Overwriting collapsed the cap to y≈0 each frame and made the
		# mushroom render upside-down (cap at floor, stem above).
		_cap_root.position.y = _cap_base_y + sin(_bob_time) * bob_amp
		_cap_root.rotation_degrees.z = sin(_idle_lean_phase) * lean_amp

func rebuild_from_genome() -> void:
	# Drop the old scaffolding (preserve other children added by Actor).
	_clear_built_children()
	if mushroom_data == null:
		return
	# Seed _rng with the kid's stable identity so any rendering randi/randf
	# (gem positions, etc.) produces identical visuals every rebuild.
	if mushroom_data.render_seed != 0:
		_rng.seed = mushroom_data.render_seed
	var g: Dictionary = mushroom_data.genome
	# Resolve palette first so cap/stem/face can read it.
	var palette: Dictionary = g.get("palette", MushroomData.default_genome()["palette"])
	var body_slot: Dictionary = g.get("body", {})
	var limbs_slot: Dictionary = g.get("limbs", {})

	# If the mushroom has legs, lift the whole stem+cap+face stack by leg_length
	# so the feet rest on the ground instead of the stem clipping through it.
	var foot_offset: float = float(body_slot.get("foot_offset", 0.0))

	# Stem
	_stem_root = _build_stem(body_slot, palette)
	_stem_root.position.y = foot_offset
	add_child(_stem_root)
	# Cap on top of the stem
	_cap_root = _build_cap(g.get("cap", {}), palette)
	var stem_height: float = float(body_slot.get("height", 0.55))
	_cap_base_y = stem_height + foot_offset
	_cap_root.position = Vector3(0, _cap_base_y, 0)
	add_child(_cap_root)
	# Face on the stem
	_face_root = _build_face(g.get("face", {}), palette, body_slot)
	_face_root.position.y = foot_offset
	add_child(_face_root)
	# Limbs (arms + legs) — feature #5/#6 in the visible-features list. Arms
	# attach to the side of the stem; legs sprout from the base.
	_limbs_root = _build_limbs(limbs_slot, body_slot, palette)
	_limbs_root.position.y = foot_offset
	add_child(_limbs_root)
	# FRANKENSTEIN GRAFT: cross-species body parts inherited via breeding.
	# Adds visible Mimic bands wrapping the stem + Mimic teeth on the cap
	# edge (for Mushroom × Mimic kids) or other species' visible features.
	if g.has("grafted"):
		_apply_cross_species_graft(g["grafted"], body_slot, palette, foot_offset)

func _clear_built_children() -> void:
	# IMMEDIATE free instead of queue_free so rebuilds in the same frame
	# don't leave ghost meshes in the SubViewport until end-of-frame.
	for child in [_cap_root, _stem_root, _face_root, _limbs_root]:
		if child and is_instance_valid(child):
			if child.get_parent() == self:
				remove_child(child)
			child.free()
	_cap_root = null
	_stem_root = null
	_face_root = null
	_limbs_root = null
	# Also nuke any leftover root we added via graft helpers (they're direct
	# children of self with deterministic names) so multi-rebuilds don't
	# accumulate graft scaffolding either.
	for graft_name in ["GraftedMushroomCap", "GraftedBodySpot", "GraftedMimicBands",
			"GraftedMimicTeeth", "GraftedGoblinSleeve", "GraftedGoatHorns",
			"GraftedExtraEye", "GraftedStemAntenna"]:
		var leftover := find_child(graft_name, false, false)
		while leftover:
			if leftover.get_parent() == self:
				remove_child(leftover)
			leftover.free()
			leftover = find_child(graft_name, false, false)

# --- Module builders -------------------------------------------------------

func _build_stem(body_slot: Dictionary, palette: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Stem"
	var height: float = float(body_slot.get("height", 0.55))
	var r_top: float = float(body_slot.get("radius_top", 0.16))
	var r_bot: float = float(body_slot.get("radius_bottom", 0.20))
	var stem_mesh := MeshInstance3D.new()
	stem_mesh.name = "StemMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = height
	cyl.radial_segments = 16
	stem_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(palette.get("stem_color", Color(0.93, 0.88, 0.74)))
	stem_mesh.material_override = mat
	# Center the cylinder so its base sits on y=0 (foot of the actor).
	stem_mesh.transform.origin = Vector3(0, height * 0.5, 0)
	root.add_child(stem_mesh)
	return root

func _build_cap(cap_slot: Dictionary, palette: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Cap"
	var radius: float = float(cap_slot.get("radius", 0.45))
	var height: float = float(cap_slot.get("height", 0.28))
	var profile: String = String(cap_slot.get("profile", "dome"))
	var cap_mesh := MeshInstance3D.new()
	cap_mesh.name = "CapMesh"
	# Y-offset where the cap mesh's CENTER should sit (relative to cap_root,
	# which is anchored at the top of the stem). Different mesh primitives
	# need different anchor offsets so the cap visually rests ON the stem
	# instead of bulging halfway through it.
	var cap_y_offset: float = height * 0.5
	# Y half-extent of the cap mesh (used by spot placement so spots land on
	# the actual surface for squashed/stretched spheres).
	var cap_y_extent: float = height
	match profile:
		"flat":
			# Pancake cap — short cylinder. Wide BOTTOM (at -Y, touching the
			# stem) tapers slightly to the narrower TOP (+Y).
			var cyl := CylinderMesh.new()
			cyl.top_radius = radius * 0.95
			cyl.bottom_radius = radius
			var thickness: float = maxf(height * 0.55, 0.10)
			cyl.height = thickness
			cyl.radial_segments = 22
			cap_mesh.mesh = cyl
			cap_y_offset = thickness * 0.5
			cap_y_extent = thickness * 0.5
		"cone":
			# Witch-hat: narrow apex (+Y), wide base (-Y at stem). Cone POINTS UP.
			var cone := CylinderMesh.new()
			cone.top_radius = radius * 0.05
			cone.bottom_radius = radius
			var cone_h: float = height * 1.8
			cone.height = cone_h
			cone.radial_segments = 22
			cap_mesh.mesh = cone
			cap_y_offset = cone_h * 0.5
			cap_y_extent = cone_h * 0.5
		"bell":
			# Bell: tall stretched sphere. Y half-extent > radius, so it reads
			# as a vertical bell rather than a flat dome.
			var sph := SphereMesh.new()
			sph.radius = radius
			var bell_h: float = maxf(radius * 2.4, height * 2.6)
			sph.height = bell_h
			cap_mesh.mesh = sph
			cap_y_offset = bell_h * 0.5 - radius * 0.5  # bias dome upward, slight overlap with stem
			cap_y_extent = bell_h * 0.5
		_:  # "dome"
			# Classic mushroom cap. Use a FULL sphere — the upper half forms
			# the visible dome, the lower half becomes the cap's underside
			# flange (where real mushroom gills live).
			# NOTE: SphereMesh.is_hemisphere in Godot 4 generates the BOTTOM
			# half (flat face at +Y, curve descending into -Y), the OPPOSITE
			# of what we want for a mushroom dome. Hence the full-sphere
			# approach — no orientation dependency.
			var dome := SphereMesh.new()
			dome.radius = radius
			var dome_h: float = maxf(height * 1.8, radius * 1.4)
			dome.height = dome_h
			cap_mesh.mesh = dome
			# Sit the sphere so its EQUATOR is just below the stem top, then
			# the upper half rises above as the visible dome and the lower
			# half makes the underside flange. Slight offset lifts the cap
			# so it doesn't sink into the stem.
			cap_y_offset = dome_h * 0.25
			cap_y_extent = dome_h * 0.5
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(palette.get("cap_color", Color(0.86, 0.25, 0.25)))
	cap_mesh.material_override = cap_mat
	cap_mesh.transform.origin = Vector3(0, cap_y_offset, 0)
	root.add_child(cap_mesh)
	# Spots — distributed across the upper hemisphere of the cap. Skip on
	# "cone" since polka-dotted witch hats look wrong. Position is computed
	# relative to the cap's sphere center (cap_y_offset) so the spots sit on
	# the actual mesh surface no matter how the cap was offset.
	var spot_count: int = int(cap_slot.get("spot_count", 5))
	var spot_radius: float = float(cap_slot.get("spot_radius", 0.06))
	if spot_count > 0 and profile != "cone":
		var spot_color: Color = Color(palette.get("spot_color", Color(0.95, 0.95, 0.88)))
		var spot_mat := StandardMaterial3D.new()
		spot_mat.albedo_color = spot_color
		for i in range(spot_count):
			var spot := MeshInstance3D.new()
			spot.name = "Spot_%d" % i
			var spot_mesh := SphereMesh.new()
			spot_mesh.radius = spot_radius
			spot_mesh.height = spot_radius * 2.0
			spot.mesh = spot_mesh
			spot.material_override = spot_mat
			var theta: float = (float(i) / float(spot_count)) * TAU + sin(float(i) * 1.7) * 0.3
			# phi in [0..pi/2] keeps spots on the UPPER hemisphere only.
			var phi: float = lerpf(0.15, PI * 0.42, fmod(float(i) * 0.37 + 0.13, 1.0))
			var x: float = cos(theta) * radius * sin(phi) * 0.94
			var z: float = sin(theta) * radius * sin(phi) * 0.94
			var y: float = 0.0
			match profile:
				"flat":
					# Spots sit on the top face of the pancake cylinder.
					y = cap_y_extent * 2.0 + spot_radius * 0.4
				_:
					# Project onto the ellipsoid surface using its actual Y
					# half-extent (NOT cap.radius, since dome/bell are
					# squashed/stretched on Y).
					y = cap_y_offset + cap_y_extent * cos(phi) * 0.96
			spot.transform.origin = Vector3(x, y, z)
			root.add_child(spot)
	return root

func _build_face(face_slot: Dictionary, palette: Dictionary, body_slot: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Face"
	var stem_radius: float = float(body_slot.get("radius_top", 0.16))
	# Eyes
	var eye_count: int = int(face_slot.get("eye_count", 2))
	var eye_radius: float = float(face_slot.get("eye_radius", 0.05))
	var eye_spread: float = float(face_slot.get("eye_spread", 0.18))
	var eye_y_local: float = float(face_slot.get("eye_y_offset", 0.30))
	var eye_color: Color = Color(palette.get("eye_color", Color(0.05, 0.05, 0.05)))
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	for i in range(eye_count):
		var eye := MeshInstance3D.new()
		eye.name = "Eye_%d" % i
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = eye_radius
		eye_mesh.height = eye_radius * 2.0
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		# Spread eyes across the stem front: 1 eye = centered cyclops,
		# 2 eyes = symmetric pair, more = even arc across the front.
		var t: float = 0.0
		if eye_count > 1:
			t = (float(i) - (float(eye_count - 1) * 0.5)) / float(eye_count)
		var x: float = t * eye_spread
		# Push eyes onto the stem surface (front-facing, +z).
		var z: float = stem_radius * 0.95
		eye.transform.origin = Vector3(x, eye_y_local, z)
		root.add_child(eye)
	# Mouth — shape depends on expression.
	var mouth_w: float = float(face_slot.get("mouth_width", 0.18))
	var mouth_h: float = float(face_slot.get("mouth_height", 0.04))
	var mouth_y_local: float = float(face_slot.get("mouth_y_offset", 0.20))
	var expression: String = String(face_slot.get("expression", "smile"))
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(palette.get("mouth_color", Color(0.10, 0.05, 0.04)))
	_build_mouth(root, expression, mouth_w, mouth_h, mouth_y_local, stem_radius, mouth_mat)
	return root

## Build the mouth as 3 small box segments arranged by the expression curve:
##   smile  - corners up
##   frown  - corners down
##   o      - single round mouth
##   smirk  - one corner up, the other flat
func _build_mouth(root: Node3D, expression: String, mouth_w: float, mouth_h: float, mouth_y_local: float, stem_radius: float, mat: StandardMaterial3D) -> void:
	var z: float = stem_radius * 0.97
	if expression == "o":
		var o := MeshInstance3D.new()
		o.name = "Mouth"
		var sph := SphereMesh.new()
		sph.radius = mouth_h * 1.6
		sph.height = mouth_h * 3.2
		o.mesh = sph
		o.material_override = mat
		o.transform.origin = Vector3(0, mouth_y_local, z)
		root.add_child(o)
		return
	# Three segments: left corner, middle, right corner.
	var corner_dy: float = mouth_h * 1.6  # how high/low corners sit vs middle
	var seg_w: float = mouth_w * 0.45
	var middle := MeshInstance3D.new()
	middle.name = "MouthMiddle"
	var mid_mesh := BoxMesh.new()
	mid_mesh.size = Vector3(mouth_w * 0.4, mouth_h, 0.02)
	middle.mesh = mid_mesh
	middle.material_override = mat
	middle.transform.origin = Vector3(0, mouth_y_local, z)
	root.add_child(middle)
	var left_dy: float = 0.0
	var right_dy: float = 0.0
	match expression:
		"smile":
			left_dy = corner_dy
			right_dy = corner_dy
		"frown":
			left_dy = -corner_dy
			right_dy = -corner_dy
		"smirk":
			left_dy = 0.0
			right_dy = corner_dy
		_:
			pass
	var left := MeshInstance3D.new()
	left.name = "MouthLeft"
	var l_mesh := BoxMesh.new()
	l_mesh.size = Vector3(seg_w, mouth_h, 0.02)
	left.mesh = l_mesh
	left.material_override = mat
	left.transform.origin = Vector3(-mouth_w * 0.45, mouth_y_local + left_dy, z)
	root.add_child(left)
	var right := MeshInstance3D.new()
	right.name = "MouthRight"
	var r_mesh := BoxMesh.new()
	r_mesh.size = Vector3(seg_w, mouth_h, 0.02)
	right.mesh = r_mesh
	right.material_override = mat
	right.transform.origin = Vector3(mouth_w * 0.45, mouth_y_local + right_dy, z)
	root.add_child(right)

## Build arms + legs from the limbs slot. Arms attach to the sides of the
## stem and droop forward/down based on `arm_droop`. Legs sprout from the
## stem base and end in small foot spheres.
func _build_limbs(limbs_slot: Dictionary, body_slot: Dictionary, palette: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Limbs"
	var stem_radius_top: float = float(body_slot.get("radius_top", 0.16))
	var stem_radius_bot: float = float(body_slot.get("radius_bottom", 0.20))
	var stem_color: Color = Color(palette.get("stem_color", Color(0.93, 0.88, 0.74)))
	var limb_mat := StandardMaterial3D.new()
	limb_mat.albedo_color = stem_color.darkened(0.08)

	# --- Arms ---
	if bool(limbs_slot.get("has_arms", false)):
		var arm_length: float = float(limbs_slot.get("arm_length", 0.32))
		var arm_radius: float = float(limbs_slot.get("arm_radius", 0.045))
		var arm_y: float = float(limbs_slot.get("arm_y_offset", 0.32))
		var arm_droop: float = clampf(float(limbs_slot.get("arm_droop", 0.0)), -1.0, 1.0)
		for side in [-1.0, 1.0]:
			var arm_pivot := Node3D.new()
			arm_pivot.name = "Arm_%s" % ("L" if side < 0 else "R")
			arm_pivot.position = Vector3(side * stem_radius_top * 0.95, arm_y, 0)
			# Arm is a cylinder pointing along +X (or -X), then rotated by
			# droop around Z so it angles downward.
			var arm := MeshInstance3D.new()
			arm.name = "ArmMesh"
			var cyl := CylinderMesh.new()
			cyl.top_radius = arm_radius * 0.7
			cyl.bottom_radius = arm_radius
			cyl.height = arm_length
			cyl.radial_segments = 10
			arm.mesh = cyl
			arm.material_override = limb_mat
			# Cylinder default axis is +Y; we want it sticking out sideways
			# (along +X for right arm). Rotate -90deg around Z for right arm,
			# +90deg for left. Then add droop (rotate around the attachment).
			var base_rot: float = -PI * 0.5 if side > 0 else PI * 0.5
			var droop_rot: float = arm_droop * (PI * 0.5)  # -90 to +90 degrees
			# Subtract `side * droop_rot` so positive droop bends BOTH arms
			# downward symmetrically (right arm rotates more clockwise from
			# its -90° base, left arm rotates more counterclockwise from +90°).
			arm_pivot.rotation = Vector3(0, 0, base_rot - side * droop_rot)
			arm.transform.origin = Vector3(0, arm_length * 0.5, 0)
			arm_pivot.add_child(arm)
			# Hand: small sphere at the tip.
			var hand := MeshInstance3D.new()
			hand.name = "Hand"
			var hand_mesh := SphereMesh.new()
			hand_mesh.radius = arm_radius * 1.3
			hand_mesh.height = arm_radius * 2.6
			hand.mesh = hand_mesh
			hand.material_override = limb_mat
			hand.transform.origin = Vector3(0, arm_length, 0)
			arm_pivot.add_child(hand)
			root.add_child(arm_pivot)

	# --- Legs ---
	if bool(limbs_slot.get("has_legs", false)):
		var leg_length: float = float(limbs_slot.get("leg_length", 0.22))
		var leg_radius: float = float(limbs_slot.get("leg_radius", 0.06))
		var leg_spread: float = float(limbs_slot.get("leg_spread", 0.10))
		var foot_size: float = float(limbs_slot.get("foot_size", 0.08))
		for side in [-1.0, 1.0]:
			var leg_pivot := Node3D.new()
			leg_pivot.name = "Leg_%s" % ("L" if side < 0 else "R")
			# Legs attach at the bottom of the stem (y=0 in the lifted frame),
			# pointing DOWN. Spread is the horizontal distance between feet.
			leg_pivot.position = Vector3(side * leg_spread, 0, 0)
			var leg := MeshInstance3D.new()
			leg.name = "LegMesh"
			var cyl := CylinderMesh.new()
			cyl.top_radius = leg_radius
			cyl.bottom_radius = leg_radius * 0.85
			cyl.height = leg_length
			cyl.radial_segments = 10
			leg.mesh = cyl
			leg.material_override = limb_mat
			# Cylinder default points along +Y; we want legs pointing DOWN,
			# so rotate 180 around X. Position the mesh so its top is at the
			# pivot and bottom extends downward by leg_length.
			leg.rotation = Vector3(PI, 0, 0)
			leg.transform.origin = Vector3(0, -leg_length * 0.5, 0)
			leg_pivot.add_child(leg)
			# Foot: flattened sphere at the leg base.
			var foot := MeshInstance3D.new()
			foot.name = "Foot"
			var foot_mesh := SphereMesh.new()
			foot_mesh.radius = foot_size
			foot_mesh.height = foot_size * 1.2
			foot.mesh = foot_mesh
			foot.material_override = limb_mat
			foot.transform.origin = Vector3(0, -leg_length, foot_size * 0.4)
			foot.scale = Vector3(1.0, 0.5, 1.4)  # flatten + lengthen forward
			leg_pivot.add_child(foot)
			root.add_child(leg_pivot)
	# (Stem and lifted-frame Y offset already applied by caller.)
	return root

# === Cross-species graft rendering ========================================

func _apply_cross_species_graft(grafted: Dictionary, body_slot: Dictionary, palette: Dictionary, foot_offset: float) -> void:
	var source: String = String(grafted.get("source_species", ""))
	print("[Graft][Mushroom] source='%s' band=%s tooth=%s eyes=%s lid=%s gems=%s extra_eye_n=%s" % [
		source,
		grafted.get("has_band_graft", false),
		grafted.get("has_tooth_graft", false),
		grafted.get("has_extra_eyes_on_cap", false),
		grafted.get("has_lid_crown", false),
		grafted.get("has_gem_scatter", false),
		grafted.get("extra_eye_count", 0)
	])
	if source.is_empty():
		return
	var cap_slot: Dictionary = {}
	if mushroom_data and mushroom_data.genome.has("cap"):
		cap_slot = mushroom_data.genome["cap"]
	match source:
		"mimic":
			# Each compound feature rolls independently — sibling hybrids
			# get unique combinations of bands / teeth / eyes / crown / gems.
			if bool(grafted.get("has_band_graft", false)):
				_graft_mimic_bands(grafted, body_slot, foot_offset)
			if bool(grafted.get("has_tooth_graft", false)):
				_graft_mimic_teeth(grafted, body_slot, cap_slot, foot_offset)
			if bool(grafted.get("has_extra_eyes_on_cap", false)):
				_graft_mimic_eyes_on_cap(grafted, body_slot, cap_slot, foot_offset)
			if bool(grafted.get("has_lid_crown", false)):
				_graft_mimic_lid_crown(grafted, body_slot, cap_slot, foot_offset)
			if bool(grafted.get("has_gem_scatter", false)):
				_graft_gem_scatter(grafted, body_slot, cap_slot, foot_offset)
		"goblin":
			_graft_goblin_tint(grafted, body_slot, foot_offset)
		"goat":
			_graft_goat_horns(grafted, body_slot, foot_offset)

## (Legacy) Original combined bands+teeth renderer. Kept for direct callers
## but the public path now uses _graft_mimic_bands and _graft_mimic_teeth
## as separate modular features rolled independently.
func _graft_mimic_features(grafted: Dictionary, body_slot: Dictionary, cap_slot: Dictionary, foot_offset: float) -> void:
	# Force minimum counts so the graft is always visibly present.
	var band_count: int = maxi(int(grafted.get("mimic_band_count", 0)), 3)
	var tooth_count: int = maxi(int(grafted.get("mimic_tooth_count", 0)), 8)
	var stem_height: float = float(body_slot.get("height", 0.55))
	var stem_radius_bot: float = float(body_slot.get("radius_bottom", 0.20))
	var stem_radius_top: float = float(body_slot.get("radius_top", 0.16))
	var cap_radius: float = float(cap_slot.get("radius", 0.40))
	var graft_root := Node3D.new()
	graft_root.name = "GraftedMimicFeatures"
	graft_root.position.y = foot_offset
	add_child(graft_root)
	# Bands around stem — thicker rings so they're obvious metalwork, not
	# just hint-stripes. Material is more metallic and slightly emissive
	# so they catch any light in the SubViewport.
	if band_count > 0:
		var band_color: Color = Color(grafted.get("mimic_band_color", Color(0.78, 0.65, 0.20)))
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = band_color
		band_mat.metallic = 0.85
		band_mat.roughness = 0.22
		for i in range(band_count):
			var t: float = (float(i) + 1.0) / float(band_count + 1)
			var y: float = stem_height * t
			var ring_radius: float = lerpf(stem_radius_bot, stem_radius_top, t) * 1.15
			var torus := TorusMesh.new()
			torus.inner_radius = ring_radius * 0.88
			torus.outer_radius = ring_radius * 1.15  # thicker band
			torus.ring_segments = 16
			torus.rings = 28
			var band := MeshInstance3D.new()
			band.name = "GraftedBand_%d" % i
			band.mesh = torus
			band.material_override = band_mat
			band.position = Vector3(0, y, 0)
			band.rotation_degrees = Vector3(90, 0, 0)
			graft_root.add_child(band)
	# Teeth ringed JUST OUTSIDE the cap's outer edge — vertical fangs
	# hanging straight down from the cap rim. ring_radius scales from the
	# kid's actual cap_radius so they're cap-shape-aware. They cannot be
	# occluded by the cap because they sit BEYOND its silhouette.
	if tooth_count > 0:
		var tooth_size: float = maxf(float(grafted.get("mimic_tooth_size", 0.03)), 0.045) * 1.7
		var tooth_color: Color = Color(grafted.get("mimic_tooth_color", Color(0.98, 0.94, 0.85)))
		var tooth_mat := StandardMaterial3D.new()
		tooth_mat.albedo_color = tooth_color
		tooth_mat.roughness = 0.55
		var tooth_height: float = tooth_size * 2.4
		# Ring sits at the cap's equator. Vertical fangs hang straight down
		# from there. Push ring_radius outside the cap by ~15% so the teeth
		# are visible against the body silhouette from every angle.
		var ring_y: float = stem_height + foot_offset
		var ring_radius: float = maxf(cap_radius * 1.15, stem_radius_top * 2.6)
		for i in range(tooth_count):
			var theta: float = (float(i) / float(tooth_count)) * TAU
			var x: float = cos(theta) * ring_radius
			var z: float = sin(theta) * ring_radius
			var tooth := MeshInstance3D.new()
			tooth.name = "GraftedTooth_%d" % i
			var cone := CylinderMesh.new()
			# Top radius = wide attachment to cap rim, bottom = narrow tip
			# pointing straight down.
			cone.top_radius = tooth_size * 0.55
			cone.bottom_radius = tooth_size * 0.05
			cone.height = tooth_height
			cone.radial_segments = 7
			tooth.mesh = cone
			tooth.material_override = tooth_mat
			# Wide top at cap-rim level; tip hangs below.
			tooth.position = Vector3(x, ring_y - tooth_height * 0.5, z)
			graft_root.add_child(tooth)

# --- New modular Mimic-source compound features ---------------------------

## Just the BANDS part — gold metal hoops wrapping the stem at 25/50/75%.
func _graft_mimic_bands(grafted: Dictionary, body_slot: Dictionary, foot_offset: float) -> void:
	var band_count: int = maxi(int(grafted.get("mimic_band_count", 0)), 3)
	var stem_height: float = float(body_slot.get("height", 0.55))
	var stem_radius_bot: float = float(body_slot.get("radius_bottom", 0.20))
	var stem_radius_top: float = float(body_slot.get("radius_top", 0.16))
	var band_color: Color = Color(grafted.get("mimic_band_color", Color(0.78, 0.65, 0.20)))
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = band_color
	band_mat.metallic = 0.85
	band_mat.roughness = 0.22
	var graft_root := Node3D.new()
	graft_root.name = "GraftedMimicBands"
	graft_root.position.y = foot_offset
	add_child(graft_root)
	for i in range(band_count):
		var t: float = (float(i) + 1.0) / float(band_count + 1)
		var y: float = stem_height * t
		var ring_radius: float = lerpf(stem_radius_bot, stem_radius_top, t) * 1.15
		var torus := TorusMesh.new()
		torus.inner_radius = ring_radius * 0.88
		torus.outer_radius = ring_radius * 1.15
		torus.ring_segments = 16
		torus.rings = 28
		var band := MeshInstance3D.new()
		band.mesh = torus
		band.material_override = band_mat
		band.position = Vector3(0, y, 0)
		band.rotation_degrees = Vector3(90, 0, 0)
		graft_root.add_child(band)

## Just the TEETH part — vertical fangs hanging from the cap rim, outside
## the cap silhouette so they're never hidden by the cap overhang.
func _graft_mimic_teeth(grafted: Dictionary, body_slot: Dictionary, cap_slot: Dictionary, foot_offset: float) -> void:
	var tooth_count: int = maxi(int(grafted.get("mimic_tooth_count", 0)), 8)
	var stem_height: float = float(body_slot.get("height", 0.55))
	var stem_radius_top: float = float(body_slot.get("radius_top", 0.16))
	var cap_radius: float = float(cap_slot.get("radius", 0.40))
	var tooth_size: float = maxf(float(grafted.get("mimic_tooth_size", 0.03)), 0.045) * 1.7
	var tooth_height: float = tooth_size * 2.4
	var tooth_color: Color = Color(grafted.get("mimic_tooth_color", Color(0.98, 0.94, 0.85)))
	var tooth_mat := StandardMaterial3D.new()
	tooth_mat.albedo_color = tooth_color
	tooth_mat.roughness = 0.55
	var graft_root := Node3D.new()
	graft_root.name = "GraftedMimicTeeth"
	graft_root.position.y = foot_offset
	add_child(graft_root)
	var ring_y: float = stem_height + foot_offset
	var ring_radius: float = maxf(cap_radius * 1.15, stem_radius_top * 2.6)
	for i in range(tooth_count):
		var theta: float = (float(i) / float(tooth_count)) * TAU
		var x: float = cos(theta) * ring_radius
		var z: float = sin(theta) * ring_radius
		var tooth := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = tooth_size * 0.55
		cone.bottom_radius = tooth_size * 0.05
		cone.height = tooth_height
		cone.radial_segments = 7
		tooth.mesh = cone
		tooth.material_override = tooth_mat
		tooth.position = Vector3(x, ring_y - tooth_height * 0.5, z)
		graft_root.add_child(tooth)

## Compound feature: extra GLOWING Mimic-style eyes scattered across the
## upper hemisphere of the cap. Mimic eyes are signature-glowing red, so
## these stand out brightly against the mushroom cap's natural color.
func _graft_mimic_eyes_on_cap(grafted: Dictionary, body_slot: Dictionary, cap_slot: Dictionary, foot_offset: float) -> void:
	if _cap_root == null:
		return
	var eye_count: int = clampi(int(grafted.get("extra_eye_count", 4)), 1, 12)
	var eye_radius: float = maxf(float(grafted.get("extra_eye_radius", 0.04)), 0.035)
	var eye_color: Color = Color(grafted.get("mimic_eye_color", Color(0.94, 0.18, 0.10)))
	var cap_radius: float = float(cap_slot.get("radius", 0.40))
	var cap_height: float = float(cap_slot.get("height", 0.25))
	var dome_h: float = maxf(cap_height * 1.8, cap_radius * 1.4)
	var cap_y_extent: float = dome_h * 0.5
	# Distribute around the upper hemisphere. Parent to cap_root so eyes
	# bob with the cap during animation.
	var graft_root := Node3D.new()
	graft_root.name = "GraftedMimicEyes"
	_cap_root.add_child(graft_root)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 2.0
	eye_mat.roughness = 0.25
	for i in range(eye_count):
		var theta: float = (float(i) / float(eye_count)) * TAU + sin(float(i) * 1.7) * 0.3
		var phi: float = lerpf(0.18, PI * 0.42, fmod(float(i) * 0.37 + 0.13, 1.0))
		var x: float = cos(theta) * cap_radius * sin(phi) * 0.93
		var z: float = sin(theta) * cap_radius * sin(phi) * 0.93
		var y: float = dome_h * 0.25 + cap_y_extent * cos(phi) * 0.97
		var eye := MeshInstance3D.new()
		eye.name = "GraftedMimicEye_%d" % i
		var sph := SphereMesh.new()
		sph.radius = eye_radius
		sph.height = eye_radius * 2.0
		eye.mesh = sph
		eye.material_override = eye_mat
		eye.position = Vector3(x, y, z)
		graft_root.add_child(eye)

## Compound feature: a tiny Mimic LID sitting on top of the cap like a
## crown / hat. The kid looks like a mushroom wearing a chest lid hat.
func _graft_mimic_lid_crown(grafted: Dictionary, body_slot: Dictionary, cap_slot: Dictionary, foot_offset: float) -> void:
	if _cap_root == null:
		return
	var crown_root := Node3D.new()
	crown_root.name = "GraftedLidCrown"
	_cap_root.add_child(crown_root)
	var cap_height: float = float(cap_slot.get("height", 0.25))
	var dome_h: float = maxf(cap_height * 1.8, float(cap_slot.get("radius", 0.40)) * 1.4)
	# Position above the cap apex.
	crown_root.position = Vector3(0, dome_h * 0.5 + 0.04, 0)
	# Tiny lid: short rounded box.
	var lid := MeshInstance3D.new()
	lid.name = "MiniLid"
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.18, 0.05, 0.14)
	lid.mesh = lid_box
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(grafted.get("mimic_band_color", Color(0.4, 0.28, 0.16)))
	lid_mat.roughness = 0.70
	lid.material_override = lid_mat
	lid.position = Vector3(0, 0.03, 0)
	crown_root.add_child(lid)
	# Small metal band wrapping the lid.
	var band := MeshInstance3D.new()
	band.name = "MiniLidBand"
	var band_box := BoxMesh.new()
	band_box.size = Vector3(0.20, 0.012, 0.16)
	band.mesh = band_box
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(grafted.get("mimic_band_color", Color(0.78, 0.65, 0.20)))
	band_mat.metallic = 0.85
	band_mat.roughness = 0.25
	band.material_override = band_mat
	band.position = Vector3(0, 0.04, 0)
	crown_root.add_child(band)

## Compound feature: small gems scattered across the cap surface. Uses
## the Mimic parent's eye color so they read as "the cap has Mimic-style
## ornament gems set into it."
func _graft_gem_scatter(grafted: Dictionary, body_slot: Dictionary, cap_slot: Dictionary, foot_offset: float) -> void:
	if _cap_root == null:
		return
	# Use the SEEDED _rng so gem count + positions are stable across rebuilds.
	var gem_count: int = _rng.randi_range(3, 6)
	var gem_color: Color = Color(grafted.get("mimic_eye_color", Color(0.94, 0.18, 0.10)))
	var cap_radius: float = float(cap_slot.get("radius", 0.40))
	var cap_height: float = float(cap_slot.get("height", 0.25))
	var dome_h: float = maxf(cap_height * 1.8, cap_radius * 1.4)
	var cap_y_extent: float = dome_h * 0.5
	var graft_root := Node3D.new()
	graft_root.name = "GraftedGems"
	_cap_root.add_child(graft_root)
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = gem_color
	gem_mat.emission_enabled = true
	gem_mat.emission = gem_color
	gem_mat.emission_energy_multiplier = 0.8
	gem_mat.metallic = 0.7
	gem_mat.roughness = 0.10
	for i in range(gem_count):
		var theta: float = _rng.randf() * TAU
		var phi: float = _rng.randf_range(0.15, 0.85)
		var x: float = cos(theta) * cap_radius * sin(phi) * 0.92
		var z: float = sin(theta) * cap_radius * sin(phi) * 0.92
		var y: float = dome_h * 0.25 + cap_y_extent * cos(phi) * 0.96
		var gem := MeshInstance3D.new()
		gem.name = "GraftedGem_%d" % i
		var sph := SphereMesh.new()
		sph.radius = 0.022
		sph.height = 0.044
		gem.mesh = sph
		gem.material_override = gem_mat
		gem.position = Vector3(x, y, z)
		graft_root.add_child(gem)

## Goblin-source: tint the stem toward goblin-green by adding a thin overlay.
func _graft_goblin_tint(grafted: Dictionary, body_slot: Dictionary, foot_offset: float) -> void:
	if _stem_root == null:
		return
	var skin: Color = Color(grafted.get("goblin_skin_color", Color(0.42, 0.66, 0.28)))
	var stem_height: float = float(body_slot.get("height", 0.55))
	var stem_r_top: float = float(body_slot.get("radius_top", 0.16))
	# Thin sleeve cylinder slightly outset from the stem.
	var sleeve := MeshInstance3D.new()
	sleeve.name = "GraftedGoblinSleeve"
	var cyl := CylinderMesh.new()
	cyl.top_radius = stem_r_top * 1.05
	cyl.bottom_radius = stem_r_top * 1.05
	cyl.height = stem_height * 0.25
	cyl.radial_segments = 16
	sleeve.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = skin
	mat.roughness = 0.85
	sleeve.material_override = mat
	sleeve.position = Vector3(0, foot_offset + stem_height * 0.50, 0)
	add_child(sleeve)

## Goat-source: small horn-like protrusions from the cap.
func _graft_goat_horns(grafted: Dictionary, body_slot: Dictionary, foot_offset: float) -> void:
	if not bool(grafted.get("goat_horn_present", false)):
		return
	if _cap_root == null:
		return
	var horn_color: Color = Color(grafted.get("goat_horn_color", Color(0.55, 0.40, 0.25)))
	var stem_height: float = float(body_slot.get("height", 0.55))
	var graft_root := Node3D.new()
	graft_root.name = "GraftedGoatHorns"
	graft_root.position.y = foot_offset + stem_height + 0.05
	add_child(graft_root)
	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		horn.name = "GraftedHorn_%s" % ("L" if side < 0 else "R")
		var cone := CylinderMesh.new()
		cone.top_radius = 0.010
		cone.bottom_radius = 0.022
		cone.height = 0.10
		horn.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = horn_color
		mat.roughness = 0.80
		horn.material_override = mat
		horn.position = Vector3(side * 0.12, 0.05, -0.05)
		horn.rotation_degrees = Vector3(-15, 0, side * -25)
		graft_root.add_child(horn)
