class_name DamageComponent
extends Node

## A component that defines damage properties and can apply them to targets.

@export var damage_amount: float = 1.0
@export var element_type: String = "none"

## Attempts to deal damage to a target node if it has a HealthComponent.
func deal_damage(target: Node) -> bool:
	var health = find_health_component(target)
	if health:
		health.take_damage(damage_amount, element_type)
		return true
	
	# Fallback for legacy take_damage calls if HealthComponent isn't found
	if target.has_method("take_damage"):
		# Check if it's the TreeFeature style (amount, is_fire) or Elemental style (amount)
		if element_type == "fire" and target.get_script() and "TreeFeature" in target.get_script().get_global_name():
			target.take_damage(damage_amount, true)
		else:
			target.take_damage(damage_amount, element_type)
		return true
		
	return false

## Helper to find a HealthComponent on a node or its children.
static func find_health_component(node: Node) -> HealthComponent:
	if not node: return null
	
	if node is HealthComponent:
		return node
		
	# Check direct children
	for child in node.get_children():
		if child is HealthComponent:
			return child
			
	return null
