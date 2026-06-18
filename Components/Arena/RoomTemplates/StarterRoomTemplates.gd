class_name StarterRoomTemplates
extends RefCounted

## Sample / starter RoomTemplate instances for the MVP biomes. These are
## constructed programmatically (cheaper than authoring 30 .tres files by
## hand for an MVP), and can be referenced by the run controller as a starting
## room pool. Real authored .tres files can replace these later for designer-
## controlled content.
##
## Three biomes × four room types = 12 default templates.

## Returns a small pool of templates for the given biome + room type.
##
## [biome] One of "crystal_caverns", "spider_nest", "volcano".
## [room_type] One of "warmup", "branch_loot", "branch_alpha", "midboss", "boss".
## [Returns] Array of RoomTemplate instances. Caller can pick_random.
static func get_pool(biome: String, room_type: String) -> Array:
	match biome:
		"crystal_caverns": return _crystal_caverns_pool(room_type)
		"spider_nest":     return _spider_nest_pool(room_type)
		"volcano":         return _volcano_pool(room_type)
		_:                 return _crystal_caverns_pool(room_type)  # Default to caverns.

# ============================================================================
# Crystal Caverns — sonic / earth monsters; walls break to reveal secrets
# ============================================================================

static func _crystal_caverns_pool(room_type: String) -> Array:
	match room_type:
		"warmup":
			return [
				_make_template("cc_warmup_1", "crystal_caverns", 1.0,
					["Goblin", "Goblin"], 8, 14, ["crystal_shard"], ""),
				_make_template("cc_warmup_2", "crystal_caverns", 1.0,
					["Skeleton", "Skeleton"], 6, 12, ["bone_dust"], ""),
			]
		"branch_loot":
			return [
				_make_template("cc_loot_1", "crystal_caverns", 0.8,
					["Goblin"], 20, 40, ["crystal_shard", "geode"], ""),
			]
		"branch_alpha":
			return [
				_make_template("cc_alpha_1", "crystal_caverns", 1.5,
					["Goblin", "Goblin"], 5, 10, ["crystal_shard"], "Wolf"),
			]
		"midboss":
			return [
				_make_template("cc_midboss_1", "crystal_caverns", 1.8,
					["Skeleton", "Skeleton", "Zombie"], 30, 55, ["bone_dust", "crystal_shard"], ""),
			]
		"boss":
			return [
				_make_template("cc_boss_1", "crystal_caverns", 2.5,
					["Zombie"], 80, 120, ["geode", "primordial_essence"], "Wight"),
			]
	return []

# ============================================================================
# Spider Nest — poison resistance matters; web traps slow movement
# ============================================================================

static func _spider_nest_pool(room_type: String) -> Array:
	match room_type:
		"warmup":
			return [
				_make_template("sn_warmup_1", "spider_nest", 1.0,
					["Goblin", "Skeleton"], 8, 14, ["spider_silk"], ""),
			]
		"branch_loot":
			return [
				_make_template("sn_loot_1", "spider_nest", 0.9,
					["Goblin"], 20, 35, ["spider_silk", "venom_sac"], ""),
			]
		"branch_alpha":
			return [
				_make_template("sn_alpha_1", "spider_nest", 1.6,
					["Skeleton"], 5, 10, ["spider_silk"], "Wolf"),
			]
		"midboss":
			return [
				_make_template("sn_midboss_1", "spider_nest", 2.0,
					["Goblin", "Zombie", "Zombie"], 35, 60, ["venom_sac"], ""),
			]
		"boss":
			return [
				_make_template("sn_boss_1", "spider_nest", 2.6,
					["Zombie", "Zombie"], 90, 140, ["venom_sac", "primordial_essence"], "Ghoul"),
			]
	return []

# ============================================================================
# Volcano — fire resistance matters; magma tiles damage non-resistant
# ============================================================================

static func _volcano_pool(room_type: String) -> Array:
	match room_type:
		"warmup":
			return [
				_make_template("vol_warmup_1", "volcano", 1.1,
					["Skeleton", "Skeleton"], 10, 16, ["sulfur_chunk"], ""),
			]
		"branch_loot":
			return [
				_make_template("vol_loot_1", "volcano", 1.0,
					["Skeleton"], 22, 42, ["sulfur_chunk", "obsidian_shard"], ""),
			]
		"branch_alpha":
			return [
				_make_template("vol_alpha_1", "volcano", 1.7,
					["Zombie"], 6, 12, ["sulfur_chunk"], "Imp"),
			]
		"midboss":
			return [
				_make_template("vol_midboss_1", "volcano", 2.2,
					["Zombie", "Zombie", "Imp"], 40, 70, ["obsidian_shard"], ""),
			]
		"boss":
			return [
				_make_template("vol_boss_1", "volcano", 2.8,
					["Imp", "Imp"], 100, 160, ["obsidian_shard", "primordial_essence"], "Magmin"),
			]
	return []

# ============================================================================
# Helper — construct a RoomTemplate with the given parameters
# ============================================================================

static func _make_template(
	id: String,
	biome: String,
	difficulty: float,
	enemy_types: Array[String],
	loot_gold_min: int,
	loot_gold_max: int,
	loot_parts: Array[String],
	alpha_species: String
) -> RoomTemplate:
	var t := RoomTemplate.new()
	t.room_id = id
	t.biome = biome
	t.difficulty = difficulty
	t.enemy_types = enemy_types
	t.loot_gold_min = loot_gold_min
	t.loot_gold_max = loot_gold_max
	t.loot_parts = loot_parts
	t.alpha_species = alpha_species
	return t
