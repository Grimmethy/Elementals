class_name MushroomActor
extends Actor

## Mushroom Monster — first species built from the genome-as-Dictionary
## architecture. The body model (ProceduralMushroomBody) reads MushroomData.genome
## and assembles cap+body+face from the cap/body/face slots. v1 covers three
## modules; surface/palette/limbs/animation/attack/mutation remain placeholders
## that future patches will wire generators for.

const MushroomControllerScript = preload("res://src/actors/types/MushroomController.gd")
const SporeBurstScript = preload("res://Components/ActorComponents/AbilityComponents/SporeBurst.gd")

@export var mushroom_data: MushroomData = null

func _init() -> void:
	element_type = "mushroom"
	should_bob = false
	actor_size = Size.SMALL
	move_speed = 1.6
	armor_class = 11
	max_hp = 24.0
	is_playable = false

func _ready() -> void:
	super._ready()
	if faction_component and not is_playable and faction_component.faction == FactionComponent.Faction.NEUTRAL:
		faction_component.setup(FactionComponent.Faction.MONSTERS)

	# Ensure we have a genome to drive the body. Wild spawns get a fresh
	# randomized genome so every mushroom looks distinct on each respawn.
	# Player-summoned mushrooms via the character-select also follow this
	# path (selected scene instantiate → _ready), so the player gets a fresh
	# fungus every match. Skip randomize if mushroom_data was injected
	# externally (e.g. captured/breed via HerdManager — those preserve genome).
	if mushroom_data == null:
		mushroom_data = MushroomData.new()
		mushroom_data.randomize()

	_apply_mushroom_stat_profile()
	call_deferred("_equip_fungal_bite")
	call_deferred("_push_genome_to_body")
	call_deferred("_apply_glow_mutation")
	_setup_ability_from_settings()

func _create_controller() -> ActorAIController:
	return MushroomControllerScript.new()

func _apply_mushroom_stat_profile() -> void:
	if ability_scores_component == null:
		return
	# AbilityScoresComponent stores modifiers as floats (codebase convention),
	# not raw 1-20 D&D scores. The MushroomData stats are also modifiers, so
	# copy directly without rounding.
	ability_scores_component.strength = mushroom_data.strength
	ability_scores_component.dexterity = mushroom_data.dexterity
	ability_scores_component.constitution = mushroom_data.constitution
	ability_scores_component.intelligence = mushroom_data.intelligence
	ability_scores_component.wisdom = mushroom_data.wisdom
	ability_scores_component.charisma = mushroom_data.charisma

func _equip_fungal_bite() -> void:
	if weapon_component == null:
		return
	if weapon_component.weapon_data:
		return
	var wl: Node = get_node_or_null("/root/ItemsAutoload")
	if wl == null:
		return
	var weapons_value: Variant = wl.get("weapons")
	if typeof(weapons_value) != TYPE_ARRAY:
		return
	# Reuse Unarmed strike but display as Fungal Bite. Mushroom attack module
	# carries the override name + reach via the genome.
	for w in (weapons_value as Array):
		if w == null or not "name" in w:
			continue
		if String(w.name) == "Unarmed strike":
			var bite: WeaponData = w.duplicate()
			if mushroom_data and mushroom_data.genome.has("attack"):
				var atk = mushroom_data.genome["attack"]
				bite.name = String(atk.get("name", "Fungal Bite"))
				bite.damage_type = String(atk.get("damage_type", bite.damage_type))
			weapon_component.weapon_data = bite
			break

func _push_genome_to_body() -> void:
	var body: Node = get_node_or_null("Body")
	if body == null:
		return
	# The ProceduralMushroomBody pulls the genome straight off mushroom_data.
	# Setter triggers the build.
	if "mushroom_data" in body:
		body.mushroom_data = mushroom_data
	if body.has_method("rebuild_from_genome"):
		body.call("rebuild_from_genome")

## Glow mutation: feature #8 in the visible-features list. Adds an OmniLight3D
## tinted with the genome's glow_color so rare bioluminescent mushrooms light
## up their surroundings. Cap color also gets a slight emission boost.
func _apply_glow_mutation() -> void:
	if mushroom_data == null or not mushroom_data.genome.has("mutation"):
		return
	var mutation: Dictionary = mushroom_data.genome["mutation"]
	if not bool(mutation.get("glow", false)):
		return
	var glow_color: Color = Color(mutation.get("glow_color", Color(0.4, 1.0, 0.6)))
	var light := OmniLight3D.new()
	light.name = "MushroomGlow"
	light.light_color = glow_color
	light.light_energy = 1.4
	light.omni_range = 4.0
	light.position = Vector3(0, 0.6, 0)
	add_child(light)
	# Boost cap material emission so the cap itself looks lit-from-within.
	var body: Node = get_node_or_null("Body")
	if body and body.has_node("Cap/CapMesh"):
		var cap_mesh: MeshInstance3D = body.get_node("Cap/CapMesh") as MeshInstance3D
		if cap_mesh and cap_mesh.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = cap_mesh.material_override as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = glow_color
			mat.emission_energy_multiplier = 0.6

func _setup_ability_from_settings() -> void:
	if ability_component == null:
		return
	ability_component.actions.clear()
	# v1 mushroom only has Spore Burst.
	var spore_action: AbilityAction = SporeBurstScript.new(self, ability_component)
	ability_component.add_action(spore_action)

func get_actor_color() -> Color:
	if mushroom_data and mushroom_data.genome.has("palette"):
		var pal: Dictionary = mushroom_data.genome["palette"]
		return Color(pal.get("cap_color", Color(0.86, 0.25, 0.25)))
	return Color(0.86, 0.25, 0.25)

## Status-effect filter: Mushrooms don't burn the same way meat does, but they
## do take extra damage from fire. (Genome.mutation could later override this.)
func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	var clean_type: String = String(type).to_lower().strip_edges()
	if clean_type == "fire":
		amount *= 1.5
	super.take_damage(amount, type, direction)
