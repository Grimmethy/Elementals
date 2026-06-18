class_name PartBuilders
extends RefCounted

## Registry of body-part builders for the universal procedural creature
## renderer (ProceduralCreatureBody.gd). One static dispatch per part-type;
## each dispatch routes to a builder function that constructs a MeshInstance3D
## (or several) and parents them under the supplied root.
##
## Adding a new body shape, head type, ornament, or mutation = adding one
## entry to the matching dictionary + writing the builder function. No other
## file in the engine has to change.
##
## All builders are STATIC functions taking (root, ...params, rng) and have
## no side effects beyond mesh instantiation under root. Determinism comes
## from passing the seeded rng through every random call.
##
## NOTE: Most builders are STUBS in this initial scaffolding pass. They
## produce a basic identifiable mesh so the system runs end-to-end. Each
## stub will be progressively replaced with a richer mesh in later steps
## of HornboundImplementationPlan.md (steps 1.3 - 1.8).

# ============================================================================
# Public dispatch — called by ProceduralCreatureBody
# ============================================================================

## Build the base body shape. Dispatches on `body_type` to a builder. `limbs`
## is consulted to determine ground clearance — bodies with legs sit higher.
## `meta` carries sub_template / category / species so the builder can produce
## a visually distinct mesh per anatomy variant (Wolf vs Bear, Goblin vs Knight).
static func build_body(root: Node3D, body_type: String, base: Dictionary, palette: Dictionary, limbs: Dictionary, meta: Dictionary, rng: RandomNumberGenerator) -> void:
	match body_type:
		"sphere": _build_sphere_body(root, base, palette, limbs, rng)
		"cube": _build_cube_body(root, base, palette, limbs, rng)
		"biped_torso": _build_biped_torso_variant(root, base, palette, limbs, meta, rng)
		"quadruped_torso": _build_quadruped_torso_variant(root, base, palette, limbs, meta, rng)
		"blob": _build_blob_body(root, base, palette, limbs, rng)
		"cylinder": _build_cylinder_body(root, base, palette, limbs, rng)
		_: _build_sphere_body(root, base, palette, limbs, rng)  # Fallback

## Build the top/head/cap mesh. `meta.sub_template` is consulted so the head
## actually looks like the species — pointed muzzle for wolf, round for bear,
## wedge for dragon, etc.
static func build_top(root: Node3D, top_type: String, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, meta: Dictionary, rng: RandomNumberGenerator) -> void:
	match top_type:
		"none": return
		"dome": _build_top_dome(root, top, base, palette, limbs, rng)
		"flat_lid": _build_top_flat_lid(root, top, base, palette, limbs, rng)
		"cap_dome": _build_top_cap_dome(root, top, base, palette, limbs, rng)
		"head_humanoid": _build_top_head_humanoid_variant(root, top, base, palette, limbs, meta, rng)
		"head_beast": _build_top_head_beast_variant(root, top, base, palette, limbs, meta, rng)
		_: _build_top_dome(root, top, base, palette, limbs, rng)

## Humanoid head dispatcher. Different sub-templates get different head shapes.
static func _build_top_head_humanoid_variant(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, meta: Dictionary, rng: RandomNumberGenerator) -> void:
	var sub: String = String(meta.get("sub_template", "warrior_humanoid"))
	match sub:
		"skeleton":
			_build_top_head_skeleton(root, top, base, palette, limbs, rng)
		"zombie":
			_build_top_head_zombie(root, top, base, palette, limbs, rng)
		"caster_humanoid":
			_build_top_head_hooded(root, top, base, palette, limbs, rng)
		"elemental_humanoid":
			_build_top_head_elemental(root, top, base, palette, limbs, rng)
		"bird_like":
			_build_top_head_bird(root, top, base, palette, limbs, rng)
		"golem_large":
			_build_top_head_golem(root, top, base, palette, limbs, rng)
		_:
			_build_top_head_humanoid(root, top, base, palette, limbs, rng)

## Beast head dispatcher. Wolf gets pointed muzzle; Bear gets round; etc.
static func _build_top_head_beast_variant(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, meta: Dictionary, rng: RandomNumberGenerator) -> void:
	var sub: String = String(meta.get("sub_template", "wolf_like"))
	match sub:
		"wolf_like":
			_build_top_head_wolf(root, top, base, palette, limbs, rng)
		"bear_like":
			_build_top_head_bear(root, top, base, palette, limbs, rng)
		"small_animal":
			_build_top_head_small(root, top, base, palette, limbs, rng)
		"small_quadruped":
			_build_top_head_hooved(root, top, base, palette, limbs, rng)
		"dinosaur_like":
			_build_top_head_dinosaur(root, top, base, palette, limbs, rng)
		"lizard_like":
			_build_top_head_lizard(root, top, base, palette, limbs, rng)
		"serpent_like":
			_build_top_head_serpent(root, top, base, palette, limbs, rng)
		"bird_like":
			_build_top_head_bird(root, top, base, palette, limbs, rng)
		"insect_like":
			_build_top_head_insect(root, top, base, palette, limbs, rng)
		"wyrmling", "young_dragon", "adult_dragon", "ancient_dragon":
			_build_top_head_dragon(root, top, base, palette, limbs, rng)
		"wyvern":
			_build_top_head_dragon(root, top, base, palette, limbs, rng)
		_:
			_build_top_head_beast(root, top, base, palette, limbs, rng)

## Build face features (eyes, mouth, optional teeth ring). Eyes and mouth are
## placed ON THE HEAD (positioned via _head_anchor), not on the torso — that
## was the bug that made every creature look like it had eyes on its back.
static func build_face(root: Node3D, face: Dictionary, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var head_anchor: Vector3 = _head_anchor(base, top, limbs)
	_build_eyes(root, face, base, top, limbs, palette, head_anchor, rng)
	var mouth_style: String = String(face.get("mouth_style", "none"))
	match mouth_style:
		"none": return
		"single": _build_mouth_single(root, face, base, palette, head_anchor, rng)
		"teeth_ring": _build_mouth_teeth_ring(root, face, base, palette, head_anchor, rng)
		"maw_horizontal": _build_mouth_maw_horizontal(root, face, base, palette, head_anchor, rng)
		"maw_vertical": _build_mouth_maw_vertical(root, face, base, palette, head_anchor, rng)

## Build limbs based on counts + parameters in the limbs dict.
static func build_limbs(root: Node3D, limbs: Dictionary, base: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	if bool(limbs.get("has_arms", false)):
		_build_arms(root, limbs, base, palette, rng)
	if bool(limbs.get("has_legs", false)):
		_build_legs(root, limbs, base, palette, rng)

## Build an ornament identified by its tag string. Top + limbs are passed so
## ornaments can position themselves correctly (e.g. horns on the head,
## tail at body-rear, halo above head).
static func build_ornament(root: Node3D, tag: String, ornaments: Dictionary, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	match tag:
		"mane": _build_ornament_mane(root, ornaments, base, top, limbs, palette, rng)
		"halo": _build_ornament_halo(root, ornaments, base, top, limbs, palette, rng)
		"wings": _build_ornament_wings(root, ornaments, base, limbs, palette, rng)
		"horns": _build_ornament_horns(root, ornaments, base, top, limbs, palette, rng)
		"tail": _build_ornament_tail(root, ornaments, base, limbs, palette, rng)
		"tentacles": _build_ornament_tentacles(root, ornaments, base, limbs, palette, rng)
		"bone_protrusion": _build_ornament_bone_protrusion(root, ornaments, base, limbs, palette, rng)
		"tattered_cloth": _build_ornament_tattered_cloth(root, ornaments, base, limbs, palette, rng)
		"metallic_plate": _build_ornament_metallic_plate(root, ornaments, base, limbs, palette, rng)
		"flowering_accents": _build_ornament_flowering_accents(root, ornaments, base, limbs, palette, rng)
		"crystal_growth": _build_ornament_crystal_growth(root, ornaments, base, limbs, palette, rng)
		_: pass  # Unknown tag — silently skip (forward-compatible)

## Build a mutation feature based on its tag string. Mutations augment the
## body with weird universal features. `top` + `limbs` are needed so the
## mutation positions itself with proper ground clearance / head reference.
static func build_mutation(root: Node3D, tag: String, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	match tag:
		"third_eye": _build_mutation_third_eye(root, base, top, limbs, palette, rng)
		"glowing_veins": _build_mutation_glowing_veins(root, base, limbs, palette, rng)
		"halo": _build_ornament_halo(root, {}, base, top, limbs, palette, rng)
		"tail_stub": _build_mutation_tail_stub(root, base, limbs, palette, rng)
		"spike_ridge": _build_mutation_spike_ridge(root, base, limbs, palette, rng)
		"crystal_growth": _build_ornament_crystal_growth(root, {}, base, limbs, palette, rng)
		"living_moss": _build_mutation_living_moss(root, base, limbs, palette, rng)
		"chitin_plate": _build_mutation_chitin_plate(root, base, top, limbs, palette, rng)
		"floating_orb": _build_mutation_floating_orb(root, base, top, limbs, palette, rng)
		"extra_mouth": _build_mutation_extra_mouth(root, base, limbs, palette, rng)
		_: pass  # Unknown mutation — silently skip

# ============================================================================
# Body shape builders — STUBS in this scaffolding pass. Step 1.3 fills in.
# ============================================================================

static func _build_sphere_body(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _vec_axis(base, "width", 0.5) * 0.5
	sphere.height = _vec_axis(base, "height", 0.5)
	mi.mesh = sphere
	mi.position = _body_center(base, limbs)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

static func _build_cube_body(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(
		_vec_axis(base, "width", 0.5),
		_vec_axis(base, "height", 0.5),
		_vec_axis(base, "depth", 0.5)
	)
	mi.mesh = cube
	mi.position = _body_center(base, limbs)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## VARIANT DISPATCH: pick the biped torso shape based on sub_template hint.
## Different sub-templates produce VISUALLY DIFFERENT mesh shapes, not just
## different dimensions — caster gets slim/tall, brute gets thick/wide, etc.
static func _build_biped_torso_variant(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, meta: Dictionary, rng: RandomNumberGenerator) -> void:
	var sub: String = String(meta.get("sub_template", "warrior_humanoid"))
	match sub:
		"brute_humanoid", "winged_huge":
			_build_biped_torso_brute(root, base, palette, limbs, rng)
		"caster_humanoid", "tiny_fey":
			_build_biped_torso_slim(root, base, palette, limbs, rng)
		"small_humanoid", "tiny_fiend":
			_build_biped_torso_small(root, base, palette, limbs, rng)
		"dinosaur_like":
			_build_biped_torso_dinosaur(root, base, palette, limbs, rng)
		"bird_like":
			_build_biped_torso_bird(root, base, palette, limbs, rng)
		"elemental_humanoid":
			_build_biped_torso_elemental(root, base, palette, limbs, rng)
		"skeleton":
			_build_biped_torso_skeleton(root, base, palette, limbs, rng)
		"zombie":
			_build_biped_torso_zombie(root, base, palette, limbs, rng)
		"plant_humanoid":
			_build_biped_torso_plant(root, base, palette, limbs, rng)
		"satyr_humanoid":
			_build_biped_torso_satyr(root, base, palette, limbs, rng)
		"golem_large":
			_build_biped_torso_golem(root, base, palette, limbs, rng)
		_:
			_build_biped_torso(root, base, palette, limbs, rng)

## VARIANT DISPATCH: pick quadruped body shape based on sub_template.
## Wolf gets lean elongated capsule, Bear gets stout box-barrel, Lizard gets
## flat wide body, Insect gets segmented chain, etc. THIS is what makes
## creatures actually look different in-game.
static func _build_quadruped_torso_variant(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, meta: Dictionary, rng: RandomNumberGenerator) -> void:
	var sub: String = String(meta.get("sub_template", "wolf_like"))
	match sub:
		"wolf_like":
			_build_quadruped_torso_wolf(root, base, palette, limbs, rng)
		"bear_like":
			_build_quadruped_torso_bear(root, base, palette, limbs, rng)
		"small_animal":
			_build_quadruped_torso_small(root, base, palette, limbs, rng)
		"small_quadruped":
			_build_quadruped_torso_hooved(root, base, palette, limbs, rng)
		"lizard_like":
			_build_quadruped_torso_lizard(root, base, palette, limbs, rng)
		"serpent_like":
			_build_quadruped_torso_serpent(root, base, palette, limbs, rng)
		"insect_like":
			_build_quadruped_torso_insect(root, base, palette, limbs, rng)
		_:
			_build_quadruped_torso(root, base, palette, limbs, rng)

## Humanoid torso — upright capsule sitting on top of the legs.
## width / height / depth come from the plan.base dict; clearance is
## leg_length so the torso's bottom rests on the ground if no legs, or on
## top of the legs if has_legs is true.
static func _build_biped_torso(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	# Radius from width (waist) — half of width.
	capsule.radius = _vec_axis(base, "width", 0.55) * 0.5
	# Height — the torso section, not the whole figure.
	capsule.height = _vec_axis(base, "height", 0.9)
	# Capsule's height includes the rounded caps, so the "cylindrical body"
	# portion is capsule.height - 2*radius. That's OK — total visible
	# height is still capsule.height.
	mi.mesh = capsule
	# Centered between legs and head.
	mi.position = _body_center(base, limbs)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Quadruped torso — a barrel sitting on top of 4 legs. Long axis (depth)
## aligned along the Z direction; rotation tips the capsule from its default
## Y orientation to lie along Z (head-to-tail).
static func _build_quadruped_torso(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	# Radius from body "thickness" — half of (width+height)/2.
	var thickness: float = (_vec_axis(base, "width", 0.7) + _vec_axis(base, "height", 0.55)) * 0.5
	capsule.radius = thickness * 0.5
	capsule.height = _vec_axis(base, "depth", 1.1)
	mi.mesh = capsule
	# Tip the capsule from vertical Y-axis to lie along Z (front-back).
	mi.rotation.x = PI * 0.5
	# Sit on top of legs (or on ground if legless).
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius, 0)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Amorphous blob — a flattened sphere resting on the ground. No legs.
static func _build_blob_body(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _vec_axis(base, "width", 0.75) * 0.5
	sphere.height = _vec_axis(base, "height", 0.45)
	mi.mesh = sphere
	mi.scale = Vector3(1.2, 0.7, 1.2)
	# Bottom flush with ground.
	mi.position = Vector3(0, sphere.height * 0.5 * 0.7 + _ground_clearance(limbs), 0)
	var mat := _make_primary_material(palette)
	mat.metallic = 0.0
	mat.roughness = 0.2  # Glossy for ooze
	mi.material_override = mat
	root.add_child(mi)

# ============================================================================
# SUB-TEMPLATE-AWARE BIPED VARIANTS — visually distinct torso shapes
# ============================================================================

## Brute (Bugbear, Orc War Chief, Ogre, winged_huge): broad shoulders, thick
## barrel torso. Wider X, slightly compressed Y vs the standard humanoid.
static func _build_biped_torso_brute(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.65) * 0.6   # wider chest
	capsule.height = _vec_axis(base, "height", 1.0) * 0.95
	mi.mesh = capsule
	mi.position = _body_center(base, limbs)
	mi.scale = Vector3(1.15, 0.95, 1.0)                       # squish vertical, widen X
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Slim caster (Mage, Pixie, Drow Mage): tall narrow torso. Compressed X,
## stretched Y. Reads as wiry / spell-touched.
static func _build_biped_torso_slim(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.40) * 0.40   # narrower
	capsule.height = _vec_axis(base, "height", 1.0) * 1.10
	mi.mesh = capsule
	mi.position = _body_center(base, limbs)
	mi.scale = Vector3(0.85, 1.05, 0.9)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Small humanoid (Goblin, Kobold, Sprite): same proportions as biped but
## the species-level scale already shrinks it. Use a pear shape — wider at
## hips, narrower at shoulders — for child-like / impish silhouette.
static func _build_biped_torso_small(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.50) * 0.55
	capsule.height = _vec_axis(base, "height", 0.85) * 0.85
	mi.mesh = capsule
	mi.position = _body_center(base, limbs)
	mi.scale = Vector3(1.0, 0.85, 1.10)                       # squat
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Dinosaur biped (T-Rex, Velociraptor): forward-leaning torso, lower stance.
## Uses scale to flatten the Y axis and stretch Z (front-back) — silhouette
## is horizontal-leaning, not vertical-standing.
static func _build_biped_torso_dinosaur(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.70) * 0.50
	capsule.height = _vec_axis(base, "height", 1.0) * 1.20
	mi.mesh = capsule
	# Forward lean — rotate slightly + offset z so torso tilts.
	mi.position = _body_center(base, limbs)
	mi.position.z += _vec_axis(base, "depth", 0.7) * 0.15
	mi.rotation.x = -PI * 0.10                                 # slight forward tip
	mi.scale = Vector3(0.95, 1.0, 1.35)                        # elongated front-back
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Bird biped (Eagle, Hawk, Chicken): compact rounded body, no neck — head
## sits directly on the body.
static func _build_biped_torso_bird(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _vec_axis(base, "width", 0.40) * 0.55
	sphere.height = _vec_axis(base, "height", 0.55) * 1.10
	mi.mesh = sphere
	mi.position = _body_center(base, limbs)
	mi.scale = Vector3(1.0, 1.15, 1.20)                        # egg shape
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Elemental humanoid: tapered flame/water silhouette. Wider at base,
## narrower at top — like a candle flame.
static func _build_biped_torso_elemental(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = _vec_axis(base, "width", 0.55) * 0.55
	cyl.top_radius = cyl.bottom_radius * 0.35                  # tapered
	cyl.height = _vec_axis(base, "height", 1.0) * 1.10
	mi.mesh = cyl
	mi.position = _body_center(base, limbs)
	var mat := _make_primary_material(palette)
	mat.emission_enabled = true
	mat.emission = palette.get("primary", Color(1.0, 0.5, 0.2))
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	root.add_child(mi)

## Skeleton: stick-thin capsule torso, exposed-bone look with a paler tint.
static func _build_biped_torso_skeleton(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.40) * 0.32   # very narrow
	capsule.height = _vec_axis(base, "height", 0.9) * 1.05
	mi.mesh = capsule
	mi.position = _body_center(base, limbs)
	mi.scale = Vector3(0.75, 1.0, 0.80)                        # gaunt
	var mat := _make_primary_material(palette)
	mat.roughness = 0.85
	mi.material_override = mat
	root.add_child(mi)

## Zombie: bloated lumpy torso. Wider Z than X.
static func _build_biped_torso_zombie(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.55) * 0.55
	capsule.height = _vec_axis(base, "height", 0.95) * 0.95
	mi.mesh = capsule
	mi.position = _body_center(base, limbs)
	mi.scale = Vector3(1.10, 0.95, 1.30)                       # bloated belly
	var mat := _make_primary_material(palette)
	mat.roughness = 0.9
	mi.material_override = mat
	root.add_child(mi)

## Plant humanoid (Vine Blight, Dryad-like): segmented gnarled trunk torso.
## Stacked cylinder sections for a knotted look.
static func _build_biped_torso_plant(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var h: float = _vec_axis(base, "height", 0.95)
	var w: float = _vec_axis(base, "width", 0.50)
	# Three stacked sections, slightly different radii.
	var sections: int = 3
	for i in range(sections):
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var r: float = w * (0.55 - float(i) * 0.08)
		cyl.bottom_radius = r
		cyl.top_radius = r * 0.92
		cyl.height = (h / sections) * 0.9
		mi.mesh = cyl
		mi.position = Vector3(0, clearance + cyl.height * 0.5 + i * cyl.height * 0.95, 0)
		mi.material_override = _make_primary_material(palette)
		root.add_child(mi)

## Satyr biped: human torso (top half) + goat legs are handled by limbs, but
## the torso itself is a slim humanoid shape.
static func _build_biped_torso_satyr(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, rng: RandomNumberGenerator) -> void:
	_build_biped_torso_slim(root, base, palette, limbs, rng)

## Golem: massive blocky torso. Uses BoxMesh instead of capsule for cubic look.
static func _build_biped_torso_golem(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(
		_vec_axis(base, "width", 0.70) * 1.20,
		_vec_axis(base, "height", 1.0) * 0.85,
		_vec_axis(base, "depth", 0.45) * 1.15,
	)
	mi.mesh = box
	mi.position = _body_center(base, limbs)
	var mat := _make_primary_material(palette)
	mat.metallic = 0.4
	mat.roughness = 0.5
	mi.material_override = mat
	root.add_child(mi)

# ============================================================================
# SUB-TEMPLATE-AWARE QUADRUPED VARIANTS — Wolf vs Bear vs Lizard at last
# ============================================================================

## Wolf-like: lean elongated capsule, slight rear taper. Long body, narrow.
static func _build_quadruped_torso_wolf(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	var thickness: float = (_vec_axis(base, "width", 0.60) + _vec_axis(base, "height", 0.45)) * 0.45
	capsule.radius = thickness * 0.5
	capsule.height = _vec_axis(base, "depth", 1.30)
	mi.mesh = capsule
	mi.rotation.x = PI * 0.5
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius, 0)
	mi.scale = Vector3(0.95, 0.90, 1.05)                       # slim, slight rear taper via scale
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Bear-like: stout barrel body. Box-with-rounded-corners proxy via wide capsule.
static func _build_quadruped_torso_bear(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	var thickness: float = (_vec_axis(base, "width", 0.95) + _vec_axis(base, "height", 0.70)) * 0.55
	capsule.radius = thickness * 0.55
	capsule.height = _vec_axis(base, "depth", 1.20)
	mi.mesh = capsule
	mi.rotation.x = PI * 0.5
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius * 0.85, 0)
	mi.scale = Vector3(1.20, 1.15, 1.0)                        # wide, tall, stocky
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Small animal: low body close to the ground, tiny.
static func _build_quadruped_torso_small(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	var thickness: float = (_vec_axis(base, "width", 0.32) + _vec_axis(base, "height", 0.25)) * 0.5
	capsule.radius = thickness * 0.5
	capsule.height = _vec_axis(base, "depth", 0.65)
	mi.mesh = capsule
	mi.rotation.x = PI * 0.5
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius * 0.7, 0)
	mi.scale = Vector3(0.9, 0.75, 1.0)                         # low slung
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Hooved quadruped (Goat, Sheep, Deer): slim mid-size, more vertical posture.
static func _build_quadruped_torso_hooved(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	var thickness: float = (_vec_axis(base, "width", 0.48) + _vec_axis(base, "height", 0.40)) * 0.5
	capsule.radius = thickness * 0.5
	capsule.height = _vec_axis(base, "depth", 0.92)
	mi.mesh = capsule
	mi.rotation.x = PI * 0.5
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius * 1.0, 0)
	mi.scale = Vector3(0.85, 1.05, 1.0)                        # narrow, tall
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Lizard-like: VERY flat low-slung body. Y-axis squished hard.
static func _build_quadruped_torso_lizard(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	var thickness: float = (_vec_axis(base, "width", 0.75) + _vec_axis(base, "height", 0.40)) * 0.55
	capsule.radius = thickness * 0.5
	capsule.height = _vec_axis(base, "depth", 1.65)
	mi.mesh = capsule
	mi.rotation.x = PI * 0.5
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius * 0.55, 0)
	mi.scale = Vector3(1.25, 0.50, 1.10)                       # WIDE, FLAT, slightly elongated
	var mat := _make_primary_material(palette)
	mat.roughness = 0.85                                        # scaly finish hint
	mi.material_override = mat
	root.add_child(mi)

## Serpent: very long thin tube. No rotation issues since it lies horizontal.
static func _build_quadruped_torso_serpent(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _vec_axis(base, "width", 0.30) * 0.5
	capsule.height = _vec_axis(base, "depth", 2.10)
	mi.mesh = capsule
	mi.rotation.x = PI * 0.5
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(0, clearance + capsule.radius * 0.75, 0)
	mi.scale = Vector3(0.85, 0.65, 1.0)                        # very thin, low
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Insect: SEGMENTED — multiple spheres in a chain along the body's z axis.
## Gives the unmistakable insectoid silhouette no single capsule can match.
static func _build_quadruped_torso_insect(root: Node3D, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var thickness: float = (_vec_axis(base, "width", 0.55) + _vec_axis(base, "height", 0.35)) * 0.5
	var seg_radius: float = thickness * 0.4
	var d: float = _vec_axis(base, "depth", 0.85)
	var segments: int = 4
	for i in range(segments):
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		# Front and back segments are smaller (head and abdomen tip).
		var size_factor: float = 1.0
		if i == 0:
			size_factor = 0.65          # head
		elif i == segments - 1:
			size_factor = 1.15          # abdomen
		sphere.radius = seg_radius * size_factor
		sphere.height = sphere.radius * 2.0
		mi.mesh = sphere
		var t: float = float(i) / float(segments - 1)
		mi.position = Vector3(
			0,
			clearance + seg_radius * 0.95,
			lerpf(d * 0.45, -d * 0.45, t),
		)
		var mat := _make_primary_material(palette)
		mat.metallic = 0.15                                       # chitinous sheen
		mat.roughness = 0.55
		mi.material_override = mat
		root.add_child(mi)

## Cylinder body — used by plants. Trunk rises from the ground; no legs.
static func _build_cylinder_body(root: Node3D, base: Dictionary, palette: Dictionary, _limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = _vec_axis(base, "width", 0.5) * 0.5
	cyl.bottom_radius = cyl.top_radius * 1.15  # Slight taper (plants are wider at base).
	cyl.height = _vec_axis(base, "height", 0.85)
	mi.mesh = cyl
	# Trunk sits on the ground.
	mi.position.y = cyl.height * 0.5
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

# ============================================================================
# Top builders — STUBS
# ============================================================================

## Dome top — used by mushrooms (cap on stem) and by generic "rounded top"
## creatures. Sits at the top of the body's height range.
static func _build_top_dome(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _vec_axis(base, "width", 0.5) * 0.5 * float(top.get("size_factor", 1.0))
	sphere.height = float(top.get("height", 0.3))
	mi.mesh = sphere
	var clearance: float = _ground_clearance(limbs)
	mi.position.y = clearance + _vec_axis(base, "height", 0.5) + sphere.height * 0.5
	mi.material_override = _make_secondary_material(palette)
	root.add_child(mi)

## Flat lid — chest/box style. Thin disc on top.
static func _build_top_flat_lid(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = _vec_axis(base, "width", 0.5) * 0.5 * float(top.get("size_factor", 1.0))
	cyl.bottom_radius = cyl.top_radius
	cyl.height = float(top.get("height", 0.08))
	mi.mesh = cyl
	var clearance: float = _ground_clearance(limbs)
	mi.position.y = clearance + _vec_axis(base, "height", 0.5) + cyl.height * 0.5
	mi.material_override = _make_secondary_material(palette)
	root.add_child(mi)

## Mushroom cap — wider dome over a narrow stem.
static func _build_top_cap_dome(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, rng: RandomNumberGenerator) -> void:
	_build_top_dome(root, top, base, palette, limbs, rng)

## Humanoid head — sphere sitting on top of biped torso.
static func _build_top_head_humanoid(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	# Head radius ~ 1/3 of body width for humanoid proportions.
	sphere.radius = _vec_axis(base, "width", 0.55) * 0.35 * float(top.get("size_factor", 1.0))
	sphere.height = sphere.radius * 2.0
	mi.mesh = sphere
	var clearance: float = _ground_clearance(limbs)
	var torso_top: float = clearance + _vec_axis(base, "height", 0.9)
	# Head center sits one radius above torso top + small neck gap.
	mi.position.y = torso_top + sphere.radius * 1.05
	mi.material_override = _make_secondary_material(palette)
	root.add_child(mi)

## Beast head — elongated muzzle protruding from the front of a quadruped body.
## Critical: positioned at the FRONT (+Z) of the barrel torso, not above it.
static func _build_top_head_beast(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	# Head thickness = ~half body thickness (so the head is smaller than torso).
	var body_thickness: float = (_vec_axis(base, "width", 0.7) + _vec_axis(base, "height", 0.55)) * 0.5
	capsule.radius = body_thickness * 0.35 * float(top.get("size_factor", 1.0))
	capsule.height = capsule.radius * 2.6
	mi.mesh = capsule
	# Tip horizontally so the muzzle points forward.
	mi.rotation.x = PI * 0.5
	# Anchor: at the body's front edge (depth*0.5), at the body's vertical
	# center (clearance + body_thickness/2). Head extends another half-length
	# beyond that.
	var depth: float = _vec_axis(base, "depth", 1.1)
	var clearance: float = _ground_clearance(limbs)
	mi.position = Vector3(
		0,
		clearance + body_thickness * 0.55,
		depth * 0.5 + capsule.height * 0.35
	)
	mi.material_override = _make_secondary_material(palette)
	root.add_child(mi)

# ============================================================================
# SUB-TEMPLATE-AWARE HEAD VARIANTS — pointed muzzle vs round vs wedge vs etc
# ============================================================================
##
## All variants anchor at the front of the quadruped body (or top of biped).
## They produce visually DIFFERENT silhouettes — long pointed muzzle for wolf,
## wide round face for bear, sharp horned wedge for dragon, narrow beak for
## bird, segmented for insect, etc.
##
## Position math mirrors _build_top_head_beast — front of body, vertically
## centered on the torso. Each variant just changes the MESH SHAPE.

## Anchor helpers — these MUST match _head_anchor() in the face section below
## so that eyes/mouth from build_face land ON the head meshes built here.
## Both functions delegate to the same _head_anchor lookup to stay in sync.
static func _head_anchor_quadruped(base: Dictionary, limbs: Dictionary) -> Vector3:
	# Use the same anchor build_face uses (assume head_beast top type).
	return _head_anchor(base, {"type": "head_beast", "size_factor": 1.0}, limbs)

static func _head_anchor_biped(base: Dictionary, limbs: Dictionary) -> Vector3:
	return _head_anchor(base, {"type": "head_humanoid", "size_factor": 1.0}, limbs)

## Wolf: long pointed muzzle (cone-tipped capsule).
static func _build_top_head_wolf(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 0.85
	# Skull / cranium sphere.
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 1.8
	skull.mesh = s
	skull.position = anchor + Vector3(0, head_r * 0.4, head_r * 0.2)
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)
	# Pointed muzzle (cone) extending forward.
	var muzzle := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = head_r * 0.75
	c.top_radius = head_r * 0.25                                # taper to a point
	c.height = head_r * 1.8
	muzzle.mesh = c
	muzzle.rotation.x = PI * 0.5
	muzzle.position = anchor + Vector3(0, head_r * 0.25, head_r * 1.3)
	muzzle.material_override = _make_secondary_material(palette)
	root.add_child(muzzle)
	# Ear bumps (two small cones).
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ec := CylinderMesh.new()
		ec.bottom_radius = head_r * 0.18
		ec.top_radius = 0.0
		ec.height = head_r * 0.45
		ear.mesh = ec
		ear.position = anchor + Vector3(side * head_r * 0.55, head_r * 1.1, head_r * 0.1)
		ear.material_override = _make_secondary_material(palette)
		root.add_child(ear)

## Bear: round wide face, no extended muzzle, small round ears.
static func _build_top_head_bear(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.15
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 1.95
	skull.mesh = s
	skull.position = anchor + Vector3(0, head_r * 0.45, head_r * 0.7)
	skull.scale = Vector3(1.10, 0.95, 1.05)                       # wide
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)
	# Short stubby snout.
	var snout := MeshInstance3D.new()
	var ssn := SphereMesh.new()
	ssn.radius = head_r * 0.55
	ssn.height = head_r * 0.9
	snout.mesh = ssn
	snout.position = anchor + Vector3(0, head_r * 0.20, head_r * 1.35)
	snout.material_override = _make_secondary_material(palette)
	root.add_child(snout)
	# Round ears on top.
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = head_r * 0.28
		es.height = head_r * 0.5
		ear.mesh = es
		ear.position = anchor + Vector3(side * head_r * 0.55, head_r * 1.15, head_r * 0.5)
		ear.material_override = _make_secondary_material(palette)
		root.add_child(ear)

## Small animal: simple round head + perky pointed ears.
static func _build_top_head_small(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.10
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 1.9
	skull.mesh = s
	skull.position = anchor + Vector3(0, head_r * 0.6, head_r * 0.5)
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)
	# Pointed ears.
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ec := CylinderMesh.new()
		ec.bottom_radius = head_r * 0.22
		ec.top_radius = 0.0
		ec.height = head_r * 0.7
		ear.mesh = ec
		ear.position = anchor + Vector3(side * head_r * 0.45, head_r * 1.25, head_r * 0.35)
		ear.material_override = _make_secondary_material(palette)
		root.add_child(ear)

## Hooved (goat/sheep/deer): long narrow face with horns suggested via top.
static func _build_top_head_hooved(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 0.90
	var head := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = head_r * 0.6
	c.height = head_r * 2.2
	head.mesh = c
	head.rotation.x = PI * 0.5
	head.position = anchor + Vector3(0, head_r * 0.55, head_r * 0.95)
	head.material_override = _make_secondary_material(palette)
	root.add_child(head)
	# Pointy ears stick out sideways.
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ec := CylinderMesh.new()
		ec.bottom_radius = head_r * 0.18
		ec.top_radius = 0.0
		ec.height = head_r * 0.55
		ear.mesh = ec
		ear.position = anchor + Vector3(side * head_r * 0.55, head_r * 0.95, head_r * 0.4)
		ear.rotation.z = side * -PI * 0.4
		ear.material_override = _make_secondary_material(palette)
		root.add_child(ear)

## Dinosaur: massive elongated head, jaw prominent.
static func _build_top_head_dinosaur(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	# Position relative to biped torso top, not quadruped front.
	var anchor: Vector3 = _head_anchor_biped(base, limbs)
	anchor.z = _vec_axis(base, "depth", 0.7) * 0.45              # head leans forward
	var head_r: float = _estimate_head_radius(base, top) * 1.30
	var skull := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = head_r * 0.75
	c.height = head_r * 2.8                                       # very long
	skull.mesh = c
	skull.rotation.x = PI * 0.5
	skull.position = anchor + Vector3(0, head_r * 0.5, head_r * 0.6)
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)
	# Lower jaw — second capsule slightly offset down/forward.
	var jaw := MeshInstance3D.new()
	var jc := CapsuleMesh.new()
	jc.radius = head_r * 0.45
	jc.height = head_r * 1.9
	jaw.mesh = jc
	jaw.rotation.x = PI * 0.5
	jaw.position = anchor + Vector3(0, head_r * 0.05, head_r * 1.0)
	jaw.material_override = _make_primary_material(palette)
	root.add_child(jaw)

## Lizard: flat head, wide jaw.
static func _build_top_head_lizard(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.10
	var skull := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = head_r * 0.65
	c.height = head_r * 2.1
	skull.mesh = c
	skull.rotation.x = PI * 0.5
	skull.position = anchor + Vector3(0, head_r * 0.35, head_r * 0.95)
	skull.scale = Vector3(1.30, 0.60, 1.10)                       # wide, FLAT
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)

## Serpent: small narrow head — barely-distinguished from neck.
static func _build_top_head_serpent(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 0.85
	var skull := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = head_r * 0.55
	c.height = head_r * 1.6
	skull.mesh = c
	skull.rotation.x = PI * 0.5
	skull.position = anchor + Vector3(0, head_r * 0.25, head_r * 0.95)
	skull.scale = Vector3(0.95, 0.85, 1.10)
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)

## Bird: small head with a hooked beak.
static func _build_top_head_bird(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	# Anchored on top of biped torso (bird) or front of quadruped (if used there).
	var anchor: Vector3
	if String(base.get("type", "")) == "biped_torso":
		anchor = _head_anchor_biped(base, limbs)
	else:
		anchor = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 0.85
	# Round head.
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 1.85
	skull.mesh = s
	skull.position = anchor + Vector3(0, head_r * 0.5, 0)
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)
	# Beak — short cone forward.
	var beak := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.bottom_radius = head_r * 0.32
	bc.top_radius = 0.0
	bc.height = head_r * 0.85
	beak.mesh = bc
	beak.rotation.x = PI * 0.5
	beak.position = anchor + Vector3(0, head_r * 0.4, head_r * 0.95)
	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = palette.get("accent", Color(0.92, 0.65, 0.18))
	beak.material_override = beak_mat
	root.add_child(beak)

## Insect: small segmented head with antennae.
static func _build_top_head_insect(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	# Insect torso already has a "head segment" at the front; this adds detail.
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 0.75
	# Antennae.
	for side in [-1, 1]:
		var ant := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.bottom_radius = head_r * 0.06
		c.top_radius = head_r * 0.03
		c.height = head_r * 1.6
		ant.mesh = c
		ant.position = anchor + Vector3(side * head_r * 0.25, head_r * 1.2, head_r * 0.6)
		ant.rotation.z = side * -PI * 0.18
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("detail", Color(0.10, 0.08, 0.06))
		ant.material_override = mat
		root.add_child(ant)

## Dragon: angular wedge head with brow ridges.
static func _build_top_head_dragon(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_quadruped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.20
	# Skull / upper wedge.
	var skull := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = head_r * 0.70
	c.height = head_r * 2.4
	skull.mesh = c
	skull.rotation.x = PI * 0.5
	skull.position = anchor + Vector3(0, head_r * 0.6, head_r * 0.9)
	skull.scale = Vector3(1.15, 0.85, 1.10)                       # wedge
	skull.material_override = _make_secondary_material(palette)
	root.add_child(skull)
	# Brow ridges — two small wedges on top.
	for side in [-1, 1]:
		var brow := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.bottom_radius = head_r * 0.25
		bc.top_radius = head_r * 0.05
		bc.height = head_r * 0.6
		brow.mesh = bc
		brow.position = anchor + Vector3(side * head_r * 0.35, head_r * 1.15, head_r * 0.45)
		brow.rotation.x = -PI * 0.30
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("detail", Color(0.20, 0.10, 0.05))
		brow.material_override = mat
		root.add_child(brow)

# ============================================================================
# Humanoid head variants
# ============================================================================

## Skeleton: hollow-eyed skull, narrow.
static func _build_top_head_skeleton(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_biped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 0.85
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 2.1
	skull.mesh = s
	skull.position = anchor + Vector3(0, head_r * 1.0, 0)
	skull.scale = Vector3(0.85, 1.10, 0.90)                        # gaunt
	var mat := _make_secondary_material(palette)
	mat.roughness = 0.85
	skull.material_override = mat
	root.add_child(skull)
	# Jaw drop — small box hanging below.
	var jaw := MeshInstance3D.new()
	var jb := BoxMesh.new()
	jb.size = Vector3(head_r * 0.95, head_r * 0.3, head_r * 0.55)
	jaw.mesh = jb
	jaw.position = anchor + Vector3(0, head_r * 0.45, head_r * 0.15)
	jaw.material_override = mat
	root.add_child(jaw)

## Zombie: lumpy, swollen, slightly tilted head.
static func _build_top_head_zombie(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_biped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.10
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 2.0
	skull.mesh = s
	skull.position = anchor + Vector3(0, head_r * 1.0, 0)
	skull.scale = Vector3(1.1, 0.95, 1.05)                          # bloated
	skull.rotation.z = -0.12                                        # tilted
	var mat := _make_secondary_material(palette)
	mat.roughness = 0.92
	skull.material_override = mat
	root.add_child(skull)

## Hooded caster (Mage, Lich): elongated hood with glowing eye-slit.
static func _build_top_head_hooded(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_biped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.20
	# Hood cone.
	var hood := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = head_r * 1.15
	c.top_radius = head_r * 0.35
	c.height = head_r * 1.9
	hood.mesh = c
	hood.position = anchor + Vector3(0, head_r * 0.95, 0)
	var hood_mat := StandardMaterial3D.new()
	hood_mat.albedo_color = palette.get("secondary", Color(0.18, 0.08, 0.30))
	hood.material_override = hood_mat
	root.add_child(hood)
	# Face shadow sphere inside hood (so eyes pop on a dark backdrop).
	var face := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = head_r * 0.65
	fs.height = head_r * 1.25
	face.mesh = fs
	face.position = anchor + Vector3(0, head_r * 0.95, head_r * 0.05)
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.08, 0.06, 0.08)
	face.material_override = face_mat
	root.add_child(face)

## Elemental: head is a wisp / cloud — emissive sphere.
static func _build_top_head_elemental(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_biped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.10
	var head := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = head_r
	s.height = head_r * 2.0
	head.mesh = s
	head.position = anchor + Vector3(0, head_r * 1.0, 0)
	var mat := _make_secondary_material(palette)
	mat.emission_enabled = true
	mat.emission = palette.get("primary", Color(1.0, 0.5, 0.2))
	mat.emission_energy_multiplier = 0.6
	head.material_override = mat
	root.add_child(head)

## Golem: blocky cubic head matching the cube body.
static func _build_top_head_golem(root: Node3D, top: Dictionary, base: Dictionary, palette: Dictionary, limbs: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor_biped(base, limbs)
	var head_r: float = _estimate_head_radius(base, top) * 1.10
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(head_r * 1.6, head_r * 1.7, head_r * 1.4)
	head.mesh = box
	head.position = anchor + Vector3(0, head_r * 1.05, 0)
	var mat := _make_secondary_material(palette)
	mat.metallic = 0.4
	mat.roughness = 0.5
	head.material_override = mat
	root.add_child(head)

# ============================================================================
# Face builders — STUBS
# ============================================================================

## Place eyes on the HEAD. The head's center is at `head_anchor`. Eyes are
## distributed around the front-facing arc of the head, offset forward so
## they bulge out past the head surface.
##
## Head "radius" estimate: half of body width for humanoid, ~1/3 body width
## for beast. We don't have the actual mesh radius here, so derive from body.
static func _build_eyes(root: Node3D, face: Dictionary, base: Dictionary, top: Dictionary, _limbs: Dictionary, palette: Dictionary, head_anchor: Vector3, _rng: RandomNumberGenerator) -> void:
	var count: int = int(face.get("eye_count", 2))
	if count <= 0:
		return
	var radius: float = float(face.get("eye_radius", 0.045))
	var glow: bool = bool(face.get("eye_glow", false))
	var eye_color: Color = palette.get("eye", palette.get("eye_color", Color(0.9, 0.2, 0.1)))
	# Head radius — derive from body type. Used to position eyes on the head
	# surface, not floating outside it.
	var head_radius: float = _estimate_head_radius(base, top)
	# Spread = how wide apart the eyes are. Override from face.eye_spread when present.
	var spread: float = float(face.get("eye_spread", head_radius * 0.6))
	for i in range(count):
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		mi.mesh = sphere
		# Distribute eyes along the head's front-facing arc.
		# For 1 eye: dead center.
		# For 2: -spread / +spread on X.
		# For 3+: distributed across a 90° front arc.
		var angle: float = 0.0
		if count == 1:
			angle = 0.0
		elif count == 2:
			angle = -spread if i == 0 else spread
			# Treat angle as x-offset directly (degenerate case).
			mi.position = head_anchor + Vector3(angle, head_radius * 0.15, head_radius * 0.9)
			_apply_eye_material(mi, eye_color, glow)
			root.add_child(mi)
			continue
		else:
			angle = -PI * 0.35 + (PI * 0.7) * (float(i) / float(count - 1))
		# Place on the front surface of the head.
		var local_x: float = sin(angle) * head_radius * 0.85
		var local_y: float = head_radius * 0.15
		var local_z: float = cos(angle) * head_radius * 0.9
		mi.position = head_anchor + Vector3(local_x, local_y, local_z)
		_apply_eye_material(mi, eye_color, glow)
		root.add_child(mi)

## Estimate the head's radius based on body type + top type. Lets eye/mouth
## builders position features on the head surface even though we don't keep
## a reference to the head mesh itself.
static func _estimate_head_radius(base: Dictionary, top: Dictionary) -> float:
	var top_type: String = String(top.get("type", "none"))
	var w: float = _vec_axis(base, "width", 0.5)
	var size_factor: float = float(top.get("size_factor", 1.0))
	match top_type:
		"head_humanoid":
			return w * 0.35 * size_factor
		"head_beast":
			var thickness: float = (w + _vec_axis(base, "height", 0.55)) * 0.5
			return thickness * 0.35 * size_factor
		"dome", "cap_dome":
			return w * 0.5 * size_factor
		"flat_lid":
			return w * 0.5 * size_factor * 0.7
		_:
			return w * 0.3

static func _apply_eye_material(mi: MeshInstance3D, eye_color: Color, glow: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = eye_color
	if glow:
		mat.emission_enabled = true
		mat.emission = eye_color
		mat.emission_energy_multiplier = 1.6
	mi.material_override = mat

## Single mouth — a small horizontal slit on the front of the head.
static func _build_mouth_single(root: Node3D, _face: Dictionary, base: Dictionary, palette: Dictionary, head_anchor: Vector3, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var head_r: float = _vec_axis(base, "width", 0.5) * 0.3
	var cube := BoxMesh.new()
	cube.size = Vector3(head_r * 0.6, head_r * 0.2, 0.02)
	mi.mesh = cube
	# Below the eyes, on the front face of the head.
	mi.position = head_anchor + Vector3(0, -head_r * 0.45, head_r * 0.95)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("detail", Color(0.1, 0.05, 0.05))
	mi.material_override = mat
	root.add_child(mi)

## Teeth ring — used by mimic specialist. Stub here (universal renderer
## doesn't need full teeth-ring detail — mimic uses ProceduralMimicChest).
static func _build_mouth_teeth_ring(_root: Node3D, _face: Dictionary, _base: Dictionary, _palette: Dictionary, _head_anchor: Vector3, _rng: RandomNumberGenerator) -> void:
	pass

## Horizontal maw — wide gaping mouth on the front of the head, used by
## beasts (canine bite shape) and humanoid jaw lines.
static func _build_mouth_maw_horizontal(root: Node3D, _face: Dictionary, base: Dictionary, palette: Dictionary, head_anchor: Vector3, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var head_r: float = _vec_axis(base, "width", 0.5) * 0.3
	var cube := BoxMesh.new()
	cube.size = Vector3(head_r * 1.1, head_r * 0.35, 0.02)
	mi.mesh = cube
	mi.position = head_anchor + Vector3(0, -head_r * 0.35, head_r * 0.95)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("detail", Color(0.05, 0.02, 0.02))
	mi.material_override = mat
	root.add_child(mi)

## Vertical maw — used by ooze/aberration types. A tall slit on the head.
static func _build_mouth_maw_vertical(root: Node3D, _face: Dictionary, base: Dictionary, palette: Dictionary, head_anchor: Vector3, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var head_r: float = _vec_axis(base, "width", 0.5) * 0.3
	var cube := BoxMesh.new()
	cube.size = Vector3(head_r * 0.25, head_r * 1.1, 0.02)
	mi.mesh = cube
	mi.position = head_anchor + Vector3(0, 0, head_r * 0.95)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("detail", Color(0.05, 0.02, 0.02))
	mi.material_override = mat
	root.add_child(mi)

# ============================================================================
# Limb builders — STUBS
# ============================================================================

## Arms — hang DOWN from the shoulders, not splayed at 45°. Used by bipeds
## (count=2) and aberrations (count=4-6). For bipeds, arms are at the
## torso's sides at shoulder height. For more-armed creatures, additional
## arms are stacked vertically below the first pair.
##
## Limbs hang vertically by default; reach posing can come later.
static func _build_arms(root: Node3D, limbs: Dictionary, base: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var count: int = int(limbs.get("arm_count", 2))
	if count <= 0:
		return
	var length: float = float(limbs.get("arm_length", 0.40))
	var radius: float = float(limbs.get("arm_radius", 0.05))
	var clearance: float = _ground_clearance(limbs)
	# Shoulder y = top of torso minus a small inset (so arm attaches just
	# below the shoulder cap of the capsule).
	var shoulder_y: float = clearance + _vec_axis(base, "height", 0.9) * 0.85
	var shoulder_x: float = _vec_axis(base, "width", 0.55) * 0.5 + radius * 0.6
	for i in range(count):
		var side: float = -1.0 if (i % 2 == 0) else 1.0
		var pair: int = i / 2  # 0 = primary pair, 1 = secondary pair, etc.
		var mi := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = radius
		capsule.height = length
		mi.mesh = capsule
		# Arm CENTER is shoulder minus half the arm length (since the capsule
		# extends from its center along its axis). Hanging straight down.
		mi.position = Vector3(
			side * shoulder_x,
			shoulder_y - length * 0.5 - pair * length * 0.55,
			0
		)
		# No rotation — capsule's default Y axis = vertical, which is what we want.
		mi.material_override = _make_primary_material(palette)
		root.add_child(mi)

## Legs — for 2-leg bipeds, two parallel legs spaced apart. For 4-leg
## quadrupeds, FOUR CORNERS (front-L, front-R, back-L, back-R). For 6+
## legs (insects, spiders), pairs distributed along the body length.
##
## All legs extend from the body bottom DOWN to y=0 (the ground).
static func _build_legs(root: Node3D, limbs: Dictionary, base: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var count: int = int(limbs.get("leg_count", 2))
	if count <= 0:
		return
	var length: float = float(limbs.get("leg_length", 0.35))
	var radius: float = float(limbs.get("leg_radius", 0.06))
	var width_spread: float = float(limbs.get("leg_spread", _vec_axis(base, "width", 0.55) * 0.4))
	var depth: float = _vec_axis(base, "depth", 1.0)
	# Build a list of (x, z) positions per leg.
	var positions: Array[Vector2] = _leg_positions(count, width_spread, depth)
	for p in positions:
		var mi := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = radius
		capsule.height = length
		mi.mesh = capsule
		# Leg center at y = length / 2, so the bottom touches y=0 and the
		# top reaches y=length (which equals ground clearance — feet on
		# floor, top of leg meets body bottom).
		mi.position = Vector3(p.x, length * 0.5, p.y)
		mi.material_override = _make_primary_material(palette)
		root.add_child(mi)

## Compute (x, z) positions for each leg based on count.
static func _leg_positions(count: int, width_spread: float, depth: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count == 1:
		out.append(Vector2(0, 0))
		return out
	if count == 2:
		# Biped — left/right at hip level, z=0.
		out.append(Vector2(-width_spread, 0))
		out.append(Vector2(+width_spread, 0))
		return out
	if count == 4:
		# Quadruped — front-left, front-right, back-left, back-right.
		# 35% inset from front/back of the body length so legs aren't at
		# the very ends (which would look like they're peeking out).
		var z_front: float = depth * 0.35
		var z_back: float = -depth * 0.35
		out.append(Vector2(-width_spread, z_front))
		out.append(Vector2(+width_spread, z_front))
		out.append(Vector2(-width_spread, z_back))
		out.append(Vector2(+width_spread, z_back))
		return out
	# 6+ legs — distribute as pairs along the body length.
	var pairs: int = count / 2
	for i in range(pairs):
		var t: float = float(i) / float(pairs - 1) if pairs > 1 else 0.5
		var z: float = lerpf(depth * 0.4, -depth * 0.4, t)
		out.append(Vector2(-width_spread, z))
		out.append(Vector2(+width_spread, z))
	# Odd extra leg (rare) at center back.
	if count % 2 == 1:
		out.append(Vector2(0, -depth * 0.4))
	return out

# ============================================================================
# Ornament builders — STUBS
# ============================================================================

## Mane — torus around the head/neck area. Sits at the head anchor's y level.
static func _build_ornament_mane(root: Node3D, _ornaments: Dictionary, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor(base, top, limbs)
	var head_r: float = _estimate_head_radius(base, top)
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = head_r * 1.05
	torus.outer_radius = head_r * 1.55
	mi.mesh = torus
	mi.position = anchor + Vector3(0, -head_r * 0.2, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("accent", palette.get("secondary", Color(0.7, 0.5, 0.3)))
	mi.material_override = mat
	root.add_child(mi)

## Halo — emissive torus floating above the head.
static func _build_ornament_halo(root: Node3D, _ornaments: Dictionary, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor(base, top, limbs)
	var head_r: float = _estimate_head_radius(base, top)
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = head_r * 1.0
	torus.outer_radius = head_r * 1.25
	mi.mesh = torus
	# Float above the head crown.
	mi.position = anchor + Vector3(0, head_r * 1.6, 0)
	var mat := StandardMaterial3D.new()
	var halo_color: Color = palette.get("accent", Color(1.0, 0.95, 0.6))
	mat.albedo_color = halo_color
	mat.emission_enabled = true
	mat.emission = halo_color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	root.add_child(mi)

## Wings — pair of side panels at the upper torso (just below the head). For
## both bipeds and quadrupeds, anchors at the shoulder line so they look
## attached to the back.
static func _build_ornament_wings(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var w: float = _vec_axis(base, "width", 0.55)
	var h: float = _vec_axis(base, "height", 0.9)
	var wing_y: float = clearance + h * 0.75
	var wing_z: float = -w * 0.15  # slightly behind the body
	for side in [-1, 1]:
		var mi := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(w * 1.4, h * 0.55, 0.04)
		mi.mesh = cube
		mi.position = Vector3(side * w * 0.65, wing_y, wing_z)
		mi.rotation.z = side * -PI * 0.18
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("secondary", Color(0.5, 0.5, 0.55))
		mi.material_override = mat
		root.add_child(mi)

## Horns — two narrowing cones rising from the top of the head, slightly
## angled outward. Positioned via head anchor.
static func _build_ornament_horns(root: Node3D, _ornaments: Dictionary, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor(base, top, limbs)
	var head_r: float = _estimate_head_radius(base, top)
	for side in [-1, 1]:
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.bottom_radius = head_r * 0.18
		cone.top_radius = 0.0
		cone.height = head_r * 1.4
		mi.mesh = cone
		# Anchor at top-side of the head; cone extends upward and outward.
		mi.position = anchor + Vector3(side * head_r * 0.45, head_r * 0.85 + cone.height * 0.4, head_r * 0.1)
		mi.rotation.z = side * -PI * 0.18
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("detail", Color(0.4, 0.3, 0.2))
		mi.material_override = mat
		root.add_child(mi)

## Tail — capsule extending out the back of the body.
static func _build_ornament_tail(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.06
	capsule.height = _vec_axis(base, "depth", 1.0) * 0.45
	mi.mesh = capsule
	mi.rotation.x = -PI * 0.5  # horizontal, pointing -Z
	var clearance: float = _ground_clearance(limbs)
	var body_y: float = clearance + _vec_axis(base, "height", 0.55) * 0.6
	var tail_z: float = -_vec_axis(base, "depth", 1.0) * 0.5 - capsule.height * 0.35
	mi.position = Vector3(0, body_y, tail_z)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Tentacles — 4 small downward limbs around the lower body. For aberrations.
static func _build_ornament_tentacles(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var spread: float = _vec_axis(base, "width", 0.55) * 0.4
	for i in range(4):
		var mi := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.04
		capsule.height = 0.35
		mi.mesh = capsule
		var angle: float = 2.0 * PI * float(i) / 4.0
		# Anchor at body middle; tentacle hangs down and slightly out.
		var body_y: float = clearance + _vec_axis(base, "height", 0.9) * 0.4
		mi.position = Vector3(cos(angle) * spread, body_y - capsule.height * 0.4, sin(angle) * spread)
		mi.rotation.x = -PI * 0.1  # slight outward droop
		mi.material_override = _make_primary_material(palette)
		root.add_child(mi)

## Bone protrusion — exposed bones / shoulder spurs.
static func _build_ornament_bone_protrusion(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var shoulder_y: float = clearance + _vec_axis(base, "height", 0.9) * 0.85
	var shoulder_x: float = _vec_axis(base, "width", 0.55) * 0.55
	for side in [-1, 1]:
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.bottom_radius = 0.04
		cone.top_radius = 0.0
		cone.height = 0.22
		mi.mesh = cone
		mi.position = Vector3(side * shoulder_x, shoulder_y, 0)
		mi.rotation.z = side * -PI * 0.35
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.92, 0.85)
		mi.material_override = mat
		root.add_child(mi)

## Tattered cloth — semi-transparent dark panel hanging from the torso.
static func _build_ornament_tattered_cloth(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var h: float = _vec_axis(base, "height", 0.9)
	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(_vec_axis(base, "width", 0.55) * 1.15, h * 0.65, 0.02)
	mi.mesh = cube
	mi.position.y = clearance + h * 0.4
	mi.position.z = _vec_axis(base, "depth", 0.4) * 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("detail", Color(0.25, 0.2, 0.15, 0.7))
	mat.flags_transparent = true
	mi.material_override = mat
	root.add_child(mi)

## Metallic chest plate.
static func _build_ornament_metallic_plate(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var h: float = _vec_axis(base, "height", 0.9)
	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(_vec_axis(base, "width", 0.55) * 0.75, h * 0.55, 0.04)
	mi.mesh = cube
	mi.position = Vector3(0, clearance + h * 0.55, _vec_axis(base, "depth", 0.4) * 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("accent", Color(0.6, 0.6, 0.65))
	mat.metallic = 0.8
	mat.roughness = 0.3
	mi.material_override = mat
	root.add_child(mi)

## Flowering accents — small bright spheres scattered around the body. For Fey + Plant.
static func _build_ornament_flowering_accents(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var h: float = _vec_axis(base, "height", 0.9)
	var w: float = _vec_axis(base, "width", 0.55)
	for _i in range(3 + rng.randi() % 3):
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.10
		mi.mesh = sphere
		var angle: float = rng.randf_range(0.0, 2.0 * PI)
		var r_pos: float = w * 0.5
		mi.position = Vector3(
			cos(angle) * r_pos,
			clearance + h * rng.randf_range(0.4, 0.95),
			sin(angle) * r_pos
		)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("accent", Color(0.95, 0.3, 0.6))
		mi.material_override = mat
		root.add_child(mi)

## Crystal growth — sharp glowing crystals jutting from the upper body.
static func _build_ornament_crystal_growth(root: Node3D, _ornaments: Dictionary, base: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var h: float = _vec_axis(base, "height", 0.9)
	var w: float = _vec_axis(base, "width", 0.55)
	for _i in range(2 + rng.randi() % 3):
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.bottom_radius = 0.05
		cone.top_radius = 0.0
		cone.height = rng.randf_range(0.12, 0.22)
		mi.mesh = cone
		var angle: float = rng.randf_range(0.0, 2.0 * PI)
		var r_pos: float = w * 0.45
		mi.position = Vector3(
			cos(angle) * r_pos,
			clearance + h * rng.randf_range(0.6, 0.9),
			sin(angle) * r_pos
		)
		mi.rotation.x = rng.randf_range(-0.3, 0.3)
		mi.rotation.z = rng.randf_range(-0.3, 0.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("accent", Color(0.5, 0.8, 1.0))
		mat.metallic = 0.4
		mat.roughness = 0.1
		mi.material_override = mat
		root.add_child(mi)

# ============================================================================
# Mutation builders — STUBS
# ============================================================================

## Third eye — extra glowing eye on the forehead. Placed via head anchor.
static func _build_mutation_third_eye(root: Node3D, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor(base, top, limbs)
	var head_r: float = _estimate_head_radius(base, top)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	mi.mesh = sphere
	# Forehead — above the eye line, on front of head.
	mi.position = anchor + Vector3(0, head_r * 0.55, head_r * 0.85)
	var mat := StandardMaterial3D.new()
	var color: Color = palette.get("eye", Color(0.95, 0.2, 0.1))
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	root.add_child(mi)

## Glowing veins — emissive ring around the body midsection.
static func _build_mutation_glowing_veins(root: Node3D, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = _vec_axis(base, "width", 0.55) * 0.55
	torus.outer_radius = torus.inner_radius + 0.025
	mi.mesh = torus
	var clearance: float = _ground_clearance(limbs)
	mi.position.y = clearance + _vec_axis(base, "height", 0.9) * 0.5
	mi.rotation.x = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("accent", Color(0.4, 0.95, 1.0))
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	root.add_child(mi)

## Stub tail — short tail protrusion at body rear.
static func _build_mutation_tail_stub(root: Node3D, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.045
	capsule.height = 0.18
	mi.mesh = capsule
	mi.rotation.x = -PI * 0.5
	mi.position = Vector3(
		0,
		clearance + _vec_axis(base, "height", 0.55) * 0.55,
		-_vec_axis(base, "depth", 0.6) * 0.5 - 0.05
	)
	mi.material_override = _make_primary_material(palette)
	root.add_child(mi)

## Spike ridge — row of spikes along the back/top.
static func _build_mutation_spike_ridge(root: Node3D, base: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var h: float = _vec_axis(base, "height", 0.55)
	var d: float = _vec_axis(base, "depth", 0.8)
	for i in range(5):
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.bottom_radius = 0.03
		cone.top_radius = 0.0
		cone.height = 0.13
		mi.mesh = cone
		var t: float = float(i) / 4.0
		# Spikes on top of the body, distributed front-to-back.
		mi.position = Vector3(0, clearance + h + cone.height * 0.4, lerpf(d * 0.4, -d * 0.4, t))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette.get("detail", Color(0.3, 0.2, 0.15))
		mi.material_override = mat
		root.add_child(mi)

## Living moss — tufts scattered on the body surface.
static func _build_mutation_living_moss(root: Node3D, base: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var _p: Dictionary = palette  # palette unused but kept for future moss-color override
	var clearance: float = _ground_clearance(limbs)
	for _i in range(4 + rng.randi() % 4):
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.03, 0.055)
		sphere.height = sphere.radius * 2.0
		mi.mesh = sphere
		var angle: float = rng.randf_range(0.0, 2.0 * PI)
		var r_pos: float = _vec_axis(base, "width", 0.55) * 0.5
		mi.position = Vector3(
			cos(angle) * r_pos,
			clearance + rng.randf_range(0.1, _vec_axis(base, "height", 0.9) * 0.85),
			sin(angle) * r_pos
		)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.55, 0.18)
		mi.material_override = mat
		root.add_child(mi)

## Chitin plate — armor plate on top of head.
static func _build_mutation_chitin_plate(root: Node3D, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor(base, top, limbs)
	var head_r: float = _estimate_head_radius(base, top)
	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(head_r * 1.4, 0.05, head_r * 1.4)
	mi.mesh = cube
	mi.position = anchor + Vector3(0, head_r * 0.85, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("detail", Color(0.2, 0.15, 0.1))
	mat.metallic = 0.3
	mat.roughness = 0.4
	mi.material_override = mat
	root.add_child(mi)

## Floating orb — small glowing sphere hovering above the head.
static func _build_mutation_floating_orb(root: Node3D, base: Dictionary, top: Dictionary, limbs: Dictionary, palette: Dictionary, _rng: RandomNumberGenerator) -> void:
	var anchor: Vector3 = _head_anchor(base, top, limbs)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	mi.mesh = sphere
	mi.position = anchor + Vector3(0, 0.5, 0)
	var mat := StandardMaterial3D.new()
	var color: Color = palette.get("accent", Color(0.6, 0.8, 1.0))
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	root.add_child(mi)

## Extra mouth — secondary mouth somewhere unexpected on the body.
static func _build_mutation_extra_mouth(root: Node3D, base: Dictionary, limbs: Dictionary, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var clearance: float = _ground_clearance(limbs)
	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.12, 0.05, 0.02)
	mi.mesh = cube
	# Random placement on the front of the body, between hip and shoulder.
	var angle: float = rng.randf_range(-PI * 0.4, PI * 0.4)
	var w: float = _vec_axis(base, "width", 0.55) * 0.5
	var d: float = _vec_axis(base, "depth", 0.4) * 0.5
	var h: float = _vec_axis(base, "height", 0.9)
	mi.position = Vector3(
		sin(angle) * w,
		clearance + rng.randf_range(h * 0.3, h * 0.7),
		cos(angle) * d
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("detail", Color(0.1, 0.05, 0.05))
	mi.material_override = mat
	root.add_child(mi)

# ============================================================================
# Helpers
# ============================================================================

## Read a dimension axis from a base dict with a fallback.
static func _vec_axis(base: Dictionary, axis: String, fallback: float) -> float:
	var v: Variant = base.get(axis, fallback)
	if v is float or v is int:
		return float(v)
	return fallback

## Returns how high above y=0 the body should sit, in world units. The creature
## stands on its legs — body bottom = leg_length. For limbless / sessile types
## (oozes, blobs, plants), returns 0 so they rest on the ground.
static func _ground_clearance(limbs: Dictionary) -> float:
	if not bool(limbs.get("has_legs", false)):
		return 0.0
	return float(limbs.get("leg_length", 0.0))

## Returns the world-space anchor where the head/face sits. Face builders place
## eyes and mouth ON the head (rather than on the torso), so this is THE
## function that decides where facial features live.
##
## Anchor logic by body type:
##   biped_torso   → on top of torso, slightly forward
##   quadruped_torso → at the FRONT end (positive Z), slightly raised
##   cylinder (plants) → top of stem, where the cap sits
##   blob/ooze     → upper-front of the body
##   sphere/cube   → center-front
##
## Returns (x, y, z) in body-root local coordinates.
static func _head_anchor(base: Dictionary, top: Dictionary, limbs: Dictionary) -> Vector3:
	var body_type: String = String(base.get("type", "sphere"))
	var w: float = _vec_axis(base, "width", 0.5)
	var h: float = _vec_axis(base, "height", 0.5)
	var d: float = _vec_axis(base, "depth", 0.5)
	var clearance: float = _ground_clearance(limbs)
	var top_height: float = float(top.get("height", 0.3))
	var top_size: float = float(top.get("size_factor", 1.0))
	match body_type:
		"biped_torso":
			# Head sits ON TOP of the torso. Torso bottom = clearance, torso
			# top = clearance + h. Head sits above that.
			return Vector3(0, clearance + h + top_height * 0.4, 0)
		"quadruped_torso":
			# Head extends FORWARD from the front end of the barrel torso.
			# Torso center is at y = clearance + (h * 0.5), z=0; front of
			# torso at z = +d * 0.5. Head extends further along +z.
			return Vector3(0, clearance + h * 0.6, d * 0.5 + h * 0.3)
		"cylinder":
			# For plants — head/cap is at the top of the stem.
			return Vector3(0, h + top_height * 0.3, 0)
		"blob":
			# Eyes ride the upper-front of the squashed sphere.
			return Vector3(0, h * 0.55, w * 0.35)
		"cube":
			# Construct head sits on top of cube torso.
			return Vector3(0, clearance + h + top_height * 0.4, 0)
		_:
			# Default sphere — face is on the front of the orb.
			return Vector3(0, h * 0.55 + clearance, w * 0.45)

## Returns the body's center position in world space — where the torso mass
## sits. Used by body shape builders for placement.
static func _body_center(base: Dictionary, limbs: Dictionary) -> Vector3:
	var body_type: String = String(base.get("type", "sphere"))
	var w: float = _vec_axis(base, "width", 0.5)
	var h: float = _vec_axis(base, "height", 0.5)
	var clearance: float = _ground_clearance(limbs)
	match body_type:
		"biped_torso":
			# Torso center halfway between legs and shoulders.
			return Vector3(0, clearance + h * 0.5, 0)
		"quadruped_torso":
			# Barrel sits on legs.
			return Vector3(0, clearance + h * 0.5, 0)
		"cylinder":
			# Plant trunk rises from the ground (no legs).
			return Vector3(0, h * 0.5, 0)
		"blob":
			# Squashed sphere sits flat on ground.
			return Vector3(0, h * 0.3, 0)
		"cube":
			return Vector3(0, clearance + h * 0.5, 0)
		_:
			# Default sphere — center at radius height above ground.
			return Vector3(0, w * 0.5 + clearance, 0)

## Build a StandardMaterial3D using palette.primary (or sane default).
static func _make_primary_material(palette: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("primary", palette.get("body_color", Color(0.5, 0.5, 0.5)))
	return mat

## Build a StandardMaterial3D using palette.secondary (or sane default).
static func _make_secondary_material(palette: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get("secondary", palette.get("cap_color", Color(0.7, 0.7, 0.7)))
	return mat
