class_name ActorTypeData
extends Resource

## Central registry of actor default stats, equipment pools, and category mappings.
## Stat values use modifier notation: 0.0 = baseline, positive = bonus, negative = penalty.
## See Markdowns/Reference/ActorTypeData.md for the full spec and migration path.

const ACTOR_TYPES: Dictionary = {
	# ── Aberration ──────────────────────────────────────────────────────────
	
	# ── Beast ────────────────────────────────────────────────────────────────

	# ── Celestial ───────────────────────────────────────────────────────────

	# ── Construct ────────────────────────────────────────────────────────────
	"Scarecrow": {
		"max_health": 36, "armor_class": 11, "damage_amount": 2.0, "element_type": "none",
		"strength": 1.0, "dexterity": 1.0, "constitution": 0.0, "intelligence": -3.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 45,
		"weapons": ["Claw", "Slam"],
		"abilities": ["Horrifying Visage", "Scare"],
		"armor": ["Natural Armor"],
	},
	# ── Dragon ───────────────────────────────────────────────────────────────
	"Fire Dragon": {
		"max_health": 256, "armor_class": 19, "damage_amount": 6.0, "element_type": "fire",
		"strength": 9.0, "dexterity": 0.0, "constitution": 5.0, "intelligence": 4.0, "wisdom": 1.0, "charisma": 4.0,
		"gold_value": 600,
		"weapons": ["Claw", "Bite", "Tail Swipe"],
		"abilities": ["Fire Breath", "Fly", "Roar"],
		"armor": ["Dragon Scales"],
	},
	"Ice Dragon": {
		"max_health": 225, "armor_class": 18, "damage_amount": 5.5, "element_type": "ice",
		"strength": 8.0, "dexterity": 0.0, "constitution": 4.0, "intelligence": 4.0, "wisdom": 1.0, "charisma": 3.0,
		"gold_value": 580,
		"weapons": ["Claw", "Bite", "Tail Swipe"],
		"abilities": ["Frost Breath", "Fly", "Roar"],
		"armor": ["Dragon Scales"],
	},
	"Storm Dragon": {
		"max_health": 243, "armor_class": 19, "damage_amount": 6.0, "element_type": "storm",
		"strength": 8.0, "dexterity": 1.0, "constitution": 5.0, "intelligence": 4.0, "wisdom": 2.0, "charisma": 4.0,
		"gold_value": 620,
		"weapons": ["Claw", "Bite", "Tail Swipe"],
		"abilities": ["Lightning Breath", "Fly", "Roar"],
		"armor": ["Dragon Scales"],
	},
	"Shadow Dragon": {
		"max_health": 189, "armor_class": 19, "damage_amount": 5.0, "element_type": "shadow",
		"strength": 7.0, "dexterity": 2.0, "constitution": 4.0, "intelligence": 4.0, "wisdom": 1.0, "charisma": 5.0,
		"gold_value": 650,
		"weapons": ["Claw", "Bite", "Tail Swipe"],
		"abilities": ["Shadow Breath", "Fly", "Living Shadow"],
		"armor": ["Dragon Scales"],
	},
	# ── Elemental ────────────────────────────────────────────────────────────
	"Fireworm": {
		"max_health": 22, "armor_class": 12, "damage_amount": 2.5, "element_type": "fire",
		"strength": 1.0, "dexterity": 0.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 55,
		"weapons": ["Flame Bite", "Constrict"],
		"abilities": ["Fire Spit", "Burrow"],
		"armor": ["Fire Scales"],
	},
	"Iceworm": {
		"max_health": 22, "armor_class": 12, "damage_amount": 2.5, "element_type": "ice",
		"strength": 1.0, "dexterity": 0.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 55,
		"weapons": ["Frost Bite", "Constrict"],
		"abilities": ["Freeze Spit", "Burrow"],
		"armor": ["Ice Scales"],
	},
	# ── Giant ─────────────────────────────────────────────────────────────────
	"Ogre": {
		"max_health": 59, "armor_class": 11, "damage_amount": 4.0, "element_type": "none",
		"strength": 5.0, "dexterity": -1.0, "constitution": 3.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 90,
		"weapons": ["Greatclub", "Javelin"],
		"abilities": ["Siege Monster"],
		"armor": ["Natural Armor"],
	},
	"Troll": {
		"max_health": 84, "armor_class": 15, "damage_amount": 3.5, "element_type": "none",
		"strength": 4.0, "dexterity": 1.0, "constitution": 5.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -4.0,
		"gold_value": 130,
		"weapons": ["Claw", "Bite"],
		"abilities": ["Regeneration", "Keen Smell"],
		"armor": ["Natural Armor"],
	},
	# ── Humanoid ─────────────────────────────────────────────────────────────
	"Farmer": {
		"max_health": 8, "armor_class": 10, "damage_amount": 1.0, "element_type": "none",
		"strength": 0.0, "dexterity": 0.0, "constitution": 0.0, "intelligence": 0.0, "wisdom": 0.0, "charisma": 0.0,
		"gold_value": 15,
		"weapons": ["Pitchfork", "Scythe"],
		"abilities": ["Hard Work"],
		"armor": ["Cloth"],
	},
	"Knight": {
		"max_health": 52, "armor_class": 18, "damage_amount": 3.0, "element_type": "none",
		"strength": 3.0, "dexterity": 0.0, "constitution": 2.0, "intelligence": 0.0, "wisdom": 0.0, "charisma": 1.0,
		"gold_value": 120,
		"weapons": ["Longsword", "Lance"],
		"abilities": ["Parry", "Rally"],
		"armor": ["Plate", "Shield"],
	},
	"Mage": {
		"max_health": 18, "armor_class": 12, "damage_amount": 4.0, "element_type": "none",
		"strength": -1.0, "dexterity": 2.0, "constitution": 0.0, "intelligence": 5.0, "wisdom": 1.0, "charisma": 0.0,
		"gold_value": 100,
		"weapons": ["Staff", "Dagger"],
		"abilities": ["Fireball", "Shield", "Magic Missile"],
		"armor": ["Robes"],
	},
	"Ranger": {
		"max_health": 33, "armor_class": 15, "damage_amount": 2.5, "element_type": "none",
		"strength": 1.0, "dexterity": 3.0, "constitution": 1.0, "intelligence": 0.0, "wisdom": 1.0, "charisma": 0.0,
		"gold_value": 80,
		"weapons": ["Longbow", "Shortsword"],
		"abilities": ["Hunter's Mark", "Favored Enemy"],
		"armor": ["Leather", "Scale Mail"],
	},
	"Goblin": {
		"max_health": 7, "armor_class": 15, "damage_amount": 1.5, "element_type": "none",
		"strength": -1.0, "dexterity": 2.5, "constitution": 0.0, "intelligence": 0.0, "wisdom": -1.0, "charisma": -1.0,
		"gold_value": 65,
		"weapons": ["Scimitar", "Shortbow"],
		"abilities": ["Nimble Escape"],
		"armor": ["Leather", "Shield"],
		"should_bob": false,
		"fixed_move_speed": 3.0,
		"ai_behaviors": ["nimble_escape"],
		"nimble_escape_disengage_range": 4.0,
		"nimble_escape_hide_range": 8.0,
		"faction": "GOBLINS",
		"hp_dice_count": 2,
		"hp_dice_sides": 6,
		"armor_pool": ["none", "leather", "chain shirt"],
		"weapon_pool": ["Dagger", "Scimitar", "Shortbow"],
		"ability_pool": ["nimble_escape", "redirect_attack"],
		"ammo_dice_count": 2,
		"ammo_dice_sides": 10,
	},
	"Kobold": {
		"max_health": 5, "armor_class": 12, "damage_amount": 1.0, "element_type": "none",
		"strength": -3.0, "dexterity": 2.0, "constitution": -1.0, "intelligence": -1.0, "wisdom": -2.0, "charisma": -2.0,
		"gold_value": 25,
		"weapons": ["Dagger", "Sling"],
		"abilities": ["Pack Tactics", "Sunlight Sensitivity"],
		"armor": ["Leather"],
	},
	"Orc": {
		"max_health": 15, "armor_class": 13, "damage_amount": 2.5, "element_type": "none",
		"strength": 3.0, "dexterity": 1.0, "constitution": 3.0, "intelligence": -2.0, "wisdom": -1.0, "charisma": -1.0,
		"gold_value": 55,
		"weapons": ["Greataxe", "Javelin"],
		"abilities": ["Aggressive", "Relentless"],
		"armor": ["Hide", "Shield"],
	},
	"Gnoll": {
		"max_health": 22, "armor_class": 15, "damage_amount": 2.0, "element_type": "none",
		"strength": 2.0, "dexterity": 1.0, "constitution": 0.0, "intelligence": -2.0, "wisdom": 0.0, "charisma": -2.0,
		"gold_value": 50,
		"weapons": ["Bite", "Spear"],
		"abilities": ["Rampage"],
		"armor": ["Hide", "Shield"],
	},
	"Bugbear": {
		"max_health": 27, "armor_class": 16, "damage_amount": 3.0, "element_type": "none",
		"strength": 3.0, "dexterity": 2.0, "constitution": 1.0, "intelligence": -1.0, "wisdom": 0.0, "charisma": -1.0,
		"gold_value": 70,
		"weapons": ["Morningstar", "Javelin"],
		"abilities": ["Brute", "Surprise Attack"],
		"armor": ["Hide", "Shield"],
	},
	# ── Monstrosity ──────────────────────────────────────────────────────────
	"Mimic": {
		"max_health": 58, "armor_class": 12, "damage_amount": 3.0, "element_type": "none",
		"strength": 3.0, "dexterity": 1.0, "constitution": 2.0, "intelligence": -3.0, "wisdom": 1.0, "charisma": -1.0,
		"gold_value": 80,
		"weapons": ["Pseudopod", "Bite"],
		"abilities": ["False Appearance", "Adhesive"],
		"armor": ["Natural Armor"],
	},
	"Minotaur": {
		"max_health": 76, "armor_class": 14, "damage_amount": 4.0, "element_type": "none",
		"strength": 5.0, "dexterity": 0.0, "constitution": 3.0, "intelligence": -3.0, "wisdom": 0.0, "charisma": -2.0,
		"gold_value": 120,
		"weapons": ["Greataxe", "Gore"],
		"abilities": ["Charge", "Labyrinthine Recall"],
		"armor": ["Natural Armor"],
	},
	"Basilisk": {
		"max_health": 52, "armor_class": 15, "damage_amount": 2.5, "element_type": "none",
		"strength": 2.0, "dexterity": -1.0, "constitution": 3.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 100,
		"weapons": ["Bite"],
		"abilities": ["Petrifying Gaze"],
		"armor": ["Natural Armor"],
	},
	"Medusa": {
		"max_health": 127, "armor_class": 15, "damage_amount": 3.0, "element_type": "none",
		"strength": 0.0, "dexterity": 2.0, "constitution": 3.0, "intelligence": 2.0, "wisdom": -1.0, "charisma": 1.0,
		"gold_value": 200,
		"weapons": ["Shortsword", "Longbow"],
		"abilities": ["Petrifying Gaze", "Snake Hair"],
		"armor": ["Natural Armor"],
	},
	"Werewolf": {
		"max_health": 58, "armor_class": 12, "damage_amount": 2.5, "element_type": "none",
		"strength": 3.0, "dexterity": 1.0, "constitution": 2.0, "intelligence": 0.0, "wisdom": 1.0, "charisma": 0.0,
		"gold_value": 110,
		"weapons": ["Claw", "Bite"],
		"abilities": ["Lycanthropy", "Pack Tactics"],
		"armor": ["Natural Armor"],
	},
	"Sandworm": {
		"max_health": 247, "armor_class": 18, "damage_amount": 6.0, "element_type": "none",
		"strength": 8.0, "dexterity": -1.0, "constitution": 5.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 400,
		"weapons": ["Bite", "Swallow"],
		"abilities": ["Tunneler", "Tremorsense"],
		"armor": ["Hardened Hide"],
	},
	# ── Plant ─────────────────────────────────────────────────────────────────
	"Mushroom": {
		"max_health": 15, "armor_class": 10, "damage_amount": 1.0, "element_type": "none",
		"strength": 1.0, "dexterity": -1.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": 0.0, "charisma": -3.0,
		"gold_value": 35,
		"weapons": ["Spore Burst", "Root Slam"],
		"abilities": ["Poison Spores", "Regrowth"],
		"armor": ["Natural Armor"],
	},
	# ── Undead ────────────────────────────────────────────────────────────────
	"Skeleton": {
		"max_health": 13, "armor_class": 13, "damage_amount": 1.5, "element_type": "none",
		"strength": 0.0, "dexterity": 2.0, "constitution": -1.0, "intelligence": -4.0, "wisdom": -2.0, "charisma": -3.0,
		"gold_value": 30,
		"weapons": ["Shortsword", "Shortbow"],
		"abilities": ["Undead Fortitude"],
		"armor": ["Armor Scraps"],
	},
	"Zombie": {
		"max_health": 22, "armor_class": 8, "damage_amount": 2.0, "element_type": "none",
		"strength": 1.0, "dexterity": -2.0, "constitution": 3.0, "intelligence": -5.0, "wisdom": -4.0, "charisma": -4.0,
		"gold_value": 25,
		"weapons": ["Slam"],
		"abilities": ["Undead Fortitude"],
		"armor": ["Tattered Cloth"],
	},
	"Ghoul": {
		"max_health": 22, "armor_class": 12, "damage_amount": 2.0, "element_type": "none",
		"strength": 1.0, "dexterity": 2.0, "constitution": 0.0, "intelligence": -2.0, "wisdom": 0.0, "charisma": -3.0,
		"gold_value": 60,
		"weapons": ["Claws", "Bite"],
		"abilities": ["Paralyzing Touch", "Undead Fortitude"],
		"armor": ["Natural Armor"],
	},
}

const CATEGORY_MAP: Dictionary = {
	"Aberration":  [
		"Beholder", "Aboleth", "Balhannoth", "Berbalang", "Blue Slaad",
		"Chaos Quadrapod", "Choker", "Chuul", "Cloaker", "Darkweaver",
		"Death Kiss", "Death Slaad", "Derro", "Dolgrim", "Elder Brain",
		"Elder Brain Dragon", "Eye Monger", "Eye of Flame", "Eyedrake", "Feyr",
		"Flumph", "Gargantua", "Gauth", "Gazer", "Giant Intellect Devourer",
		"Gibbering Mouther", "Gith", "Githyanki", "Githzerai", "Gnome Ceremorph",
		"Gnome Squidling", "Gray Slaad", "Green Slaad", "Grell", "Grimlock",
		"Intellect Devourer", "Ixitxachitl", "Kuo-toa", "Living Web", "Mind Flayer",
		"Mind Flayer Clairvoyant", "Mindwitness", "Morkoth", "Mutate", "Neh-thalggu",
		"Neo-otyugh", "Neogi", "Neothelid", "Nothic", "Otyugh",
		"Phaerimm", "Psurlon", "Red Slaad", "Roper", "Skittering Horror",
		"Skum", "Slaad", "Spectator", "Star Spawn", "Star Spawn Hulk",
		"Star Spawn Mangler", "Star Spawn Seer", "Tsucora Quori", "Ulitharid", "Woe Strider",
	],
	"Beast":       [
		"Goat", "Chicken", "Cow", "Pig", "Sheep", "Wolf", "Earthworm",
		"Alioramus", "Allosaurus", "Almiraj", "Angler Fish", "Ankylosaurus", "Ape", "Giant Ape",
		"Archaeus", "Arctic Blindfish", "Arctic Char", "Arctic Fox", "Arctic Goby", "Arctic Skate",
		"Arctic Stink Squirrel", "Aurochs", "Axe Beak", "Baboon", "Badger", "Barnacle",
		"Barovian Nightcrawler", "Bat", "Giant Bat", "Bear", "Beaver", "Giant Fire Beetle",
		"Beholderfish", "Bestial Spirit", "Black Bear", "Blood Hawk", "Blue King Crab", "Boar",
		"Brontosaurus", "Brown Bear", "Camel", "Cave Bear", "Centipede", "Chionthar Dusthawk",
		"Chiton", "Giant Clam", "Coelacanth", "Combustion Belly Spiderling", "Common Trollslyer",
		"Cooshee", "Crab", "Giant Crab", "Cranium Rat", "Giant Crayfish", "Crocodile",
		"Giant Crocodile", "Deep Rothé", "Deepfathom Devilfish", "Deer", "Deinonychus", "Devilfish",
		"Diatryma", "Dimetrodon", "Dinosaur", "Dire Badger", "Dire Boar", "Dire Wolf", "Dolphin",
		"Dragon Goby", "Eagle", "Giant Eagle", "Elephant", "Elk", "Giant Elk", "Emperor Crab",
		"Enchodus", "Endoceras", "Falcon", "Fireshear Petrel", "Flailfish", "Giant Fly",
		"Flying Monkey", "Fox", "Giant Frog", "Frozenfar Flathead", "Frozenfar Quipper",
		"Frozenfar Steelhead", "Giant Constrictor Snake", "Giant Devilfish", "Giant Dragonfly",
		"Giant Eel", "Giant Flying Spider", "Giant Plaice", "Giant Snail", "Giant Venomous Snake",
		"Giant Wolf Spider", "Glacefish", "Giant Goat", "Goblin Shark", "Goose", "Gorgonocephalus",
		"Gorilla", "Gurry Shark", "Hadrosaurus", "Halibut", "Hare", "Hawk", "Horse", "House Cat",
		"Hyaenodon", "Hyena", "Ice Climber", "Ice Spider", "Icebound Whelk", "Icewind Eel",
		"Icewind Smelt", "Jackal", "Jaculi", "Killer Whale", "Krill", "Lancetfish", "Lantern Fish",
		"Leech", "Lion", "Lizard", "Giant Lizard", "Lovely Emperor Beetle", "Lugworm",
		"Mackerel Icefish", "Mammoth", "Mastiff", "Megalodon", "Monkfish", "Monstrous Centipede",
		"Monstrous Scorpion", "Moonglow Herring", "Moose", "Mountain Goat", "Mule", "Myrmidon",
		"Nautilus", "Nelma", "Ninespine Stickleback", "Northern Haddock", "Northern Pike",
		"Northern Seahorse", "Northern Squid", "Northern Whelk", "Octopus", "Giant Octopus",
		"Otter", "Owl", "Giant Owl", "Ox", "Panther", "Peacock", "Plesiosaurus", "Polar Bear",
		"Polar Oarfish", "Pteranodon", "Queen's Knife", "Quetzalcoatlus", "Quipper", "Rat",
		"Giant Rat", "Raven", "Giant Raven", "Razor Clam", "Reef Clam", "Reindeer", "Rhinoceros",
		"Rock Lobster", "Rot Grub", "Rothé", "Saber-toothed Tiger", "Scorpion", "Sea Deva",
		"Sea Gull", "Sea Nettle", "Seal", "Serpent Star", "Shaengarne Salmon", "Shark",
		"Silvertail Barracuda", "Skipjack Tuna", "Sleeper Shark", "Snake", "Constrictor Snake",
		"Flying Snake", "Giant Snapping Turtle", "Snow Leopard", "Snowbarb", "Sorcerer Shrimp",
		"Sorcery Crow", "Space Guppy", "Giant Space Hamster", "Sperm Whale", "Spider",
		"Giant Spider", "Spiny Dogfish", "Spotted Eelpout", "Spotted Lion", "Stegosaurus",
		"Stirge", "Sturgeon", "Surface Rothé", "Swordsea Hake", "Thayan Glassfish", "Tiger",
		"Titanothere", "Toad", "Giant Toad", "Torchlight Loosejaw", "Trackless Cod",
		"Trackless Sailfish", "Triceratops", "Trout", "Twohorn Sculpin", "Tyrannosaurus",
		"Valkur's Fish", "Velociraptor", "Venomous Snake", "Ventdiver", "Vulture", "Giant Vulture",
		"Walrus", "Giant Wasp", "Waxworm", "Weasel", "Giant Weasel", "Wolf Eel", "Wolffish",
		"Wooly Crab", "Yak", "Yeti Crab", "Zebra",
	],
	"Celestial":   [
		"Angel", "Animal Lord", "Arcane", "Aurumach", "Avoral", "Bariaur", "Celestial",
		"Cosmic Stag", "Couatl", "Cuprilach", "Dabus", "Deva", "Giant Eagle", "Giant Elk",
		"Empyrean", "Empyrean Iota", "Equinal", "Fensir", "Ferrumach", "Guardian Naga",
		"Hollyphant", "Hound Archon", "Ki-rin", "Kindori", "Lantern Archon", "Musteval",
		"Giant Owl", "Pegasus", "Petitioner", "Planetar", "Reigar", "Rilmani", "Solar",
		"Sphinx", "Sphinx of Wonder", "Unicorn", "Warden Archon",
	],
	"Construct":   ["Scarecrow"],
	"Dragon":      ["Fire Dragon", "Ice Dragon", "Storm Dragon", "Shadow Dragon"],
	"Elemental":   ["Fireworm", "Iceworm"],
	"Fey":         [],
	"Fiend":       [],
	"Giant":       ["Ogre", "Troll"],
	"Humanoid":    ["Farmer", "Knight", "Mage", "Ranger", "Goblin", "Kobold", "Orc", "Gnoll", "Bugbear"],
	"Monstrosity": ["Mimic", "Minotaur", "Basilisk", "Medusa", "Werewolf", "Sandworm"],
	"Ooze":        [],
	"Plant":       ["Mushroom"],
	"Undead":      ["Skeleton", "Zombie", "Ghoul"],
}


static func get_defaults(actor_type: String) -> Dictionary:
	return ACTOR_TYPES.get(actor_type, {})

static func get_all_types() -> Array[String]:
	var result: Array[String] = []
	for key in ACTOR_TYPES.keys():
		result.append(str(key))
	return result

static func get_category(actor_type: String) -> String:
	for category in CATEGORY_MAP:
		if actor_type in CATEGORY_MAP[category]:
			return category
	return "Unknown"

static func get_types_in_category(category: String) -> Array:
	return CATEGORY_MAP.get(category, [])

static func get_all_categories() -> Array[String]:
	var result: Array[String] = []
	for key in CATEGORY_MAP.keys():
		result.append(str(key))
	return result
