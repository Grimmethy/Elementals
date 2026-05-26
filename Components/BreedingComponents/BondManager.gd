extends Node

## Autoload — manages pair-level bonds between monsters that have shared runs
## together. Bonds tick up when both survive a run, never decrease, and unlock
## perks at levels 1-5. Losing a bonded packmate applies a Grief debuff to the
## survivor.
##
## Bonds are identified by the pair of monsters' render_seed (used as a stable
## unique ID — every creature has one, set at construction and inherited via
## breeding). Pair keys are always (min_seed, max_seed) tuples so lookup is
## symmetric.
##
## All bonds and grief state are persisted to user://bond_state.cfg so
## reloading preserves the herd's relationships.

const SAVE_PATH := "user://bond_state.cfg"
const MAX_BOND := 5

## Bond level tick thresholds (run count required to reach each level).
const RUNS_FOR_LEVEL: Dictionary = {
	1: 1,
	2: 3,
	3: 7,
	4: 15,
	5: 30
}

## Emitted whenever a pair's bond level increases. Other systems (UI, combo
## unlock notifications) can listen.
signal bond_increased(seed_a: int, seed_b: int, new_level: int)

## Emitted when grief is applied to a survivor of a bonded death.
signal grief_applied(survivor_seed: int, dead_seed: int, days: int)

# Pair lookup: key = "min_seed,max_seed", value = Dictionary
#   { runs_together: int, level: int }
var _bonds: Dictionary = {}

# Per-creature grief state: key = survivor_seed, value = Array of grief entries
#   [ { dead_seed: int, expires_on_day: int } ]
var _grief: Dictionary = {}

# Current day index (incremented externally by hub day-tick / contract accept).
var current_day: int = 0

func _ready() -> void:
	_load_state()

# ============================================================================
# Pair lookup helpers
# ============================================================================

## Returns the canonical key for a pair (order-independent).
static func _pair_key(seed_a: int, seed_b: int) -> String:
	if seed_a <= seed_b:
		return "%d,%d" % [seed_a, seed_b]
	return "%d,%d" % [seed_b, seed_a]

## Returns the current bond level for a pair (0-5).
func get_bond(seed_a: int, seed_b: int) -> int:
	if seed_a == seed_b:
		return 0
	var key: String = _pair_key(seed_a, seed_b)
	if not _bonds.has(key):
		return 0
	return int(_bonds[key].get("level", 0))

## Returns the number of runs survived together for a pair.
func get_runs_together(seed_a: int, seed_b: int) -> int:
	var key: String = _pair_key(seed_a, seed_b)
	if not _bonds.has(key):
		return 0
	return int(_bonds[key].get("runs_together", 0))

# ============================================================================
# Run-completion bond ticking
# ============================================================================

## Called by the run controller when a squad successfully completes a run.
## All pairs of survivors get their runs_together incremented; pairs that
## hit a new threshold get a bond_increased signal.
##
## [squad] Array of ActorData (the surviving members of the run).
func tick_squad(squad: Array) -> void:
	# Build seed list, filtering out null entries.
	var seeds: Array[int] = []
	for member in squad:
		if member == null:
			continue
		if not "render_seed" in member:
			continue
		seeds.append(int(member.get("render_seed")))
	# Tick every pair.
	for i in range(seeds.size()):
		for j in range(i + 1, seeds.size()):
			_tick_pair(seeds[i], seeds[j])
	_save_state()

## Tick a single pair's bond. Internal — use tick_squad for the post-run path.
func _tick_pair(seed_a: int, seed_b: int) -> void:
	var key: String = _pair_key(seed_a, seed_b)
	if not _bonds.has(key):
		_bonds[key] = { "runs_together": 0, "level": 0 }
	var entry: Dictionary = _bonds[key]
	entry.runs_together = int(entry.get("runs_together", 0)) + 1
	# Check if we hit a new level threshold.
	var current_level: int = int(entry.get("level", 0))
	var new_level: int = current_level
	for level in range(current_level + 1, MAX_BOND + 1):
		if int(entry.runs_together) >= int(RUNS_FOR_LEVEL[level]):
			new_level = level
	if new_level > current_level:
		entry.level = new_level
		bond_increased.emit(seed_a, seed_b, new_level)

# ============================================================================
# Grief on bonded death
# ============================================================================

## Apply grief to a survivor whose bonded packmate died. Duration is 3 days
## per bond level ≥ 2. No grief for bond < 2.
##
## [survivor] ActorData of the survivor.
## [dead] ActorData of the deceased.
func apply_grief(survivor: Object, dead: Object) -> void:
	if survivor == null or dead == null:
		return
	if not ("render_seed" in survivor and "render_seed" in dead):
		return
	var s_seed: int = int(survivor.get("render_seed"))
	var d_seed: int = int(dead.get("render_seed"))
	var bond: int = get_bond(s_seed, d_seed)
	if bond < 2:
		return  # Only meaningful bonds trigger grief.
	var days: int = 3 + (bond - 2)  # 3-6 days based on bond depth.
	if not _grief.has(s_seed):
		_grief[s_seed] = []
	(_grief[s_seed] as Array).append({ "dead_seed": d_seed, "expires_on_day": current_day + days })
	grief_applied.emit(s_seed, d_seed, days)
	_save_state()

## Returns true if a creature is currently grieving any lost packmate.
func is_grieving(creature: Object) -> bool:
	if creature == null or not "render_seed" in creature:
		return false
	var s_seed: int = int(creature.get("render_seed"))
	if not _grief.has(s_seed):
		return false
	for entry in (_grief[s_seed] as Array):
		if int((entry as Dictionary).get("expires_on_day", 0)) > current_day:
			return true
	return false

## Returns the grief multipliers to apply during stat calculation.
## { damage_dealt: float, damage_taken: float }
## When not grieving, returns { 1.0, 1.0 }.
func get_grief_modifiers(creature: Object) -> Dictionary:
	if not is_grieving(creature):
		return { "damage_dealt": 1.0, "damage_taken": 1.0 }
	return { "damage_dealt": 0.9, "damage_taken": 1.05 }

# ============================================================================
# Day tick (called by hub on contract accept)
# ============================================================================

## Advance the day counter. Expired grief entries are pruned.
func advance_day() -> void:
	current_day += 1
	for seed_key in _grief.keys():
		var arr: Array = _grief[seed_key]
		var kept: Array = []
		for entry in arr:
			if int((entry as Dictionary).get("expires_on_day", 0)) > current_day:
				kept.append(entry)
		_grief[seed_key] = kept
	_save_state()

# ============================================================================
# Persistence
# ============================================================================

func _save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("Bonds", "data", _bonds)
	cfg.set_value("Grief", "data", _grief)
	cfg.set_value("Day", "current", current_day)
	cfg.save(SAVE_PATH)

func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var b: Variant = cfg.get_value("Bonds", "data", {})
	if b is Dictionary:
		_bonds = b
	var g: Variant = cfg.get_value("Grief", "data", {})
	if g is Dictionary:
		_grief = g
	current_day = int(cfg.get_value("Day", "current", 0))

# ============================================================================
# Debug helpers
# ============================================================================

## For testing — clear all bond state. Use sparingly.
func reset_all() -> void:
	_bonds.clear()
	_grief.clear()
	current_day = 0
	_save_state()

## For debugging — dump all bond state to a readable string.
func dump_state() -> String:
	var lines: Array[String] = []
	lines.append("=== BondManager State ===")
	lines.append("current_day: %d" % current_day)
	lines.append("bonds (%d pairs):" % _bonds.size())
	for key in _bonds.keys():
		var entry: Dictionary = _bonds[key]
		lines.append("  %s — runs=%d, level=%d" % [key, entry.get("runs_together", 0), entry.get("level", 0)])
	lines.append("grief (%d creatures):" % _grief.size())
	for seed_key in _grief.keys():
		lines.append("  seed %s: %s" % [seed_key, str(_grief[seed_key])])
	return "\n".join(lines)
