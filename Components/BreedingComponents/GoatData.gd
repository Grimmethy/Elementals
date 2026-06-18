class_name GoatData
extends ActorData

enum HornType { NONE, SMALL, LARGE, SPIRAL }
enum BodyType { SMALL, MEDIUM, LARGE }
enum PatternType { SOLID, PIEBALD, SPOTTED }

@export_group("Identity")
@export var goat_name: String = "New Goat":
	set(v): 
		if goat_name == v: return
		goat_name = v
		stats_changed.emit()
@export var level: int = 1:
	set(v):
		if level == v: return
		level = v
		stats_changed.emit()

@export_group("Genetics")
@export var horn_type: HornType = HornType.NONE:
	set(v): 
		if horn_type == v: return
		horn_type = v
		stats_changed.emit()
@export var body_type: BodyType = BodyType.MEDIUM:
	set(v): 
		if body_type == v: return
		body_type = v
		stats_changed.emit()
@export var pattern_type: PatternType = PatternType.SOLID:
	set(v): 
		if pattern_type == v: return
		pattern_type = v
		stats_changed.emit()

func _init() -> void:
	_apply_type_defaults("Goat")
	if render_seed == 0:
		render_seed = randi()
	# Auto-name from render_seed — every fresh GoatData gets a unique fantasy
	# name instead of "New Goat" by default.
	goat_name = ActorData.generate_name_from_seed(render_seed)

# stamina_max, stamina_current, age_days, is_selected all live on ActorData
# base now — every herd member (goat, mimic, mushroom, goblin, hybrid)
# shares the same lifecycle fields so ProgressionComponent.advance_day can
# poll them polymorphically without GoatData-specific casts.

@export_group("Economy")
@export var gold_value: int = 50:
	set(v): 
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

## Creates offspring from this actor and a partner.
## Same species → bespoke Goat × Goat genome crossover (horn / body / pattern
## inheritance below). Cross species → ActorData.universal_crossover_breed,
## which 50/50-rolls the kid's species and transfers limbs / palette /
## mutations from the partner. That makes Goat × Mimic sometimes produce a
## Mimic kid with goat-tinted palette, and Mimic × Goat sometimes produce
## a Goat with mimic_blood + inherited skill chance.
func create_offspring(partner: ActorData) -> ActorData:
	if partner == null:
		return null
	if not (partner is GoatData):
		return ActorData.universal_crossover_breed(self, partner)
	var kid := GoatData.new()

	# Use reflection for goat-specific fields; partner may not be a GoatData,
	# so guard each access through `in partner` before reading.
	var partner_name: String = partner.goat_name if "goat_name" in partner else "Stranger"
	kid.goat_name = "Kid of " + (goat_name if "goat_name" in self else "Unknown") + " & " + partner_name
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE

	# Genetic inheritance with slight mutation
	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.pattern_color = pattern_color.lerp(partner.pattern_color, randf())
	# Goat-specific genes default to this parent's value unless partner has
	# the same field (hybrid crossover only triggers between two GoatData).
	if "horn_type" in partner:
		kid.horn_type = horn_type if randf() < 0.5 else partner.horn_type
	else:
		kid.horn_type = horn_type
	if "body_type" in partner:
		kid.body_type = body_type if randf() < 0.5 else partner.body_type
	else:
		kid.body_type = body_type
	if "pattern_type" in partner:
		kid.pattern_type = pattern_type if randf() < 0.5 else partner.pattern_type
	else:
		kid.pattern_type = pattern_type

	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)

	# Lineage: average mimic_blood and roll the skill-inheritance gate.
	# Centralized in ActorData.apply_mimic_lineage so MimicData / GoblinData /
	# FarmerData etc. all share the same probability table.
	ActorData.apply_mimic_lineage(kid, self, partner)

	# FOREIGN-SPECIES PLAN INHERITANCE + BLENDING — a "GoatData" carrying a
	# stamped shared_body_plan.meta.species is actually a wild-captured or
	# dev-summoned exotic wrapped in GoatData for breeding compat (see
	# HerdManager._build_captured_data + DevMonsterPreview._on_keep_for_breeding).
	# Without this block, kid.shared_body_plan stays at its default empty
	# state and both the Ranch card and the arena fall back to goat visuals.
	#
	# What we do here (real mixing, not just "pick one parent whole"):
	#   1. Pick a PRIMARY parent at 50/50 — kid inherits primary's anatomical
	#      sub_template (the hand-built mesh dispatcher uses meta.sub_template,
	#      so the kid's body shape is coherent — anatomy comes from primary).
	#   2. For every other slot in the plan (palette, base dimensions, top,
	#      face, limbs, ornaments) independently pick from EITHER parent.
	#      Each kid gets a different per-slot pattern → visible variation
	#      between siblings.
	#   3. Palette colors are LERPED per-color toward the OTHER parent with a
	#      random t per color, so even when primary "wins" a slot the kid's
	#      coat is still nudged toward the partner — siblings won't look
	#      identical to a parent.
	#   4. Fresh render_seed re-rolls per-individual jitter inside the
	#      builder (size_jitter, fur tufts, claw lengths, etc.) so two kids
	#      from the same pair are still distinct individuals.
	# If NEITHER parent has a foreign plan, this is a pure-goat × pure-goat
	# breed — leave the kid's default plan alone so legacy GoatRenderer kicks in.
	var self_plan: Dictionary = self.shared_body_plan if self.shared_body_plan is Dictionary else {}
	var partner_plan: Dictionary = partner.shared_body_plan if partner.shared_body_plan is Dictionary else {}
	var self_has_plan: bool = _plan_has_species(self_plan)
	var partner_has_plan: bool = _plan_has_species(partner_plan)
	if self_has_plan or partner_has_plan:
		var primary_plan: Dictionary
		var secondary_plan: Dictionary
		if self_has_plan and partner_has_plan:
			if randf() < 0.5:
				primary_plan = self_plan
				secondary_plan = partner_plan
			else:
				primary_plan = partner_plan
				secondary_plan = self_plan
		elif self_has_plan:
			primary_plan = self_plan
			secondary_plan = {}   # partner contributes nothing visual
		else:
			primary_plan = partner_plan
			secondary_plan = {}
		kid.render_seed = randi()
		kid.shared_body_plan = _crossover_plans(primary_plan, secondary_plan, kid.render_seed)
		# If the parents are clearly different species, bump hybrid_generation
		# so the chimeric-name prefix kicks in (matches the cross-class path
		# in universal_crossover_breed). Same-species pairs leave generation
		# at 0 — they're still pure-species offspring, just mixed-genome.
		var sp_a: String = _species_from_plan(self_plan)
		var sp_b: String = _species_from_plan(partner_plan)
		if sp_a != "" and sp_b != "" and sp_a != sp_b:
			kid.hybrid_generation = maxi(self.hybrid_generation, partner.hybrid_generation) + 1

	return kid

## True if a plan dict has a non-empty meta.species — the "this is a foreign
## body plan, not a default goat" marker. Helper for create_offspring above
## so the multi-line nested check doesn't litter the breeding logic.
static func _plan_has_species(plan: Dictionary) -> bool:
	if not plan.has("meta"):
		return false
	var meta_var: Variant = plan["meta"]
	if not (meta_var is Dictionary):
		return false
	return String((meta_var as Dictionary).get("species", "")) != ""

static func _species_from_plan(plan: Dictionary) -> String:
	if not _plan_has_species(plan):
		return ""
	return String((plan["meta"] as Dictionary).get("species", ""))

## Per-slot crossover between two body plans. `primary` provides the meta /
## sub_template (so the kid's anatomy renders coherently with one parent's
## mesh builder); each other top-level slot independently rolls 50/50 from
## either parent. Palette colors are then color-LERPED toward the secondary
## with a random t per color so the kid's coat is a true mix.
##
## `secondary` may be {} when only one parent had a foreign plan — in that
## case every slot resolves to primary and only the fresh render_seed
## produces variation (in-builder jitter on this kid's specific seed).
static func _crossover_plans(primary: Dictionary, secondary: Dictionary, kid_seed: int) -> Dictionary:
	var kid_plan: Dictionary = primary.duplicate(true)
	# Cross over each top-level dict slot. Skip "meta" — we keep primary's
	# meta (sub_template / category / species) so the mesh builder is
	# anatomy-consistent with one parent rather than producing a
	# rendering-impossible Frankenstein where limb data assumes Camel
	# anatomy but base.type assumes Behir anatomy.
	var crossover_slots: Array[String] = [
		"base", "top", "face", "limbs", "ornaments", "palette"
	]
	if not secondary.is_empty():
		for slot in crossover_slots:
			if not secondary.has(slot):
				continue
			if randf() < 0.5:
				# Take secondary's full slot dict (duplicated so kid doesn't
				# share dict refs with the partner's live data).
				var sec_var: Variant = secondary[slot]
				if sec_var is Dictionary:
					kid_plan[slot] = (sec_var as Dictionary).duplicate(true)
		# Independent of slot swaps, blend the PALETTE colors per-color so
		# even when the slot stayed with primary the kid's coat is shifted
		# toward partner. Without this step a "primary won every slot" roll
		# produces a kid visually identical to primary.
		if primary.has("palette") and (primary["palette"] is Dictionary) \
				and secondary.has("palette") and (secondary["palette"] is Dictionary):
			var prim_pal: Dictionary = primary["palette"]
			var sec_pal: Dictionary = secondary["palette"]
			var kid_pal: Dictionary = kid_plan["palette"] if kid_plan.has("palette") \
					and kid_plan["palette"] is Dictionary else {}
			for key in prim_pal.keys():
				var prim_val: Variant = prim_pal.get(key)
				var sec_val: Variant = sec_pal.get(key, prim_val)
				if prim_val is Color and sec_val is Color:
					kid_pal[key] = (prim_val as Color).lerp(sec_val as Color, randf_range(0.2, 0.8))
			kid_plan["palette"] = kid_pal
	# Stamp the kid's render_seed into meta so any mesh builder that derives
	# per-individual jitter from plan.meta.render_seed picks up THIS kid's
	# seed, not the donor parent's.
	if not kid_plan.has("meta"):
		kid_plan["meta"] = {}
	(kid_plan["meta"] as Dictionary)["render_seed"] = kid_seed
	return kid_plan
