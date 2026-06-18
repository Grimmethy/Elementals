class_name ProceduralCreatureBody
extends Node3D

## Universal procedural creature renderer. Reads `actor_data.shared_body_plan`
## (a Dictionary defined on ActorData) and composes the creature's mesh by
## dispatching each body part to a registered builder in PartBuilders.gd.
##
## This is the "content engine" of Hornbound — every D&D Monster Manual entry
## becomes a unique-looking creature by running through this single renderer
## with a different shared_body_plan dict. Variety scales with category
## templates + per-species body_plan_modifiers, NOT with per-monster mesh code.
##
## The existing specialist renderers (ProceduralMimicChest, ProceduralMushroom-
## Body) coexist: they handle their own body archetypes via the `body.type`
## dispatch in BODY_BUILDERS. This class is the *fallback / universal* renderer
## that handles all other archetypes.
##
## Lifecycle:
##   1. Construct (attach as child of an Actor)
##   2. Assign actor_data
##   3. Call rebuild_from_genome(actor_data.shared_body_plan)
##   4. The mesh tree is rebuilt deterministically from the plan + render_seed
##
## All randomness inside builders MUST use `_rng` (seeded by render_seed) so
## the same plan + seed produces the same visual every rebuild.

# PartBuilders is accessed via its class_name (registered globally by Godot
# when the file declares `class_name PartBuilders`). No preload needed —
# preloading would duplicate the identifier and cause a parse error.

## The data resource this body is rendering. Optional — if null, render_seed
## defaults to 0 and the creature will be deterministic but identical.
var actor_data: ActorData = null

## Root container for all body parts. Cleared and rebuilt on each call to
## rebuild_from_genome. Keeping a single root simplifies cleanup and isolates
## procedural mesh from any animation rig the parent Actor may have.
var _body_root: Node3D = null

## Seeded RNG. Reseeded on every rebuild from actor_data.render_seed.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Optional override for the plan, used by previews when actor_data is null.
## If set, takes precedence over actor_data.shared_body_plan.
var override_plan: Dictionary = {}

func _ready() -> void:
	if _body_root == null:
		_body_root = Node3D.new()
		_body_root.name = "BodyRoot"
		add_child(_body_root)
	# If actor_data was set before _ready, auto-rebuild.
	if actor_data != null and not override_plan.is_empty():
		rebuild_from_genome(override_plan)
	elif actor_data != null:
		rebuild_from_genome(actor_data.shared_body_plan)

## Rebuild the entire mesh tree from a shared_body_plan dict. Safe to call
## multiple times — previous meshes are immediately freed.
##
## [plan] A dict matching the schema in ActorData.default_shared_body_plan().
##        Must contain keys: base, top, face, limbs, ornaments, palette.
##        Missing slots are treated as defaults (skip / empty).
func rebuild_from_genome(plan: Dictionary) -> void:
	_seed_rng()
	_clear_body_root()
	if _body_root == null:
		# Defensive — if rebuild is called before _ready, set up the root now.
		_body_root = Node3D.new()
		_body_root.name = "BodyRoot"
		add_child(_body_root)

	# Hand-authored low-poly path: if a SurfaceTool mesh exists for this
	# sub_template (Wolf, etc.), use it for the WHOLE body + head + legs +
	# tail + ears as one cohesive mesh, then add ornaments and mutations
	# on top. Sub-templates without a hand-built mesh fall through to the
	# compositional procedural path below.
	var meta: Dictionary = plan.get("meta", {})
	var sub: String = String(meta.get("sub_template", ""))
	if LowPolyMeshes.has_mesh_for(sub):
		LowPolyMeshes.build_for(sub, plan, _body_root)
		# Face features (eyes / mouth):
		#   - For the wolf, leave them to the procedural PartBuilders.build_face
		#     (its head_anchor coincidentally lands on the wolf head).
		#   - For everyone else, the hand-built mesh draws its own face. Calling
		#     PartBuilders.build_face here would lay a SECOND set of eyes at
		#     the procedural head_anchor — which is where the user-reported
		#     "satyr eyes floating above the head" bug came from.
		if not LowPolyMeshes.draws_own_face(sub):
			_build_face(plan)
		# Ornaments (tail, wings, horns, flowering_accents, etc.) — also skip
		# for hand-built creatures that draw their own. Otherwise the pig gets
		# a duplicate cylinder tail on top of its curly one, and the pixie
		# gets 3-5 huge pink spheres (flowering_accents at fixed 0.05 radius
		# while the pixie body is shrunk to 0.35× by base.scale).
		if not LowPolyMeshes.draws_own_ornaments(sub):
			_build_ornaments(plan)
		_build_mutations(plan)
		return

	_build_body(plan)
	_build_top(plan)
	_build_face(plan)
	_build_limbs(plan)
	_build_ornaments(plan)
	_build_mutations(plan)

func _seed_rng() -> void:
	var seed_value: int = 0
	if actor_data != null:
		seed_value = actor_data.render_seed
	if seed_value == 0:
		seed_value = randi()
	_rng.seed = seed_value

func _clear_body_root() -> void:
	if _body_root == null:
		return
	for child in _body_root.get_children():
		_body_root.remove_child(child)
		child.queue_free()

## Build the base body mesh (`plan.base.type`). Dispatch to BODY_BUILDERS.
## limbs is passed so the body knows ground clearance (= leg_length).
## meta carries sub_template / category / species so the body builder can
## produce visually distinct meshes per anatomy variant.
func _build_body(plan: Dictionary) -> void:
	if not plan.has("base"):
		return
	var base: Dictionary = plan["base"]
	var body_type: String = String(base.get("type", ""))
	if body_type.is_empty():
		return
	var palette: Dictionary = plan.get("palette", {})
	var limbs: Dictionary = plan.get("limbs", {})
	var meta: Dictionary = plan.get("meta", {})
	PartBuilders.build_body(_body_root, body_type, base, palette, limbs, meta, _rng)

## Build the top/head/cap mesh (`plan.top.type`). Dispatch to TOP_BUILDERS.
## meta tells the head builder which sub-template to render
## (wolf muzzle / bear round / dragon wedge / etc.).
func _build_top(plan: Dictionary) -> void:
	if not plan.has("top"):
		return
	var top: Dictionary = plan["top"]
	var top_type: String = String(top.get("type", "none"))
	if top_type == "none":
		return
	var base: Dictionary = plan.get("base", {})
	var palette: Dictionary = plan.get("palette", {})
	var limbs: Dictionary = plan.get("limbs", {})
	var meta: Dictionary = plan.get("meta", {})
	PartBuilders.build_top(_body_root, top_type, top, base, palette, limbs, meta, _rng)

## Build face meshes (eyes, mouth, teeth ring). Dispatch to FACE_BUILDERS.
## top + limbs are passed so the face is positioned ON the head, not on the
## torso (head anchor depends on body type + top type + leg clearance).
func _build_face(plan: Dictionary) -> void:
	if not plan.has("face"):
		return
	var face: Dictionary = plan["face"]
	var base: Dictionary = plan.get("base", {})
	var top: Dictionary = plan.get("top", {})
	var limbs: Dictionary = plan.get("limbs", {})
	var palette: Dictionary = plan.get("palette", {})
	PartBuilders.build_face(_body_root, face, base, top, limbs, palette, _rng)

## Build limb meshes (arms, legs). Dispatch to LIMB_BUILDERS.
func _build_limbs(plan: Dictionary) -> void:
	if not plan.has("limbs"):
		return
	var limbs: Dictionary = plan["limbs"]
	var base: Dictionary = plan.get("base", {})
	var palette: Dictionary = plan.get("palette", {})
	PartBuilders.build_limbs(_body_root, limbs, base, palette, _rng)

## Build decorative ornaments per tag in `plan.ornaments.tags`. The ornament
## builders need `top` + `limbs` to position correctly (horns on head,
## tail at body-rear, halo above head, etc.).
func _build_ornaments(plan: Dictionary) -> void:
	if not plan.has("ornaments"):
		return
	var ornaments: Dictionary = plan["ornaments"]
	var tags: Variant = ornaments.get("tags", [])
	if not (tags is Array):
		return
	var base: Dictionary = plan.get("base", {})
	var top: Dictionary = plan.get("top", {})
	var limbs: Dictionary = plan.get("limbs", {})
	var palette: Dictionary = plan.get("palette", {})
	for tag_value in tags:
		var tag: String = String(tag_value)
		PartBuilders.build_ornament(_body_root, tag, ornaments, base, top, limbs, palette, _rng)

## Build mutation features per flag in actor_data.genome.universal_mutations.
## Mutations are stored on the genome dict (not in shared_body_plan) so they
## persist across body re-rolls; we read them straight from actor_data here.
## Top + limbs slots are pulled from the plan so mutations (third eye on
## head, halo above head, chitin plate, etc.) position correctly.
func _build_mutations(_plan: Dictionary) -> void:
	if actor_data == null:
		return
	if not "genome" in actor_data:
		return
	var genome_var: Variant = actor_data.get("genome")
	if not (genome_var is Dictionary):
		return
	var genome: Dictionary = genome_var
	var mutations: Variant = genome.get("universal_mutations", {})
	if not (mutations is Dictionary):
		return
	var palette: Dictionary = _plan.get("palette", {}) if _plan is Dictionary else {}
	var base: Dictionary = _plan.get("base", {}) if _plan is Dictionary else {}
	var top: Dictionary = _plan.get("top", {}) if _plan is Dictionary else {}
	var limbs: Dictionary = _plan.get("limbs", {}) if _plan is Dictionary else {}
	for tag in mutations.keys():
		var flag: Variant = mutations[tag]
		if flag is bool and (flag as bool):
			PartBuilders.build_mutation(_body_root, String(tag), base, top, limbs, palette, _rng)
