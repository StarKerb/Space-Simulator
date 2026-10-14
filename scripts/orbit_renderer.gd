class_name OrbitRenderer
extends Node3D

## Visualizes the 3D Keplerian Orbit Trajectory (Patched Conics) and Pe/Ap markers.
## STRICTLY active in Map Mode only (M key). Zero visual clutter in Flight Mode.

const OrbitalMechanics = preload("res://scripts/orbital_mechanics.gd")

@export var line_color: Color = Color(0.2, 0.9, 1.0, 0.95)
@export var pe_color: Color = Color(0.1, 1.0, 0.5, 1.0)
@export var ap_color: Color = Color(1.0, 0.65, 0.1, 1.0)
@export var craft_marker_color: Color = Color(0.35, 0.9, 1.0, 1.0)

var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _ribbon_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D

var _pe_marker: MeshInstance3D
var _ap_marker: MeshInstance3D
var _pe_label: Label3D
var _ap_label: Label3D

var _craft_marker: MeshInstance3D
var _craft_label: Label3D

func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()

	# Shaded-independent transparent ribbon material
	_ribbon_mat = StandardMaterial3D.new()
	_ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ribbon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ribbon_mat.albedo_color = line_color
	_ribbon_mat.no_depth_test = true
	_ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon_mat.render_priority = 110

	# Bright central core line
	_line_mat = StandardMaterial3D.new()
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	_line_mat.no_depth_test = true
	_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_mat.render_priority = 111

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TrajectoryPath"
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.extra_cull_margin = 100000000.0
	add_child(_mesh_instance)

	# Periapsis marker & label
	_pe_marker = _create_billboard_marker(pe_color, "PeMarker")
	_pe_label = _create_label3d(pe_color, "PeLabel")
	add_child(_pe_marker)
	add_child(_pe_label)

	# Apoapsis marker & label
	_ap_marker = _create_billboard_marker(ap_color, "ApMarker")
	_ap_label = _create_label3d(ap_color, "ApLabel")
	add_child(_ap_marker)
	add_child(_ap_label)

	# Spacecraft Map Marker & label
	_craft_marker = _create_billboard_marker(craft_marker_color, "CraftMarker")
	_craft_label = _create_label3d(craft_marker_color, "CraftLabel")
	_craft_label.text = "APOLLO CSM"
	add_child(_craft_marker)
	add_child(_craft_label)

func _create_billboard_marker(col: Color, n_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mi.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 120
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 100000000.0
	mi.visible = false
	return mi

func _create_label3d(col: Color, l_name: String) -> Label3D:
	var lbl := Label3D.new()
	lbl.name = l_name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = col
	lbl.outline_modulate = Color(0, 0, 0, 0.95)
	lbl.outline_size = 8
	lbl.font_size = 32
	lbl.pixel_size = 200.0
	lbl.render_priority = 125
	lbl.visible = false
	return lbl

## Updates the rendered trajectory with new Keplerian orbital elements
func update_orbit(
	orbit: Dictionary,
	planet_center_global: Vector3,
	camera_pos_global: Vector3,
	craft_pos_global: Vector3 = Vector3.ZERO,
	is_map_mode: bool = false
) -> void:
	if not _immediate_mesh:
		return

	# STRICT FLIGHT MODE SEPARATION:
	# If NOT in Map Mode, completely hide the orbit line and all markers!
	if not is_map_mode:
		_immediate_mesh.clear_surfaces()
		_pe_marker.visible = false
		_pe_label.visible = false
		_ap_marker.visible = false
		_ap_label.visible = false
		_craft_marker.visible = false
		_craft_label.visible = false
		return

	global_position = planet_center_global

	var pts: PackedVector3Array = OrbitalMechanics.generate_trajectory_points(orbit, 256)
	_immediate_mesh.clear_surfaces()

	var num_pts: int = pts.size()
	var cam_pos_local: Vector3 = camera_pos_global - planet_center_global
	var d_cam: float = cam_pos_local.length()

	if num_pts >= 4:
		# Ribbon width scales smoothly with camera distance for constant crisp screen presence
		var ribbon_width: float = clampf(d_cam * 0.0016, 1000.0, 30000.0)

		# 1. TRIANGLE STRIP CAMERA-FACING RIBBON
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _ribbon_mat)
		for i in range(num_pts):
			var p: Vector3 = pts[i]
			var p_next: Vector3 = pts[(i + 1) % num_pts]
			var tangent: Vector3 = (p_next - p).normalized()
			var to_cam: Vector3 = (cam_pos_local - p).normalized()
			var side: Vector3 = tangent.cross(to_cam).normalized() * ribbon_width
			if side.length_squared() < 0.01:
				side = Vector3.UP * ribbon_width

			_immediate_mesh.surface_add_vertex(p - side)
			_immediate_mesh.surface_add_vertex(p + side)

		# Close the loop
		var p0: Vector3 = pts[0]
		var p1: Vector3 = pts[1]
		var t0: Vector3 = (p1 - p0).normalized()
		var to_cam0: Vector3 = (cam_pos_local - p0).normalized()
		var side0: Vector3 = t0.cross(to_cam0).normalized() * ribbon_width
		_immediate_mesh.surface_add_vertex(p0 - side0)
		_immediate_mesh.surface_add_vertex(p0 + side0)
		_immediate_mesh.surface_end()

		# 2. BRIGHT CENTRAL CORE LINE
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_mat)
		for p in pts:
			_immediate_mesh.surface_add_vertex(p)
		_immediate_mesh.surface_add_vertex(pts[0])
		_immediate_mesh.surface_end()

	# Marker dimensions in Map Mode
	var marker_diameter: float = clampf(d_cam * 0.022, 5000.0, 200000.0)
	var label_pixel_size: float = clampf(d_cam * 0.00012, 50.0, 1200.0)
	var label_offset: Vector3 = Vector3(0.0, marker_diameter * 0.8, 0.0)

	var e: float = orbit.get("eccentricity", 0.0)
	var pe_alt: float = orbit.get("periapsis_alt", 0.0)
	var ap_alt: float = orbit.get("apoapsis_alt", 0.0)
	var pe_pos: Vector3 = orbit.get("periapsis_pos", Vector3.ZERO)
	var ap_pos: Vector3 = orbit.get("apoapsis_pos", Vector3.ZERO)

	# Periapsis Marker & Label
	if pe_pos.length_squared() > 1000.0:
		_pe_marker.visible = true
		_pe_marker.position = pe_pos
		_pe_marker.scale = Vector3.ONE * marker_diameter
		_pe_label.visible = true
		_pe_label.position = pe_pos + label_offset
		_pe_label.pixel_size = label_pixel_size
		_pe_label.text = "Pe: %.1f km" % (pe_alt / 1000.0)
	else:
		_pe_marker.visible = false
		_pe_label.visible = false

	# Apoapsis Marker & Label
	if e < 0.999 and ap_pos.length_squared() > 1000.0:
		_ap_marker.visible = true
		_ap_marker.position = ap_pos
		_ap_marker.scale = Vector3.ONE * marker_diameter
		_ap_label.visible = true
		_ap_label.position = ap_pos + label_offset
		_ap_label.pixel_size = label_pixel_size
		_ap_label.text = "Ap: %.1f km" % (ap_alt / 1000.0)
	else:
		_ap_marker.visible = false
		_ap_label.visible = false

	# Spacecraft Map Marker & Label
	if craft_pos_global.length_squared() > 0.001 or craft_pos_global == Vector3.ZERO:
		var craft_rel_planet: Vector3 = craft_pos_global - planet_center_global
		_craft_marker.visible = true
		_craft_marker.position = craft_rel_planet
		_craft_marker.scale = Vector3.ONE * marker_diameter
		_craft_label.visible = true
		_craft_label.position = craft_rel_planet + label_offset
		_craft_label.pixel_size = label_pixel_size
	else:
		_craft_marker.visible = false
		_craft_label.visible = false
