class_name CreatureSignatures
extends RefCounted

## Per-creature variation registry. Resolves a species name into:
##   1. a `sub_template` key (e.g. "wolf_like", "bear_like") that selects
##      anatomy variant within a category
##   2. a deterministic species_rng (so the same species always rolls the
##      same dimensions / palette across game launches)
##   3. a size class (Tiny / Small / Medium / Large / Huge / Gargantuan)
##      derived from HP if no explicit value is set
##
## This is the bridge between the static `ActorTypeData` stat blocks and the
## procedural `ActorBodyPlanGenerator`, making 600+ creatures visually distinct
## without hand-authoring each one's body math.
##
## See `Markdowns/Plans/PerCreatureBodyMath.md` for design rationale.

# ============================================================================
# Sub-template hints — explicit mappings for showcase / common creatures
# ============================================================================
##
## Maps species names to anatomy variants. Looked up first by exact match;
## falls back to stat-profile heuristic, then category default.
##
## Adding a new hint: just append. The generator picks it up on next spawn.

const SUB_TEMPLATE_HINTS: Dictionary = {
	# === Beast — wolf_like (lean quadruped, long muzzle) ============
	"Wolf": "wolf_like",
	"Dire Wolf": "wolf_like",
	"Jackal": "wolf_like",
	"Mastiff": "wolf_like",
	"Hyena": "wolf_like",
	"Fox": "wolf_like",
	"Arctic Fox": "arctic_fox",
	"Tiger": "wolf_like",
	"Panther": "wolf_like",
	"Lion": "wolf_like",
	"Spotted Lion": "wolf_like",
	"Snow Leopard": "wolf_like",
	"Saber-toothed Tiger": "wolf_like",
	"Cheetah": "wolf_like",
	"Coyote": "wolf_like",

	# === Beast — bear_like (bulky quadruped, shoulder hump) =========
	"Bear": "bear_like",
	"Polar Bear": "bear_like",
	"Cave Bear": "bear_like",
	"Walrus": "bear_like",

	# === Beast — swine_like (barrel body, flat-disk snout) ==========
	"Pig": "swine_like",
	"Dire Boar": "swine_like",
	"Wild Boar": "swine_like",
	"Hog": "swine_like",
	"Warthog": "swine_like",
	# Cattle/oxen aren't really pigs, but they're close enough to a
	# barrel-bodied hooved quadruped that swine_like reads better than
	# the bear shape until a proper bovine_like builder exists.
	"Cow": "swine_like",
	"Ox": "swine_like",
	"Aurochs": "aurochs",
	"Yak": "swine_like",
	"Hippopotamus": "swine_like",
	"Mammoth": "swine_like",      # placeholder — needs pachyderm_like
	"Rhinoceros": "swine_like",   # placeholder — needs pachyderm_like
	"Elephant": "swine_like",     # placeholder — needs pachyderm_like

	# === Beast — small_animal (tiny quadruped, low body) ===========
	"House Cat": "small_animal",
	"Rat": "small_animal",
	"Giant Rat": "small_animal",
	"Weasel": "small_animal",
	"Giant Weasel": "small_animal",
	"Badger": "small_animal",
	"Dire Badger": "small_animal",
	"Beaver": "small_animal",
	"Otter": "small_animal",
	"Rabbit": "small_animal",
	"Hare": "small_animal",
	"Squirrel": "small_animal",
	"Monkey": "small_animal",
	"Baboon": "small_animal",
	"Skunk": "small_animal",

	# === Beast — dinosaur_like (bipedal, long tail) ================
	"Tyrannosaurus": "dinosaur_like",
	"Velociraptor": "dinosaur_like",
	"Deinonychus": "dinosaur_like",
	"Axe Beak": "axe_beak",
	"Diatryma": "dinosaur_like",

	# === Beast — lizard_like (low-slung quadruped, long tail) ======
	"Crocodile": "lizard_like",
	"Giant Crocodile": "lizard_like",
	"Lizard": "lizard_like",
	"Giant Lizard": "lizard_like",
	"Stegosaurus": "lizard_like",
	"Triceratops": "lizard_like",
	"Dimetrodon": "lizard_like",
	"Brontosaurus": "lizard_like",
	"Hadrosaurus": "lizard_like",
	"Plesiosaurus": "lizard_like",

	# === Beast — bird_like (biped with wings) ======================
	"Hawk": "bird_like",
	"Eagle": "bird_like",
	"Giant Eagle": "bird_like",
	"Falcon": "bird_like",
	"Vulture": "bird_like",
	"Giant Vulture": "bird_like",
	"Owl": "bird_like",
	"Giant Owl": "bird_like",
	"Chicken": "bird_like",
	"Raven": "bird_like",
	"Giant Raven": "bird_like",
	"Goose": "bird_like",
	"Peacock": "bird_like",
	"Pteranodon": "bird_like",
	"Quetzalcoatlus": "bird_like",

	# === Beast — serpent_like (long, legless or vestigial) =========
	"Snake": "serpent_like",
	"Constrictor Snake": "serpent_like",
	"Giant Constrictor Snake": "serpent_like",
	"Flying Snake": "serpent_like",
	"Venomous Snake": "serpent_like",
	"Giant Venomous Snake": "serpent_like",
	"Sandworm": "serpent_like",
	"Earthworm": "serpent_like",
	"Fireworm": "serpent_like",
	"Iceworm": "serpent_like",
	"Fire Snake": "serpent_like",
	"Thoqqua": "serpent_like",

	# === Beast — insect_like (many legs, segmented) ================
	"Spider": "insect_like",
	"Giant Spider": "insect_like",
	"Giant Wolf Spider": "insect_like",
	"Ice Spider": "insect_like",
	"Centipede": "insect_like",
	"Monstrous Centipede": "insect_like",
	"Scorpion": "insect_like",
	"Monstrous Scorpion": "insect_like",
	"Giant Crab": "insect_like",
	"Crab": "insect_like",
	"Stirge": "insect_like",
	"Phase Spider": "insect_like",

	# === Beast — sheep-like / herbivore =========================
	"Goat": "small_quadruped",
	"Mountain Goat": "small_quadruped",
	"Giant Goat": "bear_like",
	"Sheep": "small_quadruped",
	"Deer": "wolf_like",
	"Elk": "wolf_like",
	"Giant Elk": "bear_like",
	"Moose": "bear_like",
	"Reindeer": "wolf_like",

	# === Humanoid sub-templates =====================================
	"Goblin": "small_humanoid",
	"Goblin Boss": "small_humanoid",
	"Kobold": "small_humanoid",
	"Kobold Dragonshield": "small_humanoid",
	"Bugbear Chief": "brute_humanoid",
	"Orc": "brute_humanoid",
	"Orc War Chief": "brute_humanoid",
	"Orc Eye of Gruumsh": "brute_humanoid",
	"Gnoll": "brute_humanoid",
	"Gnoll Pack Lord": "brute_humanoid",
	"Hobgoblin": "warrior_humanoid",
	"Hobgoblin Captain": "warrior_humanoid",
	"Hobgoblin Warlord": "warrior_humanoid",
	"Knight": "warrior_humanoid",
	"Veteran": "warrior_humanoid",
	"Gladiator": "warrior_humanoid",
	"Mage": "caster_humanoid",
	"Priest": "caster_humanoid",
	"Cultist": "caster_humanoid",
	"Bandit": "warrior_humanoid",
	"Bandit Captain": "warrior_humanoid",
	"Scout": "warrior_humanoid",
	"Spy": "small_humanoid",
	"Thug": "brute_humanoid",
	"Ranger": "warrior_humanoid",
	"Assassin": "small_humanoid",
	"Lizardfolk": "brute_humanoid",
	"Lizardfolk King": "brute_humanoid",
	"Drow": "warrior_humanoid",
	"Drow Elite Warrior": "warrior_humanoid",
	"Drow Mage": "caster_humanoid",
	"Farmer": "small_humanoid",
	"Merfolk": "small_humanoid",
	"Troglodyte": "brute_humanoid",
	"Bullywug": "brute_humanoid",
	"Kenku": "bird_like_humanoid",
	"Yuan-ti Pureblood": "caster_humanoid",
	"Yuan-ti Malison": "caster_humanoid",
	"Yuan-ti Abomination": "serpent_humanoid",

	# === Undead sub-templates =======================================
	"Skeleton": "skeleton",
	"Warhorse Skeleton": "skeleton",
	"Minotaur Skeleton": "skeleton",
	"Zombie": "zombie",
	"Ogre Zombie": "zombie",
	"Ghoul": "ghoul_crouch",
	"Ghast": "ghoul_crouch",
	"Crawling Claw": "tiny_undead",
	"Wraith": "wraith_floating",
	"Specter": "wraith_floating",
	"Shadow": "wraith_floating",
	"Will-o'-Wisp": "tiny_floating",
	"Vampire": "warrior_humanoid",
	"Vampire Spawn": "warrior_humanoid",
	"Lich": "caster_humanoid",
	"Mummy": "zombie",
	"Mummy Lord": "warrior_humanoid",
	"Death Knight": "warrior_humanoid",

	# === Dragon sub-templates =======================================
	"Pseudodragon": "wyrmling",
	"Faerie Dragon": "wyrmling",
	"Guard Drake": "young_dragon",
	"Wyvern": "wyvern",

	# === Fey sub-templates ==========================================
	"Pixie": "tiny_fey",
	"Sprite": "tiny_fey",
	"Satyr": "satyr_humanoid",
	"Dryad": "plant_humanoid",
	"Sea Hag": "caster_humanoid",
	"Green Hag": "caster_humanoid",
	"Night Hag": "caster_humanoid",

	# === Fiend sub-templates ========================================
	"Imp": "tiny_winged_fiend",
	"Quasit": "tiny_fiend",
	"Lemure": "blob_fiend",
	"Dretch": "small_fiend",
	"Manes": "small_fiend",
	"Bearded Devil": "brute_humanoid",
	"Spined Devil": "tiny_winged_fiend",
	"Hell Hound": "wolf_like",
	"Pit Fiend": "winged_huge",
	"Marilith": "serpent_humanoid",

	# === Construct sub-templates ====================================
	"Scarecrow": "small_humanoid",
	"Flying Sword": "tiny_floating",
	"Homunculus": "tiny_winged_fiend",
	"Iron Golem": "golem_large",
	"Stone Golem": "golem_large",
	"Clay Golem": "golem_large",
	"Flesh Golem": "golem_large",
	"Shield Guardian": "golem_large",

	# === Elemental sub-templates ====================================
	"Fire Elemental": "elemental_humanoid",
	"Water Elemental": "elemental_humanoid",
	"Earth Elemental": "elemental_humanoid",
	"Air Elemental": "air_elemental",
	"Magmin": "small_humanoid",
	"Mephit": "tiny_winged_fiend",
	"Dust Mephit": "tiny_winged_fiend",
	"Ice Mephit": "tiny_winged_fiend",
	"Magma Mephit": "tiny_winged_fiend",
	"Steam Mephit": "tiny_winged_fiend",
	"Djinni": "elemental_humanoid",
	"Efreeti": "elemental_humanoid",
	"Azer": "azer",
	"Babau": "babau",
	"Balor": "balor",
	"Banshee": "banshee",
	"Barbed Devil": "barbed_devil",
	"Barghest": "barghest",
	"Basilisk": "basilisk",
	"Bat": "bat",
	"Giant Bat": "bat",
	"Behir": "behir",
	"Berserker": "berserker",
	"Black Bear": "black_bear",
	"Black Dragon Wyrmling": "black_dragon_wyrmling",
	"Young Black Dragon": "black_dragon_wyrmling",
	"Black Dragon": "black_dragon_wyrmling",
	"Adult Black Dragon": "black_dragon_wyrmling",
	"Black Pudding": "black_pudding",
	"Blink Dog": "blink_dog",
	"Blood Hawk": "blood_hawk",
	"Blue Dragon Wyrmling": "blue_dragon_wyrmling",
	"Young Blue Dragon": "blue_dragon_wyrmling",
	"Blue Dragon": "blue_dragon_wyrmling",
	"Adult Blue Dragon": "blue_dragon_wyrmling",
	"Boar": "boar",
	"Giant Boar": "boar",
	"Bone Devil": "bone_devil",
	"Brass Dragon Wyrmling": "brass_dragon_wyrmling",
	"Young Brass Dragon": "brass_dragon_wyrmling",
	"Brass Dragon": "brass_dragon_wyrmling",
	"Adult Brass Dragon": "brass_dragon_wyrmling",
	"Bronze Dragon Wyrmling": "bronze_dragon_wyrmling",
	"Young Bronze Dragon": "bronze_dragon_wyrmling",
	"Bronze Dragon": "bronze_dragon_wyrmling",
	"Adult Bronze Dragon": "bronze_dragon_wyrmling",
	"Brown Bear": "brown_bear",
	"Grizzly Bear": "brown_bear",
	"Bugbear": "bugbear",
	"Bulette": "bulette",
	"Cambion": "cambion",
	"Camel": "camel",
	"Carrion Crawler": "carrion_crawler",
	"Cat": "cat",
	"Centaur": "centaur",
	"Chain Devil": "chain_devil",
	"Kyton": "chain_devil",
	"Chimera": "chimera",
	"Chuul": "chuul",
	"Cockatrice": "cockatrice",

	# === Aberration sub-templates ===================================
	"Beholder": "floating_eye",
	"Gazer": "floating_eye",
	"Spectator": "floating_eye",
	"Mind Flayer": "tentacled_humanoid",
	"Aboleth": "aboleth",
	"Nothic": "tentacled_humanoid",
	"Otyugh": "tentacled_blob",
	"Roper": "tentacled_blob",
	"Cloaker": "wraith_floating",
	"Grell": "tentacled_blob",

	# === Ooze sub-templates =========================================
	"Gelatinous Cube": "cube_ooze",
	"Gray Ooze": "blob",
	"Ochre Jelly": "blob",
	"Oblex Spawn": "blob",
	"Adult Oblex": "adult_oblex",

	# === Plant sub-templates ========================================
	"Mushroom": "mushroom_cap",
	"Shrieker": "mushroom_cap",
	"Myconid Sprout": "mushroom_cap",
	"Myconid Adult": "mushroom_cap",
	"Myconid Sovereign": "mushroom_cap",
	"Treant": "treant",
	"Awakened Tree": "treant",
	"Awakened Shrub": "mushroom_cap",
	"Vine Blight": "plant_humanoid",
	"Twig Blight": "plant_humanoid",
	"Needle Blight": "plant_humanoid",
	"Violet Fungus": "mushroom_cap",
	"Vegepygmy": "small_humanoid",

	# === A-list per-species overrides ==============================
	"Abominable Yeti": "abominable_yeti",
	"Air Elemental Myrmidon": "air_elemental_myrmidon",
	"Alioramus": "alioramus",
	"Allip": "allip",
	"Allosaurus": "allosaurus",
	"Ambush Drake": "ambush_drake",
	"Androsphinx": "androsphinx",
	"Angel": "angel",
	"Animal Lord": "animal_lord",
	"Angler Fish": "angler_fish",
	"Animated Armor": "animated_armor",
	"Ankheg": "ankheg",
	"Ankylosaurus": "ankylosaurus",
	"Annis Hag": "annis_hag",
	"Ape": "ape",
	"Arcanaloth": "arcanaloth",
	"Archmage": "archmage",
	"Arctic Blindfish": "arctic_blindfish",
	"Arctic Char": "arctic_char",
	"Arctic Goby": "arctic_goby",
	"Arctic Skate": "arctic_skate",
	"Arctic Stink Squirrel": "arctic_stink_squirrel",
}

# ============================================================================
# Sub-template defaults per category
# ============================================================================
##
## When no hint exists for a species AND stat heuristic doesn't conclude,
## fall back to this category-default.

const CATEGORY_DEFAULTS: Dictionary = {
	"Beast":       "wolf_like",
	"Humanoid":    "warrior_humanoid",
	"Dragon":      "young_dragon",
	"Undead":      "zombie",
	"Ooze":        "blob",
	"Aberration":  "tentacled_humanoid",
	"Fey":         "warrior_humanoid",
	"Fiend":       "brute_humanoid",
	"Giant":       "warrior_humanoid",
	"Elemental":   "elemental_humanoid",
	"Celestial":   "warrior_humanoid",
	"Monstrosity": "wolf_like",
	"Construct":   "warrior_humanoid",
	"Plant":       "mushroom_cap",
}

# ============================================================================
# Size class derivation — from HP if no explicit override
# ============================================================================

enum SizeClass { TINY, SMALL, MEDIUM, LARGE, HUGE, GARGANTUAN }

const SIZE_SCALES: Dictionary = {
	SizeClass.TINY:       0.45,
	SizeClass.SMALL:      0.75,
	SizeClass.MEDIUM:     1.00,
	SizeClass.LARGE:      1.55,
	SizeClass.HUGE:       2.30,
	SizeClass.GARGANTUAN: 3.40,
}

## Derive size class from creature stat block.
## HP-driven mostly, with damage_amount as a secondary signal for huge boss
## creatures that have somehow-low HP (Tarrasque-style).
static func size_class_for(defaults: Dictionary) -> int:
	# Honor explicit override first.
	var explicit: Variant = defaults.get("size_class", null)
	if explicit is int:
		return clampi(int(explicit), 0, 5)
	if explicit is String:
		match (explicit as String).to_lower():
			"tiny": return SizeClass.TINY
			"small": return SizeClass.SMALL
			"medium": return SizeClass.MEDIUM
			"large": return SizeClass.LARGE
			"huge": return SizeClass.HUGE
			"gargantuan": return SizeClass.GARGANTUAN
	# HP-based fallback.
	var hp: float = float(defaults.get("max_health", 10))
	if hp < 5.0:       return SizeClass.TINY
	if hp < 16.0:      return SizeClass.SMALL
	if hp < 50.0:      return SizeClass.MEDIUM
	if hp < 150.0:     return SizeClass.LARGE
	if hp < 300.0:     return SizeClass.HUGE
	return SizeClass.GARGANTUAN

## Returns the world-space scale multiplier for the size class.
static func size_scale(size_class: int) -> float:
	return float(SIZE_SCALES.get(size_class, 1.0))

# ============================================================================
# Sub-template resolution
# ============================================================================

## Resolve the sub-template for a creature. Priority:
##   1. Explicit hint in SUB_TEMPLATE_HINTS
##   2. Stat-profile heuristic per category
##   3. CATEGORY_DEFAULTS fallback
static func sub_template_for(species: String, category: String, defaults: Dictionary) -> String:
	# 1. Explicit hint.
	if SUB_TEMPLATE_HINTS.has(species):
		return String(SUB_TEMPLATE_HINTS[species])
	# 2. Stat-profile heuristic (per category).
	var heuristic: String = _heuristic_for(category, defaults)
	if not heuristic.is_empty():
		return heuristic
	# 3. Category default.
	return String(CATEGORY_DEFAULTS.get(category, "warrior_humanoid"))

## Stat-profile heuristic — guesses sub-template from ability scores when no
## explicit hint exists.
static func _heuristic_for(category: String, defaults: Dictionary) -> String:
	var str_mod: float = float(defaults.get("strength", 0.0))
	var dex_mod: float = float(defaults.get("dexterity", 0.0))
	var con_mod: float = float(defaults.get("constitution", 0.0))
	var hp: float = float(defaults.get("max_health", 10))
	match category:
		"Beast":
			# Tiny stat = small_animal. Bulky = bear. Fast = wolf.
			if hp < 6.0:
				return "small_animal"
			if con_mod >= 2.0 and str_mod >= 2.0:
				return "bear_like"
			if dex_mod >= 2.0:
				return "wolf_like"
			return ""  # let caller fall through to default
		"Humanoid":
			if hp < 8.0:
				return "small_humanoid"
			if str_mod >= 3.0 and dex_mod < 1.0:
				return "brute_humanoid"
			if str_mod < 0.0 and dex_mod >= 2.0:
				return "small_humanoid"
			return "warrior_humanoid"
		"Dragon":
			if hp < 30.0:
				return "wyrmling"
			if hp < 120.0:
				return "young_dragon"
			if hp < 250.0:
				return "adult_dragon"
			return "ancient_dragon"
		"Undead":
			if hp < 5.0:
				return "tiny_undead"
			if dex_mod >= 2.0 and con_mod < 0.0:
				return "wraith_floating"
			if con_mod >= 2.0:
				return "zombie"
			return ""
		"Fiend":
			if hp < 12.0:
				return "tiny_fiend"
			if str_mod >= 4.0:
				return "winged_huge"
			return ""
		"Giant":
			# Giants are always brute-style. Size class handles scale.
			return "brute_humanoid"
		_:
			return ""

# ============================================================================
# Species signature — deterministic per-name RNG
# ============================================================================

## Hash a species name into a stable 32-bit seed. Same name in, same seed out,
## across game launches and platforms. Used to seed per-species RNG so that
## Wolves always look like Wolves (within instance jitter from render_seed).
static func species_seed(species: String) -> int:
	return _fnv1a_32(species)

## Returns a RandomNumberGenerator seeded from the species name. Use this to
## roll species-stable values like ornament tag selection, palette hue,
## proportion biases.
static func species_rng(species: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = species_seed(species)
	return rng

## FNV-1a 32-bit hash. Simple, well-distributed, no dependencies.
## Returns a positive int in [0, 2^31).
static func _fnv1a_32(text: String) -> int:
	var h: int = 2166136261  # FNV offset basis
	for byte in text.to_utf8_buffer():
		h = (h ^ int(byte)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	# Squeeze to positive 31-bit so it's safe to use as a seed everywhere.
	return h & 0x7FFFFFFF
