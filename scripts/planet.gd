@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 
@export var max_lod: int = 6 : set = _set_lod
@export_range(0.1, 10.0) var lod_threshold: float = 3.5 

@export_group("Lighting & Shadows")
@export var sun_intensity: float = 1.0 : set = _set_intensity
@export var use_built_in_shading: bool = true : set = _set_use_builtin

@export_group("Planetshine")
@export var planetshine_enabled: bool = true : set = _set_ps_enabled
@export var planetshine_intensity: float = 0.5 : set = _set_ps_intensity
@export var planetshine_color: Color = Color(0.2, 0.4, 0.8) : set = _set_ps_color

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export_dir var normal_dir: String = "res://assets/earth/normal"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 25.0 : set = _set_hscale 
@export var build_planet: bool = false : set = _trigger_build

var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var _normal_textures: Dictionary = {}
var root_quads: Array = []
var face_nodes: Dictionary = {}
var _pending_updates: Dictionary = {}
var planetshine_light: OmniLight3D

const MONOLITH_SHADER = """
shader_type spatial;
render_mode diffuse_lambert;

uniform sampler2D t1 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t2 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t3 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t4 : source_color, filter_linear_mipmap_anisotropic;

uniform sampler2D h1 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D h2 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D h3 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D h4 : repeat_disable, filter_linear_mipmap_anisotropic;

uniform sampler2D n1 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D n2 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D n3 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D n4 : hint_normal, filter_linear_mipmap_anisotropic;

uniform float h_scale = 25.0;
uniform float sun_strength = 1.0;
uniform bool is_rotated_face = false;

varying vec2 v_uv;
varying vec3 v_world_normal;

float get_h(vec2 uv) {
	vec2 cuv = clamp(uv, 0.0, 1.0);
	if (cuv.y < 0.5) {
		if (cuv.x < 0.5) return texture(h1, cuv * 2.0).r;
		return texture(h2, vec2(cuv.x - 0.5, cuv.y) * 2.0).r;
	} else {
		if (cuv.x < 0.5) return texture(h3, vec2(cuv.x, cuv.y - 0.5) * 2.0).r;
		return texture(h4, (cuv - 0.5) * 2.0).r;
	}
}

void vertex() {
	v_uv = UV;
	// Calculate World Normal correctly using the model matrix
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 edge_clamp = clamp(UV, 0.001, 0.999);
	VERTEX += NORMAL * (get_h(edge_clamp) * h_scale);
}

void fragment() {
	vec3 tex_color;
	vec3 tex_normal;
	
	if (v_uv.y < 0.5) {
		if (v_uv.x < 0.5) { tex_color = texture(t1, v_uv * 2.0).rgb; tex_normal = texture(n1, v_uv * 2.0).rgb; }
		else { tex_color = texture(t2, vec2(v_uv.x - 0.5, v_uv.y) * 2.0).rgb; tex_normal = texture(n2, vec2(v_uv.x - 0.5, v_uv.y) * 2.0).rgb; }
	} else {
		if (v_uv.x < 0.5) { tex_color = texture(t3, vec2(v_uv.x, v_uv.y - 0.5) * 2.0).rgb; tex_normal = texture(n3, vec2(v_uv.x, v_uv.y - 0.5) * 2.0).rgb; }
		else { tex_color = texture(t4, (v_uv - 0.5) * 2.0).rgb; tex_normal = texture(n4, (v_uv - 0.5) * 2.0).rgb; }
	}

	vec3 n_map = tex_normal * 2.0 - 1.0;
	// If the face was rotated in GDScript, we have to flip the normal map X/Y to match
	if (is_rotated_face) {
		n_map.xy *= -1.0;
	}

	vec3 world_n = normalize(v_world_normal);
	vec3 tangent = normalize(cross(world_n, vec3(0.0, 1.0, 0.0)));
	if (length(tangent) < 0.001) tangent = normalize(cross(world_n, vec3(0.0, 0.0, 1.0)));
	vec3 bitangent = cross(world_n, tangent);
	
	mat3 tbn = mat3(tangent, bitangent, world_n);
	vec3 final_n = normalize(tbn * n_map);
	
	NORMAL = (VIEW_MATRIX * vec4(final_n, 0.0)).xyz;
	ALBEDO = tex_color;
}

void light() {
	float dot_light = max(dot(NORMAL, LIGHT), 0.0);
	
	// Anti-Yellow Fix: Use brightness (luminance) of light color only
	float brightness = dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114));
	vec3 neutral_light = vec3(brightness);
	
	DIFFUSE_LIGHT += ALBEDO * neutral_light * dot_light * ATTENUATION * sun_strength;
}
"""

func _ready():
	_setup_planetshine()
	_init_monolith_node()

func _setup_planetshine():
	if has_node("PlanetShine"): planetshine_light = get_node("PlanetShine")
	else:
		planetshine_light = OmniLight3D.new()
		planetshine_light.name = "PlanetShine"
		add_child(planetshine_light)
	planetshine_light.light_cull_mask = 4294967295 ^ 1 
	planetshine_light.omni_range = radius * 15.0
	_update_ps_params()

func _process(_delta):
	if Engine.is_editor_hint() and not build_planet: return
	if not camera: camera = get_viewport().get_camera_3d()
	if camera: _update_monolith_lod(camera.global_position)

func _init_monolith_node():
	_preload_textures()
	for child in get_children(): if child.name.begins_with("Face_"): child.free()
	face_nodes.clear(); root_quads.clear()
	var configs = [{"id":"A","n":Vector3.RIGHT,"a":Vector3.BACK,"b":Vector3.UP},{"id":"B","n":Vector3.LEFT,"a":Vector3.FORWARD,"b":Vector3.UP},{"id":"C","n":Vector3.UP,"a":Vector3.RIGHT,"b":Vector3.BACK},{"id":"D","n":Vector3.DOWN,"a":Vector3.RIGHT,"b":Vector3.FORWARD},{"id":"E","n":Vector3.FORWARD,"a":Vector3.RIGHT,"b":Vector3.UP},{"id":"F","n":Vector3.BACK,"a":Vector3.LEFT,"b":Vector3.UP}]
	for c in configs:
		var mi = MeshInstance3D.new(); mi.name = "Face_" + c.id; add_child(mi)
		mi.layers = 1
		face_nodes[c.id] = mi
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
	var active_quads = []; _collect_active_single_face(root_q, active_quads)
	var verts = PackedVector3Array(); var uvs = PackedVector2Array(); var norms = PackedVector3Array(); var indices = PackedInt32Array()
	var res = resolution
	for q in active_quads:
		var v_offset = verts.size()
		for y in range(res + 1):
			for x in range(res + 1):
				var uv = q.offset + (Vector2(x, y) / float(res)) * q.size
				var p = (q.normal + q.axis_a * (uv.x - 0.5) * 2.0 + q.axis_b * (uv.y - 0.5) * 2.0).normalized()
				if q.face_id in ["A", "B", "E", "F"]: p = p.rotated(Vector3(0,0,1),-PI).rotated(Vector3(0,1,0),PI)
				verts.append(p * radius); uvs.append(uv); norms.append(p)
		for y in range(res):
			for x in range(res):
				var i = v_offset + x + y * (res + 1)
				indices.append_array([i, i+1, i+res+1, i+1, i+res+2, i+res+1])
	call_deferred("_apply_mesh", face_id, verts, uvs, norms, indices)

func _apply_mesh(fid, v, u, n, idx):
	var arr = []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = u; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = MONOLITH_SHADER
	mat.set_shader_parameter("h_scale", height_scale); mat.set_shader_parameter("sun_strength", sun_intensity)
	
	# FLAG ROTATED FACES
	if fid in ["A", "B", "E", "F"]: mat.set_shader_parameter("is_rotated_face", true)
	else: mat.set_shader_parameter("is_rotated_face", false)

	for i in range(_face_textures[fid].size()):
		mat.set_shader_parameter("t"+str(i+1), _face_textures[fid][i]); mat.set_shader_parameter("h"+str(i+1), _height_textures[fid][i])
		if _normal_textures[fid].size() > i: mat.set_shader_parameter("n"+str(i+1), _normal_textures[fid][i])
	am.surface_set_material(0, mat); face_nodes[fid].mesh = am; _pending_updates.erase(fid)

func _collect_active_single_face(q: QuadData, list: Array):
	if q.children.is_empty(): list.append(q)
	else: for c in q.children: _collect_active_single_face(c, list)

func _preload_textures():
	_face_textures.clear(); _height_textures.clear(); _normal_textures.clear()
	for f in ["A", "B", "C", "D", "E", "F"]:
		var c_s = []; var h_s = []; var n_s = []
		for i in range(1, 5):
			var c_p = color_dir.path_join(f + str(i) + out_format); var h_p = height_dir.path_join(f + str(i) + out_format); var n_p = normal_dir.path_join(f + str(i) + out_format)
			if FileAccess.file_exists(c_p): c_s.append(load(c_p))
			if FileAccess.file_exists(h_p): h_s.append(load(h_p))
			if FileAccess.file_exists(n_p): n_s.append(load(n_p))
		_face_textures[f] = c_s; _height_textures[f] = h_s; _normal_textures[f] = n_s

class QuadData:
	var normal: Vector3; var axis_a: Vector3; var axis_b: Vector3; var level: int; var offset: Vector2; var size: float; var face_id: String; var children = []; var center: Vector3
	func _init(_n, _a, _b, _l, _o, _s, _f):
		normal = _n; axis_a = _a; axis_b = _b; level = _l; offset = _o; size = _s; face_id = _f
		var mid = offset + Vector2(0.5, 0.5) * size
		center = (normal + axis_a * (mid.x - 0.5) * 2.0 + axis_b * (mid.y - 0.5) * 2.0).normalized()
		if face_id in ["A", "B", "E", "F"]: center = center.rotated(Vector3(0,0,1),-PI).rotated(Vector3(0,1,0),PI)
	func update_lod(cam_pos, rad, max_l, thresh, trans) -> bool:
		var dist = (trans * (center * rad)).distance_to(cam_pos)
		var split = dist < (rad / pow(2.0, level)) * thresh and level < max_l
		var changed = false
		if split and children.is_empty(): _split(); changed = true
		elif not split and not children.is_empty(): children.clear(); changed = true
		if not children.is_empty():
			for c in children: if c.update_lod(cam_pos, rad, max_l, thresh, trans): changed = true
		return changed
	func _split():
		var s = size * 0.5
		for o in [Vector2.ZERO, Vector2(s,0), Vector2(0,s), Vector2(s,s)]: children.append(QuadData.new(normal, axis_a, axis_b, level + 1, offset + o, s, face_id))

func _set_radius(v): radius = v; if Engine.is_editor_hint(): _init_monolith_node()
func _set_lod(v): max_lod = v; if Engine.is_editor_hint(): _init_monolith_node()
func _set_hscale(v): height_scale = v; _update_shader_params()
func _set_intensity(v): sun_intensity = v; _update_shader_params()
func _set_use_builtin(v): use_built_in_shading = v; _update_shader_params()
func _set_ps_enabled(v): planetshine_enabled = v; _update_ps_params()
func _set_ps_intensity(v): planetshine_intensity = v; _update_ps_params()
func _set_ps_color(v): planetshine_color = v; _update_ps_params()
func _update_ps_params():
	if not planetshine_light: return
	planetshine_light.visible = planetshine_enabled; planetshine_light.light_energy = planetshine_intensity; planetshine_light.light_color = planetshine_color
func _update_shader_params():
	for fn in face_nodes.values():
		if fn.mesh:
			var mat = fn.mesh.surface_get_material(0)
			if mat: mat.set_shader_parameter("sun_strength", sun_intensity); mat.set_shader_parameter("h_scale", height_scale)
func _trigger_build(v): if v: _init_monolith_node(); build_planet = false
