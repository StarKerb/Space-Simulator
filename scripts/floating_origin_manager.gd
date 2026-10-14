class_name FloatingOriginManager
extends Node

## Floating Origin Manager for 1:1 Astronomical Scale Spaceflight.
## Eliminates GPU 32-bit floating-point precision jitter by keeping the active
## spacecraft and camera near (0, 0, 0) in Godot engine space.

signal origin_shifted(shift_vector: Vector3, new_universe_origin: Vector3)

@export var craft: Spacecraft
@export var planet: Node3D
@export var camera: Camera3D
@export var sun_light: DirectionalLight3D
@export var trajectory_renderer: OrbitRenderer

@export var shift_threshold: float = 5000.0 # meters (shifts smoothly every 5 km)

# Master 64-bit Universe Coordinates
var universe_origin: Vector3 = Vector3.ZERO
var universe_craft_pos: Vector3 = Vector3.ZERO
var universe_craft_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	if craft:
		# Initialize universe origin at craft starting position
		universe_origin = craft.global_position
		universe_craft_pos = craft.global_position
		if planet:
			# Planet starts in universe frame
			pass

func _physics_process(_delta: float) -> void:
	if not craft or not is_instance_valid(craft):
		return

	# Update universe state
	universe_craft_pos = universe_origin + craft.global_position
	universe_craft_vel = craft.linear_velocity

	# Check if distance from Godot world origin exceeds threshold
	var drift_dist: float = craft.global_position.length()
	if drift_dist > shift_threshold:
		_apply_origin_shift(craft.global_position)

func _apply_origin_shift(shift: Vector3) -> void:
	universe_origin += shift

	# 1. Shift Spacecraft RigidBody3D
	if craft.freeze:
		craft.global_position -= shift
		craft.pending_origin_shift = Vector3.ZERO
	else:
		craft.pending_origin_shift += shift

	# 2. Shift Celestial Bodies & Environment
	if planet and is_instance_valid(planet):
		planet.global_position -= shift
		var atmo_node := planet.get_node_or_null("AtmosphereShell") as MeshInstance3D
		if atmo_node and atmo_node.material_override is ShaderMaterial:
			(atmo_node.material_override as ShaderMaterial).set_shader_parameter("planet_center", planet.global_position)
		var ocean_node := planet.get_node_or_null("OceanShell") as MeshInstance3D
		if ocean_node and ocean_node.material_override is ShaderMaterial:
			(ocean_node.material_override as ShaderMaterial).set_shader_parameter("planet_center", planet.global_position)

	# 3. Shift Camera
	if camera and is_instance_valid(camera):
		camera.global_position -= shift

	# 4. Shift Directional Sun Light
	if sun_light and is_instance_valid(sun_light):
		sun_light.global_position -= shift

	# 5. Shift Trajectory Renderer
	if trajectory_renderer and is_instance_valid(trajectory_renderer):
		trajectory_renderer.global_position -= shift

	emit_signal("origin_shifted", shift, universe_origin)

## Returns the true 64-bit position of the spacecraft in universe coordinates
func get_craft_universe_position() -> Vector3:
	if craft and is_instance_valid(craft):
		return universe_origin + craft.global_position
	return universe_craft_pos

## Returns the true 64-bit position of the planet in universe coordinates
func get_planet_universe_position() -> Vector3:
	if planet and is_instance_valid(planet):
		return universe_origin + planet.global_position
	return Vector3.ZERO
