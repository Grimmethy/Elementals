class_name GoatManager
extends Node

signal herd_updated
signal day_advanced(new_day: int)
signal gold_changed(new_amount: int)

var herd: Array[GoatData] = []
var gold: int = 100:
	set(v):
		gold = v
		gold_changed.emit(gold)

var current_day: int = 1

func _ready() -> void:
	# Start with a few default goats if the herd is empty
	if herd.is_empty():
		_generate_starter_herd()

func _generate_starter_herd() -> void:
	var names = ["Bessie", "Billy", "Daisy", "Gurt"]
	for i in range(4):
		var goat = GoatData.new()
		goat.goat_name = names[i]
		goat.gender = GoatData.Gender.DOE if i % 2 == 0 else GoatData.Gender.BUCK
		goat.base_color = Color(randf(), randf(), randf())
		herd.append(goat)
	herd_updated.emit()

func add_goat(goat: GoatData) -> void:
	herd.append(goat)
	herd_updated.emit()

func remove_goat(goat: GoatData) -> void:
	herd.erase(goat)
	herd_updated.emit()

func next_day() -> void:
	current_day += 1
	
	var new_kids: Array[GoatData] = []
	
	for goat in herd:
		# Aging
		goat.age_days += 1
		
		# Stamina Recovery
		goat.stamina_current = goat.stamina_max
		goat.is_exhausted = false
		
		# Pregnancy processing
		if goat.is_pregnant:
			goat.pregnancy_timer -= 1
			if goat.pregnancy_timer <= 0:
				goat.is_pregnant = false
				# Birth logic (would normally need a buck reference stored on the doe)
				# For now, we'll assume a random buck from the herd or a generic one
				var buck = _find_random_buck()
				if buck:
					var kid = GoatData.create_offspring(goat, buck)
					new_kids.append(kid)
	
	for kid in new_kids:
		add_goat(kid)
		
	day_advanced.emit(current_day)
	herd_updated.emit()

func breed_goats(doe: GoatData, buck: GoatData) -> bool:
	if doe.gender != GoatData.Gender.DOE or buck.gender != GoatData.Gender.BUCK:
		return false
	
	if doe.is_pregnant or doe.is_exhausted or buck.is_exhausted:
		return false
		
	doe.is_pregnant = true
	doe.pregnancy_timer = 3 # 3 days pregnancy
	
	# Breeding is tiring
	doe.is_exhausted = true
	buck.is_exhausted = true
	
	herd_updated.emit()
	return true

func _find_random_buck() -> GoatData:
	var bucks = herd.filter(func(g): return g.gender == GoatData.Gender.BUCK)
	if bucks.is_empty():
		return null
	return bucks.pick_random()

func sell_goat(goat: GoatData) -> void:
	gold += goat.gold_value
	remove_goat(goat)
