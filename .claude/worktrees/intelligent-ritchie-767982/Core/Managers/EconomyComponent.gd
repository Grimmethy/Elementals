class_name EconomyComponent
extends Node

var gold: int = 100:
	set(v):
		gold = v
		GameEvents.gold_changed.emit(gold)

func initialize(initial_gold: int) -> void:
	gold = initial_gold
