class_name FlightHUD
extends CanvasLayer

## KSP-Style Flight HUD & Orbital Diagnostics Overlay.

const OrbitalMechanics = preload("res://scripts/orbital_mechanics.gd")

@export var craft: Spacecraft

var _lbl_speed: Label
var _lbl_alt: Label
var _lbl_warp: Label
var _lbl_pe: Label
var _lbl_ap: Label
var _lbl_orbit_info: Label
var _lbl_sas: Label
var _lbl_throttle: Label
var _lbl_mode: Label
var _throttle_bar: ProgressBar

func _ready() -> void:
	layer = 10
	_build_ui()

	if craft:
		craft.throttle_changed.connect(_on_throttle_changed)
		craft.orbit_updated.connect(_on_orbit_updated)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- TOP TELEMETRY BAR ---
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.offset_top = 18
	top_panel.offset_left = -260
	top_panel.offset_right = 260
	top_panel.offset_bottom = 90
	root.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_panel.add_child(top_vbox)

	_lbl_mode = Label.new()
	_lbl_mode.text = "APOLLO CSM // ORBITAL FLIGHT (M for Map Mode)"
	_lbl_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_mode.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_lbl_mode.add_theme_font_size_override("font_size", 13)
	top_vbox.add_child(_lbl_mode)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_child(top_hbox)

	_lbl_speed = Label.new()
	_lbl_speed.text = "SPEED: 7,730 m/s"
	_lbl_speed.add_theme_font_size_override("font_size", 18)
	top_hbox.add_child(_lbl_speed)

	var sep1 := VSeparator.new()
	top_hbox.add_child(sep1)

	_lbl_alt = Label.new()
	_lbl_alt.text = "ALT: 300.0 km"
	_lbl_alt.add_theme_font_size_override("font_size", 18)
	top_hbox.add_child(_lbl_alt)

	var sep2 := VSeparator.new()
	top_hbox.add_child(sep2)

	_lbl_warp = Label.new()
	_lbl_warp.text = "WARP: 1x (1:1)"
	_lbl_warp.add_theme_font_size_override("font_size", 18)
	_lbl_warp.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	top_hbox.add_child(_lbl_warp)

	# --- BOTTOM-LEFT ORBITAL MECHANICS (PATCHED CONICS) PANEL ---
	var orbit_panel := PanelContainer.new()
	orbit_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	orbit_panel.offset_left = 20
	orbit_panel.offset_bottom = -20
	orbit_panel.offset_top = -210
	orbit_panel.offset_right = 320
	root.add_child(orbit_panel)

	var orbit_vbox := VBoxContainer.new()
	orbit_panel.add_child(orbit_vbox)

	var orbit_header := Label.new()
	orbit_header.text = "KEPLERIAN ORBIT (PATCHED CONICS)"
	orbit_header.add_theme_color_override("font_color", Color(0.2, 0.9, 0.6))
	orbit_header.add_theme_font_size_override("font_size", 13)
	orbit_vbox.add_child(orbit_header)

	_lbl_pe = Label.new()
	_lbl_pe.text = "Periapsis (Pe): 300.0 km"
	_lbl_pe.add_theme_color_override("font_color", Color(0.0, 1.0, 0.7))
	orbit_vbox.add_child(_lbl_pe)

	_lbl_ap = Label.new()
	_lbl_ap.text = "Apoapsis (Ap): 300.0 km"
	_lbl_ap.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	orbit_vbox.add_child(_lbl_ap)

	_lbl_orbit_info = Label.new()
	_lbl_orbit_info.text = "Eccentricity: 0.000\nPeriod: 90m 20s\nInc: 0.0 deg | Type: Circular"
	orbit_vbox.add_child(_lbl_orbit_info)

	_lbl_sas = Label.new()
	_lbl_sas.text = "SAS: ACTIVE (T to toggle)"
	_lbl_sas.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	orbit_vbox.add_child(_lbl_sas)

	# --- BOTTOM-CENTER THROTTLE GAUGE (KSP-STYLE) ---
	var throttle_panel := PanelContainer.new()
	throttle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	throttle_panel.offset_left = -110
	throttle_panel.offset_right = 110
	throttle_panel.offset_top = -140
	throttle_panel.offset_bottom = -20
	root.add_child(throttle_panel)

	var throttle_vbox := VBoxContainer.new()
	throttle_panel.add_child(throttle_vbox)

	_lbl_throttle = Label.new()
	_lbl_throttle.text = "THROTTLE: 0%"
	_lbl_throttle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_throttle.add_theme_font_size_override("font_size", 15)
	throttle_vbox.add_child(_lbl_throttle)

	_throttle_bar = ProgressBar.new()
	_throttle_bar.min_value = 0.0
	_throttle_bar.max_value = 1.0
	_throttle_bar.step = 0.01
	_throttle_bar.value = 0.0
	_throttle_bar.show_percentage = false
	_throttle_bar.custom_minimum_size = Vector2(180, 24)
	throttle_vbox.add_child(_throttle_bar)

	var throttle_hint := Label.new()
	throttle_hint.text = "Shift/Ctrl: Adjust\nZ: 100% | X: Cut"
	throttle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	throttle_hint.add_theme_font_size_override("font_size", 11)
	throttle_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	throttle_vbox.add_child(throttle_hint)

	# --- BOTTOM-RIGHT CONTROLS GUIDE ---
	var guide_panel := PanelContainer.new()
	guide_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	guide_panel.offset_right = -20
	guide_panel.offset_bottom = -20
	guide_panel.offset_left = -280
	guide_panel.offset_top = -180
	root.add_child(guide_panel)

	var guide_vbox := VBoxContainer.new()
	guide_panel.add_child(guide_vbox)

	var guide_title := Label.new()
	guide_title.text = "FLIGHT CONTROLS (KSP)"
	guide_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	guide_title.add_theme_font_size_override("font_size", 13)
	guide_vbox.add_child(guide_title)

	var guide_text := Label.new()
	guide_text.text = "W / S : Pitch Nose Down / Up\nA / D : Yaw Nose Left / Right\nQ / E : Roll CCW / CW\nShift / Ctrl : Throttle Up / Down\nZ / X : Max / Cut Throttle\n, / . : Timewarp (- / +)\n/ : Timewarp 1x\nM : Toggle Map Mode\nT : Toggle SAS Stability\nRMB + Drag : Rotate View\nMouse Wheel : Zoom"
	guide_text.add_theme_font_size_override("font_size", 12)
	guide_vbox.add_child(guide_text)

func set_map_mode(is_map: bool) -> void:
	if _lbl_mode:
		if is_map:
			_lbl_mode.text = "MAP MODE // GLOBAL TRAJECTORY (M to Exit)"
			_lbl_mode.add_theme_color_override("font_color", Color(0.2, 1.0, 0.7))
		else:
			_lbl_mode.text = "APOLLO CSM // ORBITAL FLIGHT (M for Map Mode)"
			_lbl_mode.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

func set_timewarp(rate: float, is_physics: bool = false) -> void:
	if _lbl_warp:
		if rate <= 1.0:
			_lbl_warp.text = "WARP: 1x (Realtime)"
			_lbl_warp.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		elif is_physics:
			_lbl_warp.text = "WARP: %dx (Physics Warp)" % int(rate)
			_lbl_warp.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
		else:
			_lbl_warp.text = "WARP: %dx (On-Rails)" % int(rate)
			_lbl_warp.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func _process(_delta: float) -> void:
	if craft and is_instance_valid(craft):
		_lbl_sas.text = "SAS: ACTIVE (T)" if craft.sas_enabled else "SAS: OFF (T)"
		_lbl_sas.add_theme_color_override(
			"font_color",
			Color(0.3, 1.0, 0.4) if craft.sas_enabled else Color(0.7, 0.7, 0.7)
		)

func _on_throttle_changed(t: float) -> void:
	if _throttle_bar:
		_throttle_bar.value = t
	if _lbl_throttle:
		_lbl_throttle.text = "THROTTLE: %d%%" % int(round(t * 100.0))

func _on_orbit_updated(o: Dictionary) -> void:
	if o.is_empty():
		return

	var spd: float = o.get("v", 0.0)
	var pe_alt: float = o.get("periapsis_alt", 0.0)
	var ap_alt: float = o.get("apoapsis_alt", 0.0)
	var r: float = o.get("r", 0.0)
	var pr: float = OrbitalMechanics.EARTH_RADIUS
	var alt: float = r - pr
	var e: float = o.get("eccentricity", 0.0)
	var period: float = o.get("period", 0.0)
	var inc: float = o.get("inclination_deg", 0.0)
	var o_type: String = o.get("orbit_type", "Elliptical")

	if _lbl_speed:
		_lbl_speed.text = "SPEED: %.1f m/s (%.2f km/s)" % [spd, spd / 1000.0]
	if _lbl_alt:
		_lbl_alt.text = "ALT: %.2f km" % (alt / 1000.0)

	if _lbl_pe:
		_lbl_pe.text = "Periapsis (Pe): %.2f km" % (pe_alt / 1000.0)
	if _lbl_ap:
		if is_inf(ap_alt):
			_lbl_ap.text = "Apoapsis (Ap): ESCAPE (Hyperbolic)"
		else:
			_lbl_ap.text = "Apoapsis (Ap): %.2f km" % (ap_alt / 1000.0)

	if _lbl_orbit_info:
		var p_str := "N/A"
		if not is_inf(period) and period > 0.0:
			var mins: int = int(period) / 60
			var secs: int = int(period) % 60
			p_str = "%dm %ds" % [mins, secs]

		_lbl_orbit_info.text = "Eccentricity: %.4f\nPeriod: %s\nInc: %.1f deg | Type: %s" % [
			e, p_str, inc, o_type
		]
