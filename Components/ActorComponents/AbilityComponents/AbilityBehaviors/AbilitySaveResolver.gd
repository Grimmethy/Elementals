class_name AbilitySaveResolver
extends RefCounted

## Computes a D&D save DC and delegates the actual roll to the target's
## SkillCheckComponent. Does NOT roll dice itself.
##
## DC formula: 8 + PROFICIENCY_BONUS + caster.ability_scores_component[dc_source_stat]
##
## IMPORTANT — modifier storage:
## AbilityScoresComponent stores stats as modifiers (floats), NOT as D&D
## ability scores (3–20). A stored value of 2.0 means +2, not a score of 2.
## The DC formula uses the raw stored value directly — no (score-10)/2 step.
##
## IMPORTANT — proficiency bonus:
## No per-actor proficiency_bonus property exists in the project. The constant
## PROFICIENCY_BONUS = 2 matches the CaptureProfile convention and the D&D 5e
## CR 1–4 standard used by the monster stat blocks in this data library.
## Replace with a CharacterProgressionComponent lookup when one is added.

## Project-wide proficiency bonus. Update when per-actor tracking is added.
const PROFICIENCY_BONUS: int = 2

## Stat string → AbilityScoresComponent property name.
const STAT_PROPERTY: Dictionary = {
	"STR": "strength",
	"DEX": "dexterity",
	"CON": "constitution",
	"INT": "intelligence",
	"WIS": "wisdom",
	"CHA": "charisma",
}

## The stat the TARGET rolls against. Parsed from data field "saving_throw".
## e.g. "CON", "WIS", "DEX"
var save_stat: String = "CON"

## The stat on the CASTER that sets the DC. Parsed from data field "save_dc_stat".
## e.g. "CON", "CHA", "INT"
var dc_source_stat: String = "CON"

## Build an AbilitySaveResolver from an ability data dictionary entry.
## Reads keys: "saving_throw", "save_dc_stat".
## "save_dc_stat" defaults to "CON" when absent.
static func from_dict(data: Dictionary) -> AbilitySaveResolver:
	var r := AbilitySaveResolver.new()
	r.save_stat      = str(data.get("saving_throw",  "CON")).strip_edges().to_upper()
	r.dc_source_stat = str(data.get("save_dc_stat",  "CON")).strip_edges().to_upper()
	return r

## Compute the DC from the caster's stats, then invoke the target's
## SkillCheckComponent to perform the actual d20 roll.
## Returns a SaveResult wrapping the outcome and adding DC + margin.
##
## For abilities with no saving throw (saving_throw == "None" or ""),
## returns a SaveResult with success = false and dc = 0 — caller should
## treat this as "save not applicable" and apply the full effect.
func resolve(caster: Actor, target: Actor) -> SaveResult:
	# Handle abilities that don't require a save.
	var st_upper: String = save_stat.to_upper()
	if st_upper == "" or st_upper == "NONE" or st_upper == "N/A":
		var no_save := SaveResult.new()
		no_save.success = false
		no_save.dc = 0
		return no_save

	# Handle contested saves: "CONTESTED (X VS Y)" — both sides roll.
	if st_upper.begins_with("CONTESTED"):
		return _resolve_contested(caster, target)

	# Compute the DC.
	var computed_dc: int = _compute_dc(caster)

	# Ask the target's SkillCheckComponent to perform the save roll.
	if not is_instance_valid(target):
		var invalid := SaveResult.new()
		invalid.dc = computed_dc
		return invalid

	var skill_check: Node = target.get("skill_check_component") as Node
	if skill_check == null or not skill_check.has_method("perform_check"):
		# No SkillCheckComponent — treat as automatic failure.
		var no_check := SaveResult.new()
		no_check.success = false
		no_check.dc      = computed_dc
		no_check.margin  = -computed_dc
		return no_check

	# Map save_stat → AbilityScoresComponent property for the target's modifier.
	var target_modifier: float = _get_modifier(target, save_stat)
	var check: Dictionary = skill_check.call("perform_check",
		target_modifier,   # total_mod
		computed_dc,       # difficulty
		save_stat + " Save",  # check_name
		caster,            # opponent (for logging)
		0.0,               # stat_value (already folded into total_mod)
		0.0,               # distance_mod
		0                  # tiles
	)

	return SaveResult.from_check(check, computed_dc)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## DC = 8 + PROFICIENCY_BONUS + caster's dc_source_stat modifier.
func _compute_dc(caster: Actor) -> int:
	var caster_mod: float = _get_modifier(caster, dc_source_stat)
	return 8 + PROFICIENCY_BONUS + int(caster_mod)

## Look up an actor's ability modifier from AbilityScoresComponent.
## Returns 0.0 when the component or property is missing.
func _get_modifier(actor: Actor, stat: String) -> float:
	if not is_instance_valid(actor):
		return 0.0
	var asc: Node = actor.get("ability_scores_component") as Node
	if asc == null:
		return 0.0
	var prop: String = STAT_PROPERTY.get(stat.to_upper(), "")
	if prop == "":
		return 0.0
	var val: Variant = asc.get(prop)
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return float(val)
	return 0.0

## Contested save: both caster and target roll; highest total wins.
## Uses the stat embedded in the "CONTESTED (X VS Y)" string.
## Example: "Contested (STR vs STR)" — both roll STR-based checks.
func _resolve_contested(caster: Actor, target: Actor) -> SaveResult:
	# Parse the contesting stats from the save_stat string.
	# Format: "Contested (ATK_STAT vs DEF_STAT)" — e.g. "Contested (STR vs STR)"
	var caster_stat: String = dc_source_stat
	var target_stat: String = save_stat
	var paren_start: int = save_stat.find("(")
	var paren_end:   int = save_stat.find(")")
	if paren_start != -1 and paren_end != -1:
		var inner: String = save_stat.substr(paren_start + 1, paren_end - paren_start - 1)
		var parts: PackedStringArray = inner.split(" vs ", false)
		if parts.size() == 2:
			caster_stat = parts[0].strip_edges().to_upper()
			target_stat = parts[1].strip_edges().to_upper()

	var caster_mod: float = _get_modifier(caster, caster_stat)
	var target_mod: float = _get_modifier(target, target_stat)

	# Both roll via SkillCheckComponent if available; otherwise use raw modifier.
	var caster_total: float = caster_mod + randf_range(1.0, 20.0)
	var target_total: float = target_mod + randf_range(1.0, 20.0)

	var caster_check: Node = caster.get("skill_check_component") as Node
	if caster_check and caster_check.has_method("perform_check"):
		var cr: Dictionary = caster_check.call("perform_check", caster_mod, 0, caster_stat + " Contest", target, 0.0, 0.0, 0)
		caster_total = float(cr.get("total", caster_total))

	var target_check: Node = target.get("skill_check_component") as Node
	if target_check and target_check.has_method("perform_check"):
		var tr: Dictionary = target_check.call("perform_check", target_mod, 0, target_stat + " Contest", caster, 0.0, 0.0, 0)
		target_total = float(tr.get("total", target_total))

	# Target succeeds (resists) when they beat the caster's roll.
	var r := SaveResult.new()
	r.success = target_total >= caster_total
	r.total   = target_total
	r.dc      = int(caster_total)
	r.margin  = int(target_total - caster_total)
	return r
