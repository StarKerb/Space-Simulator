@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 
@export var max_lod: int = 6 : set = _set_lod
@export var lod_threshold: float = 3.5 

@export_group("Lighting & Shadows")
@export var sun_intensity: float = 2.0 : set = _set_intensity
@export var shadow_smoothness: float = 0.001 : set = _set_smoothness

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 25.0 : set = _set_hscale 
@export var build_planet: bool = false : set = _trigger_build

var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var root_quads: Array = []
var face_nodes: Dictionary = {}
var _pending_updates: Dictionary = {}

const MONOLITH_SHADER = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, unshaded;

uniform sampler2D t1 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t2 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t3 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t4 : source_color, filter_linear_mipmap_anisotropic;

uniform sampler2D h1 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D h2 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D h3 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D h4 : repeat_disable, filter_linear_mipmap_anisotropic;

uniform float h_scale = 25.0;
uniform float sun_strength = 2.0;
uniform float blur_val = 0.001;
uniform vec3 sun_dir_world = vec3(1.0, -1.0, 0.5);

varying vec2 v_uv;
varying vec3 v_normal;
varying vec3 v_sun_local;

// Edge-wrapped height sampling to delete the seam
float get_h(vec2 uv) {
    vec2 wrapped_uv = fract(uv); 
    if (wrapped_uv.y < 0.5) {
        if (wrapped_uv.x < 0.5) return texture(h1, wrapped_uv * 2.0).r;
        return texture(h2, vec2(wrapped_uv.x - 0.5, wrapped_uv.y) * 2.0).r;
    } else {
        if (wrapped_uv.x < 0.5) return texture(h3, vec2(wrapped_uv.x, wrapped_uv.y - 0.5) * 2.0).r;
        return texture(h4, (wrapped_uv - 0.5) * 2.0).r;
    }
}

void vertex() {
    v_uv = UV;
    v_normal = NORMAL;
    v_sun_local = normalize((inverse(MODEL_MATRIX) * vec4(-sun_dir_world, 0.0)).xyz);
    
    float h = get_h(UV);
    VERTEX += NORMAL * (h * h_scale);
}

void fragment() {
    vec3 tex_color;
    if (v_uv.y < 0.5) {
        if (v_uv.x < 0.5) tex_color = texture(t1, v_uv * 2.0).rgb;
        else tex_color = texture(t2, vec2(v_uv.x - 0.5, v_uv.y) * 2.0).rgb;
    } else {
        if (v_uv.x < 0.5) tex_color = texture(t3, vec2(v_uv.x, v_uv.y - 0.5) * 2.0).rgb;
        else tex_color = texture(t4, (v_uv - 0.5) * 2.0).rgb;
    }

    float s = max(blur_val, 0.0001);
    
    // Sample height with wrapping logic to bridge the gaps
    float h_c = get_h(v_uv);
    float h_l = get_h(v_uv + vec2(-s, 0.0));
    float h_r = get_h(v_uv + vec2(s, 0.0));
    float h_d = get_h(v_uv + vec2(0.0, -s));
    float h_u = get_h(v_uv + vec2(0.0, s));
    
    vec3 slope = vec3((h_l - h_r) * h_scale, (h_d - h_u) * h_scale, 0.0);
    vec3 manual_normal = normalize(v_normal + slope);

    float dot_sun = max(dot(manual_normal, v_sun_local), 0.08);
    ALBEDO = tex_color * dot_sun * sun_strength;
}
"""

func _ready():
	_init_monolith_node()

func _process(_delta):
	if Engine.is_editor_hint() and not build_planet: return
	if not camera: camera = get_viewport().get_camera_3d()
	if camera: _update_monolith_lod(camera.global_position)

func _init_monolith_node():
	_preload_textures()
	for child in get_children(): if child.name.begins_with("Face_"): child.free()
	face_nodes.clear(); root_quads.clear()
	var configs = [
		{"id":"A","n":Vector3.RIGHT,"a":Vector3.BACK,"b":Vector3.UP},
		{"id":"B","n":Vector3.LEFT,"a":Vector3.FORWARD,"b":Vector3.UP},
		{"id":"C","n":Vector3.UP,"a":Vector3.RIGHT,"b":Vector3.BACK},
		{"id":"D","n":Vector3.DOWN,"a":Vector3.RIGHT,"b":Vector3.FORWARD},
		{"id":"E","n":Vector3.FORWARD,"a":Vector3.RIGHT,"b":Vector3.UP},
		{"id":"F","n":Vector3.BACK,"a":Vector3.LEFT,"b":Vector3.UP}
	]
	for c in configs:
		var mi = MeshInstance3D.new()
		mi.name = "Face_" + c.id; add_child(mi); face_nodes[c.id] = mi
		var q = QuadData.new(c.n, c.a, c.b, 0, Vector2.ZERO, 1.0, c.id)
		root_quads.append(q); _request_face_update(c.id, q)

func _update_monolith_lod(cam_pos: Vector3):
	for q in root_quads:
		if q.update_lod(cam_pos, radius, max_lod, lod_threshold, global_transform):
			_request_face_update(q.face_id, q)

func _request_face_update(face_id: String, root_q: QuadData):
	if _pending_updates.has(face_id): return
	_pending_updates[face_id] = true
	WorkerThreadPool.add_task(_threaded_gen.bind(face_id, root_q))

func _threaded_gen(face_id: String, root_q: QuadData):
	var active_quads = []
	_collect_active_single_face(root_q, active_quads)
	var verts = PackedVector3Array(); var uvs = PackedVector2Array()
	var norms = PackedVector3Array(); var indices = PackedInt32Array()
	var res = resolution
	for q in active_quads:
		var v_offset = verts.size()
		for y in range(res + 1):
			for x in range(res + 1):
				var raw_t = Vector2(x, y) / float(res)
				var uv = q.offset + raw_t * q.size
				var p = (q.normal + q.axis_a * (uv.x - 0.5) * 2.0 + q.axis_b * (uv.y - 0.5) * 2.0).normalized()
				if q.face_id in ["A", "B", "E", "F"]: p = p.rotated(Vector3(0,0,1),-PI).rotated(Vector3(0,1,0),PI)
				verts.append(p * radius); uvs.append(uv); norms.append(p)
		for y in range(res):
			for x in range(res):
				var i = v_offset + x + y * (res + 1)
				indices.append_array([i, i+1, i+res+1, i+1, i+res+2, i+res+1])
	call_deferred("_apply_mesh", face_id, verts, uvs, norms, indices)

func _apply_mesh(fid, v, u, n, idx):
	var arr = []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = u
	arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = MONOLITH_SHADER
	mat.set_shader_parameter("h_scale", height_scale)
	mat.set_shader_parameter("sun_strength", sun_intensity)
	mat.set_shader_parameter("blur_val", shadow_smoothness)
	for i in range(_face_textures[fid].size()):
		mat.set_shader_parameter("t"+str(i+1), _face_textures[fid][i])
		mat.set_shader_parameter("h"+str(i+1), _height_textures[fid][i])
	am.surface_set_material(0, mat)
	face_nodes[fid].mesh = am
	_pending_updates.erase(fid)

func _collect_active_single_face(q: QuadData, list: Array):
	if q.children.is_empty(): list.append(q)
	else: for c in q.children: _collect_active_single_face(c, list)

func _preload_textures():
	_face_textures.clear(); _height_textures.clear()
	for f in ["A", "B", "C", "D", "E", "F"]:
		var c_set = []; var h_set = []
		for i in range(1, 5):
			var c_p = color_dir.path_join(f + str(i) + out_format); var h_p = height_dir.path_join(f + str(i) + out_format)
			if FileAccess.file_exists(c_p): c_set.append(load(c_p))
			if FileAccess.file_exists(h_p): h_set.append(load(h_p))
		_face_textures[f] = c_set; _height_textures[f] = h_set

class QuadData:
	var normal: Vector3; var axis_a: Vector3; var axis_b: Vector3
	var level: int; var offset: Vector2; var size: float; var face_id: String
	var children = []; var center: Vector3
	func _init(_n, _a, _b, _l, _o, _s, _f):
		normal = _n; axis_a = _a; axis_b = _b; level = _l; offset = _o; size = _s; face_id = _f
		var mid_uv = offset + Vector2(0.5, 0.5) * size
		var lp = (normal + axis_a * (mid_uv.x - 0.5) * 2.0 + axis_b * (mid_uv.y - 0.5) * 2.0).normalized()
		if face_id in ["A", "B", "E", "F"]: lp = lp.rotated(Vector3(0,0,1),-PI).rotated(Vector3(0,1,0),PI)
		center = lp
	func update_lod(cam_pos, rad, max_l, thresh, trans) -> bool:
		var dist = (trans * (center * rad)).distance_to(cam_pos)
		var should_split = dist < (rad / pow(2.0, level)) * thresh and level < max_l
		var changed = false
		if should_split and children.is_empty(): _split(); changed = true
		elif not should_split and not children.is_empty(): children.clear(); changed = true
		if not children.is_empty():
			for c in children: if c.update_lod(cam_pos, rad, max_l, thresh, trans): changed = true
		return changed
	func _split():
		var s = size * 0.5
		for o in [Vector2.ZERO, Vector2(s,0), Vector2(0,s), Vector2(s,s)]:
			children.append(QuadData.new(normal, axis_a, axis_b, level + 1, offset + o, s, face_id))

func _set_radius(v): radius = v; if Engine.is_editor_hint(): _init_monolith_node()
func _set_lod(v): max_lod = v; if Engine.is_editor_hint(): _init_monolith_node()
func _set_hscale(v): height_scale = v; _update_shader_params()
func _set_intensity(v): sun_intensity = v; _update_shader_params()
func _set_smoothness(v): shadow_smoothness = v; _update_shader_params()

func _update_shader_params():
	for fn in face_nodes.values():
		if fn.mesh:
			var mat = fn.mesh.surface_get_material(0)
			if mat: 
				mat.set_shader_parameter("sun_strength", sun_intensity)
				mat.set_shader_parameter("blur_val", shadow_smoothness)
				mat.set_shader_parameter("h_scale", height_scale)

func _trigger_build(v): if v: _init_monolith_node(); build_planet = false
