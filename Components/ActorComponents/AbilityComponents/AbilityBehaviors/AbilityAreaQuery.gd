class_name AbilityAreaQuery
extends RefCounted

## Locates valid targets using hex tile distance via TileSignalComponent.
## Abstracts shape (radius, cone, line) and team filtering so individual
## abilities never iterate arena.actors with float-distance math directly.
##
## TileSignalComponent integration:
##   One-shot queries: reads active actors and computes axial hex distance.
##   Persistent triggers: calls register_trigger() with continuous:true,
##   updates center on actor tile_changed, removes trigger on cleanup.
##
## Reference implementation: DetectionComponent.gd follows the same pattern.
##
## Range string → tile conversion (1 tile = 5 ft.):
##   "5 ft." / "Touch" → 1 tile
##   "10 ft."          → 2 tiles
##   "X ft."           → X / 5 tiles
##   "Self"            → 0 (self-only, no query needed)

enum Shape {
	RADIUS,  ## Circular area centred on the actor.
	CONE,    ## 90° arc in a direction.
	LINE,    ## Narrow line in a direction.
	SINGLE,  ## Single target within reach.
	SELF,    ## Actor only — no external targets.
}

enum TeamFilter {
	ENEMIES,   ## Only targets that are not allies of the querying actor.
	ALLIES,    ## Only targets that are allies.
	ALL,       ## Every actor in range (excluding self).
	SELF_ONLY, ## The actor itself.
}

## Tile radius for RADIUS, CONE, LINE. 0 for SELF.
var tile_radius: int = 1

## Query shape.
var shape: Shape = Shape.SINGLE

## Team filtering.
var team: TeamFilter = TeamFilter.ENEMIES

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Build from the ability data "range" string and an explicit team filter.
##
## Supported formats:
##   "5 ft."           → SINGLE,  1 tile
##   "Touch"           → SINGLE,  1 tile
##   "10 ft."          → RADIUS,  2 tiles
##   "30 ft. cone"     → CONE,    6 tiles
##   "60 ft. line"     → LINE,   12 tiles
##   "Self"            → SELF,    0 tiles
##   "X ft."           → RADIUS,  X/5 tiles
##   "Varies per creature" → RADIUS, 6 tiles (default; override at call site)
static func from_range_string(range_str: String,
		team_filter: TeamFilter = TeamFilter.ENEMIES) -> AbilityAreaQuery:
	var a := AbilityAreaQuery.new()
	a.team = team_filter

	var s: String = range_str.strip_edges().to_lower()

	if s == "" or s == "self":
		a.shape       = Shape.SELF
		a.tile_radius = 0
		return a

	if s == "touch" or s == "5 ft." or s == "5ft":
		a.shape       = Shape.SINGLE
		a.tile_radius = 1
		return a

	# Check for shape suffix before parsing distance.
	var is_cone: bool = s.contains("cone")
	var is_line: bool = s.contains("line")

	# Extract numeric feet value — take the first integer token.
	var feet: int = 0
	for token in s.split(" ", false):
		var clean_token: String = token.replace("ft.", "").replace("ft", "").strip_edges()
		if clean_token.is_valid_int():
			feet = int(clean_token)
			break

	a.tile_radius = maxi(1, feet / 5) if feet > 0 else 6

	if is_cone:
		a.shape = Shape.CONE
	elif is_line:
		a.shape = Shape.LINE
	elif feet <= 5:
		a.shape = Shape.SINGLE
	else:
		a.shape = Shape.RADIUS

	return a

# ---------------------------------------------------------------------------
# One-shot query
# ---------------------------------------------------------------------------

## Return all valid targets right now, using TileSignalComponent for spatial
## data and axial hex distance for filtering.
##
## aim_tile is required for CONE and LINE shapes; it defines the direction.
## Pass null for RADIUS and SINGLE queries.
func get_targets_oneshot(
		actor: Actor,
		tile_signal: Node,
		aim_tile: Object = null
) -> Array[Actor]:
	var result: Array[Actor] = []

	if shape == Shape.SELF:
		result.append(actor)
		return result

	if not is_instance_valid(actor):
		return result

	# Collect all tracked actors from TileSignalComponent._actor_tiles.
	var actor_tiles: Dictionary = {}
	if tile_signal != null and tile_signal.has_method("get"):
		var at: Variant = tile_signal.get("_actor_tiles")
		if at is Dictionary:
			actor_tiles = at

	# Fallback: iterate arena actors if TileSignalComponent data unavailable.
	if actor_tiles.is_empty():
		var arena_val: Variant = actor.get("_arena_grid")
		if arena_val == null:
			return result
		for node in arena_val.actors:
			if is_instance_valid(node) and node is Actor:
				actor_tiles[node] = node.global_position

	var source_tile: Object = _get_actor_tile(actor)

	for candidate_node in actor_tiles.keys():
		if not is_instance_valid(candidate_node) or not (candidate_node is Actor):
			continue
		var candidate: Actor = candidate_node as Actor
		if candidate == actor or candidate.is_dead:
			continue
		if not _passes_team_filter(actor, candidate):
			continue

		var candidate_tile: Object = _get_actor_tile(candidate)
		if not _in_shape(source_tile, candidate_tile, aim_tile):
			continue

		result.append(candidate)

	return result

# ---------------------------------------------------------------------------
# Persistent trigger
# ---------------------------------------------------------------------------

## Register a proximity trigger that fires as actors enter the area.
## Use for auras, stench, fear, persistent hazards, etc.
## Returns the trigger handle (Dictionary); store it for update_center / release.
func register_persistent(
		actor: Actor,
		tile_signal: Node,
		on_enter: Callable,
		on_exit: Callable = Callable()
) -> Dictionary:
	if tile_signal == null or not tile_signal.has_method("register_trigger"):
		return {}

	var source_tile: Object = _get_actor_tile(actor)
	if source_tile == null:
		return {}

	var metadata: Dictionary = {
		"continuous": true,
		"on_exit_callback": on_exit,
	}

	var trigger: Dictionary = tile_signal.call(
		"register_trigger",
		source_tile,
		tile_radius,
		on_enter,
		metadata
	)
	return trigger

## Update the persistent trigger's center when the source actor moves.
## Call from actor.tile_changed signal handler.
func update_center(tile_signal: Node, trigger: Dictionary, new_tile: Object) -> void:
	if tile_signal == null or trigger.is_empty():
		return
	if tile_signal.has_method("update_trigger_center"):
		tile_signal.call("update_trigger_center", trigger, new_tile)

## Unregister the persistent trigger. Call on actor death or ability deactivated.
func release_persistent(tile_signal: Node, trigger: Dictionary) -> void:
	if tile_signal == null or trigger.is_empty():
		return
	if tile_signal.has_method("remove_trigger"):
		tile_signal.call("remove_trigger", trigger)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Get the tile Object an actor is currently standing on.
func _get_actor_tile(a: Actor) -> Object:
	if not is_instance_valid(a):
		return null
	var tile_interaction: Variant = a.get("tile_interaction_component")
	if tile_interaction and tile_interaction.has_method("get_ground_tile"):
		return tile_interaction.call("get_ground_tile")
	return null

## True if candidate_tile falls within the query shape centred at source_tile.
func _in_shape(source_tile: Object, candidate_tile: Object, aim_tile: Object) -> bool:
	if source_tile == null or candidate_tile == null:
		return false

	var dist: int = _hex_distance(source_tile, candidate_tile)

	match shape:
		Shape.SINGLE, Shape.RADIUS:
			return dist <= tile_radius

		Shape.CONE:
			if dist > tile_radius:
				return false
			if aim_tile == null:
				return dist <= tile_radius  # fallback: treat as radius
			# Cone: candidate must be within tile_radius AND within a 90° arc
			# pointing from source toward aim_tile.
			return _in_cone(source_tile, candidate_tile, aim_tile)

		Shape.LINE:
			if dist > tile_radius:
				return false
			if aim_tile == null:
				return dist <= tile_radius
			return _in_line(source_tile, candidate_tile, aim_tile)

		_:
			return false

## Axial hex distance formula: (|da.x| + |da.x+da.y| + |da.y|) / 2
func _hex_distance(a: Object, b: Object) -> int:
	if a == null or b == null:
		return 999
	# Attempt to read axial coordinates from HexTile / tile objects.
	var ax: int = int(a.get("q") if "q" in a else a.get("x") if "x" in a else 0)
	var ay: int = int(a.get("r") if "r" in a else a.get("y") if "y" in a else 0)
	var bx: int = int(b.get("q") if "q" in b else b.get("x") if "x" in b else 0)
	var by_: int = int(b.get("r") if "r" in b else b.get("y") if "y" in b else 0)
	var dx: int = bx - ax
	var dy: int = by_ - ay
	return int((abs(dx) + abs(dx + dy) + abs(dy)) / 2)

## True if candidate_tile is within a 90° cone from source toward aim_tile.
func _in_cone(source_tile: Object, candidate_tile: Object, aim_tile: Object) -> bool:
	# Use world positions as fallback when tile coordinates are ambiguous.
	# A "cone" here is defined as: the angle between (aim - source) and
	# (candidate - source) is ≤ 45° (half of 90°).
	var s_pos: Variant = source_tile.get("world_position") if "world_position" in source_tile else null
	var a_pos: Variant = aim_tile.get("world_position") if "world_position" in aim_tile else null
	var c_pos: Variant = candidate_tile.get("world_position") if "world_position" in candidate_tile else null

	if s_pos == null or a_pos == null or c_pos == null:
		return true  # Can't check — include by default.

	var dir_aim: Vector2 = Vector2(float(a_pos.x) - float(s_pos.x),
	                               float(a_pos.z) - float(s_pos.z)).normalized()
	var dir_cand: Vector2 = Vector2(float(c_pos.x) - float(s_pos.x),
	                                float(c_pos.z) - float(s_pos.z)).normalized()

	var dot: float = dir_aim.dot(dir_cand)
	return dot >= 0.707  # cos(45°) ≈ 0.707

## True if candidate_tile lies along the line from source toward aim_tile.
func _in_line(source_tile: Object, candidate_tile: Object, aim_tile: Object) -> bool:
	var s_pos: Variant = source_tile.get("world_position") if "world_position" in source_tile else null
	var a_pos: Variant = aim_tile.get("world_position") if "world_position" in aim_tile else null
	var c_pos: Variant = candidate_tile.get("world_position") if "world_position" in candidate_tile else null

	if s_pos == null or a_pos == null or c_pos == null:
		return true

	var dir_aim: Vector2 = Vector2(float(a_pos.x) - float(s_pos.x),
	                               float(a_pos.z) - float(s_pos.z)).normalized()
	var dir_cand: Vector2 = Vector2(float(c_pos.x) - float(s_pos.x),
	                                float(c_pos.z) - float(s_pos.z)).normalized()

	# Line = ≤ 15° deviation from the aim direction on both sides.
	var dot: float = dir_aim.dot(dir_cand)
	return dot >= 0.966  # cos(15°) ≈ 0.966

## True if the candidate passes the team filter relative to the querying actor.
func _passes_team_filter(querier: Actor, candidate: Actor) -> bool:
	match team:
		TeamFilter.ALL:
			return true
		TeamFilter.SELF_ONLY:
			return candidate == querier
		TeamFilter.ENEMIES:
			if querier.has_method("is_ally"):
				return not querier.is_ally(candidate)
			return true
		TeamFilter.ALLIES:
			if querier.has_method("is_ally"):
				return querier.is_ally(candidate)
			return false
	return true
