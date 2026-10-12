shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 shallow_color : source_color = vec4(0.04, 0.42, 0.58, 0.8);
uniform vec4 deep_color : source_color = vec4(0.01, 0.06, 0.18, 1.0);
uniform float depth_distance : hint_range(0.1, 100.0) = 6.0;
uniform float ocean_altitude = 0.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D water_mask : hint_default_white, repeat_enable, filter_linear_mipmap;

// Cloud Shadow Projection
uniform bool cloud_enabled = true;
uniform bool invert_clouds = false;
uniform sampler2D cloud_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 planet_center = vec3(0.0);
uniform float planet_radius = 600.0;
uniform float cloud_altitude = 2.0;
uniform float cloud_thickness = 3.5;
uniform float cloud_coverage = 0.65;
uniform float cloud_speed = 0.001;
uniform float cloud_shadow_intensity = 0.75;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying float v_is_skirt;

void vertex() {
	v_is_skirt = UV2.x;
	if (v_is_skirt < 0.0) {
		VERTEX = normalize(VERTEX) * (length(VERTEX) + ocean_altitude - 2.0);
	} else {
		VERTEX += NORMAL * ocean_altitude;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Procedural micro-wave normal calculation directly on the sphere without Cartesian UV tiling artifacts
vec3 get_wave_normal(vec3 p, vec3 n, float t) {
	vec3 p1 = p * 40.0;
	vec3 p2 = p * 90.0;
	vec3 p3 = p * 180.0;

	vec3 b1 = vec3(
		cos(p1.x + t * 1.8) * cos(p1.z + t * 1.4),
		cos(p1.y * 1.3 - t * 1.6),
		-sin(p1.x + t * 1.8) * sin(p1.z + t * 1.4)
	) * 0.005;

	vec3 b2 = vec3(
		cos(p2.z - t * 2.5) * cos(p2.y + t * 2.1),
		-sin(p2.y + t * 2.1) * sin(p2.x - t * 1.8),
		cos(p2.x - t * 1.8)
	) * 0.003;

	vec3 b3 = vec3(
		sin(p3.x + p3.z + t * 3.5),
		cos(p3.y + p3.x - t * 3.0),
		sin(p3.z - p3.y + t * 3.8)
	) * 0.0015;

	vec3 bump = b1 + b2 + b3;
	bump -= n * dot(bump, n); // Project tangentially to the sphere
	return normalize(n + bump);
}

void fragment() {
	// Equirectangular water mask check
	float lat = asin(clamp(v_world_normal.y, -1.0, 1.0));
	float v_mask = 0.5 - lat / 3.141592653589793;
	float lon = atan(v_world_normal.x, v_world_normal.z);
	float u_mask = fract(lon / (2.0 * 3.141592653589793) + 0.5);
	float mask_val = textureLod(water_mask, vec2(u_mask, v_mask), 0.0).r;

	if (FRONT_FACING && mask_val < 0.02) {
		discard;
	}

	// Reconstruct terrain depth from scene depth texture
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 up_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float terrain_depth = -up_pos.z / up_pos.w;
	float water_surface_depth = -VERTEX.z;

	float water_depth = terrain_depth - water_surface_depth;

	// Shoreline clipping: only discard on land / shallow coasts, never in open water
	if (FRONT_FACING && water_depth <= 0.0 && mask_val < 0.1) {
		discard;
	}

	// In deep open ocean, water is fully absorbed and opaque (hiding underlying seabed mesh facets & skirts)
	float open_ocean_factor = smoothstep(0.1, 0.45, mask_val);
	float depth_ratio = clamp(water_depth / depth_distance, 0.0, 1.0);
	float absorption = mix(1.0 - exp(-depth_ratio * 3.0), 1.0, open_ocean_factor);
	vec4 base_water = mix(shallow_color, deep_color, absorption);

	// Procedural wave normal on the sphere (inverted if viewed from underwater/inside)
	vec3 base_norm = FRONT_FACING ? v_world_normal : -v_world_normal;
	vec3 wave_normal_world = get_wave_normal(v_world_pos, base_norm, TIME);
	vec3 wave_normal_view = normalize((VIEW_MATRIX * vec4(wave_normal_world, 0.0)).xyz);

	// Sun visibility on the planet sphere (coherent with atmosphere day/night terminator)
	vec3 sun_norm = -normalize(sun_dir);
	float sun_dot = dot(v_world_normal, sun_norm);
	float sun_vis = smoothstep(-0.06, 0.06, sun_dot);

	// Dynamic Cloud Shadow on Ocean:
	float shadow_factor = 0.0;
	if (cloud_enabled && sun_dot > -0.05) {
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
				shadow_factor = smoothstep(1.0 - cloud_coverage * 0.9, 1.0, cov) * sun_facing;
			}
		}
	}

	// Grazing Fresnel rim reflection (only on sunlit hemisphere)
	float fresnel = pow(1.0 - clamp(dot(wave_normal_view, VIEW), 0.0, 1.0), 4.5) * sun_vis;
	vec3 ocean_surface = base_water.rgb * (0.02 + 0.98 * sun_vis) + vec3(0.08, 0.22, 0.45) * fresnel;
	ocean_surface *= mix(vec3(1.0), vec3(0.38, 0.44, 0.55), shadow_factor * (cloud_shadow_intensity * 0.96));

	// Soft shoreline feathering along coastal boundary
	float coast_edge = smoothstep(0.02, 0.25, mask_val);
	float depth_edge = clamp(water_depth / 0.4, 0.0, 1.0);
	float shore_alpha = FRONT_FACING ? mix(coast_edge * depth_edge, 1.0, open_ocean_factor) : 1.0;

	// In deep water, ALPHA is 1.0 (completely opaque, solid surface). Near shore, smoothly fades.
	float water_alpha = mix(base_water.a, 1.0, open_ocean_factor);

	ALBEDO = ocean_surface;
	ALPHA = clamp((water_alpha * (0.02 + 0.98 * sun_vis) + fresnel * 0.25) * shore_alpha, 0.0, 1.0);
	ROUGHNESS = 0.08;
	SPECULAR = 0.95 * sun_vis * mix(1.0, 0.05, shadow_factor * cloud_shadow_intensity);
	METALLIC = 0.0;
	NORMAL = wave_normal_view;
}