class_name CharacterBuildComponent
extends Node

## Reads equipment and ability pools from ActorTypeData and applies a randomized
## (or player-selected) loadout to the actor at spawn time.
## Eliminates per-type setup blocks such as GoblinMinion._ready() armor/weapon/ability logic.

const AbilityList = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/AbilityList.gd")

# ---------------------------------------------------------------------------
# Script-based ability registry (Tier 3 — bespoke state machines)
# Each entry maps an ability_pool key → preloaded GDScript class.
# Instantiated with .new(actor, actor.ability_component).
# ---------------------------------------------------------------------------
const _ABILITY_REGISTRY: Dictionary = {
	"nimble_escape":     preload("res://Components/ActorComponents/AbilityComponents/NimbleEscape.gd"),
	"redirect_attack":   preload("res://Components/ActorComponents/AbilityComponents/RedirectAttack.gd"),
	"goat_charge":       preload("res://Components/ActorComponents/AbilityComponents/GoatCharge.gd"),
	"mimic_shapechange": preload("res://Components/ActorComponents/AbilityComponents/MimicShapechange.gd"),
}

# ---------------------------------------------------------------------------
# Data-driven ability registry (Tier 1 / Tier 2 — composed from AbilityBehaviors)
# Each entry maps an ability_pool key → { "category": String, "name": String }.
# Instantiated via DataDrivenAbility.from_dict() using AbilityList.ABILITIES.
# To add a new data-driven ability: append an entry here; no other file changes.
# ---------------------------------------------------------------------------
const _DATA_ABILITY_REGISTRY: Dictionary = {
	# STATUS_EFFECTS
	"paralyzing_tentacles": { "category": "STATUS_EFFECTS", "name": "Paralyzing Tentacles" },
	"paralyzing_touch":     { "category": "STATUS_EFFECTS", "name": "Paralyzing Touch" },
	"paralyzing_needles":   { "category": "STATUS_EFFECTS", "name": "Paralyzing Needles" },
	"paralyzing_field":     { "category": "STATUS_EFFECTS", "name": "Paralyzing Field" },
	"petrifying_gaze":      { "category": "STATUS_EFFECTS", "name": "Petrifying Gaze" },
	"petrifying_bite":      { "category": "STATUS_EFFECTS", "name": "Petrifying Bite" },
	# AURAS
	"fiery_aura":           { "category": "AURAS",          "name": "Fiery Aura" },
	"aura_of_fear":         { "category": "AURAS",          "name": "Aura of Fear" },
	"divine_aura":          { "category": "AURAS",          "name": "Divine Aura" },
	"storm_aura":           { "category": "AURAS",          "name": "Storm Aura" },
}

var actor: Actor
var rng: RandomNumberGenerator

func setup(p_actor: Actor, p_rng: RandomNumberGenerator) -> void:
	actor = p_actor
	rng = p_rng

func build() -> void:
	if not actor or actor._type_key.is_empty():
		return
	var config := ActorTypeData.get_defaults(actor._type_key)
	if config.is_empty():
		return

	_apply_faction(config)
	_roll_hp(config)
	_apply_armor(config)
	_apply_weapon(config)
	_apply_ability(config)

func _apply_faction(config: Dictionary) -> void:
	if not actor.faction_component or not config.has("faction"):
		return
	var faction_name: String = config["faction"]
	if not FactionComponent.Faction.has(faction_name):
		push_warning("CharacterBuildComponent: unknown faction '%s' for %s" % [faction_name, actor.name])
		return
	actor.faction_component.setup(FactionComponent.Faction[faction_name])

func _roll_hp(config: Dictionary) -> void:
	if not actor.health_component or not config.has("hp_dice_count"):
		return
	actor.max_hp = actor.health_component.roll_max_health(
		config.get("hp_dice_count", 1),
		config.get("hp_dice_sides", 6),
		rng
	)

func _apply_armor(config: Dictionary) -> void:
	if not actor.armor_class_component:
		return
	var pool: Array = config.get("armor_pool", [])
	if pool.is_empty():
		return

	var idx := _resolve_index(pool, _get_settings_int("selected_armor_index"), actor.is_playable)
	var armor_key: String = pool[idx]

	if armor_key == "none":
		actor.armor_class_component.armor_type = ArmorClassComponent.ArmorType.NONE
		actor.armor_class_component.armor_value = 10
		actor.armor_class_component.equipped_armor = null
	else:
		actor.armor_class_component.equipped_armor = ArmorData.create_standard_armor(armor_key)
	actor.armor_class_component.refresh()

	actor.on_equipment_built(armor_key)

func _apply_weapon(config: Dictionary) -> void:
	if not actor.weapon_component:
		return
	var pool: Array = config.get("weapon_pool", [])
	if pool.is_empty():
		return

	var idx := _resolve_index(pool, _get_settings_int("selected_weapon_index"), actor.is_playable)
	var weapon_name: String = pool[idx]

	var weapon_data: WeaponData = _find_weapon(weapon_name)
	if not weapon_data:
		push_warning("CharacterBuildComponent: weapon '%s' not found for %s" % [weapon_name, actor.name])
		return

	if config.has("ammo_dice_count") and "current_ammo" in weapon_data:
		var total := 0
		for _i in range(config.get("ammo_dice_count", 1)):
			total += rng.randi_range(1, config.get("ammo_dice_sides", 10))
		weapon_data.current_ammo = total

	actor._on_weapon_selected(weapon_data)

func _apply_ability(config: Dictionary) -> void:
	if not actor.ability_component:
		return
	var pool: Array = config.get("ability_pool", [])
	if pool.is_empty():
		return

	var idx := _resolve_index(pool, _get_settings_int("selected_ability_index"), actor.is_playable)
	var ability_key: String = pool[idx]

	# --- Path A: script-based (Tier 3 bespoke) ---
	if _ABILITY_REGISTRY.has(ability_key):
		actor.ability_component.actions.clear()
		actor.ability_component.add_action(
			_ABILITY_REGISTRY[ability_key].new(actor, actor.ability_component)
		)
		return

	# --- Path B: data-driven (Tier 1/2 composed) ---
	if _DATA_ABILITY_REGISTRY.has(ability_key):
		_apply_data_ability(ability_key)
		return

	push_warning("CharacterBuildComponent: unknown ability '%s' for %s" % [ability_key, actor.name])

func _apply_data_ability(ability_key: String) -> void:
	var entry: Dictionary = _DATA_ABILITY_REGISTRY[ability_key]
	var category: String  = entry.get("category", "")
	var entry_name: String = entry.get("name", "")

	var category_data: Dictionary = AbilityList.ABILITIES.get(category, {})
	var data: Dictionary = category_data.get(entry_name, {})
	if data.is_empty():
		push_warning("CharacterBuildComponent: data entry '%s/%s' not found in AbilityList for %s" % [
			category, entry_name, actor.name
		])
		return

	# Resolve TileSignalComponent. AbilityAreaQuery handles null gracefully.
	var tile_signal: Node = actor.get("tile_signal_component") as Node
	if tile_signal == null:
		tile_signal = actor.get_node_or_null("TileSignalComponent")

	var ability: DataDrivenAbility = DataDrivenAbility.from_dict(
		entry_name, data, actor, actor.ability_component, actor, tile_signal
	)

	actor.ability_component.actions.clear()
	actor.ability_component.add_action(ability)

	# Passive / aura abilities activate immediately on build.
	var action_type: String = str(data.get("action_type", "")).to_lower()
	if action_type.contains("passive") or action_type.contains("aura"):
		ability.start_aura()

func _resolve_index(pool: Array, settings_index: int, is_player: bool) -> int:
	if is_player:
		return clampi(settings_index, 0, pool.size() - 1)
	return rng.randi_range(0, pool.size() - 1)

func _get_settings_int(property: String) -> int:
	var gs := actor.get_node_or_null("/root/GameSettings")
	if gs and gs.get(property) != null:
		return int(gs.get(property))
	return 0

func _find_weapon(weapon_name: String) -> WeaponData:
	var wl := actor.get_node_or_null("/root/ItemsAutoload")
	if wl:
		for w in wl.weapons:
			if w.name == weapon_name:
				return w.duplicate()
	return null
