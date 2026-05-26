extends Node

## Autoload — the player's permanent collection of monster traits learned
## from successful captures. Library traits feed into breeding rolls (a
## hybrid kid's slot-3 move can roll from this pool) and act as a long-tail
## progression vector ("47 / ~200 traits known").
##
## Capture is the ONLY way to add traits. Killing gives parts/gold/XP but
## never traits — this is the rule that makes capture economically necessary
## rather than optional.
##
## Per the design doc, each ActorTypeData entry's `abilities` array IS the
## trait list for that species. When the player first captures a species,
## all its abilities get added to the library.

const SAVE_PATH := "user://trait_library.cfg"

## All traits the player has learned. Key = trait name, value = first species
## captured that taught it (for "where did I get this?" reference).
var known_traits: Dictionary = {}

## All species the player has successfully captured at least once.
var captured_species: Array[String] = []

## Recently added trait names (last 5 captures). UI shows these highlighted.
var recent_additions: Array[String] = []
const RECENT_LIMIT := 5

## Total trait count known across all sources. Calculated lazily.
var _cached_total_known: int = -1

# ============================================================================
# Signals
# ============================================================================

## Emitted whenever a capture adds at least one new trait.
signal traits_added(new_traits: Array[String], source_species: String)

## Emitted when the first capture of a species occurs.
signal species_first_captured(species: String)

# ============================================================================
# Public API
# ============================================================================

func _ready() -> void:
	_load()

## Record a capture. Adds any traits not yet known to the library, and adds
## the species to captured_species if not already present.
##
## [species] Species name as it appears in ActorTypeData (e.g. "Wolf").
## [Returns] Array of newly-added trait names (may be empty if all already known).
func add_capture(species: String) -> Array[String]:
	if species.is_empty():
		return []
	var newly_added: Array[String] = []
	# First-capture bookkeeping.
	var first_time: bool = not species in captured_species
	if first_time:
		captured_species.append(species)
		species_first_captured.emit(species)
	# Pull the species' abilities from ActorTypeData and add them.
	var defaults: Dictionary = ActorTypeData.get_defaults(species)
	var abilities: Variant = defaults.get("abilities", [])
	if not (abilities is Array):
		_save()
		return []
	for ability_value in abilities:
		var trait_name: String = String(ability_value).strip_edges()
		if trait_name.is_empty():
			continue
		if not known_traits.has(trait_name):
			known_traits[trait_name] = species
			newly_added.append(trait_name)
	# Update recent additions list.
	for t in newly_added:
		_push_recent(t)
	_cached_total_known = -1
	if not newly_added.is_empty():
		traits_added.emit(newly_added, species)
		_save()
	return newly_added

## Returns true if the player has captured this species before.
func has_captured(species: String) -> bool:
	return species in captured_species

## Returns true if the trait has been learned.
func is_trait_known(trait_name: String) -> bool:
	return known_traits.has(trait_name)

## Returns the count of known traits (cached).
func get_known_trait_count() -> int:
	if _cached_total_known < 0:
		_cached_total_known = known_traits.size()
	return _cached_total_known

## Returns a random known trait, or "" if the library is empty.
## Used by breeding slot-3 roll (the 12% "library move" outcome).
func get_random_known_trait() -> String:
	if known_traits.is_empty():
		return ""
	var keys: Array = known_traits.keys()
	return String(keys[randi() % keys.size()])

## Returns the traits learned from a specific species (for UI inspection).
func get_traits_from_species(species: String) -> Array[String]:
	var result: Array[String] = []
	for trait_name in known_traits.keys():
		if known_traits[trait_name] == species:
			result.append(String(trait_name))
	return result

## Returns count of unique species captured.
func get_captured_species_count() -> int:
	return captured_species.size()

## Per-category capture progress: returns Dictionary[category_name, count].
func get_category_progress() -> Dictionary:
	var progress: Dictionary = {}
	for species in captured_species:
		var category: String = ActorTypeData.get_category(species)
		progress[category] = int(progress.get(category, 0)) + 1
	return progress

# ============================================================================
# Recent additions
# ============================================================================

func _push_recent(trait_name: String) -> void:
	recent_additions.append(trait_name)
	while recent_additions.size() > RECENT_LIMIT:
		recent_additions.pop_front()

# ============================================================================
# Persistence
# ============================================================================

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("Library", "known_traits", known_traits)
	cfg.set_value("Library", "captured_species", captured_species)
	cfg.set_value("Library", "recent_additions", recent_additions)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var kt: Variant = cfg.get_value("Library", "known_traits", {})
	if kt is Dictionary:
		known_traits = kt
	var cs: Variant = cfg.get_value("Library", "captured_species", [])
	if cs is Array:
		captured_species.clear()
		for item in cs:
			captured_species.append(String(item))
	var ra: Variant = cfg.get_value("Library", "recent_additions", [])
	if ra is Array:
		recent_additions.clear()
		for item in ra:
			recent_additions.append(String(item))

# ============================================================================
# Debug
# ============================================================================

## Wipe the library. For testing / new-game-plus.
func reset() -> void:
	known_traits.clear()
	captured_species.clear()
	recent_additions.clear()
	_cached_total_known = -1
	_save()

func dump_state() -> String:
	var lines: Array[String] = []
	lines.append("=== TraitLibrary State ===")
	lines.append("Known traits: %d" % known_traits.size())
	lines.append("Captured species: %d" % captured_species.size())
	lines.append("Recent: %s" % str(recent_additions))
	return "\n".join(lines)
