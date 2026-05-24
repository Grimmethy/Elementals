class_name ActorTypeData
extends Resource

## Central registry of actor default stats, equipment pools, and category mappings.
## Stat values use modifier notation: 0.0 = baseline, positive = bonus, negative = penalty.
## Data is split into per-category files under ActorTypes/ and merged on first access.

const _AberrationData  = preload("res://Components/ActorComponents/ActorTypes/AberrationData.gd")
const _BeastData       = preload("res://Components/ActorComponents/ActorTypes/BeastData.gd")
const _CelestialData   = preload("res://Components/ActorComponents/ActorTypes/CelestialData.gd")
const _ConstructData   = preload("res://Components/ActorComponents/ActorTypes/ConstructData.gd")
const _DragonData      = preload("res://Components/ActorComponents/ActorTypes/DragonData.gd")
const _ElementalData   = preload("res://Components/ActorComponents/ActorTypes/ElementalData.gd")
const _GiantData       = preload("res://Components/ActorComponents/ActorTypes/GiantData.gd")
const _HumanoidData    = preload("res://Components/ActorComponents/ActorTypes/HumanoidData.gd")
const _MonstrosityData = preload("res://Components/ActorComponents/ActorTypes/MonstrosityData.gd")
const _PlantData       = preload("res://Components/ActorComponents/ActorTypes/PlantData.gd")
const _UndeadData      = preload("res://Components/ActorComponents/ActorTypes/UndeadData.gd")

static var _types: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_types.merge(_AberrationData.DATA)
	_types.merge(_BeastData.DATA)
	_types.merge(_CelestialData.DATA)
	_types.merge(_ConstructData.DATA)
	_types.merge(_DragonData.DATA)
	_types.merge(_ElementalData.DATA)
	_types.merge(_GiantData.DATA)
	_types.merge(_HumanoidData.DATA)
	_types.merge(_MonstrosityData.DATA)
	_types.merge(_PlantData.DATA)
	_types.merge(_UndeadData.DATA)
	_initialized = true


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
	"Construct":   [
		"Living Unseen Servant", "Homunculus",
		"Metallic Warbler", "Monodrone", "Flying Sword", "Duodrone",
		"Skull Flier", "Tridrone",
		"Animated Armor", "Carrionette", "Fiendish Icon", "Guardian Portrait",
		"Hypnos Magen", "Quadrone", "Scarecrow", "Stone Cursed",
		"Clockwork Horror", "Demos Magen", "Pentadrone", "Rug of Smothering", "Stained Glass Golem",
		"Galvan Magen", "Snow Golem",
		"Helmed Horror", "Iron Cobra", "Living Bigby's Hand", "Metallic Peacekeeper", "Nimblewright", "Stone Defender",
		"Flesh Golem", "Gorgon",
		"Shield Guardian",
		"Clay Golem",
		"Crystal Golem", "Stone Golem", "Tomb Tapper",
		"Chardalyn Dragon", "Dragonbone Golem", "Octon",
		"Septon", "Stone Juggernaut",
		"Canopic Golem", "Hexton", "Kolyarut",
		"Cadaver Collector", "Retriever",
		"Decaton", "Fiendish Flesh Golem", "Hellfire Engine", "Iron Golem", "Nonaton", "Scaladar", "Steel Predator",
		"Walking Statue of Waterdeep",
		"Marut", "Stone Colossus",
	],
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
	_ensure_init()
	return _types.get(actor_type, {})

static func get_all_types() -> Array[String]:
	_ensure_init()
	var result: Array[String] = []
	for key in _types.keys():
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
