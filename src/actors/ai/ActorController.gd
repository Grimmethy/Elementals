## Base class for all actor decision-making logic.
## This component acts as the 'brain' of an Actor, deciding where to move and
## how to react, then passing those intentions to the MovementComponent.
class_name ActorController
extends Node

## The movement component that this controller will control.
@export var movement_component: MovementComponent

## Reference to the owning actor.
@export var actor: Node3D

## If true, this component ignores AI logic and listens for player input instead.
@export var is_controlled: bool = false

## The active control scheme. Defaults to TwinStickMode if unset.
## Swap via set_mode() at runtime to switch control styles.
@export var current_mode: ControllerModeBase

## Tracks whether on_mode_entered has been called for the current mode.
var _mode_active: bool = false

## Main update loop that dispatches control to either player input or AI logic.
func _physics_process(delta: float) -> void:
	if not movement_component:
		return

	# Lazy-initialise the default mode on the first physics tick.
	if not current_mode:
		current_mode = _make_default_mode()

	if is_controlled:
		if not _mode_active:
			_mode_active = true
			current_mode.on_mode_entered(actor, get_viewport().get_camera_3d())
		_handle_controlled_input(delta)
		if actor and actor.detection_component:
			actor.detection_component.process_update(delta)
	else:
		if _mode_active:
			_mode_active = false
			current_mode.on_mode_exited(actor, get_viewport().get_camera_3d())
		_handle_ai_logic(delta)

## Delegates movement and orientation to the active ControllerMode.
func _handle_controlled_input(delta: float) -> void:
	current_mode.process_input(actor, get_viewport().get_camera_3d(), delta)

## Returns the world-space aim target for the current control mode.
## Used by PlayerInputComponent so attack/ability targeting is mode-agnostic.
func get_aim_target() -> Vector3:
	if current_mode and is_instance_valid(actor):
		return current_mode.get_aim_target(actor, get_viewport().get_camera_3d())
	return Vector3.ZERO

## Creates the initial mode by reading selected_control_mode from GameSettings.
## Falls back to TwinStickMode if GameSettings is unavailable.
func _make_default_mode() -> ControllerModeBase:
	if is_inside_tree():
		var gs: Node = get_tree().root.get_node_or_null("GameSettings")
		if gs:
			match int(gs.get("selected_control_mode")):
				1:
					var mode := ThirdPersonMode.new()
					mode.invert_x = bool(gs.get("invert_look_x"))
					mode.invert_y = bool(gs.get("invert_look_y"))
					return mode
				# 2 (First Person) and 3 (RTS) not yet implemented — fall through to default.
	return TwinStickMode.new()

## Hot-swaps the control mode, calling the lifecycle hooks on both sides.
func set_mode(new_mode: ControllerModeBase) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if _mode_active and current_mode:
		current_mode.on_mode_exited(actor, cam)
		_mode_active = false
	current_mode = new_mode
	if is_controlled and current_mode:
		_mode_active = true
		current_mode.on_mode_entered(actor, cam)

## Virtual method intended to be overridden by subclasses.
## Should implement the logic for picking a new destination (e.g., random wandering).
func _choose_new_target() -> void:
	pass

## Returns a string representation of the current control state for debugging tools.
func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	return "AI"

## Virtual method intended to be overridden by subclasses.
## Should implement the autonomous behavior (FSM, steering, etc.) for the NPC.
func _handle_ai_logic(_delta: float) -> void:
	pass
