class_name ActorData
extends Resource

## Base resource for actor data, holding standard ability scores and common attributes.
## Used to drive actor stats and visual variations.

signal stats_changed

@export_group("Ability Scores")
@export var strength: float = 1.0:
	set(v):
		if strength == v: return
		strength = v
		stats_changed.emit()

@export var dexterity: float = 1.0:
	set(v):
		if dexterity == v: return
		dexterity = v
		stats_changed.emit()

@export var constitution: float = 1.0:
	set(v):
		if constitution == v: return
		constitution = v
		stats_changed.emit()

@export var intelligence: float = 1.0:
	set(v):
		if intelligence == v: return
		intelligence = v
		stats_changed.emit()

@export var wisdom: float = 1.0:
	set(v):
		if wisdom == v: return
		wisdom = v
		stats_changed.emit()

@export var charisma: float = 1.0:
	set(v):
		if charisma == v: return
		charisma = v
		stats_changed.emit()

@export_group("Breeding")
enum Gender { MALE, FEMALE }
@export var gender: Gender = Gender.FEMALE:
	set(v):
		if gender == v: return
		gender = v
		stats_changed.emit()
@export var is_pregnant: bool = false:
	set(v):
		if is_pregnant == v: return
		is_pregnant = v
		stats_changed.emit()
@export var pregnancy_timer: int = 0:
	set(v):
		if pregnancy_timer == v: return
		pregnancy_timer = v
		stats_changed.emit()
@export var pregnancy_father: ActorData = null:
	set(v):
		if pregnancy_father == v: return
		pregnancy_father = v
		stats_changed.emit()
@export var is_exhausted: bool = false:
	set(v):
		if is_exhausted == v: return
		is_exhausted = v
		stats_changed.emit()
## Selection flag for "send into arena next match." Lives on the base class
## because HerdComponent and ProgressionComponent already poll it polymorphi-
## cally (`actor.is_selected`), and the cheat menu can now spawn non-Goat
## creatures (Mimic / Mushroom / Goblin) that need to participate in the same
## selection flow.
@export var is_selected: bool = false:
	set(v):
		if is_selected == v: return
		is_selected = v
		stats_changed.emit()

@export_group("Lifecycle")
## Days survived since spawn. Incremented by ProgressionComponent every
## next_day() tick. All herd members age uniformly.
@export var age_days: int = 0:
	set(v):
		if age_days == v: return
		age_days = v
		stats_changed.emit()
## Maximum stamina pool. Used for arena fatigue / breeding cooldown.
@export var stamina_max: float = 100.0:
	set(v):
		if stamina_max == v: return
		stamina_max = v
		stats_changed.emit()
## Current stamina. Restored to stamina_max each day when the actor isn't
## selected for combat; emptied + flagged is_exhausted when they ARE selected.
@export var stamina_current: float = 100.0:
	set(v):
		if stamina_current == v: return
		stamina_current = v
		stats_changed.emit()

@export_group("Visual")
@export var base_color: Color = Color.WHITE:
	set(v):
		if base_color == v: return
		base_color = v
		stats_changed.emit()
@export var pattern_color: Color = Color.GRAY:
	set(v):
		if pattern_color == v: return
		pattern_color = v
		stats_changed.emit()

@export_group("Identity")
## Stable per-creature seed used to deterministically render the procedural
## body. Without this, ProceduralMimicChest / ProceduralMushroomBody call
## randi/randf during rendering (tooth jitter, spot placement, lower-tooth-
## count variation, eye phi variation, etc.) so the SAME genome produces a
## different visual every rebuild. With the seed, rendering is a pure
## function of (genome + seed) — the kid looks identical every time.
##
## Initialized to a fresh random value when the actor is constructed via
## _init, then inherited / re-rolled during breeding so each kid has its
## own stable identity.
@export var render_seed: int = 0:
	set(v):
		if render_seed == v: return
		render_seed = v
		stats_changed.emit()

@export_group("Lineage")
## Hybrid generation counter. 0 = pure-species spawn (cheat or wild). 1 = first
## cross-species kid. Increments by 1 each time a cross-species breed
## happens; same-species breeds inherit the higher parent's generation.
##
## Higher generations:
##   - Roll MORE entries from the shared MUTATION_POOL (1 + gen/2, capped)
##   - Get a "chimeric" / "twisted" name prefix at gen >= 2
##   - Bigger graft probability boost so accumulated weirdness compounds
@export var hybrid_generation: int = 0:
	set(v):
		if hybrid_generation == v: return
		hybrid_generation = v
		stats_changed.emit()

## Fraction of mimic ancestry in this actor's bloodline (0.0 = none, 1.0 = pure mimic).
## Drives the probability that offspring inherit mimic skills:
##   pure × pure       -> 100%
##   pure × non-pure   -> 30%   (with mimic blood propagated)
##   hybrid × any      -> 60%   (if at least one parent has mimic_blood > 0)
@export var mimic_blood: float = 0.0:
	set(v):
		var clamped: float = clampf(v, 0.0, 1.0)
		if is_equal_approx(mimic_blood, clamped):
			return
		mimic_blood = clamped
		stats_changed.emit()

## Runtime-only flag (NOT serialized as @export_group state across saves intentionally —
## the actor that builds from this data reads it once at spawn to decide whether to
## graft Mimic shapechange/skill-copy abilities onto a non-Mimic body). Set during
## create_offspring() by the hybrid-breeding probability roll.
var inherit_mimic_skills: bool = false

## Override in subclasses to create offspring with proper genetic mixing
func create_offspring(_partner: ActorData) -> ActorData:
	push_error("ActorData.create_offspring() must be overridden by subclass")
	return null

## Returns the type identifier for this actor (e.g., "GoatData", "GoblinData")
func get_actor_type() -> String:
	var script = get_script()
	if script:
		return script.get_global_name()
	return "ActorData"

## Applies spawn-time ability score defaults from ActorTypeData for the given
## type name. Call once from _init() — after this the per-actor stats are live
## and owned by this instance; ActorTypeData is never consulted again.
func _apply_type_defaults(type_name: String) -> void:
	var d := ActorTypeData.get_defaults(type_name)
	if d.is_empty():
		return
	strength     = d.get("strength",     strength)
	dexterity    = d.get("dexterity",    dexterity)
	constitution = d.get("constitution", constitution)
	intelligence = d.get("intelligence", intelligence)
	wisdom       = d.get("wisdom",       wisdom)
	charisma     = d.get("charisma",     charisma)

# === Shared body plan (Tier-1 scaffold, future modular composition) =========
#
# Universal cross-species body schema. Currently NOT consumed by any
# procedural body — Mimic and Mushroom still read their own species-specific
# genome slots. This dict is the SEAM for the next architectural step:
# eventually a unified ProceduralCreatureBody will read shared_body_plan and
# compose parts from the renderer registry below.
#
# How future migration works:
#   1. Populate shared_body_plan during universal_crossover_breed, with each
#      slot independently rolled from either parent.
#   2. New species' procedural bodies prefer shared_body_plan over their own
#      species-specific genome — read base.type, top.type, face.eye_count,
#      ornaments, etc. from this dict.
#   3. Existing Mimic/Mushroom bodies stay backward compatible — they keep
#      reading their old genome slots until they're refactored.
#
# Renderer registry: each "type" string maps to a builder function. New
# species register their builder via a const dict + a small wrapper.
#
# Adding a species today doesn't require touching this — but populating
# this dict during their breeding gives future-migrated species access.
@export var shared_body_plan: Dictionary = default_shared_body_plan():
	set(v):
		shared_body_plan = v
		stats_changed.emit()

static func default_shared_body_plan() -> Dictionary:
	return {
		"base": {
			# Renderer key — "box", "stem", "vase", "barrel", etc. The future
			# unified renderer matches this against a global registry of
			# part-builders. Different species register different keys.
			"type": "",
			"width": 0.5,
			"height": 0.5,
			"depth": 0.5
		},
		"top": {
			# "lid_flat" / "lid_rounded" / "cap_dome" / "cap_flat" /
			# "none" — when none, body has no separate upper part.
			"type": "none",
			"size_factor": 1.0,
			"height": 0.3
		},
		"face": {
			# Universal face fields — every creature has eyes/mouth.
			"eye_count": 2,
			"eye_radius": 0.04,
			"eye_color": Color(0.9, 0.2, 0.1),
			"eye_glow": false,
			"eye_placement": "base",  # or "top" / "head"
			"mouth_style": "teeth_ring",  # "single" / "none" / "teeth_ring"
			"tongue_present": false
		},
		"limbs": {
			"has_arms": false,
			"arm_count": 2,
			"arm_length": 0.22,
			"has_legs": false,
			"leg_count": 2,
			"leg_length": 0.18
		},
		"ornaments": {
			# Stack of decoration tags. Renderers may consume any they
			# recognize: "metal_band", "polka_dots", "gems", "lock",
			# "handle", "stripes", "carved_lines", etc.
			"tags": [],
			"primary_color": Color(0.6, 0.5, 0.3),
			"secondary_color": Color(0.9, 0.9, 0.8)
		},
		"palette": {
			# Universal color slots that any renderer reads.
			"primary": Color(0.5, 0.5, 0.5),
			"secondary": Color(0.7, 0.7, 0.7),
			"accent": Color(0.9, 0.6, 0.2),
			"eye": Color(0.9, 0.2, 0.1),
			"detail": Color(0.1, 0.05, 0.05)
		}
	}

## === Moveset inheritance (Hornbound) =======================================
##
## The kid's combat verbs. Stored as `moveset: Array[String]` on the genome's
## "moves" slot. Same-species kids get 2 moves (one from each parent). Hybrid
## (cross-species) kids get 3, with slot 3 rolled on a special table that
## includes graft-keyed moves, library-sampled moves, and rare new mutation
## moves.
##
## See GameLoopIdea.md §5 for the design rationale.
@export var moveset: Array[String] = []:
	set(v):
		moveset = v
		stats_changed.emit()

## Mutation move pool. Authored content — these are the "remember that goat?"
## moments. Rolled at 3% on hybrid kids' slot-3.
const MUTATION_MOVES: Array[String] = [
	"Pulse Burst",
	"Shadow Step",
	"Earthquake Stomp",
	"Soul Drain",
	"Mirror Self",
	"Time Slip",
	"Berserker Rage",
	"Crystallize",
	"Static Field",
	"Phase Shift",
	"Voidlash",
	"Echo Strike",
]

## Map of graft body parts to the move they grant when present. Looked up by
## checking the kid's genome["grafted"] slot for has_* flags.
const GRAFT_MOVES: Dictionary = {
	"has_cap_graft":          "Spore Cloud",
	"has_mushroom_cap":       "Spore Cloud",
	"has_tooth_graft":        "Vicious Bite",
	"has_band_graft":         "Iron Wrap",
	"has_extra_eyes_on_cap":  "Piercing Gaze",
	"has_lid_crown":          "Mimic Snap",
	"has_gem_scatter":        "Crystal Volley",
	"has_stem_antenna":       "Static Field",
	"has_spots_on_body":      "Toxic Drip",
}

## Determine a kid's moveset given its parents. Called from
## universal_crossover_breed for hybrids, and from same-species create_offspring
## overrides for pure-breeds.
##
## [parent_a / parent_b] The two parents.
## [is_hybrid] If true, kid is cross-species — gets 3 moves with mutation
##             chance on slot 3. If false, kid gets 2 reliable moves.
## [Returns] Array of up to 3 move name strings.
static func roll_moveset(parent_a: ActorData, parent_b: ActorData, is_hybrid: bool, kid: ActorData) -> Array[String]:
	var moves: Array[String] = []
	# Slot 1: from parent A.
	var pool_a: Array[String] = _move_pool_for(parent_a)
	if not pool_a.is_empty():
		moves.append(pool_a[randi() % pool_a.size()])
	# Slot 2: from parent B.
	var pool_b: Array[String] = _move_pool_for(parent_b)
	if not pool_b.is_empty():
		var attempts: int = 0
		var pick: String = ""
		while attempts < 8:
			pick = pool_b[randi() % pool_b.size()]
			if not pick in moves or attempts > 4:
				break
			attempts += 1
		if not pick.is_empty():
			moves.append(pick)
	# Slot 3: hybrid only — roll the 60 / 25 / 12 / 3 table.
	if is_hybrid:
		var slot3: String = _roll_slot3_move(parent_a, parent_b, kid)
		if not slot3.is_empty() and not slot3 in moves:
			moves.append(slot3)
	return moves

## Read a parent's move pool from ActorTypeData. Falls back to the parent's
## ActorData abilities array if it has one.
static func _move_pool_for(parent: ActorData) -> Array[String]:
	if parent == null:
		return []
	var species: String = parent.get_actor_type().trim_suffix("Data")
	var defaults: Dictionary = ActorTypeData.get_defaults(species)
	var moves: Variant = defaults.get("abilities", defaults.get("weapons", []))
	if moves is Array:
		var result: Array[String] = []
		for m in moves:
			result.append(String(m))
		return result
	return []

## Roll the slot-3 move for a hybrid kid:
##   60% — another move from either parent's pool
##   25% — a graft move keyed off the kid's grafted body parts
##   12% — a library move (any species the player has captured)
##    3% — a mutation move from MUTATION_MOVES
static func _roll_slot3_move(parent_a: ActorData, parent_b: ActorData, kid: ActorData) -> String:
	var roll: float = randf()
	# 3% mutation
	if roll < 0.03:
		return MUTATION_MOVES[randi() % MUTATION_MOVES.size()]
	# 12% library — query the TraitLibrary autoload via the SceneTree (cast
	# because Engine.get_main_loop() returns MainLoop, not SceneTree).
	if roll < 0.15:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			var lib := tree.root.get_node_or_null("/root/TraitLibrary")
			if lib:
				var trait_name: String = String(lib.call("get_random_known_trait"))
				if not trait_name.is_empty():
					return trait_name
		# Fallthrough to graft if library was empty or unavailable.
	# 25% graft
	if roll < 0.40:
		var graft_move: String = _graft_move_for_kid(kid)
		if not graft_move.is_empty():
			return graft_move
		# Fallthrough to parent pool if no graft applies.
	# 60% parent pool (or any of the above fallthrough)
	var pool: Array[String] = _move_pool_for(parent_a) + _move_pool_for(parent_b)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

## Inspect the kid's genome["grafted"] slot for has_* flags and return the
## first matching move from GRAFT_MOVES. Returns "" if no grafts present.
static func _graft_move_for_kid(kid: ActorData) -> String:
	if kid == null or not "genome" in kid:
		return ""
	var g_var: Variant = kid.get("genome")
	if not (g_var is Dictionary):
		return ""
	var g: Dictionary = g_var
	if not g.has("grafted"):
		return ""
	var grafted: Dictionary = g["grafted"]
	# Collect all matching graft moves and pick one at random.
	var candidates: Array[String] = []
	for key in GRAFT_MOVES.keys():
		if grafted.has(key) and bool(grafted[key]):
			candidates.append(String(GRAFT_MOVES[key]))
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]

# === Shared mutation pool ===================================================
#
# A flat list of "weird features" that any cross-species kid can roll on top
# of its normal genome. Each entry is a string tag with renderer-side meaning.
# Procedural body builders check `genome.universal_mutations.<tag>` and add
# the corresponding visual. Adding a new mutation: add a tag here + a render
# branch in each procedural body that supports it (mimic/mushroom/etc).
#
# Data-driven so new mutations don't require touching breeding code.
const MUTATION_POOL: Array[String] = [
	"third_eye",          # extra single glowing eye on the body/forehead
	"glowing_veins",      # subtle emissive lines on the body surface
	"fur_patches",        # tufts of fur scattered on the body
	"scale_patches",      # diamond scales on the body
	"oversized_limb",     # one limb is 1.5x size of the others
	"color_drift",        # palette hue is rotated 30-90° from the parents'
	"asymmetric_eyes",    # left and right eyes are different sizes/colors
	"extra_mouth",        # second mouth somewhere unexpected
	"halo",               # floating glowing ring above the head
	"tail_stub",          # short tail protrusion at the back
	"crystal_growth",     # small crystal shards growing on the body
	"living_moss",        # green moss patches with tiny embedded eyes
	"spike_ridge",        # row of spikes along the back / top
	"chitin_plate",       # hard insect-like plate on top of head
	"floating_orb",       # small orb hovers above the creature
]

## Roll `count` distinct mutations from MUTATION_POOL and apply them to kid's
## genome under `universal_mutations`. Procedural body renderers check each
## flag and add the corresponding visual element. Higher hybrid_generation
## passes higher `count` so weirdness compounds across generations.
static func apply_universal_mutations(kid: ActorData, count: int) -> void:
	if not "genome" in kid:
		return
	var g_var: Variant = kid.get("genome")
	if not (g_var is Dictionary):
		return
	var g: Dictionary = g_var
	if not g.has("universal_mutations"):
		g["universal_mutations"] = _default_universal_mutations()
	var um: Dictionary = g["universal_mutations"]
	# Pick `count` distinct mutations.
	var picked: Array[String] = []
	var available: Array[String] = MUTATION_POOL.duplicate()
	available.shuffle()
	var n: int = clampi(count, 0, available.size())
	for i in range(n):
		picked.append(available[i])
	# Set the picked flags true. Don't clear existing ones — mutations
	# accumulate across generations.
	for tag in picked:
		um[tag] = true

static func _default_universal_mutations() -> Dictionary:
	# All tags default to false. Procedural bodies check each one and skip
	# the render branch if the flag is missing or false. Forward-compatible
	# with future tags added to MUTATION_POOL.
	var out: Dictionary = {}
	for tag in MUTATION_POOL:
		out[tag] = false
	return out

## Compute the probability that offspring of `parent_a` and `parent_b` should
## inherit Mimic skills. Centralized so every create_offspring() override can
## reuse the same gates without duplicating the rules.
##   - both pure MimicData  -> 1.0
##   - one pure MimicData   -> 0.30
##   - neither MimicData but at least one has mimic_blood > 0 -> 0.60
##   - otherwise -> 0.0
static func mimic_skill_inheritance_chance(parent_a: ActorData, parent_b: ActorData) -> float:
	if parent_a == null or parent_b == null:
		return 0.0
	var a_is_pure: bool = parent_a.get_actor_type() == "MimicData"
	var b_is_pure: bool = parent_b.get_actor_type() == "MimicData"
	if a_is_pure and b_is_pure:
		return 1.0
	if a_is_pure or b_is_pure:
		return 0.30
	if parent_a.mimic_blood > 0.0 or parent_b.mimic_blood > 0.0:
		return 0.60
	return 0.0

## Apply the standard hybrid-breeding lineage to `kid`, given its parents.
## Sets mimic_blood (averaged + small drift) and rolls inherit_mimic_skills.
static func apply_mimic_lineage(kid: ActorData, parent_a: ActorData, parent_b: ActorData) -> void:
	if kid == null or parent_a == null or parent_b == null:
		return
	var avg_blood: float = (parent_a.mimic_blood + parent_b.mimic_blood) * 0.5
	# Pure × pure clamps to 1.0; pure × non-pure averages but uplifts since pure parent = 1.0.
	if parent_a.get_actor_type() == "MimicData":
		avg_blood = (1.0 + parent_b.mimic_blood) * 0.5
	if parent_b.get_actor_type() == "MimicData":
		avg_blood = (parent_a.mimic_blood + 1.0) * 0.5
	if parent_a.get_actor_type() == "MimicData" and parent_b.get_actor_type() == "MimicData":
		avg_blood = 1.0
	kid.mimic_blood = clampf(avg_blood, 0.0, 1.0)
	var chance: float = mimic_skill_inheritance_chance(parent_a, parent_b)
	kid.inherit_mimic_skills = randf() < chance

## Universal cross-species breeder. ANY ActorData × ANY ActorData produces a
## kid whose body type is one of the two parents (50/50 roll), with traits
## from BOTH parents blended in — stats, palette, eye colors/count/spread,
## tongue/tooth dimensions, limbs, mutation flags. All transfers write into
## the kid's GENOME (not just legacy ActorData mirrors) so the procedural
## body actually reads the mixed values.
##
## Subclasses call this from their create_offspring when partner is a
## different species. Same-species breeding stays in the subclass (richer
## per-species genome crossover).
##
## Adding a new ActorData subclass requires NO changes to existing classes —
## any cross-pair (NewSpecies × Mimic, NewSpecies × Mushroom, ...) routes
## through here automatically.
static func universal_crossover_breed(parent_a: ActorData, parent_b: ActorData) -> ActorData:
	if parent_a == null or parent_b == null:
		return null
	# Same species → defer to the species' own crossover for richer mixing.
	if parent_a.get_actor_type() == parent_b.get_actor_type():
		return parent_a.create_offspring(parent_b)
	# Cross species: pick the primary parent (50/50). Kid inherits that
	# parent's body type via a solo breed (primary × primary returns a near-
	# clone with mutations), then we overlay BOTH parents' stats AND
	# aggressively blend genome slots with the secondary parent so the
	# procedural body renders a visible hybrid.
	var kid_is_a: bool = randf() < 0.5
	var primary: ActorData = parent_a if kid_is_a else parent_b
	var secondary: ActorData = parent_b if kid_is_a else parent_a
	var kid: ActorData = primary.create_offspring(primary)
	if kid == null:
		return null
	# Stat blend from BOTH parents (overrides the solo-clone stats).
	kid.strength = (parent_a.strength + parent_b.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (parent_a.dexterity + parent_b.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (parent_a.constitution + parent_b.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (parent_a.intelligence + parent_b.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (parent_a.wisdom + parent_b.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (parent_a.charisma + parent_b.charisma) * 0.5 * randf_range(0.9, 1.1)
	# Fresh per-kid render_seed so this individual has its OWN stable visual
	# identity.
	kid.render_seed = randi()
	# Hybrid generation: a cross-species breed always increments. Same-species
	# breeds aren't routed here (they go to species-specific crossover above),
	# so reaching this point implies cross-species.
	var max_parent_gen: int = maxi(parent_a.hybrid_generation, parent_b.hybrid_generation)
	kid.hybrid_generation = max_parent_gen + 1
	# Generate a fresh random name tied to the new render_seed so the bred
	# kid has a distinct identifiable name in the herd. Without this, every
	# Mimic kid would be "Mimic Spawnling", every Mushroom kid "Mushroomling",
	# making creatures impossible to tell apart in a 20-card herd grid.
	apply_generated_name(kid)
	# GENOME-level trait transfer. This writes into the kid's genome slots
	# directly so the procedural body sees blended values.
	_transfer_genome_traits(kid, secondary)
	# FRANKENSTEIN GRAFT: populate the kid's "grafted" slot with body-part
	# data extracted from the secondary parent.
	_populate_graft_slot(kid, secondary)
	# UNIVERSAL MUTATIONS: roll mutations from the shared pool. Count scales
	# with hybrid_generation so accumulated breeding produces weirder kids.
	# Gen 1: ~1 mutation. Gen 2: ~2. Gen 3: ~3. Capped at 5.
	var mutation_count: int = clampi(1 + kid.hybrid_generation / 2, 1, 5)
	apply_universal_mutations(kid, mutation_count)
	# PER-AXIS DIMENSION MIXING: each width/height/depth axis is picked
	# independently from a parent's body slot (not just averaged). Result:
	# kids can be tall AND wide, or narrow AND short — not always averaged.
	_mix_body_dimensions_per_axis(kid, parent_a, parent_b)
	# Apply chimeric name (overrides the species-default name with optional
	# chimeric prefix based on hybrid_generation).
	apply_generated_name(kid)
	# Sync legacy ActorData mirrors (base_color / pattern_color) to whatever
	# the genome palette ended up with, so ActorCard tints + GoatRenderer
	# stay consistent with the rendered creature.
	_sync_legacy_palette_from_genome(kid)
	# Hornbound: roll the hybrid moveset. Cross-species kids get 3 moves with
	# the slot-3 table; same-species would have gone through their own crossover
	# above and skipped this branch.
	kid.moveset = roll_moveset(parent_a, parent_b, true, kid)
	# Mimic-blood lineage + skill-inheritance probability gates.
	apply_mimic_lineage(kid, parent_a, parent_b)
	# Diagnostic: log every cross-species breed so we can see in the console
	# what type the kid is and whether the graft slot was filled in.
	print("[Breed] %s × %s -> %s | graft source=%s | mimic_blood=%.2f" % [
		parent_a.get_actor_type(),
		parent_b.get_actor_type(),
		kid.get_actor_type(),
		_graft_source_of(kid),
		kid.mimic_blood
	])
	return kid

## Generate a unique fantasy-style creature name derived from a seed.
## Same seed always produces the same name, so the kid's render_seed
## determines its name — search-able and stable across reloads.
##
## The pool is small enough to be memorable but combinatorially produces
## thousands of distinct names. Examples: "Krathmoss", "Vorbark", "Sligrime",
## "Thrumwick", "Zeerune", "Brakclaw", "Yamveil", "Quorling".
const _NAME_STARTS: Array[String] = [
	"Vor", "Kra", "Thr", "Mor", "Zir", "Drak", "Gly", "Slin", "Ven", "Wrax",
	"Bren", "Quor", "Yam", "Phex", "Crum", "Slig", "Nyx", "Volk", "Eth", "Sygn",
	"Brak", "Hex", "Olg", "Wuth", "Klar", "Grim", "Snor", "Thur", "Vex", "Zog",
	"Mok", "Pry", "Snik", "Drun", "Frem", "Glar", "Hosp", "Iz", "Jurn", "Korn"
]
const _NAME_MIDS: Array[String] = [
	"", "", "", "", "el", "ar", "or", "um", "ash", "is",
	"uth", "il", "ix", "yk", "et"
]
const _NAME_ENDS: Array[String] = [
	"bark", "fang", "moss", "claw", "shroom", "vein", "wisp", "doom", "rune",
	"blight", "veil", "spire", "ling", "ot", "ek", "us", "iss", "och", "ith",
	"rax", "wick", "burr", "thorn", "grume", "scab", "tine", "row", "fen",
	"mort", "kin", "ax", "drath"
]

static func generate_name_from_seed(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	# Use the seed directly; same seed -> same name every call.
	rng.seed = seed if seed != 0 else randi()
	var start: String = _NAME_STARTS[rng.randi() % _NAME_STARTS.size()]
	var mid: String = _NAME_MIDS[rng.randi() % _NAME_MIDS.size()]
	var end: String = _NAME_ENDS[rng.randi() % _NAME_ENDS.size()]
	return start + mid + end

## Apply a seed-generated name to whichever name field this resource exposes
## (GoatData uses goat_name; everything else uses creature_name).
##
## Hybrid generation 2+ gets a CHIMERIC prefix so the player can see at a
## glance which herd members are deep-chimera lineage. Prefix pool is
## seeded too so the same kid always gets the same prefix.
static func apply_generated_name(data: ActorData) -> void:
	if data == null:
		return
	var seed: int = data.render_seed if data.render_seed != 0 else randi()
	var generated: String = generate_name_from_seed(seed)
	if data.hybrid_generation >= 2:
		generated = _chimeric_prefix_from_seed(seed, data.hybrid_generation) + " " + generated
	if "goat_name" in data:
		data.set("goat_name", generated)
	elif "creature_name" in data:
		data.set("creature_name", generated)

const _CHIMERIC_PREFIXES: Array[String] = [
	"Chimeric", "Twisted", "Warped", "Fused", "Mutant",
	"Aberrant", "Discordant", "Spliced", "Eldritch", "Distorted"
]
const _DEEP_CHIMERIC_PREFIXES: Array[String] = [
	"Abominable", "Heretical", "Forsaken", "Voidwarped", "Primordial",
	"Cosmic", "Riftborn", "Apex", "Profane", "Unhallowed"
]

static func _chimeric_prefix_from_seed(seed: int, generation: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 17 + 31  # decorrelate from name-generator seed sequence
	var pool: Array[String] = _DEEP_CHIMERIC_PREFIXES if generation >= 4 else _CHIMERIC_PREFIXES
	return pool[rng.randi() % pool.size()]

## Returns a fresh default `grafted` slot dict for whichever ActorData
## subclass the kid is. Used as a self-healing fallback when an old-format
## parent's genome (saved before the grafted slot existed) lacks the key.
static func _default_graft_slot_for_kid(kid: ActorData) -> Dictionary:
	if not "genome" in kid:
		return {}
	# Each subclass exposes its full default_genome() — we ask for it and
	# extract just the grafted slot. No species-specific knowledge here.
	if kid.has_method("default_genome"):
		var d: Variant = kid.call("default_genome")
		if d is Dictionary and (d as Dictionary).has("grafted"):
			return ((d as Dictionary)["grafted"] as Dictionary).duplicate(true)
	# default_genome is a static; try via the script.
	var script: Variant = kid.get_script()
	if script and script.has_method("default_genome"):
		var d2: Variant = script.call("default_genome")
		if d2 is Dictionary and (d2 as Dictionary).has("grafted"):
			return ((d2 as Dictionary)["grafted"] as Dictionary).duplicate(true)
	return {}

## Diagnostic: returns the kid's grafted.source_species, or "<none>".
static func _graft_source_of(kid: ActorData) -> String:
	if not "genome" in kid:
		return "<no-genome>"
	var g_var: Variant = kid.get("genome")
	if not (g_var is Dictionary):
		return "<no-genome>"
	var g: Dictionary = g_var
	if not g.has("grafted"):
		return "<no-graft-slot>"
	var graft: Dictionary = g["grafted"]
	var src: String = String(graft.get("source_species", ""))
	if src.is_empty():
		return "<empty>"
	return src

## Populate the kid's genome["grafted"] slot with body-part data extracted
## from the secondary parent. The procedural body builders (Mimic, Mushroom)
## render the grafted features on top of their normal body when the slot
## contains non-zero data for the matching source_species.
##
## Adding a new species: declare a "grafted" slot in its genome's
## default_genome() with fields for each other species' grafts, then
## extend this function with another `source_type == "XXX"` branch.
static func _populate_graft_slot(kid: ActorData, source: ActorData) -> void:
	if not "genome" in kid or not "genome" in source:
		return
	var kid_genome_var: Variant = kid.get("genome")
	var src_genome_var: Variant = source.get("genome")
	if not (kid_genome_var is Dictionary) or not (src_genome_var is Dictionary):
		return
	var kid_genome: Dictionary = kid_genome_var
	var src_genome: Dictionary = src_genome_var
	# Self-heal: if the kid genome was crossed-over from an old-format parent
	# that pre-dates the grafted slot, add it on the fly so the graft data
	# has somewhere to live. Otherwise the diagnostic prints
	# "graft source=<no-graft-slot>" and the kid renders as a plain primary.
	if not kid_genome.has("grafted"):
		var default_graft: Dictionary = _default_graft_slot_for_kid(kid)
		if default_graft.is_empty():
			return
		kid_genome["grafted"] = default_graft
	var grafted: Dictionary = kid_genome["grafted"]
	var src_pal: Dictionary = src_genome.get("palette", {})
	var source_type: String = source.get_actor_type()
	grafted["source_species"] = ""
	if source_type == "MushroomData":
		grafted["source_species"] = "mushroom"
		var src_cap: Dictionary = src_genome.get("cap", {})
		var src_face_m: Dictionary = src_genome.get("face", {})
		grafted["mushroom_cap_profile"] = String(src_cap.get("profile", "dome"))
		grafted["mushroom_cap_radius"] = float(src_cap.get("radius", 0.40)) * 0.70
		grafted["mushroom_cap_height"] = float(src_cap.get("height", 0.25)) * 0.70
		grafted["mushroom_cap_color"] = src_pal.get("cap_color", Color(0.86, 0.25, 0.25))
		grafted["mushroom_spot_count"] = int(src_cap.get("spot_count", 5))
		grafted["mushroom_spot_radius"] = float(src_cap.get("spot_radius", 0.06)) * 0.70
		grafted["mushroom_spot_color"] = src_pal.get("spot_color", Color(0.95, 0.95, 0.88))
		grafted["mushroom_eye_color"] = src_pal.get("eye_color", Color(0.1, 0.1, 0.1))
		# COMPOUND MODULAR FEATURES: each is its own independent roll, so
		# sibling hybrids get visibly different combinations.
		grafted["has_cap_graft"] = randf() < 0.85           # mushroom cap on top of lid
		grafted["has_spots_on_body"] = randf() < 0.65       # spots painted on chest
		grafted["has_extra_eyes_on_cap"] = randf() < 0.65   # eyes peer from the cap
		grafted["has_stem_antenna"] = randf() < 0.35        # stem antenna pokes from lid
		grafted["extra_eye_count"] = int(src_face_m.get("eye_count", 2)) + randi_range(0, 4)
		grafted["extra_eye_radius"] = float(src_face_m.get("eye_radius", 0.04))
		grafted["extra_eye_glow"] = bool(src_face_m.get("eye_glow", false))
	elif source_type == "MimicData":
		grafted["source_species"] = "mimic"
		var src_face: Dictionary = src_genome.get("face", {})
		var src_dec: Dictionary = src_genome.get("decorations", {})
		var src_mut: Dictionary = src_genome.get("mutation", {})
		grafted["mimic_band_count"] = int(src_dec.get("band_count", 2))
		grafted["mimic_band_color"] = src_pal.get("accent_color", Color(0.58, 0.52, 0.44))
		grafted["mimic_tooth_count"] = maxi(int(src_face.get("tooth_count", 6)), 4)
		grafted["mimic_tooth_size"] = float(src_face.get("tooth_size", 0.03)) * 0.85
		grafted["mimic_tooth_color"] = src_pal.get("tooth_color", Color(0.95, 0.92, 0.85))
		grafted["mimic_eye_color"] = src_pal.get("eye_color", Color(0.94, 0.18, 0.10))
		grafted["mimic_glow"] = bool(src_mut.get("cursed_glow", false))
		# COMPOUND MODULAR FEATURES on Mushroom-bodied hybrids:
		grafted["has_band_graft"] = randf() < 0.85          # bands wrapping stem
		grafted["has_tooth_graft"] = randf() < 0.85         # tooth ring around cap rim
		grafted["has_extra_eyes_on_cap"] = randf() < 0.70   # extra glowing eyes on cap
		grafted["has_lid_crown"] = randf() < 0.45           # tiny mimic lid on top of cap
		grafted["has_gem_scatter"] = randf() < 0.40         # gems scattered on cap
		grafted["extra_eye_count"] = int(src_face.get("eye_count", 2)) + randi_range(2, 6)
		grafted["extra_eye_radius"] = float(src_face.get("eye_radius", 0.04))
		grafted["extra_eye_glow"] = true                    # mimic eyes are signature-glowing
	elif source_type == "GoblinData":
		grafted["source_species"] = "goblin"
		grafted["goblin_skin_color"] = source.base_color
	elif source_type == "GoatData":
		grafted["source_species"] = "goat"
		grafted["goat_pattern_color"] = source.pattern_color
		# Goats sometimes have horns — propagate the flag if the source had any.
		if "horn_type" in source:
			var horn_value: Variant = source.get("horn_type")
			if horn_value is int and int(horn_value) != 0:
				grafted["goat_horn_present"] = true

## Aggressive trait transfer from `source` into `kid`'s genome. Designed so
## EVERY cross-species kid shows visible influence from both parents —
## blended palette colors (including cross-species name mapping), blended
## eye count / radius / spread, blended mouth + tongue + tooth dimensions,
## inherited limbs whenever the source has them, and inherited mutations.
##
## Each transfer writes INTO the kid genome's matching slot (palette, face,
## limbs, mutation). Body-plan-specific slots (Mimic "lid", Mushroom "cap")
## stay on the primary's body type since they require species-specific
## rendering — but the colors used to render them do get blended.
static func _transfer_genome_traits(kid: ActorData, source: ActorData) -> void:
	if not "genome" in kid or not "genome" in source:
		return
	var kid_genome_var: Variant = kid.get("genome")
	var src_genome_var: Variant = source.get("genome")
	if not (kid_genome_var is Dictionary) or not (src_genome_var is Dictionary):
		return
	var kid_genome: Dictionary = kid_genome_var
	var src_genome: Dictionary = src_genome_var
	_blend_palette_slot(kid_genome, src_genome)
	_blend_face_slot(kid_genome, src_genome)
	_blend_limbs_slot(kid_genome, src_genome)
	_blend_animation_slot(kid_genome, src_genome)
	_blend_mutation_slot(kid_genome, src_genome)

## Lerps every color field shared between two palettes. Also cross-maps
## species-specific "main body" + "accent" colors:
##   Mimic "body_color"   <-> Mushroom "cap_color"
##   Mimic "accent_color" <-> Mushroom "spot_color"
## So a Mimic kid born of a red-cap Mushroom gets RED tinting on its chest,
## not just a generic blend of unrelated fields.
static func _blend_palette_slot(kid_genome: Dictionary, src_genome: Dictionary) -> void:
	if not (kid_genome.has("palette") and src_genome.has("palette")):
		return
	var kid_pal: Dictionary = kid_genome["palette"]
	var src_pal: Dictionary = src_genome["palette"]
	# Direct lerp on shared-name keys (eye_color, mouth_color, etc.). Plus a
	# 20% chance per color to ADDITIONALLY rotate hue by 30-90° on the HSV
	# wheel — gives kids wilder palette outputs than straight averaging.
	for key in kid_pal.keys():
		if key in src_pal:
			var kid_v = kid_pal[key]
			var src_v = src_pal[key]
			if kid_v is Color and src_v is Color:
				var blended: Color = (kid_v as Color).lerp(src_v as Color, randf_range(0.30, 0.55))
				if randf() < 0.20:
					blended = _rotate_hue(blended, randf_range(30.0, 90.0) * (1.0 if randf() < 0.5 else -1.0))
				kid_pal[key] = blended
	# Cross-species "main body" mapping.
	var body_src: Color = Color.WHITE
	var has_body_src: bool = false
	if "body_color" in src_pal and src_pal["body_color"] is Color:
		body_src = src_pal["body_color"]
		has_body_src = true
	elif "cap_color" in src_pal and src_pal["cap_color"] is Color:
		body_src = src_pal["cap_color"]
		has_body_src = true
	if has_body_src:
		if "body_color" in kid_pal and kid_pal["body_color"] is Color:
			kid_pal["body_color"] = (kid_pal["body_color"] as Color).lerp(body_src, randf_range(0.30, 0.55))
		if "cap_color" in kid_pal and kid_pal["cap_color"] is Color:
			kid_pal["cap_color"] = (kid_pal["cap_color"] as Color).lerp(body_src, randf_range(0.30, 0.55))
	# Cross-species "accent" mapping (Mimic bands ↔ Mushroom spots).
	var accent_src: Color = Color.WHITE
	var has_accent_src: bool = false
	if "accent_color" in src_pal and src_pal["accent_color"] is Color:
		accent_src = src_pal["accent_color"]
		has_accent_src = true
	elif "spot_color" in src_pal and src_pal["spot_color"] is Color:
		accent_src = src_pal["spot_color"]
		has_accent_src = true
	if has_accent_src:
		if "accent_color" in kid_pal and kid_pal["accent_color"] is Color:
			kid_pal["accent_color"] = (kid_pal["accent_color"] as Color).lerp(accent_src, randf_range(0.30, 0.55))
		if "spot_color" in kid_pal and kid_pal["spot_color"] is Color:
			kid_pal["spot_color"] = (kid_pal["spot_color"] as Color).lerp(accent_src, randf_range(0.30, 0.55))

## Blends face fields — eye_count averages, then small jitter; eye_radius,
## eye_spread, mouth_width/height, tongue_length/thickness, tooth_size all
## lerp 50/50 between parents.
static func _blend_face_slot(kid_genome: Dictionary, src_genome: Dictionary) -> void:
	if not (kid_genome.has("face") and src_genome.has("face")):
		return
	var kid_face: Dictionary = kid_genome["face"]
	var src_face: Dictionary = src_genome["face"]
	# Eye count: average + bias, clamp to [1, 5].
	if "eye_count" in kid_face and "eye_count" in src_face:
		var avg: float = (float(kid_face["eye_count"]) + float(src_face["eye_count"])) * 0.5
		kid_face["eye_count"] = clampi(int(round(avg + randf_range(-0.49, 0.49))), 1, 5)
	# Numeric fields — direct average + jitter.
	var numeric_keys: Array = [
		"eye_radius", "eye_spread", "eye_y_offset",
		"mouth_width", "mouth_height", "mouth_y_offset",
		"tongue_length", "tongue_thickness", "tongue_protrude",
		"tooth_count", "tooth_size"
	]
	for key in numeric_keys:
		if key in kid_face and key in src_face:
			var kid_v = kid_face[key]
			var src_v = src_face[key]
			if (kid_v is float or kid_v is int) and (src_v is float or src_v is int):
				kid_face[key] = (float(kid_v) + float(src_v)) * 0.5 * randf_range(0.9, 1.1)
	# Eyes-on-lid (Mimic-specific) — keep kid's value (it's tied to lid shape).

## Inherit limbs from source unconditionally when source has them set true.
## This is the user's "chest with mushroom legs" path: pure mimics don't have
## limbs by default, but a Mimic × Mushroom kid (whichever type wins) will
## visibly inherit limbs from a partner that has them.
static func _blend_limbs_slot(kid_genome: Dictionary, src_genome: Dictionary) -> void:
	if not (kid_genome.has("limbs") and src_genome.has("limbs")):
		return
	var kid_limbs: Dictionary = kid_genome["limbs"]
	var src_limbs: Dictionary = src_genome["limbs"]
	var src_has_arms: bool = bool(src_limbs.get("has_arms", false))
	var src_has_legs: bool = bool(src_limbs.get("has_legs", false))
	# Force inherit when source has them — guarantees visible cross-species feature.
	if src_has_arms:
		kid_limbs["has_arms"] = true
		for key in ["arm_length", "arm_radius", "arm_y_offset", "arm_droop"]:
			if key in src_limbs:
				kid_limbs[key] = src_limbs[key]
	if src_has_legs:
		kid_limbs["has_legs"] = true
		for key in ["leg_length", "leg_radius", "leg_spread", "foot_size"]:
			if key in src_limbs:
				kid_limbs[key] = src_limbs[key]

## Blend animation fields (bob speed, lid idle speed, tongue wiggle) so hybrid
## kids have noticeably different movement rhythms from either parent.
static func _blend_animation_slot(kid_genome: Dictionary, src_genome: Dictionary) -> void:
	if not (kid_genome.has("animation") and src_genome.has("animation")):
		return
	var kid_anim: Dictionary = kid_genome["animation"]
	var src_anim: Dictionary = src_genome["animation"]
	for key in kid_anim.keys():
		if key in src_anim:
			var kid_v = kid_anim[key]
			var src_v = src_anim[key]
			if (kid_v is float or kid_v is int) and (src_v is float or src_v is int):
				kid_anim[key] = (float(kid_v) + float(src_v)) * 0.5 * randf_range(0.9, 1.1)

## Mutation slot: bools have 50% chance of inheriting source's value;
## numbers blend; colors lerp.
static func _blend_mutation_slot(kid_genome: Dictionary, src_genome: Dictionary) -> void:
	if not (kid_genome.has("mutation") and src_genome.has("mutation")):
		return
	var kid_mut: Dictionary = kid_genome["mutation"]
	var src_mut: Dictionary = src_genome["mutation"]
	for key in src_mut.keys():
		var src_val = src_mut[key]
		if src_val is bool:
			if randf() < 0.50:
				kid_mut[key] = src_val
		elif src_val is Color:
			if key in kid_mut and kid_mut[key] is Color:
				kid_mut[key] = (kid_mut[key] as Color).lerp(src_val as Color, randf_range(0.30, 0.55))
			elif randf() < 0.50:
				kid_mut[key] = src_val
		elif src_val is float or src_val is int:
			if key in kid_mut and (kid_mut[key] is float or kid_mut[key] is int):
				kid_mut[key] = (float(kid_mut[key]) + float(src_val)) * 0.5 * randf_range(0.9, 1.1)

## Rotate a Color's hue by `degrees` on the HSV wheel, preserving saturation
## and value. Used by palette blending to produce occasional wild color
## drift instead of always-averaged outputs.
static func _rotate_hue(c: Color, degrees: float) -> Color:
	var h: float = c.h
	var s: float = c.s
	var v: float = c.v
	h = fposmod(h + degrees / 360.0, 1.0)
	return Color.from_hsv(h, s, v, c.a)

## Independently picks each body-dimension axis from one parent or the other.
## Without this, the kid inherits ALL dimensions from primary (since the kid
## is solo-bred from primary). Result: kids feel like one parent's body with
## colors swapped. Now each axis is a 50/50 coin flip + ±10% jitter, so a
## kid can be tall like mom AND wide like dad, not always averaged.
static func _mix_body_dimensions_per_axis(kid: ActorData, parent_a: ActorData, parent_b: ActorData) -> void:
	if not "genome" in kid or not "genome" in parent_a or not "genome" in parent_b:
		return
	var kid_g_var: Variant = kid.get("genome")
	var pa_g_var: Variant = parent_a.get("genome")
	var pb_g_var: Variant = parent_b.get("genome")
	if not (kid_g_var is Dictionary and pa_g_var is Dictionary and pb_g_var is Dictionary):
		return
	var kid_g: Dictionary = kid_g_var
	var pa_g: Dictionary = pa_g_var
	var pb_g: Dictionary = pb_g_var
	if not kid_g.has("body"):
		return
	var kid_body: Dictionary = kid_g["body"]
	var pa_body: Dictionary = pa_g.get("body", {})
	var pb_body: Dictionary = pb_g.get("body", {})
	# Per-axis mix: width, height, depth — each independently from a parent
	# if both have the field, else fall back to the parent that has it.
	for axis in ["width", "height", "depth", "radius_top", "radius_bottom"]:
		var have_a: bool = pa_body.has(axis) and (pa_body[axis] is float or pa_body[axis] is int)
		var have_b: bool = pb_body.has(axis) and (pb_body[axis] is float or pb_body[axis] is int)
		if not (have_a or have_b):
			continue
		var picked: float
		if have_a and have_b:
			picked = float(pa_body[axis]) if randf() < 0.5 else float(pb_body[axis])
		elif have_a:
			picked = float(pa_body[axis])
		else:
			picked = float(pb_body[axis])
		kid_body[axis] = picked * randf_range(0.9, 1.1)

## Re-syncs the legacy ActorData.base_color / pattern_color mirrors to match
## whatever the genome palette ended up with after blending. Without this,
## ActorCard tints and the GoatRenderer would still show pre-blend colors.
static func _sync_legacy_palette_from_genome(kid: ActorData) -> void:
	if not "genome" in kid:
		return
	var g_var: Variant = kid.get("genome")
	if not (g_var is Dictionary):
		return
	var palette: Dictionary = (g_var as Dictionary).get("palette", {})
	if "body_color" in palette and palette["body_color"] is Color:
		kid.base_color = palette["body_color"]
	elif "cap_color" in palette and palette["cap_color"] is Color:
		kid.base_color = palette["cap_color"]
	if "accent_color" in palette and palette["accent_color"] is Color:
		kid.pattern_color = palette["accent_color"]
	elif "spot_color" in palette and palette["spot_color"] is Color:
		kid.pattern_color = palette["spot_color"]
