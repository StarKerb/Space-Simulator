class_name SpacecraftOrbitScene
extends Node3D

## Flight Scene Controller for Real-Scale Apollo CSM Orbital Flight.
## Sets up Low Earth Orbit (LEO) at 300 km altitude, 1:1 Earth scale (R = 6,371 km),
## connects Patched Conics Trajectory Renderer, Floating Origin, Realtime Earth Rotation,
## and KSP-style Dual Timewarp (Physics Warp 1x-4x in atmosphere/burns, On-Rails 1x-1,000x in vacuum).

const OrbitalMechanics = preload("res://scripts/orbital_mechanics.gd")

@export var planet: Node3D
@export var craft: Spacecraft
@export var orbit_camera: OrbitCamera
@export var orbit_renderer: OrbitRenderer
@export var floating_origin: FloatingOriginManager
@export var flight_hud: FlightHUD

# Orbital Insertion Constants (Real Low Earth Orbit - LEO)
const ORBIT_ALTITUDE_METERS: float = 300000.0 # 300 km circular orbit
const EARTH_RADIUS_METERS: float = OrbitalMechanics.EARTH_RADIUS # 6,371,000.0 m
const ATMOSPHERE_ALTITUDE_THRESHOLD: float = 100000.0 # 100 km Karman line

# Real-time Earth Sidereal Rotation (23h 56m 4.09s = 86,164.09s per revolution)
const EARTH_SIDEREAL_ROTATION_SPEED: float = 7.2921159e-05 # rad/s

# KSP Timewarp System
const ON_RAILS_RATES: Array[float] = [1.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0]
const PHYSICS_WARP_RATES: Array[float] = [1.0, 2.0, 3.0, 4.0]

var current_on_rails_idx: int = 0
var current_physics_idx: int = 0
var current_timewarp: float = 1.0
var is_physics_warp: bool = false
var _is_on_rails: bool = false

# On-Rails Keplerian Timewarp State
var _locked_orbit: Dictionary = {}
var _warp_start_mean_anomaly: float = 0.0
var _warp_elapsed_time: float = 0.0
var _current_on_rails_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	_setup_orbital_insertion()

func _setup_orbital_insertion() -> void:
	if not craft or not planet:
		return

	# Configure Planet to exact real-life Earth scale without modifying planet.gd!
	planet.radius = EARTH_RADIUS_METERS
	planet.height_scale = 8848.0       # Mt. Everest topography scale
	planet.ocean_bed_sink = 4000.0     # Average ocean depth
	planet.ocean_altitude = 0.0

	planet.planet_spin_enabled = false
	# 100 km Karman line atmosphere (at 300 km LEO, craft is in true space above atmosphere)
	planet.atmosphere_scale = 1.0157
	planet.rayleigh_coeff = Vector3(5.8e-06, 1.35e-05, 3.31e-05)
	planet.scale_height_rayleigh = 0.001255 # 8 km scale height
	planet.mie_coeff = 4.0e-06
	planet.scale_height_mie = 0.000188      # 1.2 km scale height
	planet.sun_intensity = 1.3
	planet.cloud_day_brightness = 2.0
	planet.cloud_altitude = 2500.0
	planet.cloud_thickness = 3500.0
	planet.cloud_density = 0.55
	planet.cloud_coverage = 0.55
	planet.cloud_opacity = 1.2

	# Smooth atmosphere and ocean shell meshes and prevent frustum clipping at distance
	var atmo_node := planet.get_node_or_null("AtmosphereShell") as MeshInstance3D
	if atmo_node:
		atmo_node.extra_cull_margin = 100000000.0
		if atmo_node.mesh is SphereMesh:
			var sm := atmo_node.mesh as SphereMesh
			sm.radial_segments = 256
			sm.rings = 128

	var ocean_node := planet.get_node_or_null("OceanShell") as MeshInstance3D
	if ocean_node:
		ocean_node.extra_cull_margin = 100000000.0
		if ocean_node.mesh is SphereMesh:
			var om := ocean_node.mesh as SphereMesh
			om.radial_segments = 256
			om.rings = 128

	# Orbital Radius: r = R_earth + h = 6,671,000 m
	var orbital_radius: float = EARTH_RADIUS_METERS + ORBIT_ALTITUDE_METERS

	# Circular Orbital Velocity: v = sqrt(mu / r) = ~7,729.8 m/s
	var circular_speed: float = sqrt(OrbitalMechanics.EARTH_MU / orbital_radius)

	# Floating Origin Setup (Equatorial LEO):
	# Craft is at world origin (0, 0, 0).
	# Planet is centered at (0, 0, -orbital_radius), placing craft directly over the equator (+Z).
	craft.global_position = Vector3.ZERO
	planet.global_position = Vector3(0.0, 0.0, -orbital_radius)

	# Pass initial prograde orbital velocity (+X eastward) directly to craft physics solver
	craft.set_initial_orbital_velocity(Vector3(circular_speed, 0.0, 0.0))

	# Align craft attitude prograde:
	# Local +Y (capsule apex) points prograde along world +X
	# Local +X points North along world +Y
	# Local +Z points toward Earth nadir along world -Z
	craft.global_transform.basis = Basis(Vector3.UP, Vector3.RIGHT, -Vector3.BACK)

	# Assign references
	craft.planet = planet
	craft.mu = OrbitalMechanics.EARTH_MU
	craft.planet_radius = EARTH_RADIUS_METERS

	# Align DirectionalLight3D (Sun) in the equatorial plane shining on Earth
	var sun_light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not sun_light and planet.sun_light:
		sun_light = planet.sun_light as DirectionalLight3D
	if sun_light:
		# Position sun along +Z in equatorial plane behind craft
		sun_light.global_position = planet.global_position + Vector3(0.0, 0.0, 150000000.0)
		sun_light.look_at(planet.global_position, Vector3.UP)
		sun_light.light_energy = 1.0
		sun_light.shadow_enabled = false
		sun_light.light_cull_mask = 1

	# Add Planetshine Light: Earth-reflected diffuse radiance in LEO
	# STRICTLY isolated to Cull Mask 2 (CSM Hull on Layers 1 & 2) so Earth is never illuminated from behind!
	var planetshine := DirectionalLight3D.new()
	planetshine.name = "PlanetshineLight"
	planetshine.transform = Transform3D().looking_at(Vector3.BACK, Vector3.UP)
	planetshine.light_color = Color(0.55, 0.75, 1.0)
	planetshine.light_energy = 0.65
	planetshine.shadow_enabled = false
	planetshine.light_cull_mask = 2
	add_child(planetshine)

	if orbit_camera:
		orbit_camera.target = craft
		orbit_camera.distance = 22.0
		if flight_hud:
			orbit_camera.map_mode_toggled.connect(flight_hud.set_map_mode)

	if flight_hud:
		flight_hud.craft = craft
		flight_hud.set_timewarp(1.0, false)

	if floating_origin:
		floating_origin.craft = craft
		floating_origin.planet = planet
		floating_origin.camera = orbit_camera
		floating_origin.sun_light = sun_light
		floating_origin.trajectory_renderer = orbit_renderer

	if craft:
		craft.orbit_updated.connect(_on_orbit_updated)

func _get_altitude() -> float:
	if not craft or not planet:
		return 300000.0
	return (craft.global_position - planet.global_position).length() - EARTH_RADIUS_METERS

func _can_use_on_rails() -> bool:
	if not craft or not is_instance_valid(craft):
		return false
	return craft.current_throttle <= 0.001 and _get_altitude() > ATMOSPHERE_ALTITUDE_THRESHOLD

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Timewarp Up: Period (.) or Greater (>)
		if event.keycode == KEY_PERIOD:
			_step_warp_up()
		# Timewarp Down: Comma (,) or Less (<)
		elif event.keycode == KEY_COMMA:
			_step_warp_down()
		# Timewarp Reset: Slash (/)
		elif event.keycode == KEY_SLASH:
			_drop_to_realtime()

func _step_warp_up() -> void:
	if _can_use_on_rails():
		# Can safely use On-Rails timewarp
		if is_physics_warp:
			_exit_physics_warp()
		var next_idx := clampi(current_on_rails_idx + 1, 0, ON_RAILS_RATES.size() - 1)
		_enter_on_rails_warp(next_idx)
	else:
		# In atmosphere or firing engine: use Physics Warp (1x, 2x, 3x, 4x)
		if _is_on_rails:
			_exit_on_rails_warp()
		var next_p_idx := clampi(current_physics_idx + 1, 0, PHYSICS_WARP_RATES.size() - 1)
		_enter_physics_warp(next_p_idx)

func _step_warp_down() -> void:
	if is_physics_warp:
		var next_p_idx := clampi(current_physics_idx - 1, 0, PHYSICS_WARP_RATES.size() - 1)
		_enter_physics_warp(next_p_idx)
	elif _is_on_rails:
		var next_idx := clampi(current_on_rails_idx - 1, 0, ON_RAILS_RATES.size() - 1)
		_enter_on_rails_warp(next_idx)

func _drop_to_realtime() -> void:
	if _is_on_rails:
		_exit_on_rails_warp()
	if is_physics_warp:
		_exit_physics_warp()

func _enter_on_rails_warp(idx: int) -> void:
	current_on_rails_idx = idx
	current_timewarp = ON_RAILS_RATES[current_on_rails_idx]

	if current_timewarp > 1.0:
		if not _is_on_rails:
			_is_on_rails = true
			if craft and not craft.current_orbit.is_empty():
				craft.freeze = true
				craft.is_on_rails = true
				_locked_orbit = craft.current_orbit.duplicate(true)
				craft.locked_orbit = _locked_orbit
				var r_rel: Vector3 = craft.global_position - planet.global_position
				_warp_start_mean_anomaly = OrbitalMechanics.get_mean_anomaly_from_pos(_locked_orbit, r_rel)
				_warp_elapsed_time = 0.0
	else:
		_exit_on_rails_warp()

	if flight_hud:
		flight_hud.set_timewarp(current_timewarp, false)

func _exit_on_rails_warp() -> void:
	if not _is_on_rails:
		return
	_is_on_rails = false
	current_on_rails_idx = 0
	current_timewarp = 1.0

	if craft:
		craft.freeze = false
		craft.is_on_rails = false
		craft.pending_origin_shift = Vector3.ZERO
		craft.global_position = Vector3.ZERO
		if _current_on_rails_vel.length_squared() > 1.0:
			craft.set_initial_orbital_velocity(_current_on_rails_vel)
		if not _locked_orbit.is_empty():
			craft.current_orbit = _locked_orbit.duplicate(true)

	if flight_hud:
		flight_hud.set_timewarp(1.0, false)

func _enter_physics_warp(idx: int) -> void:
	current_physics_idx = idx
	var rate: float = PHYSICS_WARP_RATES[current_physics_idx]
	is_physics_warp = (current_physics_idx > 0)
	Engine.time_scale = rate
	current_timewarp = rate

	if flight_hud:
		flight_hud.set_timewarp(rate, is_physics_warp)

func _exit_physics_warp() -> void:
	current_physics_idx = 0
	is_physics_warp = false
	Engine.time_scale = 1.0
	current_timewarp = 1.0

	if flight_hud:
		flight_hud.set_timewarp(1.0, false)

func _physics_process(delta: float) -> void:
	# Auto-drop On-Rails timewarp if pilot ignites engine or descends into atmosphere
	if _is_on_rails:
		if not _can_use_on_rails():
			_drop_to_realtime()
			return

	# On-Rails Keplerian Orbit Propagation during High Timewarp (> 1x)
	# Guarantees zero numerical drift and mathematically perfect conservation of energy.
	# By keeping craft at (0, 0, 0) and setting planet to -pos, zero floating-origin shifts occur!
	if _is_on_rails and craft and planet and not _locked_orbit.is_empty():
		var warp_dt: float = delta * current_timewarp
		_warp_elapsed_time += warp_dt
		var state: Dictionary = OrbitalMechanics.evaluate_orbit_state(_locked_orbit, _warp_start_mean_anomaly, _warp_elapsed_time, OrbitalMechanics.EARTH_MU)

		craft.global_position = Vector3.ZERO
		planet.global_position = -state.pos
		_current_on_rails_vel = state.vel
		craft.current_physics_velocity = state.vel
		craft.current_orbit = _locked_orbit
		craft.pending_origin_shift = Vector3.ZERO

		# Keep craft oriented prograde if SAS is enabled during On-Rails warp
		if craft.sas_enabled and state.vel.length_squared() > 1.0:
			var fwd: Vector3 = state.vel.normalized()
			var up: Vector3 = state.pos.normalized()
			var right: Vector3 = up.cross(fwd).normalized()
			craft.global_transform.basis = Basis(right, fwd, -up)

func _process(delta: float) -> void:
	# Earth Realtime Sidereal Rotation synchronized with active timewarp rate
	var eff_rate: float = current_timewarp if _is_on_rails else Engine.time_scale
	planet.rotation.y += EARTH_SIDEREAL_ROTATION_SPEED * (delta * eff_rate)

	# Keep planet_center and planet_rotation uniforms synchronized on materials
	var atmo_node := planet.get_node_or_null("AtmosphereShell") as MeshInstance3D
	if atmo_node and atmo_node.material_override is ShaderMaterial:
		var sm := atmo_node.material_override as ShaderMaterial
		sm.set_shader_parameter("planet_center", planet.global_position)
		sm.set_shader_parameter("planet_rotation", planet.rotation.y)
	var ocean_node := planet.get_node_or_null("OceanShell") as MeshInstance3D
	if ocean_node and ocean_node.material_override is ShaderMaterial:
		(ocean_node.material_override as ShaderMaterial).set_shader_parameter("planet_center", planet.global_position)

	# Keep Trajectory Renderer updated with current Keplerian orbit
	if orbit_renderer and craft and planet and not craft.current_orbit.is_empty():
		var cam_pos: Vector3 = orbit_camera.global_position if orbit_camera else Vector3.ZERO
		var is_map: bool = orbit_camera.is_map_mode if orbit_camera else false
		orbit_renderer.update_orbit(craft.current_orbit, planet.global_position, cam_pos, craft.global_position, is_map)

func _on_orbit_updated(_orbit: Dictionary) -> void:
	pass
