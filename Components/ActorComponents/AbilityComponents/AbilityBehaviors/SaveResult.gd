class_name SaveResult
extends RefCounted

## Wraps the Dictionary returned by SkillCheckComponent.perform_check() and
## adds the DC and margin fields it does not natively track.
##
## SkillCheckComponent.perform_check() returns:
##   { "success": bool, "roll": int, "total": float, "is_critical": bool }
##
## SaveResult adds:
##   dc     — the computed difficulty class the target needed to beat
##   margin — how far above or below the DC the total landed (positive = beat it)
##
## Example:
##   var result := SaveResult.from_check(
##       target.skill_check_component.perform_check(...), computed_dc
##   )
##   if result.success:
##       print("Saved by %d" % result.margin)
##   else:
##       print("Failed by %d" % abs(result.margin))

## True if the target's roll met or beat the DC (or rolled a natural 20).
var success:     bool  = false

## The raw d20 result (1–20).
var roll:        int   = 0

## roll + the target's ability modifier.
var total:       float = 0.0

## True when roll == 20 (automatic success regardless of DC).
var is_critical: bool  = false

## The difficulty class computed by AbilitySaveResolver:
## 8 + AbilitySaveResolver.PROFICIENCY_BONUS + caster_modifier
var dc:          int   = 0

## total - dc. Positive means the target beat the DC by this amount.
## Negative means the target failed by the absolute value of this amount.
var margin:      int   = 0

## Construct from SkillCheckComponent output and the precomputed DC.
## check must contain the four keys returned by perform_check().
static func from_check(check: Dictionary, computed_dc: int) -> SaveResult:
	var r := SaveResult.new()
	r.success     = bool(check.get("success", false))
	r.roll        = int(check.get("roll",     0))
	r.total       = float(check.get("total",  0.0))
	r.is_critical = bool(check.get("is_critical", false))
	r.dc          = computed_dc
	r.margin      = int(r.total) - computed_dc
	return r
