extends Node

var planet: Node3D
var _im: Object = null

# Internal storage arrays for ImGui pass-by-reference
var _c_enabled := [true]
var _c_invert := [false]
var _c_altitude := [6.0]
var _c_thickness := [5.0]
var _c_density := [1.0]
var _c_opacity := [1.5]
var _c_dither := [0.5]
var _c_coverage := [0.75]
var _c_speed := [0.001]
var _c_noise_speed := [0.0001]
var _c_noise_follow := [0.8]
var _c_shadow_intensity := [0.85]
var _c_self_shadow_intensity := [1.0]
var _c_terminator_depth := [1.0]
var _c_terminator_softness := [0.16]
var _c_sunset_tint := [0.0]
var _c_terminator_offset := [0.0]
var _c_day_bright := [2.0]
var _c_night_bright := [0.0]
var _c_map_height := [0.8]
var _c_map_density := [1.0]
var _c_noise_base_scale := [160.0]
var _c_noise_base_strength := [0.28]
var _c_noise_detail_scale := [480.0]
var _c_noise_detail_strength := [0.15]
var _c_edge_noise := [0.85]
var _c_noise_amount := [0.8]
var _c_samples := [16]
var _render_scale := [1.0]

var _c_l1_enabled := [true]
var _c_l1_scale := [160.0]
var _c_l1_strength := [0.35]
var _c_l1_edge_only := [0.0]
var _c_l1_ch := [0]

var _c_l2_enabled := [true]
var _c_l2_scale := [400.0]
var _c_l2_strength := [0.25]
var _c_l2_edge_only := [0.65]
var _c_l2_ch := [1]

var _c_l3_enabled := [false]
var _c_l3_scale := [800.0]
var _c_l3_strength := [0.20]
var _c_l3_edge_only := [0.85]
var _c_l3_ch := [2]

var _c_l4_enabled := [false]
var _c_l4_scale := [1600.0]
var _c_l4_strength := [0.15]
var _c_l4_edge_only := [1.0]
var _c_l4_ch := [3]

var _c_l5_enabled := [false]
var _c_l5_scale := [2400.0]
var _c_l5_strength := [0.15]
var _c_l5_edge_only := [0.8]
var _c_l5_ch := [1]

var _c_l6_enabled := [false]
var _c_l6_scale := [3200.0]
var _c_l6_strength := [0.12]
var _c_l6_edge_only := [1.0]
var _c_l6_ch := [2]

var _c_l7_enabled := [false]
var _c_l7_scale := [4800.0]
var _c_l7_strength := [0.10]
var _c_l7_edge_only := [0.5]
var _c_l7_ch := [0]

var _c_l8_enabled := [false]
var _c_l8_scale := [6400.0]
var _c_l8_strength := [0.08]
var _c_l8_edge_only := [1.0]
var _c_l8_ch := [3]


var _save_status_timer: float = 0.0
var _save_status_text: String = ""
var _lbl_save_status: Label


var _atmo_enabled := [true]
var _atmo_scale := [1.06]
var _sun_intensity := [2.0]
var _hr := [0.015]
var _hm := [0.008]
var _godray_intensity := [1.0]

var _eye_adapt_enabled := [true]
var _eye_adapt_speed := [3.0]
var _sky_max_energy := [1.2]
var _sky_min_energy := [0.0]
var _auto_exp_scale := [0.4]
var _lbl_adapt_status: Label

var _ocean_enabled := [true]
var _ocean_altitude := [0.0]
var _ocean_sink := [0.4]
var _ocean_depth_dist := [6.0]
var _wave_amplitude := [0.28]
var _wave_speed := [1.2]
var _foam_intensity := [1.0]
var _ssr_enabled := [true]

var _h_scale := [25.0]
var _sea_level := [0.485]
var _max_lod := [6]
var _lod_thresh := [3.5]
var _normal_depth := [1.0]
var _invert_normal_y := [false]
var _normal_orbital_ratio := [0.22]
var _normal_slope_thresh := [0.08]
var _planet_spin_enabled := [true]
var _planet_spin_speed := [0.005]

var _imgui_connected := false
var _show_ui := true
var _canvas_ui: CanvasLayer
var _layer_section_wrappers: Dictionary = {}

func _add_next_noise_layer() -> void:
	if not planet:
		return
	var layer_to_enable := 0
	if not _c_l3_enabled[0]: layer_to_enable = 3
	elif not _c_l4_enabled[0]: layer_to_enable = 4
	elif not _c_l5_enabled[0]: layer_to_enable = 5
	elif not _c_l6_enabled[0]: layer_to_enable = 6
	elif not _c_l7_enabled[0]: layer_to_enable = 7
	elif not _c_l8_enabled[0]: layer_to_enable = 8

	if layer_to_enable > 0:
		match layer_to_enable:
			3:
				planet.noise_l3_enabled = true
				_c_l3_enabled[0] = true
			4:
				planet.noise_l4_enabled = true
				_c_l4_enabled[0] = true
			5:
				planet.noise_l5_enabled = true
				_c_l5_enabled[0] = true
			6:
				planet.noise_l6_enabled = true
				_c_l6_enabled[0] = true
			7:
				planet.noise_l7_enabled = true
				_c_l7_enabled[0] = true
			8:
				planet.noise_l8_enabled = true
				_c_l8_enabled[0] = true
		if _layer_section_wrappers.has(layer_to_enable) and _layer_section_wrappers[layer_to_enable]:
			_layer_section_wrappers[layer_to_enable].visible = true

func _ready() -> void:
	planet = get_parent().get_node_or_null("Planet")
	if not planet:
		planet = get_tree().get_first_node_in_group("planet")
	if not planet:
		for c in get_parent().get_children():
			if "radius" in c and "height_scale" in c:
				planet = c
				break

	_sync_from_planet()

	if ClassDB.class_exists("ImGui"):
		_im = ClassDB.instantiate("ImGui")

	# Connect to ImGuiRoot autoload if available
	var imgui_root = get_node_or_null("/root/ImGuiRoot")
	if imgui_root:
		if imgui_root.has_signal("imgui_layout"):
			imgui_root.connect("imgui_layout", Callable(self, "_on_imgui_layout"))
			_imgui_connected = true

	# Fallback Canvas UI (only shown if native ImGui is unavailable)
	_create_styled_imgui_panel()
	if _imgui_connected and _canvas_ui:
		_canvas_ui.visible = false
	print("[PlanetDebugUI] Ready. Press F1, Tab, or ~ (Tilde) to toggle menu.")

func _sync_from_planet() -> void:
	if not planet:
		return
	if "cloud_enabled" in planet: _c_enabled[0] = planet.cloud_enabled
	if "invert_clouds" in planet: _c_invert[0] = planet.invert_clouds
	if "cloud_altitude" in planet: _c_altitude[0] = planet.cloud_altitude
	if "cloud_thickness" in planet: _c_thickness[0] = planet.cloud_thickness
	if "cloud_density" in planet: _c_density[0] = planet.cloud_density
	if "cloud_opacity" in planet: _c_opacity[0] = planet.cloud_opacity
	if "cloud_dither" in planet: _c_dither[0] = planet.cloud_dither
	if "cloud_coverage" in planet: _c_coverage[0] = planet.cloud_coverage
	if "cloud_speed" in planet: _c_speed[0] = planet.cloud_speed
	if "cloud_noise_speed" in planet: _c_noise_speed[0] = planet.cloud_noise_speed
	if "cloud_noise_follow" in planet: _c_noise_follow[0] = planet.cloud_noise_follow
	if "cloud_shadow_intensity" in planet: _c_shadow_intensity[0] = planet.cloud_shadow_intensity
	if "cloud_self_shadow_intensity" in planet: _c_self_shadow_intensity[0] = planet.cloud_self_shadow_intensity
	if "cloud_terminator_depth" in planet: _c_terminator_depth[0] = planet.cloud_terminator_depth
	if "cloud_terminator_softness" in planet: _c_terminator_softness[0] = planet.cloud_terminator_softness
	if "cloud_sunset_tint" in planet: _c_sunset_tint[0] = planet.cloud_sunset_tint
	if "cloud_terminator_offset" in planet: _c_terminator_offset[0] = planet.cloud_terminator_offset
	if "cloud_day_brightness" in planet: _c_day_bright[0] = planet.cloud_day_brightness
	if "cloud_night_brightness" in planet: _c_night_bright[0] = planet.cloud_night_brightness
	if "cloud_map_height" in planet: _c_map_height[0] = planet.cloud_map_height
	if "cloud_map_density" in planet: _c_map_density[0] = planet.cloud_map_density
	if "noise_base_scale" in planet: _c_noise_base_scale[0] = planet.noise_base_scale
	if "noise_base_strength" in planet: _c_noise_base_strength[0] = planet.noise_base_strength
	if "noise_detail_scale" in planet: _c_noise_detail_scale[0] = planet.noise_detail_scale
	if "noise_detail_strength" in planet: _c_noise_detail_strength[0] = planet.noise_detail_strength
	if "noise_l1_enabled" in planet: _c_l1_enabled[0] = planet.noise_l1_enabled
	if "noise_l1_scale" in planet: _c_l1_scale[0] = planet.noise_l1_scale
	if "noise_l1_strength" in planet: _c_l1_strength[0] = planet.noise_l1_strength
	if "noise_l1_edge_only" in planet: _c_l1_edge_only[0] = planet.noise_l1_edge_only
	if "noise_l1_channel" in planet: _c_l1_ch[0] = planet.noise_l1_channel
	if "noise_l2_enabled" in planet: _c_l2_enabled[0] = planet.noise_l2_enabled
	if "noise_l2_scale" in planet: _c_l2_scale[0] = planet.noise_l2_scale
	if "noise_l2_strength" in planet: _c_l2_strength[0] = planet.noise_l2_strength
	if "noise_l2_edge_only" in planet: _c_l2_edge_only[0] = planet.noise_l2_edge_only
	if "noise_l2_channel" in planet: _c_l2_ch[0] = planet.noise_l2_channel
	if "noise_l3_enabled" in planet: _c_l3_enabled[0] = planet.noise_l3_enabled
	if "noise_l3_scale" in planet: _c_l3_scale[0] = planet.noise_l3_scale
	if "noise_l3_strength" in planet: _c_l3_strength[0] = planet.noise_l3_strength
	if "noise_l3_edge_only" in planet: _c_l3_edge_only[0] = planet.noise_l3_edge_only
	if "noise_l3_channel" in planet: _c_l3_ch[0] = planet.noise_l3_channel
	if "noise_l4_enabled" in planet: _c_l4_enabled[0] = planet.noise_l4_enabled
	if "noise_l4_scale" in planet: _c_l4_scale[0] = planet.noise_l4_scale
	if "noise_l4_strength" in planet: _c_l4_strength[0] = planet.noise_l4_strength
	if "noise_l4_edge_only" in planet: _c_l4_edge_only[0] = planet.noise_l4_edge_only
	if "noise_l4_channel" in planet: _c_l4_ch[0] = planet.noise_l4_channel

	if "noise_l5_enabled" in planet: _c_l5_enabled[0] = planet.noise_l5_enabled
	if "noise_l5_scale" in planet: _c_l5_scale[0] = planet.noise_l5_scale
	if "noise_l5_strength" in planet: _c_l5_strength[0] = planet.noise_l5_strength
	if "noise_l5_edge_only" in planet: _c_l5_edge_only[0] = planet.noise_l5_edge_only
	if "noise_l5_channel" in planet: _c_l5_ch[0] = planet.noise_l5_channel

	if "noise_l6_enabled" in planet: _c_l6_enabled[0] = planet.noise_l6_enabled
	if "noise_l6_scale" in planet: _c_l6_scale[0] = planet.noise_l6_scale
	if "noise_l6_strength" in planet: _c_l6_strength[0] = planet.noise_l6_strength
	if "noise_l6_edge_only" in planet: _c_l6_edge_only[0] = planet.noise_l6_edge_only
	if "noise_l6_channel" in planet: _c_l6_ch[0] = planet.noise_l6_channel

	if "noise_l7_enabled" in planet: _c_l7_enabled[0] = planet.noise_l7_enabled
	if "noise_l7_scale" in planet: _c_l7_scale[0] = planet.noise_l7_scale
	if "noise_l7_strength" in planet: _c_l7_strength[0] = planet.noise_l7_strength
	if "noise_l7_edge_only" in planet: _c_l7_edge_only[0] = planet.noise_l7_edge_only
	if "noise_l7_channel" in planet: _c_l7_ch[0] = planet.noise_l7_channel

	if "noise_l8_enabled" in planet: _c_l8_enabled[0] = planet.noise_l8_enabled
	if "noise_l8_scale" in planet: _c_l8_scale[0] = planet.noise_l8_scale
	if "noise_l8_strength" in planet: _c_l8_strength[0] = planet.noise_l8_strength
	if "noise_l8_edge_only" in planet: _c_l8_edge_only[0] = planet.noise_l8_edge_only
	if "noise_l8_channel" in planet: _c_l8_ch[0] = planet.noise_l8_channel

	if "cloud_edge_noise" in planet: _c_edge_noise[0] = planet.cloud_edge_noise
	if "cloud_noise_amount" in planet: _c_noise_amount[0] = planet.cloud_noise_amount
	if "cloud_samples" in planet: _c_samples[0] = planet.cloud_samples
	if "render_scale" in planet: _render_scale[0] = planet.render_scale


	if "atmosphere_enabled" in planet: _atmo_enabled[0] = planet.atmosphere_enabled
	if "atmosphere_scale" in planet: _atmo_scale[0] = planet.atmosphere_scale
	if "sun_intensity" in planet: _sun_intensity[0] = planet.sun_intensity
	if "scale_height_rayleigh" in planet: _hr[0] = planet.scale_height_rayleigh
	if "scale_height_mie" in planet: _hm[0] = planet.scale_height_mie
	if "godray_intensity" in planet: _godray_intensity[0] = planet.godray_intensity

	if "eye_adaptation_enabled" in planet: _eye_adapt_enabled[0] = planet.eye_adaptation_enabled
	if "eye_adaptation_speed" in planet: _eye_adapt_speed[0] = planet.eye_adaptation_speed
	if "skybox_max_energy" in planet: _sky_max_energy[0] = planet.skybox_max_energy
	if "skybox_min_energy" in planet: _sky_min_energy[0] = planet.skybox_min_energy
	if "auto_exposure_scale" in planet: _auto_exp_scale[0] = planet.auto_exposure_scale

	if "ocean_enabled" in planet: _ocean_enabled[0] = planet.ocean_enabled
	if "ocean_altitude" in planet: _ocean_altitude[0] = planet.ocean_altitude
	if "ocean_bed_sink" in planet: _ocean_sink[0] = planet.ocean_bed_sink
	if "ocean_depth_distance" in planet: _ocean_depth_dist[0] = planet.ocean_depth_distance
	if "wave_amplitude" in planet: _wave_amplitude[0] = planet.wave_amplitude
	if "wave_speed" in planet: _wave_speed[0] = planet.wave_speed
	if "foam_intensity" in planet: _foam_intensity[0] = planet.foam_intensity
	if "ssr_enabled" in planet: _ssr_enabled[0] = planet.ssr_enabled

	if "height_scale" in planet: _h_scale[0] = planet.height_scale
	if "sea_level" in planet: _sea_level[0] = planet.sea_level
	if "max_lod" in planet: _max_lod[0] = planet.max_lod
	if "lod_threshold" in planet: _lod_thresh[0] = planet.lod_threshold
	if "normal_depth" in planet: _normal_depth[0] = planet.normal_depth
	if "invert_normal_y" in planet: _invert_normal_y[0] = planet.invert_normal_y
	if "normal_orbital_ratio" in planet: _normal_orbital_ratio[0] = planet.normal_orbital_ratio
	if "normal_slope_threshold" in planet: _normal_slope_thresh[0] = planet.normal_slope_threshold
	if "planet_spin_enabled" in planet: _planet_spin_enabled[0] = planet.planet_spin_enabled
	if "planet_spin_speed" in planet: _planet_spin_speed[0] = planet.planet_spin_speed

var _last_imgui_frame: int = -1

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_TAB or event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			_show_ui = not _show_ui
			if _canvas_ui:
				_canvas_ui.visible = _show_ui if not _imgui_connected else false
			if _show_ui:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			print("[PlanetDebugUI] Menu visibility: ", "VISIBLE" if _show_ui else "HIDDEN")

func _process(delta: float) -> void:
	if _save_status_timer > 0.0:
		_save_status_timer -= delta
		if _save_status_timer <= 0.0:
			_save_status_text = ""
			if _lbl_save_status:
				_lbl_save_status.text = ""

	if _canvas_ui and _canvas_ui.visible and _lbl_adapt_status and planet:
		var b: float = planet.current_perceived_brightness if "current_perceived_brightness" in planet else 0.0
		var s: float = planet.current_skybox_energy if "current_skybox_energy" in planet else 1.0
		_lbl_adapt_status.text = "Perceived: %.2f  |  Sky Energy: %.2f" % [b, s]

func _on_imgui_layout() -> void:
	var cur_frame := Engine.get_process_frames()
	if _last_imgui_frame == cur_frame:
		return
	_last_imgui_frame = cur_frame

	if not _show_ui or not planet or not _im:
		return

	_im.Begin("Planet Live Settings (F1 / Tab / ~ to toggle)")

	if _im.CollapsingHeader("Planet Rotation"):
		if _im.Checkbox("Enable Planet Spin", _planet_spin_enabled):
			planet.planet_spin_enabled = _planet_spin_enabled[0]
		if _im.SliderFloat("Planet Spin Speed", _planet_spin_speed, -0.05, 0.05):
			planet.planet_spin_speed = _planet_spin_speed[0]

	if _im.CollapsingHeader("Volumetric Clouds"):
		if _im.Button("💾 Save & Apply to Scene (Persistent)"):
			if planet.has_method("save_cloud_settings_to_scene"):
				var ok: bool = planet.save_cloud_settings_to_scene()
				_save_status_text = "✓ Settings Saved to space.tscn & config!" if ok else "✗ Save Failed!"
				_save_status_timer = 4.0
		if _save_status_text != "":
			_im.Text(_save_status_text)
		_im.Separator()

		if _im.Checkbox("Enable Clouds", _c_enabled):
			planet.cloud_enabled = _c_enabled[0]
		if _im.Checkbox("Invert Alpha (Transparent = Clouds)", _c_invert):
			planet.invert_clouds = _c_invert[0]
		if _im.SliderFloat("Cloud Altitude", _c_altitude, 0.0, 30.0):
			planet.cloud_altitude = _c_altitude[0]
		if _im.SliderFloat("Cloud Thickness", _c_thickness, 0.5, 20.0):
			planet.cloud_thickness = _c_thickness[0]
		if _im.SliderFloat("Cloud Density", _c_density, 0.05, 5.0):
			planet.cloud_density = _c_density[0]
		if _im.SliderFloat("Cloud Opacity", _c_opacity, 0.2, 5.0):
			planet.cloud_opacity = _c_opacity[0]
		if _im.SliderFloat("Cloud Dither", _c_dither, 0.0, 1.0):
			planet.cloud_dither = _c_dither[0]
		if _im.SliderFloat("Cloud Coverage", _c_coverage, 0.0, 1.0):
			planet.cloud_coverage = _c_coverage[0]
		if _im.SliderFloat("Cloud Drift Speed", _c_speed, -0.005, 0.005):
			planet.cloud_speed = _c_speed[0]
		if _im.SliderFloat("Cloud Noise Speed", _c_noise_speed, -0.005, 0.005):
			planet.cloud_noise_speed = _c_noise_speed[0]
		if _im.SliderFloat("Noise Follow Cloud", _c_noise_follow, 0.0, 1.5):
			planet.cloud_noise_follow = _c_noise_follow[0]
		if _im.SliderFloat("Cloud Terrain Shadow", _c_shadow_intensity, 0.0, 1.0):
			planet.cloud_shadow_intensity = _c_shadow_intensity[0]
		if _im.SliderFloat("Cloud Self-Shadowing", _c_self_shadow_intensity, 0.0, 2.0):
			planet.cloud_self_shadow_intensity = _c_self_shadow_intensity[0]
		if _im.SliderFloat("Terminator Shadow Depth", _c_terminator_depth, 0.0, 2.0):
			planet.cloud_terminator_depth = _c_terminator_depth[0]
		if _im.SliderFloat("Terminator Softness", _c_terminator_softness, 0.02, 0.4):
			planet.cloud_terminator_softness = _c_terminator_softness[0]
		if _im.SliderFloat("Cloud Terminator Shift", _c_terminator_offset, -0.3, 0.3):
			planet.cloud_terminator_offset = _c_terminator_offset[0]
		if _im.SliderFloat("Sunset Cloud Tint", _c_sunset_tint, 0.0, 1.0):
			planet.cloud_sunset_tint = _c_sunset_tint[0]
		if _im.SliderFloat("Day Brightness", _c_day_bright, 0.5, 5.0):
			planet.cloud_day_brightness = _c_day_bright[0]
		if _im.SliderFloat("Night Brightness", _c_night_bright, 0.0, 0.5):
			planet.cloud_night_brightness = _c_night_bright[0]
		if _im.SliderFloat("Map Height Factor", _c_map_height, 0.0, 1.0):
			planet.cloud_map_height = _c_map_height[0]
		if _im.SliderFloat("Map Density Factor", _c_map_density, 0.0, 1.0):
			planet.cloud_map_density = _c_map_density[0]

		_im.Separator()
		_im.Text("=== 3D Multi-Layer Noise Editor ===")
		if _im.SliderFloat("Cloud Noise Amount", _c_noise_amount, 0.0, 1.5):
			planet.cloud_noise_amount = _c_noise_amount[0]

		# Layer 1
		_im.Text("--- Layer 1: Macro Shape (Base) ---")
		if _im.Checkbox("Enable Layer 1", _c_l1_enabled):
			planet.noise_l1_enabled = _c_l1_enabled[0]
		if _im.SliderFloat("L1 Scale", _c_l1_scale, 20.0, 1000.0):
			planet.noise_l1_scale = _c_l1_scale[0]
		if _im.SliderFloat("L1 Strength", _c_l1_strength, 0.0, 1.0):
			planet.noise_l1_strength = _c_l1_strength[0]
		if _im.SliderFloat("L1 Edge-Only vs Full (0=Full, 1=Edge)", _c_l1_edge_only, 0.0, 1.0):
			planet.noise_l1_edge_only = _c_l1_edge_only[0]
		if _im.SliderInt("L1 Channel (0:R, 1:G, 2:B, 3:A)", _c_l1_ch, 0, 3):
			planet.noise_l1_channel = _c_l1_ch[0]

		# Layer 2
		_im.Text("--- Layer 2: Meso Erosion (Billows) ---")
		if _im.Checkbox("Enable Layer 2", _c_l2_enabled):
			planet.noise_l2_enabled = _c_l2_enabled[0]
		if _im.SliderFloat("L2 Scale", _c_l2_scale, 50.0, 2000.0):
			planet.noise_l2_scale = _c_l2_scale[0]
		if _im.SliderFloat("L2 Strength", _c_l2_strength, 0.0, 1.0):
			planet.noise_l2_strength = _c_l2_strength[0]
		if _im.SliderFloat("L2 Edge-Only vs Full (0=Full, 1=Edge)", _c_l2_edge_only, 0.0, 1.0):
			planet.noise_l2_edge_only = _c_l2_edge_only[0]
		if _im.SliderInt("L2 Channel (0:R, 1:G, 2:B, 3:A)", _c_l2_ch, 0, 3):
			planet.noise_l2_channel = _c_l2_ch[0]

		# Layer 3
		if _c_l3_enabled[0]:
			_im.Text("--- Layer 3: Cauliflower Detail ---")
			if _im.Checkbox("Enable Layer 3", _c_l3_enabled):
				planet.noise_l3_enabled = _c_l3_enabled[0]
			if _im.SliderFloat("L3 Scale", _c_l3_scale, 100.0, 3000.0):
				planet.noise_l3_scale = _c_l3_scale[0]
			if _im.SliderFloat("L3 Strength", _c_l3_strength, 0.0, 1.0):
				planet.noise_l3_strength = _c_l3_strength[0]
			if _im.SliderFloat("L3 Edge-Only vs Full (0=Full, 1=Edge)", _c_l3_edge_only, 0.0, 1.0):
				planet.noise_l3_edge_only = _c_l3_edge_only[0]
			if _im.SliderInt("L3 Channel (0:R, 1:G, 2:B, 3:A)", _c_l3_ch, 0, 3):
				planet.noise_l3_channel = _c_l3_ch[0]

		# Layer 4
		if _c_l4_enabled[0]:
			_im.Text("--- Layer 4: Micro Turbulence / Wisps ---")
			if _im.Checkbox("Enable Layer 4", _c_l4_enabled):
				planet.noise_l4_enabled = _c_l4_enabled[0]
			if _im.SliderFloat("L4 Scale", _c_l4_scale, 200.0, 4000.0):
				planet.noise_l4_scale = _c_l4_scale[0]
			if _im.SliderFloat("L4 Strength", _c_l4_strength, 0.0, 1.0):
				planet.noise_l4_strength = _c_l4_strength[0]
			if _im.SliderFloat("L4 Edge-Only vs Full (0=Full, 1=Edge)", _c_l4_edge_only, 0.0, 1.0):
				planet.noise_l4_edge_only = _c_l4_edge_only[0]
			if _im.SliderInt("L4 Channel (0:R, 1:G, 2:B, 3:A)", _c_l4_ch, 0, 3):
				planet.noise_l4_channel = _c_l4_ch[0]

		# Layer 5
		if _c_l5_enabled[0]:
			_im.Text("--- Layer 5: High-Frequency Grain ---")
			if _im.Checkbox("Enable Layer 5", _c_l5_enabled):
				planet.noise_l5_enabled = _c_l5_enabled[0]
			if _im.SliderFloat("L5 Scale", _c_l5_scale, 300.0, 6000.0):
				planet.noise_l5_scale = _c_l5_scale[0]
			if _im.SliderFloat("L5 Strength", _c_l5_strength, 0.0, 1.0):
				planet.noise_l5_strength = _c_l5_strength[0]
			if _im.SliderFloat("L5 Edge-Only vs Full (0=Full, 1=Edge)", _c_l5_edge_only, 0.0, 1.0):
				planet.noise_l5_edge_only = _c_l5_edge_only[0]
			if _im.SliderInt("L5 Channel (0:R, 1:G, 2:B, 3:A)", _c_l5_ch, 0, 3):
				planet.noise_l5_channel = _c_l5_ch[0]

		# Layer 6
		if _c_l6_enabled[0]:
			_im.Text("--- Layer 6: Cirrus Fibers ---")
			if _im.Checkbox("Enable Layer 6", _c_l6_enabled):
				planet.noise_l6_enabled = _c_l6_enabled[0]
			if _im.SliderFloat("L6 Scale", _c_l6_scale, 400.0, 8000.0):
				planet.noise_l6_scale = _c_l6_scale[0]
			if _im.SliderFloat("L6 Strength", _c_l6_strength, 0.0, 1.0):
				planet.noise_l6_strength = _c_l6_strength[0]
			if _im.SliderFloat("L6 Edge-Only vs Full (0=Full, 1=Edge)", _c_l6_edge_only, 0.0, 1.0):
				planet.noise_l6_edge_only = _c_l6_edge_only[0]
			if _im.SliderInt("L6 Channel (0:R, 1:G, 2:B, 3:A)", _c_l6_ch, 0, 3):
				planet.noise_l6_channel = _c_l6_ch[0]

		# Layer 7
		if _c_l7_enabled[0]:
			_im.Text("--- Layer 7: Micro Erosion ---")
			if _im.Checkbox("Enable Layer 7", _c_l7_enabled):
				planet.noise_l7_enabled = _c_l7_enabled[0]
			if _im.SliderFloat("L7 Scale", _c_l7_scale, 500.0, 10000.0):
				planet.noise_l7_scale = _c_l7_scale[0]
			if _im.SliderFloat("L7 Strength", _c_l7_strength, 0.0, 1.0):
				planet.noise_l7_strength = _c_l7_strength[0]
			if _im.SliderFloat("L7 Edge-Only vs Full (0=Full, 1=Edge)", _c_l7_edge_only, 0.0, 1.0):
				planet.noise_l7_edge_only = _c_l7_edge_only[0]
			if _im.SliderInt("L7 Channel (0:R, 1:G, 2:B, 3:A)", _c_l7_ch, 0, 3):
				planet.noise_l7_channel = _c_l7_ch[0]

		# Layer 8
		if _c_l8_enabled[0]:
			_im.Text("--- Layer 8: Fine Dust ---")
			if _im.Checkbox("Enable Layer 8", _c_l8_enabled):
				planet.noise_l8_enabled = _c_l8_enabled[0]
			if _im.SliderFloat("L8 Scale", _c_l8_scale, 600.0, 12000.0):
				planet.noise_l8_scale = _c_l8_scale[0]
			if _im.SliderFloat("L8 Strength", _c_l8_strength, 0.0, 1.0):
				planet.noise_l8_strength = _c_l8_strength[0]
			if _im.SliderFloat("L8 Edge-Only vs Full (0=Full, 1=Edge)", _c_l8_edge_only, 0.0, 1.0):
				planet.noise_l8_edge_only = _c_l8_edge_only[0]
			if _im.SliderInt("L8 Channel (0:R, 1:G, 2:B, 3:A)", _c_l8_ch, 0, 3):
				planet.noise_l8_channel = _c_l8_ch[0]

		if not (_c_l3_enabled[0] and _c_l4_enabled[0] and _c_l5_enabled[0] and _c_l6_enabled[0] and _c_l7_enabled[0] and _c_l8_enabled[0]):
			if _im.Button("➕ Add Noise Layer"):
				_add_next_noise_layer()

		if _im.SliderFloat("Legacy Edge Noise", _c_edge_noise, 0.0, 2.0):
			planet.cloud_edge_noise = _c_edge_noise[0]


		_im.Separator()
		_im.Text("Performance & Scaling Optimizations:")
		if _im.SliderInt("Cloud Raymarch Steps", _c_samples, 4, 48):
			planet.cloud_samples = _c_samples[0]
		if _im.SliderFloat("Render Scale (Buffer)", _render_scale, 0.25, 1.0):
			planet.render_scale = _render_scale[0]

	if _im.CollapsingHeader("Atmosphere"):
		if _im.Checkbox("Enable Atmosphere", _atmo_enabled):
			planet.atmosphere_enabled = _atmo_enabled[0]
		if _im.SliderFloat("Atmosphere Scale", _atmo_scale, 1.01, 1.15):
			planet.atmosphere_scale = _atmo_scale[0]
		if _im.SliderFloat("Sun Intensity", _sun_intensity, 0.1, 5.0):
			planet.sun_intensity = _sun_intensity[0]
		if _im.SliderFloat("Rayleigh Scale Height", _hr, 0.001, 0.08):
			planet.scale_height_rayleigh = _hr[0]
		if _im.SliderFloat("Mie Scale Height", _hm, 0.001, 0.04):
			planet.scale_height_mie = _hm[0]
		if _im.SliderFloat("Godray Intensity", _godray_intensity, 0.0, 3.0):
			planet.godray_intensity = _godray_intensity[0]

	if _im.CollapsingHeader("Eye Adaptation & Skybox"):
		if _im.Checkbox("Enable Eye Adaptation", _eye_adapt_enabled):
			planet.eye_adaptation_enabled = _eye_adapt_enabled[0]
		if _im.SliderFloat("Adaptation Speed", _eye_adapt_speed, 0.5, 8.0):
			planet.eye_adaptation_speed = _eye_adapt_speed[0]
		if _im.SliderFloat("Skybox Max Energy (Dark)", _sky_max_energy, 0.0, 3.0):
			planet.skybox_max_energy = _sky_max_energy[0]
		if _im.SliderFloat("Skybox Min Energy (Day)", _sky_min_energy, 0.0, 0.5):
			planet.skybox_min_energy = _sky_min_energy[0]
		if _im.SliderFloat("Auto Exposure Scale", _auto_exp_scale, 0.1, 1.5):
			planet.auto_exposure_scale = _auto_exp_scale[0]
		if "current_perceived_brightness" in planet:
			_im.Text("Perceived Brightness: %.2f" % planet.current_perceived_brightness)
		if "current_skybox_energy" in planet:
			_im.Text("Skybox Energy: %.2f" % planet.current_skybox_energy)

	if _im.CollapsingHeader("Ocean"):
		if _im.Checkbox("Enable Ocean", _ocean_enabled):
			planet.ocean_enabled = _ocean_enabled[0]
		if _im.SliderFloat("Ocean Altitude", _ocean_altitude, -3.0, 3.0):
			planet.ocean_altitude = _ocean_altitude[0]
		if _im.SliderFloat("Ocean Bed Sink", _ocean_sink, 0.0, 1.5):
			planet.ocean_bed_sink = _ocean_sink[0]
		if _im.SliderFloat("Depth Distance", _ocean_depth_dist, 0.5, 20.0):
			planet.ocean_depth_distance = _ocean_depth_dist[0]
		if _im.SliderFloat("Wave Amplitude", _wave_amplitude, 0.0, 1.5):
			planet.wave_amplitude = _wave_amplitude[0]
		if _im.SliderFloat("Wave Speed", _wave_speed, 0.1, 4.0):
			planet.wave_speed = _wave_speed[0]
		if _im.SliderFloat("Foam Intensity", _foam_intensity, 0.0, 2.0):
			planet.foam_intensity = _foam_intensity[0]
		if _im.Checkbox("Screen Space Reflections (SSR)", _ssr_enabled):
			planet.ssr_enabled = _ssr_enabled[0]

	if _im.CollapsingHeader("Terrain & LOD"):
		if _im.SliderFloat("Height Scale", _h_scale, 0.0, 80.0):
			planet.height_scale = _h_scale[0]
		if _im.SliderFloat("Sea Level", _sea_level, 0.45, 0.55):
			planet.sea_level = _sea_level[0]
		if _im.SliderFloat("LOD Threshold", _lod_thresh, 1.0, 8.0):
			planet.lod_threshold = _lod_thresh[0]
		_im.Separator()
		_im.Text("Terrain Normals & Lighting:")
		if _im.SliderFloat("Normal Map Depth", _normal_depth, 0.0, 2.0):
			planet.normal_depth = _normal_depth[0]
		if _im.SliderFloat("Orbital Relief Ratio", _normal_orbital_ratio, -1.0, 1.0):
			planet.normal_orbital_ratio = _normal_orbital_ratio[0]
		if _im.SliderFloat("Slope Filter Threshold", _normal_slope_thresh, 0.0, 0.5):
			planet.normal_slope_threshold = _normal_slope_thresh[0]
		if _im.Checkbox("Invert Normal Y (DirectX / OpenGL)", _invert_normal_y):
			planet.invert_normal_y = _invert_normal_y[0]

	_im.End()

func _create_styled_imgui_panel() -> void:
	_canvas_ui = CanvasLayer.new()
	_canvas_ui.name = "PlanetDebugCanvas"
	_canvas_ui.layer = 100
	add_child(_canvas_ui)

	# Main window container matching Dear ImGui Theme (Image 5)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(360, 600)
	win.position = Vector2(18, 18)

	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	win_style.border_color = Color(0.22, 0.30, 0.42, 1.0)
	win_style.set_border_width_all(1)
	win_style.set_corner_radius_all(4)
	win_style.set_content_margin_all(8)
	win.add_theme_stylebox_override("panel", win_style)
	_canvas_ui.add_child(win)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.add_child(main_vbox)

	# Title bar with authentic Dear ImGui Blue Banner
	var title_bar := PanelContainer.new()
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.14, 0.35, 0.62, 1.0)
	title_style.set_corner_radius_all(3)
	title_style.set_content_margin_all(6)
	title_bar.add_theme_stylebox_override("panel", title_style)
	main_vbox.add_child(title_bar)

	var title_hbox := HBoxContainer.new()
	title_bar.add_child(title_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "Planet Settings (F1 / Tab / ~ to toggle)"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " X "
	close_btn.flat = true
	close_btn.pressed.connect(func():
		_show_ui = false
		_canvas_ui.visible = false
	)
	title_hbox.add_child(close_btn)

	# Scrollable body
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var body_vbox := VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body_vbox)

	# Section 0: Planet Rotation
	var spin_vbox = _add_collapsible_section(body_vbox, "Planet Rotation", true)
	_add_checkbox(spin_vbox, "Enable Planet Spin", _planet_spin_enabled[0], func(v): planet.planet_spin_enabled = v; _planet_spin_enabled[0] = v)
	_add_slider(spin_vbox, "Planet Spin Speed", -0.05, 0.05, _planet_spin_speed[0], func(v): planet.planet_spin_speed = v; _planet_spin_speed[0] = v)

	# Section 1: Volumetric Clouds
	var clouds_vbox = _add_collapsible_section(body_vbox, "Volumetric Clouds", true)
	var _btn_save := _add_button(clouds_vbox, "💾 Save & Apply to Scene (Persistent)", func():
		if planet.has_method("save_cloud_settings_to_scene"):
			var ok: bool = planet.save_cloud_settings_to_scene()
			_save_status_text = "✓ Settings Saved to space.tscn & config!" if ok else "✗ Save Failed!"
			_save_status_timer = 4.0
			if _lbl_save_status:
				_lbl_save_status.text = _save_status_text
	)
	_lbl_save_status = Label.new()
	_lbl_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clouds_vbox.add_child(_lbl_save_status)

	_add_checkbox(clouds_vbox, "Enable Clouds", _c_enabled[0], func(v): planet.cloud_enabled = v; _c_enabled[0] = v)
	_add_checkbox(clouds_vbox, "Invert Alpha (Transparent = Clouds)", _c_invert[0], func(v): planet.invert_clouds = v; _c_invert[0] = v)
	_add_slider(clouds_vbox, "Cloud Altitude", 0.0, 30.0, _c_altitude[0], func(v): planet.cloud_altitude = v; _c_altitude[0] = v)
	_add_slider(clouds_vbox, "Cloud Thickness", 0.5, 20.0, _c_thickness[0], func(v): planet.cloud_thickness = v; _c_thickness[0] = v)
	_add_slider(clouds_vbox, "Cloud Density", 0.05, 5.0, _c_density[0], func(v): planet.cloud_density = v; _c_density[0] = v)
	_add_slider(clouds_vbox, "Cloud Opacity", 0.2, 5.0, _c_opacity[0], func(v): planet.cloud_opacity = v; _c_opacity[0] = v)
	_add_slider(clouds_vbox, "Cloud Dither", 0.0, 1.0, _c_dither[0], func(v): planet.cloud_dither = v; _c_dither[0] = v)
	_add_slider(clouds_vbox, "Cloud Coverage", 0.0, 1.0, _c_coverage[0], func(v): planet.cloud_coverage = v; _c_coverage[0] = v)
	_add_slider(clouds_vbox, "Cloud Drift Speed", -0.005, 0.005, _c_speed[0], func(v): planet.cloud_speed = v; _c_speed[0] = v)
	_add_slider(clouds_vbox, "Cloud Noise Speed", -0.005, 0.005, _c_noise_speed[0], func(v): planet.cloud_noise_speed = v; _c_noise_speed[0] = v)
	_add_slider(clouds_vbox, "Noise Follow Cloud", 0.0, 1.5, _c_noise_follow[0], func(v): planet.cloud_noise_follow = v; _c_noise_follow[0] = v)
	_add_slider(clouds_vbox, "Cloud Shadow Intensity", 0.0, 1.0, _c_shadow_intensity[0], func(v): planet.cloud_shadow_intensity = v; _c_shadow_intensity[0] = v)
	_add_slider(clouds_vbox, "Cloud Self-Shadowing", 0.0, 2.0, _c_self_shadow_intensity[0], func(v): planet.cloud_self_shadow_intensity = v; _c_self_shadow_intensity[0] = v)
	_add_slider(clouds_vbox, "Terminator Shadow Depth", 0.0, 2.0, _c_terminator_depth[0], func(v): planet.cloud_terminator_depth = v; _c_terminator_depth[0] = v)
	_add_slider(clouds_vbox, "Terminator Softness", 0.02, 0.4, _c_terminator_softness[0], func(v): planet.cloud_terminator_softness = v; _c_terminator_softness[0] = v)
	_add_slider(clouds_vbox, "Cloud Terminator Shift", -0.3, 0.3, _c_terminator_offset[0], func(v): planet.cloud_terminator_offset = v; _c_terminator_offset[0] = v)
	_add_slider(clouds_vbox, "Sunset Cloud Tint", 0.0, 1.0, _c_sunset_tint[0], func(v): planet.cloud_sunset_tint = v; _c_sunset_tint[0] = v)
	_add_slider(clouds_vbox, "Day Brightness", 0.5, 5.0, _c_day_bright[0], func(v): planet.cloud_day_brightness = v; _c_day_bright[0] = v)
	_add_slider(clouds_vbox, "Night Brightness", 0.0, 0.5, _c_night_bright[0], func(v): planet.cloud_night_brightness = v; _c_night_bright[0] = v)
	_add_slider(clouds_vbox, "Map Height Factor", 0.0, 1.0, _c_map_height[0], func(v): planet.cloud_map_height = v; _c_map_height[0] = v)
	_add_slider(clouds_vbox, "Map Density Factor", 0.0, 1.0, _c_map_density[0], func(v): planet.cloud_map_density = v; _c_map_density[0] = v)

	_add_slider(clouds_vbox, "Horizontal Edge Warping (Ruffles)", 0.0, 2.0, _c_edge_noise[0], func(v): planet.cloud_edge_noise = v; _c_edge_noise[0] = v)

	var lbl_noise := Label.new()
	lbl_noise.text = "=== 3D Multi-Layer Noise Editor ==="
	lbl_noise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clouds_vbox.add_child(lbl_noise)

	_add_slider(clouds_vbox, "Cloud Noise Amount", 0.0, 1.5, _c_noise_amount[0], func(v): planet.cloud_noise_amount = v; _c_noise_amount[0] = v)

	var _btn_add_noise := _add_button(clouds_vbox, "➕ Add Noise Layer", func():
		_add_next_noise_layer()
	)

	# Layer 1
	var l1_box := _add_collapsible_section(clouds_vbox, "Layer 1: Macro Shape (Base)", true)
	_add_checkbox(l1_box, "Enable Layer 1", _c_l1_enabled[0], func(v): planet.noise_l1_enabled = v; _c_l1_enabled[0] = v)
	_add_slider(l1_box, "L1 Scale", 20.0, 1000.0, _c_l1_scale[0], func(v): planet.noise_l1_scale = v; _c_l1_scale[0] = v)
	_add_slider(l1_box, "L1 Strength", 0.0, 1.0, _c_l1_strength[0], func(v): planet.noise_l1_strength = v; _c_l1_strength[0] = v)
	_add_slider(l1_box, "L1 Edge-Only vs Full", 0.0, 1.0, _c_l1_edge_only[0], func(v): planet.noise_l1_edge_only = v; _c_l1_edge_only[0] = v)
	_add_channel_selector(l1_box, "L1 Channel", _c_l1_ch[0], func(v): planet.noise_l1_channel = v; _c_l1_ch[0] = v)

	# Layer 2
	var l2_box := _add_collapsible_section(clouds_vbox, "Layer 2: Meso Erosion (Billows)", true)
	_add_checkbox(l2_box, "Enable Layer 2", _c_l2_enabled[0], func(v): planet.noise_l2_enabled = v; _c_l2_enabled[0] = v)
	_add_slider(l2_box, "L2 Scale", 50.0, 2000.0, _c_l2_scale[0], func(v): planet.noise_l2_scale = v; _c_l2_scale[0] = v)
	_add_slider(l2_box, "L2 Strength", 0.0, 1.0, _c_l2_strength[0], func(v): planet.noise_l2_strength = v; _c_l2_strength[0] = v)
	_add_slider(l2_box, "L2 Edge-Only vs Full", 0.0, 1.0, _c_l2_edge_only[0], func(v): planet.noise_l2_edge_only = v; _c_l2_edge_only[0] = v)
	_add_channel_selector(l2_box, "L2 Channel", _c_l2_ch[0], func(v): planet.noise_l2_channel = v; _c_l2_ch[0] = v)

	# Layer 3
	var l3_data := _add_collapsible_section_container(clouds_vbox, "Layer 3: Cauliflower Detail", true)
	_layer_section_wrappers[3] = l3_data.wrapper
	l3_data.wrapper.visible = _c_l3_enabled[0]
	_add_checkbox(l3_data.content, "Enable Layer 3", _c_l3_enabled[0], func(v): planet.noise_l3_enabled = v; _c_l3_enabled[0] = v)
	_add_slider(l3_data.content, "L3 Scale", 100.0, 3000.0, _c_l3_scale[0], func(v): planet.noise_l3_scale = v; _c_l3_scale[0] = v)
	_add_slider(l3_data.content, "L3 Strength", 0.0, 1.0, _c_l3_strength[0], func(v): planet.noise_l3_strength = v; _c_l3_strength[0] = v)
	_add_slider(l3_data.content, "L3 Edge-Only vs Full", 0.0, 1.0, _c_l3_edge_only[0], func(v): planet.noise_l3_edge_only = v; _c_l3_edge_only[0] = v)
	_add_channel_selector(l3_data.content, "L3 Channel", _c_l3_ch[0], func(v): planet.noise_l3_channel = v; _c_l3_ch[0] = v)
	_add_button(l3_data.content, "🗑 Remove Layer 3", func():
		planet.noise_l3_enabled = false
		_c_l3_enabled[0] = false
		l3_data.wrapper.visible = false
	)

	# Layer 4
	var l4_data := _add_collapsible_section_container(clouds_vbox, "Layer 4: Micro Turbulence / Wisps", true)
	_layer_section_wrappers[4] = l4_data.wrapper
	l4_data.wrapper.visible = _c_l4_enabled[0]
	_add_checkbox(l4_data.content, "Enable Layer 4", _c_l4_enabled[0], func(v): planet.noise_l4_enabled = v; _c_l4_enabled[0] = v)
	_add_slider(l4_data.content, "L4 Scale", 200.0, 4000.0, _c_l4_scale[0], func(v): planet.noise_l4_scale = v; _c_l4_scale[0] = v)
	_add_slider(l4_data.content, "L4 Strength", 0.0, 1.0, _c_l4_strength[0], func(v): planet.noise_l4_strength = v; _c_l4_strength[0] = v)
	_add_slider(l4_data.content, "L4 Edge-Only vs Full", 0.0, 1.0, _c_l4_edge_only[0], func(v): planet.noise_l4_edge_only = v; _c_l4_edge_only[0] = v)
	_add_channel_selector(l4_data.content, "L4 Channel", _c_l4_ch[0], func(v): planet.noise_l4_channel = v; _c_l4_ch[0] = v)
	_add_button(l4_data.content, "🗑 Remove Layer 4", func():
		planet.noise_l4_enabled = false
		_c_l4_enabled[0] = false
		l4_data.wrapper.visible = false
	)

	# Layer 5
	var l5_data := _add_collapsible_section_container(clouds_vbox, "Layer 5: High-Frequency Grain", true)
	_layer_section_wrappers[5] = l5_data.wrapper
	l5_data.wrapper.visible = _c_l5_enabled[0]
	_add_checkbox(l5_data.content, "Enable Layer 5", _c_l5_enabled[0], func(v): planet.noise_l5_enabled = v; _c_l5_enabled[0] = v)
	_add_slider(l5_data.content, "L5 Scale", 300.0, 6000.0, _c_l5_scale[0], func(v): planet.noise_l5_scale = v; _c_l5_scale[0] = v)
	_add_slider(l5_data.content, "L5 Strength", 0.0, 1.0, _c_l5_strength[0], func(v): planet.noise_l5_strength = v; _c_l5_strength[0] = v)
	_add_slider(l5_data.content, "L5 Edge-Only vs Full", 0.0, 1.0, _c_l5_edge_only[0], func(v): planet.noise_l5_edge_only = v; _c_l5_edge_only[0] = v)
	_add_channel_selector(l5_data.content, "L5 Channel", _c_l5_ch[0], func(v): planet.noise_l5_channel = v; _c_l5_ch[0] = v)
	_add_button(l5_data.content, "🗑 Remove Layer 5", func():
		planet.noise_l5_enabled = false
		_c_l5_enabled[0] = false
		l5_data.wrapper.visible = false
	)

	# Layer 6
	var l6_data := _add_collapsible_section_container(clouds_vbox, "Layer 6: Cirrus Fibers", true)
	_layer_section_wrappers[6] = l6_data.wrapper
	l6_data.wrapper.visible = _c_l6_enabled[0]
	_add_checkbox(l6_data.content, "Enable Layer 6", _c_l6_enabled[0], func(v): planet.noise_l6_enabled = v; _c_l6_enabled[0] = v)
	_add_slider(l6_data.content, "L6 Scale", 400.0, 8000.0, _c_l6_scale[0], func(v): planet.noise_l6_scale = v; _c_l6_scale[0] = v)
	_add_slider(l6_data.content, "L6 Strength", 0.0, 1.0, _c_l6_strength[0], func(v): planet.noise_l6_strength = v; _c_l6_strength[0] = v)
	_add_slider(l6_data.content, "L6 Edge-Only vs Full", 0.0, 1.0, _c_l6_edge_only[0], func(v): planet.noise_l6_edge_only = v; _c_l6_edge_only[0] = v)
	_add_channel_selector(l6_data.content, "L6 Channel", _c_l6_ch[0], func(v): planet.noise_l6_channel = v; _c_l6_ch[0] = v)
	_add_button(l6_data.content, "🗑 Remove Layer 6", func():
		planet.noise_l6_enabled = false
		_c_l6_enabled[0] = false
		l6_data.wrapper.visible = false
	)

	# Layer 7
	var l7_data := _add_collapsible_section_container(clouds_vbox, "Layer 7: Micro Erosion", true)
	_layer_section_wrappers[7] = l7_data.wrapper
	l7_data.wrapper.visible = _c_l7_enabled[0]
	_add_checkbox(l7_data.content, "Enable Layer 7", _c_l7_enabled[0], func(v): planet.noise_l7_enabled = v; _c_l7_enabled[0] = v)
	_add_slider(l7_data.content, "L7 Scale", 500.0, 10000.0, _c_l7_scale[0], func(v): planet.noise_l7_scale = v; _c_l7_scale[0] = v)
	_add_slider(l7_data.content, "L7 Strength", 0.0, 1.0, _c_l7_strength[0], func(v): planet.noise_l7_strength = v; _c_l7_strength[0] = v)
	_add_slider(l7_data.content, "L7 Edge-Only vs Full", 0.0, 1.0, _c_l7_edge_only[0], func(v): planet.noise_l7_edge_only = v; _c_l7_edge_only[0] = v)
	_add_channel_selector(l7_data.content, "L7 Channel", _c_l7_ch[0], func(v): planet.noise_l7_channel = v; _c_l7_ch[0] = v)
	_add_button(l7_data.content, "🗑 Remove Layer 7", func():
		planet.noise_l7_enabled = false
		_c_l7_enabled[0] = false
		l7_data.wrapper.visible = false
	)

	# Layer 8
	var l8_data := _add_collapsible_section_container(clouds_vbox, "Layer 8: Fine Dust", true)
	_layer_section_wrappers[8] = l8_data.wrapper
	l8_data.wrapper.visible = _c_l8_enabled[0]
	_add_checkbox(l8_data.content, "Enable Layer 8", _c_l8_enabled[0], func(v): planet.noise_l8_enabled = v; _c_l8_enabled[0] = v)
	_add_slider(l8_data.content, "L8 Scale", 600.0, 12000.0, _c_l8_scale[0], func(v): planet.noise_l8_scale = v; _c_l8_scale[0] = v)
	_add_slider(l8_data.content, "L8 Strength", 0.0, 1.0, _c_l8_strength[0], func(v): planet.noise_l8_strength = v; _c_l8_strength[0] = v)
	_add_slider(l8_data.content, "L8 Edge-Only vs Full", 0.0, 1.0, _c_l8_edge_only[0], func(v): planet.noise_l8_edge_only = v; _c_l8_edge_only[0] = v)
	_add_channel_selector(l8_data.content, "L8 Channel", _c_l8_ch[0], func(v): planet.noise_l8_channel = v; _c_l8_ch[0] = v)
	_add_button(l8_data.content, "🗑 Remove Layer 8", func():
		planet.noise_l8_enabled = false
		_c_l8_enabled[0] = false
		l8_data.wrapper.visible = false
	)

	var lbl_opt := Label.new()
	lbl_opt.text = "--- Performance & Scaling ---"
	lbl_opt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clouds_vbox.add_child(lbl_opt)
	_add_slider(clouds_vbox, "Cloud Raymarch Steps", 4.0, 48.0, float(_c_samples[0]), func(v): planet.cloud_samples = int(v); _c_samples[0] = int(v))
	_add_slider(clouds_vbox, "Render Scale (Buffer)", 0.25, 1.0, _render_scale[0], func(v): planet.render_scale = v; _render_scale[0] = v)

	# Section 2: Atmosphere
	var atmo_vbox = _add_collapsible_section(body_vbox, "Atmosphere", true)
	_add_checkbox(atmo_vbox, "Enable Atmosphere", _atmo_enabled[0], func(v): planet.atmosphere_enabled = v; _atmo_enabled[0] = v)
	_add_slider(atmo_vbox, "Atmosphere Scale", 1.01, 1.15, _atmo_scale[0], func(v): planet.atmosphere_scale = v; _atmo_scale[0] = v)
	_add_slider(atmo_vbox, "Sun Intensity", 0.1, 5.0, _sun_intensity[0], func(v): planet.sun_intensity = v; _sun_intensity[0] = v)
	_add_slider(atmo_vbox, "Rayleigh Height", 0.001, 0.08, _hr[0], func(v): planet.scale_height_rayleigh = v; _hr[0] = v)
	_add_slider(atmo_vbox, "Mie Height", 0.001, 0.04, _hm[0], func(v): planet.scale_height_mie = v; _hm[0] = v)
	_add_slider(atmo_vbox, "Godray Intensity", 0.0, 3.0, _godray_intensity[0], func(v): planet.godray_intensity = v; _godray_intensity[0] = v)

	# Section 3: Eye Adaptation & Skybox
	var adapt_vbox = _add_collapsible_section(body_vbox, "Eye Adaptation & Skybox", true)
	_add_checkbox(adapt_vbox, "Enable Eye Adaptation", _eye_adapt_enabled[0], func(v): planet.eye_adaptation_enabled = v; _eye_adapt_enabled[0] = v)
	_add_slider(adapt_vbox, "Adaptation Speed", 0.5, 8.0, _eye_adapt_speed[0], func(v): planet.eye_adaptation_speed = v; _eye_adapt_speed[0] = v)
	_add_slider(adapt_vbox, "Skybox Max Energy (Dark)", 0.0, 3.0, _sky_max_energy[0], func(v): planet.skybox_max_energy = v; _sky_max_energy[0] = v)
	_add_slider(adapt_vbox, "Skybox Min Energy (Day)", 0.0, 0.5, _sky_min_energy[0], func(v): planet.skybox_min_energy = v; _sky_min_energy[0] = v)
	_add_slider(adapt_vbox, "Auto Exposure Scale", 0.1, 1.5, _auto_exp_scale[0], func(v): planet.auto_exposure_scale = v; _auto_exp_scale[0] = v)

	_lbl_adapt_status = Label.new()
	_lbl_adapt_status.text = "Perceived: 0.00  |  Sky Energy: 1.20"
	adapt_vbox.add_child(_lbl_adapt_status)

	# Section 4: Ocean
	var ocean_vbox = _add_collapsible_section(body_vbox, "Ocean", true)
	_add_checkbox(ocean_vbox, "Enable Ocean", _ocean_enabled[0], func(v): planet.ocean_enabled = v; _ocean_enabled[0] = v)
	_add_slider(ocean_vbox, "Ocean Altitude", -3.0, 3.0, _ocean_altitude[0], func(v): planet.ocean_altitude = v; _ocean_altitude[0] = v)
	_add_slider(ocean_vbox, "Ocean Bed Sink", 0.0, 1.5, _ocean_sink[0], func(v): planet.ocean_bed_sink = v; _ocean_sink[0] = v)
	_add_slider(ocean_vbox, "Depth Distance", 0.5, 20.0, _ocean_depth_dist[0], func(v): planet.ocean_depth_distance = v; _ocean_depth_dist[0] = v)
	_add_slider(ocean_vbox, "Wave Amplitude", 0.0, 1.5, _wave_amplitude[0], func(v): planet.wave_amplitude = v; _wave_amplitude[0] = v)
	_add_slider(ocean_vbox, "Wave Speed", 0.1, 4.0, _wave_speed[0], func(v): planet.wave_speed = v; _wave_speed[0] = v)
	_add_slider(ocean_vbox, "Foam Intensity", 0.0, 2.0, _foam_intensity[0], func(v): planet.foam_intensity = v; _foam_intensity[0] = v)
	_add_checkbox(ocean_vbox, "SSR Reflections", _ssr_enabled[0], func(v): planet.ssr_enabled = v; _ssr_enabled[0] = v)

	# Section 5: Terrain & LOD
	var terrain_vbox = _add_collapsible_section(body_vbox, "Terrain & LOD", true)
	_add_slider(terrain_vbox, "Height Scale", 0.0, 80.0, _h_scale[0], func(v): planet.height_scale = v; _h_scale[0] = v)
	_add_slider(terrain_vbox, "Sea Level", 0.45, 0.55, _sea_level[0], func(v): planet.sea_level = v; _sea_level[0] = v)
	_add_slider(terrain_vbox, "LOD Threshold", 1.0, 8.0, _lod_thresh[0], func(v): planet.lod_threshold = v; _lod_thresh[0] = v)

	var lbl_norm := Label.new()
	lbl_norm.text = "--- Terrain Normals & Lighting ---"
	lbl_norm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terrain_vbox.add_child(lbl_norm)
	_add_slider(terrain_vbox, "Normal Map Depth", 0.0, 2.0, _normal_depth[0], func(v): planet.normal_depth = v; _normal_depth[0] = v)
	_add_slider(terrain_vbox, "Orbital Relief Ratio", -1.0, 1.0, _normal_orbital_ratio[0], func(v): planet.normal_orbital_ratio = v; _normal_orbital_ratio[0] = v)
	_add_slider(terrain_vbox, "Slope Filter Threshold", 0.0, 0.5, _normal_slope_thresh[0], func(v): planet.normal_slope_threshold = v; _normal_slope_thresh[0] = v)
	_add_checkbox(terrain_vbox, "Invert Normal Y (DirectX)", _invert_normal_y[0], func(v): planet.invert_normal_y = v; _invert_normal_y[0] = v)

func _add_collapsible_section_container(parent: VBoxContainer, title_text: String, start_open: bool) -> Dictionary:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	var sec_btn := Button.new()
	sec_btn.text = ("▼ " if start_open else "▶ ") + title_text
	sec_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sec_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.16, 0.24, 0.35, 1.0)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(5)
	sec_btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.22, 0.35, 0.52, 1.0)
	hover_style.set_corner_radius_all(3)
	hover_style.set_content_margin_all(5)
	sec_btn.add_theme_stylebox_override("hover", hover_style)

	wrapper.add_child(sec_btn)

	var content := VBoxContainer.new()
	content.visible = start_open
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(content)

	sec_btn.pressed.connect(func():
		content.visible = not content.visible
		sec_btn.text = ("▼ " if content.visible else "▶ ") + title_text
	)

	return {"wrapper": wrapper, "content": content}

func _add_collapsible_section(parent: VBoxContainer, title_text: String, start_open: bool) -> VBoxContainer:
	var sec_btn := Button.new()
	sec_btn.text = ("▼ " if start_open else "▶ ") + title_text
	sec_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sec_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.16, 0.24, 0.35, 1.0)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(5)
	sec_btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.22, 0.35, 0.52, 1.0)
	hover_style.set_corner_radius_all(3)
	hover_style.set_content_margin_all(5)
	sec_btn.add_theme_stylebox_override("hover", hover_style)

	parent.add_child(sec_btn)

	var content := VBoxContainer.new()
	content.visible = start_open
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(content)

	sec_btn.pressed.connect(func():
		content.visible = not content.visible
		sec_btn.text = ("▼ " if content.visible else "▶ ") + title_text
	)

	return content

func _add_checkbox(parent: VBoxContainer, text: String, initial_val: bool, callback: Callable) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = text
	chk.button_pressed = initial_val
	chk.toggled.connect(callback)
	parent.add_child(chk)
	return chk

func _add_slider(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, initial_v: float, callback: Callable) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)

	var span := max_v - min_v
	var fmt := "%.4f" if span <= 0.5 else "%.2f"

	var l := Label.new()
	l.text = ("%s: " + fmt) % [label_text, initial_v]
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)

	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = span / 400.0 if span <= 0.5 else span / 100.0
	s.value = initial_v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(val):
		l.text = ("%s: " + fmt) % [label_text, val]
		callback.call(val)
	)
	h.add_child(s)

func _add_channel_selector(parent: VBoxContainer, label_text: String, initial_ch: int, callback: Callable) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label_text + ": "
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	opt.add_item("Red (R) - Base Billow", 0)
	opt.add_item("Green (G) - Low Freq", 1)
	opt.add_item("Blue (B) - Med Freq", 2)
	opt.add_item("Alpha (A) - High Freq", 3)
	opt.select(clampi(initial_ch, 0, 3))
	opt.item_selected.connect(func(idx): callback.call(idx))
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(opt)

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.18, 0.42, 0.28, 1.0)
	b_style.set_corner_radius_all(3)
	b_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", b_style)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn
