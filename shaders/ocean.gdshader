shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 shallow_color : source_color = vec4(0.04, 0.42, 0.58, 0.8);
uniform vec4 deep_color : source_color = vec4(0.01, 0.06, 0.18, 1.0);
uniform float depth_distance : hint_range(0.1, 100.0) = 6.0;
uniform float ocean_altitude = 0.0;
uniform vec3 camera_pos = vec3(0.0);

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D water_mask : hint_default_white, repeat_enable, filter_linear_mipmap;

// FFT & Gerstner Ocean Wave Settings (Scatterer-Style Spectrum)
uniform float wind_direction : hint_range(0.0, 6.283) = 0.785;
uniform float wave_amplitude : hint_range(0.0, 3.0) = 0.45;
uniform float wave_frequency : hint_range(0.1, 5.0) = 1.0;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_choppiness : hint_range(0.0, 2.0) = 1.15;
uniform float wave_steepness : hint_range(0.0, 2.0) = 1.15;

// Ocean Foam & Whitecaps Settings
uniform vec4 foam_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);
uniform float whitecap_threshold : hint_range(0.0, 1.0) = 0.52;
uniform float crest_foam_threshold : hint_range(0.0, 1.0) = 0.52;
uniform float shore_foam_distance : hint_range(0.05, 5.0) = 0.85;
uniform float foam_intensity : hint_range(0.0, 2.0) = 1.0;

// Realtime Screen Space Reflections (SSR)
uniform bool ssr_enabled = true;
uniform int ssr_max_steps : hint_range(8, 48) = 24;
uniform float ssr_max_distance : hint_range(5.0, 150.0) = 45.0;
uniform float ssr_thickness : hint_range(0.1, 10.0) = 1.2;
uniform float ssr_edge_fade : hint_range(0.01, 0.5) = 0.15;

// Cloud Shadow Projection
uniform bool cloud_enabled = true;
uniform bool invert_clouds = false;
uniform sampler2D cloud_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 planet_center = vec3(0.0);
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

// Multi-layer stackable 3D procedural noise (for cloud shadows)
uniform bool noise_l1_enabled = true;
uniform float noise_l1_scale = 160.0;
uniform float noise_l1_strength = 0.35;
uniform float noise_l1_edge_only = 0.0;
uniform int noise_l1_channel = 0;

uniform bool noise_l2_enabled = true;
uniform float noise_l2_scale = 400.0;
uniform float noise_l2_strength = 0.25;
uniform float noise_l2_edge_only = 0.65;
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

// Legacy uniform aliases
uniform float noise_base_scale = 160.0;
uniform float noise_base_strength = 0.35;
uniform float noise_detail_scale = 400.0;
uniform float noise_detail_strength = 0.2;
uniform sampler3D noise_texture_3d : repeat_enable, filter_linear;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_local_pos;
varying vec3 v_local_normal;

void vertex() {
	vec3 norm = normalize(NORMAL);

	// Continuous smooth spherical ocean (Scatterer approach: perfect mathematical sphere)
	VERTEX = norm * (planet_radius + ocean_altitude);

	v_local_pos = VERTEX;
	v_local_normal = norm;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(norm, 0.0)).xyz);
}

// 8-Octave Spherical 3D Gerstner Wave Spectrum Evaluation
// 8-Octave Spherical 3D Gerstner Wave Spectrum Evaluation (Scatterer Planetary Ocean)
// Fully seamless, distortion-free across the globe with zero polar singularities
vec3 evaluate_ocean_spectrum(
	vec3 pos_local, vec3 norm_local, float t, float cam_dist, float amp_scale,
	out float out_crest_sharpness, out float out_wave_height
) {
	if (amp_scale <= 0.001) {
		out_crest_sharpness = 0.0;
		out_wave_height = 0.0;
		return norm_local;
	}

	// 8 Wave octaves across swells, wind waves, and capillary ripples (calibrated for planet scale)
	const float LAMBDAS[8]   = float[8](3.6, 2.2, 1.35, 0.82, 0.48, 0.28, 0.15, 0.07);
	const float AMPS[8]      = float[8](0.075, 0.052, 0.034, 0.021, 0.012, 0.0065, 0.0032, 0.0014);
	const float SPEEDS[8]    = float[8](0.90, 1.15, 1.50, 1.95, 2.60, 3.40, 4.50, 5.80);
	const float CHOPS[8]     = float[8](1.30, 1.20, 1.10, 1.00, 0.85, 0.70, 0.55, 0.40);
	const float ANGLES_AZ[8] = float[8](0.08, -0.22, 0.35, -0.48, 0.62, -0.75, 0.95, -1.15);
	const float ANGLES_EL[8] = float[8](0.05, 0.12, -0.15, 0.18, -0.22, 0.25, -0.30, 0.35);

	// Multi-Scale Distance LOD Filtering:
	// Capillary ripples fade near surface; swells provide glint variance to orbit
	float lod_capillary = clamp(1.0 - (cam_dist - 5.0) / 30.0, 0.0, 1.0);
	float lod_chop      = clamp(1.0 - (cam_dist - 15.0) / 80.0, 0.0, 1.0);
	float lod_wind      = clamp(1.0 - (cam_dist - 40.0) / 250.0, 0.0, 1.0);
	float lod_swell     = clamp(1.0 - (cam_dist - 100.0) / 1500.0, 0.15, 1.0);

	vec3 wind_dir = vec3(cos(wind_direction), 0.0, sin(wind_direction));
	vec3 cross_wind = vec3(-sin(wind_direction), 0.0, cos(wind_direction));
	vec3 up_dir = vec3(0.0, 1.0, 0.0);

	vec3 total_slope = vec3(0.0);
	float crest_acc = 0.0;
	float height_acc = 0.0;

	for (int i = 0; i < 8; i++) {
		float dist_weight = (i >= 6) ? lod_capillary : ((i >= 4) ? lod_chop : ((i >= 2) ? lod_wind : lod_swell));
		if (dist_weight <= 0.001) continue;

		vec3 dir_3d = normalize(
			wind_dir * cos(ANGLES_AZ[i]) +
			cross_wind * sin(ANGLES_AZ[i]) +
			up_dir * sin(ANGLES_EL[i])
		);

		// Project wave propagation direction into the local surface tangent plane
		vec3 dir_tan = dir_3d - norm_local * dot(dir_3d, norm_local);
		float dir_tan_len = length(dir_tan);
		if (dir_tan_len < 0.001) continue;
		vec3 unit_dir_tan = dir_tan / dir_tan_len;

		float k = (6.28318530718 / LAMBDAS[i]) * wave_frequency;
		float speed = SPEEDS[i] * wave_speed;
		float a = AMPS[i] * amp_scale * dist_weight;
		float q = CHOPS[i] * max(wave_choppiness, wave_steepness * 0.8);

		float phase = dot(dir_3d, pos_local) * k + t * speed;
		float sin_p = sin(phase);
		float cos_p = cos(phase);

		// Gerstner derivative slope vector along the surface tangent
		float slope_mag = q * a * k * cos_p;
		total_slope += unit_dir_tan * slope_mag;

		// Analytical wave height for 3D depth chiaroscuro
		height_acc += a * sin_p;

		// Wave crest sharpness (Jacobian determinant term for breaking foam)
		if (i <= 5) {
			crest_acc += (q * a * k * (1.0 + sin_p) * 0.5) * dist_weight;
		}
	}

	out_crest_sharpness = crest_acc;
	out_wave_height = height_acc;
	return normalize(norm_local - total_slope);
}

float remap(float value, float originalMin, float originalMax, float newMin, float newMax) {
	return newMin + (((value - originalMin) / max(1e-5, originalMax - originalMin)) * (newMax - newMin));
}

float get_noise_ch(vec4 n, int ch) {
	float v = n.r;
	if (ch == 1) v = n.g;
	else if (ch == 2) v = n.b;
	else if (ch == 3) v = n.a;
	return smoothstep(0.0, 1.0, clamp((v - 0.24) / 0.52, 0.0, 1.0));
}

float sample_cloud_raw_ocean(vec2 uv, float lod) {
	vec4 c_tex = textureLod(cloud_texture, vec2(fract(uv.x), clamp(uv.y, 0.001, 0.999)), lod);
	return (c_tex.a < 0.999) ? c_tex.a : c_tex.r;
}

// Realtime View-Space Screen Space Reflections (SSR)
vec4 trace_screen_space_reflections(
	vec3 v_pos, vec3 v_normal, mat4 proj, mat4 inv_proj,
	sampler2D s_tex, sampler2D d_tex,
	int max_steps, float max_dist, float thickness, float edge_fade_width
) {
	vec3 v_dir = normalize(v_pos);
	vec3 r_dir = reflect(v_dir, v_normal);

	if (r_dir.z > 0.85) {
		return vec4(0.0);
	}

	float step_len = max_dist / float(max_steps);
	vec3 ray_p = v_pos + r_dir * (step_len * 0.6);

	for (int i = 0; i < max_steps; i++) {
		vec4 clip = proj * vec4(ray_p, 1.0);
		if (clip.w <= 0.001) break;

		vec3 ndc = clip.xyz / clip.w;
		vec2 suv = ndc.xy * 0.5 + 0.5;

		if (suv.x < 0.001 || suv.x > 0.999 || suv.y < 0.001 || suv.y > 0.999) {
			break;
		}

		float raw_d = textureLod(d_tex, suv, 0.0).r;
		vec4 s_ndc = vec4(suv * 2.0 - 1.0, raw_d, 1.0);
		vec4 s_view = inv_proj * s_ndc;
		float scene_z = s_view.z / s_view.w;

		float z_diff = ray_p.z - scene_z;
		if (z_diff < -0.35 && z_diff > -thickness) {
			vec2 border = min(suv, 1.0 - suv);
			float edge_mask = smoothstep(0.0, edge_fade_width, min(border.x, border.y));
			float dist_mask = 1.0 - (float(i) / float(max_steps));
			float confidence = edge_mask * dist_mask;

			vec3 refl_rgb = textureLod(s_tex, suv, 0.0).rgb;
			return vec4(refl_rgb, confidence);
		}

		ray_p += r_dir * step_len;
	}

	return vec4(0.0);
}

void fragment() {
	// Equirectangular water mask check
	vec3 loc_n = normalize(v_local_normal);
	float lat = asin(clamp(loc_n.y, -1.0, 1.0));
	float v_mask = 0.5 - lat / 3.141592653589793;
	float lon = atan(loc_n.x, loc_n.z);
	float u_mask = fract(lon / (2.0 * 3.141592653589793) + 0.5);
	float mask_val = textureLod(water_mask, vec2(u_mask, v_mask), 0.0).r;

	if (mask_val < 0.02) {
		discard;
	}

	// Reconstruct terrain depth from scene depth texture
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 up_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float terrain_depth = -up_pos.z / up_pos.w;
	float water_surface_depth = -VERTEX.z;
	float water_depth = max(0.0, terrain_depth - water_surface_depth);

	// Shoreline clipping: only discard on dry land where terrain is above sea level, never in open water
	if (water_depth <= 0.001 && mask_val < 0.15) {
		discard;
	}

	// In deep open ocean, water is fully absorbed and opaque
	float open_ocean_factor = smoothstep(0.1, 0.45, mask_val);
	float depth_ratio = clamp(water_depth / depth_distance, 0.0, 1.0);
	float absorption = mix(1.0 - exp(-depth_ratio * 3.0), 1.0, open_ocean_factor);
	vec4 base_water = mix(shallow_color, deep_color, absorption);

	// Accurate camera distances
	vec3 cam_pos_world = (length(camera_pos) > 0.001) ? camera_pos : CAMERA_POSITION_WORLD;
	float cam_dist = length(v_world_pos - cam_pos_world);
	float cam_alt = max(0.0, length(cam_pos_world - planet_center) - (planet_radius + ocean_altitude));

	// Evaluate 3D Spherical Gerstner wave spectrum
	float crest_sharpness = 0.0;
	float wave_height = 0.0;
	vec3 wave_normal_local = evaluate_ocean_spectrum(v_local_pos, loc_n, TIME, cam_dist, wave_amplitude, crest_sharpness, wave_height);
	vec3 wave_normal_world = normalize((MODEL_MATRIX * vec4(wave_normal_local, 0.0)).xyz);
	vec3 wave_normal_view = normalize((VIEW_MATRIX * vec4(wave_normal_world, 0.0)).xyz);

	// Sun visibility
	vec3 sun_norm = -normalize(sun_dir);
	float sun_dot = dot(v_world_normal, sun_norm);
	float sun_vis = smoothstep(-0.08, 0.08, sun_dot);

	// Dynamic Cloud Shadow on Ocean
	float shadow_factor = 0.0;
	if (cloud_enabled && cloud_density > 0.005 && sun_dot > -0.12) {
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

				vec2 uv_c = vec2(u_c, v_c);
				vec2 pen = vec2(0.0014, 0.0028);
				float c_raw = sample_cloud_raw_ocean(uv_c, 2.4) * 0.24;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2( pen.x, 0.0), 2.4) * 0.12;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2(-pen.x, 0.0), 2.4) * 0.12;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2(0.0,  pen.y), 2.4) * 0.12;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2(0.0, -pen.y), 2.4) * 0.12;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2( pen.x,  pen.y) * 0.707, 2.4) * 0.07;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2(-pen.x,  pen.y) * 0.707, 2.4) * 0.07;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2( pen.x, -pen.y) * 0.707, 2.4) * 0.07;
				c_raw += sample_cloud_raw_ocean(uv_c + vec2(-pen.x, -pen.y) * 0.707, 2.4) * 0.07;

				// Polar Singularity Blending
				float abs_y_c = abs(n_cloud.y);
				if (abs_y_c > 0.82) {
					float pole_f = smoothstep(0.82, 0.96, abs_y_c);
					float rot_a = -planet_rotation + TIME * cloud_speed * 6.28318530718;
					float cr = cos(rot_a);
					float sr = sin(rot_a);
					vec2 pxz = vec2(n_cloud.x * cr - n_cloud.z * sr, n_cloud.x * sr + n_cloud.z * cr);
					vec2 p_uv = pxz * 0.5 + 0.5;
					float c_pole = sample_cloud_raw_ocean(p_uv, 2.4);
					c_raw = mix(c_raw, c_pole, pole_f);
				}

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
					float eff_coverage = clamp(cloud_coverage * mix(1.0, cov, cloud_map_density) * edge_feather, 0.0, 1.0);
					float base_cloud = eff_coverage;
					float edge_factor = 1.0 - smoothstep(0.02, 0.65, cov);

					if (noise_l1_enabled && noise_l1_strength > 0.001) {
						float s1 = min(noise_l1_scale, 700.0) / NOISE_DOMAIN;
						vec3 uvw1 = v_c_rot * s1;
						float n_a = get_noise_ch(textureLod(noise_texture_3d, uvw1, 0.0), noise_l1_channel);
						float n_b = get_noise_ch(textureLod(noise_texture_3d, uvw1 + vec3(0.018, 0.0, 0.018), 0.0), noise_l1_channel);
						float n_c = get_noise_ch(textureLod(noise_texture_3d, uvw1 - vec3(0.018, 0.0, 0.018), 0.0), noise_l1_channel);
						float macro1 = (n_a * 0.5 + n_b * 0.25 + n_c * 0.25);
						float l1_inf = mix(1.0, edge_factor, clamp(noise_l1_edge_only, 0.0, 1.0));
						float erode1 = (1.0 - macro1) * clamp(noise_l1_strength, 0.0, 1.0) * l1_inf * 0.50;
						base_cloud = clamp((base_cloud - erode1) / max(0.05, 1.0 - erode1), 0.0, 1.0);
					}
					if (noise_l2_enabled && noise_l2_strength > 0.001 && base_cloud > 0.001) {
						float s2 = min(noise_l2_scale, 900.0) / NOISE_DOMAIN;
						vec3 uvw2 = v_c_rot * s2;
						float n2_a = get_noise_ch(textureLod(noise_texture_3d, uvw2, 0.0), noise_l2_channel);
						float n2_b = get_noise_ch(textureLod(noise_texture_3d, uvw2 + vec3(0.022, 0.0, -0.022), 0.0), noise_l2_channel);
						float meso2 = 0.5 * (n2_a + n2_b);
						float l2_inf = mix(1.0, edge_factor, clamp(noise_l2_edge_only, 0.0, 1.0));
						float erode2 = (1.0 - meso2) * clamp(noise_l2_strength, 0.0, 1.0) * l2_inf * 0.30;
						base_cloud = clamp((base_cloud - erode2) / max(0.05, 1.0 - erode2), 0.0, 1.0);
					}

					float soft_shadow = smoothstep(0.0, 0.72, base_cloud);
					float dens_boost = clamp(cloud_density * 3.2, 0.25, 1.0);
					float sun_facing = clamp(sun_dot * 4.0, 0.0, 1.0);
					shadow_factor = soft_shadow * dens_boost * sun_facing;
				}
			}
		}
	}

	// =========================================================================
	// SCATTERER FOAM & WHITECAPS (Distance-Faded: Exactly 0.0 from space/orbit)
	// =========================================================================
	float foam_altitude_fade = clamp(1.0 - (cam_alt - 1.5) / 10.0, 0.0, 1.0);
	float foam_dist_fade     = clamp(1.0 - (cam_dist - 4.0) / 25.0, 0.0, 1.0);
	float foam_visibility    = foam_altitude_fade * foam_dist_fade;

	float final_foam = 0.0;
	if (foam_visibility > 0.001 && foam_intensity > 0.001) {
		// Breaking wave whitecaps (based on wave steepness exceeding threshold)
		float w_thresh = min(whitecap_threshold, crest_foam_threshold);
		float whitecap_val = smoothstep(w_thresh, 1.0, crest_sharpness);

		// Shoreline breaking surf (strictly restricted to coastal land contacts, never in open ocean)
		float is_shore = smoothstep(0.35, 0.05, mask_val);
		float shore_ratio = clamp(1.0 - water_depth / max(0.05, shore_foam_distance), 0.0, 1.0);
		float surf_wave = sin(water_depth * 18.0 - TIME * wave_speed * 3.5);
		float shore_surf = pow(shore_ratio, 1.5) * smoothstep(-0.25, 0.50, surf_wave) * is_shore;

		// 3D Organic seafoam lace texture
		vec3 f_p = v_local_pos * 35.0;
		float fn1 = sin(f_p.x + cos(f_p.z * 1.5) + TIME * 0.8) * cos(f_p.y + sin(f_p.x * 1.5) - TIME * 0.6);
		float foam_lace = smoothstep(0.1, 0.65, fn1 * 0.5 + 0.5);

		float foam_mask = clamp(whitecap_val * 1.3 + shore_surf * 1.5, 0.0, 1.0);
		final_foam = smoothstep(0.20, 0.75, foam_mask * (0.35 + 0.65 * foam_lace)) * foam_visibility * foam_intensity;
	}

	// =========================================================================
	// FRESNEL, REALTIME SSR, AND SUN GLINT (Scatterer Ocean Specular)
	// =========================================================================
	float cos_view = clamp(dot(wave_normal_view, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - cos_view, 5.0);
	float eff_fresnel = 0.02 + 0.98 * fresnel;

	// 3D Relief Shading: gentle chiaroscuro slope contrast
	float sun_wave_dot = dot(wave_normal_world, sun_norm);
	float slope_diff = sun_wave_dot - sun_dot;
	float crest_highlight = clamp(slope_diff * 1.5, 0.0, 1.0);
	float trough_shadow = clamp(-slope_diff * 1.2, 0.0, 0.75);

	// Ambient sky dome relief across wave slopes
	float sky_dome_relief = clamp(dot(wave_normal_world, v_world_normal) * 0.5 + 0.5, 0.0, 1.0);
	float wave_ambient = mix(0.75, 1.20, sky_dome_relief);

	// Modulate base water with 3D wave relief
	vec3 lit_water = base_water.rgb * wave_ambient * (1.0 + 0.35 * crest_highlight - 0.25 * trough_shadow);

	// Subsurface Scattering (Turquoise glow through wave crests facing sun)
	vec3 sun_view = normalize((VIEW_MATRIX * vec4(sun_norm, 0.0)).xyz);
	float sss_factor = pow(clamp(dot(VIEW, -(sun_view + wave_normal_view * 0.35)), 0.0, 1.0), 3.0);
	vec3 sss_glow = vec3(0.02, 0.35, 0.30) * sss_factor * sun_vis * (0.5 + 1.0 * crest_highlight);

	// Deep oceanic ambient & Scatterer sky reflection
	vec3 sky_refl = mix(vec3(0.02, 0.08, 0.22), vec3(0.25, 0.45, 0.75), fresnel) * sun_vis;
	vec3 ocean_surface = (lit_water + sss_glow) * sun_vis;

	// Realtime Screen Space Reflections
	if (ssr_enabled && cam_alt < 20.0) {
		vec4 ssr_hit = trace_screen_space_reflections(
			VERTEX, wave_normal_view, PROJECTION_MATRIX, INV_PROJECTION_MATRIX,
			screen_texture, depth_texture,
			ssr_max_steps, ssr_max_distance, ssr_thickness, ssr_edge_fade
		);
		if (ssr_hit.a > 0.001) {
			vec3 refl_mix = mix(sky_refl, ssr_hit.rgb, ssr_hit.a);
			ocean_surface = mix(ocean_surface, refl_mix, eff_fresnel * (1.0 - final_foam * 0.85) * sun_vis);
		} else {
			ocean_surface += sky_refl * (eff_fresnel * (1.0 - final_foam * 0.85));
		}
	} else {
		ocean_surface += sky_refl * (eff_fresnel * (1.0 - final_foam * 0.85));
	}

	// Scatterer Sun Glint Sparkle (microfacet glitter trail along wave slopes)
	vec3 half_v = normalize(sun_view + VIEW);
	float n_dot_h = clamp(dot(wave_normal_view, half_v), 0.0, 1.0);
	float glint_roughness = mix(0.10, 0.25, clamp(cam_dist / 300.0, 0.0, 1.0));
	float crest_sparkle = pow(n_dot_h, 60.0) * (0.4 + 0.6 * crest_highlight) * sun_vis * (1.0 - shadow_factor * cloud_shadow_intensity);
	ocean_surface += vec3(1.0, 0.98, 0.92) * (crest_sparkle * 0.5 * clamp(wave_amplitude, 0.1, 2.0));

	// Cloud shadow darkening
	vec3 shadow_tint = cloud_shadow_color.rgb * 0.65;
	ocean_surface *= mix(vec3(1.0), shadow_tint, shadow_factor * cloud_shadow_intensity);

	// Blend seafoam onto ocean surface
	if (final_foam > 0.001) {
		ocean_surface = mix(ocean_surface, foam_color.rgb, final_foam * foam_color.a * sun_vis);
	}

	// Soft shoreline feathering along coastal boundary
	float coast_edge = smoothstep(0.02, 0.25, mask_val);
	float depth_edge = clamp(water_depth / 0.4, 0.0, 1.0);
	float shore_alpha = mix(coast_edge * depth_edge, 1.0, open_ocean_factor);

	float water_alpha = mix(base_water.a, 1.0, open_ocean_factor);

	ALBEDO = ocean_surface;
	ALPHA = clamp((water_alpha * (0.04 + 0.96 * sun_vis) + fresnel * 0.25 + final_foam * 0.6) * shore_alpha, 0.0, 1.0);
	ROUGHNESS = mix(glint_roughness, 0.85, final_foam);
	SPECULAR = mix(0.55 * sun_vis * mix(1.0, 0.05, shadow_factor * cloud_shadow_intensity), 0.15, final_foam);
	METALLIC = 0.0;
	NORMAL = wave_normal_view;
}