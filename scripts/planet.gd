@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var height_scale: float = 25.0 : set = _set_hscale
@export var sea_level: float = 0.485 : set = _set_sea_level
@export var resolution: int = 32
@export var max_lod: int = 6 : set = _set_lod
@export var lod_threshold: float = 3.5

@export_group("Lighting & Shadows")
@export var sun_light: DirectionalLight3D : set = _set_sun_light
@export var sun_intensity: float = 2.0 : set = _set_intensity

@export_group("Terrain Settings")
@export var build_planet: bool = false : set = _trigger_build
@export var skirt_depth: float = 1.0
@export var ocean_bed_sink: float = 0.4 : set = _set_ocean_bed_sink

@export_group("Ocean Settings")
@export var ocean_enabled: bool = true : set = _set_ocean_enabled
@export var ocean_water_mask: Texture2D : set = _set_ocean_water_mask
@export var ocean_altitude: float = 0.0 : set = _set_ocean_altitude
@export var ocean_shallow_color: Color = Color(0.04, 0.42, 0.58, 0.8) : set = _set_ocean_shallow
@export var ocean_deep_color: Color = Color(0.01, 0.06, 0.18, 1.0) : set = _set_ocean_deep
@export var ocean_depth_distance: float = 6.0 : set = _set_ocean_depth_distance

@export_group("Clouds")
@export var cloud_enabled: bool = true : set = _set_cloud_enabled
@export var invert_clouds: bool = false : set = _set_invert_clouds
@export var cloud_texture: Texture2D : set = _set_cloud_texture
@export var cloud_altitude: float = 2.0 : set = _set_cloud_altitude
@export var cloud_thickness: float = 3.5 : set = _set_cloud_thickness
@export var cloud_density: float = 0.8 : set = _set_cloud_density
@export var cloud_coverage: float = 0.65 : set = _set_cloud_coverage
@export var cloud_speed: float = 0.001 : set = _set_cloud_speed
@export var cloud_day_brightness: float = 2.0 : set = _set_cloud_day_brightness
@export var cloud_night_brightness: float = 0.0 : set = _set_cloud_night_brightness
@export var cloud_map_height: float = 0.8 : set = _set_cloud_map_height
@export var cloud_map_density: float = 0.85 : set = _set_cloud_map_density
@export var cloud_color: Color = Color(1.0, 1.0, 1.0, 1.0) : set = _set_cloud_color
@export var cloud_shadow_color: Color = Color(0.18, 0.22, 0.32, 1.0) : set = _set_cloud_shadow_color
@export var cloud_shadow_intensity: float = 0.75 : set = _set_cloud_shadow_intensity
@export var noise_base_scale: float = 160.0 : set = _set_noise_base_scale
@export var noise_base_strength: float = 0.35 : set = _set_noise_base_strength
@export var noise_detail_scale: float = 400.0 : set = _set_noise_detail_scale
@export var noise_detail_strength: float = 0.2 : set = _set_noise_detail_strength

@export_group("Atmosphere")
@export var atmosphere_enabled: bool = true : set = _set_atmo_enabled
@export var atmosphere_scale: float = 1.06 : set = _set_atmo_scale
@export var rayleigh_coeff: Vector3 = Vector3(5.5e-6, 13.0e-6, 22.4e-6)
@export var scale_height_rayleigh: float = 0.015
@export var mie_coeff: float = 21.0e-6
@export var mie_g: float = 0.76
@export var scale_height_mie: float = 0.008

@export_group("Eye Adaptation & Skybox")
@export var eye_adaptation_enabled: bool = true : set = _set_eye_adaptation_enabled
@export var eye_adaptation_speed: float = 3.0 : set = _set_eye_adaptation_speed
@export var skybox_max_energy: float = 1.2 : set = _set_skybox_max_energy
@export var skybox_min_energy: float = 0.0 : set = _set_skybox_min_energy
@export var auto_exposure_scale: float = 0.4 : set = _set_auto_exposure_scale

@export_group("Surface Directories (Default Loading)")
@export_dir var color_dir: String = "res://assets/planets/earth/tiles/colour"
@export_dir var height_dir: String = "res://assets/planets/earth/tiles/height"
@export_dir var normal_dir: String = "res://assets/planets/earth/tiles/normal"
@export_dir var water_dir: String = "res://assets/planets/earth/tiles/water"
@export var out_format: String = ".png"
@export var reload_all_tiles: bool = false : set = _trigger_reload_tiles

@export_group("Surface Tiles - Face A (+X)")
@export var face_a_color: Array[Texture2D] = [] : set = _set_face_a_color
@export var face_a_height: Array[Texture2D] = [] : set = _set_face_a_height
@export var face_a_normal: Array[Texture2D] = [] : set = _set_face_a_normal
@export var face_a_water: Array[Texture2D] = [] : set = _set_face_a_water

@export_group("Surface Tiles - Face B (-X)")
@export var face_b_color: Array[Texture2D] = [] : set = _set_face_b_color
@export var face_b_height: Array[Texture2D] = [] : set = _set_face_b_height
@export var face_b_normal: Array[Texture2D] = [] : set = _set_face_b_normal
@export var face_b_water: Array[Texture2D] = [] : set = _set_face_b_water

@export_group("Surface Tiles - Face C (+Y)")
@export var face_c_color: Array[Texture2D] = [] : set = _set_face_c_color
@export var face_c_height: Array[Texture2D] = [] : set = _set_face_c_height
@export var face_c_normal: Array[Texture2D] = [] : set = _set_face_c_normal
@export var face_c_water: Array[Texture2D] = [] : set = _set_face_c_water

@export_group("Surface Tiles - Face D (-Y)")
@export var face_d_color: Array[Texture2D] = [] : set = _set_face_d_color
@export var face_d_height: Array[Texture2D] = [] : set = _set_face_d_height
@export var face_d_normal: Array[Texture2D] = [] : set = _set_face_d_normal
@export var face_d_water: Array[Texture2D] = [] : set = _set_face_d_water

@export_group("Surface Tiles - Face E (+Z)")
@export var face_e_color: Array[Texture2D] = [] : set = _set_face_e_color
@export var face_e_height: Array[Texture2D] = [] : set = _set_face_e_height
@export var face_e_normal: Array[Texture2D] = [] : set = _set_face_e_normal
@export var face_e_water: Array[Texture2D] = [] : set = _set_face_e_water

@export_group("Surface Tiles - Face F (-Z)")
@export var face_f_color: Array[Texture2D] = [] : set = _set_face_f_color
@export var face_f_height: Array[Texture2D] = [] : set = _set_face_f_height
@export var face_f_normal: Array[Texture2D] = [] : set = _set_face_f_normal
@export var face_f_water: Array[Texture2D] = [] : set = _set_face_f_water

var camera: Camera3D
var _face_textures: Dictionary = {}
var _height_textures: Dictionary = {}
var _normal_textures: Dictionary = {}
var _water_textures: Dictionary = {}
var root_quads: Array = []
var face_nodes: Dictionary = {}
var ocean_face_nodes: Dictionary = {}
var _pending_updates: Dictionary = {}

var _ocean_material: ShaderMaterial
var _cloud_node: MeshInstance3D
var _cloud_material: ShaderMaterial
var _atmo_node: MeshInstance3D
var _atmo_material: ShaderMaterial
var _shared_shader: Shader
var _world_env: WorldEnvironment
var _sky_material: PanoramaSkyMaterial
var _camera_attributes: CameraAttributesPractical
var current_perceived_brightness: float = 0.0
var current_skybox_energy: float = 1.2

const FACE_IDS: Array[String] = ["A", "B", "C", "D", "E", "F"]
const ROTATED_FACES: Array[String] = ["A", "B", "E", "F"]

const MONOLITH_SHADER = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D t1 : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D t2 : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D t3 : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D t4 : source_color, repeat_disable, filter_linear_mipmap_anisotropic;

uniform sampler2D h1 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D h2 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D h3 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D h4 : repeat_disable, filter_linear_mipmap_anisotropic;

uniform sampler2D n1 : hint_normal, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D n2 : hint_normal, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D n3 : hint_normal, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D n4 : hint_normal, repeat_disable, filter_linear_mipmap_anisotropic;

uniform sampler2D w1 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D w2 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D w3 : repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D w4 : repeat_disable, filter_linear_mipmap_anisotropic;

uniform float sea_level = 0.485;
uniform float h_scale = 25.0;
uniform float ocean_bed_sink = 0.4;

// Cloud Shadow Projection
uniform bool cloud_enabled = true;
uniform bool invert_clouds = false;
uniform sampler2D cloud_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_radius = 600.0;
uniform float cloud_altitude = 2.0;
uniform float cloud_thickness = 3.5;
uniform float cloud_coverage = 0.65;
uniform float cloud_speed = 0.001;
uniform float cloud_shadow_intensity = 0.75;

varying vec2 v_uv;
varying float v_is_skirt;
varying vec3 v_world_pos;
varying vec3 v_world_normal;

vec2 safe_uv(vec2 uv) {
    return clamp(uv, 0.0002, 0.9998);
}

float get_h(vec2 uv) {
    vec2 cuv = clamp(uv, 0.0, 1.0);
    if (cuv.y < 0.5) {
        vec2 luv = cuv * 2.0;
        if (cuv.x < 0.5) return textureLod(h1, safe_uv(luv), 0.0).r;
        luv.x -= 1.0;
        return textureLod(h2, safe_uv(luv), 0.0).r;
    } else {
        vec2 luv = cuv * 2.0;
        luv.y -= 1.0;
        if (cuv.x < 0.5) return textureLod(h3, safe_uv(luv), 0.0).r;
        luv.x -= 1.0;
        return textureLod(h4, safe_uv(luv), 0.0).r;
    }
}

float get_water(vec2 uv) {
    vec2 cuv = clamp(uv, 0.0, 1.0);
    if (cuv.y < 0.5) {
        vec2 luv = cuv * 2.0;
        if (cuv.x < 0.5) return textureLod(w1, safe_uv(luv), 0.0).r;
        luv.x -= 1.0;
        return textureLod(w2, safe_uv(luv), 0.0).r;
    } else {
        vec2 luv = cuv * 2.0;
        luv.y -= 1.0;
        if (cuv.x < 0.5) return textureLod(w3, safe_uv(luv), 0.0).r;
        luv.x -= 1.0;
        return textureLod(w4, safe_uv(luv), 0.0).r;
    }
}

void vertex() {
    v_uv = UV;
    v_is_skirt = UV2.x;
    if (v_is_skirt >= 0.0) {
        float h = get_h(UV);
        float is_water = get_water(UV);

        float raw_elev = (h - sea_level) * h_scale;
        float land_elev = max(raw_elev, 0.0);
        float water_elev = min(raw_elev, 0.0) - ocean_bed_sink;
        float elev = mix(land_elev, water_elev, is_water);

        VERTEX += NORMAL * elev;
    }
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 tex_color  = vec3(0.5);
    vec3 map_normal = vec3(0.5, 0.5, 1.0);

    // Compute continuous screen-space partial derivatives before any conditional branching.
    // This prevents GPU mipmap derivative divergence at quadrant boundaries (cuv.x=0.5, cuv.y=0.5),
    // which previously selected the coarsest 1x1 mip level and painted a black line.
    vec2 ddx = dFdx(v_uv * 2.0);
    vec2 ddy = dFdy(v_uv * 2.0);

    vec2 cuv = clamp(v_uv, 0.0, 1.0);
    if (cuv.y < 0.5) {
        vec2 luv = cuv * 2.0;
        if (cuv.x < 0.5) {
            tex_color  = textureGrad(t1, safe_uv(luv), ddx, ddy).rgb;
            map_normal = textureGrad(n1, safe_uv(luv), ddx, ddy).rgb;
        } else {
            luv.x -= 1.0;
            tex_color  = textureGrad(t2, safe_uv(luv), ddx, ddy).rgb;
            map_normal = textureGrad(n2, safe_uv(luv), ddx, ddy).rgb;
        }
    } else {
        vec2 luv = cuv * 2.0;
        luv.y -= 1.0;
        if (cuv.x < 0.5) {
            tex_color  = textureGrad(t3, safe_uv(luv), ddx, ddy).rgb;
            map_normal = textureGrad(n3, safe_uv(luv), ddx, ddy).rgb;
        } else {
            luv.x -= 1.0;
            tex_color  = textureGrad(t4, safe_uv(luv), ddx, ddy).rgb;
            map_normal = textureGrad(n4, safe_uv(luv), ddx, ddy).rgb;
        }
    }

    // Dynamic Cloud Shadow on Terrain:
    if (cloud_enabled) {
        vec3 sun_norm = -normalize(sun_dir);
        float sun_dot = dot(v_world_normal, sun_norm);
        if (sun_dot > -0.05) {
            float r_cloud = planet_radius + cloud_altitude + cloud_thickness * 0.5;
            vec3 d_c = v_world_pos - planet_center;
            float b = dot(d_c, sun_norm);
            float c = dot(d_c, d_c) - r_cloud * r_cloud;
            float disc = b * b - c;
            if (disc > 0.0) {
                float t_hit = -b + sqrt(disc);
                if (t_hit > 0.0) {
                    vec3 p_cloud = v_world_pos + sun_norm * t_hit;
                    vec3 n_cloud = normalize(p_cloud - planet_center);
                    float lat_c = asin(clamp(n_cloud.y, -1.0, 1.0));
                    float v_c = 0.5 - lat_c / 3.141592653589793;
                    float lon_c = atan(n_cloud.x, n_cloud.z);
                    float u_c = fract(lon_c / (2.0 * 3.141592653589793) + 0.5 + TIME * cloud_speed);
                    float c_a = textureLod(cloud_texture, vec2(u_c, v_c), 0.0).a;
                    float cov = invert_clouds ? (1.0 - c_a) : c_a;
                    float sun_facing = clamp(sun_dot * 5.0, 0.0, 1.0);
                    float shadow_factor = smoothstep(1.0 - cloud_coverage * 0.9, 1.0, cov) * sun_facing;
                    tex_color *= mix(vec3(1.0), vec3(0.38, 0.44, 0.55), shadow_factor * (cloud_shadow_intensity * 0.96));
                }
            }
        }
    }

    ALBEDO = tex_color;
    NORMAL_MAP = map_normal;
    NORMAL_MAP_DEPTH = 1.0;
    ROUGHNESS = 0.85;
    SPECULAR = 0.04;
    METALLIC = 0.0;
}
"""

func _ready() -> void:
	_build_planet()
	_setup_environment_and_adaptation()

func _get_active_camera() -> Camera3D:
	if Engine.is_editor_hint():
		var vp := get_viewport()
		if vp:
			var cam := vp.get_camera_3d()
			if cam:
				return cam
		if ClassDB.class_exists("EditorInterface"):
			var ei := Engine.get_singleton("EditorInterface")
			if ei and ei.has_method("get_editor_viewport_3d"):
				var evp = ei.get_editor_viewport_3d(0)
				if evp:
					return evp.get_camera_3d()
		return null
	if not camera:
		camera = get_viewport().get_camera_3d()
	return camera

func _process(delta: float) -> void:
	if sun_light:
		var dir_to_planet := global_position - sun_light.global_position
		if dir_to_planet.length_squared() > 0.01:
			sun_light.look_at(global_position)

	var active_cam := _get_active_camera()
	if active_cam:
		_update_lod(active_cam.global_position)
		_update_eye_adaptation(delta, active_cam)

	if is_inside_tree() and sun_light and sun_light.is_inside_tree():
		var s_dir := -sun_light.global_transform.basis.z.normalized()
		if _atmo_material:
			_atmo_material.set_shader_parameter("planet_center", global_position)
			_atmo_material.set_shader_parameter("sun_dir", s_dir)
		if _ocean_material:
			_ocean_material.set_shader_parameter("planet_center", global_position)
			_ocean_material.set_shader_parameter("sun_dir", s_dir)
		for fid in face_nodes.keys():
			var mi: MeshInstance3D = face_nodes[fid]
			if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
				var mat := mi.mesh.surface_get_material(0) as ShaderMaterial
				if mat:
					mat.set_shader_parameter("planet_center", global_position)
					mat.set_shader_parameter("sun_dir", s_dir)

const FACE_CONFIGS: Array[Dictionary] = [
	{"id": "A", "n": Vector3.RIGHT,   "a": Vector3.BACK,    "b": Vector3.UP},
	{"id": "B", "n": Vector3.LEFT,    "a": Vector3.FORWARD, "b": Vector3.UP},
	{"id": "C", "n": Vector3.UP,      "a": Vector3.RIGHT,   "b": Vector3.BACK},
	{"id": "D", "n": Vector3.DOWN,    "a": Vector3.RIGHT,   "b": Vector3.FORWARD},
	{"id": "E", "n": Vector3.FORWARD, "a": Vector3.RIGHT,   "b": Vector3.UP},
	{"id": "F", "n": Vector3.BACK,    "a": Vector3.LEFT,    "b": Vector3.UP},
]

func _build_planet() -> void:
	_preload_textures()

	if not _shared_shader:
		_shared_shader = Shader.new()
	_shared_shader.code = MONOLITH_SHADER

	if not _ocean_material:
		_ocean_material = ShaderMaterial.new()
	_ocean_material.shader = load("res://shaders/ocean.gdshader") as Shader
	_ocean_material.render_priority = 1
	_update_ocean_params()

	for child in get_children():
		if child.name.begins_with("Face_") or child.name.begins_with("Ocean_") or child.name == "OceanShell" or child.name == "AtmosphereShell" or child.name == "CloudShell":
			child.queue_free()
	face_nodes.clear()
	ocean_face_nodes.clear()
	root_quads.clear()
	_pending_updates.clear()

	for cfg in FACE_CONFIGS:
		var mi := MeshInstance3D.new()
		mi.name = "Face_" + cfg.id
		add_child(mi)
		face_nodes[cfg.id] = mi

		var o_mi := MeshInstance3D.new()
		o_mi.name = "Ocean_" + cfg.id
		o_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o_mi.visible = ocean_enabled
		add_child(o_mi)
		ocean_face_nodes[cfg.id] = o_mi

		var q := QuadData.new(cfg.n, cfg.a, cfg.b, 0, Vector2.ZERO, 1.0, cfg.id)
		root_quads.append(q)
		_request_face_update(cfg.id, q)

	_update_shader_params()
	_build_atmosphere()

func _update_lod(cam_pos: Vector3) -> void:
	for q in root_quads:
		if q.update_lod(cam_pos, radius, max_lod, lod_threshold, global_transform):
			_request_face_update(q.face_id, q)

func _request_face_update(face_id: String, root_q: QuadData) -> void:
	if _pending_updates.has(face_id):
		return
	_pending_updates[face_id] = true
	var snap_radius := radius
	var snap_resolution := resolution
	var snap_skirt := skirt_depth
	WorkerThreadPool.add_task(
		_threaded_gen.bind(face_id, root_q, snap_radius, snap_resolution, snap_skirt)
	)

func _threaded_gen(face_id: String, root_q: QuadData,
		snap_radius: float, snap_resolution: int, snap_skirt: float) -> void:
	var active_quads: Array[QuadData] = []
	_collect_leaves(root_q, active_quads)

	var verts   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var uv2s    := PackedVector2Array()
	var norms   := PackedVector3Array()
	var tans    := PackedFloat32Array()
	var indices := PackedInt32Array()

	var res        := snap_resolution
	var is_rotated := face_id in ROTATED_FACES

	for q in active_quads:
		var v_offset := verts.size()

		for y in range(res + 1):
			for x in range(res + 1):
				var raw_t := Vector2(x, y) / float(res)
				var uv    := q.offset + raw_t * q.size

				var p := (q.normal
					+ q.axis_a * (uv.x - 0.5) * 2.0
					+ q.axis_b * (uv.y - 0.5) * 2.0).normalized()
				var t := q.axis_a.normalized()

				if is_rotated:
					p = p.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
					t = t.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)

				t = (t - p * t.dot(p)).normalized()

				verts.append(p * snap_radius)
				uvs.append(uv)
				uv2s.append(Vector2(0.0, 0.0))
				norms.append(p)
				tans.append(t.x); tans.append(t.y); tans.append(t.z); tans.append(1.0)

		for y in range(res):
			for x in range(res):
				var i := v_offset + x + y * (res + 1)
				indices.append(i)
				indices.append(i + 1)
				indices.append(i + res + 1)
				indices.append(i + 1)
				indices.append(i + res + 2)
				indices.append(i + res + 1)

		const EPS := 1e-5
		var on_top    := q.offset.y < EPS
		var on_bottom := (q.offset.y + q.size) > 1.0 - EPS
		var on_left   := q.offset.x < EPS
		var on_right  := (q.offset.x + q.size) > 1.0 - EPS

		var skirt_idx_of := func(grid_i: int) -> int:
			var gp := verts[v_offset + grid_i]
			var gn := norms[v_offset + grid_i]
			var gu := uvs[v_offset + grid_i]
			var ti := (v_offset + grid_i) * 4
			var gt := Vector3(tans[ti], tans[ti + 1], tans[ti + 2])
			var tw := tans[ti + 3]

			var idx := verts.size()
			verts.append(gp - gn * snap_skirt)
			uvs.append(gu)
			uv2s.append(Vector2(-1.0, -1.0))
			norms.append(gn)
			tans.append(gt.x); tans.append(gt.y); tans.append(gt.z); tans.append(tw)
			return idx

		var emit_skirt_quad := func(ga: int, gb: int) -> void:
			var a  := v_offset + ga
			var b  := v_offset + gb
			var sa: int = skirt_idx_of.call(ga)
			var sb: int = skirt_idx_of.call(gb)
			indices.append(a);  indices.append(sa); indices.append(sb)
			indices.append(a);  indices.append(sb); indices.append(b)
			indices.append(sa); indices.append(a);  indices.append(sb)
			indices.append(sb); indices.append(a);  indices.append(b)

		if not on_top:
			for x in range(res):
				emit_skirt_quad.call(x, x + 1)

		if not on_bottom:
			var row_bot := res * (res + 1)
			for x in range(res):
				emit_skirt_quad.call(row_bot + x, row_bot + x + 1)

		if not on_left:
			for y in range(res):
				emit_skirt_quad.call(y * (res + 1), (y + 1) * (res + 1))

		if not on_right:
			for y in range(res):
				emit_skirt_quad.call(y * (res + 1) + res, (y + 1) * (res + 1) + res)

	call_deferred("_apply_mesh", face_id, verts, uvs, uv2s, norms, tans, indices)

func _apply_mesh(fid: String, v: PackedVector3Array, u: PackedVector2Array,
		u2: PackedVector2Array, n: PackedVector3Array,
		t: PackedFloat32Array, idx: PackedInt32Array) -> void:
	if not face_nodes.has(fid):
		_pending_updates.erase(fid)
		return

	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]   = v
	arr[Mesh.ARRAY_TEX_UV]   = u
	arr[Mesh.ARRAY_TEX_UV2]  = u2
	arr[Mesh.ARRAY_NORMAL]   = n
	arr[Mesh.ARRAY_TANGENT]  = t
	arr[Mesh.ARRAY_INDEX]    = idx

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mi: MeshInstance3D = face_nodes[fid]
	var mat: ShaderMaterial
	if mi.mesh and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0) as ShaderMaterial

	if not mat:
		mat = _create_face_material(fid)

	am.surface_set_material(0, mat)
	mi.mesh = am

	# PQS Ocean: Shares the exact same quadsphere mesh as terrain for perfect LOD and chord synchronization
	if ocean_face_nodes.has(fid):
		var o_mi: MeshInstance3D = ocean_face_nodes[fid]
		o_mi.mesh = am
		o_mi.material_override = _ocean_material

	_pending_updates.erase(fid)

func _create_face_material(fid: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shared_shader
	mat.set_shader_parameter("sea_level", sea_level)
	mat.set_shader_parameter("h_scale", height_scale)
	mat.set_shader_parameter("ocean_bed_sink", ocean_bed_sink)

	mat.set_shader_parameter("cloud_enabled", cloud_enabled)
	mat.set_shader_parameter("invert_clouds", invert_clouds)
	mat.set_shader_parameter("planet_center", global_position)
	mat.set_shader_parameter("planet_radius", radius)
	mat.set_shader_parameter("cloud_altitude", cloud_altitude)
	mat.set_shader_parameter("cloud_thickness", cloud_thickness)
	mat.set_shader_parameter("cloud_coverage", cloud_coverage)
	mat.set_shader_parameter("cloud_speed", cloud_speed)
	mat.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
	if cloud_texture:
		mat.set_shader_parameter("cloud_texture", cloud_texture)
	elif ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
		cloud_texture = load("res://assets/planets/earth/clouds_4k.png")
		mat.set_shader_parameter("cloud_texture", cloud_texture)
	if is_inside_tree() and sun_light and sun_light.is_inside_tree():
		mat.set_shader_parameter("sun_dir", -sun_light.global_transform.basis.z.normalized())

	var c_list: Array = _face_textures.get(fid, [])
	var h_list: Array = _height_textures.get(fid, [])
	var n_list: Array = _normal_textures.get(fid, [])
	var w_list: Array = _water_textures.get(fid, [])

	for i in range(4):
		if i < c_list.size() and c_list[i]:
			mat.set_shader_parameter("t" + str(i + 1), c_list[i])
		if i < h_list.size() and h_list[i]:
			mat.set_shader_parameter("h" + str(i + 1), h_list[i])
		if i < n_list.size() and n_list[i]:
			mat.set_shader_parameter("n" + str(i + 1), n_list[i])
		if i < w_list.size() and w_list[i]:
			mat.set_shader_parameter("w" + str(i + 1), w_list[i])

	return mat

func _refresh_face_material(fid: String) -> void:
	if not face_nodes.has(fid):
		return
	var mi: MeshInstance3D = face_nodes[fid]
	if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
		var mat := _create_face_material(fid)
		mi.mesh.surface_set_material(0, mat)

func _collect_leaves(q: QuadData, list: Array[QuadData]) -> void:
	if q.children.is_empty():
		list.append(q)
	else:
		for c in q.children:
			_collect_leaves(c, list)

func _preload_textures() -> void:
	# Synchronize inspector face arrays with internal dictionaries
	var face_arr_map := {
		"A": [face_a_color, face_a_height, face_a_normal, face_a_water],
		"B": [face_b_color, face_b_height, face_b_normal, face_b_water],
		"C": [face_c_color, face_c_height, face_c_normal, face_c_water],
		"D": [face_d_color, face_d_height, face_d_normal, face_d_water],
		"E": [face_e_color, face_e_height, face_e_normal, face_e_water],
		"F": [face_f_color, face_f_height, face_f_normal, face_f_water],
	}

	for f in FACE_IDS:
		var arrs = face_arr_map[f]
		var c_arr: Array[Texture2D] = arrs[0]
		var h_arr: Array[Texture2D] = arrs[1]
		var n_arr: Array[Texture2D] = arrs[2]
		var w_arr: Array[Texture2D] = arrs[3]

		# If empty, populate from directories by default
		if c_arr.is_empty() or h_arr.is_empty() or n_arr.is_empty() or w_arr.is_empty():
			for i in range(1, 5):
				var suffix := f + str(i) + out_format
				var c_p := color_dir.path_join(suffix)
				var h_p := height_dir.path_join(suffix)
				var n_p := normal_dir.path_join(suffix)
				var w_p := water_dir.path_join(suffix)

				if c_arr.size() < i and FileAccess.file_exists(c_p):
					c_arr.append(load(c_p))
				if h_arr.size() < i and FileAccess.file_exists(h_p):
					h_arr.append(load(h_p))
				if n_arr.size() < i and FileAccess.file_exists(n_p):
					n_arr.append(load(n_p))
				if w_arr.size() < i and FileAccess.file_exists(w_p):
					w_arr.append(load(w_p))

		_face_textures[f] = c_arr
		_height_textures[f] = h_arr
		_normal_textures[f] = n_arr
		_water_textures[f] = w_arr

	# Initialize cloud texture default if not yet set
	if not cloud_texture:
		if ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
			cloud_texture = load("res://assets/planets/earth/clouds_4k.png")

	# Initialize water mask texture default if not yet set
	if not ocean_water_mask:
		if ResourceLoader.exists("res://assets/earth_landocean_16K.png"):
			ocean_water_mask = load("res://assets/earth_landocean_16K.png")
		elif ResourceLoader.exists("res://assets/planets/earth/water_mask.png"):
			ocean_water_mask = load("res://assets/planets/earth/water_mask.png")

class QuadData:
	var normal: Vector3
	var axis_a: Vector3
	var axis_b: Vector3
	var level: int
	var offset: Vector2
	var size: float
	var face_id: String
	var children: Array[QuadData] = []
	var center: Vector3

	func _init(_n: Vector3, _a: Vector3, _b: Vector3,
			_l: int, _o: Vector2, _s: float, _f: String) -> void:
		normal  = _n
		axis_a  = _a
		axis_b  = _b
		level   = _l
		offset  = _o
		size    = _s
		face_id = _f

		var mid_uv := offset + Vector2(0.5, 0.5) * size
		var lp := (normal
			+ axis_a * (mid_uv.x - 0.5) * 2.0
			+ axis_b * (mid_uv.y - 0.5) * 2.0).normalized()
		if face_id in ROTATED_FACES:
			lp = lp.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
		center = lp

	func update_lod(cam_pos: Vector3, rad: float, max_l: int,
			thresh: float, trans: Transform3D) -> bool:
		var world_center := trans * (center * rad)
		var dist := world_center.distance_to(cam_pos)
		var should_split := dist < (rad / pow(2.0, level)) * thresh and level < max_l

		var changed := false
		if should_split and children.is_empty():
			_split()
			changed = true
		elif not should_split and not children.is_empty():
			children.clear()
			changed = true

		if not children.is_empty():
			for c in children:
				if c.update_lod(cam_pos, rad, max_l, thresh, trans):
					changed = true
		return changed

	func _split() -> void:
		var s := size * 0.5
		for o in [Vector2.ZERO, Vector2(s, 0), Vector2(0, s), Vector2(s, s)]:
			children.append(QuadData.new(
				normal, axis_a, axis_b, level + 1, offset + o, s, face_id
			))

func _update_ocean_params() -> void:
	if not _ocean_material:
		return
	_ocean_material.set_shader_parameter("ocean_altitude", ocean_altitude)
	_ocean_material.set_shader_parameter("shallow_color", ocean_shallow_color)
	_ocean_material.set_shader_parameter("deep_color", ocean_deep_color)
	_ocean_material.set_shader_parameter("depth_distance", ocean_depth_distance)
	_ocean_material.set_shader_parameter("planet_center", global_position)
	_ocean_material.set_shader_parameter("planet_radius", radius)
	if is_inside_tree() and sun_light and sun_light.is_inside_tree():
		_ocean_material.set_shader_parameter("sun_dir", -sun_light.global_transform.basis.z.normalized())
	if ocean_water_mask:
		_ocean_material.set_shader_parameter("water_mask", ocean_water_mask)
	elif ResourceLoader.exists("res://assets/earth_landocean_16K.png"):
		ocean_water_mask = load("res://assets/earth_landocean_16K.png")
		_ocean_material.set_shader_parameter("water_mask", ocean_water_mask)

	# Cloud shadow projection on ocean
	_ocean_material.set_shader_parameter("cloud_enabled", cloud_enabled)
	_ocean_material.set_shader_parameter("invert_clouds", invert_clouds)
	_ocean_material.set_shader_parameter("cloud_altitude", cloud_altitude)
	_ocean_material.set_shader_parameter("cloud_thickness", cloud_thickness)
	_ocean_material.set_shader_parameter("cloud_coverage", cloud_coverage)
	_ocean_material.set_shader_parameter("cloud_speed", cloud_speed)
	_ocean_material.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
	if cloud_texture:
		_ocean_material.set_shader_parameter("cloud_texture", cloud_texture)
	elif ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
		cloud_texture = load("res://assets/planets/earth/clouds_4k.png")
		_ocean_material.set_shader_parameter("cloud_texture", cloud_texture)

func _set_ocean_enabled(v: bool) -> void:
	ocean_enabled = v
	for o_mi: MeshInstance3D in ocean_face_nodes.values():
		o_mi.visible = v

func _set_ocean_water_mask(v: Texture2D) -> void:
	ocean_water_mask = v
	_update_ocean_params()

func _set_ocean_altitude(v: float) -> void:
	ocean_altitude = v
	_update_ocean_params()

func _set_ocean_shallow(v: Color) -> void:
	ocean_shallow_color = v
	_update_ocean_params()

func _set_ocean_deep(v: Color) -> void:
	ocean_deep_color = v
	_update_ocean_params()

func _set_ocean_depth_distance(v: float) -> void:
	ocean_depth_distance = v
	_update_ocean_params()

func _set_ocean_bed_sink(v: float) -> void:
	ocean_bed_sink = v
	_update_shader_params()

func _set_sea_level(v: float) -> void:
	sea_level = v
	_update_shader_params()

func _set_radius(v: float) -> void:
	radius = v
	if Engine.is_editor_hint():
		_build_planet()

func _set_lod(v: int) -> void:
	max_lod = v
	if Engine.is_editor_hint():
		_build_planet()

func _set_hscale(v: float) -> void:
	height_scale = v
	_update_shader_params()

func _set_intensity(v: float) -> void:
	sun_intensity = v
	_update_shader_params()
	_update_atmosphere_params()

func _set_sun_light(v: DirectionalLight3D) -> void:
	sun_light = v
	_update_shader_params()
	_update_ocean_params()
	_update_atmosphere_params()

func _update_cloud_params() -> void:
	_update_atmosphere_params()
	_update_shader_params()
	_update_ocean_params()

func _trigger_build(v: bool) -> void:
	if v:
		_build_planet()
	build_planet = false

func _trigger_reload_tiles(v: bool) -> void:
	if v:
		for f in FACE_IDS:
			_face_textures[f] = []
			_height_textures[f] = []
			_normal_textures[f] = []
			_water_textures[f] = []
		face_a_color.clear(); face_a_height.clear(); face_a_normal.clear(); face_a_water.clear()
		face_b_color.clear(); face_b_height.clear(); face_b_normal.clear(); face_b_water.clear()
		face_c_color.clear(); face_c_height.clear(); face_c_normal.clear(); face_c_water.clear()
		face_d_color.clear(); face_d_height.clear(); face_d_normal.clear(); face_d_water.clear()
		face_e_color.clear(); face_e_height.clear(); face_e_normal.clear(); face_e_water.clear()
		face_f_color.clear(); face_f_height.clear(); face_f_normal.clear(); face_f_water.clear()
		_preload_textures()
		for f in FACE_IDS:
			_refresh_face_material(f)
	reload_all_tiles = false

func _update_shader_params() -> void:
	if sun_light:
		sun_light.light_energy = sun_intensity
	var s_dir := Vector3.UP
	if is_inside_tree() and sun_light and sun_light.is_inside_tree():
		s_dir = -sun_light.global_transform.basis.z.normalized()
	for fid in face_nodes.keys():
		var mi: MeshInstance3D = face_nodes[fid]
		if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat := mi.mesh.surface_get_material(0) as ShaderMaterial
			if mat:
				mat.set_shader_parameter("sea_level", sea_level)
				mat.set_shader_parameter("h_scale", height_scale)
				mat.set_shader_parameter("ocean_bed_sink", ocean_bed_sink)
				mat.set_shader_parameter("cloud_enabled", cloud_enabled)
				mat.set_shader_parameter("invert_clouds", invert_clouds)
				mat.set_shader_parameter("planet_center", global_position)
				mat.set_shader_parameter("sun_dir", s_dir)
				mat.set_shader_parameter("planet_radius", radius)
				mat.set_shader_parameter("cloud_altitude", cloud_altitude)
				mat.set_shader_parameter("cloud_thickness", cloud_thickness)
				mat.set_shader_parameter("cloud_coverage", cloud_coverage)
				mat.set_shader_parameter("cloud_speed", cloud_speed)
				mat.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
				if cloud_texture:
					mat.set_shader_parameter("cloud_texture", cloud_texture)
				elif ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
					cloud_texture = load("res://assets/planets/earth/clouds_4k.png")
					mat.set_shader_parameter("cloud_texture", cloud_texture)

# Face tile property setters
func _set_face_a_color(v: Array[Texture2D]) -> void: face_a_color = v; _face_textures["A"] = v; _refresh_face_material("A")
func _set_face_a_height(v: Array[Texture2D]) -> void: face_a_height = v; _height_textures["A"] = v; _refresh_face_material("A")
func _set_face_a_normal(v: Array[Texture2D]) -> void: face_a_normal = v; _normal_textures["A"] = v; _refresh_face_material("A")
func _set_face_a_water(v: Array[Texture2D]) -> void: face_a_water = v; _water_textures["A"] = v; _refresh_face_material("A")

func _set_face_b_color(v: Array[Texture2D]) -> void: face_b_color = v; _face_textures["B"] = v; _refresh_face_material("B")
func _set_face_b_height(v: Array[Texture2D]) -> void: face_b_height = v; _height_textures["B"] = v; _refresh_face_material("B")
func _set_face_b_normal(v: Array[Texture2D]) -> void: face_b_normal = v; _normal_textures["B"] = v; _refresh_face_material("B")
func _set_face_b_water(v: Array[Texture2D]) -> void: face_b_water = v; _water_textures["B"] = v; _refresh_face_material("B")

func _set_face_c_color(v: Array[Texture2D]) -> void: face_c_color = v; _face_textures["C"] = v; _refresh_face_material("C")
func _set_face_c_height(v: Array[Texture2D]) -> void: face_c_height = v; _height_textures["C"] = v; _refresh_face_material("C")
func _set_face_c_normal(v: Array[Texture2D]) -> void: face_c_normal = v; _normal_textures["C"] = v; _refresh_face_material("C")
func _set_face_c_water(v: Array[Texture2D]) -> void: face_c_water = v; _water_textures["C"] = v; _refresh_face_material("C")

func _set_face_d_color(v: Array[Texture2D]) -> void: face_d_color = v; _face_textures["D"] = v; _refresh_face_material("D")
func _set_face_d_height(v: Array[Texture2D]) -> void: face_d_height = v; _height_textures["D"] = v; _refresh_face_material("D")
func _set_face_d_normal(v: Array[Texture2D]) -> void: face_d_normal = v; _normal_textures["D"] = v; _refresh_face_material("D")
func _set_face_d_water(v: Array[Texture2D]) -> void: face_d_water = v; _water_textures["D"] = v; _refresh_face_material("D")

func _set_face_e_color(v: Array[Texture2D]) -> void: face_e_color = v; _face_textures["E"] = v; _refresh_face_material("E")
func _set_face_e_height(v: Array[Texture2D]) -> void: face_e_height = v; _height_textures["E"] = v; _refresh_face_material("E")
func _set_face_e_normal(v: Array[Texture2D]) -> void: face_e_normal = v; _normal_textures["E"] = v; _refresh_face_material("E")
func _set_face_e_water(v: Array[Texture2D]) -> void: face_e_water = v; _water_textures["E"] = v; _refresh_face_material("E")

func _set_face_f_color(v: Array[Texture2D]) -> void: face_f_color = v; _face_textures["F"] = v; _refresh_face_material("F")
func _set_face_f_height(v: Array[Texture2D]) -> void: face_f_height = v; _height_textures["F"] = v; _refresh_face_material("F")
func _set_face_f_normal(v: Array[Texture2D]) -> void: face_f_normal = v; _normal_textures["F"] = v; _refresh_face_material("F")
func _set_face_f_water(v: Array[Texture2D]) -> void: face_f_water = v; _water_textures["F"] = v; _refresh_face_material("F")

# Cloud methods
func _build_clouds() -> void:
	if is_instance_valid(_cloud_node):
		_cloud_node.queue_free()
	_cloud_node     = null
	_cloud_material = null

func _set_cloud_enabled(v: bool) -> void:
	cloud_enabled = v
	_update_cloud_params()

func _set_invert_clouds(v: bool) -> void:
	invert_clouds = v
	_update_cloud_params()

func _set_cloud_texture(v: Texture2D) -> void:
	cloud_texture = v
	_update_cloud_params()

func _set_cloud_altitude(v: float) -> void:
	cloud_altitude = v
	_update_cloud_params()

func _set_cloud_thickness(v: float) -> void:
	cloud_thickness = v
	_update_cloud_params()

func _set_cloud_density(v: float) -> void:
	cloud_density = v
	_update_cloud_params()

func _set_cloud_coverage(v: float) -> void:
	cloud_coverage = v
	_update_cloud_params()

func _set_cloud_speed(v: float) -> void:
	cloud_speed = v
	_update_cloud_params()

func _set_cloud_shadow_intensity(v: float) -> void:
	cloud_shadow_intensity = v
	_update_cloud_params()

func _set_cloud_day_brightness(v: float) -> void:
	cloud_day_brightness = v
	_update_atmosphere_params()

func _set_cloud_night_brightness(v: float) -> void:
	cloud_night_brightness = v
	_update_atmosphere_params()

func _set_cloud_map_height(v: float) -> void:
	cloud_map_height = v
	_update_atmosphere_params()

func _set_cloud_map_density(v: float) -> void:
	cloud_map_density = v
	_update_atmosphere_params()

func _set_cloud_color(v: Color) -> void:
	cloud_color = v
	_update_atmosphere_params()

func _set_cloud_shadow_color(v: Color) -> void:
	cloud_shadow_color = v
	_update_atmosphere_params()

func _set_noise_base_scale(v: float) -> void:
	noise_base_scale = v
	_update_atmosphere_params()

func _set_noise_base_strength(v: float) -> void:
	noise_base_strength = v
	_update_atmosphere_params()

func _set_noise_detail_scale(v: float) -> void:
	noise_detail_scale = v
	_update_atmosphere_params()

func _set_noise_detail_strength(v: float) -> void:
	noise_detail_strength = v
	_update_atmosphere_params()

# Atmosphere methods
func _build_atmosphere() -> void:
	if is_instance_valid(_atmo_node):
		_atmo_node.queue_free()
	_atmo_node     = null
	_atmo_material = null

	if is_instance_valid(_cloud_node):
		_cloud_node.queue_free()
	_cloud_node = null

	if not atmosphere_enabled and not cloud_enabled:
		return

	var shell_r := radius * atmosphere_scale

	var sphere             := SphereMesh.new()
	sphere.radius          = shell_r
	sphere.height          = shell_r * 2.0
	sphere.radial_segments = 64
	sphere.rings           = 32

	_atmo_node             = MeshInstance3D.new()
	_atmo_node.name        = "AtmosphereShell"
	_atmo_node.mesh        = sphere
	_atmo_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_atmo_node)

	_atmo_material        = ShaderMaterial.new()
	_atmo_material.shader = load("res://shaders/atmosphere.gdshader") as Shader
	_atmo_material.render_priority = 10
	_atmo_node.material_override = _atmo_material
	_atmo_node.extra_cull_margin = shell_r

	_update_atmosphere_params()

func _update_atmosphere_params() -> void:
	if not _atmo_material:
		return
	if is_inside_tree():
		_atmo_material.set_shader_parameter("planet_center",  global_position)
		if sun_light and sun_light.is_inside_tree():
			_atmo_material.set_shader_parameter(
				"sun_dir", -sun_light.global_transform.basis.z.normalized()
			)
	_atmo_material.set_shader_parameter("planet_radius",  radius)
	_atmo_material.set_shader_parameter("atmo_radius",    radius * atmosphere_scale)

	# Atmospheric scattering parameters
	if atmosphere_enabled:
		_atmo_material.set_shader_parameter("rayleigh_coeff", rayleigh_coeff)
		_atmo_material.set_shader_parameter("scale_height_r", radius * scale_height_rayleigh)
		_atmo_material.set_shader_parameter("mie_coeff",      mie_coeff)
		_atmo_material.set_shader_parameter("mie_g",          mie_g)
		_atmo_material.set_shader_parameter("scale_height_m", radius * scale_height_mie)
	else:
		_atmo_material.set_shader_parameter("rayleigh_coeff", Vector3.ZERO)
		_atmo_material.set_shader_parameter("scale_height_r", radius * scale_height_rayleigh)
		_atmo_material.set_shader_parameter("mie_coeff",      0.0)
		_atmo_material.set_shader_parameter("mie_g",          mie_g)
		_atmo_material.set_shader_parameter("scale_height_m", radius * scale_height_mie)

	_atmo_material.set_shader_parameter("sun_intensity",  sun_intensity)

	# Unified Cloud Parameters
	_atmo_material.set_shader_parameter("cloud_enabled",      cloud_enabled)
	_atmo_material.set_shader_parameter("invert_clouds",      invert_clouds)
	_atmo_material.set_shader_parameter("cloud_altitude",    cloud_altitude)
	_atmo_material.set_shader_parameter("cloud_thickness",   cloud_thickness)
	_atmo_material.set_shader_parameter("cloud_density",     cloud_density)
	_atmo_material.set_shader_parameter("cloud_coverage",    cloud_coverage)
	_atmo_material.set_shader_parameter("cloud_speed",            cloud_speed)
	_atmo_material.set_shader_parameter("cloud_day_brightness",   cloud_day_brightness)
	_atmo_material.set_shader_parameter("cloud_night_brightness", cloud_night_brightness)
	_atmo_material.set_shader_parameter("cloud_map_height",       cloud_map_height)
	_atmo_material.set_shader_parameter("cloud_map_density",      cloud_map_density)
	_atmo_material.set_shader_parameter("cloud_color",            cloud_color)
	_atmo_material.set_shader_parameter("cloud_shadow_color",      cloud_shadow_color)
	_atmo_material.set_shader_parameter("noise_base_scale",       noise_base_scale)
	_atmo_material.set_shader_parameter("noise_base_strength",    noise_base_strength)
	_atmo_material.set_shader_parameter("noise_detail_scale",     noise_detail_scale)
	_atmo_material.set_shader_parameter("noise_detail_strength",  noise_detail_strength)

	if cloud_texture:
		_atmo_material.set_shader_parameter("cloud_texture", cloud_texture)
	elif ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
		cloud_texture = load("res://assets/planets/earth/clouds_4k.png")
		_atmo_material.set_shader_parameter("cloud_texture", cloud_texture)

func _set_atmo_enabled(v: bool) -> void:
	atmosphere_enabled = v
	_build_atmosphere()

func _set_atmo_scale(v: float) -> void:
	atmosphere_scale = v
	if is_instance_valid(_atmo_node) and _atmo_node.mesh:
		var s := _atmo_node.mesh as SphereMesh
		if s:
			s.radius = radius * v
			s.height = radius * v * 2.0
	_update_atmosphere_params()

# Eye Adaptation & Skybox Methods
func _setup_environment_and_adaptation() -> void:
	if not _world_env or not is_instance_valid(_world_env):
		_world_env = get_node_or_null("WorldEnvironment")
		if not _world_env:
			for c in get_children():
				if c is WorldEnvironment:
					_world_env = c
					break
		if not _world_env and get_parent():
			_world_env = get_parent().get_node_or_null("WorldEnvironment")

	if _world_env and _world_env.environment:
		var env := _world_env.environment
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_white = 6.0

		if env.sky and env.sky.sky_material is PanoramaSkyMaterial:
			_sky_material = env.sky.sky_material

		if not _world_env.camera_attributes:
			_camera_attributes = CameraAttributesPractical.new()
			_world_env.camera_attributes = _camera_attributes
		elif _world_env.camera_attributes is CameraAttributesPractical:
			_camera_attributes = _world_env.camera_attributes

		_update_camera_attributes()

func _update_camera_attributes() -> void:
	if _camera_attributes:
		_camera_attributes.auto_exposure_enabled = eye_adaptation_enabled
		_camera_attributes.auto_exposure_speed = eye_adaptation_speed
		_camera_attributes.auto_exposure_scale = auto_exposure_scale
		_camera_attributes.auto_exposure_min_sensitivity = 20.0
		_camera_attributes.auto_exposure_max_sensitivity = 640.0

func _update_eye_adaptation(delta: float, active_cam: Camera3D) -> void:
	if not _world_env or not _sky_material or not is_instance_valid(_sky_material):
		_setup_environment_and_adaptation()
		if not _sky_material:
			return

	if not eye_adaptation_enabled:
		_sky_material.energy_multiplier = skybox_max_energy
		current_skybox_energy = skybox_max_energy
		current_perceived_brightness = 0.0
		if _camera_attributes:
			_camera_attributes.auto_exposure_enabled = false
		return

	if _camera_attributes and not _camera_attributes.auto_exposure_enabled:
		_camera_attributes.auto_exposure_enabled = true

	var cam_pos: Vector3 = active_cam.global_position
	var cam_fwd: Vector3 = -active_cam.global_transform.basis.z.normalized()

	var sun_dir: Vector3 = Vector3.UP
	if sun_light and sun_light.is_inside_tree():
		sun_dir = -sun_light.global_transform.basis.z.normalized()

	# 1. Direct Sun Glare:
	var sun_alignment: float = cam_fwd.dot(sun_dir)
	var sun_glare: float = 0.0
	if sun_alignment > 0.0:
		sun_glare = pow(sun_alignment, 3.0) * clampf(sun_intensity / 2.0, 0.5, 3.0)

	# 2. Planet Daytime Albedo Reflection:
	var to_planet: Vector3 = global_position - cam_pos
	var dist_to_planet: float = to_planet.length()
	var planet_dir: Vector3 = to_planet / maxf(dist_to_planet, 0.001)
	var planet_alignment: float = cam_fwd.dot(planet_dir)

	var sin_ang: float = clampf(radius / maxf(dist_to_planet, radius), 0.0, 1.0)
	var solid_angle: float = sin_ang * sin_ang

	var cam_phase_norm: Vector3 = (cam_pos - global_position).normalized()
	var planet_phase: float = cam_phase_norm.dot(sun_dir)
	var day_fraction: float = clampf((planet_phase + 0.25) / 1.25, 0.0, 1.0)

	var planet_fov_coverage: float = 0.0
	if planet_alignment > 0.1:
		planet_fov_coverage = smoothstep(0.1, 0.85, planet_alignment) * minf(solid_angle * 4.0, 1.0)

	var planet_day_glare: float = day_fraction * planet_fov_coverage

	# 3. Target Perceived Field-of-View Luminance:
	var target_brightness: float = clampf(sun_glare * 0.9 + planet_day_glare * 0.9, 0.0, 1.0)

	# 4. Smooth Temporal Eye Adaptation (simulating pupil dilation / contraction lag):
	var adapt_speed: float = eye_adaptation_speed
	if target_brightness > current_perceived_brightness:
		adapt_speed *= 1.4
	var t: float = 1.0 - exp(-adapt_speed * delta)
	current_perceived_brightness = lerpf(current_perceived_brightness, target_brightness, t)

	# 5. Dynamic Skybox Dimming:
	current_skybox_energy = lerpf(skybox_max_energy, skybox_min_energy, current_perceived_brightness)
	_sky_material.energy_multiplier = current_skybox_energy

# Setters for Eye Adaptation & Skybox
func _set_eye_adaptation_enabled(v: bool) -> void:
	eye_adaptation_enabled = v
	_update_camera_attributes()

func _set_eye_adaptation_speed(v: float) -> void:
	eye_adaptation_speed = v
	_update_camera_attributes()

func _set_skybox_max_energy(v: float) -> void:
	skybox_max_energy = v

func _set_skybox_min_energy(v: float) -> void:
	skybox_min_energy = v

func _set_auto_exposure_scale(v: float) -> void:
	auto_exposure_scale = v
	_update_camera_attributes()
