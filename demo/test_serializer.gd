## Phase 11 test — attach to the root Node in test_serializer_scene.tscn.
## Press F6 to run.  All output appears in the Output panel — no viewport needed.
##
## What this exercises:
##   1. validate()        — clean def passes; mutated def lists errors correctly
##   2. save()            — writes a .tres to user://creatures/
##   3. load()            — reads it back; confirms type and property round-trip
##   4. create_variant()  — overrides apply; unknown key warns but doesn't crash
##   5. load() on missing — returns null gracefully with push_error
##   6. save() with bad def — refused with push_warning, returns ERR_INVALID_PARAMETER
extends Node

const SAVE_PATH := "user://creatures/test_variant.tres"

func _ready() -> void:
	print("─── Phase 11: Serializer ───────────────────────────────────────")

	# ── 1. Validate a clean definition ──────────────────────────────────────
	var base := CreatureDefinition.new()   # all defaults — should be clean
	var errors := CreatureSerializer.validate(base)
	_expect("1a  clean def → 0 errors", errors.is_empty(),
			"got errors: %s" % str(errors))

	# ── 2. Validate a broken definition ─────────────────────────────────────
	var bad := CreatureDefinition.new()
	bad.torso_height   = -1.0   # must be > 0
	bad.walk_speed     = 0.0    # must be > 0
	bad.roughness      = 2.5    # must be in [0,1]
	bad.has_tail       = true
	bad.tail_segments  = 0      # must be >= 1 when has_tail
	bad.horn_count     = -3     # must be >= 0
	var bad_errors := CreatureSerializer.validate(bad)
	_expect("2a  broken def → 5+ errors", bad_errors.size() >= 5,
			"got %d errors: %s" % [bad_errors.size(), str(bad_errors)])
	print("    Errors reported:")
	for e in bad_errors:
		print("      • ", e)

	# ── 3. save() with bad def — should refuse ───────────────────────────────
	var save_result := CreatureSerializer.save(bad, SAVE_PATH)
	_expect("3a  save(bad) → ERR_INVALID_PARAMETER",
			save_result == ERR_INVALID_PARAMETER,
			"got error code %d" % save_result)

	# ── 4. create_variant() ──────────────────────────────────────────────────
	var overrides := {
		"body_color":    Color(0.1, 0.8, 0.3),
		"walk_speed":    2.0,
		"has_tail":      true,
		"tail_segments": 8,
		"tail_length":   1.5,
	}
	var variant := CreatureSerializer.create_variant(base, overrides)
	_expect("4a  variant body_color",
			variant.body_color.is_equal_approx(Color(0.1, 0.8, 0.3)),
			"got %s" % str(variant.body_color))
	_expect("4b  variant walk_speed == 2.0",
			is_equal_approx(variant.walk_speed, 2.0),
			"got %g" % variant.walk_speed)
	_expect("4c  variant has_tail == true",
			variant.has_tail == true, "got false")
	_expect("4d  variant tail_segments == 8",
			variant.tail_segments == 8,
			"got %d" % variant.tail_segments)
	_expect("4e  base unchanged (walk_speed still 1.0)",
			is_equal_approx(base.walk_speed, 1.0),
			"got %g" % base.walk_speed)

	# ── 5. Unknown override key — should warn, not crash ─────────────────────
	print("    (expect a push_warning about 'nonexistent_key' below)")
	var v2 := CreatureSerializer.create_variant(base, {"nonexistent_key": 99})
	_expect("5a  unknown key doesn't crash", v2 != null, "returned null")

	# ── 6. save() the clean variant ──────────────────────────────────────────
	_ensure_dir("user://creatures")
	var ok := CreatureSerializer.save(variant, SAVE_PATH)
	_expect("6a  save() → OK", ok == OK, "error code %d" % ok)
	_expect("6b  file exists after save",
			ResourceLoader.exists(SAVE_PATH), "file missing at %s" % SAVE_PATH)

	# ── 7. load() round-trip ─────────────────────────────────────────────────
	var loaded := CreatureSerializer.load(SAVE_PATH)
	_expect("7a  load() returns CreatureDefinition", loaded != null, "returned null")
	if loaded != null:
		_expect("7b  walk_speed round-trips",
				is_equal_approx(loaded.walk_speed, 2.0),
				"got %g" % loaded.walk_speed)
		_expect("7c  tail_segments round-trips",
				loaded.tail_segments == 8,
				"got %d" % loaded.tail_segments)
		_expect("7d  body_color round-trips",
				loaded.body_color.is_equal_approx(Color(0.1, 0.8, 0.3)),
				"got %s" % str(loaded.body_color))

	# ── 8. load() missing file ───────────────────────────────────────────────
	print("    (expect a push_error about missing file below)")
	var missing := CreatureSerializer.load("user://creatures/does_not_exist.tres")
	_expect("8a  load(missing) → null", missing == null, "returned non-null")

	# ── Done ─────────────────────────────────────────────────────────────────
	print("─── All Serializer tests complete ─────────────────────────────")


# ==============================================================================
# Helpers
# ==============================================================================

func _expect(label: String, cond: bool, fail_detail: String = "") -> void:
	if cond:
		print("  ✓  ", label)
	else:
		var detail := (" → " + fail_detail) if not fail_detail.is_empty() else ""
		print("  ✗  FAIL  ", label, detail)


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
