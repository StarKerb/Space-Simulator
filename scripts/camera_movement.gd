extends Camera3D

@export var move_speed := 20.0
@export var look_sensitivity := 0.003
@export var fast_multiplier := 5.0 # Hold Shift to go Zoomies

var mouse_locked := false
var wireframe := false


var _rmb_held := false
var _imgui: Object = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if ClassDB.class_exists("ImGui"):
		if Engine.has_singleton("ImGui"):
			_imgui = Engine.get_singleton("ImGui")
		else:
			_imgui = ClassDB.instantiate("ImGui")


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
		# 1. Yaw (Left/Right) — Rotate around Global Up (Vector3.UP)
		global_rotate(Vector3.UP, -event.relative.x * look_sensitivity)

		# 2. Pitch (Up/Down) — Rotate around Local Right (Basis X)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * look_sensitivity)

		# 3. Prevent Backflips (Clamp Pitch)
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))

		# 4. Force Z rotation to 0 to kill any accidental rolling
		rotation.z = 0

		# 5. Clean up the matrix so it doesn't drift over time
		transform = transform.orthonormalized()

	# ESC to unlock mouse
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		_rmb_held = false
		_unlock_mouse()

	# P = wireframe toggle
	if event.is_action_pressed("toggle_wireframe"):
		_toggle_wireframe()


func _process(delta: float) -> void:
	if mouse_locked:
		_move(delta)


func _move(delta: float) -> void:
	var dir := Vector3.ZERO

	# Check for shift key to go fast
	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	# Use Basis for direction so "Forward" is where you are looking
	if Input.is_action_pressed("ui_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("ui_backward"):
		dir += transform.basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("ui_right"):
		dir += transform.basis.x

	# Fly straight up/down in global space (feels better for debug)
	if Input.is_action_pressed("ui_up"):
		dir += Vector3.UP
	if Input.is_action_pressed("ui_down"):
		dir -= Vector3.UP

	if dir != Vector3.ZERO:
		position += dir.normalized() * speed * delta


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
