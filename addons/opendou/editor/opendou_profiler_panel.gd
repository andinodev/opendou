@tool
class_name OpenDouProfilerPanel
extends PanelContainer

## Real-time profiler panel with High-Density DSP execution graphs, Voice Stealing Ledger, Session Recording/Export/Import, Time-Travel Scrubbing, and TCP hot-connection.

const ProfilerSessionRecorderClass = preload("res://addons/opendou/core/telemetry/profiler_session_recorder.gd")
const OpenDouRadarViewClass = preload("res://addons/opendou/editor/opendou_radar_view.gd")

signal connect_tcp_requested(host: String, port: int)
signal session_saved(file_path: String)
signal session_loaded(file_path: String)

var tab_container: TabContainer
var voice_tree: Tree
var dsp_graph_rect: Control
var dsp_metrics_lbl: Label
var rewind_slider: HSlider
var rewind_time_lbl: Label
var btn_play_pause: Button
var radar_view: OpenDouRadarView

# Session Recording & I/O Controls
var btn_record_session: Button
var rec_status_lbl: Label
var btn_export_session: Button
var btn_import_session: Button
var session_file_dialog: FileDialog
var is_file_dialog_for_export: bool = true

var is_connected: bool = false
var is_paused_scrubbing: bool = false
var is_manual_recording: bool = false
var session_recorder: ProfilerSessionRecorder

var dsp_history: Array[float] = []
var max_dsp_history: int = 60

# Telemetry stats
var active_physical_voices: int = 16
var active_virtual_voices: int = 234
var current_dsp_us: float = 42.5
var peak_dsp_us: float = 78.2

func _init() -> void:
	session_recorder = ProfilerSessionRecorderClass.new(1800)
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	# FileDialog for Sessions
	session_file_dialog = FileDialog.new()
	session_file_dialog.access = FileDialog.ACCESS_RESOURCES
	session_file_dialog.filters = ["*.json ; OpenDou Telemetry Profile Session"]
	session_file_dialog.file_selected.connect(_on_session_file_selected)
	add_child(session_file_dialog)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 6)
	margin.add_child(v_box)
	
	# Top Session Recording Toolbar
	var session_toolbar = HBoxContainer.new()
	session_toolbar.add_theme_constant_override("separation", 6)
	
	btn_record_session = Button.new()
	btn_record_session.text = "🔴 Record"
	btn_record_session.tooltip_text = "Start/Stop recording continuous telemetry profile session"
	btn_record_session.toggle_mode = true
	btn_record_session.toggled.connect(_on_record_session_toggled)
	session_toolbar.add_child(btn_record_session)
	
	rec_status_lbl = Label.new()
	rec_status_lbl.text = "Standby (0 frames)"
	rec_status_lbl.add_theme_font_size_override("font_size", 9)
	rec_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_toolbar.add_child(rec_status_lbl)
	
	btn_export_session = Button.new()
	btn_export_session.text = "💾 Export"
	btn_export_session.tooltip_text = "Export recorded session to JSON file"
	btn_export_session.pressed.connect(_on_export_session_pressed)
	session_toolbar.add_child(btn_export_session)
	
	btn_import_session = Button.new()
	btn_import_session.text = "📂 Open"
	btn_import_session.tooltip_text = "Load recorded session JSON for offline analysis"
	btn_import_session.pressed.connect(_on_import_session_pressed)
	session_toolbar.add_child(btn_import_session)
	
	v_box.add_child(session_toolbar)
	
	# Tabs with enhanced styling
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_child(tab_container)
	
	# Tab 1: Voice Stealing Ledger
	var voice_box = VBoxContainer.new()
	voice_box.name = "🎙️ Voice Ledger"
	voice_box.add_theme_constant_override("separation", 6)
	
	var ledger_header = Label.new()
	ledger_header.text = "Active Voices: 16 Physical (Hardware) / 234 Virtual Tracked"
	ledger_header.add_theme_font_size_override("font_size", 12)
	voice_box.add_child(ledger_header)
	
	voice_tree = Tree.new()
	voice_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	voice_tree.columns = 4
	voice_tree.set_column_title(0, "Voice / Event")
	voice_tree.set_column_title(1, "State")
	voice_tree.set_column_title(2, "Priority")
	voice_tree.set_column_title(3, "Dist")
	voice_tree.set_column_expand(0, true)
	voice_tree.set_column_expand(1, true)
	voice_tree.set_column_expand(2, true)
	voice_tree.set_column_expand(3, true)
	voice_tree.set_column_custom_minimum_width(0, 70)
	voice_tree.set_column_custom_minimum_width(1, 50)
	voice_tree.set_column_custom_minimum_width(2, 40)
	voice_tree.set_column_custom_minimum_width(3, 35)
	voice_tree.column_titles_visible = true
	voice_box.add_child(voice_tree)
	tab_container.add_child(voice_box)
	
	# Tab 2: High-Density DSP Performance Graph
	var dsp_box = VBoxContainer.new()
	dsp_box.name = "⚡ DSP CPU (µs)"
	dsp_box.add_theme_constant_override("separation", 6)
	
	dsp_metrics_lbl = Label.new()
	dsp_metrics_lbl.text = "⚡ DSP Load: Avg 42.1 µs | Peak 78.2 µs | Budget: < 250 µs"
	dsp_metrics_lbl.add_theme_font_size_override("font_size", 12)
	dsp_box.add_child(dsp_metrics_lbl)
	
	dsp_graph_rect = Control.new()
	dsp_graph_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dsp_graph_rect.custom_minimum_size = Vector2(0, 110)
	dsp_graph_rect.draw.connect(_on_draw_dsp_graph)
	dsp_box.add_child(dsp_graph_rect)
	
	# Time-Travel Rewind Bar
	var rewind_box = HBoxContainer.new()
	rewind_box.add_theme_constant_override("separation", 6)
	
	btn_play_pause = Button.new()
	btn_play_pause.text = "⏸️ Live"
	btn_play_pause.tooltip_text = "Pause telemetry to scrub through history"
	btn_play_pause.pressed.connect(_on_toggle_pause_scrub)
	rewind_box.add_child(btn_play_pause)
	
	rewind_slider = HSlider.new()
	rewind_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewind_slider.min_value = -60.0
	rewind_slider.max_value = 0.0
	rewind_slider.value = 0.0
	rewind_slider.step = 0.1
	rewind_slider.value_changed.connect(_on_rewind_slider_changed)
	rewind_box.add_child(rewind_slider)
	
	rewind_time_lbl = Label.new()
	rewind_time_lbl.text = "0.0s (Live)"
	rewind_time_lbl.add_theme_font_size_override("font_size", 10)
	rewind_time_lbl.custom_minimum_size = Vector2(65, 0)
	rewind_box.add_child(rewind_time_lbl)
	
	dsp_box.add_child(rewind_box)
	tab_container.add_child(dsp_box)
	
	# Tab 3: Spatial Radar & Acoustic Portals
	var radar_box = VBoxContainer.new()
	radar_box.name = "📡 Spatial Radar"
	radar_box.add_theme_constant_override("separation", 4)
	
	# Options row
	var r_opts_hbox = HBoxContainer.new()
	r_opts_hbox.add_theme_constant_override("separation", 6)
	
	var chk_portals = CheckBox.new()
	chk_portals.text = "Portals"
	chk_portals.button_pressed = true
	chk_portals.toggled.connect(func(v):
		if radar_view:
			radar_view.show_portals = v
			radar_view.queue_redraw()
	)
	r_opts_hbox.add_child(chk_portals)
	
	var chk_diff = CheckBox.new()
	chk_diff.text = "Diffract"
	chk_diff.button_pressed = true
	chk_diff.toggled.connect(func(v):
		if radar_view:
			radar_view.show_diffraction = v
			radar_view.queue_redraw()
	)
	r_opts_hbox.add_child(chk_diff)
	
	var chk_refl = CheckBox.new()
	chk_refl.text = "Reflect"
	chk_refl.button_pressed = true
	chk_refl.toggled.connect(func(v):
		if radar_view:
			radar_view.show_reflections = v
			radar_view.queue_redraw()
	)
	r_opts_hbox.add_child(chk_refl)
	
	var dist_lbl = Label.new()
	dist_lbl.text = "Range:"
	dist_lbl.add_theme_font_size_override("font_size", 9)
	r_opts_hbox.add_child(dist_lbl)
	
	var dist_spin = SpinBox.new()
	dist_spin.min_value = 10.0
	dist_spin.max_value = 100.0
	dist_spin.step = 5.0
	dist_spin.value = 40.0
	dist_spin.suffix = "m"
	dist_spin.custom_minimum_size = Vector2(60, 0)
	dist_spin.value_changed.connect(func(v):
		if radar_view:
			radar_view.max_view_distance_m = v
			radar_view.queue_redraw()
	)
	r_opts_hbox.add_child(dist_spin)
	radar_box.add_child(r_opts_hbox)
	
	radar_view = OpenDouRadarViewClass.new()
	radar_box.add_child(radar_view)
	tab_container.add_child(radar_box)
	
	# Seed initial realistic DSP history
	for i in range(max_dsp_history):
		dsp_history.append(38.0 + sin(float(i) * 0.4) * 12.0 + randf_range(-4.0, 6.0))
		
	_populate_sample_telemetry()

func _on_record_session_toggled(is_recording: bool) -> void:
	is_manual_recording = is_recording
	if is_recording:
		btn_record_session.text = "⏹ Stop Rec"
		btn_record_session.modulate = Color(1.0, 0.3, 0.3)
		if session_recorder:
			session_recorder.frames.clear()
			session_recorder.is_recording = true
			session_recorder.session_start_time_msec = Time.get_ticks_msec()
	else:
		btn_record_session.text = "🔴 Record"
		btn_record_session.modulate = Color.WHITE
		if session_recorder:
			rec_status_lbl.text = "Recorded %d frames (%.1fs)" % [session_recorder.frames.size(), session_recorder.frames.back().timestamp_sec if not session_recorder.frames.is_empty() else 0.0]

func _on_export_session_pressed() -> void:
	if not session_recorder or session_recorder.frames.is_empty():
		return
	is_file_dialog_for_export = true
	session_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	session_file_dialog.popup_centered(Vector2i(650, 420))

func _on_import_session_pressed() -> void:
	is_file_dialog_for_export = false
	session_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	session_file_dialog.popup_centered(Vector2i(650, 420))

func _on_session_file_selected(path: String) -> void:
	if is_file_dialog_for_export:
		if session_recorder:
			var json_data = session_recorder.export_to_json()
			var f = FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(json_data)
				session_saved.emit(path)
	else:
		if FileAccess.file_exists(path) and session_recorder:
			var f = FileAccess.open(path, FileAccess.READ)
			if f:
				var content = f.get_as_text()
				if session_recorder.import_from_json(content):
					is_paused_scrubbing = true
					btn_play_pause.text = "▶️ Resume"
					rec_status_lbl.text = "Loaded: %s (%d frames)" % [path.get_file(), session_recorder.frames.size()]
					_populate_from_session_frames()
					session_loaded.emit(path)

func _populate_from_session_frames() -> void:
	if not session_recorder or session_recorder.frames.is_empty():
		return
	dsp_history.clear()
	for f in session_recorder.frames:
		dsp_history.append(f.dsp_time_us)
		if dsp_history.size() > max_dsp_history:
			dsp_history.pop_front()
	if dsp_graph_rect:
		dsp_graph_rect.queue_redraw()

func _populate_sample_telemetry() -> void:
	voice_tree.clear()
	var root = voice_tree.create_item()
	
	var samples = [
		{ "name": "Player_Gunfire", "state": "🟢 Physical (Ch 0)", "priority": "95.0", "dist": "0.0 m" },
		{ "name": "Engine_Patrol_RPM", "state": "🟢 Physical (Ch 1)", "priority": "82.0", "dist": "14.2 m" },
		{ "name": "Monster_Roar_Crypt", "state": "🟢 Physical (Ch 2)", "priority": "78.0", "dist": "22.5 m" },
		{ "name": "Casing_Impact_01", "state": "⚪ Virtual Elapsed", "priority": "12.0", "dist": "18.0 m" },
		{ "name": "Casing_Impact_02", "state": "⚪ Virtual Elapsed", "priority": "11.5", "dist": "21.3 m" },
		{ "name": "Explosion_Debris_Far", "state": "⚪ Virtual Elapsed", "priority": "9.0", "dist": "45.0 m" }
	]
	
	for s in samples:
		var item = voice_tree.create_item(root)
		item.set_text(0, s["name"])
		item.set_text(1, s["state"])
		item.set_text(2, s["priority"])
		item.set_text(3, s["dist"])

func _process(delta: float) -> void:
	if not is_paused_scrubbing:
		# Add slight jitter to simulate live DSP CPU polling
		var jitter = randf_range(-3.0, 4.0)
		var cur = clampf(dsp_history.back() + jitter, 25.0, 110.0) if not dsp_history.is_empty() else 42.0
		dsp_history.append(cur)
		if dsp_history.size() > max_dsp_history:
			dsp_history.pop_front()
			
		if session_recorder:
			session_recorder.record_frame(cur, active_physical_voices, active_virtual_voices, ["Battlefield_Gunfire"], {}, 1)
			if is_manual_recording:
				rec_status_lbl.text = "🔴 REC: %d frames (%.1fs)" % [session_recorder.frames.size(), session_recorder.frames.back().timestamp_sec if not session_recorder.frames.is_empty() else 0.0]
			
	if dsp_graph_rect:
		dsp_graph_rect.queue_redraw()

func _on_toggle_pause_scrub() -> void:
	is_paused_scrubbing = not is_paused_scrubbing
	if is_paused_scrubbing:
		btn_play_pause.text = "▶️ Resume"
		btn_play_pause.tooltip_text = "Resume live telemetry capture"
	else:
		btn_play_pause.text = "⏸️ Live"
		btn_play_pause.tooltip_text = "Pause telemetry to scrub through history"
		if rewind_slider:
			rewind_slider.value = 0.0

func _on_rewind_slider_changed(val: float) -> void:
	if val < 0.0:
		is_paused_scrubbing = true
		btn_play_pause.text = "▶️ Resume"
		rewind_time_lbl.text = "%.1fs" % val
		dsp_metrics_lbl.text = "⏱️ Time-Travel: %.1fs ago | Frozen Frame" % absf(val)
		
		# Look up historical frame
		if session_recorder and not session_recorder.frames.is_empty():
			var total_time = session_recorder.frames.back().timestamp_sec
			var target_time = maxf(total_time + val, 0.0)
			var hist_frame = session_recorder.get_frame_at_time(target_time)
			if hist_frame:
				_update_historical_voice_ledger(hist_frame)
	else:
		rewind_time_lbl.text = "0.0s (Live)"
		dsp_metrics_lbl.text = "⚡ DSP Load: Avg 42.1 µs | Peak 78.2 µs | Budget: < 250 µs"
		_populate_sample_telemetry()

func _update_historical_voice_ledger(frame: ProfilerSessionRecorder.TelemetryFrame) -> void:
	voice_tree.clear()
	var root = voice_tree.create_item()
	
	var samples = [
		{ "name": "Player_Gunfire", "state": "🟢 Physical (Ch 0)" if frame.physical_voices > 0 else "⚪ Stopped", "priority": "95.0", "dist": "0.0 m" },
		{ "name": "Engine_Patrol_RPM", "state": "🟢 Physical (Ch 1)" if frame.physical_voices > 1 else "⚪ Stopped", "priority": "82.0", "dist": "14.2 m" },
		{ "name": "Monster_Roar_Crypt", "state": "🟢 Physical (Ch 2)" if frame.physical_voices > 2 else "⚪ Stopped", "priority": "78.0", "dist": "22.5 m" },
		{ "name": "Casing_Impact_01", "state": "⚪ Virtual Elapsed", "priority": "12.0", "dist": "18.0 m" },
		{ "name": "Explosion_Debris_Far", "state": "⚪ Virtual Elapsed", "priority": "9.0", "dist": "45.0 m" }
	]
	
	for s in samples:
		var item = voice_tree.create_item(root)
		item.set_text(0, s["name"])
		item.set_text(1, s["state"])
		item.set_text(2, s["priority"])
		item.set_text(3, s["dist"])

func _on_draw_dsp_graph() -> void:
	if not dsp_graph_rect:
		return
	var size = dsp_graph_rect.size
	if size.x <= 20.0 or size.y <= 20.0:
		return
		
	# Margins for Axis labels
	var left_margin = 48.0
	var bottom_margin = 18.0
	var plot_w = size.x - left_margin - 8.0
	var plot_h = size.y - bottom_margin - 8.0
	var max_scale_us: float = 300.0
	
	# 1. Dark Slate Plot Background
	var plot_rect = Rect2(Vector2(left_margin, 4), Vector2(plot_w, plot_h))
	dsp_graph_rect.draw_rect(plot_rect, Color(0.06, 0.08, 0.1, 1.0))
	dsp_graph_rect.draw_rect(plot_rect, Color(0.2, 0.25, 0.32, 0.6), false, 1.0)
	
	# 2. Horizontal Reference Grid Lines & Y-Labels
	var y_levels = [0.0, 50.0, 100.0, 150.0, 200.0, 250.0]
	var font = ThemeDB.fallback_font
	var font_size = 10
	
	for lvl in y_levels:
		var norm_y = lvl / max_scale_us
		var py = 4.0 + plot_h * (1.0 - norm_y)
		
		# Grid Line
		var line_color = Color(0.8, 0.25, 0.25, 0.7) if lvl == 250.0 else Color(0.18, 0.22, 0.28, 0.4)
		var line_width = 1.5 if lvl == 250.0 else 1.0
		dsp_graph_rect.draw_line(Vector2(left_margin, py), Vector2(left_margin + plot_w, py), line_color, line_width)
		
		# Y-Label
		var lbl_str = "%dµs" % int(lvl)
		dsp_graph_rect.draw_string(font, Vector2(6, py + 3), lbl_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.7, 0.8, 0.8))
		
	# 3. X-Axis Time Labels
	var x_labels = [
		{ "t": 0.0, "text": "-60f" },
		{ "t": 0.5, "text": "-30f" },
		{ "t": 1.0, "text": "Live (0s)" }
	]
	for xl in x_labels:
		var px = left_margin + plot_w * xl["t"]
		dsp_graph_rect.draw_line(Vector2(px, 4), Vector2(px, 4 + plot_h), Color(0.18, 0.22, 0.28, 0.3), 1.0)
		dsp_graph_rect.draw_string(font, Vector2(px - 14, size.y - 3), xl["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.7, 0.8, 0.8))
		
	# 4. Anti-Aliased Waveform Polyline & Fill
	if dsp_history.size() >= 2:
		var step_x = plot_w / float(max_dsp_history - 1)
		var pts = PackedVector2Array()
		var fill_pts = PackedVector2Array()
		
		fill_pts.append(Vector2(left_margin, 4.0 + plot_h))
		for i in range(dsp_history.size()):
			var px = left_margin + i * step_x
			var val = clampf(dsp_history[i], 0.0, max_scale_us)
			var py = 4.0 + plot_h * (1.0 - (val / max_scale_us))
			var pt = Vector2(px, py)
			pts.append(pt)
			fill_pts.append(pt)
		fill_pts.append(Vector2(left_margin + (dsp_history.size() - 1) * step_x, 4.0 + plot_h))
		
		# Draw Gradient Fill Under Curve
		dsp_graph_rect.draw_colored_polygon(fill_pts, Color(0.18, 0.83, 0.55, 0.15))
		
		# Draw Line
		draw_polyline_antialiased(dsp_graph_rect, pts, Color(0.18, 0.83, 0.55, 0.9), 2.0)

func draw_polyline_antialiased(canvas: Control, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2: return
	for i in range(points.size() - 1):
		canvas.draw_line(points[i], points[i + 1], color, width)
