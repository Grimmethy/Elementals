class_name MimicActor
extends Actor

const MimicControllerScript = preload("res://src/actors/types/MimicController.gd")
const MimicShapechangeScript = preload("res://Components/ActorComponents/AbilityComponents/MimicShapechange.gd")
const MimicAmbushBiteScript = preload("res://Components/ActorComponents/AbilityComponents/MimicAmbushBite.gd")

## Optional genome carrier. Wild mimics get a fresh randomized one in _ready;
## captured / bred mimics inherit theirs from the breeding pipeline.
@export var mimic_data: MimicData = null

func _init() -> void:
	element_type = "mimic"
	should_bob = false
	actor_size = Size.MEDIUM
	move_speed = 2.2
	armor_class = 12
	max_hp = 58.0
	# Wild mimics are hostile by default. Selected-player spawns override this.
	is_playable = false

func _ready() -> void:
	super._ready()
	if faction_component and not is_playable and faction_component.faction == FactionComponent.Faction.NEUTRAL:
		faction_component.setup(FactionComponent.Faction.MONSTERS)
	# Ensure we have a genome to drive the procedural body. Wild spawns and
	# player-selected mimics both get a fresh randomized one so each Mimic
	# in the world looks like a different piece of disguised furniture.
	if mimic_data == null:
		mimic_data = MimicData.new()
		mimic_data.randomize_genome()
	_apply_mimic_stat_profile()
	_apply_mimic_dnd_cap()
	call_deferred("_equip_default_unarmed")
	call_deferred("_push_genome_to_body")
	_setup_ability_from_settings()
	call_deferred("_refresh_selected_ability_ui")

## Push the randomized/inherited genome to ProceduralMimicChest so it can
## rebuild from the genome shape instead of the legacy voxel defaults.
##
## We ONLY assign mimic_data here — the setter on ProceduralMimicChest fires
## rebuild_from_genome() automatically when in-tree. Calling it explicitly
## after the assignment would trigger a second rebuild in the same frame,
## which leaves the first rebuild's nodes queue_freed but still in the tree
## until end-of-frame (visible as faint "ghost" geometry that the player
## might describe as "the old tongue is still there").
func _push_genome_to_body() -> void:
	var body: Node = get_node_or_null("Body")
	if body == null:
		return
	if "mimic_data" in body:
		body.mimic_data = mimic_data

## Apply the D&D 5e Mimic statblock cap:
##   - Stealth +5 (mimicking object)
##   - Prone-immune (Mimics have no traditional legs to knock out)
##   - Grappler trait (advantage vs grappled targets — checked by MimicAmbushBite)
##   - Adhesive trait is on the CreatureMorphComponent (triggered while in object form)
## All four are exposed via metadata so external systems (StatusEffectComponent,
## the future Stealth roll system, MimicAmbushBite) can opt into the bonus without
## hard-coding MimicActor references.
func _apply_mimic_dnd_cap() -> void:
	set_meta("stealth_bonus", 5)
	set_meta("prone_immune", true)
	set_meta("grappler_advantage", true)
	# Adhesive escape DC (5e Mimic: DC 13 Strength).
	set_meta("adhesive_escape_dc", 13)
	set_meta("adhesive_disadvantage_on_escape", true)

func _create_controller() -> ActorAIController:
	return MimicControllerScript.new()

func _equip_default_unarmed() -> void:
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

func get_actor_color() -> Color:
	return Color(0.44, 0.30, 0.18)

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if String(type).to_lower().strip_edges() == "acid":
		return
	super.take_damage(amount, type, direction)

func die() -> void:
	var morph_component: Node = get_node_or_null("CreatureMorphComponent")
	if morph_component and morph_component.has_method("force_true_form"):
		morph_component.call("force_true_form")
	var skill_copy_component: Node = get_node_or_null("SkillCopyComponent")
	if skill_copy_component and skill_copy_component.has_method("restore"):
		skill_copy_component.call("restore")
	super.die()

func _apply_mimic_stat_profile() -> void:
	if ability_scores_component:
		ability_scores_component.strength = 3
		ability_scores_component.dexterity = 1
		ability_scores_component.constitution = 2
		ability_scores_component.intelligence = -3
		ability_scores_component.wisdom = 1
		ability_scores_component.charisma = -1

func _setup_ability_from_settings() -> void:
	if ability_component == null:
		return

	ability_component.actions.clear()

	var ability_selection: int
	if is_playable:
		ability_selection = GameSettings.selected_ability_index
	else:
		ability_selection = _rng.randi_range(0, 1)
	ability_selection = clampi(ability_selection, 0, 1)

	var action_instance: Variant
	match ability_selection:
		0:
			action_instance = MimicShapechangeScript.new(self, ability_component)
		1:
			action_instance = MimicAmbushBiteScript.new(self, ability_component)

	if action_instance is AbilityAction:
		ability_component.add_action(action_instance as AbilityAction)

func _refresh_selected_ability_ui() -> void:
	if not is_controlled or ability_component == null:
		return
	if ability_component.actions.is_empty():
		return
	if has_node("/root/ItemsAutoload"):
		ItemsAutoload.set_selected_ability(ability_component.actions[0].get_ability_data())
