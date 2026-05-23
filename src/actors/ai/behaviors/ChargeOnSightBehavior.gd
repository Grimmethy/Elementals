class_name ChargeOnSightBehavior
extends AIBehavior

## Drives the IDLE → ALERT → CHARGING → COOLDOWN charge cycle.
## Overrides movement during ALERT, CHARGING, and COOLDOWN.
## Replaces GoatController's internal state machine and _update_* methods.

enum State { IDLE, ALERT, CHARGING, COOLDOWN }

var alert_duration: float = 1.0
var cooldown_duration: float = 3.0

var _state: State = State.IDLE
var _target: Node3D = null
var _state_timer: float = 0.0

func setup(p_controller: ActorAIController, config: Dictionary) -> void:
	super.setup(p_controller, config)
	alert_duration = config.get("charge_alert_duration", 1.0)
	cooldown_duration = config.get("charge_cooldown_duration", 3.0)

func is_overriding_movement() -> bool:
	return _state != State.IDLE

func physics_tick(delta: float) -> float:
	match _state:
		State.IDLE:     return _tick_idle()
		State.ALERT:    return _tick_alert(delta)
		State.CHARGING: return _tick_charging()
		State.COOLDOWN: return _tick_cooldown(delta)
	return 1.0

func _tick_idle() -> float:
	var a := controller.actor as Actor
	if a and a.detection_component:
		var target := a.detection_component.detect_nearest_actor()
		if target:
			_target = target
			_transition_to(State.ALERT)
	return 1.0

func _tick_alert(delta: float) -> float:
	if not is_instance_valid(_target):
		_transition_to(State.IDLE)
		return 1.0
	if not controller._movement_claimed:
		controller.claim_movement()
		controller.movement_component.stop(delta)
	controller._face_target(_target.global_position)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_transition_to(State.CHARGING)
	return 1.5

func _tick_charging() -> float:
	if is_instance_valid(_target):
		var a := controller.actor as Actor
		if a and a.ability_component:
			a.ability_component.execute_ability("charge", _target.global_position)
	_transition_to(State.COOLDOWN)
	return 1.0

func _tick_cooldown(delta: float) -> float:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_transition_to(State.IDLE)
	return 0.5

func _transition_to(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.IDLE:
			_target = null
		State.ALERT:
			_state_timer = alert_duration
			var a := controller.actor as Actor
			if a and a.has_method("_scream"):
				a.call("_scream")
		State.CHARGING:
			pass
		State.COOLDOWN:
			_state_timer = cooldown_duration
