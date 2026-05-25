## Phase 12 test — attach to the root Node in test_breeder_scene.tscn.
## Press F6 to run.  All output appears in the Output panel — no viewport needed.
##
## What this exercises:
##   1. Basic breed()          — offspring properties fall between the two parents
##   2. Mutation scaling       — mutation_strength=0 → no jitter; >0 → variation
##   3. Bool / enum crossover  — has_tail, has_wings, head_shape inherit from parents
##   4. Color blending         — offspring color is between parent colors
##   5. Validate passes        — every offspring satisfies CreatureSerializer.validate()
##   6. Trait drift over N generations — floats gradually drift under repeated breeding
##   7. Zero-mutation clone    — ms=0, same parent twice → nearly identical result
extends Node

func _ready() -> void:
	print("─── Phase 12: Breeder ──────────────────────────────────────────")

	# ── Build two distinct parent definitions ────────────────────────────────
	var parent_a := CreatureDefinition.new()
	parent_a.torso_height   = 1.2
	parent_a.leg_length     = 1.1
	parent_a.arm_length     = 0.9
	parent_a.walk_speed     = 0.8
	parent_a.body_color     = Color(1.0, 0.2, 0.2)   # red
	parent_a.eye_color      = Color(0.0, 0.0, 1.0)   # blue eyes
	parent_a.has_tail       = true
	parent_a.tail_segments  = 10
	parent_a.tail_length    = 1.5
	parent_a.has_wings      = false
	parent_a.head_shape     = CreatureDefinition.HeadShape.ROUND

	var parent_b := CreatureDefinition.new()
	parent_b.torso_height   = 0.8
	parent_b.leg_length     = 0.7
	parent_b.arm_length     = 1.1
	parent_b.walk_speed     = 1.8
	parent_b.body_color     = Color(0.2, 0.2, 1.0)   # blue
	parent_b.eye_color      = Color(1.0, 1.0, 0.0)   # yellow eyes
	parent_b.has_tail       = false
	parent_b.has_wings      = true
	parent_b.head_shape     = CreatureDefinition.HeadShape.ANGULAR

	# ── 1. Basic breed — offspring should land between parents on float props ─
	print("\n[1] Basic blend (mutation_strength=1.0, 100 offspring sample)")
	var torso_sum  := 0.0
	var speed_sum  := 0.0
	var N          := 100
	for i in range(N):
		var kid := CreatureBreeder.breed(parent_a, parent_b, 1.0)
		torso_sum += kid.torso_height
		speed_sum += kid.walk_speed
	var avg_torso := torso_sum / N
	var avg_speed := speed_sum / N
	# averages should be near the midpoint (1.0 and 1.3) ± mutation scatter
	_expect("1a  avg torso_height near 1.0 [0.7, 1.3]",
			avg_torso >= 0.7 and avg_torso <= 1.3,
			"got %.3f" % avg_torso)
	_expect("1b  avg walk_speed near 1.3 [0.9, 1.7]",
			avg_speed >= 0.9 and avg_speed <= 1.7,
			"got %.3f" % avg_speed)

	# ── 2. Zero-mutation clone ───────────────────────────────────────────────
	print("\n[2] Zero-mutation clone (same parent × same parent, ms=0.0)")
	var clone := CreatureBreeder.breed(parent_a, parent_a, 0.0)
	_expect("2a  torso_height == parent_a",
			is_equal_approx(clone.torso_height, parent_a.torso_height),
			"got %g vs %g" % [clone.torso_height, parent_a.torso_height])
	_expect("2b  walk_speed == parent_a",
			is_equal_approx(clone.walk_speed, parent_a.walk_speed),
			"got %g vs %g" % [clone.walk_speed, parent_a.walk_speed])
	_expect("2c  body_color == parent_a",
			clone.body_color.is_equal_approx(parent_a.body_color),
			"got %s" % str(clone.body_color))

	# ── 3. Bool / enum inheritance — sample 200, check frequencies ──────────
	print("\n[3] Bool / enum crossover (200 offspring)")
	var tail_true_count := 0
	var wings_true_count := 0
	var round_count := 0
	var angular_count := 0
	var other_shape_count := 0
	for i in range(200):
		var kid := CreatureBreeder.breed(parent_a, parent_b, 1.0)
		if kid.has_tail:  tail_true_count  += 1
		if kid.has_wings: wings_true_count += 1
		match kid.head_shape:
			CreatureDefinition.HeadShape.ROUND:   round_count   += 1
			CreatureDefinition.HeadShape.ANGULAR: angular_count += 1
			_: other_shape_count += 1
	print("    has_tail=true: %d/200  (parent_a=true, parent_b=false)" % tail_true_count)
	print("    has_wings=true: %d/200 (parent_a=false, parent_b=true)" % wings_true_count)
	print("    head ROUND: %d  ANGULAR: %d  other (mutation): %d" \
			% [round_count, angular_count, other_shape_count])
	# Each bool should appear roughly half the time from genetic inheritance
	_expect("3a  has_tail ≈50/50 [60, 140]",
			tail_true_count >= 60 and tail_true_count <= 140,
			"got %d/200" % tail_true_count)
	_expect("3b  has_wings ≈50/50 [60, 140]",
			wings_true_count >= 60 and wings_true_count <= 140,
			"got %d/200" % wings_true_count)
	# ROUND + ANGULAR should dominate; a few mutations may land elsewhere
	_expect("3c  ROUND+ANGULAR >= 90% of offspring",
			(round_count + angular_count) >= 180,
			"got %d/200" % (round_count + angular_count))

	# ── 4. Color blending ────────────────────────────────────────────────────
	print("\n[4] Color blending")
	var kid_color := CreatureBreeder.breed(parent_a, parent_b, 0.0).body_color
	# With ms=0 the color is pure lerp — must be between red and blue
	_expect("4a  offspring red channel in [0.2, 1.0]",
			kid_color.r >= 0.2 and kid_color.r <= 1.0,
			"got %.3f" % kid_color.r)
	_expect("4b  offspring blue channel in [0.2, 1.0]",
			kid_color.b >= 0.2 and kid_color.b <= 1.0,
			"got %.3f" % kid_color.b)

	# ── 5. Validate passes for every offspring ───────────────────────────────
	print("\n[5] Validate() passes for 50 offspring at various mutation levels")
	var fail_count := 0
	for i in range(50):
		var ms  := randf_range(0.0, 3.0)
		var kid := CreatureBreeder.breed(parent_a, parent_b, ms)
		var errors := CreatureSerializer.validate(kid)
		if not errors.is_empty():
			fail_count += 1
			print("  ✗  ms=%.2f → %d errors: %s" % [ms, errors.size(), str(errors)])
	_expect("5a  0 validation failures across 50 random-ms offspring",
			fail_count == 0, "%d failures" % fail_count)

	# ── 6. Tail coherence: has_tail=false → tail fields don't matter, but if ─
	#     has_tail=true the offspring should pass tail validation
	print("\n[6] Tail coherence — offspring with has_tail=true have valid tail fields")
	var tail_fail := 0
	for i in range(100):
		var kid := CreatureBreeder.breed(parent_a, parent_b, 1.0)
		if kid.has_tail:
			var errs := CreatureSerializer.validate(kid)
			for e in errs:
				if "tail" in e:
					tail_fail += 1
	_expect("6a  No tail-field validation errors across tailed offspring",
			tail_fail == 0, "%d errors" % tail_fail)

	# ── 7. Trait drift — 10 sequential generations from the same two parents ─
	print("\n[7] Trait drift — 10 generations (parent_a × parent_b repeatedly)")
	var gen := parent_a.duplicate_definition()
	for g in range(10):
		gen = CreatureBreeder.breed(gen, parent_b, 1.0)
	print("    Gen-10 torso_height: %.3f  (A=%.2f  B=%.2f)" \
			% [gen.torso_height, parent_a.torso_height, parent_b.torso_height])
	print("    Gen-10 walk_speed:   %.3f  (A=%.2f  B=%.2f)" \
			% [gen.walk_speed, parent_a.walk_speed, parent_b.walk_speed])
	_expect("7a  Gen-10 is still a valid definition",
			CreatureSerializer.validate(gen).is_empty(), "failed validate")

	print("\n─── All Breeder tests complete ─────────────────────────────────")


# ==============================================================================
# Helpers
# ==============================================================================

func _expect(label: String, cond: bool, fail_detail: String = "") -> void:
	if cond:
		print("  ✓  ", label)
	else:
		var detail := (" → " + fail_detail) if not fail_detail.is_empty() else ""
		print("  ✗  FAIL  ", label, detail)
