extends Camera3D

@export var planet: Node3D : set = _set_planet
@export var move_speed := 20.0
@export var look_sensitivity := 0.003
@export var fast_multiplier := 5.0 # Hold Shift to go Zoomies

var mouse_locked := false
var wireframe := false


var _rmb_held := false
var _imgui: Object = null
var _prev_planet_transform: Transform3D = Transform3D.IDENTITY
var _has_prev_planet_transform: bool = false
var _horizon_heading: Vector3 = Vector3.FORWARD
var _horizon_pitch: float = 0.0
var _horizon_initialized: bool = false


func _set_planet(val: Node3D) -> void:
	planet = val
	_horizon_initialized = false
	if planet and planet.is_inside_tree():
		_prev_planet_transform = planet.global_transform.orthonormalized()
		_has_prev_planet_transform = true
		if is_inside_tree():
			_init_horizon_from_current_basis()
	else:
		_has_prev_planet_transform = false


func _ready() -> void:
	process_priority = -10
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if planet and planet.is_inside_tree():
		_prev_planet_transform = planet.global_transform.orthonormalized()
		_has_prev_planet_transform = true
	_init_horizon_from_current_basis()
	if ClassDB.class_exists("ImGui"):
		if Engine.has_singleton("ImGui"):
			_imgui = Engine.get_singleton("ImGui")
		else:
			_imgui = ClassDB.instantiate("ImGui")


func _get_horizon_up() -> Vector3:
	if planet and planet.is_inside_tree():
		var to_cam := global_position - planet.global_position
		if to_cam.length_squared() > 0.0001:
			return to_cam.normalized()
	return Vector3.UP


func _init_horizon_from_current_basis() -> void:
	var u := _get_horizon_up()
	var bx := global_transform.basis.x
	var h := u.cross(bx)
	if h.length_squared() < 0.0001:
		var by := global_transform.basis.y
		h = by - u * by.dot(u)
		if h.length_squared() < 0.0001:
			h = Vector3.FORWARD.cross(u)
			if h.length_squared() < 0.0001:
				h = Vector3.RIGHT.cross(u)
	_horizon_heading = h.normalized()
	var fwd := -global_transform.basis.z.normalized()
	var cam_up := global_transform.basis.y.normalized()
	var sin_p := fwd.dot(u)
	var cos_p := maxf(fwd.dot(_horizon_heading), cam_up.dot(u))
	_horizon_pitch = clampf(atan2(sin_p, cos_p), deg_to_rad(-89.0), deg_to_rad(89.0))
	_horizon_initialized = true


func _apply_horizon_basis(u: Vector3) -> void:
	_horizon_heading = _horizon_heading - u * _horizon_heading.dot(u)
	if _horizon_heading.length_squared() < 0.0001:
		_init_horizon_from_current_basis()
		return
	_horizon_heading = _horizon_heading.normalized()
	var right := _horizon_heading.cross(u).normalized()
	var fwd := (_horizon_heading * cos(_horizon_pitch) + u * sin(_horizon_pitch)).normalized()
	var cam_up := right.cross(fwd).normalized()
	global_transform.basis = Basis(right, cam_up, -fwd).orthonormalized()


func sync_with_planet() -> void:
	if not planet or not planet.is_inside_tree():
		_has_prev_planet_transform = false
		return

	if not _horizon_initialized:
		_init_horizon_from_current_basis()

	var cur_planet_xform := planet.global_transform.orthonormalized()
	if not _has_prev_planet_transform:
		_prev_planet_transform = cur_planet_xform
		_has_prev_planet_transform = true
		return

	if cur_planet_xform.is_equal_approx(_prev_planet_transform):
		return

	var delta_basis := cur_planet_xform.basis * _prev_planet_transform.basis.inverse()
	var rel_pos := global_position - _prev_planet_transform.origin
	global_position = cur_planet_xform.origin + delta_basis * rel_pos
	_horizon_heading = delta_basis * _horizon_heading
	var u := _get_horizon_up()
	_apply_horizon_basis(u)
	_prev_planet_transform = cur_planet_xform


func _is_mouse_over_gui() -> bool:
	# 1. Check Dear ImGui window, active items, or mouse capture request
	if _imgui:
		var io = _imgui.GetIO()
		if io and io.WantCaptureMouse:
			return true
		# Flag 4 = ImGuiHoveredFlags_AnyWindow
		if _imgui.has_method("IsWindowHovered") and _imgui.IsWindowHovered(4):
			return true
		if _imgui.has_method("IsAnyItemHovered") and _imgui.IsAnyItemHovered():
			return true

	# 2. Check Godot GUI Controls (CanvasLayer UI fallback, panels, sliders, buttons)
	var vp := get_viewport()
	if vp and vp.has_method("gui_get_hovered_control"):
		var hovered = vp.gui_get_hovered_control()
		if hovered != null and hovered.is_visible_in_tree():
			return true

	return false


func _input(event: InputEvent) -> void:
	# MOUSE BUTTONS
	if event is InputEventMouseButton:
		var over_gui := _is_mouse_over_gui()

		# Right Mouse Button: Hold to freelook (standard 3D editor behavior)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if not over_gui:
					_rmb_held = true
					_lock_mouse()
			else:
				if _rmb_held:
					_rmb_held = false
					_unlock_mouse()
				elif mouse_locked:
					_unlock_mouse()
			return

		# Left Mouse Button: Only lock if clicking on the 3D scene (NEVER on ImGui or GUI)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if over_gui:
					# Click is interacting with ImGui / GUI: ignore camera lock!
					return
				_lock_mouse()
			return

	# MOUSE LOOK (Only when mouse is locked!)
	if mouse_locked and event is InputEventMouseMotion:
		if not _horizon_initialized:
			_init_horizon_from_current_basis()

		var u := _get_horizon_up()

		# 1. Yaw (Left/Right) — Rotate around the planet's local horizon normal (u)
		var yaw_delta: float = -event.relative.x * look_sensitivity
		_horizon_heading = _horizon_heading.rotated(u, yaw_delta)

		# 2. Pitch (Up/Down) — Rotate relative to the planet's local horizon plane, clamped to [-89, 89] deg
		var pitch_delta: float = -event.relative.y * look_sensitivity
		_horizon_pitch = clampf(_horizon_pitch + pitch_delta, deg_to_rad(-89.0), deg_to_rad(89.0))

		# 3. Reconstruct orthonormal basis aligned with the planet's horizon (zero horizon roll)
		_apply_horizon_basis(u)

	# ESC to unlock mouse
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		_rmb_held = false
		_unlock_mouse()

	# P = wireframe toggle
	if event.is_action_pressed("toggle_wireframe"):
		_toggle_wireframe()


func _process(delta: float) -> void:
	sync_with_planet()
	if mouse_locked:
		_move(delta)


func _move(delta: float) -> void:
	if not _horizon_initialized:
		_init_horizon_from_current_basis()

	var old_u := _get_horizon_up()
	var dir := Vector3.ZERO

	# Check for shift key to go fast
	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	# Use Basis for direction so "Forward" is where you are looking
	if Input.is_action_pressed("ui_forward"):
		dir -= global_transform.basis.z
	if Input.is_action_pressed("ui_backward"):
		dir += global_transform.basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= global_transform.basis.x
	if Input.is_action_pressed("ui_right"):
		dir += global_transform.basis.x

	# Fly straight up/down relative to the planet's local horizon normal
	if Input.is_action_pressed("ui_up"):
		dir += old_u
	if Input.is_action_pressed("ui_down"):
		dir -= old_u

	if dir != Vector3.ZERO:
		global_position += dir.normalized() * speed * delta
		var new_u := _get_horizon_up()
		var arc := Quaternion(old_u, new_u)
		_horizon_heading = arc * _horizon_heading
		_apply_horizon_basis(new_u)


func _lock_mouse() -> void:
	mouse_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unlock_mouse() -> void:
	mouse_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _toggle_wireframe() -> void:
	wireframe = !wireframe
	if wireframe:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	else:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
