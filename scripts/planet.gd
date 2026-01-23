@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var resolution: int = 32 
@export var spawn_planet: bool = false : set = _spawn_trigger

@export_group("Textures")
@export var global_albedo: Texture2D : set = _set_albedo
@export_dir var tiles_dir: String = "res://assets/earth tiles/21K"
@export var tile_prefix: String = "16k" 

@export_group("System")
@export var live_track: bool = true 
@export var load_dist: float = 2000.0 # Distance from planet center to trigger load

var terrain_node: Node3D
var patches: Array = []
var _texture_cache: Dictionary = {}
var _loading_set: Dictionary = {}
var _check_timer: float = 0.0

const PLANET_SHADER = """
shader_type spatial;
uniform sampler2D global_map : source_color, filter_linear_mipmap;
uniform sampler2D tile_map : source_color, filter_linear_mipmap;
uniform vec4 tile_bounds = vec4(0.0, 0.25, 0.0, 0.5);
uniform float tile_alpha : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_normal;

void vertex() { v_normal = normalize(VERTEX); }

void fragment() {
    vec3 n = normalize(v_normal);
    float u = (atan(n.x, n.z) + PI) / (2.0 * PI);
    float v = asin(n.y) / PI + 0.5;
    vec2 global_uv = vec2(u, 1.0 - v);
    
    vec3 g_color = texture(global_map, global_uv).rgb;
    vec3 final_color = g_color;

    if (tile_alpha > 0.01 && 
        global_uv.x >= tile_bounds.x && global_uv.x <= tile_bounds.y &&
        global_uv.y >= tile_bounds.z && global_uv.y <= tile_bounds.w) {
        
        vec2 tile_uv = (global_uv - tile_bounds.xz) / (tile_bounds.yw - tile_bounds.xz);
        vec3 t_color = texture(tile_map, tile_uv).rgb;
        final_color = mix(g_color, t_color, tile_alpha);
    }
    
    ALBEDO = final_color;
    ROUGHNESS = 0.8;
}
"""

func _ready():
	_check_timer = 0.0
	_init_planet()

func _process(delta):
	if _check_timer == null: _check_timer = 0.0
	_check_loading_status()
	
	if Engine.is_editor_hint() and not live_track: return
	
	_check_timer += delta
	if _check_timer > 0.1: 
		_check_timer = 0.0
		_update_logic(delta)

# THE OLD TRACKING SYSTEM REBORN
func _find_camera() -> Camera3D:
	if Engine.is_editor_hint():
		var vp = EditorInterface.get_editor_viewport_3d(0)
		if vp: return vp.get_camera_3d()
	return get_viewport().get_camera_3d()

func _init_planet():
	terrain_node = get_node_or_null("Terrain")
	if not terrain_node:
		terrain_node = Node3D.new(); terrain_node.name = "Terrain"; add_child(terrain_node)
		if Engine.is_editor_hint(): terrain_node.owner = get_tree().edited_scene_root
	else:
		for c in terrain_node.get_children(): c.queue_free()
	
	patches.clear()
	var dirs = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for i in range(6): _create_patch(dirs[i], i)

func _create_patch(n: Vector3, i: int):
	var axis_a = Vector3(n.y, n.z, n.x); var axis_b = n.cross(axis_a)
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s = 1.0/float(resolution)
	for y in range(resolution):
		for x in range(resolution):
			var p1=(n+axis_a*((x*s-0.5)*2.0)+axis_b*((y*s-0.5)*2.0)).normalized()*radius
			var p2=(n+axis_a*(((x+1)*s-0.5)*2.0)+axis_b*((y*s-0.5)*2.0)).normalized()*radius
			var p3=(n+axis_a*((x*s-0.5)*2.0)+axis_b*(((y+1)*s-0.5)*2.0)).normalized()*radius
			var p4=(n+axis_a*(((x+1)*s-0.5)*2.0)+axis_b*(((y+1)*s-0.5)*2.0)).normalized()*radius
			st.add_vertex(p3); st.add_vertex(p2); st.add_vertex(p1)
			st.add_vertex(p3); st.add_vertex(p4); st.add_vertex(p2)
	st.generate_normals()
	var mi = MeshInstance3D.new(); mi.mesh = st.commit(); terrain_node.add_child(mi)
	if Engine.is_editor_hint(): mi.owner = get_tree().edited_scene_root
	var mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = PLANET_SHADER
	if global_albedo: mat.set_shader_parameter("global_map", global_albedo)
	mi.set_surface_override_material(0, mat)
	
	patches.append({
		"node": mi, 
		"center": n * radius, 
		"active_tile": "", 
		"alpha": 0.0
	})

func _update_logic(delta):
	var cam = _find_camera()
	if not cam: return
	
	var cam_pos = to_local(cam.global_position)
	
	for p in patches:
		if not p.has("alpha"): continue
		
		# Distance logic from your working LOD system
		var dist = p["center"].distance_to(cam_pos)
		var is_near = dist < load_dist
		
		if is_near:
			p["alpha"] = min(p["alpha"] + delta * 2.0, 1.0)
			var n = p["center"].normalized()
			var u = (atan2(n.x, n.z) + PI) / (2.0 * PI)
			var v = asin(n.y) / PI + 0.5
			var guv = Vector2(u, 1.0 - v)
			var col = clamp(int(guv.x * 4.0), 0, 3)
			var row = clamp(int(guv.y * 2.0), 0, 1)
			var t_name = ["A","B","C","D"][col] + str(row + 1)
			
			if p["active_tile"] != t_name: _try_load_tile(p, t_name, col, row)
		else:
			p["alpha"] = max(p["alpha"] - delta * 2.0, 0.0)
			if p["alpha"] <= 0.0: p["active_tile"] = ""

		if is_instance_valid(p["node"]):
			var mat = p["node"].get_surface_override_material(0)
			if mat: mat.set_shader_parameter("tile_alpha", p["alpha"])

func _try_load_tile(p: Dictionary, name: String, c: int, r: int):
	if _texture_cache.has(name):
		var mat = p["node"].get_surface_override_material(0)
		if mat:
			mat.set_shader_parameter("tile_map", _texture_cache[name])
			mat.set_shader_parameter("tile_bounds", Vector4(c*0.25, (c+1)*0.25, r*0.5, (r+1)*0.5))
		p["active_tile"] = name
	else:
		if not _loading_set.has(name):
			var path = tiles_dir.path_join(tile_prefix + name + ".jpg")
			if FileAccess.file_exists(path):
				_loading_set[name] = path
				ResourceLoader.load_threaded_request(path)

func _check_loading_status():
	var finished = []
	for name in _loading_set:
		var status = ResourceLoader.load_threaded_get_status(_loading_set[name])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_texture_cache[name] = ResourceLoader.load_threaded_get(_loading_set[name])
			finished.append(name)
	for f in finished: _loading_set.erase(f)

func _set_radius(v): radius = v; if terrain_node: _init_planet()
func _set_albedo(v): global_albedo = v; if terrain_node: _init_planet()
func _spawn_trigger(v): if v: _init_planet(); spawn_planet = false
