@tool
extends Node3D

@export_group("Planet Settings")
@export var radius: float = 600.0 : set = _set_radius
@export var height_scale: float = 25.0 : set = _set_hscale
@export var sea_level: float = 0.485 : set = _set_sea_level
@export var resolution: int = 32
@export var max_lod: int = 6 : set = _set_lod
@export var lod_threshold: float = 3.5
@export var planet_spin_enabled: bool = true : set = _set_planet_spin_enabled
@export var planet_spin_speed: float = 0.005 : set = _set_planet_spin_speed

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
@export var wave_amplitude: float = 0.28 : set = _set_wave_amplitude
@export var wave_frequency: float = 1.0 : set = _set_wave_frequency
@export var wave_speed: float = 1.2 : set = _set_wave_speed
@export var wave_steepness: float = 0.65 : set = _set_wave_steepness
@export var shore_foam_distance: float = 0.85 : set = _set_shore_foam_distance
@export var crest_foam_threshold: float = 0.45 : set = _set_crest_foam_threshold
@export var foam_intensity: float = 1.0 : set = _set_foam_intensity
@export var ssr_enabled: bool = true : set = _set_ssr_enabled

@export_group("Clouds")
@export var cloud_enabled: bool = true : set = _set_cloud_enabled
@export var invert_clouds: bool = false : set = _set_invert_clouds
@export var cloud_texture: Texture2D : set = _set_cloud_texture
@export var cloud_altitude: float = 2.0 : set = _set_cloud_altitude
@export var cloud_thickness: float = 3.5 : set = _set_cloud_thickness
@export var cloud_density: float = 0.8 : set = _set_cloud_density
@export var cloud_coverage: float = 0.65 : set = _set_cloud_coverage
@export var cloud_speed: float = 0.001 : set = _set_cloud_speed
@export var cloud_noise_speed: float = 0.0001 : set = _set_cloud_noise_speed
@export var cloud_noise_follow: float = 0.8 : set = _set_cloud_noise_follow
@export var cloud_day_brightness: float = 2.0 : set = _set_cloud_day_brightness
@export var cloud_night_brightness: float = 0.0 : set = _set_cloud_night_brightness
@export var cloud_map_height: float = 0.8 : set = _set_cloud_map_height
@export var cloud_map_density: float = 0.85 : set = _set_cloud_map_density
@export var cloud_color: Color = Color(1.0, 1.0, 1.0, 1.0) : set = _set_cloud_color
@export var cloud_shadow_color: Color = Color(0.18, 0.22, 0.32, 1.0) : set = _set_cloud_shadow_color
@export var cloud_shadow_intensity: float = 0.85 : set = _set_cloud_shadow_intensity
@export var cloud_edge_noise: float = 0.85 : set = _set_cloud_edge_noise
@export var cloud_noise_amount: float = 0.8 : set = _set_cloud_noise_amount
@export var cloud_self_shadow_intensity: float = 1.0 : set = _set_cloud_self_shadow_intensity
@export var cloud_terminator_depth: float = 1.0 : set = _set_cloud_terminator_depth
@export var cloud_terminator_softness: float = 0.16 : set = _set_cloud_terminator_softness
@export var cloud_sunset_tint: float = 0.0 : set = _set_cloud_sunset_tint
@export var cloud_terminator_offset: float = 0.0 : set = _set_cloud_terminator_offset
@export var cloud_opacity: float = 1.5 : set = _set_cloud_opacity
@export var cloud_dither: float = 0.5 : set = _set_cloud_dither
@export var noise_base_scale: float = 160.0 : set = _set_noise_base_scale
@export var noise_base_strength: float = 0.35 : set = _set_noise_base_strength
@export var noise_detail_scale: float = 400.0 : set = _set_noise_detail_scale
@export var noise_detail_strength: float = 0.25 : set = _set_noise_detail_strength

@export_group("Cloud Noise Layers")
@export var noise_l1_enabled: bool = true : set = _set_noise_l1_enabled
@export var noise_l1_scale: float = 160.0 : set = _set_noise_l1_scale
@export var noise_l1_strength: float = 0.35 : set = _set_noise_l1_strength
@export var noise_l1_edge_only: float = 0.0 : set = _set_noise_l1_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l1_channel: int = 0 : set = _set_noise_l1_channel

@export var noise_l2_enabled: bool = true : set = _set_noise_l2_enabled
@export var noise_l2_scale: float = 400.0 : set = _set_noise_l2_scale
@export var noise_l2_strength: float = 0.25 : set = _set_noise_l2_strength
@export var noise_l2_edge_only: float = 0.65 : set = _set_noise_l2_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l2_channel: int = 1 : set = _set_noise_l2_channel

@export var noise_l3_enabled: bool = false : set = _set_noise_l3_enabled
@export var noise_l3_scale: float = 800.0 : set = _set_noise_l3_scale
@export var noise_l3_strength: float = 0.20 : set = _set_noise_l3_strength
@export var noise_l3_edge_only: float = 0.85 : set = _set_noise_l3_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l3_channel: int = 2 : set = _set_noise_l3_channel

@export var noise_l4_enabled: bool = false : set = _set_noise_l4_enabled
@export var noise_l4_scale: float = 1600.0 : set = _set_noise_l4_scale
@export var noise_l4_strength: float = 0.15 : set = _set_noise_l4_strength
@export var noise_l4_edge_only: float = 1.0 : set = _set_noise_l4_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l4_channel: int = 3 : set = _set_noise_l4_channel

@export var noise_l5_enabled: bool = false : set = _set_noise_l5_enabled
@export var noise_l5_scale: float = 2400.0 : set = _set_noise_l5_scale
@export var noise_l5_strength: float = 0.15 : set = _set_noise_l5_strength
@export var noise_l5_edge_only: float = 0.8 : set = _set_noise_l5_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l5_channel: int = 1 : set = _set_noise_l5_channel

@export var noise_l6_enabled: bool = false : set = _set_noise_l6_enabled
@export var noise_l6_scale: float = 3200.0 : set = _set_noise_l6_scale
@export var noise_l6_strength: float = 0.12 : set = _set_noise_l6_strength
@export var noise_l6_edge_only: float = 1.0 : set = _set_noise_l6_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l6_channel: int = 2 : set = _set_noise_l6_channel

@export var noise_l7_enabled: bool = false : set = _set_noise_l7_enabled
@export var noise_l7_scale: float = 4800.0 : set = _set_noise_l7_scale
@export var noise_l7_strength: float = 0.10 : set = _set_noise_l7_strength
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l7_channel: int = 0 : set = _set_noise_l7_channel
@export var noise_l7_edge_only: float = 0.5 : set = _set_noise_l7_edge_only

@export var noise_l8_enabled: bool = false : set = _set_noise_l8_enabled
@export var noise_l8_scale: float = 6400.0 : set = _set_noise_l8_scale
@export var noise_l8_strength: float = 0.08 : set = _set_noise_l8_strength
@export var noise_l8_edge_only: float = 1.0 : set = _set_noise_l8_edge_only
@export_enum("R:0", "G:1", "B:2", "A:3") var noise_l8_channel: int = 3 : set = _set_noise_l8_channel


@export var cloud_samples: int = 16 : set = _set_cloud_samples
@export var render_scale: float = 1.0 : set = _set_render_scale

@export_group("Terrain & Normals")
@export var normal_depth: float = 1.0 : set = _set_normal_depth
@export var invert_normal_y: bool = false : set = _set_invert_normal_y
@export var normal_orbital_ratio: float = 0.22 : set = _set_normal_orbital_ratio
@export var normal_slope_threshold: float = 0.08 : set = _set_normal_slope_threshold

@export_group("Atmosphere")
@export var atmosphere_enabled: bool = true : set = _set_atmo_enabled
@export var atmosphere_scale: float = 1.06 : set = _set_atmo_scale
@export var rayleigh_coeff: Vector3 = Vector3(0.0035, 0.0085, 0.021) : set = _set_rayleigh_coeff
@export var scale_height_rayleigh: float = 0.015 : set = _set_scale_height_rayleigh
@export var mie_coeff: float = 0.002 : set = _set_mie_coeff
@export var mie_g: float = 0.76 : set = _set_mie_g
@export var scale_height_mie: float = 0.008 : set = _set_scale_height_mie
@export var godray_intensity: float = 1.0 : set = _set_godray_intensity

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
var _ocean_node: MeshInstance3D
var _cloud_node: MeshInstance3D
var _cloud_material: ShaderMaterial
var _atmo_node: MeshInstance3D
var _atmo_material: ShaderMaterial
var _shared_shader: Shader
var _noise_texture_3d: ImageTexture3D = null
var _transmittance_lut: Texture2D = null
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
uniform vec3 camera_pos = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_radius = 600.0;
uniform float cloud_altitude = 2.0;
uniform float cloud_thickness = 3.5;
uniform float cloud_density = 0.8;
uniform float cloud_coverage = 0.65;
uniform float cloud_speed = 0.001;
uniform float planet_rotation = 0.0;
uniform float cloud_noise_speed = 0.0001;
uniform float cloud_noise_follow = 0.8;
uniform float cloud_map_density = 0.85;
uniform float cloud_shadow_intensity = 0.85;
uniform vec4 cloud_shadow_color : source_color = vec4(0.18, 0.22, 0.32, 1.0);
uniform float cloud_edge_noise = 0.85;
uniform float noise_base_scale = 160.0;
uniform float noise_base_strength = 0.35;
uniform float noise_detail_scale = 400.0;
uniform float noise_detail_strength = 0.2;
uniform bool noise_l1_enabled = true;
uniform float noise_l1_scale = 160.0;
uniform float noise_l1_strength = 0.35;
uniform float noise_l1_edge_only = 0.0;
uniform int noise_l1_channel = 0;
uniform bool noise_l2_enabled = true;
uniform float noise_l2_scale = 400.0;
uniform float noise_l2_strength = 0.2;
uniform float noise_l2_edge_only = 0.0;
uniform int noise_l2_channel = 1;
uniform bool noise_l3_enabled = false;
uniform float noise_l3_scale = 800.0;
uniform float noise_l3_strength = 0.20;
uniform float noise_l3_edge_only = 0.85;
uniform int noise_l3_channel = 2;
uniform bool noise_l4_enabled = false;
uniform float noise_l4_scale = 1600.0;
uniform float noise_l4_strength = 0.15;
uniform float noise_l4_edge_only = 1.0;
uniform int noise_l4_channel = 3;
uniform bool noise_l5_enabled = false;
uniform float noise_l5_scale = 2400.0;
uniform float noise_l5_strength = 0.15;
uniform float noise_l5_edge_only = 0.8;
uniform int noise_l5_channel = 1;
uniform bool noise_l6_enabled = false;
uniform float noise_l6_scale = 3200.0;
uniform float noise_l6_strength = 0.12;
uniform float noise_l6_edge_only = 1.0;
uniform int noise_l6_channel = 2;
uniform bool noise_l7_enabled = false;
uniform float noise_l7_scale = 4800.0;
uniform float noise_l7_strength = 0.10;
uniform float noise_l7_edge_only = 0.5;
uniform int noise_l7_channel = 0;
uniform bool noise_l8_enabled = false;
uniform float noise_l8_scale = 6400.0;
uniform float noise_l8_strength = 0.08;
uniform float noise_l8_edge_only = 1.0;
uniform int noise_l8_channel = 3;
uniform sampler3D noise_texture_3d : repeat_enable, filter_linear;

float sample_noise_ch_terrain(vec4 s, int ch) {
    float v = s.r;
    if (ch == 1) v = s.g;
    else if (ch == 2) v = s.b;
    else if (ch == 3) v = s.a;
    return smoothstep(0.0, 1.0, clamp((v - 0.24) / 0.52, 0.0, 1.0));
}

float sample_cloud_raw_terrain(vec2 uv, float lod) {
    vec4 c_tex = textureLod(cloud_texture, vec2(fract(uv.x), clamp(uv.y, 0.001, 0.999)), lod);
    return (c_tex.a < 0.999) ? c_tex.a : c_tex.r;
}

uniform float normal_depth = 1.0;
uniform bool invert_normal_y = false;
uniform float normal_fade_start = 8.0;
uniform float normal_fade_end = 200.0;
uniform float normal_orbital_ratio = 0.22;
uniform float normal_slope_threshold = 0.08;

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

    if (cloud_enabled && cloud_density > 0.005) {
        vec3 sun_norm = -normalize(sun_dir);
        float sun_dot = dot(v_world_normal, sun_norm);
        if (sun_dot > -0.12) {
            float r_cloud = planet_radius + cloud_altitude + cloud_thickness * 0.45;
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
                    float lon_c = atan(n_cloud.x, n_cloud.z) - planet_rotation;
                    float u_c = fract(lon_c / (2.0 * 3.141592653589793) + 0.5 + TIME * cloud_speed);

                    // 9-tap soft penumbra blur across cloud_texture at mip 2.4 to remove 4K texel pixelation
                    vec2 uv_c = vec2(u_c, v_c);
                    vec2 pen = vec2(0.0014, 0.0028);
                    float c_raw = sample_cloud_raw_terrain(uv_c, 2.4) * 0.24;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2( pen.x, 0.0), 2.4) * 0.12;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2(-pen.x, 0.0), 2.4) * 0.12;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2(0.0,  pen.y), 2.4) * 0.12;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2(0.0, -pen.y), 2.4) * 0.12;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2( pen.x,  pen.y) * 0.707, 2.4) * 0.07;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2(-pen.x,  pen.y) * 0.707, 2.4) * 0.07;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2( pen.x, -pen.y) * 0.707, 2.4) * 0.07;
                    c_raw += sample_cloud_raw_terrain(uv_c + vec2(-pen.x, -pen.y) * 0.707, 2.4) * 0.07;
                    float cov = invert_clouds ? (1.0 - c_raw) : c_raw;

                    if (cov > 0.01) {
                        float rot_noise_angle = -planet_rotation + TIME * (cloud_speed * cloud_noise_follow + cloud_noise_speed) * 6.28318530718;
                        float cos_nr = cos(rot_noise_angle);
                        float sin_nr = sin(rot_noise_angle);
                        vec3 v_c_local = p_cloud - planet_center;
                        vec3 v_c_rot = vec3(v_c_local.x * cos_nr + v_c_local.z * sin_nr, v_c_local.y, -v_c_local.x * sin_nr + v_c_local.z * cos_nr);
                        const float NOISE_DOMAIN = 18000.0;

                        float edge_ramp_width = mix(0.22, 0.58, clamp(cloud_edge_noise * 0.5, 0.0, 1.0));
                        float edge_feather = smoothstep(0.005, edge_ramp_width, cov);
                        float eff_cov = clamp(cloud_coverage * mix(1.0, cov, cloud_map_density) * edge_feather, 0.0, 1.0);
                        float base_cloud = eff_cov;
                        float edge_factor = 1.0 - smoothstep(0.02, 0.65, cov);

                        // Softened 3-tap spatial average on macro noise L1 & L2 only (high-freq L3-L8 diffuse out over altitude drop)
                        if (noise_l1_enabled && noise_l1_strength > 0.001) {
                            float s1 = min(noise_l1_scale, 700.0) / NOISE_DOMAIN;
                            vec3 uvw1 = v_c_rot * s1;
                            float n_a = sample_noise_ch_terrain(textureLod(noise_texture_3d, uvw1, 0.0), noise_l1_channel);
                            float n_b = sample_noise_ch_terrain(textureLod(noise_texture_3d, uvw1 + vec3(0.018, 0.0, 0.018), 0.0), noise_l1_channel);
                            float n_c = sample_noise_ch_terrain(textureLod(noise_texture_3d, uvw1 - vec3(0.018, 0.0, 0.018), 0.0), noise_l1_channel);
                            float macro1 = (n_a * 0.5 + n_b * 0.25 + n_c * 0.25);
                            float l1_inf = mix(1.0, edge_factor, clamp(noise_l1_edge_only, 0.0, 1.0));
                            float erode1 = (1.0 - macro1) * clamp(noise_l1_strength, 0.0, 1.0) * l1_inf * 0.50;
                            base_cloud = clamp((base_cloud - erode1) / max(0.05, 1.0 - erode1), 0.0, 1.0);
                        }
                        if (noise_l2_enabled && noise_l2_strength > 0.001 && base_cloud > 0.001) {
                            float s2 = min(noise_l2_scale, 900.0) / NOISE_DOMAIN;
                            vec3 uvw2 = v_c_rot * s2;
                            float n2_a = sample_noise_ch_terrain(textureLod(noise_texture_3d, uvw2, 0.0), noise_l2_channel);
                            float n2_b = sample_noise_ch_terrain(textureLod(noise_texture_3d, uvw2 + vec3(0.022, 0.0, -0.022), 0.0), noise_l2_channel);
                            float meso2 = 0.5 * (n2_a + n2_b);
                            float l2_inf = mix(1.0, edge_factor, clamp(noise_l2_edge_only, 0.0, 1.0));
                            float erode2 = (1.0 - meso2) * clamp(noise_l2_strength, 0.0, 1.0) * l2_inf * 0.30;
                            base_cloud = clamp((base_cloud - erode2) / max(0.05, 1.0 - erode2), 0.0, 1.0);
                        }

                        // Wide, soft penumbra ramp
                        float soft_shadow = smoothstep(0.0, 0.72, base_cloud);
                        float dens_boost = clamp(cloud_density * 3.2, 0.25, 1.0);
                        float sun_facing = clamp(sun_dot * 4.0 + 0.48, 0.0, 1.0);
                        float shadow_factor = soft_shadow * dens_boost * sun_facing;
                        vec3 shadow_tint = cloud_shadow_color.rgb * 0.65;
                        tex_color *= mix(vec3(1.0), shadow_tint, clamp(shadow_factor * cloud_shadow_intensity, 0.0, 0.92));
                    }
                }
            }
        }
    }

    ALBEDO = tex_color;

    vec3 cam_pos = (length(camera_pos) > 0.001) ? camera_pos : CAMERA_POSITION_WORLD;
    float cam_alt = max(0.0, length(cam_pos - planet_center) - planet_radius);
    float alt_factor = clamp((cam_alt - normal_fade_start) / max(1.0, normal_fade_end - normal_fade_start), 0.0, 1.0);
    float current_normal_depth = normal_depth * mix(1.0, normal_orbital_ratio, alt_factor);

    vec3 n_map = map_normal;
    if (invert_normal_y) {
        n_map.g = 1.0 - n_map.g;
    }

    if (normal_slope_threshold > 0.001) {
        vec2 n_xy = (n_map.rg - vec2(0.5)) * 2.0;
        float micro_slope = length(n_xy);

        vec3 radial_up = normalize(v_world_pos - planet_center);
        vec3 geom_norm = normalize(cross(dFdx(v_world_pos), dFdy(v_world_pos)));
        if (dot(geom_norm, radial_up) < 0.0) {
            geom_norm = -geom_norm;
        }
        float geom_slope = 1.0 - clamp(dot(geom_norm, radial_up), 0.0, 1.0);

        float effective_slope = max(micro_slope, geom_slope * 2.5);
        float slope_factor = smoothstep(normal_slope_threshold * 0.3, normal_slope_threshold * 1.2, effective_slope);
        current_normal_depth *= slope_factor;
    }

    NORMAL_MAP = n_map;
    NORMAL_MAP_DEPTH = current_normal_depth;

    ROUGHNESS = 0.85;
    SPECULAR = 0.04;
    METALLIC = 0.0;
}
"""

func _ready() -> void:
	load_cloud_settings_from_config()
	if get_viewport():
		get_viewport().scaling_3d_scale = render_scale
	_get_or_create_3d_noise_texture()
	_get_transmittance_lut()
	_build_planet()
	_setup_environment_and_adaptation()

func _get_active_camera() -> Camera3D:
	if Engine.is_editor_hint():
		if ClassDB.class_exists("EditorInterface"):
			var ei = Engine.get_singleton("EditorInterface")
			if not ei and ClassDB.class_exists("EditorInterface"):
				ei = EditorInterface
			if ei and ei.has_method("get_editor_viewport_3d"):
				var evp = ei.get_editor_viewport_3d(0)
				if evp:
					var ecam = evp.get_camera_3d()
					if ecam:
						return ecam
		var vp := get_viewport()
		if vp:
			var cam := vp.get_camera_3d()
			if cam:
				return cam
		return null
	if not camera and get_viewport():
		camera = get_viewport().get_camera_3d()
	return camera

func _process(delta: float) -> void:
	if not is_inside_tree():
		return

	if not Engine.is_editor_hint() and planet_spin_enabled and absf(planet_spin_speed) > 0.000001:
		rotate_y(planet_spin_speed * delta)

	if sun_light and sun_light.is_inside_tree():
		var dir_to_planet := global_position - sun_light.global_position
		if dir_to_planet.length_squared() > 0.01:
			sun_light.look_at(global_position)

	var active_cam := _get_active_camera()
	var cam_pos_world := Vector3.ZERO
	if active_cam:
		if not Engine.is_editor_hint() and active_cam.has_method("sync_with_planet"):
			active_cam.sync_with_planet()
		cam_pos_world = active_cam.global_position
		_update_lod(cam_pos_world)
		_update_eye_adaptation(delta, active_cam)

	var cur_rot_y := rotation.y
	var s_dir := -sun_light.global_transform.basis.z.normalized() if (sun_light and sun_light.is_inside_tree()) else Vector3.UP

	if _atmo_material:
		_atmo_material.set_shader_parameter("planet_center", global_position)
		_atmo_material.set_shader_parameter("planet_rotation", cur_rot_y)
		_atmo_material.set_shader_parameter("sun_dir", s_dir)
		_atmo_material.set_shader_parameter("camera_pos", cam_pos_world)

	if _ocean_material:
		_ocean_material.set_shader_parameter("planet_center", global_position)
		_ocean_material.set_shader_parameter("planet_rotation", cur_rot_y)
		_ocean_material.set_shader_parameter("sun_dir", s_dir)
		_ocean_material.set_shader_parameter("camera_pos", cam_pos_world)

	for fid in face_nodes.keys():
		var mi: MeshInstance3D = face_nodes[fid]
		if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat := mi.mesh.surface_get_material(0) as ShaderMaterial
			if mat:
				mat.set_shader_parameter("planet_center", global_position)
				mat.set_shader_parameter("planet_rotation", cur_rot_y)
				mat.set_shader_parameter("sun_dir", s_dir)
				mat.set_shader_parameter("camera_pos", cam_pos_world)

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

		var q := QuadData.new(cfg.n, cfg.a, cfg.b, 0, Vector2.ZERO, 1.0, cfg.id)
		root_quads.append(q)
		_request_face_update(cfg.id, q)

	_build_ocean()
	_update_shader_params()
	_build_atmosphere()

func _build_ocean() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_ocean_node):
		_ocean_node.queue_free()

	var sphere := SphereMesh.new()
	var o_r := radius + ocean_altitude
	sphere.radius = o_r
	sphere.height = o_r * 2.0
	sphere.radial_segments = 256
	sphere.rings = 128

	_ocean_node = MeshInstance3D.new()
	_ocean_node.name = "OceanShell"
	_ocean_node.mesh = sphere
	_ocean_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ocean_node.material_override = _ocean_material
	_ocean_node.visible = ocean_enabled
	add_child(_ocean_node)
	_update_ocean_params()

func _update_lod(cam_pos: Vector3) -> void:
	if not is_inside_tree():
		return
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
				var b_vec := q.axis_b.normalized()

				if is_rotated:
					p = p.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
					t = t.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)
					b_vec = b_vec.rotated(Vector3(0, 0, 1), -PI).rotated(Vector3(0, 1, 0), PI)

				t = (t - p * t.dot(p)).normalized()
				b_vec = (b_vec - p * b_vec.dot(p)).normalized()

				var tw: float = -1.0 if (p.cross(t)).dot(b_vec) < 0.0 else 1.0

				verts.append(p * snap_radius)
				uvs.append(uv)
				uv2s.append(Vector2(0.0, 0.0))
				norms.append(p)
				tans.append(t.x); tans.append(t.y); tans.append(t.z); tans.append(tw)

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

	if is_instance_valid(self) and is_inside_tree():
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

	_pending_updates.erase(fid)

func _create_face_material(fid: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shared_shader
	mat.set_shader_parameter("sea_level", sea_level)
	mat.set_shader_parameter("h_scale", height_scale)
	mat.set_shader_parameter("ocean_bed_sink", ocean_bed_sink)

	mat.set_shader_parameter("cloud_enabled", cloud_enabled)
	mat.set_shader_parameter("invert_clouds", invert_clouds)
	if is_inside_tree():
		mat.set_shader_parameter("planet_center", global_position)
	mat.set_shader_parameter("planet_radius", radius)
	mat.set_shader_parameter("cloud_altitude", cloud_altitude)
	mat.set_shader_parameter("cloud_thickness", cloud_thickness)
	mat.set_shader_parameter("cloud_density", cloud_density)
	mat.set_shader_parameter("cloud_coverage", cloud_coverage)
	mat.set_shader_parameter("cloud_speed", cloud_speed)
	mat.set_shader_parameter("planet_rotation", rotation.y)
	mat.set_shader_parameter("cloud_noise_speed", cloud_noise_speed)
	mat.set_shader_parameter("cloud_noise_follow", cloud_noise_follow)
	mat.set_shader_parameter("cloud_map_density", cloud_map_density)
	mat.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
	mat.set_shader_parameter("cloud_shadow_color", cloud_shadow_color)
	mat.set_shader_parameter("cloud_edge_noise", cloud_edge_noise)
	mat.set_shader_parameter("noise_base_scale", noise_base_scale)
	mat.set_shader_parameter("noise_base_strength", noise_base_strength)
	mat.set_shader_parameter("noise_detail_scale", noise_detail_scale)
	mat.set_shader_parameter("noise_detail_strength", noise_detail_strength)
	mat.set_shader_parameter("noise_l1_enabled", noise_l1_enabled)
	mat.set_shader_parameter("noise_l1_scale", noise_l1_scale)
	mat.set_shader_parameter("noise_l1_strength", noise_l1_strength)
	mat.set_shader_parameter("noise_l1_edge_only", noise_l1_edge_only)
	mat.set_shader_parameter("noise_l1_channel", noise_l1_channel)
	mat.set_shader_parameter("noise_l2_enabled", noise_l2_enabled)
	mat.set_shader_parameter("noise_l2_scale", noise_l2_scale)
	mat.set_shader_parameter("noise_l2_strength", noise_l2_strength)
	mat.set_shader_parameter("noise_l2_edge_only", noise_l2_edge_only)
	mat.set_shader_parameter("noise_l2_channel", noise_l2_channel)
	mat.set_shader_parameter("normal_depth", normal_depth)
	mat.set_shader_parameter("invert_normal_y", invert_normal_y)
	mat.set_shader_parameter("normal_orbital_ratio", normal_orbital_ratio)
	mat.set_shader_parameter("normal_slope_threshold", normal_slope_threshold)
	var n3d := _get_or_create_3d_noise_texture()
	if n3d:
		mat.set_shader_parameter("noise_texture_3d", n3d)
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

	if not cloud_texture:
		if ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
			cloud_texture = load("res://assets/planets/earth/clouds_4k.png")

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
	_ocean_material.set_shader_parameter("wave_amplitude", wave_amplitude)
	_ocean_material.set_shader_parameter("wave_frequency", wave_frequency)
	_ocean_material.set_shader_parameter("wave_speed", wave_speed)
	_ocean_material.set_shader_parameter("wave_steepness", wave_steepness)
	_ocean_material.set_shader_parameter("shore_foam_distance", shore_foam_distance)
	_ocean_material.set_shader_parameter("crest_foam_threshold", crest_foam_threshold)
	_ocean_material.set_shader_parameter("foam_intensity", foam_intensity)
	_ocean_material.set_shader_parameter("ssr_enabled", ssr_enabled)
	if is_inside_tree():
		_ocean_material.set_shader_parameter("planet_center", global_position)
		if sun_light and sun_light.is_inside_tree():
			_ocean_material.set_shader_parameter("sun_dir", -sun_light.global_transform.basis.z.normalized())
		else:
			_ocean_material.set_shader_parameter("sun_dir", Vector3.UP)
	_ocean_material.set_shader_parameter("planet_radius", radius)
	if ocean_water_mask:
		_ocean_material.set_shader_parameter("water_mask", ocean_water_mask)
	elif ResourceLoader.exists("res://assets/earth_landocean_16K.png"):
		ocean_water_mask = load("res://assets/earth_landocean_16K.png")
		_ocean_material.set_shader_parameter("water_mask", ocean_water_mask)

	_ocean_material.set_shader_parameter("cloud_enabled", cloud_enabled)
	_ocean_material.set_shader_parameter("invert_clouds", invert_clouds)
	_ocean_material.set_shader_parameter("cloud_altitude", cloud_altitude)
	_ocean_material.set_shader_parameter("cloud_thickness", cloud_thickness)
	_ocean_material.set_shader_parameter("cloud_density", cloud_density)
	_ocean_material.set_shader_parameter("cloud_coverage", cloud_coverage)
	_ocean_material.set_shader_parameter("cloud_speed", cloud_speed)
	_ocean_material.set_shader_parameter("planet_rotation", rotation.y)
	_ocean_material.set_shader_parameter("cloud_noise_speed", cloud_noise_speed)
	_ocean_material.set_shader_parameter("cloud_noise_follow", cloud_noise_follow)
	_ocean_material.set_shader_parameter("cloud_map_density", cloud_map_density)
	_ocean_material.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
	_ocean_material.set_shader_parameter("cloud_shadow_color", cloud_shadow_color)
	_ocean_material.set_shader_parameter("cloud_edge_noise", cloud_edge_noise)
	_ocean_material.set_shader_parameter("noise_base_scale", noise_base_scale)
	_ocean_material.set_shader_parameter("noise_base_strength", noise_base_strength)
	_ocean_material.set_shader_parameter("noise_detail_scale", noise_detail_scale)
	_ocean_material.set_shader_parameter("noise_detail_strength", noise_detail_strength)

	_ocean_material.set_shader_parameter("noise_l1_enabled", noise_l1_enabled)
	_ocean_material.set_shader_parameter("noise_l1_scale", noise_l1_scale)
	_ocean_material.set_shader_parameter("noise_l1_strength", noise_l1_strength)
	_ocean_material.set_shader_parameter("noise_l1_edge_only", noise_l1_edge_only)
	_ocean_material.set_shader_parameter("noise_l1_channel", noise_l1_channel)

	_ocean_material.set_shader_parameter("noise_l2_enabled", noise_l2_enabled)
	_ocean_material.set_shader_parameter("noise_l2_scale", noise_l2_scale)
	_ocean_material.set_shader_parameter("noise_l2_strength", noise_l2_strength)
	_ocean_material.set_shader_parameter("noise_l2_edge_only", noise_l2_edge_only)
	_ocean_material.set_shader_parameter("noise_l2_channel", noise_l2_channel)

	_ocean_material.set_shader_parameter("noise_l3_enabled", noise_l3_enabled)
	_ocean_material.set_shader_parameter("noise_l3_scale", noise_l3_scale)
	_ocean_material.set_shader_parameter("noise_l3_strength", noise_l3_strength)
	_ocean_material.set_shader_parameter("noise_l3_edge_only", noise_l3_edge_only)
	_ocean_material.set_shader_parameter("noise_l3_channel", noise_l3_channel)

	_ocean_material.set_shader_parameter("noise_l4_enabled", noise_l4_enabled)
	_ocean_material.set_shader_parameter("noise_l4_scale", noise_l4_scale)
	_ocean_material.set_shader_parameter("noise_l4_strength", noise_l4_strength)
	_ocean_material.set_shader_parameter("noise_l4_edge_only", noise_l4_edge_only)
	_ocean_material.set_shader_parameter("noise_l4_channel", noise_l4_channel)

	_ocean_material.set_shader_parameter("noise_l5_enabled", noise_l5_enabled)
	_ocean_material.set_shader_parameter("noise_l5_scale", noise_l5_scale)
	_ocean_material.set_shader_parameter("noise_l5_strength", noise_l5_strength)
	_ocean_material.set_shader_parameter("noise_l5_edge_only", noise_l5_edge_only)
	_ocean_material.set_shader_parameter("noise_l5_channel", noise_l5_channel)

	_ocean_material.set_shader_parameter("noise_l6_enabled", noise_l6_enabled)
	_ocean_material.set_shader_parameter("noise_l6_scale", noise_l6_scale)
	_ocean_material.set_shader_parameter("noise_l6_strength", noise_l6_strength)
	_ocean_material.set_shader_parameter("noise_l6_edge_only", noise_l6_edge_only)
	_ocean_material.set_shader_parameter("noise_l6_channel", noise_l6_channel)

	_ocean_material.set_shader_parameter("noise_l7_enabled", noise_l7_enabled)
	_ocean_material.set_shader_parameter("noise_l7_scale", noise_l7_scale)
	_ocean_material.set_shader_parameter("noise_l7_strength", noise_l7_strength)
	_ocean_material.set_shader_parameter("noise_l7_edge_only", noise_l7_edge_only)
	_ocean_material.set_shader_parameter("noise_l7_channel", noise_l7_channel)

	_ocean_material.set_shader_parameter("noise_l8_enabled", noise_l8_enabled)
	_ocean_material.set_shader_parameter("noise_l8_scale", noise_l8_scale)
	_ocean_material.set_shader_parameter("noise_l8_strength", noise_l8_strength)
	_ocean_material.set_shader_parameter("noise_l8_edge_only", noise_l8_edge_only)
	_ocean_material.set_shader_parameter("noise_l8_channel", noise_l8_channel)


	var n3d := _get_or_create_3d_noise_texture()
	if n3d:
		_ocean_material.set_shader_parameter("noise_texture_3d", n3d)
	if cloud_texture:
		_ocean_material.set_shader_parameter("cloud_texture", cloud_texture)
	elif ResourceLoader.exists("res://assets/planets/earth/clouds_4k.png"):
		cloud_texture = load("res://assets/planets/earth/clouds_4k.png")
		_ocean_material.set_shader_parameter("cloud_texture", cloud_texture)

func _set_ocean_enabled(v: bool) -> void:
	ocean_enabled = v
	if is_instance_valid(_ocean_node):
		_ocean_node.visible = v
	for o_mi: MeshInstance3D in ocean_face_nodes.values():
		o_mi.visible = v

func _set_ocean_water_mask(v: Texture2D) -> void:
	ocean_water_mask = v
	_update_ocean_params()

func _set_ocean_altitude(v: float) -> void:
	ocean_altitude = v
	if is_instance_valid(_ocean_node) and _ocean_node.mesh:
		var s := _ocean_node.mesh as SphereMesh
		if s:
			var o_r := radius + v
			s.radius = o_r
			s.height = o_r * 2.0
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

func _set_wave_amplitude(v: float) -> void:
	wave_amplitude = v
	_update_ocean_params()

func _set_wave_frequency(v: float) -> void:
	wave_frequency = v
	_update_ocean_params()

func _set_wave_speed(v: float) -> void:
	wave_speed = v
	_update_ocean_params()

func _set_wave_steepness(v: float) -> void:
	wave_steepness = v
	_update_ocean_params()

func _set_shore_foam_distance(v: float) -> void:
	shore_foam_distance = v
	_update_ocean_params()

func _set_crest_foam_threshold(v: float) -> void:
	crest_foam_threshold = v
	_update_ocean_params()

func _set_foam_intensity(v: float) -> void:
	foam_intensity = v
	_update_ocean_params()

func _set_ssr_enabled(v: bool) -> void:
	ssr_enabled = v
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

func _set_planet_spin_enabled(v: bool) -> void:
	planet_spin_enabled = v

func _set_planet_spin_speed(v: float) -> void:
	planet_spin_speed = v

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
				if is_inside_tree():
					mat.set_shader_parameter("planet_center", global_position)
				mat.set_shader_parameter("sun_dir", s_dir)
				mat.set_shader_parameter("planet_radius", radius)
				mat.set_shader_parameter("cloud_altitude", cloud_altitude)
				mat.set_shader_parameter("cloud_thickness", cloud_thickness)
				mat.set_shader_parameter("cloud_density", cloud_density)
				mat.set_shader_parameter("cloud_coverage", cloud_coverage)
				mat.set_shader_parameter("cloud_speed", cloud_speed)
				mat.set_shader_parameter("planet_rotation", rotation.y)
				mat.set_shader_parameter("cloud_noise_speed", cloud_noise_speed)
				mat.set_shader_parameter("cloud_noise_follow", cloud_noise_follow)
				mat.set_shader_parameter("cloud_map_density", cloud_map_density)
				mat.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
				mat.set_shader_parameter("cloud_shadow_color", cloud_shadow_color)
				mat.set_shader_parameter("cloud_edge_noise", cloud_edge_noise)
				mat.set_shader_parameter("noise_base_scale", noise_base_scale)
				mat.set_shader_parameter("noise_base_strength", noise_base_strength)
				mat.set_shader_parameter("noise_detail_scale", noise_detail_scale)
				mat.set_shader_parameter("noise_detail_strength", noise_detail_strength)
				mat.set_shader_parameter("noise_l1_enabled", noise_l1_enabled)
				mat.set_shader_parameter("noise_l1_scale", noise_l1_scale)
				mat.set_shader_parameter("noise_l1_strength", noise_l1_strength)
				mat.set_shader_parameter("noise_l1_edge_only", noise_l1_edge_only)
				mat.set_shader_parameter("noise_l1_channel", noise_l1_channel)
				mat.set_shader_parameter("noise_l2_enabled", noise_l2_enabled)
				mat.set_shader_parameter("noise_l2_scale", noise_l2_scale)
				mat.set_shader_parameter("noise_l2_strength", noise_l2_strength)
				mat.set_shader_parameter("noise_l2_edge_only", noise_l2_edge_only)
				mat.set_shader_parameter("noise_l2_channel", noise_l2_channel)
				mat.set_shader_parameter("noise_l3_enabled", noise_l3_enabled)
				mat.set_shader_parameter("noise_l3_scale", noise_l3_scale)
				mat.set_shader_parameter("noise_l3_strength", noise_l3_strength)
				mat.set_shader_parameter("noise_l3_edge_only", noise_l3_edge_only)
				mat.set_shader_parameter("noise_l3_channel", noise_l3_channel)
				mat.set_shader_parameter("noise_l4_enabled", noise_l4_enabled)
				mat.set_shader_parameter("noise_l4_scale", noise_l4_scale)
				mat.set_shader_parameter("noise_l4_strength", noise_l4_strength)
				mat.set_shader_parameter("noise_l4_edge_only", noise_l4_edge_only)
				mat.set_shader_parameter("noise_l4_channel", noise_l4_channel)
				mat.set_shader_parameter("noise_l5_enabled", noise_l5_enabled)
				mat.set_shader_parameter("noise_l5_scale", noise_l5_scale)
				mat.set_shader_parameter("noise_l5_strength", noise_l5_strength)
				mat.set_shader_parameter("noise_l5_edge_only", noise_l5_edge_only)
				mat.set_shader_parameter("noise_l5_channel", noise_l5_channel)
				mat.set_shader_parameter("noise_l6_enabled", noise_l6_enabled)
				mat.set_shader_parameter("noise_l6_scale", noise_l6_scale)
				mat.set_shader_parameter("noise_l6_strength", noise_l6_strength)
				mat.set_shader_parameter("noise_l6_edge_only", noise_l6_edge_only)
				mat.set_shader_parameter("noise_l6_channel", noise_l6_channel)
				mat.set_shader_parameter("noise_l7_enabled", noise_l7_enabled)
				mat.set_shader_parameter("noise_l7_scale", noise_l7_scale)
				mat.set_shader_parameter("noise_l7_strength", noise_l7_strength)
				mat.set_shader_parameter("noise_l7_edge_only", noise_l7_edge_only)
				mat.set_shader_parameter("noise_l7_channel", noise_l7_channel)
				mat.set_shader_parameter("noise_l8_enabled", noise_l8_enabled)
				mat.set_shader_parameter("noise_l8_scale", noise_l8_scale)
				mat.set_shader_parameter("noise_l8_strength", noise_l8_strength)
				mat.set_shader_parameter("noise_l8_edge_only", noise_l8_edge_only)
				mat.set_shader_parameter("noise_l8_channel", noise_l8_channel)
				mat.set_shader_parameter("normal_depth", normal_depth)
				mat.set_shader_parameter("invert_normal_y", invert_normal_y)
				mat.set_shader_parameter("normal_orbital_ratio", normal_orbital_ratio)
				mat.set_shader_parameter("normal_slope_threshold", normal_slope_threshold)
				var n3d := _get_or_create_3d_noise_texture()
				if n3d:
					mat.set_shader_parameter("noise_texture_3d", n3d)
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

func _set_cloud_noise_speed(v: float) -> void:
	cloud_noise_speed = v
	_update_cloud_params()

func _set_cloud_noise_follow(v: float) -> void:
	cloud_noise_follow = v
	_update_cloud_params()

func _set_cloud_shadow_intensity(v: float) -> void:
	cloud_shadow_intensity = v
	_update_cloud_params()

func _set_cloud_edge_noise(v: float) -> void:
	cloud_edge_noise = clampf(v, 0.0, 2.0)
	_update_cloud_params()

func _set_cloud_noise_amount(v: float) -> void:
	cloud_noise_amount = clampf(v, 0.0, 2.0)
	_update_cloud_params()

func _set_cloud_self_shadow_intensity(v: float) -> void:
	cloud_self_shadow_intensity = clampf(v, 0.0, 2.0)
	_update_atmosphere_params()

func _set_cloud_terminator_depth(v: float) -> void:
	cloud_terminator_depth = clampf(v, 0.0, 2.0)
	_update_atmosphere_params()

func _set_cloud_terminator_softness(v: float) -> void:
	cloud_terminator_softness = clampf(v, 0.02, 0.5)
	_update_atmosphere_params()

func _set_cloud_sunset_tint(v: float) -> void:
	cloud_sunset_tint = clampf(v, 0.0, 1.0)
	_update_atmosphere_params()

func _set_cloud_terminator_offset(v: float) -> void:
	cloud_terminator_offset = clampf(v, -0.4, 0.4)
	_update_atmosphere_params()

func _set_cloud_opacity(v: float) -> void:
	cloud_opacity = clampf(v, 0.2, 5.0)
	_update_atmosphere_params()

func _set_cloud_dither(v: float) -> void:
	cloud_dither = clampf(v, 0.0, 1.0)
	_update_atmosphere_params()

func _set_cloud_day_brightness(v: float) -> void:
	cloud_day_brightness = v
	_update_atmosphere_params()

func _set_cloud_night_brightness(v: float) -> void:
	cloud_night_brightness = v
	_update_atmosphere_params()

func _set_cloud_map_height(v: float) -> void:
	cloud_map_height = v
	_update_cloud_params()

func _set_cloud_map_density(v: float) -> void:
	cloud_map_density = v
	_update_cloud_params()

func _set_cloud_color(v: Color) -> void:
	cloud_color = v
	_update_atmosphere_params()

func _set_cloud_shadow_color(v: Color) -> void:
	cloud_shadow_color = v
	_update_cloud_params()

var _in_noise_sync: bool = false

func _set_noise_base_scale(v: float) -> void:
	noise_base_scale = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_l1_scale(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_base_strength(v: float) -> void:
	noise_base_strength = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_l1_strength(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_detail_scale(v: float) -> void:
	noise_detail_scale = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_l2_scale(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_detail_strength(v: float) -> void:
	noise_detail_strength = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_l2_strength(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_l1_enabled(v: bool) -> void: noise_l1_enabled = v; _update_cloud_params()
func _set_noise_l1_scale(v: float) -> void:
	noise_l1_scale = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_base_scale(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_l1_strength(v: float) -> void:
	noise_l1_strength = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_base_strength(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_l1_edge_only(v: float) -> void: noise_l1_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l1_channel(v: int) -> void: noise_l1_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l2_enabled(v: bool) -> void: noise_l2_enabled = v; _update_cloud_params()
func _set_noise_l2_scale(v: float) -> void:
	noise_l2_scale = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_detail_scale(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_l2_strength(v: float) -> void:
	noise_l2_strength = v
	if not _in_noise_sync:
		_in_noise_sync = true
		_set_noise_detail_strength(v)
		_in_noise_sync = false
	_update_cloud_params()

func _set_noise_l2_edge_only(v: float) -> void: noise_l2_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l2_channel(v: int) -> void: noise_l2_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l3_enabled(v: bool) -> void: noise_l3_enabled = v; _update_cloud_params()
func _set_noise_l3_scale(v: float) -> void: noise_l3_scale = v; _update_cloud_params()
func _set_noise_l3_strength(v: float) -> void: noise_l3_strength = v; _update_cloud_params()
func _set_noise_l3_edge_only(v: float) -> void: noise_l3_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l3_channel(v: int) -> void: noise_l3_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l4_enabled(v: bool) -> void: noise_l4_enabled = v; _update_cloud_params()
func _set_noise_l4_scale(v: float) -> void: noise_l4_scale = v; _update_cloud_params()
func _set_noise_l4_strength(v: float) -> void: noise_l4_strength = v; _update_cloud_params()
func _set_noise_l4_edge_only(v: float) -> void: noise_l4_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l4_channel(v: int) -> void: noise_l4_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l5_enabled(v: bool) -> void: noise_l5_enabled = v; _update_cloud_params()
func _set_noise_l5_scale(v: float) -> void: noise_l5_scale = v; _update_cloud_params()
func _set_noise_l5_strength(v: float) -> void: noise_l5_strength = v; _update_cloud_params()
func _set_noise_l5_edge_only(v: float) -> void: noise_l5_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l5_channel(v: int) -> void: noise_l5_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l6_enabled(v: bool) -> void: noise_l6_enabled = v; _update_cloud_params()
func _set_noise_l6_scale(v: float) -> void: noise_l6_scale = v; _update_cloud_params()
func _set_noise_l6_strength(v: float) -> void: noise_l6_strength = v; _update_cloud_params()
func _set_noise_l6_edge_only(v: float) -> void: noise_l6_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l6_channel(v: int) -> void: noise_l6_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l7_enabled(v: bool) -> void: noise_l7_enabled = v; _update_cloud_params()
func _set_noise_l7_scale(v: float) -> void: noise_l7_scale = v; _update_cloud_params()
func _set_noise_l7_strength(v: float) -> void: noise_l7_strength = v; _update_cloud_params()
func _set_noise_l7_edge_only(v: float) -> void: noise_l7_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l7_channel(v: int) -> void: noise_l7_channel = clampi(v, 0, 3); _update_cloud_params()

func _set_noise_l8_enabled(v: bool) -> void: noise_l8_enabled = v; _update_cloud_params()
func _set_noise_l8_scale(v: float) -> void: noise_l8_scale = v; _update_cloud_params()
func _set_noise_l8_strength(v: float) -> void: noise_l8_strength = v; _update_cloud_params()
func _set_noise_l8_edge_only(v: float) -> void: noise_l8_edge_only = clampf(v, 0.0, 1.0); _update_cloud_params()
func _set_noise_l8_channel(v: int) -> void: noise_l8_channel = clampi(v, 0, 3); _update_cloud_params()


func _set_cloud_samples(v: int) -> void:
	cloud_samples = clampi(v, 4, 64)
	_update_atmosphere_params()

func _set_render_scale(v: float) -> void:
	render_scale = clampf(v, 0.25, 1.0)
	if is_inside_tree() and get_viewport():
		get_viewport().scaling_3d_scale = render_scale

func _set_normal_depth(v: float) -> void:
	normal_depth = clampf(v, 0.0, 2.0)
	_update_shader_params()

func _set_invert_normal_y(v: bool) -> void:
	invert_normal_y = v
	_update_shader_params()

func _set_normal_orbital_ratio(v: float) -> void:
	normal_orbital_ratio = clampf(v, -2.0, 2.0)
	_update_shader_params()

func _set_normal_slope_threshold(v: float) -> void:
	normal_slope_threshold = clampf(v, 0.0, 1.0)
	_update_shader_params()

func _get_or_create_3d_noise_texture() -> ImageTexture3D:
	if _noise_texture_3d != null:
		return _noise_texture_3d
	var path := "res://assets/cloud_noise_3d.bin"
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var size := 64
		var images: Array[Image] = []
		var slice_size := size * size * 4
		for z in range(size):
			var slice_data := bytes.slice(z * slice_size, (z + 1) * slice_size)
			var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, slice_data)
			images.append(img)
		_noise_texture_3d = ImageTexture3D.new()
		var err := _noise_texture_3d.create(Image.FORMAT_RGBA8, size, size, size, false, images)
		if err != OK:
			push_warning("Failed to create ImageTexture3D: %s" % err)
	return _noise_texture_3d

func _get_transmittance_lut() -> Texture2D:
	if _transmittance_lut != null:
		return _transmittance_lut
	var path := "res://assets/transmittance_lut.png"
	if ResourceLoader.exists(path):
		_transmittance_lut = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			_transmittance_lut = ImageTexture.create_from_image(img)
	return _transmittance_lut

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
		_atmo_material.set_shader_parameter("planet_center", global_position)
		if sun_light and sun_light.is_inside_tree():
			_atmo_material.set_shader_parameter(
				"sun_dir", -sun_light.global_transform.basis.z.normalized()
			)
		else:
			_atmo_material.set_shader_parameter("sun_dir", Vector3.UP)
	_atmo_material.set_shader_parameter("planet_radius", radius)
	_atmo_material.set_shader_parameter("atmo_radius", radius * atmosphere_scale)

	if atmosphere_enabled:
		_atmo_material.set_shader_parameter("rayleigh_coeff", rayleigh_coeff)
		_atmo_material.set_shader_parameter("scale_height_r", radius * scale_height_rayleigh)
		_atmo_material.set_shader_parameter("mie_coeff", mie_coeff)
		_atmo_material.set_shader_parameter("mie_g", mie_g)
		_atmo_material.set_shader_parameter("scale_height_m", radius * scale_height_mie)
	else:
		_atmo_material.set_shader_parameter("rayleigh_coeff", Vector3.ZERO)
		_atmo_material.set_shader_parameter("scale_height_r", radius * scale_height_rayleigh)
		_atmo_material.set_shader_parameter("mie_coeff", 0.0)
		_atmo_material.set_shader_parameter("mie_g", mie_g)
		_atmo_material.set_shader_parameter("scale_height_m", radius * scale_height_mie)

	_atmo_material.set_shader_parameter("sun_intensity", sun_intensity)

	_atmo_material.set_shader_parameter("cloud_enabled", cloud_enabled)
	_atmo_material.set_shader_parameter("invert_clouds", invert_clouds)
	_atmo_material.set_shader_parameter("cloud_altitude", cloud_altitude)
	_atmo_material.set_shader_parameter("cloud_thickness", cloud_thickness)
	_atmo_material.set_shader_parameter("cloud_density", cloud_density)
	_atmo_material.set_shader_parameter("cloud_coverage", cloud_coverage)
	_atmo_material.set_shader_parameter("cloud_speed", cloud_speed)
	_atmo_material.set_shader_parameter("planet_rotation", rotation.y)
	_atmo_material.set_shader_parameter("cloud_noise_speed", cloud_noise_speed)
	_atmo_material.set_shader_parameter("cloud_noise_follow", cloud_noise_follow)
	_atmo_material.set_shader_parameter("cloud_day_brightness", cloud_day_brightness)
	_atmo_material.set_shader_parameter("cloud_night_brightness", cloud_night_brightness)
	_atmo_material.set_shader_parameter("cloud_map_height", cloud_map_height)
	_atmo_material.set_shader_parameter("cloud_map_density", cloud_map_density)
	_atmo_material.set_shader_parameter("cloud_color", cloud_color)
	_atmo_material.set_shader_parameter("cloud_shadow_color", cloud_shadow_color)
	_atmo_material.set_shader_parameter("cloud_edge_noise", cloud_edge_noise)
	_atmo_material.set_shader_parameter("cloud_noise_amount", cloud_noise_amount)
	_atmo_material.set_shader_parameter("godray_intensity", godray_intensity)
	_atmo_material.set_shader_parameter("cloud_self_shadow_intensity", cloud_self_shadow_intensity)
	_atmo_material.set_shader_parameter("cloud_terminator_depth", cloud_terminator_depth)
	_atmo_material.set_shader_parameter("cloud_terminator_softness", cloud_terminator_softness)
	_atmo_material.set_shader_parameter("cloud_sunset_tint", cloud_sunset_tint)
	_atmo_material.set_shader_parameter("cloud_terminator_offset", cloud_terminator_offset)
	_atmo_material.set_shader_parameter("cloud_opacity", cloud_opacity)
	_atmo_material.set_shader_parameter("cloud_dither", cloud_dither)
	_atmo_material.set_shader_parameter("cloud_shadow_intensity", cloud_shadow_intensity)
	_atmo_material.set_shader_parameter("noise_base_scale", noise_base_scale)
	_atmo_material.set_shader_parameter("noise_base_strength", noise_base_strength)
	_atmo_material.set_shader_parameter("noise_detail_scale", noise_detail_scale)
	_atmo_material.set_shader_parameter("noise_detail_strength", noise_detail_strength)

	_atmo_material.set_shader_parameter("noise_l1_enabled", noise_l1_enabled)
	_atmo_material.set_shader_parameter("noise_l1_scale", noise_l1_scale)
	_atmo_material.set_shader_parameter("noise_l1_strength", noise_l1_strength)
	_atmo_material.set_shader_parameter("noise_l1_edge_only", noise_l1_edge_only)
	_atmo_material.set_shader_parameter("noise_l1_channel", noise_l1_channel)

	_atmo_material.set_shader_parameter("noise_l2_enabled", noise_l2_enabled)
	_atmo_material.set_shader_parameter("noise_l2_scale", noise_l2_scale)
	_atmo_material.set_shader_parameter("noise_l2_strength", noise_l2_strength)
	_atmo_material.set_shader_parameter("noise_l2_edge_only", noise_l2_edge_only)
	_atmo_material.set_shader_parameter("noise_l2_channel", noise_l2_channel)

	_atmo_material.set_shader_parameter("noise_l3_enabled", noise_l3_enabled)
	_atmo_material.set_shader_parameter("noise_l3_scale", noise_l3_scale)
	_atmo_material.set_shader_parameter("noise_l3_strength", noise_l3_strength)
	_atmo_material.set_shader_parameter("noise_l3_edge_only", noise_l3_edge_only)
	_atmo_material.set_shader_parameter("noise_l3_channel", noise_l3_channel)

	_atmo_material.set_shader_parameter("noise_l4_enabled", noise_l4_enabled)
	_atmo_material.set_shader_parameter("noise_l4_scale", noise_l4_scale)
	_atmo_material.set_shader_parameter("noise_l4_strength", noise_l4_strength)
	_atmo_material.set_shader_parameter("noise_l4_edge_only", noise_l4_edge_only)
	_atmo_material.set_shader_parameter("noise_l4_channel", noise_l4_channel)

	_atmo_material.set_shader_parameter("noise_l5_enabled", noise_l5_enabled)
	_atmo_material.set_shader_parameter("noise_l5_scale", noise_l5_scale)
	_atmo_material.set_shader_parameter("noise_l5_strength", noise_l5_strength)
	_atmo_material.set_shader_parameter("noise_l5_edge_only", noise_l5_edge_only)
	_atmo_material.set_shader_parameter("noise_l5_channel", noise_l5_channel)

	_atmo_material.set_shader_parameter("noise_l6_enabled", noise_l6_enabled)
	_atmo_material.set_shader_parameter("noise_l6_scale", noise_l6_scale)
	_atmo_material.set_shader_parameter("noise_l6_strength", noise_l6_strength)
	_atmo_material.set_shader_parameter("noise_l6_edge_only", noise_l6_edge_only)
	_atmo_material.set_shader_parameter("noise_l6_channel", noise_l6_channel)

	_atmo_material.set_shader_parameter("noise_l7_enabled", noise_l7_enabled)
	_atmo_material.set_shader_parameter("noise_l7_scale", noise_l7_scale)
	_atmo_material.set_shader_parameter("noise_l7_strength", noise_l7_strength)
	_atmo_material.set_shader_parameter("noise_l7_edge_only", noise_l7_edge_only)
	_atmo_material.set_shader_parameter("noise_l7_channel", noise_l7_channel)

	_atmo_material.set_shader_parameter("noise_l8_enabled", noise_l8_enabled)
	_atmo_material.set_shader_parameter("noise_l8_scale", noise_l8_scale)
	_atmo_material.set_shader_parameter("noise_l8_strength", noise_l8_strength)
	_atmo_material.set_shader_parameter("noise_l8_edge_only", noise_l8_edge_only)
	_atmo_material.set_shader_parameter("noise_l8_channel", noise_l8_channel)


	var n3d := _get_or_create_3d_noise_texture()
	if n3d:
		_atmo_material.set_shader_parameter("noise_texture_3d", n3d)
	var lut := _get_transmittance_lut()
	if lut:
		_atmo_material.set_shader_parameter("transmittance_lut", lut)
	_atmo_material.set_shader_parameter("cloud_samples", cloud_samples)

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

func _set_godray_intensity(v: float) -> void:
	godray_intensity = clampf(v, 0.0, 3.0)
	_update_atmosphere_params()

func _set_rayleigh_coeff(v: Vector3) -> void:
	rayleigh_coeff = v
	_update_atmosphere_params()

func _set_scale_height_rayleigh(v: float) -> void:
	scale_height_rayleigh = v
	_update_atmosphere_params()

func _set_mie_coeff(v: float) -> void:
	mie_coeff = v
	_update_atmosphere_params()

func _set_mie_g(v: float) -> void:
	mie_g = v
	_update_atmosphere_params()

func _set_scale_height_mie(v: float) -> void:
	scale_height_mie = v
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
	if not is_inside_tree() or not active_cam or not active_cam.is_inside_tree():
		return

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

	var sun_alignment: float = cam_fwd.dot(sun_dir)
	var sun_glare: float = 0.0
	if sun_alignment > 0.0:
		sun_glare = pow(sun_alignment, 3.0) * clampf(sun_intensity / 2.0, 0.5, 3.0)

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

	var target_brightness: float = clampf(sun_glare * 0.9 + planet_day_glare * 0.9, 0.0, 1.0)

	var adapt_speed: float = eye_adaptation_speed
	if target_brightness > current_perceived_brightness:
		adapt_speed *= 1.4
	var t: float = 1.0 - exp(-adapt_speed * delta)
	current_perceived_brightness = lerpf(current_perceived_brightness, target_brightness, t)

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

# ==============================================================================
# Persistent Cloud Settings System
# ==============================================================================
func get_cloud_settings_dict() -> Dictionary:
	return {
		"planet_spin_enabled": planet_spin_enabled,
		"planet_spin_speed": planet_spin_speed,
		"cloud_enabled": cloud_enabled,
		"invert_clouds": invert_clouds,
		"cloud_altitude": cloud_altitude,
		"cloud_thickness": cloud_thickness,
		"cloud_density": cloud_density,
		"cloud_opacity": cloud_opacity,
		"cloud_dither": cloud_dither,
		"cloud_coverage": cloud_coverage,
		"cloud_speed": cloud_speed,
		"cloud_noise_speed": cloud_noise_speed,
		"cloud_noise_follow": cloud_noise_follow,
		"cloud_day_brightness": cloud_day_brightness,
		"cloud_night_brightness": cloud_night_brightness,
		"cloud_map_height": cloud_map_height,
		"cloud_map_density": cloud_map_density,
		"cloud_edge_noise": cloud_edge_noise,
		"cloud_noise_amount": cloud_noise_amount,
		"godray_intensity": godray_intensity,
		"cloud_self_shadow_intensity": cloud_self_shadow_intensity,
		"cloud_terminator_depth": cloud_terminator_depth,
		"cloud_terminator_softness": cloud_terminator_softness,
		"cloud_sunset_tint": cloud_sunset_tint,
		"cloud_terminator_offset": cloud_terminator_offset,
		"cloud_shadow_intensity": cloud_shadow_intensity,
		"cloud_samples": cloud_samples,
		"noise_base_scale": noise_base_scale,
		"noise_base_strength": noise_base_strength,
		"noise_detail_scale": noise_detail_scale,
		"noise_detail_strength": noise_detail_strength,
		"noise_l1_enabled": noise_l1_enabled,
		"noise_l1_scale": noise_l1_scale,
		"noise_l1_strength": noise_l1_strength,
		"noise_l1_edge_only": noise_l1_edge_only,
		"noise_l1_channel": noise_l1_channel,
		"noise_l2_enabled": noise_l2_enabled,
		"noise_l2_scale": noise_l2_scale,
		"noise_l2_strength": noise_l2_strength,
		"noise_l2_edge_only": noise_l2_edge_only,
		"noise_l2_channel": noise_l2_channel,
		"noise_l3_enabled": noise_l3_enabled,
		"noise_l3_scale": noise_l3_scale,
		"noise_l3_strength": noise_l3_strength,
		"noise_l3_edge_only": noise_l3_edge_only,
		"noise_l3_channel": noise_l3_channel,
		"noise_l4_enabled": noise_l4_enabled,
		"noise_l4_scale": noise_l4_scale,
		"noise_l4_strength": noise_l4_strength,
		"noise_l4_edge_only": noise_l4_edge_only,
		"noise_l4_channel": noise_l4_channel,
		"noise_l5_enabled": noise_l5_enabled,
		"noise_l5_scale": noise_l5_scale,
		"noise_l5_strength": noise_l5_strength,
		"noise_l5_edge_only": noise_l5_edge_only,
		"noise_l5_channel": noise_l5_channel,
		"noise_l6_enabled": noise_l6_enabled,
		"noise_l6_scale": noise_l6_scale,
		"noise_l6_strength": noise_l6_strength,
		"noise_l6_edge_only": noise_l6_edge_only,
		"noise_l6_channel": noise_l6_channel,
		"noise_l7_enabled": noise_l7_enabled,
		"noise_l7_scale": noise_l7_scale,
		"noise_l7_strength": noise_l7_strength,
		"noise_l7_edge_only": noise_l7_edge_only,
		"noise_l7_channel": noise_l7_channel,
		"noise_l8_enabled": noise_l8_enabled,
		"noise_l8_scale": noise_l8_scale,
		"noise_l8_strength": noise_l8_strength,
		"noise_l8_edge_only": noise_l8_edge_only,
		"noise_l8_channel": noise_l8_channel,
	}


func load_cloud_settings_from_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://cloud_settings.cfg") == OK:
		var keys := cfg.get_section_keys("clouds")
		for k in keys:
			var val = cfg.get_value("clouds", k)
			set(k, val)
		_update_cloud_params()

func save_cloud_settings_to_scene() -> bool:
	var dict := get_cloud_settings_dict()

	var cfg := ConfigFile.new()
	for k in dict:
		cfg.set_value("clouds", k, dict[k])
	var err := cfg.save("res://cloud_settings.cfg")
	if err != OK:
		push_warning("Failed to save cloud_settings.cfg: %s" % err)

	var tscn_path := "res://scenes/space.tscn"
	if not FileAccess.file_exists(tscn_path):
		return true

	var f_read := FileAccess.open(tscn_path, FileAccess.READ)
	if not f_read:
		return false
	var content := f_read.get_as_text()
	f_read.close()

	var planet_tag := '[node name="Planet" '
	var start_idx := content.find(planet_tag)
	if start_idx == -1:
		return true

	var next_node_idx := content.find("\n[node ", start_idx + 1)
	var end_idx := content.length() if next_node_idx == -1 else next_node_idx

	var planet_block := content.substr(start_idx, end_idx - start_idx)
	var lines := planet_block.split("\n")
	var new_lines: Array[String] = []

	var handled_keys: Dictionary = {}
	for line in lines:
		var trimmed := line.strip_edges()
		var eq_pos := trimmed.find(" = ")
		if eq_pos > 0 and not trimmed.begins_with("["):
			var key := trimmed.substr(0, eq_pos).strip_edges()
			if dict.has(key):
				var val = dict[key]
				var val_str := ""
				if typeof(val) == TYPE_BOOL:
					val_str = "true" if val else "false"
				elif typeof(val) == TYPE_FLOAT:
					val_str = "%.4f" % val if val != floor(val) else "%.1f" % val
				else:
					val_str = str(val)
				new_lines.append("%s = %s" % [key, val_str])
				handled_keys[key] = true
				continue
		new_lines.append(line)

	var insert_pos := -1
	for i in range(new_lines.size()):
		if new_lines[i].begins_with("face_a_color"):
			insert_pos = i
			break
	if insert_pos == -1:
		insert_pos = new_lines.size()

	var to_insert: Array[String] = []
	for k in dict:
		if not handled_keys.has(k):
			var val = dict[k]
			var val_str := ""
			if typeof(val) == TYPE_BOOL:
				val_str = "true" if val else "false"
			elif typeof(val) == TYPE_FLOAT:
				val_str = "%.4f" % val if val != floor(val) else "%.1f" % val
			else:
				val_str = str(val)
			to_insert.append("%s = %s" % [k, val_str])

	for l in to_insert:
		new_lines.insert(insert_pos, l)
		insert_pos += 1

	var new_planet_block := "\n".join(new_lines)
	var new_content := content.substr(0, start_idx) + new_planet_block + content.substr(end_idx)

	var f_write := FileAccess.open(tscn_path, FileAccess.WRITE)
	if f_write:
		f_write.store_string(new_content)
		f_write.close()
		print("[Planet] Cloud settings successfully saved and applied to scenes/space.tscn and cloud_settings.cfg!")
		return true

	return false
