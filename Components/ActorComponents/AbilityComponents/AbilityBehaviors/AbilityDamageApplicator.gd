class_name AbilityDamageApplicator
extends RefCounted

## Parses a dice expression string and applies typed damage to a target.
## Centralises the dice roller so no individual ability re-implements it.
##
## Supported formats:
##   "2d6"         → roll 2 six-sided dice
##   "4d8+4"       → roll 4d8 and add 4
##   "10d10"       → roll 10d10
##   "1d4+2"       → roll 1d4 and add 2
##   "3d6-1"       → roll 3d6 and subtract 1
##   ""            → no damage (condition-only abilities)
##   "Varies per creature" → no damage; is_variable() returns true
##
## Multiplier:
##   1.0  = full damage (default)
##   0.5  = half damage (successful save on a half-damage ability)
##   0.0  = no damage (target immune, or condition-only)
##
## Damage is applied via the confirmed HealthComponent signature:
##   target.take_damage(amount: float, type: String, direction: Vector3)

## Dice expression from ability data field "damage_dice". e.g. "2d6", "4d8+4".
var dice_expression: String = ""

## Damage type string from ability data field "damage_type".
## e.g. "fire", "poison", "psychic", "necrotic", "bludgeoning", "normal".
var damage_type: String = "normal"

## Build an AbilityDamageApplicator from an ability data dictionary entry.
## Reads keys: "damage_dice", "damage_type".
static func from_dict(data: Dictionary) -> AbilityDamageApplicator:
	var a := AbilityDamageApplicator.new()
	a.dice_expression = str(data.get("damage_dice", "")).strip_edges()
	a.damage_type     = str(data.get("damage_type", "normal")).strip_edges().to_lower()
	if a.damage_type == "" or a.damage_type == "n/a":
		a.damage_type = "normal"
	return a

## Roll the dice, scale by multiplier, and apply damage to target.
## direction is used for knockback and hit reactions.
## Returns the final integer amount dealt (0 when is_variable() or multiplier == 0).
func apply(caster: Actor, target: Actor, multiplier: float = 1.0,
		direction: Vector3 = Vector3.ZERO) -> int:
	if is_variable() or multiplier <= 0.0:
		return 0
	if not is_instance_valid(target) or target.is_dead:
		return 0

	var amount: int = roll_amount()
	var final_amount: float = float(amount) * multiplier
	var dealt: int = maxi(0, int(final_amount))

	if dealt > 0:
		target.take_damage(float(dealt), damage_type, direction)

	return dealt

## Roll the dice expression and return the integer result.
## Does NOT apply damage — useful for previews and UI display.
## Returns 0 when is_variable() or expression is empty.
func roll_amount() -> int:
	if is_variable():
		return 0
	return _parse_and_roll(dice_expression)

## True when dice_expression is empty, "Varies per creature", or similar
## non-rollable values. apply() returns 0 for variable expressions.
func is_variable() -> bool:
	if dice_expression == "":
		return true
	var lower: String = dice_expression.to_lower().strip_edges()
	return lower == "varies per creature" or lower == "varies" or lower == "n/a"

# ---------------------------------------------------------------------------
# Dice parser
# ---------------------------------------------------------------------------

## Parse and roll a dice expression of the form NdS, NdS+M, or NdS-M.
## Returns 0 for unrecognised formats rather than throwing.
func _parse_and_roll(expr: String) -> int:
	var e: String = expr.strip_edges().to_lower()

	# Separate the fixed modifier: find last + or - after the 'd'
	var d_pos: int = e.find("d")
	if d_pos == -1:
		# No 'd' — try interpreting as a plain integer.
		return int(e) if e.is_valid_int() else 0

	var num_dice: int  = 1
	var die_sides: int = 0
	var modifier: int  = 0

	# Dice count: everything before 'd'
	var count_str: String = e.substr(0, d_pos).strip_edges()
	if count_str.is_valid_int():
		num_dice = maxi(1, int(count_str))

	# Right-hand side of 'd': sides and optional +/- modifier
	var right: String = e.substr(d_pos + 1)

	# Find the last + or - (handles negative modifiers like "3d6-1")
	var plus_pos:  int = right.rfind("+")
	var minus_pos: int = right.rfind("-")

	var mod_pos: int = -1
	var mod_sign: int = 1
	if plus_pos != -1 and plus_pos > minus_pos:
		mod_pos  = plus_pos
		mod_sign = 1
	elif minus_pos != -1:
		mod_pos  = minus_pos
		mod_sign = -1

	if mod_pos != -1:
		var sides_str: String = right.substr(0, mod_pos).strip_edges()
		var mod_str:   String = right.substr(mod_pos + 1).strip_edges()
		if sides_str.is_valid_int():
			die_sides = int(sides_str)
		if mod_str.is_valid_int():
			modifier = int(mod_str) * mod_sign
	else:
		if right.strip_edges().is_valid_int():
			die_sides = int(right.strip_edges())

	if die_sides < 1:
		return 0

	# Roll.
	var total: int = modifier
	for _i in num_dice:
		total += randi_range(1, die_sides)
	return maxi(0, total)
