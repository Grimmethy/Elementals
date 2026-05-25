class_name CreatureBreeder

## Static utility — cross two CreatureDefinition parents into a new offspring.
##
## ── Relationship to the existing ActorData breeding system ───────────────────
## GoatData.create_offspring / MimicData._crossover_genome handle the game-
## layer concerns (stats, gold_value, mimic_blood, gender, etc.).
## CreatureBreeder handles the VISUAL / BODY phenotype — the CreatureDefinition
## properties that the procedural body generator reads to build meshes.
##
## In practice: after ActorData breeding resolves which species the kid is,
## call CreatureBreeder.breed(parent_a.definition, parent_b.definition) to
## decide what the kid looks like.  The result feeds directly into a
## CreatureGenerator so the kid's body appears in the world.
##
## ── How each property type is inherited ──────────────────────────────────────
##   float  → average of both parents × randf_range(1-jitter, 1+jitter)
##   Color  → Color.lerp at a random weight; rare per-channel mutation spike
##   int    → 50/50 pick from one parent, rare ±1 nudge; clamped to valid range
##   enum   → 50/50 pick from one parent; rare full re-roll within valid range
##   bool   → 50/50 pick from one parent; rare flip
##
## ── What does NOT breed ───────────────────────────────────────────────────────
##   detail_level — render quality, not a trait; offspring inherits parent_a's
##                  value.  Override via CreatureSerializer.create_variant().
##
## ── Mutation strength ─────────────────────────────────────────────────────────
##   0.0 → pure blend, no jitter (identical twins from same parents)
##   1.0 → default natural variation (BASE_FLOAT_JITTER ≈ ±8%)
##   2.0 → wild/feral — twice the scatter; useful for random spawn pools
##
## ── Validation ────────────────────────────────────────────────────────────────
##   Every output is clamped / corrected so CreatureSerializer.validate()
##   returns no errors on the result.

## Per-float magnitude of the jitter multiplier (scales with mutation_strength).
## 0.08 → each averaged float is then multiplied by randf in [0.92, 1.08].
const BASE_FLOAT_JITTER : float = 0.08

## Probability that a bool flips from the inherited parent value.
const BASE_BOOL_FLIP : float = 0.05

## Probability that an enum re-rolls to a completely random valid value
## instead of inheriting from one parent.
const BASE_ENUM_MUTATION : float = 0.04

## Per-channel Color mutation strength (added as ±delta to a random channel).
const BASE_COLOR_SPIKE : float = 0.06


# ==============================================================================
# Public API
# ==============================================================================

## Breed two CreatureDefinition parents and return a new offspring definition.
##
## The returned definition is NOT saved — call CreatureSerializer.save() if
## persistence is needed.
##
## Passing the same definition as both parents with mutation_strength = 0.0
## produces an exact copy (useful for cloning without duplicate_definition()).
static func breed(
		parent_a: CreatureDefinition,
		parent_b: CreatureDefinition,
		mutation_strength: float = 1.0) -> CreatureDefinition:

	assert(parent_a != null, "CreatureBreeder.breed — parent_a must not be null.")
	assert(parent_b != null, "CreatureBreeder.breed — parent_b must not be null.")

	var kid := CreatureDefinition.new()
	var ms  := maxf(mutation_strength, 0.0)

	# ── Structural / non-cosmetic ──────────────────────────────────────────────
	# detail_level is render quality, not a hereditary trait — keep parent_a.
	kid.detail_level = parent_a.detail_level

	# body_plan: dominant 50/50 inheritance, mutation deliberately excluded
	# (a biped × biped should not randomly produce a serpentine).
	kid.body_plan = parent_a.body_plan if randf() < 0.5 else parent_b.body_plan

	# ── Proportions ───────────────────────────────────────────────────────────
	kid.torso_height   = _float_pos(parent_a.torso_height,   parent_b.torso_height,   ms)
	kid.torso_width    = _float_pos(parent_a.torso_width,    parent_b.torso_width,    ms)
	kid.torso_depth    = _float_pos(parent_a.torso_depth,    parent_b.torso_depth,    ms)
	kid.limb_thickness = _float_pos(parent_a.limb_thickness, parent_b.limb_thickness, ms)
	kid.arm_length     = _float_pos(parent_a.arm_length,     parent_b.arm_length,     ms)
	kid.leg_length     = _float_pos(parent_a.leg_length,     parent_b.leg_length,     ms)
	kid.head_scale     = _float_pos(parent_a.head_scale,     parent_b.head_scale,     ms)

	# ── Posture (allow negative values — no floor clamp) ──────────────────────
	kid.spine_bend     = _float_free(parent_a.spine_bend,     parent_b.spine_bend,     ms)
	kid.neck_angle     = _float_free(parent_a.neck_angle,     parent_b.neck_angle,     ms)
	kid.shoulder_droop = _float_free(parent_a.shoulder_droop, parent_b.shoulder_droop, ms)

	# ── Head & face ───────────────────────────────────────────────────────────
	kid.head_shape  = _blend_enum(parent_a.head_shape,  parent_b.head_shape,
			CreatureDefinition.HeadShape.HORNED, ms)
	kid.snout_length = clampf(_float_free(parent_a.snout_length, parent_b.snout_length, ms), 0.0, 1.0)
	kid.eye_size    = _float_pos(parent_a.eye_size,    parent_b.eye_size,    ms)
	kid.eye_spacing = _float_pos(parent_a.eye_spacing, parent_b.eye_spacing, ms)
	kid.jaw_width   = _float_pos(parent_a.jaw_width,   parent_b.jaw_width,   ms)

	# ── Extras ────────────────────────────────────────────────────────────────
	kid.has_tail      = _blend_bool(parent_a.has_tail,      parent_b.has_tail,      ms)
	kid.tail_segments = _blend_int( parent_a.tail_segments, parent_b.tail_segments, ms, 1, 32)
	kid.tail_length   = _float_pos(parent_a.tail_length,   parent_b.tail_length,   ms)
	kid.has_wings     = _blend_bool(parent_a.has_wings,     parent_b.has_wings,     ms)
	kid.horn_count    = _blend_int( parent_a.horn_count,    parent_b.horn_count,    ms, 0, 8)

	# ── Appearance ────────────────────────────────────────────────────────────
	kid.body_color   = _blend_color(parent_a.body_color,   parent_b.body_color,   ms)
	kid.accent_color = _blend_color(parent_a.accent_color, parent_b.accent_color, ms)
	kid.eye_color    = _blend_color(parent_a.eye_color,    parent_b.eye_color,    ms)
	kid.roughness    = clampf(_float_free(parent_a.roughness, parent_b.roughness, ms), 0.0, 1.0)

	# ── Animation feel ────────────────────────────────────────────────────────
	kid.walk_speed                = _float_pos(parent_a.walk_speed,                parent_b.walk_speed,                ms)
	kid.bounce_amount             = maxf(0.0, _float_free(parent_a.bounce_amount,             parent_b.bounce_amount,             ms))
	kid.secondary_motion_strength = maxf(0.0, _float_free(parent_a.secondary_motion_strength, parent_b.secondary_motion_strength, ms))
	kid.step_height               = maxf(0.0, _float_free(parent_a.step_height,               parent_b.step_height,               ms))

	return kid


# ==============================================================================
# Private helpers
# ==============================================================================

## Average two positive floats, then multiply by a jitter factor centred on 1.
## Result is clamped to a small positive floor so proportions stay valid.
static func _float_pos(a: float, b: float, ms: float, floor: float = 0.01) -> float:
	var avg := (a + b) * 0.5
	if ms > 0.0:
		var jitter := BASE_FLOAT_JITTER * ms
		avg *= randf_range(1.0 - jitter, 1.0 + jitter)
	return maxf(floor, avg)


## Average two floats (may be zero or negative) with jitter.  No floor clamp.
static func _float_free(a: float, b: float, ms: float) -> float:
	var avg := (a + b) * 0.5
	if ms > 0.0:
		var jitter := BASE_FLOAT_JITTER * ms
		avg *= randf_range(1.0 - jitter, 1.0 + jitter)
	return avg


## Lerp two Colors at a random weight.  At high mutation strength there is a
## small chance one random channel receives an extra ±spike.
static func _blend_color(a: Color, b: Color, ms: float) -> Color:
	var t   := randf()
	var out := a.lerp(b, t)
	# Rare per-channel mutation — adds visual interest without gross colour shift
	if ms > 0.0 and randf() < 0.15 * ms:
		var ch  := randi() % 3                     # 0=R 1=G 2=B
		var mag := BASE_COLOR_SPIKE * ms * randf_range(-1.0, 1.0)
		match ch:
			0: out.r = clampf(out.r + mag, 0.0, 1.0)
			1: out.g = clampf(out.g + mag, 0.0, 1.0)
			2: out.b = clampf(out.b + mag, 0.0, 1.0)
	return out


## Pick one parent's int (50/50), then rarely nudge ±1.  Clamped to [lo, hi].
static func _blend_int(a: int, b: int, ms: float, lo: int, hi: int) -> int:
	var v := a if randf() < 0.5 else b
	if ms > 0.0 and randf() < 0.12 * ms:
		v += 1 if randf() < 0.5 else -1
	return clampi(v, lo, hi)


## Pick one parent's enum (50/50), then rarely roll a completely random value
## within [0, max_enum_value].
static func _blend_enum(a: int, b: int, max_enum_value: int, ms: float) -> int:
	var v := a if randf() < 0.5 else b
	if ms > 0.0 and randf() < BASE_ENUM_MUTATION * ms:
		v = randi() % (max_enum_value + 1)
	return v


## Pick one parent's bool (50/50), then rarely flip it.
static func _blend_bool(a: bool, b: bool, ms: float) -> bool:
	var v := a if randf() < 0.5 else b
	if ms > 0.0 and randf() < BASE_BOOL_FLIP * ms:
		v = not v
	return v
