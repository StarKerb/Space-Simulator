@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 
@export var max_lod: int = 6 : set = _set_lod
@export var lod_threshold: float = 3.0

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 5.0 : set = _set_hscale
@export var build_planet: bool = false : set = _trigger_build

var camera: Camera3D
var terrain_mesh_node: MeshInstance3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var root_quads: Array = []
var vertex_count_tracker: int = 0 # THE FIX fr

const MONOLITH_SHADER = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

uniform sampler2D t1 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t2 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t3 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t4 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D h1 : filter_linear_mipmap;
uniform sampler2D h2 : filter_linear_mipmap;
uniform sampler2D h3 : filter_linear_mipmap;
uniform sampler2D h4 : filter_linear_mipmap;

uniform float h_scale = 5.0;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float m = 0.0001; 
	float h = 0.0;
	if (v_uv.y < 0.5) {
		if (v_uv.x < 0.5) h = texture(h1, clamp(v_uv * 2.0, m, 1.0 - m)).r;
		else h = texture(h2, clamp(vec2(v_uv.x - 0.5, v_uv.y) * 2.0, m, 1.0 - m)).r;
	} else {
		if (v_uv.x < 0.5) h = texture(h3, clamp(vec2(v_uv.x, v_uv.y - 0.5) * 2.0, m, 1.0 - m)).r;
		else h = texture(h4, clamp((v_uv - 0.5) * 2.0, m, 1.0 - m)).r;
	}
	VERTEX += NORMAL * (h * h_scale);
}

void fragment() {
	vec3 tex_color;
	float m = 0.0001; 
	if (v_uv.y < 0.5) {
		if (v_uv.x < 0.5) tex_color = texture(t1, clamp(v_uv * 2.0, m, 1.0 - m)).rgb;
		else tex_color = texture(t2, clamp(vec2(v_uv.x - 0.5, v_uv.y) * 2.0, m, 1.0 - m)).rgb;
	} else {
		if (v_uv.x < 0.5) tex_color = texture(t3, clamp(vec2(v_uv.x, v_uv.y - 0.5) * 2.0, m, 1.0 - m)).rgb;
		else tex_color = texture(t4, clamp((v_uv - 0.5) * 2.0, m, 1.0 - m)).rgb;
	}
	ALBEDO = tex_color;
}
"""

func _ready():
	_init_monolith_node()

func _process(_delta):
	if Engine.is_editor_hint() and not build_planet: return
	if not camera: camera = get_viewport().get_camera_3d()
	if camera and terrain_mesh_node:
		_update_monolith_lod(camera.global_position)

func _init_monolith_node():
	_preload_textures()
	for child in get_children():
		if child.name == "MonolithTerrain": child.free()
	
	terrain_mesh_node = MeshInstance3D.new()
	terrain_mesh_node.name = "MonolithTerrain"
	add_child(terrain_mesh_node)
	
	root_quads.clear()
	var configs = [
		{"id": "A", "n": Vector3.RIGHT, "a": Vector3.BACK, "b": Vector3.UP},
		{"id": "B", "n": Vector3.LEFT, "a": Vector3.FORWARD, "b": Vector3.UP},
		{"id": "C", "n": Vector3.UP, "a": Vector3.RIGHT, "b": Vector3.BACK},
		{"id": "D", "n": Vector3.DOWN, "a": Vector3.RIGHT, "b": Vector3.FORWARD},
		{"id": "E", "n": Vector3.FORWARD, "a": Vector3.RIGHT, "b": Vector3.UP},
		{"id": "F", "n": Vector3.BACK, "a": Vector3.LEFT, "b": Vector3.UP}
	]
	for c in configs:
		root_quads.append(QuadData.new(c.n, c.a, c.b, 0, Vector2.ZERO, 1.0, c.id))
	_stitch_monolith()

func _update_monolith_lod(cam_pos: Vector3):
	var changed = false
	for q in root_quads:
		if q.update_lod(cam_pos, radius, max_lod, lod_threshold, global_transform):
			changed = true
	if changed:
		_stitch_monolith()

func _stitch_monolith():
	var st = SurfaceTool.new()
	var am = ArrayMesh.new()
	var face_groups = {"A":[], "B":[], "C":[], "D":[], "E":[], "F":[]}
	_collect_active(root_quads, face_groups)
	
	for face_id in face_groups:
		if face_groups[face_id].is_empty(): continue
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		vertex_count_tracker = 0 # Reset for each face surface
		for q in face_groups[face_id]:
			_add_geometry(st, q)
		st.commit(am)
		
		var mat = ShaderMaterial.new()
		mat.shader = Shader.new(); mat.shader.code = MONOLITH_SHADER
		mat.set_shader_parameter("h_scale", height_scale)
		for i in range(_face_textures[face_id].size()):
			mat.set_shader_parameter("t"+str(i+1), _face_textures[face_id][i])
			mat.set_shader_parameter("h"+str(i+1), _height_textures[face_id][i])
		am.surface_set_material(am.get_surface_count() - 1, mat)
	
	terrain_mesh_node.mesh = am
	terrain_mesh_node.custom_aabb = AABB(Vector3(-radius*2,-radius*2,-radius*2), Vector3(radius*4,radius*4,radius*4))

func _add_geometry(st: SurfaceTool, q: QuadData):
	var res = resolution
	var v_offset = vertex_count_tracker # FIXED: Manually tracking
	for y in range(res + 1):
		for x in range(res + 1):
			var uv = q.offset + (Vector2(x, y) / float(res)) * q.size
			var p = (q.normal + q.axis_a * (uv.x - 0.5) * 2.0 + q.axis_b * (uv.y - 0.5) * 2.0).normalized()
			if q.face_id in ["A", "B", "E", "F"]:
				p = p.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
			st.set_normal(p); st.set_uv(uv); st.add_vertex(p * radius)
			vertex_count_tracker += 1
	for y in range(res):
		for x in range(res):
			var i = v_offset + x + y * (res + 1)
			st.add_index(i); st.add_index(i+1); st.add_index(i+res+1)
			st.add_index(i+1); st.add_index(i+res+2); st.add_index(i+res+1)

func _collect_active(quads: Array, groups: Dictionary):
	for q in quads:
		if q.children.is_empty(): groups[q.face_id].append(q)
		else: _collect_active(q.children, groups)

func _preload_textures():
	_face_textures.clear(); _height_textures.clear()
	for f in ["A", "B", "C", "D", "E", "F"]:
		var c_set = []; var h_set = []
		for i in range(1, 5):
			var c_p = color_dir.path_join(f + str(i) + out_format)
			var h_p = height_dir.path_join(f + str(i) + out_format)
			if FileAccess.file_exists(c_p): c_set.append(load(c_p))
			if FileAccess.file_exists(h_p): h_set.append(load(h_p))
		_face_textures[f] = c_set; _height_textures[f] = h_set

class QuadData:
	var normal: Vector3; var axis_a: Vector3; var axis_b: Vector3
	var level: int; var offset: Vector2; var size: float
	var face_id: String; var children = []; var center: Vector3

	func _init(_n, _a, _b, _l, _o, _s, _f):
		normal = _n; axis_a = _a; axis_b = _b; level = _l; offset = _o; size = _s; face_id = _f
		var lp = (normal + axis_a * (offset.x + size*0.5 - 0.5) * 2.0 + axis_b * (offset.y + size*0.5 - 0.5) * 2.0).normalized()
		if face_id in ["A", "B", "E", "F"]: lp = lp.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
		center = lp

	func update_lod(cam_pos: Vector3, rad: float, max_l: int, thresh: float, trans: Transform3D) -> bool:
		var dist = (trans * (center * rad)).distance_to(cam_pos)
		var should_split = dist < (rad / pow(2.0, level)) * thresh and level < max_l
		var changed = false
		if should_split and children.is_empty():
			_split(); changed = true
		elif not should_split and not children.is_empty():
			children.clear(); changed = true
		for c in children:
			if c.update_lod(cam_pos, rad, max_l, thresh, trans): changed = true
		return changed

	func _split():
		var s = size * 0.5
		for o in [Vector2.ZERO, Vector2(s,0), Vector2(0,s), Vector2(s,s)]:
			children.append(QuadData.new(normal, axis_a, axis_b, level + 1, offset + o, s, face_id))

# Setters
func _set_radius(v): radius = v; if Engine.is_editor_hint(): _init_monolith_node()
func _set_lod(v): max_lod = v; if Engine.is_editor_hint(): _init_monolith_node()
func _set_hscale(v): height_scale = v; if Engine.is_editor_hint(): _init_monolith_node()
func _trigger_build(v): if v: _init_monolith_node(); build_planet = false
