shader_type spatial;
render_mode blend_mix, cull_front, unshaded, depth_test_disabled, depth_draw_never;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_radius = 600.0;
uniform float atmo_radius = 636.0;

uniform vec3 rayleigh_coeff = vec3(5.5e-6, 13.0e-6, 22.4e-6);
uniform float scale_height_r = 48.0;

uniform float mie_coeff = 21.0e-6;
uniform float scale_height_m = 7.2;
uniform float mie_g = 0.76;

uniform float sun_intensity = 2.0;

// Unified Atmospheric Volumetric Clouds
uniform bool cloud_enabled = true;
uniform bool invert_clouds = false; // False by default: alpha = clouds, 0 = clear sky
uniform sampler2D cloud_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float cloud_altitude = 2.0;
uniform float cloud_thickness = 3.5;
uniform float cloud_density = 0.8;
uniform float cloud_coverage = 0.65;
uniform float cloud_speed = 0.001;
uniform float cloud_day_brightness = 2.0;
uniform float cloud_night_brightness = 0.0;
uniform float cloud_map_height = 0.8;
uniform float cloud_map_density = 1.0;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.15, 0.2, 0.3, 1.0);

// Multi-layer stackable 3D procedural noise
uniform float noise_base_scale = 160.0;
uniform float noise_base_strength = 0.28;
uniform float noise_detail_scale = 480.0;
uniform float noise_detail_strength = 0.15;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

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

// Procedural 3D Volumetric Fractal Noise for realistic billows and wisps
float hash3D(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float noise3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3D(i + vec3(0,0,0)), hash3D(i + vec3(1,0,0)), f.x),
			mix(hash3D(i + vec3(0,1,0)), hash3D(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3D(i + vec3(0,0,1)), hash3D(i + vec3(1,0,1)), f.x),
			mix(hash3D(i + vec3(0,1,1)), hash3D(i + vec3(1,1,1)), f.x), f.y),
		f.z
	);
}

float fbm3D(vec3 p) {
	return noise3D(p) * 0.55 + noise3D(p * 2.02) * 0.3 + noise3D(p * 4.05) * 0.15;
}

float detail_noise3D(vec3 p) {
	return noise3D(p) * 0.7 + noise3D(p * 2.05) * 0.3;
}

void calc_atmo_sample_full(
	vec3 p, vec3 sun_norm, float atmo_thickness, float hr, float hm,
	vec3 beta_r, float beta_m, float p_rayleigh, float p_mie,
	out vec3 step_scat, out vec3 step_ext_coeff, out vec3 atten
) {
	vec3 v_cp = p - planet_center;
	float dist_cp = length(v_cp);
	float h = max(0.0, dist_cp - planet_radius);
	float alt_ratio = clamp(h / atmo_thickness, 0.0, 1.0);
	float edge_fade = (1.0 - alt_ratio) * (1.0 - alt_ratio);

	float d_r = exp(-h / hr) * edge_fade;
	float d_m = exp(-h / hm) * edge_fade;

	vec3 norm_cp = v_cp / dist_cp;
	float sun_dot = dot(sun_norm, norm_cp);
	float sun_vis = smoothstep(-0.15, 0.15, sun_dot);

	atten = vec3(0.0);
	if (sun_vis > 0.001) {
		vec2 sun_atmo = ray_sphere(p, sun_norm, planet_center, atmo_radius);
		float dt_l = max(0.0, sun_atmo.y) / 3.0;
		float opt_l_r = 0.0;
		float opt_l_m = 0.0;

		for (int k = 0; k < 3; k++) {
			vec3 p_l = p + sun_norm * (dt_l * (float(k) + 0.5));
			float h_l = max(0.0, length(p_l - planet_center) - planet_radius);
			float l_ratio = clamp(h_l / atmo_thickness, 0.0, 1.0);
			float l_fade = (1.0 - l_ratio) * (1.0 - l_ratio);
			opt_l_r += exp(-h_l / hr) * l_fade * dt_l;
			opt_l_m += exp(-h_l / hm) * l_fade * dt_l;
		}

		vec3 tau = beta_r * opt_l_r + vec3(beta_m * 1.1) * opt_l_m;
		atten = exp(-tau) * sun_vis;
	}

	vec3 scat_r = d_r * beta_r * p_rayleigh * atten * sun_intensity;
	vec3 scat_m = d_m * vec3(beta_m) * p_mie * atten * sun_intensity;
	step_scat = scat_r + scat_m;
	step_ext_coeff = beta_r * d_r + vec3(beta_m) * d_m;
}

void calc_atmo_sample_fast(
	vec3 p, vec3 sun_norm, float atmo_thickness, float hr, float hm,
	vec3 beta_r, float beta_m, float p_rayleigh, float p_mie, vec3 atten,
	out vec3 step_scat, out vec3 step_ext_coeff
) {
	vec3 v_cp = p - planet_center;
	float dist_cp = length(v_cp);
	float h = max(0.0, dist_cp - planet_radius);
	float alt_ratio = clamp(h / atmo_thickness, 0.0, 1.0);
	float edge_fade = (1.0 - alt_ratio) * (1.0 - alt_ratio);

	float d_r = exp(-h / hr) * edge_fade;
	float d_m = exp(-h / hm) * edge_fade;

	vec3 scat_r = d_r * beta_r * p_rayleigh * atten * sun_intensity;
	vec3 scat_m = d_m * vec3(beta_m) * p_mie * atten * sun_intensity;
	step_scat = scat_r + scat_m;
	step_ext_coeff = beta_r * d_r + vec3(beta_m) * d_m;
}

void calc_atmo_sample(
	vec3 p, vec3 sun_norm, float atmo_thickness, float hr, float hm,
	vec3 beta_r, float beta_m, float p_rayleigh, float p_mie,
	out vec3 step_scat, out vec3 step_ext_coeff
) {
	vec3 atten_dummy;
	calc_atmo_sample_full(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, p_rayleigh, p_mie, step_scat, step_ext_coeff, atten_dummy);
}

void fragment() {
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	vec3 ray_dir = normalize(v_world_pos - cam_pos);
	vec3 sun_norm = -normalize(sun_dir);

	float atmo_thickness = max(atmo_radius - planet_radius, 1.0);
	float hr = clamp(scale_height_r, atmo_thickness * 0.15, atmo_thickness * 0.35);
	float hm = clamp(scale_height_m, atmo_thickness * 0.04, atmo_thickness * 0.12);

	vec3 beta_r = vec3(0.0035, 0.0085, 0.021);
	float beta_m = 0.002;

	vec2 atmo_hit = ray_sphere(cam_pos, ray_dir, planet_center, atmo_radius);
	if (atmo_hit.y <= 0.0) {
		discard;
	}

	float t_start = max(0.0, atmo_hit.x);
	float t_end = atmo_hit.y;

	vec2 planet_hit = ray_sphere(cam_pos, ray_dir, planet_center, planet_radius);
	if (planet_hit.x > 0.0) {
		t_end = min(t_end, planet_hit.x);
	}

	// Clip raymarch at terrain surface
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	if (raw_depth > 0.0001) {
		vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
		vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
		view_pos.xyz /= view_pos.w;
		vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos.xyz, 1.0)).xyz;

		if (length(world_pos - planet_center) <= atmo_radius) {
			t_end = min(t_end, distance(cam_pos, world_pos));
		}
	}

	if (t_end <= t_start) {
		discard;
	}

	// Interleaved gradient dither to dissolve discrete layering into continuous volume
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));

	// -------------------------------------------------------------
	// DEPTH-ORDERED UNIFIED ATMOSPHERE + VOLUMETRIC CLOUD RAYMARCHING
	// -------------------------------------------------------------
	float r_c_bot = planet_radius + cloud_altitude;
	float r_c_top = r_c_bot + cloud_thickness;
	vec2 c_top_hit = ray_sphere(cam_pos, ray_dir, planet_center, r_c_top);
	vec2 c_bot_hit = ray_sphere(cam_pos, ray_dir, planet_center, r_c_bot);

	float cam_r = length(cam_pos - planet_center);
	float t_c_start = -1.0;
	float t_c_end = -1.0;

	if (cloud_enabled && c_top_hit.y > 0.0) {
		if (cam_r >= r_c_top) {
			t_c_start = max(0.0, c_top_hit.x);
			// Grazing rays continue smoothly across limb to c_top_hit.y without artificial terminator cuts
			if (c_bot_hit.x > 0.0 && planet_hit.x > 0.0) {
				t_c_end = c_bot_hit.x;
			} else {
				t_c_end = c_top_hit.y;
			}
		} else if (cam_r <= r_c_bot) {
			t_c_start = (c_bot_hit.y > 0.0) ? c_bot_hit.y : -1.0;
			t_c_end = c_top_hit.y;
		} else {
			// Camera is INSIDE the cloud slab
			t_c_start = 0.0;
			if (c_bot_hit.x > 0.0 && planet_hit.x > 0.0) {
				t_c_end = c_bot_hit.x;
			} else {
				t_c_end = c_top_hit.y;
			}
		}
		t_c_end = min(t_c_end, t_end);
		t_c_start = min(t_c_start, t_c_end);
	}

	bool has_clouds = (cloud_enabled && t_c_end > t_c_start && t_c_start >= 0.0);

	float cos_theta = dot(ray_dir, sun_norm);
	float cos2 = cos_theta * cos_theta;
	float p_rayleigh = 0.75 * (1.0 + cos2);

	float g = clamp(mie_g, 0.0, 0.99);
	float g2 = g * g;
	float p_mie = (1.0 - g2) / pow(max(0.01, 1.0 + g2 - 2.0 * g * cos_theta), 1.5);

	vec3 total_color = vec3(0.0);
	vec3 atmo_transmittance = vec3(1.0);

	if (has_clouds) {
		// -------------------------------------------------------------
		// SEGMENT 1: FOREGROUND ATMOSPHERE (Air between camera and clouds)
		// -------------------------------------------------------------
		if (t_c_start > t_start + 0.05) {
			const int SAMPLES_PRE = 8;
			float dt_pre = (t_c_start - t_start) / float(SAMPLES_PRE);
			for (int i = 0; i < SAMPLES_PRE; i++) {
				float t = t_start + dt_pre * (float(i) + dither);
				vec3 p = cam_pos + ray_dir * t;
				vec3 scat, ext_c;
				calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, p_rayleigh, p_mie, scat, ext_c);
				vec3 tr = exp(-ext_c * dt_pre);
				total_color += scat * dt_pre * atmo_transmittance;
				atmo_transmittance *= tr;
			}
		}

		// -------------------------------------------------------------
		// SEGMENT 2: CLOUD VOLUME + CO-LOCATED ATMOSPHERE
		// -------------------------------------------------------------
		const int SAMPLES_CLOUD = 24;
		float dt_c = (t_c_end - t_c_start) / float(SAMPLES_CLOUD);
		float cos_th = dot(ray_dir, sun_norm);
		float p_cloud = 0.65 + 0.45 * pow(max(0.0, -cos_th), 3.0) + 0.3 * pow(max(0.0, cos_th), 2.0);

		float rot_angle = TIME * cloud_speed * 6.28318530718;
		float cos_r = cos(rot_angle);
		float sin_r = sin(rot_angle);

		float tc_mid = (t_c_start + t_c_end) * 0.5;
		vec3 pc_mid = cam_pos + ray_dir * tc_mid;
		vec3 mid_scat, mid_ext_c, mid_atten;
		calc_atmo_sample_full(pc_mid, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, p_rayleigh, p_mie, mid_scat, mid_ext_c, mid_atten);

		for (int j = 0; j < SAMPLES_CLOUD; j++) {
			float tc = t_c_start + dt_c * (float(j) + dither);
			vec3 pc = cam_pos + ray_dir * tc;
			vec3 v_c = pc - planet_center;
			float dist_c = length(v_c);

			vec3 atmo_scat, atmo_ext_c;
			calc_atmo_sample_fast(pc, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, p_rayleigh, p_mie, mid_atten, atmo_scat, atmo_ext_c);

			if (dist_c >= r_c_bot && dist_c <= r_c_top) {
				vec3 norm_c = v_c / dist_c;

				float lat = asin(clamp(norm_c.y, -1.0, 1.0));
				float v_uv = 0.5 - lat / 3.141592653589793;
				float lon = atan(norm_c.x, norm_c.z);
				float u_uv = fract(lon / (2.0 * 3.141592653589793) + 0.5 + TIME * cloud_speed);

				vec4 c_tex = textureLod(cloud_texture, vec2(u_uv, v_uv), 0.0);
				float a_val = c_tex.a;
				float coverage = invert_clouds ? (1.0 - a_val) : a_val;

				if (coverage > 0.02) {
					float height_profile = mix(1.0, pow(clamp(coverage, 0.0, 1.0), 0.65), cloud_map_height);
					float local_ceiling = max(0.1, height_profile);

					float h_local = (dist_c - r_c_bot) / (cloud_thickness * local_ceiling);
					if (h_local >= 0.0 && h_local <= 1.0) {
						float h_bot_fade = smoothstep(0.0, 0.15, h_local);
						float h_top_fade = smoothstep(1.0, 0.70, h_local);
						float vert_curve = h_bot_fade * h_top_fade;

						vec3 v_c_rot = vec3(v_c.x * cos_r - v_c.z * sin_r, v_c.y, v_c.x * sin_r + v_c.z * cos_r);
						vec3 p_noise_dir = v_c_rot / dist_c;
						vec3 p_surf = p_noise_dir * (planet_radius + cloud_altitude) + p_noise_dir * (h_local * 0.35 * cloud_thickness);

						vec3 p_base = p_surf * (noise_base_scale / 600.0);
						float n_base = fbm3D(p_base);

						vec3 p_detail = p_surf * (noise_detail_scale / 600.0);
						float n_detail = detail_noise3D(p_detail);

						float combined_noise = n_base * noise_base_strength + n_detail * noise_detail_strength;

						float dens_factor = mix(1.0, coverage, cloud_map_density);
						float base_cloud = dens_factor * vert_curve;

						float erosion = combined_noise * (1.1 - base_cloud * 0.65);
						float shape = max(0.0, base_cloud - erosion);

						float threshold = (1.0 - clamp(cloud_coverage, 0.05, 0.98)) * 0.55;
						float dens = smoothstep(threshold, threshold + 0.30, shape);

						float r_fade = smoothstep(r_c_bot, r_c_bot + cloud_thickness * 0.08, dist_c) * smoothstep(r_c_top, r_c_top - cloud_thickness * 0.08, dist_c);
						dens = pow(dens * r_fade, 1.2) * cloud_density * 5.0;

						if (dens > 0.005) {
							float sun_dot = dot(sun_norm, norm_c);
							float sun_vis = smoothstep(-0.01, 0.06, sun_dot);
							// Smooth twilight skylight transition across terminator
							float twilight = smoothstep(-0.15, 0.08, sun_dot);

							vec3 sunset_tint = mix(vec3(1.0, 0.45, 0.15), vec3(1.0), smoothstep(0.0, 0.12, sun_dot));
							vec3 sun_light_in = sunset_tint * (sun_vis * sun_intensity * cloud_day_brightness);

							float opt_sun = dens * (1.0 - h_local);
							float beer = exp(-opt_sun * 0.5);
							float multi_scatter = exp(-opt_sun * 0.08) * 0.65;
							float sun_penetration = max(beer, multi_scatter);

							vec3 direct_scat = cloud_color.rgb * p_cloud * sun_light_in * sun_penetration;

							// Ambient skylight: slate-blue daylight / twilight ambient fades to starlight night ambient
							vec3 day_sky_ambient = cloud_shadow_color.rgb * (0.2 + 0.3 * h_local) * (sun_intensity * 0.45);
							vec3 night_sky_ambient = cloud_shadow_color.rgb * 0.2 * cloud_night_brightness * (sun_intensity * 0.45);
							vec3 ambient_scat = mix(night_sky_ambient, day_sky_ambient, twilight);

							float cloud_ext = dens * 0.45;
							vec3 step_trans = exp(-(atmo_ext_c + vec3(cloud_ext)) * dt_c);
							vec3 step_scat = (direct_scat + ambient_scat) * (1.0 - exp(-cloud_ext * dt_c)) + atmo_scat * dt_c;

							total_color += step_scat * atmo_transmittance;
							atmo_transmittance *= step_trans;

							if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.01) {
								break;
							}
							continue;
						}
					}
				}
			}

			// Clear air inside cloud altitude shell
			vec3 step_trans = exp(-atmo_ext_c * dt_c);
			total_color += atmo_scat * dt_c * atmo_transmittance;
			atmo_transmittance *= step_trans;

			if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.01) {
				break;
			}
		}

		// -------------------------------------------------------------
		// SEGMENT 3: BACKGROUND ATMOSPHERE (Air behind clouds down to ground/exit)
		// -------------------------------------------------------------
		if (t_end > t_c_end + 0.05 && max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) > 0.01) {
			const int SAMPLES_POST = 6;
			float dt_post = (t_end - t_c_end) / float(SAMPLES_POST);
			for (int i = 0; i < SAMPLES_POST; i++) {
				float t = t_c_end + dt_post * (float(i) + dither);
				vec3 p = cam_pos + ray_dir * t;
				vec3 scat, ext_c;
				calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, p_rayleigh, p_mie, scat, ext_c);
				vec3 tr = exp(-ext_c * dt_post);
				total_color += scat * dt_post * atmo_transmittance;
				atmo_transmittance *= tr;
				if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.01) {
					break;
				}
			}
		}
	} else {
		// -------------------------------------------------------------
		// STANDALONE ATMOSPHERE (Clear rays that miss the cloud shell)
		// -------------------------------------------------------------
		const int SAMPLES_PURE = 16;
		float dt_pure = (t_end - t_start) / float(SAMPLES_PURE);
		for (int i = 0; i < SAMPLES_PURE; i++) {
			float t = t_start + dt_pure * (float(i) + dither);
			vec3 p = cam_pos + ray_dir * t;
			vec3 scat, ext_c;
			calc_atmo_sample(p, sun_norm, atmo_thickness, hr, hm, beta_r, beta_m, p_rayleigh, p_mie, scat, ext_c);
			vec3 tr = exp(-ext_c * dt_pure);
			total_color += scat * dt_pure * atmo_transmittance;
			atmo_transmittance *= tr;
			if (max(atmo_transmittance.r, max(atmo_transmittance.g, atmo_transmittance.b)) < 0.01) {
				break;
			}
		}
	}

	float avg_trans = clamp((atmo_transmittance.r + atmo_transmittance.g + atmo_transmittance.b) / 3.0, 0.0, 1.0);
	float final_alpha = clamp(1.0 - avg_trans, 0.0, 1.0);

	if (final_alpha < 0.002) {
		discard;
	}

	ALBEDO = total_color / max(final_alpha, 0.001);
	ALPHA = final_alpha;
}