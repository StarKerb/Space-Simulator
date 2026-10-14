class_name Spacecraft
extends RigidBody3D

## Apollo Command and Service Module (CSM) to 1:1 exact real scale.
## Powered by Jolt Physics with KSP flight controls, rock-solid attitude-lock SAS,
## physical SPS engine gimbal with Thrust Vector Control (TVC), and volumetric plume.

const OrbitalMechanics = preload("res://scripts/orbital_mechanics.gd")

signal throttle_changed(new_throttle: float)
signal orbit_updated(orbit_data: Dictionary)

# Real Apollo CSM Specifications:
const REAL_MASS_KG: float = 30300.0           # Total launch / orbital mass (kg)
const SPS_MAX_THRUST_N: float = 91200.0       # Aerojet AJ10-137 SPS thrust (91.2 kN)
const RCS_TORQUE_NM: float = 60000.0          # High-authority Reaction Control System torque (N*m)
const MAX_GIMBAL_ANGLE_RAD: float = deg_to_rad(6.5) # Physical SPS gimbal range (+/- 6.5 deg)

@export var planet: Node3D
@export var mu: float = OrbitalMechanics.EARTH_MU
@export var planet_radius: float = OrbitalMechanics.EARTH_RADIUS

# Flight Control State
var current_throttle: float = 0.0
var sas_enabled: bool = true
var is_engine_firing: bool = false
var initial_linear_velocity: Vector3 = Vector3.ZERO
var _is_first_physics_step: bool = true

# SAS Attitude Lock
var _sas_target_basis: Basis = Basis.IDENTITY
var _sas_target_initialized: bool = false
var _is_braking_to_lock: bool = false

# Engine Gimbal State
var _engine_gimbal_pivot: Node3D
var _current_gimbal_pitch: float = 0.0
var _current_gimbal_yaw: float = 0.0
var _pitch_input: float = 0.0
var _yaw_input: float = 0.0
var _roll_input: float = 0.0

# Internal references
var _plume_mesh: MeshInstance3D
var _plume_mat: ShaderMaterial
var _engine_light: OmniLight3D
var _throat_mat: StandardMaterial3D
var _rcs_particles: Array[GPUParticles3D] = []

# Orbital Mechanics Cache
var current_orbit: Dictionary = {}
var current_physics_velocity: Vector3 = Vector3.ZERO
var is_on_rails: bool = false
var locked_orbit: Dictionary = {}

# Floating Origin Integration
var pending_origin_shift: Vector3 = Vector3.ZERO
var pending_velocity_reset: bool = false

func _ready() -> void:
	# Configure RigidBody3D for Jolt Physics (true space vacuum, zero drag)
	mass = REAL_MASS_KG
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = true

	_build_apollo_csm_model()
	_build_collision_shapes()

func set_initial_orbital_velocity(v: Vector3) -> void:
	initial_linear_velocity = v
	linear_velocity = v
	current_physics_velocity = v
	pending_velocity_reset = true

func _process(delta: float) -> void:
	_handle_input(delta)
	_update_gimbal_visuals(delta)
	_update_visuals()
	if not is_on_rails:
		_update_orbit_data()

func _handle_input(delta: float) -> void:
	# Throttle Control (KSP-style: Shift/Ctrl, Z/X)
	var prev_throttle: float = current_throttle

	if Input.is_key_pressed(KEY_SHIFT):
		current_throttle = clampf(current_throttle + 0.45 * delta, 0.0, 1.0)
	if Input.is_key_pressed(KEY_CTRL):
		current_throttle = clampf(current_throttle - 0.45 * delta, 0.0, 1.0)
	if Input.is_key_pressed(KEY_Z):
		current_throttle = 1.0
	if Input.is_key_pressed(KEY_X):
		current_throttle = 0.0

	if not is_equal_approx(prev_throttle, current_throttle):
		emit_signal("throttle_changed", current_throttle)

	# Read manual attitude inputs
	_pitch_input = 0.0
	_yaw_input = 0.0
	_roll_input = 0.0

	# Pitch: W (pitch down), S (pitch up) around local X
	if Input.is_key_pressed(KEY_W): _pitch_input -= 1.0
	if Input.is_key_pressed(KEY_S): _pitch_input += 1.0

	# Yaw: A (yaw left), D (yaw right) around local Z
	if Input.is_key_pressed(KEY_A): _yaw_input += 1.0
	if Input.is_key_pressed(KEY_D): _yaw_input -= 1.0

	# Roll: Q (roll CCW), E (roll CW) around local Y
	if Input.is_key_pressed(KEY_Q): _roll_input += 1.0
	if Input.is_key_pressed(KEY_E): _roll_input -= 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			sas_enabled = not sas_enabled
			if sas_enabled:
				_sas_target_basis = global_transform.basis
				_sas_target_initialized = true

func _update_gimbal_visuals(delta: float) -> void:
	# Corrected visual deflection:
	# Pitch Up (S key): Nozzle tilts aft down (-target_pitch)
	# Pitch Down (W key): Nozzle tilts aft up (+target_pitch)
	# Yaw Left (A key): Nozzle tilts aft right (+target_yaw)
	# Yaw Right (D key): Nozzle tilts aft left (-target_yaw)
	var target_pitch: float = -_pitch_input * MAX_GIMBAL_ANGLE_RAD
	var target_yaw: float = _yaw_input * MAX_GIMBAL_ANGLE_RAD

	_current_gimbal_pitch = lerpf(_current_gimbal_pitch, target_pitch, clampf(delta * 14.0, 0.0, 1.0))
	_current_gimbal_yaw = lerpf(_current_gimbal_yaw, target_yaw, clampf(delta * 14.0, 0.0, 1.0))

	if _engine_gimbal_pivot:
		_engine_gimbal_pivot.transform.basis = Basis.from_euler(Vector3(_current_gimbal_pitch, 0.0, _current_gimbal_yaw))

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Apply initial orbital velocity directly to Jolt physics state
	if pending_velocity_reset or (_is_first_physics_step and initial_linear_velocity.length_squared() > 1.0):
		state.linear_velocity = initial_linear_velocity
		current_physics_velocity = initial_linear_velocity
		pending_velocity_reset = false
		_is_first_physics_step = false

	# Handle Floating Origin Shift (teleport cleanly in Jolt physics solver)
	if pending_origin_shift.length_squared() > 0.0001:
		var cur_xf := state.transform
		cur_xf.origin -= pending_origin_shift
		state.transform = cur_xf
		pending_origin_shift = Vector3.ZERO

	# 1. Newtonian Central Gravity from Earth
	if planet and is_instance_valid(planet):
		var to_planet: Vector3 = planet.global_position - state.transform.origin
		var dist: float = to_planet.length()
		if dist > 100.0:
			var grav_accel: Vector3 = to_planet.normalized() * (mu / (dist * dist))
			state.linear_velocity += grav_accel * state.step

	current_physics_velocity = state.linear_velocity

	# 2. SPS Engine Thrust with Physical Gimbal Thrust Vector Control (TVC)
	is_engine_firing = current_throttle > 0.001
	if is_engine_firing:
		var thrust_dir_world := state.transform.basis * Vector3.UP
		state.apply_central_force(thrust_dir_world * (SPS_MAX_THRUST_N * current_throttle))

		# Physical TVC steering torque proportional to gimbal nozzle angle:
		var tvc_pitch_torque: float = -_current_gimbal_pitch / MAX_GIMBAL_ANGLE_RAD * (SPS_MAX_THRUST_N * 0.15 * current_throttle)
		var tvc_yaw_torque: float = _current_gimbal_yaw / MAX_GIMBAL_ANGLE_RAD * (SPS_MAX_THRUST_N * 0.15 * current_throttle)
		state.apply_torque(state.transform.basis * Vector3(tvc_pitch_torque, 0.0, tvc_yaw_torque))

	# 3. KSP Attitude Control (WASD + QE) and Rock-Solid Attitude Lock
	var has_manual_attitude: bool = absf(_pitch_input) > 0.1 or absf(_yaw_input) > 0.1 or absf(_roll_input) > 0.1

	if has_manual_attitude:
		# Manual RCS steering: apply torque in local craft frame
		_is_braking_to_lock = true
		var torque_local := Vector3(
			_pitch_input * RCS_TORQUE_NM,
			_roll_input * RCS_TORQUE_NM * 0.8,
			_yaw_input * RCS_TORQUE_NM
		)
		var torque_world: Vector3 = state.transform.basis * torque_local
		state.apply_torque(torque_world)
	elif sas_enabled:
		if not _sas_target_initialized:
			_sas_target_basis = state.transform.basis
			_sas_target_initialized = true
			_is_braking_to_lock = false

		if _is_braking_to_lock:
			# Pilot just released manual steering:
			# Actively brake angular velocity to a smooth zero with opposing RCS torque.
			# Zero snapping back, zero reverse-pulling!
			var ang_speed := state.angular_velocity.length()
			if ang_speed > 0.025:
				var brake_torque: Vector3 = -state.angular_velocity * (RCS_TORQUE_NM * 4.5)
				state.apply_torque(brake_torque)
			else:
				# Rotation stopped: lock new attitude!
				_sas_target_basis = state.transform.basis
				_is_braking_to_lock = false
		else:
			# Hold locked attitude with exact Angle-Axis PD Controller (critically damped)
			var rot_diff: Basis = _sas_target_basis * state.transform.basis.inverse()
			var q := rot_diff.get_rotation_quaternion()
			if q.w < 0.0:
				q = -q

			var sin_half := sqrt(q.x * q.x + q.y * q.y + q.z * q.z)
			var err_axis := Vector3.ZERO
			if sin_half > 1e-5:
				var angle := 2.0 * atan2(sin_half, q.w)
				err_axis = Vector3(q.x, q.y, q.z) * (angle / sin_half)

			var kp: float = RCS_TORQUE_NM * 2.2
			var kd: float = RCS_TORQUE_NM * 4.8 # Critically damped for 30,300 kg mass
			var sas_torque: Vector3 = (err_axis * kp) - (state.angular_velocity * kd)
			state.apply_torque(sas_torque)

func _update_visuals() -> void:
	# Update Volumetric Plume Shader Uniform
	if _plume_mat:
		_plume_mat.set_shader_parameter("throttle", current_throttle)

	# Update Engine Light & Emissive Throat
	if _engine_light:
		_engine_light.visible = current_throttle > 0.01
		_engine_light.light_energy = current_throttle * 4.0

	if _throat_mat:
		_throat_mat.emission_energy_multiplier = current_throttle * 4.5

func _update_orbit_data() -> void:
	if not planet or not is_instance_valid(planet):
		return

	var r_vec: Vector3 = global_position - planet.global_position
	var v_vec: Vector3 = current_physics_velocity if current_physics_velocity.length_squared() > 1.0 else linear_velocity
	current_orbit = OrbitalMechanics.calculate_orbit(r_vec, v_vec, mu, planet_radius)
	emit_signal("orbit_updated", current_orbit)

## Builds the Apollo CSM 3D Geometry to exact real scale (meters)
func _build_apollo_csm_model() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "ApolloCSM_Visuals"
	add_child(visual_root)

	# Local Reflection Probe for real-time planetshine and Earth reflections in hull
	var probe := ReflectionProbe.new()
	probe.name = "CraftReflectionProbe"
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	probe.size = Vector3(100.0, 100.0, 100.0)
	probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	probe.max_distance = 50000000.0
	visual_root.add_child(probe)

	# -------------------------------------------------------------
	# 1. SERVICE MODULE (SM) - Cylindrical Body
	# Diameter: 3.90 m (R = 1.95 m), Height: 4.00 m (Y: -2.0 to +2.0)
	# -------------------------------------------------------------
	var sm_mesh := CylinderMesh.new()
	sm_mesh.top_radius = 1.95
	sm_mesh.bottom_radius = 1.95
	sm_mesh.height = 4.0
	sm_mesh.radial_segments = 48
	sm_mesh.rings = 4

	var sm_mat := StandardMaterial3D.new()
	sm_mat.albedo_color = Color(0.92, 0.93, 0.96) # Off-white radiator skin
	sm_mat.metallic = 0.35
	sm_mat.roughness = 0.25
	sm_mat.clearcoat_enabled = true
	sm_mat.clearcoat = 0.5
	sm_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var sm_node := MeshInstance3D.new()
	sm_node.name = "ServiceModule"
	sm_node.mesh = sm_mesh
	sm_node.material_override = sm_mat
	sm_node.position = Vector3(0, 0, 0)
	visual_root.add_child(sm_node)

	_build_sm_details(visual_root)

	# -------------------------------------------------------------
	# 2. COMMAND MODULE (CM) - Conical Capsule
	# Base Diameter: 3.90 m (R = 1.95 m), Apex Diameter: 0.76 m (R = 0.38 m)
	# Height: 3.23 m (Y: +2.00 to +5.23)
	# Authentic aluminized Kapton mirror finish with chrome reflectivity
	# -------------------------------------------------------------
	var cm_mesh := CylinderMesh.new()
	cm_mesh.top_radius = 0.38
	cm_mesh.bottom_radius = 1.95
	cm_mesh.height = 3.23
	cm_mesh.radial_segments = 48
	cm_mesh.rings = 6

	var cm_mat := StandardMaterial3D.new()
	cm_mat.albedo_color = Color(0.92, 0.92, 0.94)
	cm_mat.metallic = 0.95
	cm_mat.roughness = 0.08
	cm_mat.clearcoat_enabled = true
	cm_mat.clearcoat = 1.0
	cm_mat.clearcoat_roughness = 0.05
	cm_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var cm_node := MeshInstance3D.new()
	cm_node.name = "CommandModule"
	cm_node.mesh = cm_mesh
	cm_node.material_override = cm_mat
	cm_node.position = Vector3(0, 2.0 + 3.23 * 0.5, 0)
	visual_root.add_child(cm_node)

	# Docking Probe Mechanism at Apex
	var probe_mesh := CylinderMesh.new()
	probe_mesh.top_radius = 0.15
	probe_mesh.bottom_radius = 0.38
	probe_mesh.height = 0.65
	probe_mesh.radial_segments = 24

	var probe_mat := StandardMaterial3D.new()
	probe_mat.albedo_color = Color(0.3, 0.3, 0.32)
	probe_mat.metallic = 0.9
	probe_mat.roughness = 0.2
	probe_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var probe_node := MeshInstance3D.new()
	probe_node.name = "DockingProbe"
	probe_node.mesh = probe_mesh
	probe_node.material_override = probe_mat
	probe_node.position = Vector3(0, 5.23 + 0.32, 0)
	visual_root.add_child(probe_node)

	# -------------------------------------------------------------
	# 3. SPS ENGINE GIMBAL ASSEMBLY
	# Pivots around Y = -2.00 (base of Service Module)
	# -------------------------------------------------------------
	_engine_gimbal_pivot = Node3D.new()
	_engine_gimbal_pivot.name = "EngineGimbalPivot"
	_engine_gimbal_pivot.position = Vector3(0, -2.0, 0)
	visual_root.add_child(_engine_gimbal_pivot)

	# SPS Curved Cone Rao Bell Nozzle
	var bell_mesh := _generate_bell_nozzle_mesh(0.20, 1.25, 2.80, 0.0)
	var bell_mat := StandardMaterial3D.new()
	bell_mat.albedo_color = Color(0.22, 0.22, 0.25)
	bell_mat.metallic = 0.95
	bell_mat.roughness = 0.20
	bell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bell_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var bell_node := MeshInstance3D.new()
	bell_node.name = "SPSEngineBell"
	bell_node.mesh = bell_mesh
	bell_node.material_override = bell_mat
	_engine_gimbal_pivot.add_child(bell_node)

	# Glowing Throat Disc
	var throat_mesh := CylinderMesh.new()
	throat_mesh.top_radius = 0.19
	throat_mesh.bottom_radius = 0.19
	throat_mesh.height = 0.05
	throat_mesh.radial_segments = 24

	_throat_mat = StandardMaterial3D.new()
	_throat_mat.albedo_color = Color(1.0, 0.4, 0.1)
	_throat_mat.emission_enabled = true
	_throat_mat.emission = Color(1.0, 0.6, 0.2)
	_throat_mat.emission_energy_multiplier = 0.0
	_throat_mat.render_priority = 11
	_throat_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var throat_node := MeshInstance3D.new()
	throat_node.name = "EngineThroat"
	throat_node.mesh = throat_mesh
	throat_node.material_override = _throat_mat
	throat_node.position = Vector3(0, -0.05, 0)
	_engine_gimbal_pivot.add_child(throat_node)

	# Volumetric Engine Plume (Attached at nozzle exit: local Y = -2.80)
	_build_volumetric_plume(_engine_gimbal_pivot, -2.80, 14.0, 1.25, 4.8)

	# -------------------------------------------------------------
	# 4. RCS QUAD THRUSTER PODS
	# -------------------------------------------------------------
	_build_rcs_quads(visual_root)

	# Assign visual meshes to layers 1 & 2 (layers = 3) to receive planetshine without affecting Earth
	_set_node_layers_recursive(visual_root, 3)

func _set_node_layers_recursive(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		_set_node_layers_recursive(child, layer_mask)

func _build_sm_details(parent: Node3D) -> void:
	# 4 vertical panel dividers
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 3.8, 0.08)
		strip.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.32, 0.35)
		strip.material_override = mat
		strip.position = Vector3(sin(angle) * 1.96, 0.0, cos(angle) * 1.96)
		strip.rotation.y = angle
		parent.add_child(strip)

	# High Gain S-Band Antenna on Aft Bulkhead
	var ant_pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.03
	pole_mesh.bottom_radius = 0.03
	pole_mesh.height = 1.2
	ant_pole.mesh = pole_mesh
	ant_pole.position = Vector3(1.6, -2.6, 0.6)
	ant_pole.rotation.z = deg_to_rad(-25.0)
	parent.add_child(ant_pole)

	for dish_idx in range(4):
		var dish := MeshInstance3D.new()
		var dish_mesh := CylinderMesh.new()
		dish_mesh.top_radius = 0.35
		dish_mesh.bottom_radius = 0.05
		dish_mesh.height = 0.12
		dish.mesh = dish_mesh
		var d_ang := float(dish_idx) * PI * 0.5
		dish.position = Vector3(1.8 + cos(d_ang) * 0.35, -3.2, 0.6 + sin(d_ang) * 0.35)
		dish.rotation.z = deg_to_rad(-65.0)
		parent.add_child(dish)

func _build_rcs_quads(parent: Node3D) -> void:
	for i in range(4):
		var angle: float = float(i) * PI * 0.5 + PI * 0.25
		var q_root := Node3D.new()
		q_root.name = "RCSQuad_%d" % i
		q_root.position = Vector3(sin(angle) * 1.95, 0.8, cos(angle) * 1.95)
		q_root.rotation.y = angle
		parent.add_child(q_root)

		var block := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.25, 0.25, 0.18)
		block.mesh = b_box
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.2, 0.2, 0.22)
		b_mat.metallic = 0.8
		block.material_override = b_mat
		q_root.add_child(block)

		var dirs := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT]
		for d in dirs:
			var n_mi := MeshInstance3D.new()
			var n_mesh := CylinderMesh.new()
			n_mesh.top_radius = 0.04
			n_mesh.bottom_radius = 0.015
			n_mesh.height = 0.12
			n_mesh.radial_segments = 12
			n_mi.mesh = n_mesh
			n_mi.position = d * 0.14
			if d == Vector3.UP: n_mi.rotation.x = 0
			elif d == Vector3.DOWN: n_mi.rotation.x = PI
			elif d == Vector3.LEFT: n_mi.rotation.z = PI * 0.5
			elif d == Vector3.RIGHT: n_mi.rotation.z = -PI * 0.5
			q_root.add_child(n_mi)

## Generates a mathematically accurate flared Rao bell nozzle (curved cone)
func _generate_bell_nozzle_mesh(r_throat: float, r_exit: float, length: float, y_start: float) -> ArrayMesh:
	var rings: int = 32
	var segments: int = 48

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs   := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var y: float = y_start - length * t
		var r: float = r_throat + (r_exit - r_throat) * pow(t, 0.65)
		var dr_dt: float = 0.65 * (r_exit - r_throat) * pow(max(1e-4, t), -0.35) / length

		for j in range(segments + 1):
			var u: float = float(j) / float(segments)
			var phi: float = u * 2.0 * PI
			var cos_p: float = cos(phi)
			var sin_p: float = sin(phi)

			var pos := Vector3(r * cos_p, y, r * sin_p)
			var norm := Vector3(cos_p, dr_dt, sin_p).normalized()

			verts.append(pos)
			norms.append(norm)
			uvs.append(Vector2(u, t))

	for i in range(rings):
		for j in range(segments):
			var i0: int = i * (segments + 1) + j
			var i1: int = i0 + 1
			var i2: int = (i + 1) * (segments + 1) + j
			var i3: int = i2 + 1

			indices.append(i0); indices.append(i2); indices.append(i1)
			indices.append(i1); indices.append(i2); indices.append(i3)

	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func _build_volumetric_plume(parent: Node3D, y_exit: float, length: float, r_exit: float, r_plume_max: float) -> void:
	var plume_mesh := _generate_expanding_plume_mesh(r_exit, r_plume_max, length, y_exit)

	_plume_mat = ShaderMaterial.new()
	var plume_shader := load("res://shaders/rocket_plume.gdshader") as Shader
	_plume_mat.shader = plume_shader
	_plume_mat.render_priority = 12
	_plume_mat.set_shader_parameter("throttle", 0.0)
	_plume_mat.set_shader_parameter("expansion_factor", 1.8)
	_plume_mat.set_shader_parameter("plume_color_core", Color(1.2, 0.95, 0.8, 1.0))
	_plume_mat.set_shader_parameter("plume_color_outer", Color(0.4, 0.6, 1.0, 0.75))

	_plume_mesh = MeshInstance3D.new()
	_plume_mesh.name = "VolumetricPlume"
	_plume_mesh.mesh = plume_mesh
	_plume_mesh.material_override = _plume_mat
	_plume_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_plume_mesh)

	_engine_light = OmniLight3D.new()
	_engine_light.name = "EnginePlumeLight"
	_engine_light.light_color = Color(1.0, 0.65, 0.35)
	_engine_light.light_energy = 0.0
	_engine_light.omni_range = 35.0
	_engine_light.position = Vector3(0, y_exit - 1.5, 0)
	parent.add_child(_engine_light)

func _generate_expanding_plume_mesh(r_start: float, r_max: float, length: float, y_top: float) -> ArrayMesh:
	var rings: int = 36
	var segments: int = 40

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs   := PackedVector2Array()
	var indices := PackedInt32Array()

	# Layer 1: Outer expansion mantle
	for i in range(rings + 1):
		var v_frac: float = float(i) / float(rings)
		var y: float = y_top - length * v_frac
		var r: float = r_start + (r_max - r_start) * sqrt(v_frac)

		for j in range(segments + 1):
			var u_frac: float = float(j) / float(segments)
			var angle: float = u_frac * 2.0 * PI
			var cp: float = cos(angle)
			var sp: float = sin(angle)

			verts.append(Vector3(r * cp, y, r * sp))
			norms.append(Vector3(cp, 0.0, sp))
			uvs.append(Vector2(u_frac, v_frac))

	for i in range(rings):
		for j in range(segments):
			var row1: int = i * (segments + 1)
			var row2: int = (i + 1) * (segments + 1)
			var a: int = row1 + j
			var b: int = row1 + j + 1
			var c: int = row2 + j
			var d: int = row2 + j + 1
			indices.append(a); indices.append(b); indices.append(c)
			indices.append(b); indices.append(d); indices.append(c)
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)

	# Layer 2: Inner Mach Core
	var v_offset: int = verts.size()
	var r_core_start: float = r_start * 0.65
	var r_core_max: float = r_max * 0.45
	var core_len: float = length * 0.70

	for i in range(rings + 1):
		var v_frac: float = float(i) / float(rings)
		var y: float = y_top - core_len * v_frac
		var r_core: float = r_core_start + (r_core_max - r_core_start) * v_frac

		for j in range(segments + 1):
			var u_frac: float = float(j) / float(segments)
			var angle: float = u_frac * 2.0 * PI
			var cp: float = cos(angle)
			var sp: float = sin(angle)

			verts.append(Vector3(r_core * cp, y, r_core * sp))
			norms.append(Vector3(cp, 0.0, sp))
			uvs.append(Vector2(u_frac, v_frac * 0.7))

	for i in range(rings):
		for j in range(segments):
			var row1: int = v_offset + i * (segments + 1)
			var row2: int = v_offset + (i + 1) * (segments + 1)
			var a: int = row1 + j
			var b: int = row1 + j + 1
			var c: int = row2 + j
			var d: int = row2 + j + 1
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
			indices.append(a); indices.append(b); indices.append(c)
			indices.append(b); indices.append(d); indices.append(c)

	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func _build_collision_shapes() -> void:
	var sm_col := CollisionShape3D.new()
	sm_col.name = "SM_Collision"
	var sm_shape := CylinderShape3D.new()
	sm_shape.radius = 1.95
	sm_shape.height = 4.0
	sm_col.shape = sm_shape
	sm_col.position = Vector3(0, 0, 0)
	add_child(sm_col)

	var cm_col := CollisionShape3D.new()
	cm_col.name = "CM_Collision"
	var cm_shape := CylinderShape3D.new()
	cm_shape.radius = 1.6
	cm_shape.height = 3.23
	cm_col.shape = cm_shape
	cm_col.position = Vector3(0, 3.615, 0)
	add_child(cm_col)
