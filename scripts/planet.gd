@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 
@export var max_lod: int = 6 : set = _set_lod
@export var lod_threshold: float = 3.5 

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 15.0 : set = _set_hscale 
@export var build_planet: bool = false : set = _trigger_build

var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var root_quads: Array = []
var face_nodes: Dictionary = {}
var _pending_updates: Dictionary = {}

const MONOLITH_SHADER = """
shader_type spatial;
render_mode cull_back, depth_draw_always, shadows_disabled;

uniform sampler2D t1 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t2 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t3 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t4 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D h1 : filter_linear_mipmap;
uniform sampler2D h2 : filter_linear_mipmap;
uniform sampler2D h3 : filter_linear_mipmap;
uniform sampler2D h4 : filter_linear_mipmap;

uniform float h_scale = 5.0;
// Hillshade settings. Light dir is normalized (x, y, z)
uniform vec3 light_dir = vec3(-0.5, 0.5, 0.2); 
uniform float hillshade_intensity = 0.5;

varying vec2 v_uv;

float get_h(vec2 uv) {
    vec2 cuv = clamp(uv, 0.0, 1.0); 
    float m = 0.001; 
    
    if (cuv.y < 0.5) {
        if (cuv.x < 0.5) return texture(h1, clamp(cuv * 2.0, m, 1.0 - m)).r;
        return texture(h2, clamp(vec2(cuv.x - 0.5, cuv.y) * 2.0, m, 1.0 - m)).r;
    } else {
        if (cuv.x < 0.5) return texture(h3, clamp(vec2(cuv.x, cuv.y - 0.5) * 2.0, m, 1.0 - m)).r;
        return texture(h4, clamp((cuv - 0.5) * 2.0, m, 1.0 - m)).r;
    }
}

void vertex() {
    v_uv = UV;
    float h = get_h(v_uv);
    VERTEX += NORMAL * (h * h_scale);
}

void fragment() {
    float m = 0.001;
    vec3 tex_color;
    
    // Albedo Splice
    if (v_uv.y < 0.5) {
        if (v_uv.x < 0.5) tex_color = texture(t1, clamp(v_uv * 2.0, m, 1.0 - m)).rgb;
        else tex_color = texture(t2, clamp(vec2(v_uv.x - 0.5, v_uv.y) * 2.0, m, 1.0 - m)).rgb;
    } else {
        if (v_uv.x < 0.5) tex_color = texture(t3, clamp(vec2(v_uv.x, v_uv.y - 0.5) * 2.0, m, 1.0 - m)).rgb;
        else tex_color = texture(t4, clamp((v_uv - 0.5) * 2.0, m, 1.0 - m)).rgb;
    }

    // Hillshading Calc
    float e = 0.002; // Epsilon for neighbor lookup
    float h_c = get_h(v_uv);
    float h_r = get_h(v_uv + vec2(e, 0.0));
    float h_d = get_h(v_uv + vec2(0.0, e));

    // Calculate slope vectors
    // Adjust scale factor to make normals punchy enough
    float d_x = (h_c - h_r) * h_scale;
    float d_y = (h_c - h_d) * h_scale;

    // Construct a pseudo-normal (approximate)
    vec3 normal = normalize(vec3(d_x, d_y, e));
    
    // Dot product with light
    float shade = dot(normal, normalize(light_dir));
    
    // Remap -1..1 to 0..1 and mix with intensity
    shade = clamp((shade + 1.0) * 0.5, 0.0, 1.0);
    vec3 final_shade = mix(vec3(1.0), vec3(shade), hillshade_intensity);

    ALBEDO = tex_color * final_shade;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
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
				
				if q.face_id in ["A", "B", "E", "F"]: 
					p = p.rotated(Vector3(0,0,1),-PI).rotated(Vector3(0,1,0),PI)
				
				verts.append(p * radius)
				uvs.append(uv)
				norms.append(p)
				
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
func _set_hscale(v): height_scale = v; if Engine.is_editor_hint(): _init_monolith_node()
func _trigger_build(v): if v: _init_monolith_node(); build_planet = false
