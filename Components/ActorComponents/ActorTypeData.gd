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
const _FeyData         = preload("res://Components/ActorComponents/ActorTypes/FeyData.gd")
const _FiendData       = preload("res://Components/ActorComponents/ActorTypes/FiendData.gd")
const _GiantData       = preload("res://Components/ActorComponents/ActorTypes/GiantData.gd")
const _HumanoidData    = preload("res://Components/ActorComponents/ActorTypes/HumanoidData.gd")
const _MonstrosityData = preload("res://Components/ActorComponents/ActorTypes/MonstrosityData.gd")
const _OozeData        = preload("res://Components/ActorComponents/ActorTypes/OozeData.gd")
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
	_types.merge(_FeyData.DATA)
	_types.merge(_FiendData.DATA)
	_types.merge(_GiantData.DATA)
	_types.merge(_HumanoidData.DATA)
	_types.merge(_MonstrosityData.DATA)
	_types.merge(_OozeData.DATA)
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
	"Dragon":      [
		"Fire Dragon", "Ice Dragon", "Storm Dragon", "Shadow Dragon",
		"Pseudodragon", "Faerie Dragon", "Ambush Drake", "Guard Drake", "Wyvern", "Jabberwock", "Dragon Turtle",
		"White Dragon Wyrmling", "Black Dragon Wyrmling", "Green Dragon Wyrmling", "Blue Dragon Wyrmling", "Red Dragon Wyrmling",
		"Brass Dragon Wyrmling", "Copper Dragon Wyrmling", "Bronze Dragon Wyrmling", "Silver Dragon Wyrmling", "Gold Dragon Wyrmling",
		"White Dragon Young", "Black Dragon Young", "Green Dragon Young", "Blue Dragon Young", "Red Dragon Young",
		"Brass Dragon Young", "Copper Dragon Young", "Bronze Dragon Young", "Silver Dragon Young", "Gold Dragon Young",
		"White Dragon Adult", "Black Dragon Adult", "Green Dragon Adult", "Blue Dragon Adult", "Red Dragon Adult",
		"Brass Dragon Adult", "Copper Dragon Adult", "Bronze Dragon Adult", "Silver Dragon Adult", "Gold Dragon Adult",
		"White Dragon Ancient", "Black Dragon Ancient", "Green Dragon Ancient", "Blue Dragon Ancient", "Red Dragon Ancient",
		"Brass Dragon Ancient", "Copper Dragon Ancient", "Bronze Dragon Ancient", "Silver Dragon Ancient", "Gold Dragon Ancient",
		"Tiamat",
	],
	"Elemental":   [
		"Fireworm", "Iceworm",
		"Dust Mephit", "Ice Mephit", "Magma Mephit", "Mud Mephit", "Smoke Mephit", "Steam Mephit", "Magmin",
		"Fire Snake", "Thoqqua",
		"Azer", "Gargoyle",
		"Water Weird",
		"Air Elemental", "Earth Elemental", "Fire Elemental", "Water Elemental", "Salamander", "Xorn",
		"Galeb Duhr", "Invisible Stalker",
		"Air Elemental Myrmidon", "Earth Elemental Myrmidon", "Fire Elemental Myrmidon", "Water Elemental Myrmidon",
		"Dao", "Djinni", "Efreeti", "Marid",
		"Phoenix",
		"Leviathan",
		"Zaratan",
		"Elder Tempest",
	],
	"Fey":         [
		"Boggle", "Blink Dog", "Pixie", "Sprite",
		"Satyr", "Darkling",
		"Dryad", "Quickling",
		"Centaur", "Darkling Elder", "Meenlock", "Sea Hag",
		"Green Hag", "Redcap",
		"Yeth Hound",
		"Annis Hag",
		"Korred", "Bheur Hag",
		"Autumn Eladrin", "Spring Eladrin", "Summer Eladrin",
		"Winter Eladrin",
	],
	"Fiend":       [
		"Lemure", "Manes", "Dretch",
		"Imp", "Quasit",
		"Spined Devil",
		"Bearded Devil", "Hell Hound",
		"Barghest", "Shadow Demon", "Succubus", "Babau",
		"Barbed Devil", "Barlgura", "Cambion", "Mezzoloth", "Night Hag",
		"Chasme", "Vrock",
		"Chain Devil", "Hezrou",
		"Bone Devil", "Glabrezu", "Nycaloth",
		"Horned Devil",
		"Erinyes", "Arcanaloth",
		"Ice Devil",
		"Nalfeshnee", "Rakshasa", "Ultroloth",
		"Marilith",
		"Goristro",
		"Balor",
		"Pit Fiend",
	],
	"Giant":       [
		"Firbolg",
		"Ettin", "Verbeeg",
		"Ogre", "Hill Giant",
		"Cyclops", "Mouth of Grolantor",
		"Stone Giant", "Oni", "Venom Troll",
		"Fomorian", "Frost Giant",
		"Fire Giant", "Cloud Giant", "Rot Troll", "Troll",
		"Stone Giant Dreamwalker",
		"Spirit Troll", "Cloud Giant Smiling One",
		"Storm Giant",
		"Storm Giant Quintessent",
	],
	"Humanoid":    [
		"Merfolk", "Bandit", "Guard", "Cultist",
		"Troglodyte", "Bullywug", "Kenku", "Drow", "Kobold",
		"Thug", "Scout", "Hobgoblin", "Lizardfolk", "Sahuagin", "Deep Gnome", "Orc", "Gnoll",
		"Goblin Boss", "Spy", "Kobold Dragonshield", "Yuan-ti Pureblood", "Goblin", "Bugbear",
		"Bandit Captain", "Gnoll Pack Lord", "Orc Eye of Gruumsh", "Priest", "Sahuagin Priestess", "Lizardfolk Shaman",
		"Hobgoblin Captain", "Bugbear Chief", "Veteran", "Farmer", "Ranger",
		"Gnoll Fang of Yeenoghu", "Lizardfolk King", "Orc War Chief",
		"Drow Elite Warrior", "Sahuagin Baron", "Gladiator",
		"Hobgoblin Warlord",
		"Drow Mage", "Knight",
		"Drow Priestess of Lolth", "Assassin",
		"Mage", "Archmage",
	],
	"Monstrosity": [
		"Sandworm",
		"Cockatrice", "Darkmantle", "Rust Monster",
		"Harpy", "Hippogriff", "Death Dog",
		"Ankheg", "Carrion Crawler", "Ettercap", "Griffin", "Merrow", "Peryton", "Grick", "Wererat",
		"Displacer Beast", "Hook Horror", "Manticore", "Owlbear", "Phase Spider", "Yuan-ti Malison", "Yeti", "Minotaur",
		"Lamia", "Wereboar", "Weretiger",
		"Basilisk", "Bulette", "Catoblepas", "Umber Hulk", "Werebear", "Werewolf",
		"Mimic", "Medusa",
		"Chimera", "Grick Alpha", "Yuan-ti Abomination",
		"Hydra", "Abominable Yeti",
		"Froghemoth", "Guardian Naga",
		"Behir", "Remorhaz", "Roc", "Gynosphinx",
		"Spirit Naga",
		"Androsphinx",
		"Kraken",
		"Tarrasque",
	],
	"Ooze":        [
		"Oblex Spawn",
		"Gray Ooze",
		"Ochre Jelly", "Gelatinous Cube",
		"Slithering Tracker",
		"Black Pudding",
		"Adult Oblex",
		"Elder Oblex",
		"Juiblex",
	],
	"Plant":       [
		"Mushroom",
		"Shrieker", "Myconid Sprout", "Awakened Shrub",
		"Twig Blight",
		"Needle Blight", "Violet Fungus", "Vegepygmy",
		"Gas Spore", "Vine Blight", "Myconid Adult",
		"Thorny",
		"Awakened Tree", "Vegepygmy Chief", "Myconid Sovereign",
		"Wood Woad",
		"Corpse Flower",
		"Treant",
	],
	"Undead":      [
		"Crawling Claw",
		"Skeleton", "Zombie", "Warhorse Skeleton",
		"Ghoul", "Shadow", "Specter",
		"Ghast", "Minotaur Skeleton", "Ogre Zombie", "Will-o'-Wisp", "Poltergeist",
		"Mummy", "Wight", "Sword Wraith Warrior", "Vampiric Mist",
		"Banshee", "Bone Naga", "Deathlock", "Flameskull", "Ghost",
		"Allip", "Revenant", "Vampire Spawn", "Wraith",
		"Bodak",
		"Deathlock Mastermind", "Sword Wraith Commander",
		"Vampire",
		"Mummy Lord", "Skull Lord",
		"Death Knight",
		"Demilich",
		"Lich",
	],
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
