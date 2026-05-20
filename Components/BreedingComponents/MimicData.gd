class_name MimicData
extends ActorData

## Procedural data carrier for Mimic creatures.
##
## Like MushroomData, MimicData holds the canonical creature definition as a
## `genome: Dictionary` (NOT scattered @exports). The body generator reads
## genome["body"]["shape"] etc. — different shapes give the player chests,
## vases, caskets, barrels, and crates that disguise themselves as ordinary
## furniture. Pure mimics never have legs/arms; the limbs slot is reserved
## for hybrid offspring that inherited limbs from a non-mimic ancestor.
##
## Module slot summary:
##   body         - silhouette + dimensions (WOODEN_BOX / TREASURE_CHEST / VASE / CASKET / BARREL / CRATE)
##   lid          - lid variant (FLAT / ROUNDED / PEAKED / NONE)
##   face         - eye count, mouth, tongue, teeth
##   surface      - texture / weathering hints
##   palette      - body / accent / mouth / eye / tongue colors
##   decorations  - metal bands, clasps, gems, lock, handles
##   limbs        - has_legs / has_arms (pure mimics: always false)
##   animation    - lid idle bob, tongue wiggle, bite open/close
##   attack       - bite specs (reach, damage)
##   mutation     - rare features (cursed glow, blood-stained, gem-encrusted)

signal genome_changed

@export_group("Identity")
@export var creature_name: String = "Mimic":
	set(v):
		if creature_name == v: return
		creature_name = v
		stats_changed.emit()
@export var level: int = 1:
	set(v):
		if level == v: return
		level = v
		stats_changed.emit()

@export_group("Economy")
@export var gold_value: int = 80:
	set(v):
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

## Genome Dictionary — canonical creature descriptor. The procedural body
## generator reads genome["<slot>"]["<field>"] to assemble the model.
@export var genome: Dictionary = default_genome():
	set(v):
		genome = v
		genome_changed.emit()
		stats_changed.emit()

func _init() -> void:
	# Mimic stat profile (matches MimicActor._apply_mimic_stat_profile).
	strength = 3.0
	dexterity = 1.0
	constitution = 2.0
	intelligence = -3.0
	wisdom = 1.0
	charisma = -1.0
	# Pure mimic by definition.
	mimic_blood = 1.0
	base_color = Color(0.46, 0.31, 0.17)
	pattern_color = Color(0.24, 0.16, 0.08)
	# Per-creature deterministic render seed so the body looks the same on
	# every rebuild. Initialised here so a freshly-constructed MimicData
	# already has a unique identity.
	if render_seed == 0:
		render_seed = randi()
	# Auto-name from the render_seed so each MimicData has a unique,
	# memorable name like "Krathmoss" or "Vorbark" instead of the generic
	# "Mimic" default.
	creature_name = ActorData.generate_name_from_seed(render_seed)
	if genome.is_empty():
		genome = default_genome()

## Canonical genome shape. ALL slots present even if a particular shape
## doesn't read all of them, so breeding can mix freely.
static func default_genome() -> Dictionary:
	return {
		"body": {
			# Shape determines which generator runs:
			# "wooden_box" / "treasure_chest" / "vase" / "casket" / "barrel" / "crate"
			"shape": "wooden_box",
			"width": 0.70,
			"height": 0.55,
			"depth": 0.45,
			# Vase-specific: neck position + narrowing
			"neck_ratio": 0.55,
			"neck_radius_ratio": 0.45,
			# Barrel/crate plank/stave count
			"plank_count": 4,
			# Casket aspect (length-vs-height stretch)
			"length_stretch": 1.0
		},
		"lid": {
			# "flat" / "rounded" (half-cylinder) / "peaked" / "none" (open top)
			"variant": "flat",
			"thickness": 0.06,
			"open_angle_idle": 18.0,
			"open_angle_bite": 65.0
		},
		"face": {
			"eye_count": 2,
			"eye_radius": 0.04,
			"eye_spread": 0.22,
			"eye_glow": true,
			# When the lid is rounded/peaked, eyes sit ON the lid surface.
			"eyes_on_lid": false,
			"tooth_count": 8,
			"tooth_size": 0.04,
			"tongue_length": 0.14,
			# 0.0 = fully retracted inside mouth, 1.0 = fully extended.
			# Tongues idle around 0.35 and lash forward during bite.
			"tongue_protrude": 0.35,
			"tongue_thickness": 0.04
		},
		"surface": {
			# "wood_planks" / "ceramic" / "polished" / "weathered" / "stone"
			"texture_hint": "wood_planks",
			"roughness": 0.75,
			"emission": 0.0
		},
		"palette": {
			"body_color": Color(0.40, 0.27, 0.16),    # wood/ceramic main
			"accent_color": Color(0.58, 0.52, 0.44),  # metal bands / trim
			"mouth_color": Color(0.02, 0.02, 0.02),   # interior shadow
			"eye_color": Color(0.94, 0.18, 0.10),     # glowing eyes
			"tongue_color": Color(0.76, 0.25, 0.32),
			"tooth_color": Color(0.95, 0.92, 0.85)
		},
		"decorations": {
			"band_count": 0,        # metal bands wrapping the body
			"clasp_count": 0,       # latches/clasps on the front
			"gem_count": 0,         # encrusted gems
			"lock_present": false,  # padlock on front
			"handle_present": false # side handles
		},
		"limbs": {
			# Pure mimics have NO limbs. Hybrid offspring (born from a Mimic
			# crossed with something legged) may have these set true by the
			# breeding system in a future patch.
			"has_legs": false,
			"has_arms": false,
			"arm_count": 2,
			"arm_length": 0.22,
			"arm_radius": 0.04,
			"arm_y_offset": 0.30,
			"arm_droop": 0.4,
			"leg_count": 2,
			"leg_length": 0.18,
			"leg_radius": 0.05,
			"leg_spread": 0.12,
			"foot_size": 0.07
		},
		"animation": {
			"lid_idle_speed": 1.4,
			"lid_idle_amplitude": 10.0,   # degrees
			"tongue_wiggle_speed": 3.0,
			"tongue_wiggle_amplitude": 0.04
		},
		"attack": {
			"name": "Adhesive Bite",
			"reach": 1.5,
			"damage_die": "1d8",
			"damage_type": "piercing",
			"secondary_damage_type": "acid",
			"secondary_damage": 3.0
		},
		"mutation": {
			"cursed_glow": false,
			"glow_color": Color(0.85, 0.20, 0.55),
			"blood_stained": false,
			"gem_encrusted": false
		},
		"grafted": {
			"source_species": "",
			# Mushroom-source graft fields:
			"mushroom_cap_profile": "dome",
			"mushroom_cap_radius": 0.0,
			"mushroom_cap_height": 0.0,
			"mushroom_cap_color": Color(0.86, 0.25, 0.25),
			"mushroom_spot_count": 0,
			"mushroom_spot_radius": 0.06,
			"mushroom_spot_color": Color(0.95, 0.95, 0.88),
			"mushroom_eye_color": Color(0.1, 0.1, 0.1),
			# Compound modular feature flags — independently rolled at
			# breeding time so each hybrid has a unique combo:
			"has_cap_graft": false,         # mushroom cap on top of lid
			"has_spots_on_body": false,     # spots painted on chest
			"has_extra_eyes_on_cap": false, # extra eyes on the cap
			"has_stem_antenna": false,      # mushroom stem poking from lid
			"extra_eye_count": 0,
			"extra_eye_radius": 0.04,
			"extra_eye_glow": false,
			# Goblin-source graft fields:
			"goblin_skin_color": Color(0.42, 0.66, 0.28),
			"goblin_size_factor": 0.0,
			# Goat-source graft fields:
			"goat_pattern_color": Color(0.7, 0.6, 0.4),
			"goat_horn_present": false
		}
	}

## Roll a fresh procedural genome. Every wild spawn calls this so each Mimic
## looks like a different piece of disguised furniture. NEVER sets legs/arms
## true — pure mimics are always limbless. Hybrid offspring may have those
## flags set externally by the breeding system.
func randomize_genome() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var g: Dictionary = default_genome()

	# --- Body shape (weighted) ---
	# Treasure chest is the iconic mimic so it stays common; other shapes
	# round out the disguise vocabulary.
	var shapes: Array = ["wooden_box", "treasure_chest", "vase", "casket", "barrel", "crate"]
	var weights: Array = [0.20, 0.30, 0.15, 0.12, 0.13, 0.10]
	var roll: float = rng.randf()
	var acc: float = 0.0
	var picked: String = "treasure_chest"
	for i in range(shapes.size()):
		acc += weights[i]
		if roll <= acc:
			picked = shapes[i]
			break
	g["body"]["shape"] = picked

	# --- Dimensions (shape-dependent) ---
	match picked:
		"wooden_box":
			g["body"]["width"] = rng.randf_range(0.55, 0.78)
			g["body"]["height"] = rng.randf_range(0.45, 0.65)
			g["body"]["depth"] = rng.randf_range(0.40, 0.55)
		"treasure_chest":
			g["body"]["width"] = rng.randf_range(0.60, 0.82)
			g["body"]["height"] = rng.randf_range(0.42, 0.58)
			g["body"]["depth"] = rng.randf_range(0.42, 0.58)
		"vase":
			# Vase is taller than wide.
			g["body"]["width"] = rng.randf_range(0.32, 0.48)
			g["body"]["height"] = rng.randf_range(0.65, 0.95)
			g["body"]["depth"] = g["body"]["width"]  # vases are round
			g["body"]["neck_ratio"] = rng.randf_range(0.50, 0.72)
			g["body"]["neck_radius_ratio"] = rng.randf_range(0.32, 0.58)
		"casket":
			# Casket is long, low, narrow.
			g["body"]["width"] = rng.randf_range(0.82, 1.10)
			g["body"]["height"] = rng.randf_range(0.32, 0.48)
			g["body"]["depth"] = rng.randf_range(0.36, 0.48)
			g["body"]["length_stretch"] = rng.randf_range(1.05, 1.25)
		"barrel":
			# Barrel is round, slightly squat.
			g["body"]["width"] = rng.randf_range(0.50, 0.72)
			g["body"]["height"] = rng.randf_range(0.55, 0.78)
			g["body"]["depth"] = g["body"]["width"]
			g["body"]["plank_count"] = rng.randi_range(8, 14)
		"crate":
			g["body"]["width"] = rng.randf_range(0.55, 0.72)
			g["body"]["height"] = rng.randf_range(0.50, 0.70)
			g["body"]["depth"] = rng.randf_range(0.50, 0.65)
			g["body"]["plank_count"] = rng.randi_range(3, 5)

	# --- Lid (depends on shape) ---
	# Treasure chests are the canonical rounded-lid variant; wooden boxes
	# and crates usually have flat lids; caskets sometimes peak; vases and
	# barrels have NO lid (open top, tongue protrudes through opening).
	match picked:
		"treasure_chest":
			# 70% rounded, 25% peaked, 5% flat — iconic chest silhouette.
			var lid_roll: float = rng.randf()
			if lid_roll < 0.70: g["lid"]["variant"] = "rounded"
			elif lid_roll < 0.95: g["lid"]["variant"] = "peaked"
			else: g["lid"]["variant"] = "flat"
		"wooden_box", "crate":
			# 80% flat, 20% peaked.
			g["lid"]["variant"] = "peaked" if rng.randf() < 0.20 else "flat"
		"casket":
			# 60% flat, 40% peaked.
			g["lid"]["variant"] = "peaked" if rng.randf() < 0.40 else "flat"
		"vase", "barrel":
			g["lid"]["variant"] = "none"
	g["lid"]["thickness"] = rng.randf_range(0.05, 0.10)
	g["lid"]["open_angle_idle"] = rng.randf_range(8.0, 28.0)

	# PURE-MIMIC RULES (user spec):
	#   1. Eyes always sit on the upper part of the lid — they peer over the
	#      opening when the lid bobs idle. This applies regardless of lid
	#      variant (flat / rounded / peaked).
	#   2. Tongue always stays inside the mouth — never protruding for pure
	#      mimics. (Hybrid offspring can override this later via their own
	#      genome roll, but pure mimics keep the disguise tight.)
	g["face"]["eyes_on_lid"] = true

	# --- Face variation ---
	# Eye count goes up to 8 in pure mimics. Hybrids can roll up to 12 via
	# the compound-feature graft system, where extra eyes can land on the
	# grafted cap or crown on top of the normal lid eyes.
	g["face"]["eye_count"] = rng.randi_range(2, 8)
	g["face"]["eye_radius"] = rng.randf_range(0.028, 0.055)
	g["face"]["eye_spread"] = rng.randf_range(0.16, 0.34)
	g["face"]["eye_glow"] = rng.randf() < 0.85  # most mimics have glowing eyes
	g["face"]["tooth_count"] = rng.randi_range(6, 13)
	g["face"]["tooth_size"] = rng.randf_range(0.025, 0.05)
	g["face"]["tongue_length"] = rng.randf_range(0.11, 0.18)
	# tongue_protrude=0 means the tongue base sits half a length back from
	# the mouth opening, so the FORWARD HALF of the segmented tongue (last
	# segments + forked tip) emerges from the mouth between the teeth.
	# Pure mimics never extend further than this — hybrid offspring may.
	g["face"]["tongue_protrude"] = 0.0
	# Thin enough that the tongue actually fits BETWEEN the two tooth rows
	# instead of clipping through them. Previous 0.030-0.055 range gave a
	# 0.05-0.10m-wide tongue that intersected the upper/lower teeth.
	g["face"]["tongue_thickness"] = rng.randf_range(0.014, 0.024)

	# --- Surface / palette ---
	var surface_hints: Array = ["wood_planks", "wood_planks", "ceramic", "polished", "weathered", "stone"]
	g["surface"]["texture_hint"] = surface_hints[rng.randi() % surface_hints.size()]
	g["surface"]["roughness"] = rng.randf_range(0.55, 0.95)
	g["palette"] = _roll_palette(rng, picked, g["surface"]["texture_hint"])

	# --- Decorations (shape-biased) ---
	match picked:
		"treasure_chest":
			g["decorations"]["band_count"] = rng.randi_range(2, 4)
			g["decorations"]["clasp_count"] = rng.randi_range(1, 3)
			g["decorations"]["gem_count"] = rng.randi_range(0, 4)
			g["decorations"]["lock_present"] = rng.randf() < 0.70
			g["decorations"]["handle_present"] = rng.randf() < 0.55
		"wooden_box":
			g["decorations"]["band_count"] = rng.randi_range(0, 2)
			g["decorations"]["clasp_count"] = rng.randi_range(0, 1)
			g["decorations"]["gem_count"] = 0
			g["decorations"]["lock_present"] = rng.randf() < 0.30
			g["decorations"]["handle_present"] = rng.randf() < 0.25
		"vase":
			g["decorations"]["band_count"] = rng.randi_range(0, 3)  # decorative rings
			g["decorations"]["clasp_count"] = 0
			g["decorations"]["gem_count"] = rng.randi_range(0, 2)
			g["decorations"]["lock_present"] = false
			g["decorations"]["handle_present"] = rng.randf() < 0.50  # handles on sides
		"casket":
			g["decorations"]["band_count"] = rng.randi_range(2, 3)
			g["decorations"]["clasp_count"] = rng.randi_range(2, 4)
			g["decorations"]["gem_count"] = rng.randi_range(0, 3)
			g["decorations"]["lock_present"] = rng.randf() < 0.85
			g["decorations"]["handle_present"] = rng.randf() < 0.80
		"barrel":
			g["decorations"]["band_count"] = rng.randi_range(3, 5)  # canonical barrel hoops
			g["decorations"]["clasp_count"] = 0
			g["decorations"]["gem_count"] = 0
			g["decorations"]["lock_present"] = false
			g["decorations"]["handle_present"] = false
		"crate":
			g["decorations"]["band_count"] = 0
			g["decorations"]["clasp_count"] = 0
			g["decorations"]["gem_count"] = 0
			g["decorations"]["lock_present"] = rng.randf() < 0.15
			g["decorations"]["handle_present"] = rng.randf() < 0.20

	# --- Limbs (NEVER for pure mimics) ---
	# Pure mimics are blob-like; arms/legs are reserved for hybrid offspring.
	# The genome SHAPE still lists them so hybrid breeding can populate them
	# without altering the data layout.
	g["limbs"]["has_arms"] = false
	g["limbs"]["has_legs"] = false

	# --- Animation ---
	g["animation"]["lid_idle_speed"] = rng.randf_range(0.9, 2.0)
	g["animation"]["lid_idle_amplitude"] = rng.randf_range(6.0, 16.0)
	g["animation"]["tongue_wiggle_speed"] = rng.randf_range(2.0, 5.0)
	g["animation"]["tongue_wiggle_amplitude"] = rng.randf_range(0.025, 0.065)

	# --- Mutation (rare) ---
	g["mutation"]["cursed_glow"] = rng.randf() < 0.12
	if g["mutation"]["cursed_glow"]:
		# Glow tinted by the mimic's eye color so cursed mimics radiate
		# whatever their iris hue happens to be.
		g["mutation"]["glow_color"] = g["palette"]["eye_color"].lerp(Color(0.85, 0.20, 0.55), 0.4)
	g["mutation"]["blood_stained"] = rng.randf() < 0.08
	g["mutation"]["gem_encrusted"] = (g["decorations"]["gem_count"] >= 3) and (rng.randf() < 0.40)

	# Commit the genome (setter rebuilds the body via ProceduralMimicChest).
	genome = g
	# Cosmetic mirror for legacy ActorCard rendering.
	base_color = g["palette"]["body_color"]
	pattern_color = g["palette"]["accent_color"]

static func _roll_palette(rng: RandomNumberGenerator, shape: String, texture_hint: String) -> Dictionary:
	# Choose a body palette appropriate to the surface texture.
	var body_color: Color
	match texture_hint:
		"ceramic":
			body_color = Color(rng.randf_range(0.85, 0.98), rng.randf_range(0.82, 0.95), rng.randf_range(0.75, 0.88))
		"polished":
			# Dark polished wood — rich browns / blacks.
			body_color = Color(rng.randf_range(0.12, 0.32), rng.randf_range(0.08, 0.22), rng.randf_range(0.05, 0.16))
		"weathered":
			body_color = Color(rng.randf_range(0.32, 0.55), rng.randf_range(0.28, 0.50), rng.randf_range(0.22, 0.42))
		"stone":
			body_color = Color(rng.randf_range(0.42, 0.62), rng.randf_range(0.42, 0.62), rng.randf_range(0.42, 0.62))
		_:  # "wood_planks"
			body_color = Color(rng.randf_range(0.28, 0.50), rng.randf_range(0.18, 0.35), rng.randf_range(0.08, 0.22))
	# Accent (metal bands / trim).
	var metal_palette: Array = [
		Color(0.58, 0.52, 0.44),  # iron
		Color(0.72, 0.62, 0.20),  # brass
		Color(0.86, 0.78, 0.45),  # gold
		Color(0.78, 0.78, 0.82),  # silver
		Color(0.42, 0.30, 0.20)   # dark iron
	]
	var accent: Color = metal_palette[rng.randi() % metal_palette.size()]
	# Eyes — usually red/yellow/orange/green for "evil glow".
	var eye_palette: Array = [
		Color(0.94, 0.18, 0.10),  # red
		Color(0.98, 0.42, 0.08),  # orange
		Color(0.95, 0.70, 0.12),  # yellow
		Color(0.20, 0.85, 0.32),  # green
		Color(0.30, 0.62, 0.95),  # blue (rare)
		Color(0.90, 0.12, 0.78)   # magenta (rare)
	]
	var eye_color: Color = eye_palette[rng.randi() % eye_palette.size()]
	# Tongue — pink/red biological.
	var tongue_palette: Array = [
		Color(0.76, 0.25, 0.32),
		Color(0.88, 0.42, 0.48),
		Color(0.62, 0.18, 0.20),
		Color(0.82, 0.32, 0.40)
	]
	var tongue: Color = tongue_palette[rng.randi() % tongue_palette.size()]
	return {
		"body_color": body_color,
		"accent_color": accent,
		"mouth_color": Color(0.02, 0.02, 0.02),
		"eye_color": eye_color,
		"tongue_color": tongue,
		"tooth_color": Color(0.95, 0.92, 0.85)
	}

func create_offspring(partner: ActorData) -> ActorData:
	# Same species → species-specific crossover. Anything else (Mushroom,
	# Goblin, Goat, future creatures) → universal cross-species path on
	# ActorData. No bespoke per-pair hybrid functions live here anymore.
	if partner == null:
		return null
	if partner is MimicData:
		return _create_pure_mimic_kid(partner as MimicData)
	return ActorData.universal_crossover_breed(self, partner)

## Pure Mimic × Mimic breeding (existing path, factored out).
func _create_pure_mimic_kid(partner_mimic: MimicData) -> MimicData:
	var pure_kid := MimicData.new()
	pure_kid.creature_name = "Mimic Spawnling"
	pure_kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	pure_kid.genome = _crossover_genome(genome, partner_mimic.genome)
	pure_kid.base_color = pure_kid.genome["palette"]["body_color"]
	pure_kid.pattern_color = pure_kid.genome["palette"]["accent_color"]
	pure_kid.strength = (strength + partner_mimic.strength) * 0.5 * randf_range(0.9, 1.1)
	pure_kid.dexterity = (dexterity + partner_mimic.dexterity) * 0.5 * randf_range(0.9, 1.1)
	pure_kid.constitution = (constitution + partner_mimic.constitution) * 0.5 * randf_range(0.9, 1.1)
	pure_kid.intelligence = (intelligence + partner_mimic.intelligence) * 0.5 * randf_range(0.9, 1.1)
	pure_kid.wisdom = (wisdom + partner_mimic.wisdom) * 0.5 * randf_range(0.9, 1.1)
	pure_kid.charisma = (charisma + partner_mimic.charisma) * 0.5 * randf_range(0.9, 1.1)
	ActorData.apply_mimic_lineage(pure_kid, self, partner_mimic)
	return pure_kid

# Bespoke per-pair hybrid helpers were removed. All cross-species breeding
# now flows through ActorData.universal_crossover_breed which transfers
# limbs, palette, stats, and mutations from both parents to the kid.

func get_actor_type() -> String:
	return "MimicData"

# --- Internal: genome crossover ---------------------------------------------

## Per-slot crossover with mutation. Each leaf field is pulled from one
## parent (50/50) and jittered. Shape strings inherit cleanly. Colors lerp.
static func _crossover_genome(genome_a: Dictionary, genome_b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot_key in genome_a.keys():
		var slot_a: Dictionary = genome_a.get(slot_key, {})
		var slot_b: Dictionary = genome_b.get(slot_key, slot_a)
		var slot_out: Dictionary = {}
		for field_key in slot_a.keys():
			var value_a = slot_a[field_key]
			var value_b = slot_b.get(field_key, value_a)
			slot_out[field_key] = _crossover_field(value_a, value_b)
		out[slot_key] = slot_out
	# Pure-mimic invariants: eyes always on the lid, tongue always inside,
	# never any limbs. These hold for every pure×pure offspring regardless
	# of which parent's lid variant won the coin flip.
	if out.has("face"):
		out["face"]["eyes_on_lid"] = true
		out["face"]["tongue_protrude"] = 0.0
	if out.has("limbs"):
		out["limbs"]["has_arms"] = false
		out["limbs"]["has_legs"] = false
	return out

static func _crossover_field(a, b):
	if a is float or a is int:
		var picked = a if randf() < 0.5 else b
		return picked * randf_range(0.92, 1.08)
	if a is Color:
		return (a as Color).lerp(b as Color, randf())
	if a is bool:
		var picked = a if randf() < 0.5 else b
		if randf() < 0.05:
			picked = not picked
		return picked
	if a is String or a is StringName:
		return a if randf() < 0.5 else b
	return a if randf() < 0.5 else b
