class_name DungeonRunController
extends Node

## Manages the 4-room run state machine that defines a single Hornbound dungeon
## expedition. A run is bounded (15-25 min target), permadeath, and ends in
## one of three ways at the extract point: leave, push for boss, or abandon.
##
## State machine:
##   WARMUP   → BRANCH   → MIDBOSS   → EXTRACT  ─┬→ LEAVE → DONE_SUCCESS
##                                                ├→ PUSH  → BOSS → DONE_SUCCESS
##                                                └→ ABANDON → DONE_ABANDON
##
##   At any state, if the player pack is wiped: → DONE_FAILURE
##
## Sees minimal of the arena — works through high-level signals and a list of
## room templates. Each room template handles its own spawn / cleanup. This
## controller's job is sequencing + extract logic, nothing else.

enum RunState {
	NOT_STARTED,
	WARMUP,
	BRANCH,
	MIDBOSS,
	EXTRACT,
	PUSH_BOSS,
	DONE_SUCCESS,
	DONE_ABANDON,
	DONE_FAILURE,
}

## Branch choice at room 2. Set externally by ExtractScreen or BranchRoom.
enum BranchChoice {
	NONE,    # not yet chosen
	LOOT,    # safer route, treasure
	ALPHA,   # harder route, capturable rare
}

# ============================================================================
# Signals
# ============================================================================

## Emitted when a room is entered. UI updates can subscribe.
signal room_entered(state: RunState)
## Emitted when a room is completed (cleared / extracted).
signal room_completed(state: RunState)
## Emitted when the player pack is wiped — run ends in failure.
signal run_failed()
## Emitted when the run ends successfully (leave or boss kill).
signal run_succeeded(rewards: Dictionary)
## Emitted at the EXTRACT state — UI should show the leave/push/abandon screen.
signal extract_point_reached()

# ============================================================================
# Public state
# ============================================================================

var current_state: RunState = RunState.NOT_STARTED
var current_room_index: int = 0
var branch_choice: BranchChoice = BranchChoice.NONE

## Player's squad for this run. Set before start_run() — used to detect wipe.
var player_squad: Array = []

## Per-run reward accumulator (gold, parts, captured monsters, traits learned).
var pending_rewards: Dictionary = {
	"gold": 0,
	"parts": [],
	"captured": [],
	"traits_learned": [],
	"loot_items": [],
}

## Reference to the arena this run is happening in. Optional — used to query
## the player pack and listen to wipe signals.
var arena: Node = null

# ============================================================================
# Run lifecycle
# ============================================================================

## Begin a new run. Resets state, primes the warmup room.
##
## [p_arena] The arena to run inside. May be null in headless tests.
## [p_squad] Array of ActorData (the player's selected squad).
func start_run(p_arena: Node, p_squad: Array) -> void:
	arena = p_arena
	player_squad = p_squad
	current_state = RunState.NOT_STARTED
	current_room_index = 0
	branch_choice = BranchChoice.NONE
	pending_rewards = {
		"gold": 0,
		"parts": [],
		"captured": [],
		"traits_learned": [],
		"loot_items": [],
	}
	# Listen for pack wipe.
	if arena and arena.has_signal("player_pack_wiped"):
		if not arena.is_connected("player_pack_wiped", _on_pack_wiped):
			arena.connect("player_pack_wiped", _on_pack_wiped)
	_transition(RunState.WARMUP)

## Called by the active room template when it's been cleared / completed.
## Drives the state machine forward.
func complete_current_room() -> void:
	room_completed.emit(current_state)
	match current_state:
		RunState.WARMUP:
			_transition(RunState.BRANCH)
		RunState.BRANCH:
			_transition(RunState.MIDBOSS)
		RunState.MIDBOSS:
			_transition(RunState.EXTRACT)
		RunState.PUSH_BOSS:
			_finish(true, "Boss vanquished.")
		_:
			pass  # No-op for terminal states

## Called by the ExtractScreen UI when the player chooses an option.
func choose_extract_option(option: String) -> void:
	if current_state != RunState.EXTRACT:
		return
	match option:
		"leave":
			_finish(true, "Extracted safely.")
		"push":
			_transition(RunState.PUSH_BOSS)
		"abandon":
			pending_rewards = {
				"gold": 0,
				"parts": [],
				"captured": [],
				"traits_learned": [],
				"loot_items": [],
			}
			current_state = RunState.DONE_ABANDON
			run_succeeded.emit(pending_rewards)

## Called by the BranchRoom UI when the player picks a door.
func choose_branch(choice: BranchChoice) -> void:
	if current_state != RunState.BRANCH:
		return
	branch_choice = choice

# ============================================================================
# Internal state transitions
# ============================================================================

func _transition(next: RunState) -> void:
	current_state = next
	current_room_index += 1
	room_entered.emit(next)
	if next == RunState.EXTRACT:
		extract_point_reached.emit()

func _finish(success: bool, message: String) -> void:
	if success:
		current_state = RunState.DONE_SUCCESS
		# Tick bond manager — survivors got closer.
		if has_node("/root/BondManager") and not player_squad.is_empty():
			get_node("/root/BondManager").call("tick_squad", player_squad)
		# Day advances on completed run.
		if has_node("/root/BondManager"):
			get_node("/root/BondManager").call("advance_day")
		run_succeeded.emit(pending_rewards)
	else:
		current_state = RunState.DONE_FAILURE
		run_failed.emit()
	print("[Run] complete — %s" % message)

func _on_pack_wiped() -> void:
	if current_state in [RunState.DONE_SUCCESS, RunState.DONE_ABANDON, RunState.DONE_FAILURE]:
		return
	_finish(false, "Pack wiped.")

# ============================================================================
# Reward accumulation (called by rooms)
# ============================================================================

func add_gold(amount: int) -> void:
	pending_rewards.gold = int(pending_rewards.get("gold", 0)) + amount

func add_part(part_id: String) -> void:
	(pending_rewards.parts as Array).append(part_id)

func add_captured(data) -> void:
	(pending_rewards.captured as Array).append(data)

func add_trait_learned(trait_name: String) -> void:
	(pending_rewards.traits_learned as Array).append(trait_name)

func add_loot_item(item_id: String) -> void:
	(pending_rewards.loot_items as Array).append(item_id)
