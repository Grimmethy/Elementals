extends Node

## Smoke tests for the Hornbound systems. Not a unit-test framework — just
## a script that exercises the new pieces and prints PASS/FAIL.
##
## To run: attach this to a Node3D in a test scene and play.
## Each test is independent; failures don't halt the rest.
##
## NOTE: Requires the autoloads (BondManager, TraitLibrary, LeaderboardManager)
## to be registered. If they're missing, tests print SKIP.

var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0

func _ready() -> void:
	print("=== Hornbound Smoke Tests ===")
	call_deferred("_run_all")

func _run_all() -> void:
	_test_actor_body_plan_generator()
	_test_universal_crossover_breed_moveset()
	_test_bond_manager_tick()
	_test_bond_manager_grief()
	_test_trait_library_capture()
	_test_leaderboard_submit()
	_test_dungeon_run_state_machine()
	_test_capture_archetype_resolution()
	_test_active_pension_split()
	_test_contract_summary()
	_print_summary()

# ============================================================================
# Tests
# ============================================================================

func _test_actor_body_plan_generator() -> void:
	var plan: Dictionary = ActorBodyPlanGenerator.generate("Wolf", 1234)
	if not plan.has("base") or not plan.has("palette"):
		return _fail("ActorBodyPlanGenerator.generate(Wolf) missing base/palette slots")
	if String(plan.base.get("type", "")) != "quadruped_torso":
		return _fail("Wolf body type should be quadruped_torso, got: %s" % plan.base.get("type"))
	# Determinism check — same seed, same plan.
	var plan2: Dictionary = ActorBodyPlanGenerator.generate("Wolf", 1234)
	if not str(plan) == str(plan2):
		return _fail("ActorBodyPlanGenerator non-deterministic for same seed")
	_pass("ActorBodyPlanGenerator: Wolf generates a quadruped, deterministic")

func _test_universal_crossover_breed_moveset() -> void:
	# Construct two parents (use a simple ActorData subclass; here we cheat with
	# stubs since real subclasses need their full genome setup).
	# For smoke test, just verify MUTATION_MOVES is non-empty.
	if ActorData.MUTATION_MOVES.is_empty():
		return _fail("MUTATION_MOVES is empty")
	if ActorData.MUTATION_MOVES.size() < 8:
		return _fail("MUTATION_MOVES has fewer than 8 entries (%d)" % ActorData.MUTATION_MOVES.size())
	if ActorData.GRAFT_MOVES.is_empty():
		return _fail("GRAFT_MOVES is empty")
	_pass("Moveset inheritance constants populated (%d mutation moves, %d graft mappings)" % [ActorData.MUTATION_MOVES.size(), ActorData.GRAFT_MOVES.size()])

func _test_bond_manager_tick() -> void:
	var bm: Node = get_node_or_null("/root/BondManager")
	if bm == null:
		return _skip("BondManager autoload not present")
	bm.call("reset_all")
	# Build fake actors using GoatData (a real subclass).
	var a := GoatData.new()
	a.render_seed = 100
	var b := GoatData.new()
	b.render_seed = 200
	bm.call("tick_squad", [a, b])
	var bond: int = int(bm.call("get_bond", 100, 200))
	if bond != 1:
		return _fail("Expected bond level 1 after 1 run, got %d" % bond)
	# Tick to level 2 (needs 3 runs total).
	bm.call("tick_squad", [a, b])
	bm.call("tick_squad", [a, b])
	bond = int(bm.call("get_bond", 100, 200))
	if bond != 2:
		return _fail("Expected bond level 2 after 3 runs, got %d" % bond)
	_pass("BondManager.tick_squad correctly levels bonds")

func _test_bond_manager_grief() -> void:
	var bm: Node = get_node_or_null("/root/BondManager")
	if bm == null:
		return _skip("BondManager autoload not present")
	# Bond from previous test should still be there (level 2).
	var a := GoatData.new()
	a.render_seed = 100
	var b := GoatData.new()
	b.render_seed = 200
	bm.call("apply_grief", a, b)
	var grieving: bool = bool(bm.call("is_grieving", a))
	if not grieving:
		return _fail("Expected survivor to be grieving after bonded death")
	var mods: Dictionary = bm.call("get_grief_modifiers", a)
	if float(mods.get("damage_dealt", 1.0)) >= 1.0:
		return _fail("Grief should reduce damage_dealt below 1.0")
	_pass("BondManager grief activates and applies modifiers")

func _test_trait_library_capture() -> void:
	var lib: Node = get_node_or_null("/root/TraitLibrary")
	if lib == null:
		return _skip("TraitLibrary autoload not present")
	lib.call("reset")
	var new_traits: Array = lib.call("add_capture", "Wolf")
	if new_traits.is_empty():
		return _fail("Capturing Wolf should add at least one trait to empty library")
	# Second capture of same species should add NO new traits (all already known).
	var second: Array = lib.call("add_capture", "Wolf")
	if not second.is_empty():
		return _fail("Second Wolf capture should add 0 new traits, got %d" % second.size())
	# But should still count as a capture.
	if not bool(lib.call("has_captured", "Wolf")):
		return _fail("has_captured(Wolf) should be true after capture")
	_pass("TraitLibrary captures and deduplicates traits")

func _test_leaderboard_submit() -> void:
	var lb: Node = get_node_or_null("/root/LeaderboardManager")
	if lb == null:
		return _skip("LeaderboardManager autoload not present")
	lb.call("reset_all")
	var rank: int = int(lb.call("submit_score", "deepest_dive", 5.0, "Test run"))
	if rank != 1:
		return _fail("First submission to empty board should rank #1, got %d" % rank)
	# Higher score should rank above lower.
	lb.call("submit_score", "deepest_dive", 8.0, "Better run")
	var arr: Array = lb.call("get_board", "deepest_dive")
	if arr.size() != 2:
		return _fail("Board should have 2 entries, got %d" % arr.size())
	if float((arr[0] as Dictionary).get("score", 0.0)) != 8.0:
		return _fail("Higher score (8.0) should be ranked #1, but #1 is %s" % str(arr[0]))
	_pass("LeaderboardManager submit + sort correct")

func _test_dungeon_run_state_machine() -> void:
	var ctrl := DungeonRunController.new()
	add_child(ctrl)
	# Start a run with an empty squad (just to test the state machine).
	ctrl.start_run(null, [])
	if ctrl.current_state != DungeonRunController.RunState.WARMUP:
		ctrl.queue_free()
		return _fail("Run should start in WARMUP, got %s" % ctrl.current_state)
	ctrl.complete_current_room()
	if ctrl.current_state != DungeonRunController.RunState.BRANCH:
		ctrl.queue_free()
		return _fail("After WARMUP, should be BRANCH, got %s" % ctrl.current_state)
	ctrl.complete_current_room()
	if ctrl.current_state != DungeonRunController.RunState.MIDBOSS:
		ctrl.queue_free()
		return _fail("After BRANCH, should be MIDBOSS, got %s" % ctrl.current_state)
	ctrl.complete_current_room()
	if ctrl.current_state != DungeonRunController.RunState.EXTRACT:
		ctrl.queue_free()
		return _fail("After MIDBOSS, should be EXTRACT, got %s" % ctrl.current_state)
	ctrl.queue_free()
	_pass("DungeonRunController state machine progresses correctly")

func _test_capture_archetype_resolution() -> void:
	# Check that ActorTypeData returns archetypes for known species.
	var wolf_arch: String = ActorTypeData.get_capture_archetype("Wolf")
	if wolf_arch.is_empty():
		return _fail("Wolf should have a capture_archetype set")
	var iron_arch: String = ActorTypeData.get_capture_archetype("Iron Golem")
	if iron_arch != "break_armor":
		return _fail("Iron Golem should require break_armor, got %s" % iron_arch)
	_pass("ActorTypeData capture archetype resolution works (Wolf=%s, Iron Golem=%s)" % [wolf_arch, iron_arch])

func _test_active_pension_split() -> void:
	var hm: Node = get_node_or_null("/root/HerdManager")
	if hm == null:
		return _skip("HerdManager autoload not present")
	# Just verify the API exists and returns Arrays.
	var active: Variant = hm.call("get_active_herd")
	var pension: Variant = hm.call("get_pension")
	if not (active is Array) or not (pension is Array):
		return _fail("get_active_herd / get_pension should return Arrays")
	_pass("HerdManager active/pension split API present")

func _test_contract_summary() -> void:
	var c: ContractData = ContractData.make_sample(42)
	if c.contract_id.is_empty():
		return _fail("Sample contract should have a non-empty id")
	var s: String = c.summary()
	if s.is_empty() or not s.contains("Reward"):
		return _fail("Contract summary should mention Reward")
	_pass("ContractData sample factory works, summary='%s'" % s)

# ============================================================================
# Helpers
# ============================================================================

func _pass(msg: String) -> void:
	_passed += 1
	print("  ✓ PASS: %s" % msg)

func _fail(msg: String) -> void:
	_failed += 1
	push_error("  ✗ FAIL: %s" % msg)
	print("  ✗ FAIL: %s" % msg)

func _skip(msg: String) -> void:
	_skipped += 1
	print("  ⊘ SKIP: %s" % msg)

func _print_summary() -> void:
	print("\n=== Results: %d passed, %d failed, %d skipped ===" % [_passed, _failed, _skipped])
