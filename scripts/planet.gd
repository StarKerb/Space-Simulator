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

@export_group("Hybrid Texture Switching")
@export var enable_hybrid_maps: bool = true
@export var hybrid_switch_dist: float = 4500.0
@export var hybrid_hysteresis: float = 500.0
@export var max_stitched_size: int = 16384
@export var height_max_stitched_size: int = 8192

@export_group("Maps - Single")
@export var color_map: Texture2D : set = _set_color_map
@export var specular_map: Texture2D : set = _set_specular_map
@export var height_map: Texture2D : set = _set_height_map

@export_group("Maps - Tiles (folder contains A1..D2)")
@export_dir var color_tiles_dir: String = ""
@export_dir var specular_tiles_dir: String = ""
@export_dir var height_tiles_dir: String = ""
@export var color_tiles_filter: String = ""
@export var specular_tiles_filter: String = ""
@export var height_tiles_filter: String = ""

@export_group("Maps - Params")
@export var height_intensity: float = 20.0 : set = _set_height_val
@export_range(0.0, 1.0) var roughness_base: float = 1.0 : set = _set_roughness

var camera: Camera3D
var terrain: Node3D
var height_image: Image
var _editor_timer := 0.0

# editor safety
var _spawned := false
var _spawn_armed := false # lets "Spawn Planet" work even if saved ON

# hybrid
var _using_tiles := false

var _active_color: Texture2D
var _active_specular: Texture2D
var _active_height: Texture2D

var _stitched_color: ImageTexture
var _stitched_specular: ImageTexture
var _stitched_height: ImageTexture
var _tiles_built_color := false
var _tiles_built_spec := false
var _tiles_built_height := false

# --- SHADER CODE ---
const PLANET_SHADER = """
shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap;
uniform sampler2D specular_map : hint_default_white, filter_linear_mipmap;
uniform float roughness_base : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_local_pos;

void vertex() { v_local_pos = VERTEX; }

void fragment() {
    vec3 n = normalize(v_local_pos);
    float u = atan(n.x, n.z) / (2.0 * PI) + 0.5;
    float v = asin(n.y) / PI + 0.5;
    u = u + 0.5;
    v = 1.0 - v;
    vec2 uv = vec2(fract(u), v);

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

const TILE_SUFFIXES := ["A1","B1","C1","D1","A2","B2","C2","D2"]
const TILE_COLS := 4
const TILE_ROWS := 2

func _ready():
	if Engine.is_editor_hint():
		# If scene was saved with Spawn Planet = ON, arm it so it triggers once.
		if spawn_planet:
			_spawn_armed = true
		return

	_init_terrain_node()
	_spawned = true
	call_deferred("_init_patches")

func _process(delta):
	# editor: allow "spawn once" even if user forgot to toggle
	if Engine.is_editor_hint():
		if spawn_planet and _spawn_armed:
			_spawn_armed = false
			# run spawn
			_init_terrain_node()
			_spawned = true
			_using_tiles = false
			_init_patches()
			# reset toggle so it behaves like a button
			spawn_planet = false
			return

	if not _spawned:
		return

	if Engine.is_editor_hint():
		if not live_update:
			return
		_editor_timer += delta
		if _editor_timer < 0.1:
			return
		_editor_timer = 0.0

	_find_camera()
	if not camera:
		return

	_maybe_switch_maps()
	_update_lod()

# -------------------- SETTERS --------------------
func _set_radius(val):
	planet_radius = val
	if live_update and _spawned and terrain:
		_init_patches()

func _set_color_map(val):
	color_map = val
	if live_update and _spawned:
		_apply_active_maps_to_materials()

func _set_specular_map(val):
	specular_map = val
	if live_update and _spawned:
		_apply_active_maps_to_materials()

func _set_height_map(val):
	height_map = val
	if live_update and _spawned:
		_refresh_height_image()

func _set_height_val(val):
	height_intensity = val
	if live_update and _spawned and terrain:
		_init_patches()

func _set_roughness(val):
	roughness_base = val
	if live_update and _spawned:
		_apply_active_maps_to_materials()

# -------------------- BUTTONS --------------------
func _force_spawn_base(val):
	if not val:
		return
	# arm and trigger on next _process tick (safer in editor)
	_spawn_armed = true

func _trigger_lod_update(val):
	if not val:
		return
	update_once = false
	if not _spawned:
		return
	_find_camera()
	if camera:
		_maybe_switch_maps()
		_update_lod()

# -------------------- CAMERA / NODES --------------------
func _edited_owner() -> Node:
	if Engine.is_editor_hint():
		return get_tree().edited_scene_root
	return self

func _find_camera():
	if Engine.is_editor_hint():
		var vp = EditorInterface.get_editor_viewport_3d(0)
		if vp:
			camera = vp.get_camera_3d()
	else:
		var vp = get_viewport()
		if vp:
			camera = vp.get_camera_3d()

func _init_terrain_node():
	if has_node("Terrain"):
		terrain = get_node("Terrain")
		return

	terrain = Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	# IMPORTANT for editor: give ownership so it exists properly
	var o = _edited_owner()
	if o:
		terrain.owner = o

# -------------------- HYBRID SWITCHING --------------------
func _maybe_switch_maps():
	if not enable_hybrid_maps:
		if _using_tiles:
			_set_using_tiles(false)
		return

	var d = camera.global_position.distance_to(global_position)
	var enter_tiles = hybrid_switch_dist
	var exit_tiles = hybrid_switch_dist + hybrid_hysteresis

	if not _using_tiles and d < enter_tiles:
		_set_using_tiles(true)
	elif _using_tiles and d > exit_tiles:
		_set_using_tiles(false)

func _set_using_tiles(want_tiles: bool):
	if want_tiles == _using_tiles:
		return

	_using_tiles = want_tiles

	if _using_tiles:
		_ensure_tiles_built()
		if _stitched_color == null and _stitched_specular == null and _stitched_height == null:
			_using_tiles = false

	_resolve_active_maps()
	_apply_active_maps_to_materials()
	_refresh_height_image()

func _resolve_active_maps():
	if _using_tiles:
		_active_color = _stitched_color if _stitched_color else color_map
		_active_specular = _stitched_specular if _stitched_specular else specular_map
		_active_height = _stitched_height if _stitched_height else height_map
	else:
		_active_color = color_map
		_active_specular = specular_map
		_active_height = height_map

func _ensure_tiles_built():
	if not _tiles_built_color and not color_tiles_dir.is_empty():
		_tiles_built_color = true
		_stitched_color = _build_stitched_texture(color_tiles_dir, color_tiles_filter, "color", max_stitched_size)

	if not _tiles_built_spec and not specular_tiles_dir.is_empty():
		_tiles_built_spec = true
		_stitched_specular = _build_stitched_texture(specular_tiles_dir, specular_tiles_filter, "specular", max_stitched_size)

	if not _tiles_built_height and not height_tiles_dir.is_empty():
		_tiles_built_height = true
		_stitched_height = _build_stitched_texture(height_tiles_dir, height_tiles_filter, "height", height_max_stitched_size)

# -------------------- TILE STITCHING --------------------
func _build_stitched_texture(dir_path: String, filter_str: String, label: String, clamp_size: int) -> ImageTexture:
	var da := DirAccess.open(dir_path)
	if da == null:
		printerr("[Planet] can't open tiled dir for ", label, ": ", dir_path)
		return null

	var files := _find_tiles_in_dir(dir_path, filter_str)
	if files.is_empty() or not files.has("A1"):
		printerr("[Planet] missing tiles for ", label, " in: ", dir_path)
		return null

	var first := Image.new()
	var err = first.load(files["A1"])
	if err != OK:
		printerr("[Planet] failed load A1 for ", label, ": ", files["A1"], " err=", err)
		return null
	if first.is_compressed():
		first.decompress()

	var tw = first.get_width()
	var th = first.get_height()
	var out := Image.create(tw * TILE_COLS, th * TILE_ROWS, false, first.get_format())
	out.fill(Color(0,0,0,1))

	for row in range(TILE_ROWS):
		for col in range(TILE_COLS):
			var suffix = "%s%d" % [char(65 + col), row + 1] # A1..D2
			if not files.has(suffix):
				printerr("[Planet] missing tile ", suffix, " for ", label)
				return null
			var img := Image.new()
			var e = img.load(files[suffix])
			if e != OK:
				printerr("[Planet] failed load tile ", suffix, " for ", label, ": ", files[suffix], " err=", e)
				return null
			if img.is_compressed():
				img.decompress()
			out.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(col * tw, row * th))

	if clamp_size > 0:
		var w = out.get_width()
		var h = out.get_height()
		var max_dim = max(w, h)
		if max_dim > clamp_size:
			var scale = float(clamp_size) / float(max_dim)
			var nw = max(1, int(round(w * scale)))
			var nh = max(1, int(round(h * scale)))
			out.resize(nw, nh, Image.INTERPOLATE_LANCZOS)

	return ImageTexture.create_from_image(out)

func _find_tiles_in_dir(dir_path: String, filter_str: String) -> Dictionary:
	var result := {}
	var da := DirAccess.open(dir_path)
	if da == null:
		return result

	da.list_dir_begin()
	while true:
		var f = da.get_next()
		if f == "":
			break
		if da.current_is_dir():
			continue

		var lower = f.to_lower()
		if not (lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".tif") or lower.ends_with(".tiff")):
			continue
		if filter_str != "" and lower.find(filter_str.to_lower()) == -1 and f.find(filter_str) == -1:
			continue

		var suf := _extract_tile_suffix(f)
		if suf != "":
			result[suf] = dir_path.path_join(f)

	da.list_dir_end()
	return result

func _extract_tile_suffix(filename: String) -> String:
	var base = filename.get_basename()
	if base.length() < 2:
		return ""
	var suf = base.substr(base.length() - 2, 2).to_upper()
	return suf if TILE_SUFFIXES.has(suf) else ""

# -------------------- PLANET BUILD --------------------
func _init_patches():
	if not terrain:
		_init_terrain_node()

	for c in terrain.get_children():
		c.queue_free()
	patches.clear()

	_resolve_active_maps()
	_refresh_height_image()

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
	var o = _edited_owner()
	if o:
		node.owner = o
	patch.node = node
	_update_patch_mesh(patch)

func _update_patch_mesh(patch: Patch):
	var res = base_resolution
	patch.node.mesh = _build_patch_mesh(patch.face_normal, patch.axis_a, patch.axis_b, patch.x0, patch.y0, patch.size, res)

	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = PLANET_SHADER
	patch.node.set_surface_override_material(0, mat)
	_apply_material_params(mat)

func _apply_active_maps_to_materials():
	_resolve_active_maps()
	if not terrain:
		return
	for child in terrain.get_children():
		if child is MeshInstance3D:
			var mat = child.get_surface_override_material(0)
			if mat is ShaderMaterial:
				_apply_material_params(mat)

func _apply_material_params(mat: ShaderMaterial):
	if _active_color:
		mat.set_shader_parameter("color_map", _active_color)
	if _active_specular:
		mat.set_shader_parameter("specular_map", _active_specular)
	mat.set_shader_parameter("roughness_base", roughness_base)

func _refresh_height_image():
	if _active_height:
		height_image = _active_height.get_image()
		if height_image and height_image.is_compressed():
			height_image.decompress()
		if height_image and height_image.is_empty():
			height_image = null
	else:
		height_image = null

func _build_patch_mesh(normal, axis_a, axis_b, x0, y0, size, res) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()

	var r_minus_1 = float(res - 1)
	var iw := 0.0
	var ih := 0.0
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
			u = u + 0.5
			v = 1.0 - v

			var final_radius = planet_radius
			if iw > 0.0:
				u = fmod(u, 1.0)
				if u < 0.0:
					u += 1.0
				var sx = clamp(int(u * iw), 0, int(iw) - 1)
				var sy = clamp(int(v * ih), 0, int(ih) - 1)
				var h_val = height_image.get_pixel(sx, sy).r
				final_radius += h_val * height_intensity

			verts.append(sphere_p * final_radius)
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
		var op = verts[i]
		var on = norms[i]
		verts.append(op - (op.normalized() * skirt_depth))
		norms.append(on)

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

# -------------------- LOD --------------------
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
		if patch.children.is_empty():
			_subdivide(patch)
	elif not need_sub and not patch.children.is_empty():
		_collapse(patch)

	if not patch.children.is_empty():
		for child in patch.children:
			_process_lod_recursive(child, local_cam_pos)

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
