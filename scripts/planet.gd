@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 64 
@export var max_lod: int = 8 : set = _set_lod 
@export var lod_threshold: float = 2.5 

@export_group("Debug")
@export var wireframe_mode: bool = false : set = _set_wireframe

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 5.0 : set = _set_hscale 
@export var spawn_planet: bool = false : set = _spawn_trigger 
@export var fade_duration: float = 0.5 

var terrain_node: Node3D
var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var build_queue: Array = []

const LOD_SHADER = """
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
uniform bool wireframe = false;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
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
	if (fade < 1.0) {
		float d_t[16] = {0.0625, 0.5625, 0.1875, 0.6875, 0.8125, 0.3125, 0.9375, 0.4375, 0.25, 0.75, 0.125, 0.625, 1.0, 0.5, 0.875, 0.375};
		uvec2 uv = uvec2(FRAGCOORD.xy) % 4u;
		if (fade < d_t[uv.x + uv.y * 4u]) discard;
	}
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
	if (wireframe) {
		vec2 grid = abs(fract(v_uv * 16.0 - 0.5) - 0.5) / fwidth(v_uv * 16.0);
		ALBEDO = mix(ALBEDO, vec3(0.0, 1.0, 0.0), 1.0 - smoothstep(0.0, 0.1, min(grid.x, grid.y)));
	}
}
"""

func _ready(): _init_planet()

func _process(_delta):
	if not build_queue.is_empty():
		var q = build_queue.pop_front()
		if is_instance_valid(q) and q.state != 2: q._generate_mesh_final()
	if Engine.is_editor_hint(): return
	if not camera: camera = get_viewport().get_camera_3d()
	if camera and terrain_node:
		for face in terrain_node.get_children(): face.update_lod(camera.global_position, _delta)

func _init_planet():
	_preload_textures()
	for child in get_children():
		if child.name.begins_with("Terrain"): child.free()
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
			var c_p = color_dir.path_join(f + str(i) + out_format); var h_p = height_dir.path_join(f + str(i) + out_format)
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
	var current_fade: float = 0.0
	var state: int = 0 # 0: Fade In, 1: Visible, 2: Fade Out

	func _init(_n, _a, _b, _l, _o, _s, _p, _f):
		normal = _n; axis_a = _a; axis_b = _b; level = _l; offset = _o; size = _s; planet = _p; face_id = _f
		var uv = offset + Vector2(0.5, 0.5) * size
		var lp = (normal + axis_a * (uv.x - 0.5) * 2.0 + axis_b * (uv.y - 0.5) * 2.0).normalized()
		if face_id in ["A", "B", "E", "F"]: lp = lp.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
		base_center = lp; planet.build_queue.append(self)

	func _generate_mesh_final():
		var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var res = planet.resolution
		for y in range(res + 1):
			for x in range(res + 1):
				var uv = offset + (Vector2(x, y) / float(res)) * size
				var p = (normal + axis_a * (uv.x - 0.5) * 2.0 + axis_b * (uv.y - 0.5) * 2.0).normalized()
				if face_id in ["A", "B", "E", "F"]: p = p.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
				st.set_normal(p); st.set_uv(uv); st.add_vertex(p * planet.radius)
		for y in range(res):
			for x in range(res):
				var i = x + y * (res + 1)
				st.add_index(i); st.add_index(i+1); st.add_index(i+res+1); st.add_index(i+1); st.add_index(i+res+2); st.add_index(i+res+1)
		mesh_instance = MeshInstance3D.new(); mesh_instance.mesh = st.commit()
		mesh_instance.custom_aabb = AABB(Vector3(-planet.radius*2,-planet.radius*2,-planet.radius*2), Vector3(planet.radius*4,planet.radius*4,planet.radius*4))
		add_child(mesh_instance)
		var mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = planet.LOD_SHADER
		mat.set_shader_parameter("h_scale", planet.height_scale); mat.set_shader_parameter("fade", 0.0); mat.set_shader_parameter("wireframe", planet.wireframe_mode)
		for i in planet._face_textures[face_id].size(): mat.set_shader_parameter("t"+str(i+1), planet._face_textures[face_id][i])
		for i in planet._height_textures[face_id].size(): mat.set_shader_parameter("h"+str(i+1), planet._height_textures[face_id][i])
		mesh_instance.set_surface_override_material(0, mat)

	func update_lod(cam_pos: Vector3, delta: float):
		# Process fade for self
		if mesh_instance:
			var mat = mesh_instance.get_surface_override_material(0)
			if state == 0:
				current_fade = clamp(current_fade + delta / planet.fade_duration, 0.0, 1.0)
				mat.set_shader_parameter("fade", current_fade)
				if current_fade >= 1.0: state = 1
			elif state == 2:
				current_fade = clamp(current_fade - delta / planet.fade_duration, 0.0, 1.0)
				mat.set_shader_parameter("fade", current_fade)
				if current_fade <= 0.0:
					if children.is_empty(): queue_free(); return

		# LOD logic
		var dist = (planet.global_transform * (base_center * (planet.radius + planet.height_scale))).distance_to(cam_pos)
		var should_split = dist < (planet.radius / pow(2.0, level)) * planet.lod_threshold and level < planet.max_lod
		if state == 2: should_split = false # Force collapse if we're dying

		if should_split:
			if children.is_empty(): _split()
		else:
			if not children.is_empty(): _merge()

		# Update children and cleanup freed ones (CRASH FIX)
		var children_ready = true
		var i = children.size() - 1
		while i >= 0:
			var c = children[i]
			if is_instance_valid(c):
				c.update_lod(cam_pos, delta)
				if c.state != 1: children_ready = false
			else:
				children.remove_at(i)
			i -= 1

		# Visibility hand-off
		if not children.is_empty():
			if should_split and children_ready:
				if mesh_instance and mesh_instance.visible: mesh_instance.visible = false
			elif not should_split or state == 2:
				if mesh_instance and not mesh_instance.visible: mesh_instance.visible = true
		elif mesh_instance and not mesh_instance.visible:
			mesh_instance.visible = true

	func _split():
		var s = size * 0.5
		for o in [Vector2.ZERO, Vector2(s,0), Vector2(0,s), Vector2(s,s)]:
			var child = PlanetQuad.new(normal, axis_a, axis_b, level + 1, offset + o, s, planet, face_id)
			children.append(child); add_child(child)

	func _merge():
		for c in children: if is_instance_valid(c): c._trigger_recursive_death()
		if not mesh_instance: planet.build_queue.append(self)

	func _trigger_recursive_death():
		state = 2
		for c in children: if is_instance_valid(c): c._trigger_recursive_death()

func _set_radius(v): radius = v; if Engine.is_editor_hint(): _init_planet()
func _set_lod(v): max_lod = v; if Engine.is_editor_hint(): _init_planet()
func _set_hscale(v): height_scale = v; if Engine.is_editor_hint(): _init_planet()
func _set_wireframe(v): 
	wireframe_mode = v
	if terrain_node: for f in terrain_node.get_children(): _apply_wire(f, v)
func _apply_wire(n, v):
	if n is PlanetQuad and n.mesh_instance:
		var m = n.mesh_instance.get_surface_override_material(0)
		if m: m.set_shader_parameter("wireframe", v)
	for c in n.get_children(): _apply_wire(c, v)
func _spawn_trigger(v): if v: _init_planet(); spawn_planet = false
