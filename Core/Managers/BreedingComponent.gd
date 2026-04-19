class_name BreedingComponent
extends Node

func breed_goats(doe: GoatData, buck: GoatData) -> bool:
	if doe.gender != GoatData.Gender.DOE or buck.gender != GoatData.Gender.BUCK:
		return false
	
	if doe.is_pregnant or doe.is_exhausted or buck.is_exhausted:
		return false
		
	doe.is_pregnant = true
	doe.pregnancy_timer = 3 # 3 days pregnancy
	doe.pregnancy_father = buck
	
	# Breeding is tiring
	doe.is_exhausted = true
	buck.is_exhausted = true
	
	GameEvents.herd_updated.emit()
	return true

func process_pregnancy(herd: Array[GoatData]) -> Array[GoatData]:
	var new_kids: Array[GoatData] = []
	for goat in herd:
		if goat.is_pregnant:
			goat.pregnancy_timer -= 1
			if goat.pregnancy_timer <= 0:
				goat.is_pregnant = false
				var buck = goat.pregnancy_father
				if not buck:
					buck = _find_random_buck(herd)
				
				if buck:
					var kid = GoatData.create_offspring(goat, buck)
					new_kids.append(kid)
				
				goat.pregnancy_father = null
	return new_kids

func _find_random_buck(herd: Array[GoatData]) -> GoatData:
	var bucks = herd.filter(func(g): return g.gender == GoatData.Gender.BUCK)
	if bucks.is_empty():
		return null
	return bucks.pick_random()
