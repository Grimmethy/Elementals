class_name OrbitPreviewContainer
extends SubViewportContainer

## Mouse-driven orbit camera for the Dev Monster Preview SubViewport.
##
##   Left-drag       → orbit around the pivot
##   Mouse wheel     → zoom in/out
##   Right-drag      → pan (small offset to the pivot)
##   Middle-click    → reset to default view
##
## Attach to a SubViewportContainer whose SubViewport contains a Camera3D.
## Set `camera_path` to point at the camera (relative to this container).

@export var camera_path: NodePath = NodePath("SubViewport/Camera3D")

## Where the camera orbits around. Roughly the center of the rendered creature.
## Y > 0 because creatures stand on the floor and we want to look at their body.
@export var pivot: Vector3 = Vector3(0, 0.7, 0)

@export var min_distance: float = 0.6
@export var max_distance: float = 6.0
@export var zoom_speed: float = 0.25

## Mouse sensitivity (radians per pixel).
@export var orbit_sensitivity: float = 0.008
@export var pan_sensitivity: float = 0.003

## Spherical-coord state — driven by input each frame.
var distance: float = 2.6
var yaw: float = 0.35      # horizontal angle around Y axis
var pitch: float = -0.35   # vertical angle (negative = looking slightly down)

var _camera: Camera3D = null
var _orbiting: bool = false
var _panning: bool = false

# Defaults so middle-click can reset
var _default_distance: float = 2.6
var _default_yaw: float = 0.35
var _default_pitch: float = -0.35
var _default_pivot: Vector3 = Vector3(0, 0.7, 0)

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	# Make sure the container actually captures mouse input.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_default_distance = distance
	_default_yaw = yaw
	_default_pitch = pitch
	_default_pivot = pivot
	_update_camera()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_orbiting = mb.pressed
				accept_event()
			MOUSE_BUTTON_RIGHT:
				_panning = mb.pressed
				accept_event()
			MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					_reset_view()
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					distance = clampf(distance - zoom_speed, min_distance, max_distance)
					_update_camera()
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					distance = clampf(distance + zoom_speed, min_distance, max_distance)
					_update_camera()
				accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			yaw -= mm.relative.x * orbit_sensitivity
			pitch = clampf(pitch - mm.relative.y * orbit_sensitivity, -1.40, 1.40)
			_update_camera()
			accept_event()
		elif _panning:
			# Pan in camera-relative XY — drag the pivot.
			if _camera:
				var basis: Basis = _camera.global_transform.basis
				pivot -= basis.x * (mm.relative.x * pan_sensitivity * distance)
				pivot += basis.y * (mm.relative.y * pan_sensitivity * distance)
				_update_camera()
			accept_event()

func _reset_view() -> void:
	distance = _default_distance
	yaw = _default_yaw
	pitch = _default_pitch
	pivot = _default_pivot
	_update_camera()

func _update_camera() -> void:
	if _camera == null:
		return
	# Spherical → cartesian. pitch=0 = horizon; pitch positive = above.
	var cp: float = cos(pitch)
	var x: float = pivot.x + cp * sin(yaw) * distance
	var y: float = pivot.y + sin(pitch) * distance
	var z: float = pivot.z + cp * cos(yaw) * distance
	_camera.position = Vector3(x, y, z)
	_camera.look_at(pivot, Vector3.UP)
