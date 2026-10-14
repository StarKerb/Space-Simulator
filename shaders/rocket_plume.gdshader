shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float throttle : hint_range(0.0, 1.0) = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.90, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform vec4 exhaust_color : source_color = vec4(0.35, 0.55, 1.0, 0.85);

varying vec3 v_local_pos;
varying vec2 v_uv;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_local_pos = VERTEX;
	v_uv = UV;
}

void fragment() {
	if (throttle < 0.002) {
		discard;
	}

	// v_uv.y runs along the plume from 0.0 (nozzle exit) to 1.0 (plume tail)
	float y_norm = clamp(v_uv.y, 0.0, 1.0);

	// Supersonic convective flow animation
	float flow_speed = 35.0;
	float flow_t = y_norm * 18.0 - TIME * flow_speed;
	float n = noise2d(vec2(v_uv.x * 10.0, flow_t));

	// Shock diamonds (standing pressure wave nodes along the core)
	float diamond_wave = sin(y_norm * 32.0 - TIME * 5.0) * 0.5 + 0.5;
	float diamond_envelope = exp(-y_norm * 3.5);
	float shock_diamonds = diamond_wave * diamond_envelope * 1.5;

	// Core combustion flame (brightest near exit)
	float core_intensity = exp(-y_norm * 2.0) * (1.0 + shock_diamonds);

	// Outer vacuum plume expansion envelope
	float envelope_glow = (1.0 - y_norm * 0.65) * (0.65 + 0.35 * n);

	// Color composition: white-hot core -> orange flame -> violet/blue vacuum expansion
	vec3 col = mix(exhaust_color.rgb, flame_color.rgb, clamp(core_intensity * 0.8, 0.0, 1.0));
	col = mix(col, core_color.rgb, clamp(core_intensity * 1.6, 0.0, 1.0));

	// Soft boundary fade (fade near nozzle lip and plume tail)
	float edge_fade = smoothstep(0.0, 0.03, y_norm) * smoothstep(1.0, 0.80, y_norm);

	// Blend alpha: core is fully opaque (1.0), expanding shear layer is translucent
	float alpha = clamp((core_intensity * 1.5 + envelope_glow * 0.75) * edge_fade * throttle * 1.4, 0.0, 1.0);

	ALBEDO = col * (1.0 + core_intensity * 0.5);
	ALPHA = alpha;
}
