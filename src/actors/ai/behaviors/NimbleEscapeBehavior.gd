class_name NimbleEscapeBehavior
extends AIBehavior

## Triggers disengage or hide abilities based on enemy proximity.
## Does not override movement — runs alongside the state machine every frame.
## Replaces GoblinController._update_nimble_escape().

var disengage_range: float = 4.0
var hide_range: float = 8.0

func setup(p_controller: ActorAIController, config: Dictionary) -> void:
	super.setup(p_controller, config)
	disengage_range = config.get("nimble_escape_disengage_range", 4.0)
	hide_range = config.get("nimble_escape_hide_range", 8.0)

func physics_tick(_delta: float) -> float:
	var a := controller.actor as Actor
	if not a or not a._arena_grid or not a.ability_component:
		return 1.0

	var nearest_enemy: Node3D = controller._find_nearest_enemy()
	if not nearest_enemy:
		return 1.0

	var dist := a.global_position.distance_to(nearest_enemy.global_position)
	if dist < disengage_range:
		a.ability_component.execute_ability("disengage")
	elif dist > hide_range and not a.ability_component.is_hidden:
		a.ability_component.execute_ability("hide")

	return 1.0
