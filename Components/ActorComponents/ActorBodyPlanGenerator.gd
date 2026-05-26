class_name ActorBodyPlanGenerator
extends RefCounted

## Per-category body-plan generator. Given an actor type name from
## ActorTypeData (e.g. "Wolf", "Skeleton", "Fire Dragon"), produces a fully-
## populated shared_body_plan dict that the universal procedural body renderer
## (ProceduralCreatureBody) can consume.
##
## Dispatch by category (Beast, Humanoid, Dragon, Undead, ...). Each category
## has a template function that fills the dict with sensible defaults for that
## archetype. Per-species variation comes from `body_plan_modifiers` on the
## ActorTypeData entry, which are applied as a final overlay step.
##
## This is the single bridge between the D&D Monster Manual data
## (ActorTypeData.gd + ActorTypes/*Data.gd) and the visual renderer. New
## monsters need no code — just an entry in their category's data file.
##
## All randomness uses a seeded RandomNumberGenerator so the same actor_type
## + render_seed produces the same body plan every time.

## Generate a complete shared_body_plan dict for the given actor type.
##
## Combines three layers of variation:
##   1. Category template (Beast / Humanoid / Dragon / ...) — broad anatomy
##   2. Sub-template variant (wolf_like / bear_like / ...) — per-species shape
##   3. Species RNG — deterministic per-species rolls (palette, dimensions)
## Plus optional `body_plan_modifiers` overlay from ActorTypeData entry.
## Plus a size-class scale multiplier derived from HP (Tiny / Small / ...).
##
## See `Markdowns/Plans/PerCreatureBodyMath.md` for the design.
##
## [actor_type] Species name. Must match a key in ActorTypeData.
## [render_seed] Determinism seed for instance jitter. Same seed = same look.
## [Returns] A Dictionary matching ActorData.default_shared_body_plan() schema.
static func generate(actor_type: String, render_seed: int) -> Dictionary:
	# Instance-level RNG (varies per individual creature).
	var rng := RandomNumberGenerator.new()
	rng.seed = render_seed if render_seed != 0 else randi()
	# Species-stable RNG (same species → same dimensions / palette family).
	var species_rng: RandomNumberGenerator = CreatureSignatures.species_rng(actor_type)
	var category: String = ActorTypeData.get_category(actor_type)
	var defaults: Dictionary = ActorTypeData.get_defaults(actor_type)
	# Resolve sub-template (wolf_like, bear_like, etc.).
	var sub_template: String = CreatureSignatures.sub_template_for(actor_type, category, defaults)
	# Build the plan via category template, varied by sub-template + species_rng.
	var plan: Dictionary = _template_for_category(category, rng, species_rng, sub_template, defaults)
	# CRITICAL: embed sub_template in plan metadata so body / head builders can
	# branch on it. Without this, _build_quadruped_torso renders Wolf and Bear
	# as the same capsule shape — only colors differ. With it, builders can
	# produce visually distinct meshes (lean capsule vs stout box, etc.).
	if not plan.has("meta"):
		plan["meta"] = {}
	plan["meta"]["sub_template"] = sub_template
	plan["meta"]["category"] = category
	plan["meta"]["species"] = actor_type
	# Stash the element type — used by _build_elemental to branch fire/water/earth/air.
	plan["meta"]["element_type"] = String(defaults.get("element_type", "none"))
	# Stash render_seed so hand-built mesh builders can derive per-individual
	# variation (e.g. pig fat/skinny/spot count) deterministically — same seed
	# = same pig look across rebuilds.
	plan["meta"]["render_seed"] = render_seed
	# Apply size class scale (Tiny = 0.45x, Huge = 2.3x, Gargantuan = 3.4x).
	var size_class: int = CreatureSignatures.size_class_for(defaults)
	var scale: float = CreatureSignatures.size_scale(size_class)
	if not is_equal_approx(scale, 1.0) and plan.has("base"):
		_apply_size_scale(plan, scale)
	# Overlay species-level modifiers from the actor type entry, if any.
	var modifiers: Variant = defaults.get("body_plan_modifiers", {})
	if modifiers is Dictionary:
		_apply_modifiers(plan, modifiers as Dictionary)
	return plan

## Apply a uniform scale to all body dimensions, including limb lengths.
## Used to honor size class.
static func _apply_size_scale(plan: Dictionary, scale: float) -> void:
	if plan.has("base"):
		var base: Dictionary = plan["base"]
		for axis in ["width", "height", "depth"]:
			if base.has(axis):
				base[axis] = float(base[axis]) * scale
	if plan.has("limbs"):
		var limbs: Dictionary = plan["limbs"]
		for key in ["arm_length", "arm_radius", "leg_length", "leg_radius", "leg_spread", "foot_size"]:
			if limbs.has(key):
				limbs[key] = float(limbs[key]) * scale

## Dispatch to the per-category template function, passing the sub-template.
static func _template_for_category(category: String, rng: RandomNumberGenerator, species_rng: RandomNumberGenerator, sub_template: String, defaults: Dictionary) -> Dictionary:
	match category:
		"Beast":       return _template_beast(rng, species_rng, sub_template, defaults)
		"Humanoid":    return _template_humanoid(rng, defaults)
		"Plant":       return _template_plant(rng, defaults)
		"Construct":   return _template_construct(rng, defaults)
		"Dragon":      return _template_dragon(rng, defaults)
		"Undead":      return _template_undead(rng, defaults)
		"Ooze":        return _template_ooze(rng, defaults)
		"Aberration":  return _template_aberration(rng, defaults)
		"Fey":         return _template_fey(rng, defaults)
		"Fiend":       return _template_fiend(rng, defaults)
		"Giant":       return _template_giant(rng, defaults)
		"Elemental":   return _template_elemental(rng, defaults)
		"Celestial":   return _template_celestial(rng, defaults)
		"Monstrosity": return _template_monstrosity(rng, defaults)
		_:             return _template_beast(rng, species_rng, sub_template, defaults)

# ============================================================================
# CORE TEMPLATES (4 fully-implemented)
# ============================================================================

## Beast — quadruped/biped baseline with sub-template variations. Each sub-
## template (wolf_like, bear_like, etc.) produces distinctly different
## proportions. Species-level RNG ensures Wolves always look like Wolves.
##
## Sub-templates:
##   wolf_like      — lean quadruped, long muzzle (Wolf, Tiger, Fox, Lion)
##   bear_like      — bulky quadruped, short legs (Bear, Boar, Ox, Mammoth)
##   small_animal   — tiny quadruped, low body (Cat, Rat, Weasel, Badger)
##   small_quadruped — sheep/goat-sized (Goat, Sheep, Deer)
##   dinosaur_like  — biped, long tail, big head (T-Rex, Velociraptor)
##   lizard_like    — low-slung quadruped, long tail (Crocodile, Triceratops)
##   bird_like      — biped with wings, small head (Hawk, Eagle, Chicken)
##   serpent_like   — long body, no legs (Snake, Sandworm, Earthworm)
##   insect_like    — many legs, segmented (Spider, Centipede, Scorpion)
static func _template_beast(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator, sub_template: String, _defaults: Dictionary) -> Dictionary:
	match sub_template:
		"wolf_like":      return _beast_wolf_like(rng, species_rng)
		"bear_like":      return _beast_bear_like(rng, species_rng)
		"small_animal":   return _beast_small_animal(rng, species_rng)
		"small_quadruped": return _beast_small_quadruped(rng, species_rng)
		"dinosaur_like":  return _beast_dinosaur_like(rng, species_rng)
		"lizard_like":    return _beast_lizard_like(rng, species_rng)
		"bird_like":      return _beast_bird_like(rng, species_rng)
		"serpent_like":   return _beast_serpent_like(rng, species_rng)
		"insect_like":    return _beast_insect_like(rng, species_rng)
		_:                return _beast_wolf_like(rng, species_rng)  # default

## Wolf-like — lean quadruped with long muzzle. Wolf, Tiger, Lion, Fox.
## Distinguishing: depth > width (long body), tall thin legs.
static func _beast_wolf_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "quadruped_torso",
			"width": species_rng.randf_range(0.55, 0.70) * rng.randf_range(0.95, 1.05),
			"height": species_rng.randf_range(0.40, 0.52) * rng.randf_range(0.95, 1.05),
			"depth": species_rng.randf_range(1.10, 1.55) * rng.randf_range(0.95, 1.05),
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.85, 1.05),
			"height": 0.38,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.042,
			"eye_glow": false,
			"mouth_style": "maw_horizontal", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": true, "leg_count": 4,
			"leg_length": species_rng.randf_range(0.36, 0.48),
			"leg_radius": 0.06,
			"leg_spread": species_rng.randf_range(0.22, 0.28),
			"foot_size": 0.08,
		},
		"ornaments": { "tags": ["tail"] },
		"palette": _beast_palette(species_rng),
	}

## Bear-like — bulky quadruped, thick body, short legs. Bear, Boar, Ox.
## Distinguishing: width ≈ depth (chunky), shorter legs.
static func _beast_bear_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "quadruped_torso",
			"width": species_rng.randf_range(0.85, 1.10) * rng.randf_range(0.95, 1.05),
			"height": species_rng.randf_range(0.65, 0.85) * rng.randf_range(0.95, 1.05),
			"depth": species_rng.randf_range(1.10, 1.40) * rng.randf_range(0.95, 1.05),
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(1.00, 1.25),  # bigger head
			"height": 0.42,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.05,
			"eye_glow": false,
			"mouth_style": "maw_horizontal", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": true, "leg_count": 4,
			"leg_length": species_rng.randf_range(0.26, 0.36),  # SHORT
			"leg_radius": 0.10,                                  # THICK
			"leg_spread": species_rng.randf_range(0.30, 0.38),
			"foot_size": 0.12,
		},
		"ornaments": { "tags": ["tail"] },
		"palette": _beast_palette(species_rng),
	}

## Small animal — tiny quadruped, low to the ground. Cat, Rat, Weasel.
static func _beast_small_animal(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "quadruped_torso",
			"width": species_rng.randf_range(0.28, 0.40) * rng.randf_range(0.95, 1.05),
			"height": species_rng.randf_range(0.22, 0.30) * rng.randf_range(0.95, 1.05),
			"depth": species_rng.randf_range(0.55, 0.85) * rng.randf_range(0.95, 1.05),
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.90, 1.10),
			"height": 0.22,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.030,
			"eye_glow": false,
			"mouth_style": "single", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": true, "leg_count": 4,
			"leg_length": species_rng.randf_range(0.16, 0.24),  # very short
			"leg_radius": 0.035,
			"leg_spread": species_rng.randf_range(0.12, 0.18),
			"foot_size": 0.05,
		},
		"ornaments": { "tags": ["tail"] },
		"palette": _beast_palette(species_rng),
	}

## Small quadruped (between small_animal and wolf_like in size). Goat, Sheep.
static func _beast_small_quadruped(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "quadruped_torso",
			"width": species_rng.randf_range(0.42, 0.55),
			"height": species_rng.randf_range(0.35, 0.45),
			"depth": species_rng.randf_range(0.80, 1.05),
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.80, 1.00),
			"height": 0.28,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.038,
			"eye_glow": false,
			"mouth_style": "single", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": true, "leg_count": 4,
			"leg_length": species_rng.randf_range(0.30, 0.40),
			"leg_radius": 0.055,
			"leg_spread": species_rng.randf_range(0.18, 0.24),
			"foot_size": 0.07,
		},
		"ornaments": { "tags": ["tail"] },
		"palette": _beast_palette(species_rng),
	}

## Dinosaur-like — bipedal, long tail, big head. T-Rex, Velociraptor.
static func _beast_dinosaur_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "biped_torso",
			"width": species_rng.randf_range(0.55, 0.85),
			"height": species_rng.randf_range(0.85, 1.30),
			"depth": species_rng.randf_range(0.65, 0.95),  # deeper than humanoid (long torso)
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(1.10, 1.45),  # big head
			"height": 0.48,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.05,
			"eye_glow": false,
			"mouth_style": "maw_horizontal", "tongue_present": false,
		},
		"limbs": {
			"has_arms": true, "arm_count": 2,
			"arm_length": species_rng.randf_range(0.18, 0.30),  # tiny arms
			"arm_radius": 0.04,
			"has_legs": true, "leg_count": 2,
			"leg_length": species_rng.randf_range(0.55, 0.75),  # long powerful legs
			"leg_radius": 0.12,
			"leg_spread": species_rng.randf_range(0.18, 0.24),
			"foot_size": 0.15,
		},
		"ornaments": { "tags": ["tail"] },
		"palette": _beast_palette(species_rng),
	}

## Lizard-like — low-slung quadruped, long tail. Crocodile, Triceratops.
static func _beast_lizard_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "quadruped_torso",
			"width": species_rng.randf_range(0.60, 0.85),
			"height": species_rng.randf_range(0.30, 0.45),  # low body
			"depth": species_rng.randf_range(1.30, 1.85),   # very long
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.95, 1.15),
			"height": 0.36,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.04,
			"eye_glow": false,
			"mouth_style": "maw_horizontal", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": true, "leg_count": 4,
			"leg_length": species_rng.randf_range(0.18, 0.28),  # short, splayed
			"leg_radius": 0.06,
			"leg_spread": species_rng.randf_range(0.32, 0.42),
			"foot_size": 0.09,
		},
		"ornaments": { "tags": ["tail", "spike_ridge" if species_rng.randf() < 0.4 else "tail"] },
		"palette": _beast_palette(species_rng),
	}

## Bird-like — biped with wings. Hawk, Eagle, Chicken.
static func _beast_bird_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "biped_torso",
			"width": species_rng.randf_range(0.35, 0.55),
			"height": species_rng.randf_range(0.45, 0.75),
			"depth": species_rng.randf_range(0.30, 0.50),
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.70, 0.95),  # small bird head
			"height": 0.22,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.035,
			"eye_glow": false,
			"mouth_style": "single", "tongue_present": false,  # beak
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,  # wings handled by ornament
			"has_legs": true, "leg_count": 2,
			"leg_length": species_rng.randf_range(0.35, 0.55),  # tall bird legs
			"leg_radius": 0.05,
			"leg_spread": species_rng.randf_range(0.10, 0.16),
			"foot_size": 0.07,
		},
		"ornaments": { "tags": ["wings", "tail"] },
		"palette": _beast_palette(species_rng),
	}

## Serpent-like — long body, no legs. Snake, Sandworm.
static func _beast_serpent_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base": {
			"type": "quadruped_torso",  # use elongated quadruped as serpent body
			"width": species_rng.randf_range(0.28, 0.42),
			"height": species_rng.randf_range(0.25, 0.38),
			"depth": species_rng.randf_range(1.80, 2.60),  # very long
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.95, 1.15),
			"height": 0.20,
		},
		"face": {
			"eye_count": 2, "eye_radius": 0.035,
			"eye_glow": species_rng.randf() < 0.3,
			"mouth_style": "maw_horizontal", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": false, "leg_count": 0,  # NO LEGS
		},
		"ornaments": { "tags": [] },
		"palette": _beast_palette(species_rng),
	}

## Insect-like — many legs, segmented body. Spider, Centipede, Scorpion.
static func _beast_insect_like(rng: RandomNumberGenerator, species_rng: RandomNumberGenerator) -> Dictionary:
	var leg_count: int = [6, 8, 8, 8][species_rng.randi() % 4]  # most are spiders
	return {
		"base": {
			"type": "quadruped_torso",
			"width": species_rng.randf_range(0.45, 0.75),
			"height": species_rng.randf_range(0.30, 0.45),
			"depth": species_rng.randf_range(0.55, 1.00),
		},
		"top": {
			"type": "head_beast",
			"size_factor": species_rng.randf_range(0.60, 0.85),
			"height": 0.18,
		},
		"face": {
			"eye_count": [4, 6, 8][species_rng.randi() % 3],  # cluster of eyes
			"eye_radius": 0.025,
			"eye_glow": species_rng.randf() < 0.4,
			"mouth_style": "maw_vertical", "tongue_present": false,
		},
		"limbs": {
			"has_arms": false, "arm_count": 0,
			"has_legs": true, "leg_count": leg_count,
			"leg_length": species_rng.randf_range(0.30, 0.45),
			"leg_radius": 0.035,
			"leg_spread": species_rng.randf_range(0.30, 0.42),
			"foot_size": 0.04,
		},
		"ornaments": { "tags": ["chitin_plate" if species_rng.randf() < 0.5 else "tail"] },
		"palette": _beast_palette(species_rng),
	}

## Humanoid — biped baseline. Goblins, orcs, bandits, knights, mages.
## Total figure: ~1.3-1.6 units tall (legs + torso + head).
static func _template_humanoid(rng: RandomNumberGenerator, _defaults: Dictionary) -> Dictionary:
	return {
		"base": {
			"type": "biped_torso",
			"width": rng.randf_range(0.45, 0.60),
			"height": rng.randf_range(0.75, 0.95),       # torso height (above legs)
			"depth": rng.randf_range(0.30, 0.45)
		},
		"top": {
			"type": "head_humanoid",
			"size_factor": rng.randf_range(0.90, 1.15),
			"height": 0.32
		},
		"face": {
			"eye_count": 2,
			"eye_radius": 0.04,
			"eye_glow": false,
			"mouth_style": "single",
			"tongue_present": false
		},
		"limbs": {
			"has_arms": true,
			"arm_count": 2,
			"arm_length": rng.randf_range(0.40, 0.55),   # arms reach down past hips
			"arm_radius": 0.06,
			"has_legs": true,
			"leg_count": 2,
			"leg_length": rng.randf_range(0.40, 0.55),
			"leg_radius": 0.07,
			"leg_spread": rng.randf_range(0.10, 0.16),   # narrow hip stance
			"foot_size": 0.08
		},
		"ornaments": {
			"tags": [],
			"primary_color": Color(0.55, 0.45, 0.35),
			"secondary_color": Color(0.42, 0.32, 0.22)
		},
		"palette": _humanoid_palette(rng)
	}

## Plant — sessile (no legs). Trunk rises from ground, foliage cap on top.
## Some plants get arm-vines.
static func _template_plant(rng: RandomNumberGenerator, _defaults: Dictionary) -> Dictionary:
	return {
		"base": {
			"type": "cylinder",
			"width": rng.randf_range(0.45, 0.65),
			"height": rng.randf_range(0.80, 1.40),
			"depth": rng.randf_range(0.45, 0.65)
		},
		"top": {
			"type": "dome",
			"size_factor": rng.randf_range(1.3, 1.9),
			"height": 0.45
		},
		"face": {
			"eye_count": rng.randi_range(1, 3),
			"eye_radius": 0.05,
			"eye_glow": false,
			"mouth_style": "maw_horizontal",
			"tongue_present": false
		},
		"limbs": {
			"has_arms": rng.randf() < 0.6,
			"arm_count": 2,
			"arm_length": rng.randf_range(0.30, 0.45),
			"arm_radius": 0.05,
			"has_legs": false,
			"leg_count": 0
		},
		"ornaments": {
			"tags": ["flowering_accents"],
			"primary_color": Color(0.35, 0.50, 0.20),
			"secondary_color": Color(0.20, 0.32, 0.12)
		},
		"palette": _plant_palette(rng)
	}

## Construct — angular cube body, metallic, glowing eyes. Iron golems,
## animated armor, scarecrows (oversized scale).
static func _template_construct(rng: RandomNumberGenerator, _defaults: Dictionary) -> Dictionary:
	return {
		"base": {
			"type": "cube",
			"width": rng.randf_range(0.55, 0.80),
			"height": rng.randf_range(0.90, 1.20),
			"depth": rng.randf_range(0.40, 0.60)
		},
		"top": {
			"type": "head_humanoid",
			"size_factor": rng.randf_range(0.75, 0.95),
			"height": 0.30
		},
		"face": {
			"eye_count": 2,
			"eye_radius": 0.05,
			"eye_glow": true,
			"mouth_style": "none",
			"tongue_present": false
		},
		"limbs": {
			"has_arms": true,
			"arm_count": 2,
			"arm_length": rng.randf_range(0.45, 0.60),
			"arm_radius": 0.08,
			"has_legs": true,
			"leg_count": 2,
			"leg_length": rng.randf_range(0.45, 0.60),
			"leg_radius": 0.09,
			"leg_spread": rng.randf_range(0.14, 0.20),
			"foot_size": 0.12
		},
		"ornaments": {
			"tags": ["metallic_plate"],
			"primary_color": Color(0.55, 0.55, 0.60),
			"secondary_color": Color(0.40, 0.40, 0.45)
		},
		"palette": _construct_palette(rng)
	}

# ============================================================================
# CATEGORY TEMPLATES (10 stub templates — Beast/Humanoid base + category tags)
# ============================================================================

## Dragon — quadruped with wings + horns + tail. Borrows the beast lizard_like
## sub-template (low-slung, long tail) and scales up.
static func _template_dragon(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_beast(rng, rng, "lizard_like", defaults)
	plan.base.width *= 1.4
	plan.base.height *= 1.3
	plan.base.depth *= 1.5
	plan.face.eye_glow = true
	plan.ornaments.tags = ["tail", "wings", "horns"]
	plan.palette = _dragon_palette(rng)
	return plan

## Undead — Humanoid or Beast skeleton variant with bone + tattered cloth.
static func _template_undead(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	# Pick between skeleton-humanoid and zombie-quadruped randomly.
	var as_quadruped: bool = rng.randf() < 0.2
	var plan: Dictionary
	if as_quadruped:
		plan = _template_beast(rng, rng, "wolf_like", defaults)
	else:
		plan = _template_humanoid(rng, defaults)
	plan.face.eye_glow = true
	plan.ornaments.tags = ["bone_protrusion", "tattered_cloth"]
	plan.palette = _undead_palette(rng)
	return plan

## Ooze — amorphous blob. No limbs, no head, scattered eyes on the body surface.
static func _template_ooze(rng: RandomNumberGenerator, _defaults: Dictionary) -> Dictionary:
	return {
		"base": {
			"type": "blob",
			"width": rng.randf_range(0.85, 1.20),
			"height": rng.randf_range(0.45, 0.70),
			"depth": rng.randf_range(0.85, 1.20)
		},
		"top": {
			"type": "none",
			"size_factor": 0.0,
			"height": 0.0
		},
		"face": {
			"eye_count": rng.randi_range(2, 5),
			"eye_radius": 0.05,
			"eye_glow": rng.randf() < 0.5,
			"mouth_style": "none",
			"tongue_present": false
		},
		"limbs": {
			"has_arms": false,
			"arm_count": 0,
			"has_legs": false,
			"leg_count": 0
		},
		"ornaments": {
			"tags": [],
			"primary_color": Color(0.4, 0.6, 0.35),
			"secondary_color": Color(0.3, 0.5, 0.25)
		},
		"palette": _ooze_palette(rng)
	}

## Aberration — chaotic. Many eyes, tentacles, asymmetric.
static func _template_aberration(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_humanoid(rng, defaults)
	plan.face.eye_count = rng.randi_range(3, 6)
	plan.face.eye_glow = true
	plan.face.eye_spread = 0.16
	plan.limbs.has_arms = false  # Replaced by tentacles
	plan.ornaments.tags = ["tentacles"]
	plan.palette = _aberration_palette(rng)
	return plan

## Fey — humanoid with flowers + small wings.
static func _template_fey(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_humanoid(rng, defaults)
	plan.base.width *= 0.75
	plan.base.height *= 0.85
	plan.ornaments.tags = ["wings", "flowering_accents"]
	plan.palette = _fey_palette(rng)
	return plan

## Fiend — humanoid with horns + tail + claws + dark palette.
static func _template_fiend(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_humanoid(rng, defaults)
	plan.face.eye_glow = true
	plan.ornaments.tags = ["horns", "tail"]
	plan.palette = _fiend_palette(rng)
	return plan

## Giant — humanoid scaled up.
static func _template_giant(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_humanoid(rng, defaults)
	plan.base.width *= 1.6
	plan.base.height *= 1.8
	plan.base.depth *= 1.5
	plan.ornaments.tags = []  # Cleaner silhouette
	plan.palette = _giant_palette(rng)
	return plan

## Elemental — body matches element via palette + glow.
static func _template_elemental(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_humanoid(rng, defaults)
	plan.face.eye_glow = true
	plan.ornaments.tags = ["crystal_growth"]
	plan.palette = _elemental_palette(rng)
	return plan

## Celestial — humanoid with halo + wings + ethereal palette.
static func _template_celestial(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	var plan: Dictionary = _template_humanoid(rng, defaults)
	plan.face.eye_glow = true
	plan.ornaments.tags = ["halo", "wings"]
	plan.palette = _celestial_palette(rng)
	return plan

## Monstrosity — varied. Quadruped base + extra ornament weirdness.
static func _template_monstrosity(rng: RandomNumberGenerator, defaults: Dictionary) -> Dictionary:
	# Default to wolf_like beast base; per-species sub-template hints can
	# override this via Phase 2 work (e.g. chimera, hydra, serpentine).
	var plan: Dictionary = _template_beast(rng, rng, "wolf_like", defaults)
	var weird_tag: String
	# Pick one wild ornament randomly.
	var roll: float = rng.randf()
	if roll < 0.25: weird_tag = "horns"
	elif roll < 0.5: weird_tag = "tentacles"
	elif roll < 0.75: weird_tag = "crystal_growth"
	else: weird_tag = "wings"
	plan.ornaments.tags = ["tail", weird_tag]
	plan.face.eye_count = rng.randi_range(2, 4)
	plan.palette = _monstrosity_palette(rng)
	return plan

# ============================================================================
# PALETTES — per category color rolls
# ============================================================================

static func _beast_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Browns, greys, tans. Earthy.
	var primary := Color(rng.randf_range(0.30, 0.65), rng.randf_range(0.22, 0.50), rng.randf_range(0.15, 0.40))
	return {
		"primary": primary,
		"secondary": primary.darkened(0.2),
		"accent": Color(0.95, 0.92, 0.85),
		"eye": Color(0.15, 0.10, 0.05),
		"detail": Color(0.10, 0.07, 0.05)
	}

static func _humanoid_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Skin tones. Wide range.
	var hue_pick: float = rng.randf()
	var primary: Color
	if hue_pick < 0.4:
		# Warm peach/brown
		primary = Color(rng.randf_range(0.55, 0.85), rng.randf_range(0.40, 0.65), rng.randf_range(0.30, 0.55))
	elif hue_pick < 0.7:
		# Green/grey (goblin-like)
		primary = Color(rng.randf_range(0.30, 0.55), rng.randf_range(0.45, 0.65), rng.randf_range(0.25, 0.45))
	else:
		# Pale grey-blue (undead-ish)
		primary = Color(rng.randf_range(0.55, 0.75), rng.randf_range(0.55, 0.72), rng.randf_range(0.60, 0.78))
	return {
		"primary": primary,
		"secondary": primary.darkened(0.25),
		"accent": Color(0.78, 0.62, 0.42),
		"eye": Color(0.15, 0.10, 0.08),
		"detail": Color(0.20, 0.15, 0.10)
	}

static func _plant_palette(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"primary": Color(rng.randf_range(0.20, 0.45), rng.randf_range(0.45, 0.65), rng.randf_range(0.15, 0.35)),
		"secondary": Color(rng.randf_range(0.30, 0.50), rng.randf_range(0.25, 0.40), rng.randf_range(0.15, 0.30)),
		"accent": Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.20, 0.65), rng.randf_range(0.30, 0.85)),
		"eye": Color(0.85, 0.85, 0.30),
		"detail": Color(0.10, 0.20, 0.08)
	}

static func _construct_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Grey-blue metals + warm accents.
	var primary := Color(rng.randf_range(0.45, 0.65), rng.randf_range(0.45, 0.65), rng.randf_range(0.50, 0.70))
	return {
		"primary": primary,
		"secondary": primary.darkened(0.2),
		"accent": Color(0.95, 0.82, 0.45),
		"eye": Color(1.0, 0.6, 0.2),
		"detail": Color(0.20, 0.20, 0.22)
	}

static func _dragon_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Choose one of chromatic/metallic colors randomly.
	var dragon_colors: Array[Color] = [
		Color(0.85, 0.18, 0.15),  # Red
		Color(0.20, 0.18, 0.20),  # Black
		Color(0.25, 0.55, 0.30),  # Green
		Color(0.20, 0.35, 0.80),  # Blue
		Color(0.92, 0.92, 0.95),  # White
		Color(0.85, 0.75, 0.40),  # Brass
		Color(0.65, 0.50, 0.30),  # Copper
		Color(0.65, 0.55, 0.30),  # Bronze
		Color(0.85, 0.85, 0.90),  # Silver
		Color(0.95, 0.85, 0.30),  # Gold
	]
	var primary: Color = dragon_colors[rng.randi() % dragon_colors.size()]
	return {
		"primary": primary,
		"secondary": primary.darkened(0.3),
		"accent": Color(0.95, 0.85, 0.40),
		"eye": Color(0.95, 0.85, 0.20),
		"detail": Color(0.10, 0.08, 0.05)
	}

static func _undead_palette(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"primary": Color(rng.randf_range(0.65, 0.85), rng.randf_range(0.65, 0.85), rng.randf_range(0.65, 0.80)),
		"secondary": Color(0.30, 0.25, 0.20),
		"accent": Color(0.90, 0.85, 0.75),  # Bone
		"eye": Color(0.50, 0.95, 0.85),     # Spectral cyan
		"detail": Color(0.20, 0.18, 0.15)
	}

static func _ooze_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Slimy colors.
	var hue_roll: float = rng.randf()
	var primary: Color
	if hue_roll < 0.33:
		primary = Color(0.30, 0.55, 0.25)  # Green
	elif hue_roll < 0.66:
		primary = Color(0.50, 0.40, 0.20)  # Mustard
	else:
		primary = Color(0.30, 0.30, 0.35)  # Grey
	return {
		"primary": primary,
		"secondary": primary.lerp(Color.BLACK, 0.4),
		"accent": Color(0.65, 0.95, 0.50),
		"eye": Color(0.95, 0.95, 0.30),
		"detail": Color(0.15, 0.20, 0.10)
	}

static func _aberration_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Purples, pinks, weird greens.
	var hue: float = rng.randf_range(0.6, 0.95)
	var primary := Color.from_hsv(hue, rng.randf_range(0.55, 0.85), rng.randf_range(0.35, 0.60))
	return {
		"primary": primary,
		"secondary": primary.darkened(0.25),
		"accent": Color.from_hsv(fposmod(hue + 0.4, 1.0), 0.7, 0.85),
		"eye": Color(0.95, 0.30, 0.85),
		"detail": Color(0.20, 0.08, 0.20)
	}

static func _fey_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Bright vibrant flowers + leafy greens.
	var primary := Color.from_hsv(rng.randf_range(0.05, 0.35), 0.65, 0.75)
	return {
		"primary": primary,
		"secondary": Color(0.20, 0.50, 0.30),
		"accent": Color.from_hsv(rng.randf(), 0.85, 0.95),
		"eye": Color(0.40, 0.90, 0.95),
		"detail": Color(0.40, 0.25, 0.10)
	}

static func _fiend_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Dark reds, blacks, purples.
	var primary := Color(rng.randf_range(0.30, 0.55), rng.randf_range(0.10, 0.25), rng.randf_range(0.08, 0.22))
	return {
		"primary": primary,
		"secondary": primary.darkened(0.4),
		"accent": Color(0.95, 0.35, 0.10),
		"eye": Color(1.0, 0.30, 0.05),
		"detail": Color(0.10, 0.05, 0.05)
	}

static func _giant_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Earthy + neutral.
	return _humanoid_palette(rng)

static func _elemental_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Pick element from common four.
	var element_pick: int = rng.randi() % 4
	match element_pick:
		0: # Fire
			return {
				"primary": Color(0.95, 0.40, 0.10),
				"secondary": Color(0.65, 0.20, 0.05),
				"accent": Color(1.0, 0.85, 0.30),
				"eye": Color(1.0, 0.95, 0.40),
				"detail": Color(0.30, 0.05, 0.0)
			}
		1: # Ice
			return {
				"primary": Color(0.55, 0.85, 0.95),
				"secondary": Color(0.30, 0.60, 0.85),
				"accent": Color(0.90, 0.95, 1.0),
				"eye": Color(0.85, 0.95, 1.0),
				"detail": Color(0.10, 0.30, 0.50)
			}
		2: # Earth
			return {
				"primary": Color(0.45, 0.35, 0.25),
				"secondary": Color(0.30, 0.22, 0.15),
				"accent": Color(0.65, 0.50, 0.30),
				"eye": Color(0.85, 0.60, 0.30),
				"detail": Color(0.15, 0.10, 0.07)
			}
		_: # Air
			return {
				"primary": Color(0.85, 0.90, 0.95),
				"secondary": Color(0.65, 0.75, 0.85),
				"accent": Color(0.95, 0.95, 1.0),
				"eye": Color(0.95, 0.95, 1.0),
				"detail": Color(0.30, 0.40, 0.50)
			}

static func _celestial_palette(_rng: RandomNumberGenerator) -> Dictionary:
	return {
		"primary": Color(0.95, 0.92, 0.80),
		"secondary": Color(0.80, 0.75, 0.55),
		"accent": Color(1.0, 0.95, 0.55),  # Halo gold
		"eye": Color(0.95, 0.95, 0.40),
		"detail": Color(0.55, 0.45, 0.25)
	}

static func _monstrosity_palette(rng: RandomNumberGenerator) -> Dictionary:
	# Wild card. Pick from beast OR aberration palette.
	if rng.randf() < 0.5:
		return _beast_palette(rng)
	return _aberration_palette(rng)

# ============================================================================
# MODIFIER OVERLAY
# ============================================================================

## Apply species-level body_plan_modifiers on top of the category template.
## Modifiers are dot-keyed paths into the plan dict, e.g.:
##   "ornaments.tags": ["mane", "tail"]
##   "palette.primary": Color(0.95, 0.40, 0.10)
##   "base.scale": 1.5  (multiplies all base dimensions)
##
## This is the species-level variation that distinguishes Wolf from Lion within
## the Beast template, or Fire Dragon from Ice Dragon within the Dragon template.
static func _apply_modifiers(plan: Dictionary, modifiers: Dictionary) -> void:
	for key in modifiers.keys():
		var key_str: String = String(key)
		var value: Variant = modifiers[key]
		if key_str == "base.scale":
			# Special case — multiply all base dimensions.
			if value is float or value is int:
				var scale: float = float(value)
				if plan.has("base"):
					var base: Dictionary = plan["base"]
					for axis in ["width", "height", "depth"]:
						if base.has(axis) and (base[axis] is float or base[axis] is int):
							base[axis] = float(base[axis]) * scale
			continue
		# General dot-path overwrite.
		_set_dotted(plan, key_str, value)

## Set a value at a dotted path inside a nested dict. Creates intermediate
## dicts as needed. Used by _apply_modifiers.
static func _set_dotted(d: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".", false)
	if parts.size() == 0:
		return
	var cursor: Dictionary = d
	for i in range(parts.size() - 1):
		var part: String = parts[i]
		if not cursor.has(part) or not (cursor[part] is Dictionary):
			cursor[part] = {}
		cursor = cursor[part]
	cursor[parts[parts.size() - 1]] = value
