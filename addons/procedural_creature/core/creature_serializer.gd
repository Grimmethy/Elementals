class_name CreatureSerializer

## Static utility class for saving, loading, and forking CreatureDefinition resources.
##
## ── Quick reference ──────────────────────────────────────────────────────────
##
##   # Validate before saving
##   var errors := CreatureSerializer.validate(def)
##   if errors.is_empty():
##       CreatureSerializer.save(def, "res://creatures/definitions/my_creature.tres")
##
##   # Load and check
##   var def := CreatureSerializer.load("res://creatures/definitions/my_creature.tres")
##   if def == null:
##       push_error("Load failed")
##
##   # Fork from a base with property overrides
##   var variant := CreatureSerializer.create_variant(base_def, {
##       "body_color":   Color(0.2, 0.5, 0.9),
##       "walk_speed":   1.5,
##       "has_tail":     true,
##       "tail_segments": 8,
##   })
##
## ── Path conventions ──────────────────────────────────────────────────────────
##   Editor / dev builds  →  res://creatures/definitions/…
##   Runtime-generated    →  user://creatures/…      (survives export, per-user)
##
## ── Why static ───────────────────────────────────────────────────────────────
##   No state needed.  Keeping it static means callers never have to add it to
##   the scene tree or keep a reference alive.

# ==============================================================================
# Public API
# ==============================================================================

## Validate a CreatureDefinition and return a (possibly empty) list of error
## strings.  An empty return means the definition is safe to save and use.
## Call this before save() and after create_variant() if you want early feedback.
static func validate(def: CreatureDefinition) -> Array[String]:
	var errors: Array[String] = []
	if def == null:
		errors.append("Definition is null.")
		return errors

	# ── Enum range checks ────────────────────────────────────────────────────
	if def.detail_level < 0 or def.detail_level > CreatureDefinition.DetailLevel.COMPLEX:
		errors.append("detail_level out of range (%d)." % def.detail_level)
	if def.body_plan < 0 or def.body_plan > CreatureDefinition.BodyPlan.CUSTOM:
		errors.append("body_plan out of range (%d)." % def.body_plan)
	if def.head_shape < 0 or def.head_shape > CreatureDefinition.HeadShape.HORNED:
		errors.append("head_shape out of range (%d)." % def.head_shape)

	# ── Proportions (all must be strictly positive) ──────────────────────────
	_check_positive(errors, def.torso_height,    "torso_height")
	_check_positive(errors, def.torso_width,     "torso_width")
	_check_positive(errors, def.torso_depth,     "torso_depth")
	_check_positive(errors, def.limb_thickness,  "limb_thickness")
	_check_positive(errors, def.arm_length,      "arm_length")
	_check_positive(errors, def.leg_length,      "leg_length")
	_check_positive(errors, def.head_scale,      "head_scale")

	# ── Head & face ──────────────────────────────────────────────────────────
	_check_positive(errors, def.eye_size,        "eye_size")
	_check_positive(errors, def.eye_spacing,     "eye_spacing")
	_check_positive(errors, def.jaw_width,       "jaw_width")
	_check_range(errors,    def.snout_length,    "snout_length",    0.0, 1.0)

	# ── Animation ────────────────────────────────────────────────────────────
	_check_positive(errors, def.walk_speed,      "walk_speed")
	_check_non_negative(errors, def.bounce_amount,           "bounce_amount")
	_check_non_negative(errors, def.secondary_motion_strength, "secondary_motion_strength")
	_check_non_negative(errors, def.step_height,             "step_height")

	# ── Appearance ───────────────────────────────────────────────────────────
	_check_range(errors, def.roughness, "roughness", 0.0, 1.0)

	# ── Tail ─────────────────────────────────────────────────────────────────
	if def.has_tail:
		if def.tail_segments < 1:
			errors.append("tail_segments must be >= 1 when has_tail is true (got %d)." % def.tail_segments)
		_check_positive(errors, def.tail_length, "tail_length")

	# ── Horns ────────────────────────────────────────────────────────────────
	if def.horn_count < 0:
		errors.append("horn_count must be >= 0 (got %d)." % def.horn_count)

	return errors


## Save a CreatureDefinition to disk.
## Returns OK on success, or ERR_INVALID_PARAMETER if validation fails,
## or any ResourceSaver error code on write failure.
##
## The parent directory is created automatically if it does not exist.
static func save(def: CreatureDefinition, path: String) -> Error:
	# Validate first — refuse to write a broken definition
	var errors := validate(def)
	if not errors.is_empty():
		for e in errors:
			push_warning("CreatureSerializer.save — validation error: %s" % e)
		return ERR_INVALID_PARAMETER

	# Ensure the target directory exists (works for both res:// and user://)
	var dir := path.get_base_dir()
	if not dir.is_empty():
		var da := DirAccess.open(dir)
		if da == null:
			var err := DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(dir)
			)
			if err != OK:
				push_error(
					"CreatureSerializer.save — could not create directory '%s' (error %d)." \
					% [dir, err]
				)
				return err

	var result := ResourceSaver.save(def, path)
	if result != OK:
		push_error(
			"CreatureSerializer.save — ResourceSaver.save failed for '%s' (error %d)." \
			% [path, result]
		)
	return result


## Load a CreatureDefinition from disk.
## Returns the typed resource, or null if the file is missing, the wrong type,
## or fails validation (errors are push_warning'd, not thrown).
static func load(path: String) -> CreatureDefinition:
	if not ResourceLoader.exists(path):
		push_error("CreatureSerializer.load — file not found: '%s'." % path)
		return null

	var res := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_REUSE)
	if res == null:
		push_error("CreatureSerializer.load — ResourceLoader returned null for '%s'." % path)
		return null

	if not res is CreatureDefinition:
		push_error(
			"CreatureSerializer.load — resource at '%s' is '%s', expected CreatureDefinition." \
			% [path, res.get_class()]
		)
		return null

	var def := res as CreatureDefinition

	# Non-fatal validation: warn but still return so callers can inspect / repair
	var errors := validate(def)
	for e in errors:
		push_warning("CreatureSerializer.load('%s') — validation warning: %s" % [path, e])

	return def


## Duplicate `base` and apply `overrides` (property-name → value pairs).
##
## Unknown property names are silently skipped (push_warning issued).
## Returns the new variant; does NOT save it — call save() separately.
##
##   var variant := CreatureSerializer.create_variant(base, {
##       "body_color": Color(0.1, 0.8, 0.3),
##       "walk_speed": 2.0,
##   })
static func create_variant(
		base: CreatureDefinition,
		overrides: Dictionary) -> CreatureDefinition:

	assert(base != null, "CreatureSerializer.create_variant — base must not be null.")

	var variant := base.duplicate_definition()

	for key: String in overrides:
		if not _has_property(variant, key):
			push_warning(
				"CreatureSerializer.create_variant — unknown property '%s', skipping." % key
			)
			continue
		variant.set(key, overrides[key])

	return variant


# ==============================================================================
# Private helpers
# ==============================================================================

static func _check_positive(errors: Array[String], value: float, name: String) -> void:
	if value <= 0.0:
		errors.append("%s must be > 0 (got %g)." % [name, value])


static func _check_non_negative(errors: Array[String], value: float, name: String) -> void:
	if value < 0.0:
		errors.append("%s must be >= 0 (got %g)." % [name, value])


static func _check_range(
		errors: Array[String],
		value: float,
		name: String,
		lo: float,
		hi: float) -> void:
	if value < lo or value > hi:
		errors.append("%s must be in [%g, %g] (got %g)." % [name, lo, hi, value])


static func _has_property(obj: Object, prop_name: String) -> bool:
	for prop in obj.get_property_list():
		if prop["name"] == prop_name:
			return true
	return false
