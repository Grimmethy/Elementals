# Master ability index. Each category lives in its own file.
# Usage: AbilityList.ABILITIES["MOVEMENT"]["Fly"]

const Movement       = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/MovementAbilitiesList.gd")
const PassiveDefense = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/PassiveDefenseAbilitiesList.gd")
const Regeneration   = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/RegenerationAbilitiesList.gd")
const Offense        = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/OffenseAbilitiesList.gd")
const BreathWeapons  = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/BreathWeaponAbilitiesList.gd")
const Spellcasting   = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/SpellcastingAbilitiesList.gd")
const Shapeshifting  = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/ShapeshiftingAbilitiesList.gd")
const Psychic        = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/PsychicAbilitiesList.gd")
const Sensory        = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/SensoryAbilitiesList.gd")
const Auras          = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/AurasAbilitiesList.gd")
const StatusEffects  = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/StatusEffectsAbilitiesList.gd")
const LifeDrain      = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/LifeDrainAbilitiesList.gd")
const Summoning      = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/SummoningAbilitiesList.gd")
const Environmental  = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/EnvironmentalAbilitiesList.gd")
const Special        = preload("res://Components/ActorComponents/AbilityComponents/AbilityLists/SpecialAbilitiesList.gd")

const ABILITIES: Dictionary = {
	"MOVEMENT":       Movement.DATA,
	"PASSIVE_DEFENSE":PassiveDefense.DATA,
	"REGENERATION":   Regeneration.DATA,
	"OFFENSE":        Offense.DATA,
	"BREATH_WEAPONS": BreathWeapons.DATA,
	"SPELLCASTING":   Spellcasting.DATA,
	"SHAPESHIFTING":  Shapeshifting.DATA,
	"PSYCHIC":        Psychic.DATA,
	"SENSORY":        Sensory.DATA,
	"AURAS":          Auras.DATA,
	"STATUS_EFFECTS": StatusEffects.DATA,
	"LIFE_DRAIN":     LifeDrain.DATA,
	"SUMMONING":      Summoning.DATA,
	"ENVIRONMENTAL":  Environmental.DATA,
	"SPECIAL":        Special.DATA,
}
