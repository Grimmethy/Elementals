class_name MissionBoard
extends Node

## The hub's mission board. Holds a list of currently-available ContractData
## entries that refresh daily. When the player accepts a contract:
##   1. Day advances (BondManager.advance_day)
##   2. HerdManager.pending_run_mode is set true
##   3. The active contract is stored so the arena/run controller can read it
##   4. Scene changes to the arena
##
## This component is owned by HerdManager (or instanced separately as needed).
## The board itself is in-memory only — persistence happens on day advance and
## resets on a new day.

const CONTRACTS_PER_DAY: int = 4

## Currently-displayed contracts. Refreshed when refresh_board() is called.
var current_contracts: Array[ContractData] = []

## The contract the player just accepted (cleared once arena consumes it).
var accepted_contract: ContractData = null

## Last day the board was refreshed. Forces refresh if current_day advances.
var _last_refresh_day: int = -1

## Emitted when the board is refreshed (UI redraws).
signal board_refreshed(contracts: Array)
## Emitted when the player accepts a contract.
signal contract_accepted(contract: ContractData)

## Refresh the board with new contracts. Called on day-tick or at startup.
##
## [day_index] Current day. Used as RNG seed so the same day always shows the
##             same board (re-loading the game shouldn't reroll contracts).
## [count] How many contracts to roll. Defaults to CONTRACTS_PER_DAY.
func refresh_board(day_index: int, count: int = CONTRACTS_PER_DAY) -> void:
	current_contracts.clear()
	for i in range(count):
		# Seed each contract with day + slot index for stability.
		var contract_seed: int = day_index * 100 + i
		var contract := ContractData.make_sample(contract_seed)
		current_contracts.append(contract)
	_last_refresh_day = day_index
	board_refreshed.emit(current_contracts)

## Ensure the board is fresh for the current day. Idempotent — only refreshes
## if a new day has started since the last refresh.
func ensure_fresh(day_index: int) -> void:
	if _last_refresh_day != day_index:
		refresh_board(day_index)

## Player accepts a contract from the board. Sets up the run-mode flag on
## HerdManager so the next arena spawn knows to spin up the run controller.
##
## [contract] The contract picked. Must be in current_contracts.
## [Returns] true if the contract was accepted; false on validation failure.
func accept_contract(contract: ContractData) -> bool:
	if contract == null:
		return false
	if not contract in current_contracts:
		push_warning("MissionBoard: tried to accept a contract not on the current board.")
		return false
	accepted_contract = contract
	# Set the run-mode flag on HerdManager.
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm:
		if "pending_run_mode" in hm:
			hm.set("pending_run_mode", true)
		if "accepted_contract" in hm:
			hm.set("accepted_contract", contract)
	# Apply this contract's dungeon seed to GameSettings so the arena's
	# GridGenerator builds a fresh map specific to this contract. Without
	# this every run would re-use whatever seed was last saved.
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs and contract.dungeon_seed != 0:
		gs.set("noise_seed", contract.dungeon_seed)
	# Advance the day via BondManager (which prunes expired grief too).
	var bm: Node = get_node_or_null("/root/BondManager")
	if bm:
		bm.call("advance_day")
	contract_accepted.emit(contract)
	# Remove the accepted contract from the board.
	current_contracts.erase(contract)
	return true

## Clear all contracts (e.g. on new-game-plus or save reset).
func clear() -> void:
	current_contracts.clear()
	accepted_contract = null
	_last_refresh_day = -1
