class_name AIBehavior
extends RefCounted

## Base class for composable AI behaviors attached to ActorAIController.
## Behaviors are instantiated from ActorTypeData's "ai_behaviors" list and
## run every frame alongside the state machine.

var controller: ActorAIController

func setup(p_controller: ActorAIController, _config: Dictionary) -> void:
	controller = p_controller

## Called after the state machine is initialized.
## Override to register additional states on controller.state_machine.
func register_states() -> void:
	pass

## Called every physics frame. Returns a speed multiplier (1.0 = no change).
## Behaviors that override movement should call controller.claim_movement()
## before touching movement_component directly.
func physics_tick(_delta: float) -> float:
	return 1.0

## Called every process frame.
func process_tick(_delta: float) -> void:
	pass

## Returns true if this behavior is currently controlling movement.
## When true, the controller skips the state machine's physics_update.
func is_overriding_movement() -> bool:
	return false
