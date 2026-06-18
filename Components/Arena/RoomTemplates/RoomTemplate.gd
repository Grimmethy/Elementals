class_name RoomTemplate
extends Resource

## Base class for procedural room templates. A RoomTemplate is a Resource
## (not a Node) — it's data describing how to populate a room, not the
## scene itself. The DungeonRunController + arena spawning combine the
## template's data into actual entities at run time.
##
## Subclasses:
##   WarmupRoomTemplate    — easy fight, 2-3 weak monsters
##   BranchRoomTemplate    — loot OR alpha choice
##   MidBossRoomTemplate   — single tougher enemy, ~40% of deaths happen here
##   BossRoomTemplate      — push-for-it final room with rare rewards
##
## Each template has a biome affinity (Crystal Caverns / Spider Nest / Volcano)
## and difficulty multiplier so the same template pool scales across biomes.

@export var room_id: String = ""

## Biome this template belongs to. Empty = generic / works anywhere.
@export var biome: String = ""

## Difficulty multiplier — scales enemy stats and counts.
@export var difficulty: float = 1.0

## Enemy actor types to spawn. ActorTypeData species names.
## E.g. ["Goblin", "Goblin", "Wolf"]
@export var enemy_types: Array[String] = []

## Loot table — rewards added to the run on completion.
@export var loot_gold_min: int = 0
@export var loot_gold_max: int = 0
@export var loot_parts: Array[String] = []

## Capture target — for Alpha branch rooms. Empty string = no alpha.
@export var alpha_species: String = ""

## Called by the run controller to populate the room. Default does nothing —
## subclasses override or the spawn logic lives in an external Arena method
## that reads template fields.
##
## [arena] The arena node — used to spawn enemies, place loot, etc.
## [seed_value] Run/room seed for deterministic procedural variations.
func populate_room(_arena: Node, _seed_value: int) -> void:
	pass

## Called when the room is cleared / completed. Subclasses can emit signals,
## drop rewards into the run controller, etc.
##
## [run_controller] The DungeonRunController to add rewards to.
## [room_seed] Deterministic seed for loot rolls.
func on_room_completed(run_controller: Node, room_seed: int) -> void:
	if run_controller == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = room_seed
	if loot_gold_max > loot_gold_min:
		run_controller.call("add_gold", rng.randi_range(loot_gold_min, loot_gold_max))
	elif loot_gold_min > 0:
		run_controller.call("add_gold", loot_gold_min)
	for part in loot_parts:
		run_controller.call("add_part", part)
