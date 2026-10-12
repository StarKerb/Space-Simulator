extends Node

var planet: Node3D
var _im: Object = null

# Internal storage arrays for ImGui pass-by-reference
var _c_enabled := [true]
var _c_invert := [false]
var _c_altitude := [6.0]
var _c_thickness := [5.0]
var _c_density := [1.0]
var _c_coverage := [0.75]
var _c_speed := [0.001]
var _c_day_bright := [2.0]
var _c_night_bright := [0.0]
var _c_map_height := [0.8]
var _c_map_density := [1.0]
var _c_noise_base_scale := [160.0]
var _c_noise_base_strength := [0.28]
var _c_noise_detail_scale := [480.0]
var _c_noise_detail_strength := [0.15]

var _atmo_enabled := [true]
var _atmo_scale := [1.06]
var _sun_intensity := [2.0]
var _hr := [0.015]
var _hm := [0.008]

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

var _h_scale := [25.0]
var _sea_level := [0.485]
var _max_lod := [6]
var _lod_thresh := [3.5]

var _imgui_connected := false
var _show_ui := true
var _canvas_ui: CanvasLayer

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
	if "cloud_coverage" in planet: _c_coverage[0] = planet.cloud_coverage
	if "cloud_speed" in planet: _c_speed[0] = planet.cloud_speed
	if "cloud_day_brightness" in planet: _c_day_bright[0] = planet.cloud_day_brightness
	if "cloud_night_brightness" in planet: _c_night_bright[0] = planet.cloud_night_brightness
	if "cloud_map_height" in planet: _c_map_height[0] = planet.cloud_map_height
	if "cloud_map_density" in planet: _c_map_density[0] = planet.cloud_map_density
	if "noise_base_scale" in planet: _c_noise_base_scale[0] = planet.noise_base_scale
	if "noise_base_strength" in planet: _c_noise_base_strength[0] = planet.noise_base_strength
	if "noise_detail_scale" in planet: _c_noise_detail_scale[0] = planet.noise_detail_scale
	if "noise_detail_strength" in planet: _c_noise_detail_strength[0] = planet.noise_detail_strength

	if "atmosphere_enabled" in planet: _atmo_enabled[0] = planet.atmosphere_enabled
	if "atmosphere_scale" in planet: _atmo_scale[0] = planet.atmosphere_scale
	if "sun_intensity" in planet: _sun_intensity[0] = planet.sun_intensity
	if "scale_height_rayleigh" in planet: _hr[0] = planet.scale_height_rayleigh
	if "scale_height_mie" in planet: _hm[0] = planet.scale_height_mie

	if "eye_adaptation_enabled" in planet: _eye_adapt_enabled[0] = planet.eye_adaptation_enabled
	if "eye_adaptation_speed" in planet: _eye_adapt_speed[0] = planet.eye_adaptation_speed
	if "skybox_max_energy" in planet: _sky_max_energy[0] = planet.skybox_max_energy
	if "skybox_min_energy" in planet: _sky_min_energy[0] = planet.skybox_min_energy
	if "auto_exposure_scale" in planet: _auto_exp_scale[0] = planet.auto_exposure_scale

	if "ocean_enabled" in planet: _ocean_enabled[0] = planet.ocean_enabled
	if "ocean_altitude" in planet: _ocean_altitude[0] = planet.ocean_altitude
	if "ocean_bed_sink" in planet: _ocean_sink[0] = planet.ocean_bed_sink
	if "ocean_depth_distance" in planet: _ocean_depth_dist[0] = planet.ocean_depth_distance

	if "height_scale" in planet: _h_scale[0] = planet.height_scale
	if "sea_level" in planet: _sea_level[0] = planet.sea_level
	if "max_lod" in planet: _max_lod[0] = planet.max_lod
	if "lod_threshold" in planet: _lod_thresh[0] = planet.lod_threshold

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

func _process(_delta: float) -> void:
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

	if _im.CollapsingHeader("Volumetric Clouds"):
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
		if _im.SliderFloat("Cloud Coverage", _c_coverage, 0.0, 1.0):
			planet.cloud_coverage = _c_coverage[0]
		if _im.SliderFloat("Cloud Drift Speed", _c_speed, -0.005, 0.005):
			planet.cloud_speed = _c_speed[0]
		if _im.SliderFloat("Day Brightness", _c_day_bright, 0.5, 5.0):
			planet.cloud_day_brightness = _c_day_bright[0]
		if _im.SliderFloat("Night Brightness", _c_night_bright, 0.0, 0.5):
			planet.cloud_night_brightness = _c_night_bright[0]
		if _im.SliderFloat("Map Height Factor", _c_map_height, 0.0, 1.0):
			planet.cloud_map_height = _c_map_height[0]
		if _im.SliderFloat("Map Density Factor", _c_map_density, 0.0, 1.0):
			planet.cloud_map_density = _c_map_density[0]

		_im.Separator()
		_im.Text("3D Noise Layers (Stackable):")
		if _im.SliderFloat("Base Noise Scale", _c_noise_base_scale, 10.0, 800.0):
			planet.noise_base_scale = _c_noise_base_scale[0]
		if _im.SliderFloat("Base Noise Strength", _c_noise_base_strength, 0.0, 1.0):
			planet.noise_base_strength = _c_noise_base_strength[0]
		if _im.SliderFloat("Detail Noise Scale", _c_noise_detail_scale, 50.0, 1500.0):
			planet.noise_detail_scale = _c_noise_detail_scale[0]
		if _im.SliderFloat("Detail Noise Strength", _c_noise_detail_strength, 0.0, 1.0):
			planet.noise_detail_strength = _c_noise_detail_strength[0]

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

	if _im.CollapsingHeader("Terrain & LOD"):
		if _im.SliderFloat("Height Scale", _h_scale, 0.0, 80.0):
			planet.height_scale = _h_scale[0]
		if _im.SliderFloat("Sea Level", _sea_level, 0.45, 0.55):
			planet.sea_level = _sea_level[0]
		if _im.SliderFloat("LOD Threshold", _lod_thresh, 1.0, 8.0):
			planet.lod_threshold = _lod_thresh[0]

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

	# Section 1: Volumetric Clouds
	var clouds_vbox = _add_collapsible_section(body_vbox, "Volumetric Clouds", true)
	_add_checkbox(clouds_vbox, "Enable Clouds", _c_enabled[0], func(v): planet.cloud_enabled = v; _c_enabled[0] = v)
	_add_checkbox(clouds_vbox, "Invert Alpha (Transparent = Clouds)", _c_invert[0], func(v): planet.invert_clouds = v; _c_invert[0] = v)
	_add_slider(clouds_vbox, "Cloud Altitude", 0.0, 30.0, _c_altitude[0], func(v): planet.cloud_altitude = v; _c_altitude[0] = v)
	_add_slider(clouds_vbox, "Cloud Thickness", 0.5, 20.0, _c_thickness[0], func(v): planet.cloud_thickness = v; _c_thickness[0] = v)
	_add_slider(clouds_vbox, "Cloud Density", 0.05, 5.0, _c_density[0], func(v): planet.cloud_density = v; _c_density[0] = v)
	_add_slider(clouds_vbox, "Cloud Coverage", 0.0, 1.0, _c_coverage[0], func(v): planet.cloud_coverage = v; _c_coverage[0] = v)
	_add_slider(clouds_vbox, "Cloud Drift Speed", -0.005, 0.005, _c_speed[0], func(v): planet.cloud_speed = v; _c_speed[0] = v)
	_add_slider(clouds_vbox, "Day Brightness", 0.5, 5.0, _c_day_bright[0], func(v): planet.cloud_day_brightness = v; _c_day_bright[0] = v)
	_add_slider(clouds_vbox, "Night Brightness", 0.0, 0.5, _c_night_bright[0], func(v): planet.cloud_night_brightness = v; _c_night_bright[0] = v)
	_add_slider(clouds_vbox, "Map Height Factor", 0.0, 1.0, _c_map_height[0], func(v): planet.cloud_map_height = v; _c_map_height[0] = v)
	_add_slider(clouds_vbox, "Map Density Factor", 0.0, 1.0, _c_map_density[0], func(v): planet.cloud_map_density = v; _c_map_density[0] = v)

	var lbl_noise := Label.new()
	lbl_noise.text = "--- 3D Noise Layers (Stackable) ---"
	lbl_noise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clouds_vbox.add_child(lbl_noise)
	_add_slider(clouds_vbox, "Base Noise Scale", 10.0, 800.0, _c_noise_base_scale[0], func(v): planet.noise_base_scale = v; _c_noise_base_scale[0] = v)
	_add_slider(clouds_vbox, "Base Noise Strength", 0.0, 1.0, _c_noise_base_strength[0], func(v): planet.noise_base_strength = v; _c_noise_base_strength[0] = v)
	_add_slider(clouds_vbox, "Detail Noise Scale", 50.0, 1500.0, _c_noise_detail_scale[0], func(v): planet.noise_detail_scale = v; _c_noise_detail_scale[0] = v)
	_add_slider(clouds_vbox, "Detail Noise Strength", 0.0, 1.0, _c_noise_detail_strength[0], func(v): planet.noise_detail_strength = v; _c_noise_detail_strength[0] = v)

	# Section 2: Atmosphere
	var atmo_vbox = _add_collapsible_section(body_vbox, "Atmosphere", true)
	_add_checkbox(atmo_vbox, "Enable Atmosphere", _atmo_enabled[0], func(v): planet.atmosphere_enabled = v; _atmo_enabled[0] = v)
	_add_slider(atmo_vbox, "Atmosphere Scale", 1.01, 1.15, _atmo_scale[0], func(v): planet.atmosphere_scale = v; _atmo_scale[0] = v)
	_add_slider(atmo_vbox, "Sun Intensity", 0.1, 5.0, _sun_intensity[0], func(v): planet.sun_intensity = v; _sun_intensity[0] = v)
	_add_slider(atmo_vbox, "Rayleigh Height", 0.001, 0.08, _hr[0], func(v): planet.scale_height_rayleigh = v; _hr[0] = v)
	_add_slider(atmo_vbox, "Mie Height", 0.001, 0.04, _hm[0], func(v): planet.scale_height_mie = v; _hm[0] = v)

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

	# Section 5: Terrain & LOD
	var terrain_vbox = _add_collapsible_section(body_vbox, "Terrain & LOD", true)
	_add_slider(terrain_vbox, "Height Scale", 0.0, 80.0, _h_scale[0], func(v): planet.height_scale = v; _h_scale[0] = v)
	_add_slider(terrain_vbox, "Sea Level", 0.45, 0.55, _sea_level[0], func(v): planet.sea_level = v; _sea_level[0] = v)
	_add_slider(terrain_vbox, "LOD Threshold", 1.0, 8.0, _lod_thresh[0], func(v): planet.lod_threshold = v; _lod_thresh[0] = v)

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

	var l := Label.new()
	l.text = "%s: %.2f" % [label_text, initial_v]
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)

	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = (max_v - min_v) / 100.0
	s.value = initial_v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(val):
		l.text = "%s: %.2f" % [label_text, val]
		callback.call(val)
	)
	h.add_child(s)
