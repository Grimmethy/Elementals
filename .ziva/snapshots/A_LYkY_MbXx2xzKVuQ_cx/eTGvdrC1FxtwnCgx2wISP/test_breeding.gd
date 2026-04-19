extends Node

func _ready():
	var does = 0
	var bucks = 0
	var iterations = 10000
	
	var doe = GoatData.new()
	doe.gender = GoatData.Gender.DOE
	doe.goat_name = "Mama"
	
	var buck = GoatData.new()
	buck.gender = GoatData.Gender.BUCK
	buck.goat_name = "Papa"
	
	for i in range(iterations):
		var kid = GoatData.create_offspring(doe, buck)
		if kid.gender == GoatData.Gender.DOE:
			does += 1
		else:
			bucks += 1
			
	print("Simulation of ", iterations, " births:")
	print("Does: ", does, " (", float(does)/iterations * 100.0, "%)")
	print("Bucks: ", bucks, " (", float(bucks)/iterations * 100.0, "%)")
	
	get_tree().quit()
