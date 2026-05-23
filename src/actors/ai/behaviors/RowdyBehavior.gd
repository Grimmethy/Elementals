class_name RowdyBehavior
extends AIBehavior

## Increases movement speed based on how many nearby allies of the same type are present.
## Purely a speed modifier — does not affect state machine or movement direction.

var nearby_radius: float = 8.0
var bonus_per_actor: float = 0.25
var actor_filter: String = ""

func setup(p_controller: ActorAIController, config: Dictionary) -> void:
	super.setup(p_controller, config)
	nearby_radius = config.get("rowdy_radius", 8.0)
	bonus_per_actor = config.get("rowdy_bonus_per_actor", 0.25)
	actor_filter = config.get("rowdy_actor_filter", "")

func physics_tick(_delta: float) -> float:
	var a := controller.actor as Actor
	if not a or not a._arena_grid:
		return 1.0

	var bonus := 1.0
	for other in a._arena_grid.actors:
		if not is_instance_valid(other) or other == a:
			continue
		if not actor_filter.is_empty() and other.get("element_type") != actor_filter:
			continue
		if other.global_position.distance_to(a.global_position) < nearby_radius:
			bonus += bonus_per_actor
	return bonus
