extends Node

## HerdManager orchestrates herd, economy, and progression systems.
## Delegating work to specialized components to avoid god-object patterns.
## This manager is actor-type-agnostic — it works with any ActorData subclass.

# Components
var herd_manager: HerdComponent
var economy_manager: EconomyComponent
var progression_manager: ProgressionComponent
var save_manager: SaveComponent
var breeding_manager: BreedingComponent
## Hornbound: mission board owning the daily contract refresh + accept flow.
var mission_board: MissionBoard

var herd: Array[ActorData]:
	get: return herd_manager.herd

var gold: int:
	get: return economy_manager.gold
	set(v): economy_manager.gold = v

var current_day: int:
	get: return progression_manager.current_day

const MAX_TEAM_SIZE = 4
const NET_CAPTURE_CHANCE: float = 0.5

## When set, the next arena spawn enters SOLO MODE — only this creature
## spawns (not the group of "Select for Arena" checked members) and the
## player controls it directly with its full bred genome.
##
## Set by ActorCard's "Play As" button. Cleared by ArenaSpawner after spawn.
## Lives on HerdManager because it's a one-shot transport between scenes —
## doesn't belong in GameSettings (which is persistent config) and doesn't
## belong on any per-actor data resource.
var pending_individual_creature: ActorData = null

## Hornbound: when true, the next arena entry spins up a DungeonRunController
## for a structured 4-room run. When false (default), the arena runs in
## sandbox / free-play mode (existing behavior).
## Set by the hub when the player accepts a contract; cleared by Arena on
## run completion.
var pending_run_mode: bool = false

## Hornbound: the contract the player accepted at the mission board. Carried
## through scene change to the arena. The arena reads biome / objective /
## reward parameters from this to configure the run. Cleared after run end.
var accepted_contract: ContractData = null

## Hornbound: the full squad (Array[ActorData]) the player picked at the
## Squad Picker. Index 0 = lead (the monster the player will play as);
## 1..N = AI pack. The arena reads this on _ready to call
## DungeonRunController.start_run with the correct squad. Cleared after run.
var pending_squad: Array = []
const NET_DISABLE_DURATION: float = 1.6
const NET_CLOSE_RANGE: float = 2.6
const NET_THROW_RANGE: float = 12.0
const NET_THROW_IMPACT_RADIUS: float = 2.4

func _ready() -> void:
	randomize()
	_setup_components()
	_load_initial_state()
	_connect_signals()

func _setup_components() -> void:
	herd_manager = preload("res://Core/Managers/HerdComponent.gd").new()
	herd_manager.name = "HerdComponent"
	add_child(herd_manager)
	
	economy_manager = preload("res://Core/Managers/EconomyComponent.gd").new()
	economy_manager.name = "EconomyComponent"
	add_child(economy_manager)
	
	progression_manager = preload("res://Core/Managers/ProgressionComponent.gd").new()
	progression_manager.name = "ProgressionComponent"
	add_child(progression_manager)
	
	save_manager = preload("res://Core/Managers/SaveComponent.gd").new()
	save_manager.name = "SaveComponent"
	add_child(save_manager)
	
	breeding_manager = preload("res://Core/Managers/BreedingComponent.gd").new()
	breeding_manager.name = "BreedingComponent"
	add_child(breeding_manager)

	# Hornbound: mission board lives as a child of HerdManager so the hub UI
	# can reach it via `HerdManager.mission_board` and the day-tick logic can
	# refresh it after `BondManager.advance_day`.
	mission_board = preload("res://Components/BreedingComponents/MissionBoard.gd").new()
	mission_board.name = "MissionBoard"
	add_child(mission_board)

func _load_initial_state() -> void:
	var save_data: GoatSaveData = save_manager.load_game()
	if save_data:
		herd_manager.initialize(save_data.herd)
		economy_manager.initialize(save_data.gold)
		progression_manager.initialize(save_data.current_day)
	else:
		herd_manager.generate_starter_herd()
		save_game()

func _connect_signals() -> void:
	# Wire up auto-saving on relevant events
	GameEvents.herd_updated.connect(save_game)
	GameEvents.day_advanced.connect(func(_d): save_game())
	GameEvents.gold_changed.connect(func(_g): save_game())
	herd_manager.herd_state_changed.connect(save_game)

# --- Delegate Methods ---

func toggle_selection(actor: ActorData) -> bool:
	return herd_manager.toggle_selection(actor)

func get_selected_goats() -> Array[ActorData]:
	return herd_manager.get_selected_goats()

func add_goat(actor: ActorData) -> void:
	herd_manager.add_goat(actor)

func remove_goat(actor: ActorData) -> void:
	herd_manager.remove_goat(actor)

func sell_goat(actor: ActorData) -> void:
	# Cast to GoatData for goat-specific property, but design supports any ActorData
	var goat = actor as GoatData
	if goat:
		economy_manager.gold += goat.gold_value
	remove_goat(actor)

func breed(parent_a: ActorData, parent_b: ActorData) -> bool:
	return breeding_manager.breed(parent_a, parent_b)

func next_day() -> void:
	progression_manager.advance_day(herd_manager.herd)

	# Process pregnancies with the generic polymorphic handler. Any kid
	# returned (GoatData, MimicData, GoblinData hybrid, ...) is added to the
	# herd via the actor-type-agnostic add_goat() — HerdComponent stores the
	# herd as Array[ActorData], not Array[GoatData].
	var new_kids: Array[ActorData] = breeding_manager.process_pregnancy(herd_manager.herd)
	for kid in new_kids:
		if kid == null:
			continue
		add_goat(kid)
		if kid.inherit_mimic_skills:
			print("[Breeding] %s inherited mimic skills (mimic_blood=%.2f)" % [
				_kid_display_name(kid),
				kid.mimic_blood
			])

	# Any other day-transition logic...
	GameEvents.herd_updated.emit()

func _kid_display_name(kid: ActorData) -> String:
	if kid == null:
		return "<null>"
	if "goat_name" in kid:
		return String(kid.goat_name)
	if "creature_name" in kid:
		return String(kid.creature_name)
	return kid.get_actor_type()

func save_game() -> void:
	save_manager.save_game(herd_manager.herd, economy_manager.gold, progression_manager.current_day)

# --- Capture ---

func attempt_capture_with_net(capturer: Actor, target_position: Vector3, reach: float = NET_THROW_RANGE) -> Dictionary:
	return throw_net_at(capturer, target_position, reach, NET_THROW_IMPACT_RADIUS)

func use_net_close(capturer: Actor, target_position: Vector3 = Vector3.ZERO, use_target_position: bool = false, max_distance: float = NET_CLOSE_RANGE) -> Dictionary:
	if capturer == null or not is_instance_valid(capturer):
		return _capture_result(false, false, "Invalid capturer.", 0, 0.0, false)
	
	var search_center: Vector3 = capturer.global_position
	var point_radius: float = max_distance
	if use_target_position:
		search_center = target_position
		point_radius = 1.8
	
	var target: Actor = _find_capture_target(capturer, search_center, max_distance, point_radius)
	if target == null:
		_emit_capture_message("No capture target in range.")
		return _capture_result(false, false, "No valid target nearby.", 0, NET_CAPTURE_CHANCE, false)
	
	return _resolve_capture_attempt(capturer, target)

func throw_net_at(capturer: Actor, target_position: Vector3, max_distance: float = NET_THROW_RANGE, impact_radius: float = NET_THROW_IMPACT_RADIUS) -> Dictionary:
	if capturer == null or not is_instance_valid(capturer):
		return _capture_result(false, false, "Invalid capturer.", 0, 0.0, false)
	
	var target: Actor = _find_capture_target(capturer, target_position, max_distance, impact_radius)
	if target == null:
		_emit_capture_message("Net missed. No capture target hit.")
		return _capture_result(false, false, "No valid target at net impact.", 0, NET_CAPTURE_CHANCE, false)
	
	return _resolve_capture_attempt(capturer, target)

func _resolve_capture_attempt(capturer: Actor, target: Actor) -> Dictionary:
	if not _is_capture_candidate(capturer, target):
		_emit_capture_message("That target cannot be captured.")
		return _capture_result(false, false, "Target is not capturable.", 0, NET_CAPTURE_CHANCE, false)

	# Hornbound: check the species' capture archetype precondition. For MVP, only
	# "weaken" is fully enforced (HP < 30%); the other archetypes are stubbed and
	# always pass with a log message. Full mini-puzzles are post-MVP work.
	var species_resolve: String = _resolve_species_id(target).capitalize()
	var archetype: String = ActorTypeData.get_capture_archetype(species_resolve)
	if not _check_capture_archetype(target, archetype):
		_emit_capture_message("%s needs its %s precondition first." % [target.name, archetype])
		return _capture_result(false, false, "Archetype precondition not met (%s)." % archetype, 0, NET_CAPTURE_CHANCE, false)

	var roll: int = randi() % 20 + 1
	var success: bool = false
	
	if roll == 20:
		success = true
	elif roll == 1:
		success = false
	else:
		success = randf() <= NET_CAPTURE_CHANCE
	
	var species_id: String = _resolve_species_id(target)
	var target_name: String = target.name if target.name != "" else species_id
	
	if success:
		var captured_data: GoatData = _build_captured_data(target, species_id)
		add_goat(captured_data)

		# Hornbound: record this capture in the TraitLibrary so the species' traits
		# become breedable in future rolls. Capitalize species_id for ActorTypeData
		# lookup (species_id is lowercase like "goblin", registry keys are "Goblin").
		# Engine.has_singleton() doesn't work for autoloads in Godot 4 — use the
		# scene-tree path check, which is the canonical way.
		var lib: Node = get_node_or_null("/root/TraitLibrary")
		if lib:
			var species_proper: String = species_id.capitalize()
			var new_traits: Array = lib.call("add_capture", species_proper)
			if new_traits is Array and not (new_traits as Array).is_empty():
				_emit_capture_message("Learned %d new traits from %s!" % [(new_traits as Array).size(), species_proper])

		print("[Capture] [%s] net capture roll=%d chance=%.2f -> SUCCESS (%s)" % [capturer.name, roll, NET_CAPTURE_CHANCE, target_name])
		_emit_capture_message("Captured %s!" % target_name)
		
		if target.has_method("die"):
			target.die()
		target.call_deferred("queue_free")
		return _capture_result(true, true, "Capture succeeded.", roll, NET_CAPTURE_CHANCE, true, captured_data)
	
	if target.has_method("stun"):
		target.stun(NET_DISABLE_DURATION)
	
	print("[Capture] [%s] net capture roll=%d chance=%.2f -> FAILURE (%s)" % [capturer.name, roll, NET_CAPTURE_CHANCE, target_name])
	_emit_capture_message("Capture failed on %s." % target_name)
	return _capture_result(true, false, "Capture failed.", roll, NET_CAPTURE_CHANCE, false)

func _find_capture_target(capturer: Actor, center: Vector3, max_distance_from_capturer: float, within_center_radius: float) -> Actor:
	var arena_value: Variant = capturer.get("_arena_grid")
	if not (arena_value is ArenaGrid):
		return null
	
	var arena: ArenaGrid = arena_value as ArenaGrid
	var nearest: Actor = null
	var nearest_dist: float = INF
	
	for node in arena.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var actor: Actor = node as Actor
		if actor == capturer:
			continue
		
		var distance_to_capturer: float = _flat_distance(actor.global_position, capturer.global_position)
		if distance_to_capturer > max_distance_from_capturer:
			continue
		
		var distance_to_center: float = _flat_distance(actor.global_position, center)
		if distance_to_center > within_center_radius:
			continue
		
		if not _is_capture_candidate(capturer, actor):
			continue
		
		if distance_to_center < nearest_dist:
			nearest_dist = distance_to_center
			nearest = actor
	
	return nearest

func _is_capture_candidate(capturer: Actor, target: Actor) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.is_dead:
		return false
	if target.is_playable:
		return false
	if target.has_meta("capture_candidate"):
		return bool(target.get_meta("capture_candidate"))
	
	if target.faction_component:
		var faction: int = int(target.faction_component.faction)
		if faction == FactionComponent.Faction.PLAYER or faction == FactionComponent.Faction.FARMSTEAD:
			return false
	
	# Fallback for legacy/non-tagged targets: anything non-playable and not allied can be captured.
	if capturer and capturer.has_method("is_ally") and capturer.is_ally(target):
		return false
	return true

func _resolve_species_id(target: Actor) -> String:
	if target and target.has_meta("capture_species"):
		var tagged: String = String(target.get_meta("capture_species", "")).to_lower().strip_edges()
		if not tagged.is_empty():
			return tagged
	
	if target and target.element_type:
		var element_species := target.element_type.to_lower().strip_edges()
		if not element_species.is_empty():
			return element_species
	
	if target is GoatActor:
		return "goat"
	if target is GoblinMinion:
		return "goblin"
	return "creature"

## Verify the capture archetype's precondition is met for this target.
##
## Archetypes:
##   "weaken"          — HP < 30% required. The default.
##   "break_armor"     — Target must have its armor broken (sets meta flag).
##   "kill_lessers"    — All weaker minions of the same species must be down.
##   "counter_charge"  — Target must have been parried during a charge (meta flag).
##
## Returns true if the precondition is satisfied, false to deny the capture.
## Non-weaken archetypes are stub-implemented for MVP — they check meta flags
## that visual / combat code will set in a later phase. Until then they all
## return true so captures aren't gated.
func _check_capture_archetype(target: Actor, archetype: String) -> bool:
	if target == null:
		return false
	match archetype:
		"weaken":
			# Require HP at or below 30% to capture. Standard archetype.
			if target.health_component:
				var hp_ratio: float = target.health_component.current_health / max(1.0, target.health_component.max_health)
				return hp_ratio <= 0.30
			return true
		"break_armor":
			if target.has_meta("armor_broken"):
				return bool(target.get_meta("armor_broken"))
			return true  # Stub-allow for MVP
		"kill_lessers":
			if target.has_meta("lessers_cleared"):
				return bool(target.get_meta("lessers_cleared"))
			return true  # Stub-allow for MVP
		"counter_charge":
			if target.has_meta("charge_countered"):
				return bool(target.get_meta("charge_countered"))
			return true  # Stub-allow for MVP
		_:
			# Unknown archetype — allow capture by default (forward-compatible).
			return true

func _build_captured_data(target: Actor, species_id: String) -> GoatData:
	# Important: duplicate GoatData so GoatActor.die() removing its own data will not remove the captured copy.
	if target is GoatActor:
		var goat_target: GoatActor = target as GoatActor
		if goat_target.goat_data:
			var dup_data: GoatData = goat_target.goat_data.duplicate(true) as GoatData
			if dup_data:
				dup_data.is_selected = false
				dup_data.is_exhausted = false
				return dup_data
	
	var data := GoatData.new()
	data.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	data.goat_name = _generate_capture_name(species_id)
	data.is_selected = false
	data.is_exhausted = false
	data.horn_type = GoatData.HornType.NONE
	data.body_type = GoatData.BodyType.MEDIUM
	data.pattern_type = GoatData.PatternType.SOLID
	
	match species_id:
		"goblin":
			data.base_color = Color(0.42, 0.66, 0.28)
			data.pattern_color = Color(0.20, 0.36, 0.14)
			data.gold_value = 65
		"mimic":
			data.base_color = Color(0.46, 0.31, 0.17)
			data.pattern_color = Color(0.24, 0.16, 0.08)
			data.gold_value = 80
			# Captured mimics retain their full bloodline. Without this, the
			# only way a player ever gets mimic blood into the herd today (the
			# net) would silently downgrade the creature to a vanilla goat for
			# breeding purposes, defeating the 30/60/100 probability gates.
			data.mimic_blood = 1.0
			data.inherit_mimic_skills = true
		"mushroom":
			data.base_color = Color(0.86, 0.25, 0.25)
			data.pattern_color = Color(0.95, 0.95, 0.88)
			data.gold_value = 45
		_:
			data.base_color = Color(0.68, 0.58, 0.43)
			data.pattern_color = Color(0.30, 0.23, 0.16)
			data.gold_value = 55
	
	if target and target.ability_scores_component:
		var asc = target.ability_scores_component
		data.strength = asc.strength
		data.dexterity = asc.dexterity
		data.constitution = asc.constitution
		data.intelligence = asc.intelligence
		data.wisdom = asc.wisdom
		data.charisma = asc.charisma
	
	return data

func _generate_capture_name(species_id: String) -> String:
	var clean_species: String = species_id.capitalize()
	var suffix: int = randi() % 900 + 100
	return "%s %d" % [clean_species, suffix]

func _emit_capture_message(text: String) -> void:
	print("[Capture] ", text)
	if has_node("/root/QuestEvents"):
		QuestEvents.message(text)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _capture_result(attempted: bool, success: bool, reason: String, roll: int, chance: float, captured: bool, creature: ActorData = null) -> Dictionary:
	return {
		"attempted": attempted,
		"success": success,
		"reason": reason,
		"roll": roll,
		"chance": chance,
		"captured": captured,
		"creature": creature
	}

# ============================================================================
# Hornbound — Active herd + Pension + Squad Loadouts
# ============================================================================
##
## The herd is split into TWO conceptual pools:
##   ACTIVE  — up to MAX_ACTIVE_HERD creatures. These can be deployed to
##             squads and sent into runs. Bonded combos are eligible here.
##   PENSION — unlimited. These creatures can ONLY breed; they can't deploy.
##             Free, instant swap to active. Pension is the "vault" for
##             beloved or breeding-only monsters.
##
## Both pools live within the existing herd array — active membership is
## tracked by render_seed in `_active_ids`. This avoids array-shuffling on
## rotation and keeps the existing herd APIs intact.

const MAX_ACTIVE_HERD: int = 12

## Active-membership tracker. render_seeds of currently-active herd members.
## Pension members are those in `herd` not in this set.
var _active_ids: Array[int] = []

## Named squad loadouts. Each loadout is an Array[int] of render_seeds.
var squad_loadouts: Dictionary = {
	"Loadout A": [],
	"Loadout B": [],
	"Loadout C": [],
}

signal active_pension_changed()

func _ensure_active_initialized() -> void:
	if not _active_ids.is_empty():
		return
	var ids: Array[int] = []
	for i in range(min(MAX_ACTIVE_HERD, herd.size())):
		var m: ActorData = herd[i]
		if m and "render_seed" in m:
			ids.append(int(m.render_seed))
	_active_ids = ids

## Returns the currently-active herd as an Array[ActorData].
func get_active_herd() -> Array[ActorData]:
	_ensure_active_initialized()
	var out: Array[ActorData] = []
	for member in herd:
		if member and "render_seed" in member and int(member.render_seed) in _active_ids:
			out.append(member)
	return out

## Returns the pension as an Array[ActorData] (everything not active).
func get_pension() -> Array[ActorData]:
	_ensure_active_initialized()
	var out: Array[ActorData] = []
	for member in herd:
		if member and "render_seed" in member and not (int(member.render_seed) in _active_ids):
			out.append(member)
	return out

## Move a creature from active to pension. Always succeeds.
func move_to_pension(actor_data: ActorData) -> void:
	if actor_data == null or not "render_seed" in actor_data:
		return
	var rid: int = int(actor_data.render_seed)
	if rid in _active_ids:
		_active_ids.erase(rid)
		active_pension_changed.emit()

## Move a creature from pension to active. Fails silently if active is full.
func restore_from_pension(actor_data: ActorData) -> bool:
	if actor_data == null or not "render_seed" in actor_data:
		return false
	var rid: int = int(actor_data.render_seed)
	if rid in _active_ids:
		return true
	if _active_ids.size() >= MAX_ACTIVE_HERD:
		return false
	_active_ids.append(rid)
	active_pension_changed.emit()
	return true

## Swap an active member with a pension member. Always succeeds.
func swap_active_with_pension(active_member: ActorData, pension_member: ActorData) -> void:
	if active_member == null or pension_member == null:
		return
	if not ("render_seed" in active_member and "render_seed" in pension_member):
		return
	var a_id: int = int(active_member.render_seed)
	var p_id: int = int(pension_member.render_seed)
	if a_id in _active_ids:
		_active_ids.erase(a_id)
	if not (p_id in _active_ids) and _active_ids.size() < MAX_ACTIVE_HERD:
		_active_ids.append(p_id)
	active_pension_changed.emit()

## Save a squad loadout. squad is an Array of ActorData.
func save_loadout(loadout_name: String, squad: Array) -> void:
	var seeds: Array[int] = []
	for member in squad:
		if member is ActorData and "render_seed" in member:
			seeds.append(int(member.render_seed))
		elif member is int:
			seeds.append(int(member))
		else:
			seeds.append(0)
	squad_loadouts[loadout_name] = seeds

## Load a squad loadout. Returns Array[ActorData] — null entries for missing creatures.
func load_loadout(loadout_name: String) -> Array:
	var seeds: Array = squad_loadouts.get(loadout_name, [])
	var out: Array = []
	for seed_value in seeds:
		var rid: int = int(seed_value)
		var found: ActorData = null
		for member in herd:
			if member and "render_seed" in member and int(member.render_seed) == rid:
				found = member
				break
		out.append(found)
	return out

