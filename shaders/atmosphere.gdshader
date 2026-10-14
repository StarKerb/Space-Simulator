shader_type spatial;
render_mode blend_mix, cull_front, unshaded, depth_test_disabled, depth_draw_never;

// =============================================================================
// PLANETARY ATMOSPHERE & VOLUMETRIC CLOUDS SHADER
// Production-grade, scale-invariant atmospheric scattering and volumetric clouds.
// Designed for 1:1 astronomical scale (R = 6,371 km) with sub-millimeter precision.
// =============================================================================

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Celestial Geometries
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_radius = 6371000.0;
uniform float atmo_radius = 6471000.0;
uniform vec3 camera_pos = vec3(0.0);

// Atmospheric Rayleigh, Mie, and Ozone Scattering/Absorption
uniform vec3 rayleigh_coeff = vec3(5.8e-6, 1.35e-5, 3.31e-5);
uniform float scale_height_r = 8000.0;

uniform float mie_coeff = 4.0e-6;
uniform float scale_height_m = 1200.0;
uniform float mie_g = 0.76;

uniform vec3 ozone_coeff = vec3(6.5e-7, 1.88e-6, 8.5e-8);
uniform float sun_intensity = 1.3;

// Unified Atmospheric Volumetric Clouds
uniform bool cloud_enabled = true;
uniform bool invert_clouds = false;
uniform sampler2D cloud_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float cloud_altitude = 2500.0;
uniform float cloud_thickness = 3500.0;
uniform float cloud_density = 0.55;
uniform float cloud_coverage = 0.65;
uniform float cloud_speed = 0.0;
uniform float planet_rotation = 0.0;
uniform float cloud_noise_speed = 0.0;
uniform float cloud_noise_follow = 0.8;
uniform float cloud_day_brightness = 2.0;
uniform float cloud_night_brightness = 0.0;
uniform float cloud_map_height = 0.8;
uniform float cloud_map_density = 1.0;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.18, 0.22, 0.32, 1.0);
uniform float cloud_edge_noise = 0.85;
uniform float cloud_self_shadow_intensity = 1.0;
uniform float cloud_terminator_depth = 1.0;
uniform float cloud_terminator_softness = 0.16;
uniform float cloud_sunset_tint = 0.0;
uniform float cloud_terminator_offset = 0.0;
uniform float cloud_opacity = 1.5;
uniform float cloud_dither = 0.5;
uniform float cloud_shadow_intensity = 0.85;

// Multi-layer Stackable 3D Procedural Noise
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

// Legacy / Compatibility Uniforms
uniform float noise_base_scale = 160.0;
uniform float noise_base_strength = 0.35;
uniform float noise_detail_scale = 400.0;
uniform float noise_detail_strength = 0.25;
uniform float cloud_noise_amount = 0.8;
uniform float godray_intensity = 1.0;

uniform sampler3D noise_texture_3d : repeat_enable, filter_linear;
uniform sampler2D transmittance_lut : hint_default_black, filter_linear, repeat_disable;
uniform int cloud_samples = 28;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// =============================================================================
// MATHEMATICAL HELPER FUNCTIONS
// =============================================================================

// High-precision scale-invariant Ray-Sphere intersection
// Solves quadratic equation normalized by s = max(r, dist) to eliminate 32-bit mantissa cancellation.
vec2 ray_sphere(vec3 ro, vec3 rd, vec3 center, float r) {
	vec3 v = ro - center;
	float dist_cam = length(v);
	float s = max(max(r, dist_cam), 1.0);

	vec3 v_s = v / s;
	float r_s = r / s;

	float b = dot(v_s, rd);
	vec3 perp = v_s - rd * b;
	float d2 = dot(perp, perp);
	float r2 = r_s * r_s;

	if (d2 > r2) return vec2(-1.0);

	float half_chord = sqrt(max(0.0, r2 - d2));
	float t_near = (-b - half_chord) * s;
	float t_far  = (-b + half_chord) * s;

	if (t_far < 0.0) return vec2(-1.0);
	return vec2(t_near, t_far);
}

// Analytical intersection bounds for a spherical shell [r_bot, r_top]
bool get_cloud_ray_bounds(
	vec3 ro, vec3 rd, vec3 center,
	float r_bot, float r_top,
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
		// Inside shell
		t_entry = 0.0;
		t_exit = (hit_bot.x > 0.0) ? hit_bot.x : hit_top.y;
	}

	t_entry = max(0.0, t_entry);
	return t_exit > t_entry + 0.01;
}

// Screen-space deterministic triangular dither (0 jitter on camera motion/zoom)
float screen_dither(vec2 coord) {
	return fract(52.9829189 * fract(dot(coord, vec2(0.06711056, 0.00583715))));
}

// Henyey-Greenstein scattering phase function
float hg_phase(float g, float cos_th) {
	float g2 = g * g;
	return (1.0 - g2) / (4.0 * 3.14159265359 * pow(max(0.01, 1.0 + g2 - 2.0 * g * cos_th), 1.5));
}

// Dual-lobe Henyey-Greenstein phase for cloud droplets
float dual_hg_cloud_phase(float cos_th) {
	// 70% forward scattering (silver lining), 30% back-scattering (radiant diffuse)
	return 0.70 * hg_phase(0.80, cos_th) + 0.30 * hg_phase(-0.25, cos_th);
}

// Planet-local Y-axis rotation
vec3 rotate_y_local(vec3 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
}

float get_noise_channel(vec4 n, int ch) {
	if (ch == 0) return n.r;
	if (ch == 1) return n.g;
	if (ch == 2) return n.b;
	return n.a;
}

// =============================================================================
// VOLUMETRIC CLOUD DENSITY SAMPLING
// =============================================================================
float sample_cloud_density(
	vec3 p, vec3 p_local, float dist_p, float r_c_bot, float r_c_top, float atmo_h
) {
	if (dist_p < r_c_bot || dist_p > r_c_top) {
		return 0.0;
	}

	vec3 norm_local = p_local / dist_p;

	// Spherical Equirectangular coordinates in planet-locked local frame
	float lat = asin(clamp(norm_local.y, -1.0, 1.0));
	float v_uv = 0.5 - lat / 3.141592653589793;
	float lon = atan(norm_local.x, norm_local.z);
	float u_uv = fract(lon / (2.0 * 3.141592653589793) + 0.5);

	vec4 c_tex = textureLod(cloud_texture, vec2(u_uv, v_uv), 0.0);
	float raw_cov = (c_tex.a < 0.999) ? c_tex.a : c_tex.r;
	float map_cov = invert_clouds ? (1.0 - raw_cov) : raw_cov;

	// Respect clear skies: threshold out image compression background noise and sea haze
	float cloud_val = smoothstep(0.26, 0.70, map_cov);
	if (cloud_val <= 0.001) {
		return 0.0;
	}

	float eff_coverage = clamp(cloud_val * cloud_coverage, 0.0, 1.0);

	// Vertical cloud density profile (soft base, dense convective mid, wispy top)
	float h_frac = clamp((dist_p - r_c_bot) / max(1.0, cloud_thickness), 0.0, 1.0);
	float h_shape = smoothstep(0.0, 0.18, h_frac) * smoothstep(1.0, 0.65, h_frac);
	if (h_shape <= 0.001) {
		return 0.0;
	}

	float base_dens = eff_coverage * h_shape;

	// 3D Procedural Fractal Noise Carving
	if (cloud_noise_amount > 0.01) {
		float noise_domain = max(18000.0, planet_radius * 0.05);
		vec3 uvw = p_local * (noise_l1_scale / noise_domain);
		vec4 n1 = textureLod(noise_texture_3d, uvw, 0.0);
		float fbm = get_noise_channel(n1, noise_l1_channel);
		if (noise_l2_enabled) {
			vec3 uvw2 = p_local * (noise_l2_scale / noise_domain);
			vec4 n2 = textureLod(noise_texture_3d, uvw2, 0.0);
			fbm = mix(fbm, get_noise_channel(n2, noise_l2_channel), 0.35);
		}

		float erode = (1.0 - fbm) * (cloud_noise_amount * 0.55);
		base_dens = clamp((base_dens - erode) / max(0.01, 1.0 - erode), 0.0, 1.0);
	}

	return base_dens * cloud_density * cloud_opacity;
}

// =============================================================================
// ATMOSPHERIC SAMPLE EVALUATION (Rayleigh, Mie, Ozone)
// =============================================================================
void evaluate_atmosphere(
	vec3 p, vec3 sun_norm, float atmo_thickness,
	float hr, float hm, vec3 beta_r, float beta_m, vec3 beta_o,
	float p_rayleigh, float p_mie,
	out vec3 scat, out vec3 ext
) {
	vec3 v_cp = p - planet_center;
	float dist_cp = length(v_cp);
	float h = max(0.0, dist_cp - planet_radius);
	float alt_ratio = clamp(h / atmo_thickness, 0.0, 1.0);

	// SMOOTH ASYMPTOTIC ENVELOPE: Density tapers to EXACTLY 0.0 at the outer shell.
	// This completely eliminates the razor-sharp white boundary ring on zoom out!
	float edge_fade = smoothstep(1.0, 0.70, alt_ratio);

	float d_r = exp(-h / hr) * edge_fade;
	float d_m = exp(-h / hm) * edge_fade;

	// Stratospheric Ozone layer (peaks at ~40% of atmosphere)
	float h_o_center = atmo_thickness * 0.40;
	float h_o_width = max(1.0, atmo_thickness * 0.25);
	float d_o = max(0.0, 1.0 - abs(h - h_o_center) / h_o_width) * edge_fade;

	vec3 norm_cp = v_cp / dist_cp;
	float sun_dot = dot(sun_norm, norm_cp);
	float sun_vis = smoothstep(-0.08, 0.08, sun_dot);

	// Solar transmission through atmosphere (Chapman approximation)
	float ch_opt = exp(-h / hr) * (1.0 / max(0.04, sun_dot + 0.12));
	vec3 sun_trans = exp(-(beta_r * ch_opt * hr + vec3(beta_m * ch_opt * hm))) * sun_vis;

	vec3 scat_r = d_r * beta_r * p_rayleigh * sun_trans * sun_intensity;
	vec3 scat_m = d_m * vec3(beta_m) * p_mie * sun_trans * sun_intensity;

	scat = scat_r + scat_m;
	ext = beta_r * d_r + vec3(beta_m) * d_m + beta_o * d_o;
}

// =============================================================================
// MAIN FRAGMENT SHADER
// =============================================================================
void fragment() {
	vec3 cam_pos = CAMERA_POSITION_WORLD;
	vec3 ray_dir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	vec3 sun_norm = -normalize(sun_dir);

	float atmo_thickness = max(atmo_radius - planet_radius, 1.0);
	float hr = (scale_height_r > 0.0) ? scale_height_r : (atmo_thickness * 0.08);
	float hm = (scale_height_m > 0.0) ? scale_height_m : (atmo_thickness * 0.012);

	vec3 beta_r = rayleigh_coeff;
	float beta_m = mie_coeff;
	vec3 beta_o = ozone_coeff;

	// Scale-invariant intersection with atmosphere outer shell
	vec2 atmo_hit = ray_sphere(cam_pos, ray_dir, planet_center, atmo_radius);
	if (atmo_hit.y <= 0.0) {
		discard;
	}

	float t_atmo_start = max(0.0, atmo_hit.x);
	float t_atmo_end = atmo_hit.y;

	// Clip against scene depth buffer (spacecraft in orbit, terrain, ocean)
	bool hit_surface = false;
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	if (raw_depth > 1e-6) {
		vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
		vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
		view_pos.xyz /= view_pos.w;
		float depth_dist = length(view_pos.xyz);

		// If an opaque scene object (e.g. Apollo CSM) is closer than atmosphere entry:
		if (depth_dist <= t_atmo_start + 5.0) {
			discard;
		}

		// Clip raymarch against terrain or ocean surface:
		if (depth_dist < t_atmo_end) {
			t_atmo_end = depth_dist;
			hit_surface = true;
		}
	}

	// Fallback to mathematical planet sphere if depth buffer was clear
	if (!hit_surface) {
		vec2 planet_hit = ray_sphere(cam_pos, ray_dir, planet_center, planet_radius);
		if (planet_hit.x > t_atmo_start) {
			t_atmo_end = min(t_atmo_end, planet_hit.x);
		}
	}

	t_atmo_end = max(t_atmo_start, t_atmo_end);
	if (t_atmo_end <= t_atmo_start + 0.01) {
		discard;
	}

	// Scattering Phase Functions
	float cos_theta = dot(ray_dir, sun_norm);
	float cos2 = cos_theta * cos_theta;
	float p_rayleigh = 0.75 * (1.0 + cos2);

	float g_mie = clamp(mie_g, 0.0, 0.99);
	float g2_mie = g_mie * g_mie;
	float p_mie = clamp((1.0 - g2_mie) / pow(max(0.01, 1.0 + g2_mie - 2.0 * g_mie * cos_theta), 1.5), 0.05, 8.0);
	float p_cloud = dual_hg_cloud_phase(cos_theta);

	// Screen-space deterministic dither
	float dither_val = (cloud_dither > 0.01) ? screen_dither(FRAGCOORD.xy) : 0.5;

	// Cloud Deck Shell
	float r_c_bot = planet_radius + cloud_altitude;
	float r_c_top = r_c_bot + cloud_thickness;
	float t_c_entry = 0.0;
	float t_c_exit = 0.0;
	bool has_clouds = cloud_enabled && get_cloud_ray_bounds(cam_pos, ray_dir, planet_center, r_c_bot, r_c_top, t_c_entry, t_c_exit);

	vec3 total_color = vec3(0.0);
	vec3 atmo_transmittance = vec3(1.0);

	// Primary Raymarching Loop
	if (has_clouds) {
		// =====================================================================
		// 1. PRE-CLOUD ATMOSPHERE (Clear air between camera and cloud deck)
		// =====================================================================
		if (t_c_entry > t_atmo_start + 0.05) {
			const int STEPS_PRE = 5;
			float dt = (t_c_entry - t_atmo_start) / float(STEPS_PRE);
			for (int i = 0; i < STEPS_PRE; i++) {
				float t = t_atmo_start + dt * (float(i) + dither_val);
				vec3 p = cam_pos + ray_dir * t;
				vec3 scat, ext;
				evaluate_atmosphere(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, scat, ext);
				vec3 tr = exp(-ext * dt);
				vec3 slice_scat = scat * ((vec3(1.0) - tr) / max(vec3(1e-7), ext));
				total_color += slice_scat * atmo_transmittance;
				atmo_transmittance *= tr;
				if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) break;
			}
		}

		// =====================================================================
		// 2. VOLUMETRIC CLOUD DECK (Coupled cloud + atmospheric scattering)
		// =====================================================================
		int c_steps = clamp(cloud_samples, 12, 48);
		float dt_c = (t_c_exit - t_c_entry) / float(c_steps);
		float dt_norm = (dt_c / max(1.0, cloud_thickness)) * 3.5;

		for (int s = 0; s < c_steps; s++) {
			if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) break;

			float t = t_c_entry + dt_c * (float(s) + dither_val);
			vec3 p = cam_pos + ray_dir * t;
			vec3 v_cp = p - planet_center;
			float dist_cp = length(v_cp);

			// Transform point into planet-locked local rotating coordinate frame
			vec3 p_local = rotate_y_local(v_cp, -planet_rotation);

			float dens = sample_cloud_density(p, p_local, dist_cp, r_c_bot, r_c_top, atmo_thickness);

			// Atmospheric scattering at this step
			vec3 atmo_scat, atmo_ext;
			evaluate_atmosphere(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, atmo_scat, atmo_ext);

			if (dens > 0.001) {
				// Solar penetration through local cloud optical depth
				float sun_penetration = exp(-dens * 0.35);
				float h_frac = clamp((dist_cp - r_c_bot) / max(1.0, cloud_thickness), 0.0, 1.0);
				float billow_ao = clamp(0.35 + 0.65 * smoothstep(0.04, 0.70, h_frac), 0.0, 1.0);

				vec3 norm_cp = v_cp / dist_cp;
				float sun_dot = dot(norm_cp, sun_norm);
				float sun_vis = smoothstep(-0.06, 0.08, sun_dot);

				// Multiple-scattering floor albedo: guarantees bright, radiant white clouds
				float multi_scat = 0.55 * billow_ao;
				vec3 direct_scat = cloud_color.rgb * sun_intensity * (p_cloud * sun_penetration + multi_scat) * (cloud_day_brightness * billow_ao) * sun_vis;
				vec3 day_ambient = cloud_shadow_color.rgb * (0.25 * sun_intensity * billow_ao);
				vec3 night_ambient = cloud_shadow_color.rgb * (0.15 * cloud_night_brightness);
				vec3 ambient_scat = mix(night_ambient, day_ambient, sun_vis);

				float cloud_ext = dens * 0.85;
				float cloud_tau = cloud_ext * dt_norm;
				float cloud_tr = exp(-cloud_tau);
				vec3 atmo_tr = exp(-atmo_ext * dt_c);
				vec3 step_tr = atmo_tr * cloud_tr;

				vec3 cloud_slice = (direct_scat + ambient_scat) * (1.0 - cloud_tr);
				vec3 atmo_slice = atmo_scat * ((vec3(1.0) - atmo_tr) / max(vec3(1e-7), atmo_ext));

				total_color += (cloud_slice + atmo_slice) * atmo_transmittance;
				atmo_transmittance *= step_tr;
			} else {
				vec3 atmo_tr = exp(-atmo_ext * dt_c);
				vec3 atmo_slice = atmo_scat * ((vec3(1.0) - atmo_tr) / max(vec3(1e-7), atmo_ext));
				total_color += atmo_slice * atmo_transmittance;
				atmo_transmittance *= atmo_tr;
			}
		}

		// =====================================================================
		// 3. POST-CLOUD ATMOSPHERE (Air below clouds down to surface)
		// =====================================================================
		if (t_atmo_end > t_c_exit + 0.05 && max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) > 0.005) {
			const int STEPS_POST = 5;
			float dt = (t_atmo_end - t_c_exit) / float(STEPS_POST);
			for (int i = 0; i < STEPS_POST; i++) {
				float t = t_c_exit + dt * (float(i) + dither_val);
				vec3 p = cam_pos + ray_dir * t;
				vec3 scat, ext;
				evaluate_atmosphere(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, scat, ext);
				vec3 tr = exp(-ext * dt);
				vec3 slice_scat = scat * ((vec3(1.0) - tr) / max(vec3(1e-7), ext));
				total_color += slice_scat * atmo_transmittance;
				atmo_transmittance *= tr;
				if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) break;
			}
		}

	} else {
		// =====================================================================
		// STANDALONE ATMOSPHERE (Clear rays that miss the cloud deck)
		// =====================================================================
		const int STEPS_PURE = 16;
		float dt = (t_atmo_end - t_atmo_start) / float(STEPS_PURE);
		for (int i = 0; i < STEPS_PURE; i++) {
			float t = t_atmo_start + dt * (float(i) + dither_val);
			vec3 p = cam_pos + ray_dir * t;
			vec3 scat, ext;
			evaluate_atmosphere(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, beta_o, p_rayleigh, p_mie, scat, ext);
			vec3 tr = exp(-ext * dt);
			vec3 slice_scat = scat * ((vec3(1.0) - tr) / max(vec3(1e-7), ext));
			total_color += slice_scat * atmo_transmittance;
			atmo_transmittance *= tr;
			if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.005) break;
		}
	}

	// Chromatic Extinction with Screen Texture Compositing
	vec3 bg_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 final_color = total_color + bg_color * atmo_transmittance;

	ALBEDO = final_color;
	ALPHA = 1.0;
}