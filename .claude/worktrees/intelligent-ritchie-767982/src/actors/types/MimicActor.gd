## Mimic actor — a procedural creature that scans nearby creatures, copies a
## limited number of their abilities, and morphs into them for a fixed
## duration. Uses the existing AbilityComponent / WeaponComponent for the
## bite attack (falls through to `Unarmed strike` via WeaponComponent's
## fallback at WeaponComponent.gd:91-103).
##
## All timing routes through GameClockComponent and all proximity routes
## through TileSignalComponent — see MimicController.gd for the loop.
class_name MimicActor
extends Actor

## Accessor that mirrors GoatActor.goat_data — returns `_data` already cast
## to MimicData so callers don't repeat the cast.
var mimic_data: MimicData:
	get: return _data as MimicData
	set(v): _data = v

func _init() -> void:
	element_type = "mimic"
	should_bob = false
	actor_size = Size.MEDIUM
	# Mimic is never the controllable hero. Without this the base Actor
	# defaults `is_playable = true`, and `_setup_components()` would set the
	# Mimic's faction to PLAYER — at which point the player-side detection
	# trigger filters it out and the AI never chases or bites anyone. See
	# GoblinMinion._init() for the same fix in pattern.
	is_playable = false

func _ready() -> void:
	super._ready()
	# Ensure a MimicData resource exists so the controller can read defaults
	# even when the spawner did not provide one.
	if mimic_data == null:
		mimic_data = MimicData.new()
	# Drop the Mimic into the MONSTERS faction so the player's allies treat
	# it as hostile and the Mimic's own AI engages non-MONSTERS targets.
	# Spawners can override this if a scenario needs a tamed Mimic.
	if faction_component:
		faction_component.setup(FactionComponent.Faction.MONSTERS)
	# Bite attack uses the existing `Unarmed strike` weapon entry from the
	# global catalog (see Agent 1 spec: "Do NOT add new WeaponData entries").
	# Assignment is deferred so WeaponComponent.setup() has run first.
	call_deferred("_equip_default_bite")

## Equips the Mimic with the global `Unarmed strike` WeaponData so its
## MeleeHitbox has damage values to apply on attack ticks. Idempotent.
func _equip_default_bite() -> void:
	if not weapon_component:
		return
	if weapon_component.weapon_data:
		return
	var wl: Node = get_node_or_null("/root/ItemsAutoload")
	if wl == null:
		return
	var weapons_value: Variant = wl.get("weapons")
	if typeof(weapons_value) != TYPE_ARRAY:
		return
	for w in (weapons_value as Array):
		if w.name == "Unarmed strike":
			weapon_component.weapon_data = w
			break

## Use the AI controller specialized for Mimic scan/morph/copy behavior.
func _create_controller() -> ActorAIController:
	return MimicController.new()

## Mimic's signature tint used by reticles, debug labels, etc.
func get_actor_color() -> Color:
	if mimic_data:
		return mimic_data.base_color
	return Color(0.35, 0.20, 0.55)

func die() -> void:
	if is_dead:
		return
	super.die()
	# Unlike GoblinMinion/FarmerActor/Fire/Water, MimicActor._ready()
	# AUTO-CREATES a MimicData if none was assigned, so `_data != null` is
	# true even for wild combat Mimics that were never in the herd. Without
	# the explicit `herd.has(_data)` guard, removing them would still be a
	# no-op (Array.erase on a non-member) but would still emit
	# `herd_updated` and trigger an unnecessary autosave. Agent 1 R9.
	_remove_from_herd_if_present()

## Mimic-specific herd cleanup: only remove if `_data` is actually IN the
## herd. See `die()` docstring for why this differs from the other actors.
func _remove_from_herd_if_present() -> void:
	if _data == null:
		return
	if not has_node("/root/HerdManager"):
		return
	var hm: Node = get_node("/root/HerdManager")
	# `hm.herd` is the typed `Array[ActorData]` getter — `.has()` is safe.
	if hm.herd.has(_data):
		hm.remove_goat(_data)
