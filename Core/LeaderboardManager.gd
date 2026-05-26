extends Node

## Autoload — local leaderboard storage for Hornbound's five competitive boards.
##
##   1. Deepest Dive          — Most floors in a single endless run
##   2. Apex Bloodline        — Fewest generations to a 14-category chimera (lower is better)
##   3. Trait Library Speed   — Days-to-reach trait count milestones (lower is better)
##   4. Contract Chain        — Longest consecutive successful run streak (higher is better)
##   5. Highest-Rated Chimera — One monster's combined score (higher is better)
##
## Plus the daily seeded run mechanic: same dungeon seed for everyone in the
## world per day, derived from the Unix day index. Pure tactical board, no
## breeding head-start matters.
##
## All scores stored locally in user://leaderboards.cfg. Future work: optional
## online backend (Steam Leaderboards or custom).

const SAVE_PATH := "user://leaderboards.cfg"

## Boards by their ID. Each board is an Array of score entries.
## Entry schema:
##   { score: float, date: String, label: String, meta: Dictionary }
var boards: Dictionary = {
	"deepest_dive": [],
	"apex_bloodline": [],
	"trait_library_speed_50": [],
	"trait_library_speed_100": [],
	"trait_library_speed_all": [],
	"contract_chain": [],
	"chimera_rating": [],
	"daily_run": [],  # Keyed by daily seed in meta
}

## Lower-is-better boards. Score sort order is reversed for these.
const LOWER_IS_BETTER: Array[String] = [
	"apex_bloodline",
	"trait_library_speed_50",
	"trait_library_speed_100",
	"trait_library_speed_all",
]

## Maximum entries kept per board.
const MAX_ENTRIES_PER_BOARD := 25

# ============================================================================
# Signals
# ============================================================================

signal score_submitted(board: String, score: float, rank: int)
signal personal_best(board: String, score: float)

# ============================================================================
# Public API
# ============================================================================

func _ready() -> void:
	_load()

## Submit a score to a board.
##
## [board] One of the keys in `boards`.
## [score] The score value.
## [label] A human-readable label (creature name, "Floor 7", etc.).
## [meta] Optional dict of extra info (run seed, biome, etc.).
## [Returns] The rank achieved (1-indexed), or -1 if the board doesn't exist.
func submit_score(board: String, score: float, label: String = "", meta: Dictionary = {}) -> int:
	if not boards.has(board):
		push_warning("LeaderboardManager: unknown board '%s'" % board)
		return -1
	var entry: Dictionary = {
		"score": score,
		"date": Time.get_datetime_string_from_system(true),
		"label": label,
		"meta": meta,
	}
	var arr: Array = boards[board]
	arr.append(entry)
	_sort_board(board)
	# Trim to max entries.
	while arr.size() > MAX_ENTRIES_PER_BOARD:
		arr.pop_back()
	# Find rank (1-indexed).
	var rank: int = -1
	for i in range(arr.size()):
		if (arr[i] as Dictionary).get("date") == entry.date:
			rank = i + 1
			break
	score_submitted.emit(board, score, rank)
	if rank == 1:
		personal_best.emit(board, score)
	_save()
	return rank

## Returns the board's entries in rank order (best first).
func get_board(board: String) -> Array:
	return boards.get(board, [])

## Returns the player's best score on a board, or NaN if no entries.
func get_personal_best(board: String) -> float:
	var arr: Array = boards.get(board, [])
	if arr.is_empty():
		return NAN
	return float((arr[0] as Dictionary).get("score", 0.0))

func _sort_board(board: String) -> void:
	var arr: Array = boards[board]
	var lower_better: bool = board in LOWER_IS_BETTER
	if lower_better:
		arr.sort_custom(func(a, b): return float(a.score) < float(b.score))
	else:
		arr.sort_custom(func(a, b): return float(a.score) > float(b.score))

# ============================================================================
# Score formulas (helpers — called by run/breed completion)
# ============================================================================

## Compute chimera rating score:
##   graft_count × 8 + mutation_count × 6 + hybrid_generation × 4 + library_completeness × 0.5
static func compute_chimera_rating(creature: Object) -> float:
	if creature == null:
		return 0.0
	var score: float = 0.0
	# Hybrid generation.
	if "hybrid_generation" in creature:
		score += float(creature.get("hybrid_generation")) * 4.0
	# Mutations on genome.
	if "genome" in creature:
		var g: Variant = creature.get("genome")
		if g is Dictionary:
			var mutations: Variant = (g as Dictionary).get("universal_mutations", {})
			if mutations is Dictionary:
				for tag in (mutations as Dictionary).keys():
					if bool((mutations as Dictionary)[tag]):
						score += 6.0
			# Graft slots.
			var graft: Variant = (g as Dictionary).get("grafted", {})
			if graft is Dictionary:
				for key in (graft as Dictionary).keys():
					if String(key).begins_with("has_") and bool((graft as Dictionary)[key]):
						score += 8.0
	# Library coverage bonus. Static functions can't call has_node/get_node —
	# reach into the scene tree via Engine.get_main_loop() cast to SceneTree.
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var lib := tree.root.get_node_or_null("/root/TraitLibrary")
		if lib:
			score += float(lib.call("get_known_trait_count")) * 0.5
	return score

## Compute apex bloodline score (lower is better). Returns the hybrid_generation
## of the creature, which represents how many generations of cross-breeding
## were needed to produce it.
static func compute_apex_bloodline_score(creature: Object) -> int:
	if creature == null:
		return 9999
	if "hybrid_generation" in creature:
		return int(creature.get("hybrid_generation"))
	return 9999

# ============================================================================
# Daily seeded run
# ============================================================================

## Returns today's seed for the daily-seeded run. All players in the world
## get the same seed on the same date (UTC day index).
static func get_today_seed() -> int:
	var unix_sec: int = int(Time.get_unix_time_from_system())
	var day_index: int = unix_sec / 86400
	# Hash it to avoid seed predictability.
	return _hash_int(day_index)

## Returns the daily seed for a specific date offset (negative = past days).
static func get_daily_seed_offset(days_from_today: int) -> int:
	var unix_sec: int = int(Time.get_unix_time_from_system())
	var day_index: int = (unix_sec / 86400) + days_from_today
	return _hash_int(day_index)

## Cheap integer hash so today's seed isn't a sequential number.
static func _hash_int(n: int) -> int:
	var x: int = n
	x = ((x >> 16) ^ x) * 0x45d9f3b
	x = ((x >> 16) ^ x) * 0x45d9f3b
	x = (x >> 16) ^ x
	# Keep it positive and modest size.
	return abs(x) % 2147483647

# ============================================================================
# Persistence
# ============================================================================

func _save() -> void:
	var cfg := ConfigFile.new()
	for board_key in boards.keys():
		cfg.set_value("Boards", board_key, boards[board_key])
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for board_key in boards.keys():
		var loaded: Variant = cfg.get_value("Boards", board_key, [])
		if loaded is Array:
			boards[board_key] = loaded

## Wipe all boards. For testing / clear leaderboards menu option.
func reset_all() -> void:
	for key in boards.keys():
		boards[key] = []
	_save()

## Returns a human-readable summary for debugging.
func dump_state() -> String:
	var lines: Array[String] = []
	lines.append("=== LeaderboardManager State ===")
	for board_key in boards.keys():
		var arr: Array = boards[board_key]
		lines.append("[%s] %d entries" % [board_key, arr.size()])
		for i in range(min(3, arr.size())):
			var e: Dictionary = arr[i]
			lines.append("  #%d %.2f — %s" % [i + 1, e.get("score", 0.0), e.get("label", "")])
	return "\n".join(lines)
