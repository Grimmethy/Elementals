class_name MushroomController
extends ActorAIController

## Slow, methodical fungus AI. Mushrooms idle in place until an enemy enters
## their detection range, then approach lazily and bite. Spore Burst fires
## automatically when surrounded (2+ enemies within burst radius).

const SPORE_BURST_TRIGGER_RANGE: float = 2.4
const SPORE_BURST_MIN_ENEMIES: int = 2

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if actor and not is_controlled:
		_consider_spore_burst()

func _consider_spore_burst() -> void:
	if not actor or not actor.ability_component:
		return
	if actor._arena_grid == null:
		return
	var enemies_close: int = 0
	for node in actor._arena_grid.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var candidate: Actor = node as Actor
		if candidate == actor or candidate.is_dead:
			continue
		if actor.has_method("is_enemy") and not actor.is_enemy(candidate):
			continue
		var flat: float = Vector2(
			candidate.global_position.x - actor.global_position.x,
			candidate.global_position.z - actor.global_position.z
		).length()
		if flat <= SPORE_BURST_TRIGGER_RANGE:
			enemies_close += 1
			if enemies_close >= SPORE_BURST_MIN_ENEMIES:
				actor.ability_component.execute_ability("ability_r")
				return
