shader_type spatial;
render_mode blend_mix, cull_front, unshaded, depth_test_disabled, depth_draw_never;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_radius = 600.0;
uniform float atmo_radius = 636.0;
uniform vec3 camera_pos = vec3(0.0);

// Atmospheric Rayleigh, Mie, and Ozone Scattering/Absorption
uniform vec3 rayleigh_coeff = vec3(0.0035, 0.0085, 0.021);
uniform float scale_height_r = 48.0;

uniform float mie_coeff = 0.002;
uniform float scale_height_m = 7.2;
uniform float mie_g = 0.76;

// Ozone Chappuis Absorption (absorbs yellow-orange, preserves twilight blue & crimson sunsets)
uniform vec3 ozone_coeff = vec3(0.00065, 0.00188, 0.000085);

uniform float sun_intensity = 2.0;

// Unified Atmospheric Volumetric Clouds
uniform bool cloud_enabled = true;
uniform bool invert_clouds = false;
uniform sampler2D cloud_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float cloud_altitude = 2.0;
uniform float cloud_thickness = 3.5;
uniform float cloud_density = 0.8;
uniform float cloud_coverage = 0.65;
uniform float cloud_speed = 0.001;
uniform float planet_rotation = 0.0;
uniform float cloud_noise_speed = 0.0001;
uniform float cloud_noise_follow = 0.8;
uniform float cloud_day_brightness = 2.0;
uniform float cloud_night_brightness = 0.0;
uniform float cloud_map_height = 0.8;
uniform float cloud_map_density = 1.0;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.15, 0.2, 0.3, 1.0);
uniform float cloud_edge_noise = 0.85;
uniform float cloud_self_shadow_intensity = 1.0;
uniform float cloud_terminator_depth = 1.0;
uniform float cloud_terminator_softness = 0.16;
uniform float cloud_sunset_tint = 0.0;
uniform float cloud_terminator_offset = 0.0;
uniform float cloud_opacity = 1.5;
uniform float cloud_dither = 0.5;
uniform float cloud_shadow_intensity = 0.85;

// Multi-layer stackable 3D procedural noise
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
uniform float noise_detail_strength = 0.25;

uniform float cloud_noise_amount = 0.8;
uniform float godray_intensity = 1.0;

// Performance Optimizations
uniform sampler3D noise_texture_3d : repeat_enable, filter_linear;
uniform sampler2D transmittance_lut : hint_default_black, filter_linear, repeat_disable;
uniform int cloud_samples = 24;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Analytical ray-sphere intersection
vec2 ray_sphere(vec3 ro, vec3 rd, vec3 center, float r) {
	vec3 oc = center - ro;
	float t_closest = dot(oc, rd);
	vec3 p_closest = ro + rd * t_closest;
	float d2 = dot(center - p_closest, center - p_closest);
	float r2 = r * r;
	if (d2 > r2) return vec2(-1.0);
	float half_chord = sqrt(max(0.0, r2 - d2));
	float t_near = t_closest - half_chord;
	float t_far = t_closest + half_chord;
	if (t_far < 0.0) return vec2(-1.0);
	return vec2(t_near, t_far);
}

// Dedicated Analytical Cloud Deck Shell Intersection [t_entry, t_exit]
bool get_cloud_ray_bounds(
	vec3 ro, vec3 rd, vec3 center,
	float r_bot, float r_top, float t_max,
	out float t_entry, out float t_exit
) {
	vec2 hit_top = ray_sphere(ro, rd, center, r_top);
	if (hit_top.y <= 0.0) return false;

	vec2 hit_bot = ray_sphere(ro, rd, center, r_bot);
	float cam_dist = length(ro - center);

	if (cam_dist >= r_top) {
		t_entry = max(0.0, hit_top.x);
		t_exit = (hit_bot.x > 0.0) ? hit_bot.x : hit_top.y;
	} else if (cam_dist <= r_bot) {
		if (hit_bot.y <= 0.0) return false;
		t_entry = max(0.0, hit_bot.y);
		t_exit = hit_top.y;
	} else {
		// Camera is inside the cloud slab
		t_entry = 0.0;
		t_exit = (hit_bot.x > 0.0) ? hit_bot.x : hit_top.y;
	}

	t_entry = min(t_entry, t_max);
	t_exit = min(t_exit, t_max);

	return (t_exit > t_entry + 0.005);
}

// Single-lobe Henyey-Greenstein phase function
float henyey_greenstein(float cos_th, float g) {
	float g2 = g * g;
	return (1.0 - g2) / (4.0 * 3.141592653589793 * pow(max(1e-4, 1.0 + g2 - 2.0 * g * cos_th), 1.5));
}

// Dual-lobe Henyey-Greenstein Cloud Phase Function (Silver lining forward + glory backward)
float dual_hg_cloud_phase(float cos_th) {
	const float g_forward = 0.80;
	const float g_backward = -0.22;
	const float k = 0.78;
	float hg_f = henyey_greenstein(cos_th, g_forward);
	float hg_b = henyey_greenstein(cos_th, g_backward);
	float phase = mix(hg_b, hg_f, k) * (4.0 * 3.141592653589793);
	return clamp(phase, 0.15, 3.8);
}

// Atmospheric in-scattering & extinction with Rayleigh, Mie, and Ozone (Chappuis) absorption
void calc_atmo_sample(
	vec3 p, vec3 sun_norm, float atmo_thickness, float hr, float hm,
	vec3 beta_r, float beta_m, vec3 beta_o, float p_rayleigh, float p_mie,
	float cloud_sun_trans,
	out vec3 step_scat, out vec3 step_ext
) {
	vec3 v_cp = p - planet_center;
	float dist_cp = length(v_cp);
	float h = max(0.0, dist_cp - planet_radius);
	float alt_ratio = clamp(h / atmo_thickness, 0.0, 1.0);
	float edge_fade = (1.0 - alt_ratio) * (1.0 - alt_ratio);

	float d_r = exp(-h / hr) * edge_fade;
	float d_m = exp(-h / hm) * edge_fade;

	// Stratospheric Ozone layer (peaks around 45% of atmospheric thickness, absorbs yellow/orange/green)
	float h_o_center = atmo_thickness * 0.45;
	float h_o_width = max(1.0, atmo_thickness * 0.22);
	float d_o = max(0.0, 1.0 - abs(h - h_o_center) / h_o_width) * edge_fade;

	vec3 norm_cp = v_cp / dist_cp;
	float sun_dot = dot(sun_norm, norm_cp);
	float sun_vis = smoothstep(-0.12, 0.12, sun_dot);

	vec3 atten = vec3(0.0);
	if (sun_vis > 0.001) {
		vec2 lut_uv = vec2(clamp(sun_dot * 0.5 + 0.5, 0.01, 0.99), clamp(alt_ratio, 0.01, 0.96));
		vec3 lut_sample = textureLod(transmittance_lut, lut_uv, 0.0).rgb;
		if (max(lut_sample.r, max(lut_sample.g, lut_sample.b)) > 0.01) {
			atten = lut_sample * sun_vis;
		} else {
			// Analytical Chapman approximation fallback when LUT is uninitialized or clamped
			float ch_opt = exp(-h / hr) * (1.0 / max(0.05, sun_dot + 0.15));
			atten = exp(-(beta_r * ch_opt * hr + vec3(beta_m * ch_opt * hm))) * sun_vis;
		}
	}

	float g_intensity = clamp(godray_intensity, 0.0, 3.0);
	float ambient_sky = mix(0.25, 0.03, clamp(g_intensity, 0.0, 1.0));
	float eff_trans = mix(1.0, clamp(cloud_sun_trans, 0.0, 1.0), clamp(g_intensity, 0.0, 1.0));
	float beam_boost = mix(1.0, 1.0 + (g_intensity - 1.0) * 0.8, clamp(g_intensity - 1.0, 0.0, 2.0));
	float direct_sun_frac = mix(mix(1.0, ambient_sky, clamp(g_intensity, 0.0, 1.0)), beam_boost, eff_trans);

	vec3 scat_r = d_r * beta_r * p_rayleigh * atten * (sun_intensity * direct_sun_frac);
	vec3 scat_m = d_m * vec3(beta_m) * p_mie * atten * (sun_intensity * direct_sun_frac);
	step_scat = scat_r + scat_m;
	step_ext = beta_r * d_r + vec3(beta_m) * d_m + beta_o * d_o;
}

// Schneider / Clay John volumetric cloud shaping functions
float remap(float value, float originalMin, float originalMax, float newMin, float newMax) {
	return newMin + (((value - originalMin) / max(1e-5, originalMax - originalMin)) * (newMax - newMin));
}

vec4 mixGradients(float cloudType) {
	const vec4 STRATUS_GRADIENT = vec4(0.00, 0.05, 0.45, 0.75);
	const vec4 STRATOCUMULUS_GRADIENT = vec4(0.00, 0.06, 0.60, 0.88);
	const vec4 CUMULUS_GRADIENT = vec4(0.00, 0.07, 0.75, 0.98);
	float stratus = 1.0 - clamp(cloudType * 2.0, 0.0, 1.0);
	float stratocumulus = 1.0 - abs(cloudType - 0.5) * 2.0;
	float cumulus = clamp(cloudType - 0.5, 0.0, 1.0) * 2.0;
	return STRATUS_GRADIENT * stratus + STRATOCUMULUS_GRADIENT * stratocumulus + CUMULUS_GRADIENT * cumulus;
}

float densityHeightGradient(float heightFrac, float cloudType) {
	vec4 cloudGradient = mixGradients(cloudType);
	return smoothstep(cloudGradient.x, cloudGradient.y, heightFrac) - smoothstep(cloudGradient.z, cloudGradient.w, heightFrac);
}

float get_noise_ch(vec4 n, int ch) {
	float v = n.r;
	if (ch == 1) v = n.g;
	else if (ch == 2) v = n.b;
	else if (ch == 3) v = n.a;
	float norm_v = clamp((v - 0.24) / 0.52, 0.0, 1.0);
	return smoothstep(0.0, 1.0, norm_v);
}

// 3D Procedural Cloud Density Evaluation with Polar-Singularity Correction & Optimization
float sample_cloud_density_at(
	vec3 p, vec3 v_c, float dist_c, float r_c_bot, float r_c_top,
	float cos_nr, float sin_nr, vec3 cam_pos, bool is_shadow_ray
) {
	if (dist_c < r_c_bot || dist_c > r_c_top) {
		return 0.0;
	}

	vec3 norm_c = v_c / dist_c;

	// Spherical Equirectangular Coordinates
	float lat = asin(clamp(norm_c.y, -1.0, 1.0));
	float v_uv = 0.5 - lat / 3.141592653589793;
	float lon = atan(norm_c.x, norm_c.z) - planet_rotation;
	float u_uv = fract(lon / (2.0 * 3.141592653589793) + 0.5 + TIME * cloud_speed);

	vec4 c_tex = textureLod(cloud_texture, vec2(u_uv, v_uv), 0.0);

	// Polar Singularity Blending: Smoothly blend with planar polar mapping near poles (|y| > 0.82)
	float abs_y = abs(norm_c.y);
	if (abs_y > 0.82) {
		float pole_factor = smoothstep(0.82, 0.96, abs_y);
		float rot_angle = -planet_rotation + TIME * cloud_speed * 6.28318530718;
		float c_rot = cos(rot_angle);
		float s_rot = sin(rot_angle);
		vec2 planar_xz = vec2(norm_c.x * c_rot - norm_c.z * s_rot, norm_c.x * s_rot + norm_c.z * c_rot);
		vec2 pole_uv = planar_xz * 0.5 + 0.5;
		vec4 pole_tex = textureLod(cloud_texture, pole_uv, 0.0);
		c_tex = mix(c_tex, pole_tex, pole_factor);
	}

	float a_val = (c_tex.a < 0.999) ? c_tex.a : c_tex.r;
	float coverage = invert_clouds ? (1.0 - a_val) : a_val;
	if (coverage <= 0.005) {
		return 0.0;
	}

	float height_fraction = clamp((dist_c - r_c_bot) / max(0.01, cloud_thickness), 0.0, 1.0);

	// Cloud type: Wispy coverage edges are stratocumulus, dense cores are towering cumulus
	float cloud_type = clamp(mix(0.55, smoothstep(0.05, 0.65, coverage), cloud_map_height), 0.0, 1.0);
	float g = densityHeightGradient(height_fraction, cloud_type);
	if (g <= 0.001) {
		return 0.0;
	}

	// 3D Polar-rotated Coordinates
	vec3 v_c_rot = vec3(v_c.x * cos_nr + v_c.z * sin_nr, v_c.y, -v_c.x * sin_nr + v_c.z * cos_nr);
	const float NOISE_DOMAIN = 18000.0;

	// Weather coverage mapping
	float edge_ramp_width = mix(0.18, 0.55, clamp(cloud_edge_noise * 0.5, 0.0, 1.0));
	float edge_feather = smoothstep(0.005, edge_ramp_width, coverage);
	float base_accum = mix(1.25, 0.82, smoothstep(0.04, 0.55, height_fraction));
	float eff_coverage = clamp(cloud_coverage * mix(1.0, coverage, cloud_map_density) * edge_feather * base_accum, 0.0, 1.0);
	if (eff_coverage <= 0.005) {
		return 0.0;
	}

	float base_cloud = g * eff_coverage;

	// Distance-based texture MIP bias and LOD
	float cam_dist = length(p - cam_pos);
	float detail_lod = clamp(1.0 - (cam_dist - 6.0) / 45.0, 0.0, 1.0);
	float noise_mip = clamp(cam_dist * 0.02, 0.0, 2.5);

	float horiz_edge = 1.0 - smoothstep(0.02, 0.60, coverage);
	float top_margin = smoothstep(0.50, 0.94, height_fraction);
	float base_protect = smoothstep(0.0, 0.22, height_fraction);
	float erosion_height_scale = mix(0.10, 1.0, base_protect);

	float n_amt = clamp(cloud_noise_amount, 0.0, 2.0);
	float edge_boost = 1.0 + clamp(cloud_edge_noise, 0.0, 2.0) * 0.15 * max(horiz_edge, top_margin) * n_amt;

	// LAYER 1: Base / Macro Shape (carves large horizontal mounds, valleys, and varying cloud heights)
	if (n_amt > 0.001 && noise_l1_enabled && noise_l1_strength > 0.001) {
		vec3 uvw_1 = v_c_rot * (noise_l1_scale / NOISE_DOMAIN);
		vec4 n1 = textureLod(noise_texture_3d, uvw_1, noise_mip * 0.5);
		float ch_val1 = get_noise_ch(n1, noise_l1_channel);
		float fbm1 = get_noise_ch(n1, 1) * 0.625 + get_noise_ch(n1, 2) * 0.25 + get_noise_ch(n1, 3) * 0.125;
		float macro_val = mix(ch_val1, fbm1, 0.30);

		float l1_edge_factor = clamp(max(horiz_edge, top_margin), 0.0, 1.0);
		float l1_influence = mix(1.0, l1_edge_factor, clamp(noise_l1_edge_only, 0.0, 1.0));
		float l1_erode = clamp((1.0 - macro_val) * clamp(noise_l1_strength, 0.0, 1.0) * l1_influence * edge_boost * erosion_height_scale * 0.65 * n_amt, 0.0, 0.60);
		base_cloud = remap(base_cloud, l1_erode, 1.0, 0.0, 1.0);
		base_cloud = max(0.0, base_cloud);
	}

	if (base_cloud <= 0.0001) {
		return 0.0;
	}

	// Fast shadow ray exit: macro density suffices for volumetric light occluders
	if (is_shadow_ray) {
		float dens_s = pow(clamp(base_cloud, 0.0, 1.0), mix(0.55, 1.25, height_fraction));
		return dens_s * cloud_density * 2.5;
	}

	// Surface & perimeter mask for subsequent billow and cauliflower layers
	float surface_margin = 1.0 - smoothstep(0.08, 0.65, base_cloud);
	float edge_mask = clamp(max(max(horiz_edge, top_margin), surface_margin), 0.0, 1.0);

	// LAYER 2: Secondary / Meso Shaping (Bold Cumulus Billows)
	if (n_amt > 0.001 && noise_l2_enabled && noise_l2_strength > 0.001) {
		vec3 uvw_2 = v_c_rot * (noise_l2_scale / NOISE_DOMAIN);
		vec4 n2 = textureLod(noise_texture_3d, uvw_2, noise_mip);
		float ch_val2 = get_noise_ch(n2, noise_l2_channel);
		float l2_influence = mix(1.0, edge_mask, clamp(noise_l2_edge_only, 0.0, 1.0));
		float l2_erosion = clamp((1.0 - ch_val2) * clamp(noise_l2_strength, 0.0, 1.0) * l2_influence * edge_boost * erosion_height_scale * detail_lod * 0.55 * n_amt, 0.0, 0.55);
		base_cloud = remap(base_cloud, l2_erosion, 1.0, 0.0, 1.0);
		base_cloud = max(0.0, base_cloud);
	}

	// Only evaluate micro-detail layers (L3-L8) near cloud boundary and close to camera (skips solid cores)
	float detail_surface_mask = clamp(max(edge_mask, 1.0 - smoothstep(0.10, 0.75, base_cloud)), 0.0, 1.0);
	if (detail_lod > 0.02 && detail_surface_mask > 0.02 && base_cloud > 0.0001) {
		// LAYER 3: Cauliflower puffs
		if (n_amt > 0.001 && noise_l3_enabled && noise_l3_strength > 0.001) {
			vec3 uvw_3 = v_c_rot * (noise_l3_scale / NOISE_DOMAIN);
			vec4 n3 = textureLod(noise_texture_3d, uvw_3, noise_mip);
			float ch_val3 = get_noise_ch(n3, noise_l3_channel);
			float l3_influence = mix(detail_surface_mask, edge_mask, clamp(noise_l3_edge_only, 0.0, 1.0));
			float l3_erosion = clamp((1.0 - ch_val3) * clamp(noise_l3_strength, 0.0, 1.0) * l3_influence * detail_lod * 0.42 * n_amt, 0.0, 0.45);
			base_cloud = remap(base_cloud, l3_erosion, 1.0, 0.0, 1.0);
			base_cloud = max(0.0, base_cloud);
		}

		// LAYER 4: Wisps / Fine Fringe
		if (n_amt > 0.001 && noise_l4_enabled && noise_l4_strength > 0.001 && base_cloud > 0.0001) {
			vec3 uvw_4 = v_c_rot * (noise_l4_scale / NOISE_DOMAIN);
			vec4 n4 = textureLod(noise_texture_3d, uvw_4, noise_mip);
			float ch_val4 = get_noise_ch(n4, noise_l4_channel);
			float l4_influence = mix(detail_surface_mask, edge_mask, clamp(noise_l4_edge_only, 0.0, 1.0));
			float l4_erosion = clamp((1.0 - ch_val4) * clamp(noise_l4_strength, 0.0, 1.0) * l4_influence * detail_lod * 0.32 * n_amt, 0.0, 0.38);
			base_cloud = remap(base_cloud, l4_erosion, 1.0, 0.0, 1.0);
			base_cloud = max(0.0, base_cloud);
		}

		// LAYER 5: Additional Detail
		if (n_amt > 0.001 && noise_l5_enabled && noise_l5_strength > 0.001 && base_cloud > 0.0001) {
			vec3 uvw_5 = v_c_rot * (noise_l5_scale / NOISE_DOMAIN);
			vec4 n5 = textureLod(noise_texture_3d, uvw_5, noise_mip);
			float ch_val5 = get_noise_ch(n5, noise_l5_channel);
			float l5_influence = mix(detail_surface_mask, edge_mask, clamp(noise_l5_edge_only, 0.0, 1.0));
			float l5_erosion = clamp((1.0 - ch_val5) * clamp(noise_l5_strength, 0.0, 1.0) * l5_influence * detail_lod * 0.25 * n_amt, 0.0, 0.30);
			base_cloud = remap(base_cloud, l5_erosion, 1.0, 0.0, 1.0);
			base_cloud = max(0.0, base_cloud);
		}

		// LAYER 6: High-frequency Distortion
		if (n_amt > 0.001 && noise_l6_enabled && noise_l6_strength > 0.001 && base_cloud > 0.0001) {
			vec3 uvw_6 = v_c_rot * (noise_l6_scale / NOISE_DOMAIN);
			vec4 n6 = textureLod(noise_texture_3d, uvw_6, noise_mip);
			float ch_val6 = get_noise_ch(n6, noise_l6_channel);
			float l6_influence = mix(detail_surface_mask, edge_mask, clamp(noise_l6_edge_only, 0.0, 1.0));
			float l6_erosion = clamp((1.0 - ch_val6) * clamp(noise_l6_strength, 0.0, 1.0) * l6_influence * detail_lod * 0.20 * n_amt, 0.0, 0.28);
			base_cloud = remap(base_cloud, l6_erosion, 1.0, 0.0, 1.0);
			base_cloud = max(0.0, base_cloud);
		}

		// LAYER 7: Ultra-fine Whispers
		if (n_amt > 0.001 && noise_l7_enabled && noise_l7_strength > 0.001 && base_cloud > 0.0001) {
			vec3 uvw_7 = v_c_rot * (noise_l7_scale / NOISE_DOMAIN);
			vec4 n7 = textureLod(noise_texture_3d, uvw_7, noise_mip);
			float ch_val7 = get_noise_ch(n7, noise_l7_channel);
			float l7_influence = mix(detail_surface_mask, edge_mask, clamp(noise_l7_edge_only, 0.0, 1.0));
			float l7_erosion = clamp((1.0 - ch_val7) * clamp(noise_l7_strength, 0.0, 1.0) * l7_influence * detail_lod * 0.16 * n_amt, 0.0, 0.24);
			base_cloud = remap(base_cloud, l7_erosion, 1.0, 0.0, 1.0);
			base_cloud = max(0.0, base_cloud);
		}

		// LAYER 8: Micro Perimeter Fuzz
		if (n_amt > 0.001 && noise_l8_enabled && noise_l8_strength > 0.001 && base_cloud > 0.0001) {
			vec3 uvw_8 = v_c_rot * (noise_l8_scale / NOISE_DOMAIN);
			vec4 n8 = textureLod(noise_texture_3d, uvw_8, noise_mip);
			float ch_val8 = get_noise_ch(n8, noise_l8_channel);
			float l8_influence = mix(detail_surface_mask, edge_mask, clamp(noise_l8_edge_only, 0.0, 1.0));
			float l8_erosion = clamp((1.0 - ch_val8) * clamp(noise_l8_strength, 0.0, 1.0) * l8_influence * detail_lod * 0.12 * n_amt, 0.0, 0.20);
			base_cloud = remap(base_cloud, l8_erosion, 1.0, 0.0, 1.0);
			base_cloud = max(0.0, base_cloud);
		}
	}

	float edge_softness = smoothstep(0.0, 0.08, base_cloud);
	float dens = pow(clamp(base_cloud, 0.0, 1.0), mix(0.65, 1.15, height_fraction)) * edge_softness;
	return dens * cloud_density * 2.5;
}

// 4-Tap Progressive Shadow Ray with Exponential Spacing & Multiple Scattering
float calc_cloud_sun_penetration(
	vec3 p, vec3 sun_norm, float dens, float height_fraction,
	float r_c_bot, float r_c_top, float cos_nr, float sin_nr,
	vec3 cam_pos, float dt
) {
	if (cloud_self_shadow_intensity <= 0.001) {
		return 1.0;
	}

	vec2 hit_top = ray_sphere(p, sun_norm, planet_center, r_c_top);
	float t_to_space = clamp(hit_top.y, 0.0, cloud_thickness * 3.5);
	if (t_to_space <= 0.01) {
		return 1.0;
	}

	// 4 progressive taps exponentially spaced towards the sun
	float opt_sun = dens * (t_to_space * 0.15);
	const float TAP_WEIGHTS[4] = float[4](0.22, 0.28, 0.30, 0.20);
	const float TAP_OFFSETS[4] = float[4](0.10, 0.26, 0.54, 0.88);

	for (int i = 0; i < 4; i++) {
		float step_dist = t_to_space * TAP_OFFSETS[i];
		vec3 p_probe = p + sun_norm * step_dist;
		vec3 v_probe = p_probe - planet_center;
		float dist_probe = length(v_probe);
		float d_probe = sample_cloud_density_at(p_probe, v_probe, dist_probe, r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos, true);
		opt_sun += d_probe * (t_to_space * TAP_WEIGHTS[i]);
	}

	// Wrenninge / Ebert multiple scattering dual octaves (primary extinction + soft secondary forward lobe)
	float sigma_t = 0.75 * clamp(cloud_self_shadow_intensity, 0.0, 3.0);
	float T1 = exp(-opt_sun * sigma_t);
	float T2 = 0.50 * exp(-opt_sun * sigma_t * 0.25);
	return max(T1, T2);
}

// Volumetric Godray Occlusion: 2-tap fast march through cloud layer
float sample_3d_sun_transmission(
	vec3 p, vec3 sun_norm, float r_c_bot, float r_c_top,
	float cos_nr, float sin_nr, vec3 cam_pos
) {
	if (!cloud_enabled || cloud_density <= 0.005 || godray_intensity <= 0.01) {
		return 1.0;
	}

	vec3 v_cp = p - planet_center;
	float dist_cp = length(v_cp);
	if (dist_cp >= r_c_top) {
		return 1.0;
	}

	vec2 hit_top = ray_sphere(p, sun_norm, planet_center, r_c_top);
	if (hit_top.y <= 0.0) {
		return 1.0;
	}

	float t_entry = 0.0;
	if (dist_cp < r_c_bot) {
		vec2 hit_bot = ray_sphere(p, sun_norm, planet_center, r_c_bot);
		t_entry = (hit_bot.y > 0.0) ? hit_bot.y : 0.0;
	}

	float t_exit = hit_top.y;
	float l_sun = t_exit - t_entry;
	if (l_sun <= 0.005) {
		return 1.0;
	}

	l_sun = min(l_sun, cloud_thickness * 4.0);

	vec3 p1 = p + sun_norm * (t_entry + l_sun * 0.33);
	vec3 v1 = p1 - planet_center;
	float d1 = sample_cloud_density_at(p1, v1, length(v1), r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos, true);

	vec3 p2 = p + sun_norm * (t_entry + l_sun * 0.75);
	vec3 v2 = p2 - planet_center;
	float d2 = sample_cloud_density_at(p2, v2, length(v2), r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos, true);

	float opt = (d1 * 0.5 + d2 * 0.5) * l_sun;
	return exp(-opt * (0.85 * clamp(cloud_shadow_intensity, 0.0, 2.0)));
}

// Hoskins 3D spatial hash (isotropic, camera-tracked in world space, zero concentric rings)
float camera_track_dither(vec3 dir, vec3 pos) {
	vec3 p3 = fract(dir * 1847.193 + pos * 0.0371);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 cam_pos = (length(camera_pos) > 0.001) ? camera_pos : CAMERA_POSITION_WORLD;
	vec3 ray_dir = normalize(v_world_pos - cam_pos);
	vec3 sun_norm = -normalize(sun_dir);

	float atmo_thickness = max(atmo_radius - planet_radius, 1.0);
	float hr = clamp(scale_height_r, atmo_thickness * 0.15, atmo_thickness * 0.35);
	float hm = clamp(scale_height_m, atmo_thickness * 0.04, atmo_thickness * 0.12);

	// Wire Rayleigh & Mie coefficients directly from uniforms (auto-scale physical units if needed)
	vec3 beta_r = (rayleigh_coeff.b < 0.0005 && rayleigh_coeff.b > 0.0) ? (rayleigh_coeff * 1000.0) : rayleigh_coeff;
	float beta_m = (mie_coeff < 0.0005 && mie_coeff > 0.0) ? (mie_coeff * 100.0) : mie_coeff;
	vec3 beta_o = (ozone_coeff.g < 0.0001 && ozone_coeff.g > 0.0) ? (ozone_coeff * 1000.0) : ozone_coeff;

	vec2 atmo_hit = ray_sphere(cam_pos, ray_dir, planet_center, atmo_radius);
	if (atmo_hit.y <= 0.0) {
		discard;
	}

	float t_atmo_start = max(0.0, atmo_hit.x);
	float t_atmo_end = atmo_hit.y;

	// Clip raymarch at terrain/ocean surface from scene depth texture
	bool hit_surface = false;
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	if (raw_depth > 1e-6) {
		vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
		vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
		view_pos.xyz /= view_pos.w;
		float depth_dist = length(view_pos.xyz);
		vec3 surf_world = cam_pos + ray_dir * depth_dist;
		if (length(surf_world - planet_center) <= atmo_radius + 15.0) {
			t_atmo_end = min(t_atmo_end, depth_dist);
			hit_surface = true;
		}
	}

	// Fallback to mathematical planet sphere if depth texture was empty / missed
	if (!hit_surface) {
		vec2 planet_hit = ray_sphere(cam_pos, ray_dir, planet_center, planet_radius);
		if (planet_hit.x > 0.0) {
			t_atmo_end = min(t_atmo_end, planet_hit.x);
		}
	}

	// Clamp safe span: guarantees t_atmo_end >= t_atmo_start with ZERO DISCARD on the planet disk!
	t_atmo_end = max(t_atmo_start, t_atmo_end);

	// Phase functions
	float cos_theta = dot(ray_dir, sun_norm);
	float cos2 = cos_theta * cos_theta;
	float p_rayleigh = 0.75 * (1.0 + cos2);

	float g_mie = clamp(mie_g, 0.0, 0.99);
	float g2_mie = g_mie * g_mie;
	float p_mie = clamp((1.0 - g2_mie) / pow(max(0.01, 1.0 + g2_mie - 2.0 * g_mie * cos_theta), 1.5), 0.05, 8.0);

	// Dual-lobe Henyey-Greenstein Cloud Phase
	float p_cloud = dual_hg_cloud_phase(cos_theta);

	float rot_noise_angle = -planet_rotation + TIME * (cloud_speed * cloud_noise_follow + cloud_noise_speed) * 6.28318530718;
	float cos_nr = cos(rot_noise_angle);
	float sin_nr = sin(rot_noise_angle);

	float dither_val = (cloud_dither > 0.01) ? camera_track_dither(ray_dir, cam_pos) : 0.5;

	vec3 total_color = vec3(0.0);
	vec3 atmo_transmittance = vec3(1.0);

	// Cloud altitude band
	float r_c_bot = planet_radius + cloud_altitude;
	float r_c_top = r_c_bot + cloud_thickness;

	// Dedicated analytical intersection for the cloud deck
	float t_c_entry = 0.0;
	float t_c_exit = 0.0;
	bool has_cloud_seg = cloud_enabled && get_cloud_ray_bounds(cam_pos, ray_dir, planet_center, r_c_bot, r_c_top, t_atmo_end, t_c_entry, t_c_exit);

	if (t_atmo_end > t_atmo_start + 0.005) {
		if (has_cloud_seg) {
		// =========================================================================
		// SEGMENT 1: PRE-CLOUD ATMOSPHERE (Clear air between camera and cloud top)
		// =========================================================================
		if (t_c_entry > t_atmo_start + 0.05) {
			const int SAMPLES_PRE = 6;
			float dt_pre = (t_c_entry - t_atmo_start) / float(SAMPLES_PRE);
			for (int i = 0; i < SAMPLES_PRE; i++) {
				float t = t_atmo_start + dt_pre * (float(i) + dither_val);
				vec3 p = cam_pos + ray_dir * t;
				vec3 scat, ext;
				calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, 1.0, scat, ext);
				vec3 tr = exp(-ext * dt_pre);
				total_color += scat * dt_pre * atmo_transmittance;
				atmo_transmittance *= tr;
				if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) {
					break;
				}
			}
		}

		// =========================================================================
		// SEGMENT 2: DEDICATED CLOUD DECK (All cloud steps concentrated in cloud slab)
		// =========================================================================
		if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) >= 0.005) {
			int c_steps = clamp(cloud_samples, 8, 64);
			float cloud_span = t_c_exit - t_c_entry;
			float dt_c = cloud_span / float(c_steps);

			for (int s = 0; s < c_steps; s++) {
				if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) {
					break;
				}

				float t = t_c_entry + dt_c * (float(s) + dither_val);
				vec3 p = cam_pos + ray_dir * t;
				vec3 v_p = p - planet_center;
				float dist_p = length(v_p);

				float dens = sample_cloud_density_at(p, v_p, dist_p, r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos, false);

				vec3 atmo_scat, atmo_ext;

				if (dens > 0.002) {
					vec3 norm_p = v_p / dist_p;
					float height_fraction = clamp((dist_p - r_c_bot) / max(0.01, cloud_thickness), 0.0, 1.0);

					float sun_dot = dot(sun_norm, norm_p);
					float shifted_sun_dot = sun_dot + cloud_terminator_offset;
					float eff_sun_vis = smoothstep(-0.12, 0.12, shifted_sun_dot);
					float twilight = smoothstep(-0.15, 0.12, shifted_sun_dot);

					// Direct sun chromatic tint through atmosphere
					vec3 direct_sun_tint = vec3(1.0);
					if (cloud_sunset_tint > 0.001) {
						float h_c = max(0.0, dist_p - planet_radius);
						vec2 lut_uv = vec2(clamp(sun_dot * 0.5 + 0.5, 0.01, 0.99), clamp(h_c / atmo_thickness, 0.0, 1.0));
						vec3 atmo_trans = textureLod(transmittance_lut, lut_uv, 0.0).rgb;
						float grazing_factor = 1.0 - smoothstep(0.0, 0.35, max(0.0, sun_dot));
						float max_trans = max(atmo_trans.r, max(atmo_trans.g, atmo_trans.b));
						if (max_trans > 0.01) {
							vec3 norm_trans = atmo_trans / max(1e-4, max_trans);
							direct_sun_tint = mix(vec3(1.0), norm_trans, grazing_factor * clamp(cloud_sunset_tint, 0.0, 1.0));
						}
					}

					vec3 sun_light_in = direct_sun_tint * (eff_sun_vis * sun_intensity * cloud_day_brightness);

					// 4-Tap progressive shadow ray with multiple scattering
					float sun_penetration = 0.0;
					if (eff_sun_vis > 0.001) {
						sun_penetration = calc_cloud_sun_penetration(p, sun_norm, dens, height_fraction, r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos, dt_c);
					}

					// Billow ambient occlusion and edge powder fluffiness
					float billow_ao = clamp(0.35 + 0.65 * smoothstep(0.05, 0.70, height_fraction), 0.0, 1.0);
					float powder = 1.0 - exp(-dens * dt_c * 2.5);
					float powder_factor = mix(1.0, clamp(powder * 1.5, 0.25, 1.0), clamp(-cos_theta, 0.0, 1.0));

					vec3 direct_scat = cloud_color.rgb * p_cloud * sun_light_in * (sun_penetration * billow_ao * powder_factor);
					vec3 day_sky_ambient = cloud_shadow_color.rgb * (0.22 + 0.28 * height_fraction) * (sun_intensity * 0.45) * billow_ao;
					vec3 night_sky_ambient = cloud_shadow_color.rgb * (0.25 * cloud_night_brightness) * (sun_intensity * 0.45) * billow_ao;
					vec3 ambient_scat = mix(night_sky_ambient, day_sky_ambient, twilight);

					// Atmosphere in-scattering inside cloud volume
					calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, 1.0, atmo_scat, atmo_ext);

					float cloud_ext = dens * (0.85 * clamp(cloud_opacity, 0.2, 5.0));
					vec3 step_ext = atmo_ext + vec3(cloud_ext);
					vec3 step_trans = exp(-step_ext * dt_c);
					vec3 step_scat = (direct_scat + ambient_scat) * (1.0 - exp(-cloud_ext * dt_c)) + atmo_scat * dt_c;

					total_color += step_scat * atmo_transmittance;
					atmo_transmittance *= step_trans;

				} else {
					// Clear air gap inside cloud altitude band
					calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, 1.0, atmo_scat, atmo_ext);
					vec3 step_trans = exp(-atmo_ext * dt_c);
					total_color += atmo_scat * dt_c * atmo_transmittance;
					atmo_transmittance *= step_trans;
				}
			}
		}

		// =========================================================================
		// SEGMENT 3: POST-CLOUD ATMOSPHERE (Air behind/beneath clouds down to terrain)
		// =========================================================================
		if (t_atmo_end > t_c_exit + 0.05 && max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) > 0.005) {
			const int SAMPLES_POST = 6;
			float dt_post = (t_atmo_end - t_c_exit) / float(SAMPLES_POST);
			for (int i = 0; i < SAMPLES_POST; i++) {
				float t = t_c_exit + dt_post * (float(i) + dither_val);
				vec3 p = cam_pos + ray_dir * t;
				float air_shadow = 1.0;
				if (godray_intensity > 0.01) {
					air_shadow = sample_3d_sun_transmission(p, sun_norm, r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos);
				}
				vec3 scat, ext;
				calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, air_shadow, scat, ext);
				vec3 tr = exp(-ext * dt_post);
				total_color += scat * dt_post * atmo_transmittance;
				atmo_transmittance *= tr;
				if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) {
					break;
				}
			}
		}

	} else {
		// =========================================================================
		// STANDALONE ATMOSPHERE (Clear rays that miss the cloud deck)
		// =========================================================================
		const int SAMPLES_PURE = 16;
		float dt_pure = (t_atmo_end - t_atmo_start) / float(SAMPLES_PURE);
		for (int i = 0; i < SAMPLES_PURE; i++) {
			float t = t_atmo_start + dt_pure * (float(i) + dither_val);
			vec3 p = cam_pos + ray_dir * t;
			float dist_p = length(p - planet_center);
			float air_shadow = 1.0;
			if (cloud_enabled && godray_intensity > 0.01 && dist_p < r_c_top) {
				air_shadow = sample_3d_sun_transmission(p, sun_norm, r_c_bot, r_c_top, cos_nr, sin_nr, cam_pos);
			}
			vec3 scat, ext;
			calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, air_shadow, scat, ext);
			vec3 tr = exp(-ext * dt_pure);
			total_color += scat * dt_pure * atmo_transmittance;
			atmo_transmittance *= tr;
			if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) {
				break;
			}
		}
	}
}

	// Chromatic Extinction with Screen Texture Compositing
	vec3 bg_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 final_color = total_color + bg_color * atmo_transmittance;

	ALBEDO = final_color;
	ALPHA = 1.0;
}