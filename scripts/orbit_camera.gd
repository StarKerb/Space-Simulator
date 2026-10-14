class_name OrbitCamera
extends Camera3D

## KSP-Style Orbit / Gimbal Camera tracking the Spacecraft.
## Features Unlimited Zooming and Map Mode (M key).

signal map_mode_toggled(is_map_mode: bool)

@export var target: Node3D
@export var target_offset: Vector3 = Vector3(0, 0, 0)

@export var distance: float = 22.0
@export var min_distance: float = 3.0
@export var max_distance: float = 100000000.0 # 100,000 km (unlimited astronomical zooming)

@export var mouse_sensitivity: float = 0.004
@export var zoom_speed: float = 1.25

var is_map_mode: bool = false

var _azimuth: float = 0.8       # horizontal angle (radians)
var _elevation: float = 0.35    # vertical angle (radians)
var _is_orbiting: bool = false
var _target_distance: float = 22.0
var _saved_flight_distance: float = 22.0

func _ready() -> void:
	near = 0.1
	far = 100000000.0 # 100,000 km far clip plane
	fov = 60.0
	_target_distance = distance
	current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_map_mode()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
			_is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Multiplicative zoom: scroll speed scales smoothly with current distance
			_target_distance = clampf(_target_distance / zoom_speed, min_distance, max_distance)
			if is_map_mode and _target_distance < 1000.0:
				is_map_mode = false
				emit_signal("map_mode_toggled", false)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance * zoom_speed, min_distance, max_distance)

	elif event is InputEventMouseMotion and _is_orbiting:
		_azimuth -= event.relative.x * mouse_sensitivity
		_elevation += event.relative.y * mouse_sensitivity
		_elevation = clampf(_elevation, deg_to_rad(-85.0), deg_to_rad(85.0))

func toggle_map_mode() -> void:
	is_map_mode = not is_map_mode
	if is_map_mode:
		_saved_flight_distance = distance
		_target_distance = 25000000.0 # 25,000 km orbital overview
	else:
		_target_distance = clampf(_saved_flight_distance, min_distance, 500.0)
	emit_signal("map_mode_toggled", is_map_mode)

func _process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	# Smooth adaptive distance interpolation
	var interp_speed: float = 14.0 if is_map_mode else 10.0
	distance = lerpf(distance, _target_distance, clampf(delta * interp_speed, 0.0, 1.0))

	# Dynamic near/far clip plane: guarantees high precision float depth at any scale
	near = clampf(distance * 0.005, 0.2, 500.0)
	far = clampf(maxf(distance * 30.0, 100000000.0), 100000000.0, 1000000000.0)

	# Compute spherical offset around target
	var cos_elev: float = cos(_elevation)
	var sin_elev: float = sin(_elevation)
	var cos_azim: float = cos(_azimuth)
	var sin_azim: float = sin(_azimuth)

	var offset := Vector3(
		distance * cos_elev * sin_azim,
		distance * sin_elev,
		distance * cos_elev * cos_azim
	)

	var focus_point: Vector3 = target.global_position + target_offset
	global_position = focus_point + offset
	look_at(focus_point, Vector3.UP)
