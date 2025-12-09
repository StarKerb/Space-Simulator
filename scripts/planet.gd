@tool
extends Node3D

@export_group("Settings")
@export var planet_radius: float = 600.0 : set = _set_radius
@export var base_resolution: int = 16
@export var max_lod: int = 6 
@export var lod_distance: float = 2000.0 

@export_group("Editor Controls")
@export var spawn_planet: bool = false : set = _force_spawn_base
@export var live_update: bool = false
@export var update_once: bool = false : set = _trigger_lod_update

@export_group("Maps")
@export var color_map: Texture2D : set = _set_color_map
@export var specular_map: Texture2D : set = _set_specular_map
@export var height_map: Texture2D : set = _set_height_map
@export var height_intensity: float = 20.0 : set = _set_height_val
@export_range(0.0, 1.0) var roughness_base: float = 1.0 : set = _set_roughness

var camera: Camera3D
var terrain: Node3D
var height_image: Image 
var _editor_timer: float = 0.0

# --- SHADER CODE ---
const PLANET_SHADER = """
shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap;
uniform sampler2D specular_map : hint_default_white, filter_linear_mipmap;
uniform float roughness_base : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_local_pos;

void vertex() {
    v_local_pos = VERTEX;
}

void fragment() {
    vec3 n = normalize(v_local_pos);
    float u = atan(n.x, n.z) / (2.0 * PI) + 0.5;
    float v = asin(n.y) / PI + 0.5;
    u = u + 0.5;
    v = 1.0 - v; 
    vec2 uv = vec2(u, v);
    ALBEDO = texture(color_map, uv).rgb;
    float spec_val = texture(specular_map, uv).r;
    ROUGHNESS = mix(roughness_base, 0.05, spec_val); 
}
"""

class Patch:
	var face_normal: Vector3
	var axis_a: Vector3
	var axis_b: Vector3
	var depth: int
	var x0: float
	var y0: float
	var size: float
	var node: MeshInstance3D
	var children := []
	var parent: Patch
	var center_point: Vector3 

	func _init(_normal, _x0, _y0, _size, _depth):
		face_normal = _normal
		depth = _depth
		x0 = _x0
		y0 = _y0
		size = _size

	func set_axes():
		axis_a = Vector3(face_normal.y, face_normal.z, face_normal.x)
		axis_b = face_normal.cross(axis_a)

var patches: Array = []

func _ready():
	if not Engine.is_editor_hint():
		_init_terrain_node()
		call_deferred("_init_patches")

func _process(delta):
	if Engine.is_editor_hint():
		if not live_update: return
		_editor_timer += delta
		if _editor_timer < 0.1: return 
		_editor_timer = 0.0
	
	_find_camera()
	if camera:
		_update_lod()

# --- SETTERS ---
func _set_radius(val):
	planet_radius = val
	if live_update and terrain: _init_patches()

func _set_color_map(val):
	color_map = val
	if live_update and terrain: _init_patches()

func _set_specular_map(val):
	specular_map = val
	if live_update and terrain: _init_patches()

func _set_height_map(val):
	height_map = val
	if live_update and terrain: _init_patches()

func _set_height_val(val):
	height_intensity = val
	if live_update and terrain: _init_patches()

func _set_roughness(val):
	roughness_base = val
	if live_update and terrain: _init_patches()

# --- BUTTONS ---
func _force_spawn_base(val):
	if val:
		spawn_planet = false 
		_init_terrain_node()
		_init_patches()

func _trigger_lod_update(val):
	if val:
		update_once = false 
		_find_camera()
		if camera: _update_lod()

# --- LOGIC ---
func _find_camera():
	if Engine.is_editor_hint():
		var vp = EditorInterface.get_editor_viewport_3d(0)
		if vp: camera = vp.get_camera_3d()
	else:
		var vp = get_viewport()
		if vp: camera = vp.get_camera_3d()

func _init_terrain_node():
	if has_node("Terrain"):
		terrain = get_node("Terrain")
	else:
		terrain = Node3D.new()
		terrain.name = "Terrain"
		add_child(terrain)

func _init_patches():
	if not terrain: _init_terrain_node()
	for c in terrain.get_children():
		c.queue_free()
	patches.clear()
	
	# --- TIFF SUPPORT FIX ---
	if height_map:
		height_image = height_map.get_image()
		# Safety check: Decompress if Godot imported it as VRAM compressed
		if height_image and height_image.is_compressed():
			height_image.decompress()
		# Double safety: If get_image failed (null), ensure we don't crash
		if height_image and height_image.is_empty():
			printerr("Warning: Height map image is empty. Check Import settings.")
			height_image = null
	else:
		height_image = null

	var dirs = [
		Vector3(1,0,0), Vector3(-1,0,0),
		Vector3(0,1,0), Vector3(0,-1,0),
		Vector3(0,0,1), Vector3(0,0,-1)
	]

	for i in range(6):
		var p = Patch.new(dirs[i], 0.0, 0.0, 1.0, 0)
		p.set_axes()
		p.center_point = _calculate_patch_center(p) 
		_make_patch_node(p)
		patches.append(p)

func _calculate_patch_center(patch: Patch) -> Vector3:
	var cx = patch.x0 + (patch.size * 0.5)
	var cy = patch.y0 + (patch.size * 0.5)
	var point_on_cube = patch.face_normal + (cx - 0.5) * 2.0 * patch.axis_a + (cy - 0.5) * 2.0 * patch.axis_b
	return point_on_cube.normalized() * planet_radius

func _make_patch_node(patch: Patch):
	var node := MeshInstance3D.new()
	node.name = "Patch_d%d" % patch.depth
	terrain.add_child(node)
	patch.node = node
	_update_patch_mesh(patch)

func _update_patch_mesh(patch: Patch):
	var res = base_resolution 
	var mesh = _build_patch_mesh(patch.face_normal, patch.axis_a, patch.axis_b, patch.x0, patch.y0, patch.size, res)
	patch.node.mesh = mesh

	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = PLANET_SHADER
	if color_map: mat.set_shader_parameter("color_map", color_map)
	if specular_map: mat.set_shader_parameter("specular_map", specular_map)
	mat.set_shader_parameter("roughness_base", roughness_base)
	
	patch.node.set_surface_override_material(0, mat)

func _build_patch_mesh(normal, axis_a, axis_b, x0, y0, size, res) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()

	var r_minus_1 = float(res - 1)
	var iw = 0.0
	var ih = 0.0
	
	# Check explicitly if height_image exists
	if height_image and not height_image.is_empty():
		iw = float(height_image.get_width())
		ih = float(height_image.get_height())
	
	for y in range(res):
		for x in range(res):
			var px = x0 + (float(x) / r_minus_1) * size
			var py = y0 + (float(y) / r_minus_1) * size
			var origin = (normal + (px - 0.5) * 2.0 * axis_a + (py - 0.5) * 2.0 * axis_b)
			var sphere_p = origin.normalized() 
			
			var n = sphere_p
			var u = atan2(n.x, n.z) / (2.0 * PI) + 0.5
			var v = asin(n.y) / PI + 0.5
			u = u + 0.5; v = 1.0 - v; 

			var final_radius = planet_radius
			if iw > 0: # Only sample if image is valid
				u = fmod(u, 1.0); if u < 0: u += 1.0
				var sample_x = clamp(int(u * iw), 0, iw - 1)
				var sample_y = clamp(int(v * ih), 0, ih - 1)
				# .r reads Red channel. Standard for grayscale TIFFs.
				var h_val = height_image.get_pixel(sample_x, sample_y).r
				final_radius += h_val * height_intensity

			var p = sphere_p * final_radius
			verts.append(p)
			norms.append(sphere_p) 

	for y in range(res - 1):
		for x in range(res - 1):
			var i0 = y * res + x
			var i1 = i0 + 1
			var i2 = i0 + res
			var i3 = i2 + 1
			indices.append(i0); indices.append(i2); indices.append(i1)
			indices.append(i1); indices.append(i2); indices.append(i3)

	var skirt_depth = planet_radius * 0.02 
	var edge_indices = []
	for x in range(res): edge_indices.append(x)
	for y in range(res): edge_indices.append(y * res + (res - 1))
	for x in range(res - 1, -1, -1): edge_indices.append((res - 1) * res + x)
	for y in range(res - 1, -1, -1): edge_indices.append(y * res)

	var start_skirt_index = verts.size()
	for i in edge_indices:
		var original_pos = verts[i]
		var original_norm = norms[i] 
		var skirt_pos = original_pos - (original_pos.normalized() * skirt_depth)
		verts.append(skirt_pos)
		norms.append(original_norm)
	
	var skirt_count = edge_indices.size()
	for i in range(skirt_count):
		var curr_edge = edge_indices[i]
		var next_edge = edge_indices[(i + 1) % skirt_count]
		var curr_skirt = start_skirt_index + i
		var next_skirt = start_skirt_index + ((i + 1) % skirt_count)
		indices.append(curr_edge); indices.append(curr_skirt); indices.append(next_skirt)
		indices.append(curr_edge); indices.append(next_skirt); indices.append(next_edge)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _update_lod():
	var cam_pos = camera.global_position
	var local_cam_pos = to_local(cam_pos)
	for patch in patches:
		_process_lod_recursive(patch, local_cam_pos)

func _process_lod_recursive(patch: Patch, local_cam_pos: Vector3):
	var dist = local_cam_pos.distance_to(patch.center_point)
	var split_dist = lod_distance / pow(2, patch.depth)
	var need_sub = dist < split_dist
	
	if need_sub and patch.depth < max_lod:
		if patch.children.is_empty(): _subdivide(patch)
	elif !need_sub and not patch.children.is_empty():
		_collapse(patch)
	if not patch.children.is_empty():
		for child in patch.children: _process_lod_recursive(child, local_cam_pos)

func _subdivide(patch: Patch):
	var half = patch.size * 0.5
	for yy in range(2):
		for xx in range(2):
			var c = Patch.new(patch.face_normal, patch.x0 + xx * half, patch.y0 + yy * half, half, patch.depth + 1)
			c.parent = patch
			c.set_axes()
			c.center_point = _calculate_patch_center(c)
			_make_patch_node(c)
			patch.children.append(c)
	patch.node.visible = false

func _collapse(patch: Patch):
	for c in patch.children:
		_collapse_recursive_cleanup(c)
		c.node.queue_free()
	patch.children.clear()
	patch.node.visible = true

func _collapse_recursive_cleanup(patch: Patch):
	for c in patch.children:
		_collapse_recursive_cleanup(c)
		c.node.queue_free()
	patch.children.clear()
