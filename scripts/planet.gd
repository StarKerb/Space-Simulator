@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 
@export var max_lod: int = 8 : set = _set_lod 
@export var lod_threshold: float = 2.0 

@export_group("Debug")
@export var wireframe_mode: bool = false : set = _set_wireframe

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 30.0 : set = _set_hscale
@export var spawn_planet: bool = false : set = _spawn_trigger 

var terrain_node: Node3D
var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var build_queue: Array = []

const LOD_SHADER = """
shader_type spatial;
render_mode cull_back, depth_draw_always;

uniform sampler2D t1 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t2 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t3 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D t4 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D h1 : filter_linear_mipmap;
uniform sampler2D h2 : filter_linear_mipmap;
uniform sampler2D h3 : filter_linear_mipmap;
uniform sampler2D h4 : filter_linear_mipmap;

uniform float h_scale = 10.0;
uniform bool wireframe = false;
varying vec2 v_uv;

float get_h(vec2 uv) {
	float m = 0.0005; 
	if (uv.y < 0.5) {
		if (uv.x < 0.5) return texture(h1, clamp(uv * 2.0, m, 1.0 - m)).r;
		return texture(h2, clamp(vec2(uv.x - 0.5, uv.y) * 2.0, m, 1.0 - m)).r;
	} else {
		if (uv.x < 0.5) return texture(h3, clamp(vec2(uv.x, uv.y - 0.5) * 2.0, m, 1.0 - m)).r;
		return texture(h4, clamp((uv - 0.5) * 2.0, m, 1.0 - m)).r;
	}
}

void vertex() {
	v_uv = UV;
	VERTEX += NORMAL * (get_h(v_uv) * h_scale);
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
	if (wireframe) {
		vec2 grid = abs(fract(v_uv * 16.0 - 0.5) - 0.5) / fwidth(v_uv * 16.0);
		ALBEDO = mix(tex_color, vec3(0.0, 1.0, 0.0), 1.0 - smoothstep(0.0, 0.1, min(grid.x, grid.y)));
	} else {
		ALBEDO = tex_color;
	}
}
"""

func _ready(): _init_planet()

func _process(_delta):
	if Engine.is_editor_hint(): return
	if not camera: camera = get_viewport().get_camera_3d()
	if camera and terrain_node:
		for face in terrain_node.get_children(): face.update_lod(camera.global_position)
	if not build_queue.is_empty():
		var quad = build_queue.pop_front()
		if is_instance_valid(quad): quad._generate_mesh_final()

func _init_planet():
	_preload_textures()
	if has_node("Terrain"): get_node("Terrain").free()
	build_queue.clear()
	terrain_node = Node3D.new(); terrain_node.name = "Terrain"; add_child(terrain_node)
	var faces = [
		{"id": "A", "n": Vector3.RIGHT, "a": Vector3.BACK, "b": Vector3.UP},
		{"id": "B", "n": Vector3.LEFT, "a": Vector3.FORWARD, "b": Vector3.UP},
		{"id": "C", "n": Vector3.UP, "a": Vector3.RIGHT, "b": Vector3.BACK},
		{"id": "D", "n": Vector3.DOWN, "a": Vector3.RIGHT, "b": Vector3.FORWARD},
		{"id": "E", "n": Vector3.FORWARD, "a": Vector3.RIGHT, "b": Vector3.UP},
		{"id": "F", "n": Vector3.BACK, "a": Vector3.LEFT, "b": Vector3.UP}
	]
	for f in faces:
		var face_root = PlanetQuad.new(f.n, f.a, f.b, 0, Vector2.ZERO, 1.0, self, f.id)
		terrain_node.add_child(face_root)

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

class PlanetQuad extends Node3D:
	var normal: Vector3; var axis_a: Vector3; var axis_b: Vector3
	var level: int; var offset: Vector2; var size: float
	var planet: Node3D; var face_id: String
	var mesh_instance: MeshInstance3D
	var children = []
	var base_center: Vector3 

	func _init(_n, _a, _b, _l, _o, _s, _p, _f):
		normal = _n; axis_a = _a; axis_b = _b; level = _l
		offset = _o; size = _s; planet = _p; face_id = _f
		var rot_basis = _get_face_basis()
		var mid_uv = offset + Vector2(0.5, 0.5) * size
		var local_p = (normal + axis_a * (mid_uv.x - 0.5) * 2.0 + axis_b * (mid_uv.y - 0.5) * 2.0).normalized()
		base_center = rot_basis * local_p
		planet.build_queue.append(self)

	func _get_face_basis() -> Basis:
		var b = Basis.IDENTITY
		if face_id in ["A", "B", "E", "F"]:
			b = b.rotated(Vector3(0, 0, 1), PI).rotated(Vector3(0, 1, 0), PI)
		return b

	func _generate_mesh_final():
		if not is_inside_tree() or not children.is_empty(): return # GHOST GUARD
		var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var res = planet.resolution
		var rot_basis = _get_face_basis()
		for y in range(res + 1):
			for x in range(res + 1):
				var p = Vector2(x, y) / float(res)
				var uv = offset + p * size
				var local_p = (normal + axis_a * (uv.x - 0.5) * 2.0 + axis_b * (uv.y - 0.5) * 2.0).normalized()
				var final_p = rot_basis * local_p
				st.set_normal(final_p) # SHARD FIX: Synced Normals
				st.set_uv(uv); st.add_vertex(final_p * planet.radius)

		for y in range(res):
			for x in range(res):
				var i = x + y * (res + 1)
				st.add_index(i); st.add_index(i+1); st.add_index(i+res+1)
				st.add_index(i+1); st.add_index(i+res+2); st.add_index(i+res+1)
		
		mesh_instance = MeshInstance3D.new(); mesh_instance.mesh = st.commit(); add_child(mesh_instance)
		var mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = planet.LOD_SHADER
		mat.set_shader_parameter("h_scale", planet.height_scale)
		mat.set_shader_parameter("wireframe", planet.wireframe_mode)
		var c_t = planet._face_textures[face_id]; var h_t = planet._height_textures[face_id]
		for i in range(c_t.size()): mat.set_shader_parameter("t"+str(i+1), c_t[i])
		for i in range(h_t.size()): mat.set_shader_parameter("h"+str(i+1), h_t[i])
		mesh_instance.set_surface_override_material(0, mat)

	func update_lod(cam_pos: Vector3):
		var surface_center = planet.global_transform * (base_center * (planet.radius + planet.height_scale))
		var dist = surface_center.distance_to(cam_pos)
		var split_dist = (planet.radius / pow(2.0, level)) * planet.lod_threshold
		var should_split = dist < split_dist and level < planet.max_lod
		if should_split:
			if children.is_empty(): _split()
			for child in children: child.update_lod(cam_pos)
		else:
			if not children.is_empty(): _merge()

	func _split():
		# INSTANT GHOST KILL: remove from scene immediately
		if mesh_instance: 
			remove_child(mesh_instance) 
			mesh_instance.queue_free()
			mesh_instance = null
		
		var s = size * 0.5
		for o in [Vector2.ZERO, Vector2(s,0), Vector2(0,s), Vector2(s,s)]:
			var child = PlanetQuad.new(normal, axis_a, axis_b, level + 1, offset + o, s, planet, face_id)
			children.append(child); add_child(child)

	func _merge():
		for c in children: 
			if c in planet.build_queue: planet.build_queue.erase(c)
			c.queue_free()
		children.clear()
		
		# TRIGGER REBUILD: Put parent back in queue
		if not mesh_instance: planet.build_queue.append(self)

func _set_radius(v): radius = v; if Engine.is_editor_hint(): _init_planet()
func _set_lod(v): max_lod = v; if Engine.is_editor_hint(): _init_planet()
func _set_hscale(v): height_scale = v; if Engine.is_editor_hint(): _init_planet()
func _set_wireframe(v): 
	wireframe_mode = v
	if terrain_node:
		for face in terrain_node.get_children(): _apply_wireframe(face, v)

func _apply_wireframe(node, val):
	if node is PlanetQuad and node.mesh_instance:
		var mat = node.mesh_instance.get_surface_override_material(0)
		if mat: mat.set_shader_parameter("wireframe", val)
	for child in node.get_children(): _apply_wireframe(child, val)

func _spawn_trigger(v): if v: _init_planet(); spawn_planet = false
