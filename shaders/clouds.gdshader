shader_type spatial;
render_mode blend_mix, cull_front, unshaded, depth_test_disabled, depth_draw_never;

uniform sampler2D cloud_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float sun_intensity = 2.0;
uniform float planet_radius = 600.0;
uniform vec3 camera_pos = vec3(0.0);

uniform bool invert_clouds = false; // False by default: alpha = clouds, 0 = clear sky
uniform float cloud_altitude = 6.0;
uniform float cloud_thickness = 5.0;
uniform float cloud_density = 1.0;
uniform float cloud_coverage = 0.75;
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

float hash3D(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
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
	return noise3D(p) * 0.5 + noise3D(p * 2.02) * 0.25 + noise3D(p * 4.05) * 0.15 + noise3D(p * 8.1) * 0.1;
}

void fragment() {
	vec3 cam_pos = (length(camera_pos) > 0.001) ? camera_pos : CAMERA_POSITION_WORLD;
	vec3 ray_dir = normalize(v_world_pos - cam_pos);
	vec3 sun_norm = -normalize(sun_dir);

	float r_bottom = planet_radius + cloud_altitude;
	float r_top = r_bottom + cloud_thickness;
	vec2 hit_top = ray_sphere(cam_pos, ray_dir, planet_center, r_top);
	if (hit_top.y <= 0.0) {
		discard;
	}

	float t_start = -1.0;
	float t_end = -1.0;

	vec2 hit_bottom = ray_sphere(cam_pos, ray_dir, planet_center, r_bottom);
	float cam_dist = length(cam_pos - planet_center);

	if (hit_top.y > 0.0) {
		if (cam_dist >= r_top) {
			t_start = max(0.0, hit_top.x);
			if (hit_bottom.x > 0.0) {
				t_end = hit_bottom.x;
			} else {
				// Ray grazes outer shell past inner sphere out into space
				t_end = hit_top.y;
			}
		} else if (cam_dist <= r_bottom) {
			t_start = (hit_bottom.y > 0.0) ? hit_bottom.y : -1.0;
			t_end = hit_top.y;
		} else {
			// Camera is INSIDE the cloud slab!
			t_start = 0.0;
			if (hit_bottom.x > 0.0) {
				t_end = hit_bottom.x;
			} else {
				t_end = hit_top.y;
			}
		}
	}

	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	if (raw_depth > 0.0001 && raw_depth < 0.9999) {
		vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
		vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
		view_pos.xyz /= view_pos.w;
		float d_terrain = length(view_pos.xyz);
		t_end = min(t_end, d_terrain);
	}

	if (t_end <= t_start) {
		discard;
	}

	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	const int SAMPLES = 48;
	float dt = (t_end - t_start) / float(SAMPLES);

	float transmittance = 1.0;
	vec3 total_color = vec3(0.0);

	float cos_theta = dot(ray_dir, sun_norm);
	float p_cloud = 0.65 + 0.45 * pow(max(0.0, -cos_theta), 3.0) + 0.3 * pow(max(0.0, cos_theta), 2.0);

	float rot_angle = TIME * cloud_speed * 6.28318530718;
	float cos_r = cos(rot_angle);
	float sin_r = sin(rot_angle);

	for (int i = 0; i < SAMPLES; i++) {
		float t = t_start + dt * (float(i) + dither);
		vec3 p = cam_pos + ray_dir * t;
		vec3 v_rad = p - planet_center;
		float dist_rad = length(v_rad);

		if (dist_rad < r_bottom || dist_rad > r_top) {
			continue;
		}

		vec3 norm_p = v_rad / dist_rad;

		float lat = asin(clamp(norm_p.y, -1.0, 1.0));
		float v_uv = 0.5 - lat / 3.141592653589793;
		float lon = atan(norm_p.x, norm_p.z);
		float u_uv = fract(lon / (2.0 * 3.141592653589793) + 0.5 + TIME * cloud_speed);

		vec4 tex_val = textureLod(cloud_texture, vec2(u_uv, v_uv), 0.0);
		float a_val = tex_val.a;
		float coverage = invert_clouds ? (1.0 - a_val) : a_val;

		if (coverage > 0.02) {
			// 1. HEIGHT MODULATION:
			float height_profile = mix(1.0, pow(clamp(coverage, 0.0, 1.0), 0.65), cloud_map_height);
			float local_ceiling = max(0.1, height_profile);

			float h_local = (dist_rad - r_bottom) / (cloud_thickness * local_ceiling);
			if (h_local >= 0.0 && h_local <= 1.0) {
				float h_bot_fade = smoothstep(0.0, 0.15, h_local);
				float h_top_fade = smoothstep(1.0, 0.70, h_local);
				float vert_curve = h_bot_fade * h_top_fade;

				vec3 v_c_rot = vec3(v_rad.x * cos_r - v_rad.z * sin_r, v_rad.y, v_rad.x * sin_r + v_rad.z * cos_r);
				vec3 p_noise_dir = v_c_rot / dist_rad;
				vec3 p_surf = p_noise_dir * (planet_radius + cloud_altitude) + p_noise_dir * (h_local * 0.35 * cloud_thickness);

				vec3 np_base = p_surf * (noise_base_scale / 600.0);
				float n_base = fbm3D(np_base);

				vec3 np_detail = p_surf * (noise_detail_scale / 600.0);
				float n_detail = fbm3D(np_detail);

				float combined_noise = n_base * noise_base_strength + n_detail * noise_detail_strength;

				float dens_factor = mix(1.0, coverage, cloud_map_density);
				float base_cloud = dens_factor * vert_curve;

				float erosion = combined_noise * (1.1 - base_cloud * 0.65);
				float shape = max(0.0, base_cloud - erosion);

				float threshold = (1.0 - clamp(cloud_coverage, 0.05, 0.98)) * 0.55;
				float density = smoothstep(threshold, threshold + 0.30, shape);

				float r_fade = smoothstep(r_bottom, r_bottom + cloud_thickness * 0.08, dist_rad) * smoothstep(r_top, r_top - cloud_thickness * 0.08, dist_rad);
				density = pow(density * r_fade, 1.2) * cloud_density * 5.0;

				if (density > 0.005) {
					float sun_dot = dot(norm_p, sun_norm);
					float sun_vis = smoothstep(-0.01, 0.05, sun_dot);

					vec3 sunset_tint = mix(vec3(1.0, 0.45, 0.15), vec3(1.0), smoothstep(0.0, 0.12, sun_dot));
					vec3 sun_light_in = sunset_tint * (sun_vis * sun_intensity * cloud_day_brightness);

					// Multiple scattering penetration
					float opt_sun = density * (1.0 - h_local);
					float beer = exp(-opt_sun * 0.5);
					float multi_scatter = exp(-opt_sun * 0.08) * 0.65;
					float sun_penetration = max(beer, multi_scatter);

					vec3 direct_scat = cloud_color.rgb * p_cloud * sun_light_in * sun_penetration;

					float ambient_mult = mix(cloud_night_brightness, 1.0, sun_vis);
					vec3 ambient_scat = cloud_shadow_color.rgb * (0.2 + 0.3 * h_local) * ambient_mult * (sun_intensity * 0.4);

					float step_ext = density * 0.45 * dt;
					float step_trans = exp(-step_ext);
					float integ_scat = 1.0 - step_trans;

					total_color += (direct_scat + ambient_scat) * integ_scat * transmittance;
					transmittance *= step_trans;

					if (transmittance < 0.01) {
						break;
					}
				}
			}
		}
	}

	float final_alpha = clamp(1.0 - transmittance, 0.0, 1.0);
	if (final_alpha < 0.002) {
		discard;
	}

	ALBEDO = total_color;
	ALPHA = final_alpha;
}
