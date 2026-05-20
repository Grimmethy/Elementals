class_name MushroomData
extends ActorData

## MushroomData carries the genome for a procedural Mushroom Monster.
##
## SOURCE-OF-TRUTH RULE: the genome Dictionary is the canonical description
## of the creature. The body generator (ProceduralMushroomBody) reads from
## genome["<module>"], NOT from scattered @exports on this resource. This
## lets us add new module generators later without touching the data shape.
##
## ALL future modules listed in the architectural doc appear here as
## placeholder sub-dicts even when v1's generator only reads three of them
## (cap, body, face). The v1 generator must tolerate the placeholders as
## inert; later patches replace each generator without breaking saves.
##
## Module slot summary (architectural doc):
##   cap        - mushroom cap (radius, height, profile)
##   body       - stem / torso (height, radius, taper)
##   face       - eyes / mouth (eye_count, eye_spread, mouth_width)
##   surface    - texture / shader hints (texture_hint, roughness)
##   palette    - colors (cap, stem, accent, eye)
##   limbs      - legs / arms (limb_count, limb_length)  -- v1: empty
##   animation  - idle behavior (bob_speed, bob_amplitude)
##   attack     - bite / weapon specs (reach, damage_die)
##   mutation   - rare traits (glow, spore_color, etc.)

signal genome_changed

@export_group("Identity")
@export var creature_name: String = "Mushroom":
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
@export var gold_value: int = 35:
	set(v):
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

## Genome Dictionary — the canonical descriptor. Read by generators via
## genome["<slot>"]["<field>"]. Do NOT scatter these fields as @exports;
## that breaks the contract that breeding mixes genomes, not @exports.
@export var genome: Dictionary = default_genome():
	set(v):
		genome = v
		genome_changed.emit()
		stats_changed.emit()

func _init() -> void:
	# Baseline Mushroom Monster stat profile (small fungus, sluggish, sturdy).
	strength = 1.0
	dexterity = -1.0
	constitution = 2.0
	intelligence = -4.0
	wisdom = 0.0
	charisma = -3.0
	base_color = Color(0.86, 0.25, 0.25)   # red-cap
	pattern_color = Color(0.95, 0.95, 0.88) # cream spots
	# Per-creature deterministic render seed so the procedural body produces
	# identical visuals on every rebuild.
	if render_seed == 0:
		render_seed = randi()
	# Auto-name from the render_seed so each MushroomData has a unique
	# fantasy name instead of the generic "Mushroom" default.
	creature_name = ActorData.generate_name_from_seed(render_seed)
	if genome.is_empty():
		genome = default_genome()

## Roll a fresh procedural genome. Every wild spawn calls this so each
## mushroom looks distinct. Exposes all eight visible features:
##   1) cap profile     2) cap radius / height
##   3) stem dimensions 4) spot count + radius
##   5) eye count       6) mouth proportions
##   7) palette colors  8) mutation (glow + spore-burst bonus)
func randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var g: Dictionary = default_genome()

	# 1) Cap profile — 8 profiles now. Adding new ones: append to the array
	# + the weights array + add a build case in ProceduralMushroomBody._build_cap.
	var cap_profiles: Array = ["dome", "flat", "cone", "bell", "umbrella", "coral", "puffball", "parasol"]
	var cap_weights: Array = [0.30, 0.15, 0.10, 0.10, 0.10, 0.08, 0.10, 0.07]
	var profile_roll: float = rng.randf()
	var profile_acc: float = 0.0
	var profile: String = "dome"
	for i in range(cap_profiles.size()):
		profile_acc += cap_weights[i]
		if profile_roll <= profile_acc:
			profile = cap_profiles[i]
			break
	g["cap"]["profile"] = profile

	# 2) Cap size variation. Roll the STEM height FIRST so we can clamp the
	# cap proportions to always read as "cap on top of body" instead of
	# "blob with no separation." A cap can never be wider than ~1.6x the
	# stem height, and never taller than 60% of the stem.
	var stem_height: float = rng.randf_range(0.50, 0.85)
	g["body"]["height"] = stem_height
	var max_cap_radius: float = clampf(stem_height * 0.85, 0.30, 0.58)
	var max_cap_height: float = stem_height * 0.55
	g["cap"]["radius"] = rng.randf_range(0.28, max_cap_radius)
	g["cap"]["height"] = rng.randf_range(0.18, max_cap_height)
	g["cap"]["spot_count"] = rng.randi_range(3, 9)
	g["cap"]["spot_radius"] = rng.randf_range(0.035, 0.085)

	# 3) Stem taper
	var stem_r_bot: float = rng.randf_range(0.13, 0.22)
	g["body"]["radius_bottom"] = stem_r_bot
	g["body"]["radius_top"] = stem_r_bot * rng.randf_range(0.65, 0.95)

	# 4) Face — eye count drives the most-visible variation. Eyes/mouth y
	# offsets are kept in the upper half of the stem so the face reads
	# clearly above the legs (if any). Expression rolls 4 ways.
	# Pure mushrooms cap at 6 eyes; hybrids can stack additional eyes on
	# grafted features for visible counts up to 12+.
	g["face"]["eye_count"] = rng.randi_range(1, 6)
	g["face"]["eye_radius"] = rng.randf_range(0.035, 0.065)
	g["face"]["eye_spread"] = rng.randf_range(0.10, 0.22)
	g["face"]["eye_y_offset"] = rng.randf_range(stem_height * 0.55, stem_height * 0.85)
	g["face"]["mouth_width"] = rng.randf_range(0.10, 0.24)
	g["face"]["mouth_height"] = rng.randf_range(0.02, 0.06)
	g["face"]["mouth_y_offset"] = rng.randf_range(stem_height * 0.35, stem_height * 0.55)
	var expressions: Array = ["smile", "frown", "o", "smirk"]
	g["face"]["expression"] = expressions[rng.randi() % expressions.size()]

	# 5) Limbs — wire the architectural placeholder. 60% chance of arms,
	# 55% chance of legs. Arms have a droop pose so they look characterful
	# rather than stiff T-poses. Legs always pair (left/right).
	g["limbs"]["has_arms"] = rng.randf() < 0.60
	g["limbs"]["arm_count"] = 2
	g["limbs"]["arm_length"] = rng.randf_range(0.20, 0.40)
	g["limbs"]["arm_radius"] = rng.randf_range(0.035, 0.060)
	g["limbs"]["arm_y_offset"] = rng.randf_range(stem_height * 0.45, stem_height * 0.75)
	g["limbs"]["arm_droop"] = rng.randf_range(-0.4, 0.9)  # mostly downward, sometimes up
	g["limbs"]["has_legs"] = rng.randf() < 0.55
	g["limbs"]["leg_count"] = 2
	g["limbs"]["leg_length"] = rng.randf_range(0.14, 0.30)
	g["limbs"]["leg_radius"] = rng.randf_range(0.045, 0.075)
	g["limbs"]["leg_spread"] = rng.randf_range(0.07, 0.14)
	g["limbs"]["foot_size"] = rng.randf_range(0.06, 0.11)
	# Mushrooms with legs need a slightly taller body offset so their feet
	# rest at floor level — record an offset the generator can apply.
	g["body"]["foot_offset"] = g["limbs"]["leg_length"] if g["limbs"]["has_legs"] else 0.0

	# 5) Palette — pick a base cap color from a curated set so it stays
	# "fungal" instead of randomly hideous. Stem tracks toward off-white.
	var cap_palette: Array = [
		Color(0.86, 0.25, 0.25),  # red
		Color(0.92, 0.55, 0.22),  # orange
		Color(0.85, 0.78, 0.32),  # yellow
		Color(0.40, 0.30, 0.55),  # purple
		Color(0.30, 0.55, 0.35),  # forest green
		Color(0.55, 0.32, 0.22),  # brown
		Color(0.92, 0.92, 0.92),  # white
		Color(0.18, 0.20, 0.24),  # slate
	]
	var cap_color: Color = cap_palette[rng.randi() % cap_palette.size()]
	g["palette"]["cap_color"] = cap_color
	# Spots = high-contrast complement of cap.
	if cap_color.get_luminance() < 0.5:
		g["palette"]["spot_color"] = Color(
			clampf(cap_color.r + rng.randf_range(0.4, 0.6), 0.0, 1.0),
			clampf(cap_color.g + rng.randf_range(0.4, 0.6), 0.0, 1.0),
			clampf(cap_color.b + rng.randf_range(0.4, 0.6), 0.0, 1.0)
		)
	else:
		g["palette"]["spot_color"] = Color(
			clampf(cap_color.r - rng.randf_range(0.4, 0.6), 0.0, 1.0),
			clampf(cap_color.g - rng.randf_range(0.4, 0.6), 0.0, 1.0),
			clampf(cap_color.b - rng.randf_range(0.4, 0.6), 0.0, 1.0)
		)
	g["palette"]["stem_color"] = Color(
		rng.randf_range(0.78, 0.95),
		rng.randf_range(0.72, 0.92),
		rng.randf_range(0.60, 0.82)
	)
	g["palette"]["eye_color"] = Color(rng.randf_range(0.02, 0.18), rng.randf_range(0.02, 0.18), rng.randf_range(0.02, 0.18))

	# 6) Animation — bob / lean speeds
	g["animation"]["bob_speed"] = rng.randf_range(1.0, 2.6)
	g["animation"]["bob_amplitude"] = rng.randf_range(0.02, 0.08)
	g["animation"]["idle_lean_speed"] = rng.randf_range(0.4, 1.4)
	g["animation"]["idle_lean_amplitude"] = rng.randf_range(1.0, 4.5)

	# 7) Mutation — rare glow (15%) + spore-burst radius bonus
	g["mutation"]["glow"] = rng.randf() < 0.15
	if g["mutation"]["glow"]:
		# Glow color biased toward the cap color shifted toward emission-ish hues.
		g["mutation"]["glow_color"] = cap_color.lerp(Color(0.4, 1.0, 0.6), 0.55)
	g["mutation"]["spore_burst_radius_bonus"] = rng.randf_range(-0.3, 0.7)

	# Apply genome (setter emits genome_changed → body rebuilds).
	genome = g
	# Cosmetic mirror for legacy ActorCard rendering.
	base_color = cap_color
	pattern_color = g["palette"]["spot_color"]

## The full module schema. All slots present; v1 generator reads cap+body+face.
static func default_genome() -> Dictionary:
	return {
		"cap": {
			"radius": 0.45,
			"height": 0.28,
			# Profile shape: "dome" (default), "flat", "cone", "bell"
			"profile": "dome",
			"spot_count": 5,
			"spot_radius": 0.06
		},
		"body": {
			# Stem dimensions.
			"height": 0.55,
			"radius_top": 0.16,
			"radius_bottom": 0.20,
			"segment_count": 6
		},
		"face": {
			"eye_count": 2,
			"eye_radius": 0.05,
			"eye_spread": 0.18,
			"eye_y_offset": 0.30,
			"mouth_width": 0.18,
			"mouth_height": 0.04,
			"mouth_y_offset": 0.20,
			# Expression: "smile" / "frown" / "o" / "smirk"
			"expression": "smile"
		},
		"surface": {
			"texture_hint": "matte",
			"roughness": 0.85,
			"emission": 0.0
		},
		"palette": {
			"cap_color": Color(0.86, 0.25, 0.25),
			"spot_color": Color(0.95, 0.95, 0.88),
			"stem_color": Color(0.93, 0.88, 0.74),
			"eye_color": Color(0.05, 0.05, 0.05),
			"mouth_color": Color(0.10, 0.05, 0.04)
		},
		"limbs": {
			"has_arms": false,
			"arm_count": 2,        # always 2 if has_arms
			"arm_length": 0.32,
			"arm_radius": 0.045,
			"arm_y_offset": 0.32,  # how high up the stem the arms attach
			"arm_droop": 0.0,      # -1 = arms up, 0 = T-pose, 1 = arms down
			"has_legs": false,
			"leg_count": 2,
			"leg_length": 0.22,
			"leg_radius": 0.06,
			"leg_spread": 0.10,    # how far apart the legs stand
			"foot_size": 0.08
		},
		"animation": {
			"bob_speed": 1.6,
			"bob_amplitude": 0.04,
			"idle_lean_speed": 0.8,
			"idle_lean_amplitude": 2.5  # degrees
		},
		"attack": {
			# Mirrors WeaponData fields. v1 reuses "Unarmed strike" as Fungal Bite.
			"name": "Fungal Bite",
			"reach": 1.4,
			"damage_die": "1d4",
			"damage_type": "piercing",
			"secondary_damage_type": "poison",
			"secondary_damage": 1.0
		},
		"mutation": {
			# Reserved: glow_color, spore_burst_radius_bonus, regeneration, etc.
			"glow": false,
			"glow_color": Color(0.4, 1.0, 0.6),
			"spore_burst_radius_bonus": 0.0
		},
		"grafted": {
			"source_species": "",
			# Mimic-source graft fields:
			"mimic_band_count": 0,
			"mimic_band_color": Color(0.58, 0.52, 0.44),
			"mimic_tooth_count": 0,
			"mimic_tooth_size": 0.03,
			"mimic_tooth_color": Color(0.95, 0.92, 0.85),
			"mimic_eye_color": Color(0.94, 0.18, 0.10),
			"mimic_glow": false,
			# Compound modular feature flags — independently rolled at
			# breeding time so siblings get visibly different combos:
			"has_band_graft": false,        # bands wrapping stem
			"has_tooth_graft": false,       # tooth ring around cap rim
			"has_extra_eyes_on_cap": false, # glowing mimic eyes on cap
			"has_lid_crown": false,         # tiny mimic lid on top of cap
			"has_gem_scatter": false,       # gems scattered across cap
			"extra_eye_count": 0,
			"extra_eye_radius": 0.04,
			"extra_eye_glow": true,
			# Goblin-source graft fields:
			"goblin_skin_color": Color(0.42, 0.66, 0.28),
			"goblin_pattern_intensity": 0.0,
			# Goat-source graft fields:
			"goat_horn_present": false,
			"goat_horn_color": Color(0.55, 0.40, 0.25)
		}
	}

## Override: create offspring with genome mixing.
##
## Hybrid behavior (anything-breeds-anything):
##   MushroomData × MushroomData -> MushroomData (genome crossover + mutation)
##   MushroomData × <other>      -> <other>.create_offspring(self) so the kid
##                                  takes after the body-plan of the partner.
##                                  The kid still gets mimic_blood via
##                                  ActorData.apply_mimic_lineage(), preserving
##                                  the breeding-probability gates.
func create_offspring(partner: ActorData) -> ActorData:
	# Same species → species-specific crossover. Everything else → universal
	# cross-species path. No bespoke per-pair hybrid functions remain.
	if partner == null:
		return null
	if partner is MushroomData:
		return _create_pure_mushroom_kid(partner as MushroomData)
	return ActorData.universal_crossover_breed(self, partner)

## Pure Mushroom × Mushroom (existing path, factored out).
func _create_pure_mushroom_kid(partner_mushroom: MushroomData) -> MushroomData:
	var kid := MushroomData.new()
	kid.creature_name = "Mushroomling"
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	kid.genome = _crossover_genome(genome, partner_mushroom.genome)
	kid.base_color = kid.genome["palette"]["cap_color"]
	kid.pattern_color = kid.genome["palette"]["spot_color"]
	kid.strength = (strength + partner_mushroom.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner_mushroom.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner_mushroom.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner_mushroom.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner_mushroom.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner_mushroom.charisma) * 0.5 * randf_range(0.9, 1.1)
	ActorData.apply_mimic_lineage(kid, self, partner_mushroom)
	return kid

# Bespoke per-pair hybrid helpers were removed. All cross-species breeding
# flows through ActorData.universal_crossover_breed which transfers limbs,
# palette, stats, and mutations from both parents to the kid.

func get_actor_type() -> String:
	return "MushroomData"

# --- Internal: genome crossover --------------------------------------------

## Per-slot crossover with small mutation. Each leaf field is pulled from
## either parent (50/50) and jittered ±10%. Color fields lerp between
## parents by a random factor. Booleans flip rarely (5% chance).
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
	return out

static func _crossover_field(a, b):
	if a is float or a is int:
		var picked = a if randf() < 0.5 else b
		# ±10% mutation
		return picked * randf_range(0.9, 1.1)
	if a is Color:
		return (a as Color).lerp(b as Color, randf())
	if a is bool:
		var picked = a if randf() < 0.5 else b
		if randf() < 0.05:  # rare mutation
			picked = not picked
		return picked
	if a is String or a is StringName:
		return a if randf() < 0.5 else b
	# Fallback: pick one.
	return a if randf() < 0.5 else b
