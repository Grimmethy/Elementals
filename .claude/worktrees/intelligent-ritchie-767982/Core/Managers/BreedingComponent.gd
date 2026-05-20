class_name BreedingComponent
extends Node

func breed(parent_a: ActorData, parent_b: ActorData) -> bool:
	# Find which is male and which is female
	var male: ActorData
	var female: ActorData
	
	if parent_a.gender == ActorData.Gender.MALE and parent_b.gender == ActorData.Gender.FEMALE:
		male = parent_a
		female = parent_b
	elif parent_a.gender == ActorData.Gender.FEMALE and parent_b.gender == ActorData.Gender.MALE:
		male = parent_b
		female = parent_a
	else:
		return false  # Must be male + female
	
	if female.is_pregnant or female.is_exhausted or male.is_exhausted:
		return false
		
	female.is_pregnant = true
	female.pregnancy_timer = 3 # 3 days pregnancy
	female.pregnancy_father = male
	
	# Breeding is tiring
	female.is_exhausted = true
	male.is_exhausted = true
	
	GameEvents.herd_updated.emit()
	return true

## Asexual / self-budding breeding entry point. Skips the male+female gate
## that `breed()` enforces, so single-parent species (e.g. Mimic) can
## reproduce. The parent itself is recorded as `pregnancy_father` — a
## self-reference — so `process_pregnancy()` resolves `partner = parent`
## and calls `parent.create_offspring(parent)` exactly the way
## `MimicData.create_offspring()` already expects (it ignores the partner).
##
## Returns `true` on success, `false` if the parent is null, already
## pregnant, or exhausted.
##
## Safety: process_pregnancy() clears `is_pregnant = false` BEFORE calling
## create_offspring(), and clears `pregnancy_father = null` AFTER — so the
## self-reference does NOT leak into saved data and there is no re-entry
## hazard. Verified by Agent 1 §5 + advisor pass.
func breed_asexual(parent: ActorData) -> bool:
	if parent == null:
		return false
	if parent.is_pregnant or parent.is_exhausted:
		return false

	parent.is_pregnant = true
	parent.pregnancy_timer = 3  # 3 days, mirrors breed()
	parent.pregnancy_father = parent  # self-reference — process_pregnancy reads this

	# Breeding is tiring even when asexual — blocks rapid re-budding
	# within the same day and matches the `breed()` exhaustion semantic.
	parent.is_exhausted = true

	GameEvents.herd_updated.emit()
	return true

func process_pregnancy(actors: Array) -> Array[ActorData]:
	var new_offspring: Array[ActorData] = []
	for actor in actors:
		if actor is ActorData and actor.is_pregnant:
			actor.pregnancy_timer -= 1
			if actor.pregnancy_timer <= 0:
				actor.is_pregnant = false
				var partner = actor.pregnancy_father
				if not partner:
					partner = _find_random_male(actors)
				
				if partner:
					var kid = actor.create_offspring(partner)
					new_offspring.append(kid)
				
				actor.pregnancy_father = null
	return new_offspring

func _find_random_male(actors: Array[ActorData]) -> ActorData:
	var males = actors.filter(func(a): return a.gender == ActorData.Gender.MALE)
	if males.is_empty():
		return null
	return males.pick_random()
