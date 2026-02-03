@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 : set = _set_res
@export var max_lod: int = 4 : set = _set_lod
@export var lod_threshold: float = 2.0 

@export_group("Textures")
@export_dir var color_dir: String = "res://assets/earth/color"
@export_dir var height_dir: String = "res://assets/earth/height"
@export var out_format: String = ".png"

@export_group("Terrain Settings")
@export var height_scale: float = 15.0 : set = _set_hscale
@export var spawn_planet: bool = false : set = _spawn_trigger # FIXED: Declared variable

var terrain_node: Node3D
var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}

const LOD_SHADER = """
shader_type spatial;
render_mode cull_back, depth_draw_always;

uniform sampler2D t1; uniform sampler2D t2; 
uniform sampler2D t3; uniform sampler2D t4;
uniform sampler2D h1; uniform sampler2D h2;
uniform sampler2D h3; uniform sampler2D h4;

uniform float h_scale = 10.0;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float h = 0.0;
	// Monochrome sampling: Black is low, White is high
	if (v_uv.y < 0.5) {
		if (v_uv.x < 0.5) h = texture(h1, v_uv * 2.0).r;
		else h = texture(h2, vec2(v_uv.x - 0.5, v_uv.y) * 2.0).r;
	} else {
		if (v_uv.x < 0.5) h = texture(h3, vec2(v_uv.x, v_uv.y - 0.5) * 2.0).r;
		else h = texture(h4, (v_uv - 0.5) * 2.0).r;
	}
	VERTEX += NORMAL * (h * h_scale);
}

void fragment() {
	vec3 color;
	if (v_uv.y < 0.5) {
		if (v_uv.x < 0.5) color = texture(t1, v_uv * 2.0).rgb;
		else color = texture(t2, vec2(v_uv.x - 0.5, v_uv.y) * 2.0).rgb;
	} else {
		if (v_uv.x < 0.5) color = texture(t3, vec2(v_uv.x, v_uv.y - 0.5) * 2.0).rgb;
		else color = texture(t4, (v_uv - 0.5) * 2.0).rgb;
	}
	ALBEDO = color;
	ROUGHNESS = 0.8;
}
"""

func _ready():
	if not Engine.is_editor_hint():
		_init_planet()

func _process(_delta):
	if Engine.is_editor_hint(): return
	if not camera: camera = get_viewport().get_camera_3d()
	if camera and terrain_node:
		for face in terrain_node.get_children():
			face.update_lod(camera.global_position, lod_threshold)

func _init_planet():
	_preload_textures()
	if has_node("Terrain"): get_node("Terrain").free()
	
	terrain_node = Node3D.new()
	terrain_node.name = "Terrain"
	add_child(terrain_node)
	if Engine.is_editor_hint(): terrain_node.owner = get_tree().edited_scene_root

	var faces = [
		{"id": "A", "n": Vector3.RIGHT,   "a": Vector3.BACK,    "b": Vector3.UP},
		{"id": "B", "n": Vector3.LEFT,    "a": Vector3.FORWARD, "b": Vector3.UP},
		{"id": "C", "n": Vector3.UP,      "a": Vector3.RIGHT,   "b": Vector3.BACK},
		{"id": "D", "n": Vector3.DOWN,    "a": Vector3.RIGHT,   "b": Vector3.FORWARD},
		{"id": "E", "n": Vector3.FORWARD, "a": Vector3.RIGHT,   "b": Vector3.UP},
		{"id": "F", "n": Vector3.BACK,    "a": Vector3.LEFT,    "b": Vector3.UP}
	]
	
	for f in faces:
		var face_root = PlanetQuad.new(f.n, f.a, f.b, 0, Vector2.ZERO, 1.0, self, f.id)
		terrain_node.add_child(face_root)

func _preload_textures():
	_face_textures.clear()
	_height_textures.clear()
	for f in ["A", "B", "C", "D", "E", "F"]:
		var c_set = []; var h_set = []
		for i in range(1, 5):
			var c_p = color_dir.path_join(f + str(i) + out_format)
			var h_p = height_dir.path_join(f + str(i) + out_format)
			if FileAccess.file_exists(c_p): c_set.append(load(c_p))
			if FileAccess.file_exists(h_p): h_set.append(load(h_p))
		_face_textures[f] = c_set
		_height_textures[f] = h_set

class PlanetQuad extends Node3D:
	var normal: Vector3; var axis_a: Vector3; var axis_b: Vector3
	var level: int; var offset: Vector2; var size: float
	var planet: Node3D; var face_id: String
	var mesh_instance: MeshInstance3D
	var children = []

	func _init(_n, _a, _b, _l, _o, _s, _p, _f):
		normal = _n; axis_a = _a; axis_b = _b
		level = _l; offset = _o; size = _s
		planet = _p; face_id = _f
		_create_mesh()

	func _create_mesh():
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var res = planet.resolution
		
		var rot_transform = Transform3D.IDENTITY
		if face_id in ["A", "B", "E", "F"]:
			rot_transform = rot_transform.rotated(Vector3(0, 0, 1), deg_to_rad(-180.0))
			rot_transform = rot_transform.rotated(Vector3(0, 1, 0), deg_to_rad(180.0))

		for y in range(res + 1):
			for x in range(res + 1):
				var p = Vector2(x, y) / float(res)
				var uv = offset + p * size
				var point = (normal + axis_a * (uv.x - 0.5) * 2.0 + axis_b * (uv.y - 0.5) * 2.0).normalized()
				var final_point = rot_transform * point
				st.set_normal((rot_transform.basis * point).normalized())
				st.set_uv(uv)
				st.add_vertex(final_point * planet.radius)

		for y in range(res):
			for x in range(res):
				var i = x + y * (res + 1)
				st.add_index(i); st.add_index(i+1); st.add_index(i+res+1)
				st.add_index(i+1); st.add_index(i+res+2); st.add_index(i+res+1)
		
		mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = st.commit()
		add_child(mesh_instance)
		
		var mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = planet.LOD_SHADER
		mat.set_shader_parameter("h_scale", planet.height_scale)
		var c_tiles = planet._face_textures[face_id]
		var h_tiles = planet._height_textures[face_id]
		for i in range(c_tiles.size()): mat.set_shader_parameter("t"+str(i+1), c_tiles[i])
		for i in range(h_tiles.size()): mat.set_shader_parameter("h"+str(i+1), h_tiles[i])
		mesh_instance.set_surface_override_material(0, mat)

	func update_lod(cam_pos: Vector3, threshold: float):
		var dist = global_position.distance_to(cam_pos)
		var should_split = dist < (planet.radius / pow(1.6, level)) * threshold and level < planet.max_lod
		if should_split and children.is_empty(): _split()
		elif not should_split and not children.is_empty(): _merge()
		for child in children: child.update_lod(cam_pos, threshold)

	func _split():
		mesh_instance.visible = false
		var s = size * 0.5
		children.append(PlanetQuad.new(normal, axis_a, axis_b, level + 1, offset, s, planet, face_id))
		children.append(PlanetQuad.new(normal, axis_a, axis_b, level + 1, offset + Vector2(s, 0), s, planet, face_id))
		children.append(PlanetQuad.new(normal, axis_a, axis_b, level + 1, offset + Vector2(0, s), s, planet, face_id))
		children.append(PlanetQuad.new(normal, axis_a, axis_b, level + 1, offset + Vector2(s, s), s, planet, face_id))
		for c in children: add_child(c)

	func _merge():
		for c in children: c.queue_free()
		children.clear(); mesh_instance.visible = true

func _set_radius(v): radius = v; if Engine.is_editor_hint(): _init_planet()
func _set_res(v): resolution = v; if Engine.is_editor_hint(): _init_planet()
func _set_lod(v): max_lod = v; if Engine.is_editor_hint(): _init_planet()
func _set_hscale(v): height_scale = v; if Engine.is_editor_hint(): _init_planet()
func _spawn_trigger(v): if v: _init_planet(); spawn_planet = false
