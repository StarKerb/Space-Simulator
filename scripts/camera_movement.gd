extends Camera3D

@export var move_speed := 20.0
@export var look_sensitivity := 0.003
@export var fast_multiplier := 5.0 # Hold Shift to go Zoomies

var mouse_locked := false
var wireframe := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# CLICK to lock mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_lock_mouse()

	# MOUSE LOOK
	if mouse_locked and event is InputEventMouseMotion:
		# 1. Yaw (Left/Right) - Rotate around Global Up (Vector3.UP)
		# This keeps your head level with the horizon
		global_rotate(Vector3.UP, -event.relative.x * look_sensitivity)
		
		# 2. Pitch (Up/Down) - Rotate around Local Right (Basis X)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * look_sensitivity)
		
		# 3. Prevent Backflips (Clamp Pitch)
		# We clamp the rotation so you can't look further than straight up/down
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
		# 4. Force Z rotation to 0 to kill any accidental rolling
		rotation.z = 0 
		
		# 5. Clean up the matrix or it gets messy over time
		orthonormalize()

	# ESC to unlock mouse
	if event.is_action_pressed("ui_cancel"):
		_unlock_mouse()

	# F = wireframe
	if event.is_action_pressed("toggle_wireframe"):
		_toggle_wireframe()

func _process(delta):
	if mouse_locked:
		_move(delta)

func _move(delta):
	var dir := Vector3.ZERO
	
	# Check for shift key to go fast
	var speed = move_speed
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
	
	# Fly straight up/down in global space (optional, feels better for debug)
	if Input.is_action_pressed("ui_up"):
		dir += Vector3.UP # Global Up
	if Input.is_action_pressed("ui_down"):
		dir -= Vector3.UP

	if dir != Vector3.ZERO:
		position += dir.normalized() * speed * delta

func _lock_mouse():
	mouse_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unlock_mouse():
	mouse_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _toggle_wireframe():
	wireframe = !wireframe
	if wireframe:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	else:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
