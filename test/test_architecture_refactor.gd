extends Node

func test_elemental_load() -> void:
	var elemental_scene = load("res://Elemental/FireElemental.tscn")
	assert(elemental_scene != null, "FireElemental scene should exist")
	
	var elemental = elemental_scene.instantiate()
	assert(elemental != null, "Elemental should be instantiatable")
	
	add_child(elemental)
	elemental.queue_free()
	
func test_decision_component_load() -> void:
	var decision_comp = ElementalDecisionComponent.new()
	assert(decision_comp != null, "ElementalDecisionComponent should be instantiatable")
	
	add_child(decision_comp)
	decision_comp.queue_free()
