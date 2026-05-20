## Minimum-viable capture handler attached to capturable actors.
##
## The component is **lazily attached** by `BaseProjectile._on_body_entered`
## when a capture-tool projectile (today: thrown Net) hits an actor without
## an existing `CaptureComponent`. This avoids changing `Actor._setup_components()`
## and keeps wild actors free of unused component overhead.
##
## API (intentionally small — three primitives the full Capture patch can
## EXTEND verbatim, not replace):
##   - `can_be_captured()`   — gate (allowlist check, dead/alive, etc.)
##   - `roll_save(mod)`      — d20 + ability_modifier vs profile.save_dc
##   - `roll_catch(mod)`     — uniform random vs profile.catch_chance
##   - `apply_stun(seconds)` — routes through Actor.stun() → StunComponent
##   - `apply_capture()`     — builds the matching *Data resource from the
##                              actor's ability scores, pushes to HerdManager,
##                              and queue_frees the actor.
##
## All print readouts use the literal `[Capture]` tag and unicode arrow `→`
## per the Patch 3 spec so the player can see save / catch outcomes in the
## Godot console until the Capture UI lands.
class_name CaptureComponent
extends Node

## Designer-authored capture parameters. Provided by whichever tool / system
## attached this component (today: the Net's `CaptureProfile.tres`).
@export var capture_profile: CaptureProfile

var actor: Actor

## Sets up the component with its owning actor. Mirrors the project-wide
## `setup(p_actor)` pattern used by every other ActorComponent.
func setup(p_actor: Actor) -> void:
	actor = p_actor

## Returns true if the actor can be targeted by a capture attempt.
## Defaults: must have a non-null actor, a profile, the actor must not be
## dead, and the actor's type must be allowed by the profile (empty
## allowlist = any type).
func can_be_captured() -> bool:
	if actor == null or capture_profile == null:
		return false
	if actor.is_dead:
		return false
	if not capture_profile.allowed_actor_types.is_empty():
		var key: StringName = StringName(actor.element_type)
		if not capture_profile.allowed_actor_types.has(key):
			return false
	return true

## Rolls a d20 save against `capture_profile.save_dc` using the target's
## ability modifier identified by `capture_profile.save_ability`.
##
## Returns `true` if the save SUCCEEDS (no capture, no stun).
##
## `attacker_modifier` is added to the DC effectively — i.e. a stronger
## thrower makes saves harder. Currently the projectile passes 0; this is
## here so future patches can wire in proficiency / weapon enchantment
## bonuses without changing the call site.
func roll_save(attacker_modifier: int = 0) -> bool:
	if capture_profile == null or actor == null:
		return true  # No profile → no capture possible → save "succeeds".
	var modifier: float = _get_save_modifier()
	var d20: int = randi() % 20 + 1
	var total: int = d20 + int(round(modifier))
	var effective_dc: int = capture_profile.save_dc + attacker_modifier
	var saved: bool = total >= effective_dc
	# Readout matches the user spec from the Patch 3 brief — the "rolled N"
	# field is the TOTAL (d20 + ability modifier), the breakdown is shown in
	# the trailing parens for clarity. Unicode arrow → is U+2192.
	print("[Capture] Net hit %s. Save: rolled %d vs DC %d → %s (d20=%d + %s=%d)" % [
		actor.name,
		total,
		effective_dc,
		"SUCCESS" if saved else "FAIL",
		d20,
		String(capture_profile.save_ability),
		int(round(modifier)),
	])
	return saved

## Rolls catch chance against `capture_profile.catch_chance`.
## Returns `true` if the catch SUCCEEDS (actor will be captured).
##
## `attacker_modifier` shifts catch chance up by 0.05 per +1 — reserved for
## future weapon-tier integration. Currently the projectile passes 0.
func roll_catch(attacker_modifier: int = 0) -> bool:
	if capture_profile == null or actor == null:
		return false
	var effective_chance: float = clampf(
		capture_profile.catch_chance + float(attacker_modifier) * 0.05,
		0.0, 1.0
	)
	var roll: float = randf()
	var caught: bool = roll <= effective_chance
	print("[Capture] %s stunned for %.1fs. Catch roll: %.2f vs %.2f → %s" % [
		actor.name,
		capture_profile.stun_duration,
		roll,
		effective_chance,
		"CAUGHT" if caught else "ESCAPED",
	])
	return caught

## Applies a stun via the actor's existing `Actor.stun(duration)` → routes
## through `StunComponent`. NEVER `Timer.new()`, NEVER `create_timer()` —
## `StunComponent` is the project's centralized stun authority and already
## drives its decrement via `_process(delta)`. Passing 0 / negative is a
## no-op.
func apply_stun(duration: float) -> void:
	if actor == null or duration <= 0.0:
		return
	if actor.has_method("stun"):
		actor.stun(duration)

## Materializes a fresh `*Data` resource from the actor's current ability
## scores (option (b) from the Patch 3 plan — no spawn-time data changes
## required for wild actors), pushes it into `HerdManager`, and frees the
## actor node.
##
## Dispatch is keyed on `Actor.element_type` (set in each actor's `_init()`)
## NOT on `actor._data`, because most wild actors carry `_data == null`.
##
## NOTE: this calls `queue_free()` directly rather than `actor.die()` —
## `die()` plays fall-over visuals, drops inventory, and fires
## `actor_died`, all of which are wrong for a clean capture (the actor is
## leaving the world peacefully, not dying).
func apply_capture() -> void:
	if actor == null:
		return
	var new_data: ActorData = _create_data_for_actor()
	if new_data == null:
		print("[Capture] Failed to create data resource for %s (element_type=%s) — capture aborted." % [
			actor.name, actor.element_type,
		])
		return
	_populate_data_from_actor(new_data)
	var hm: Node = actor.get_node_or_null("/root/HerdManager")
	if hm and hm.has_method("add_goat"):
		hm.add_goat(new_data)
		print("[Capture] %s added to herd as %s" % [
			actor.name, new_data.get_actor_type(),
		])
	else:
		print("[Capture] HerdManager unreachable — %s not persisted." % actor.name)
	actor.queue_free()

# --- Internal helpers ---

## Reads the named ability modifier off the actor's
## `ability_scores_component`. Returns 0.0 if the component or the named
## ability is missing — same defensive default the game uses elsewhere.
##
## We use `Object.get(prop)` directly — on `AbilityScoresComponent` the
## six ability fields are `@export var` so `get()` resolves them via the
## property system. Unknown keys return `null`, which we filter out.
func _get_save_modifier() -> float:
	if actor == null:
		return 0.0
	var scores = actor.get("ability_scores_component")
	if scores == null:
		return 0.0
	var key: String = String(capture_profile.save_ability)
	var value = scores.get(key)
	if value == null:
		return 0.0
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return 0.0

## Picks the right ActorData subclass for the actor being captured.
## Keyed on `Actor.element_type` (NOT `_data`) because most wild actors
## have `_data == null` — that's exactly what this method is here to fix.
##
## Future: when more capturable creatures land, add cases here. Keep this
## the SINGLE dispatch site so future-Capture maintenance is one method.
func _create_data_for_actor() -> ActorData:
	match actor.element_type:
		"goblin":
			return GoblinData.new()
		"mimic":
			return MimicData.new()
		"fire":
			var fire_data: ElementalData = ElementalData.new()
			fire_data.element_subtype = &"fire"
			return fire_data
		"water":
			var water_data: ElementalData = ElementalData.new()
			water_data.element_subtype = &"water"
			return water_data
		"farmer":
			return FarmerData.new()
		"goat":
			return GoatData.new()
		_:
			# Unknown type — refuse to capture rather than build a base
			# ActorData (which has no `get_actor_type()` override and would
			# spam push_warning on every UI refresh).
			return null

## Copies the actor's live combat stats into the freshly-built data
## resource so the captured creature retains its individuality (not just a
## fresh default block). Uses ability_scores_component as the source of
## truth — that's the live combat-relevant version of the stats.
func _populate_data_from_actor(data: ActorData) -> void:
	var scores = actor.get("ability_scores_component")
	if scores:
		data.strength = _read_score(scores, "strength", data.strength)
		data.dexterity = _read_score(scores, "dexterity", data.dexterity)
		data.constitution = _read_score(scores, "constitution", data.constitution)
		data.intelligence = _read_score(scores, "intelligence", data.intelligence)
		data.wisdom = _read_score(scores, "wisdom", data.wisdom)
		data.charisma = _read_score(scores, "charisma", data.charisma)
	# Preserve any visuals already on the actor's data, if it carried one.
	if actor._data:
		data.base_color = actor._data.base_color
		data.pattern_color = actor._data.pattern_color

## Defensive `scores.get(prop)` wrapper — returns the default if the
## property is missing or non-numeric. Prevents `float(null)` from
## blowing up the capture flow if a future component variant lacks one
## of the six ability fields.
func _read_score(scores: Object, prop: String, default_value: float) -> float:
	var value = scores.get(prop)
	if value == null:
		return default_value
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return default_value
