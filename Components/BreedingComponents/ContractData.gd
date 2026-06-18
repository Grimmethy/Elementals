class_name ContractData
extends Resource

## A single mission contract for the Hornbound mission board. Players accept
## contracts at the hub, which:
##   1. Locks in the biome / dungeon for the run
##   2. Locks in the objective (hunt / capture / boss / dungeon expedition)
##   3. Sets the reward (gold + parts + reputation)
##   4. Advances the day on accept
##
## Each ContractData is a Resource (.tres) so designers can author boards
## without touching code. The hub's MissionBoard reads a pool of these and
## presents 3-5 to the player per day, refreshed on day-tick.

enum ContractType {
	HUNT,             # Kill a specific number of a monster type
	CAPTURE,          # Bring back N alive of a specific species
	BOSS,             # Defeat a unique named boss in the boss room
	DUNGEON_EXPEDITION, # Generic — clear a 4-room run, no specific target
	BREEDING_MATERIAL,  # Bring back N of a specific monster part
}

@export var contract_id: String = ""
@export var contract_name: String = "Untitled Contract"
@export var description: String = ""

## Which contract pattern this is. Drives objective + reward calculation.
@export var contract_type: ContractType = ContractType.DUNGEON_EXPEDITION

## Which biome the dungeon runs in. Must match a key in StarterRoomTemplates.
@export var biome: String = "crystal_caverns"

## Objective parameters — meaning depends on contract_type:
##   HUNT             → target_species + target_count
##   CAPTURE          → target_species + target_count
##   BOSS             → target_species (the boss's species name)
##   DUNGEON_EXPED.   → target_count = floor count required
##   BREEDING_MAT.    → target_species (the part identifier) + target_count
@export var target_species: String = ""
@export var target_count: int = 1

## Difficulty 1-5. Drives enemy stat scaling and reward magnitude.
@export var difficulty: int = 1

## Reward on completion. Reputation feeds contract tier unlocks.
@export var reward_gold: int = 50
@export var reward_parts: Array[String] = []
@export var reward_reputation: int = 1

## Risk modifier — chance multiplier for monster wipes. 1.0 = normal.
@export var risk_modifier: float = 1.0

## How long until this contract expires off the board (in days). 0 = persistent.
@export var expires_in_days: int = 3

## Dungeon seed for this specific contract. Rolled when the contract is
## created — every contract gets its own unique map. Applied to
## GameSettings.noise_seed when the contract is accepted, so the arena
## generates a fresh grid layout the player has never seen before.
@export var dungeon_seed: int = 0

## Returns true if the player's squad meets the minimum requirements to
## ATTEMPT this contract (e.g. has at least 1 monster, isn't all exhausted).
## More elaborate gate logic (specific species required, etc.) can extend.
func can_attempt(squad: Array) -> bool:
	if squad == null or squad.is_empty():
		return false
	for member in squad:
		if member == null:
			continue
		if "is_exhausted" in member and not member.is_exhausted:
			return true
	return false

## Human-readable summary for the mission board UI.
func summary() -> String:
	var diff_stars: String = "★".repeat(difficulty) + "☆".repeat(maxi(0, 5 - difficulty))
	var obj: String = ""
	match contract_type:
		ContractType.HUNT:
			obj = "Hunt %d × %s" % [target_count, target_species]
		ContractType.CAPTURE:
			obj = "Capture %d × %s (ALIVE)" % [target_count, target_species]
		ContractType.BOSS:
			obj = "Defeat the %s" % target_species
		ContractType.DUNGEON_EXPEDITION:
			obj = "Clear %d floors of %s" % [target_count, biome.capitalize()]
		ContractType.BREEDING_MATERIAL:
			obj = "Recover %d × %s" % [target_count, target_species]
	return "%s | %s | %s | Reward: %d gp" % [diff_stars, biome.capitalize(), obj, reward_gold]

# ============================================================================
# Sample contract factory — used by MissionBoard until designers author .tres
# ============================================================================

## Build a sample contract programmatically. Used by the mission board when
## no .tres pool is configured (early dev) or as a fallback if all .tres
## contracts are expired.
static func make_sample(seed_value: int) -> ContractData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	var c := ContractData.new()
	var type_pick: int = rng.randi() % 4
	var biome_pool: Array[String] = ["crystal_caverns", "spider_nest", "volcano"]
	c.biome = biome_pool[rng.randi() % biome_pool.size()]
	c.difficulty = rng.randi_range(1, 5)
	c.reward_gold = 30 + c.difficulty * 25 + rng.randi() % 20
	c.reward_reputation = c.difficulty
	c.expires_in_days = 3
	c.contract_id = "sample_%d" % seed_value
	# Roll a unique dungeon seed for this contract — every contract gets its
	# own map. Derived from seed_value so the same contract on the same day
	# always generates the same map (stable for retries / leaderboards).
	c.dungeon_seed = (seed_value * 1103515245 + 12345) & 0x7FFFFFFF

	match type_pick:
		0:
			c.contract_type = ContractType.HUNT
			c.target_species = ["Goblin", "Skeleton", "Zombie", "Wolf"][rng.randi() % 4]
			c.target_count = rng.randi_range(2, 5)
			c.contract_name = "Cull the %ss" % c.target_species
			c.description = "Reduce the %s population threatening the homestead." % c.target_species
		1:
			c.contract_type = ContractType.CAPTURE
			c.target_species = ["Wolf", "Imp", "Pixie", "Sheep"][rng.randi() % 4]
			c.target_count = rng.randi_range(1, 2)
			c.contract_name = "Live Capture: %s" % c.target_species
			c.description = "Bring back %d %s alive. Required for trait research." % [c.target_count, c.target_species]
			c.reward_gold *= 2  # Capture pays better
		2:
			c.contract_type = ContractType.BOSS
			c.target_species = ["Ghoul", "Wight", "Magmin"][rng.randi() % 3]
			c.target_count = 1
			c.contract_name = "Bounty: %s" % c.target_species
			c.description = "A %s lurks in the deepest part of the dungeon. Bring proof of its defeat." % c.target_species
			c.reward_gold *= 3
			c.difficulty = clampi(c.difficulty + 1, 1, 5)
		_:
			c.contract_type = ContractType.DUNGEON_EXPEDITION
			c.target_count = rng.randi_range(3, 4)
			c.contract_name = "Expedition into %s" % c.biome.capitalize()
			c.description = "Survey the %s. Push as deep as you dare; extract any time." % c.biome
	return c
