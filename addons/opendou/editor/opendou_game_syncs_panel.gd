@tool
class_name OpenDouGameSyncsPanel
extends PanelContainer

## Sidebar manager for Game Syncs (RTPCs, States, Switches, and Synth Presets) in OpenDou Studio with persistent JSON storage.

const DataPathsClass = preload("res://addons/opendou/runtime/data_paths.gd")

signal rtpc_selected(param_name: StringName, min_val: float, max_val: float, def_val: float)
signal rtpc_value_changed(rtpc_name: StringName, value: float)
signal state_changed(group: StringName, state: StringName)
signal switch_changed(group: StringName, sw: StringName)
signal syncs_updated()

## Ruta del override del proyecto para los Game Syncs.
const SYNCS_FILE_PATH: String = "%s%s.json" % [OpenDouDataPaths.PROJECT_PREFIX, OpenDouDataPaths.GAME_SYNCS]

## Ruta de persistencia de los Game Syncs. Inyectable para que los tests no
## escriban en res:// y contaminen el repositorio: ejecutar la suite llegaba a
## inyectar entradas RTPC en el JSON versionado del proyecto.
## La migracion general de res:// a user:// es la observacion 17 (Fase 4).
var syncs_file_path: String = SYNCS_FILE_PATH

## Ruta del override del proyecto para los presets de sintesis.
const DEFAULT_PRESETS_PATH: String = "%s%s.json" % [OpenDouDataPaths.PROJECT_PREFIX, OpenDouDataPaths.SYNTH_PRESETS]

## Ruta de persistencia de los presets de sintesis. Misma razon.
var presets_file_path: String = DEFAULT_PRESETS_PATH

## Custom control for rendering synthesized audio waveform previews
class WaveformVisualizerControl extends Control:
	var samples: PackedFloat32Array = PackedFloat32Array()
	
	func _init() -> void:
		custom_minimum_size = Vector2(0, 56)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
	func _draw() -> void:
		var w = size.x
		var h = size.y
		# Dark background
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.14, 1.0))
		# Center baseline
		draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(0.22, 0.28, 0.35, 0.6), 1.0)
		
		if samples.is_empty() or w < 2.0:
			return
			
		var count = samples.size()
		var step = float(count) / w
		var mid_y = h * 0.5
		var points = PackedVector2Array()
		for x in range(int(w)):
			var s_idx = int(x * step)
			if s_idx < count:
				var s = samples[s_idx]
				var y = mid_y - s * (mid_y * 0.85)
				points.append(Vector2(x, clampf(y, 2.0, h - 2.0)))
				
		if points.size() > 1:
			draw_polyline(points, Color(0.2, 0.85, 1.0, 0.95), 1.5)

var tab_container: TabContainer
var rtpc_tree: Tree
var state_tree: Tree
var switch_tree: Tree

# Persistent Project Game Syncs Registry
var rtpcs: Dictionary = {}
var states: Dictionary = {}
var switches: Dictionary = {}

# Synth Presets Builder Controls
var preset_tree: Tree
var btn_add_preset: Button
var btn_delete_preset: Button
var preset_name_edit: LineEdit
var preset_type_opt: OptionButton
var preset_loop_chk: CheckBox
var preset_duration_spin: SpinBox
var preset_gain_spin: SpinBox

# Modular Rack Controls
var gen_type_opt: OptionButton
var base_freq_spin: SpinBox
var base_freq_var_spin: SpinBox
var pitch_decay_spin: SpinBox
var pitch_amount_spin: SpinBox
var env_attack_spin: SpinBox
var env_decay_spin: SpinBox
var env_sustain_spin: SpinBox
var env_release_spin: SpinBox
var lfo_wave_opt: OptionButton
var lfo_rate_spin: SpinBox
var lfo_depth_spin: SpinBox
var lfo_target_opt: OptionButton
var filter_type_opt: OptionButton
var filter_cutoff_spin: SpinBox
var filter_q_spin: SpinBox
var drive_type_opt: OptionButton
var drive_amount_spin: SpinBox

# Visualizer & Transport
var waveform_visualizer: Control
var btn_audition_play: Button
var btn_audition_stop: Button
var btn_save_presets: Button
var audition_player: AudioStreamPlayer
var active_preset_name: StringName = &""
var current_waveform_samples: PackedFloat32Array = PackedFloat32Array()
var _is_updating_ui: bool = false

## Las rutas entran por el constructor porque _init() ya carga del disco: si se
## asignaran despues, la carga habria ocurrido ya contra res://. Los valores por
## defecto conservan el comportamiento existente para el resto del editor.
func _init(p_syncs_path: String = SYNCS_FILE_PATH, p_presets_path: String = DEFAULT_PRESETS_PATH) -> void:
	syncs_file_path = p_syncs_path
	presets_file_path = p_presets_path
	custom_minimum_size = Vector2(0, 0)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	load_syncs_from_disk()
	_build_ui()

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var v_box = VBoxContainer.new()
	v_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_theme_constant_override("separation", 6)
	margin.add_child(v_box)
	
	# Header
	var title_lbl = Label.new()
	title_lbl.text = "🎮 Game Syncs & Synth Studio"
	title_lbl.add_theme_font_size_override("font_size", 12)
	v_box.add_child(title_lbl)
	
	# Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_child(tab_container)
	
	# Tab 1: RTPCs
	var rtpc_box = VBoxContainer.new()
	rtpc_box.name = "📈 RTPCs"
	rtpc_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtpc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtpc_box.add_theme_constant_override("separation", 4)
	
	rtpc_tree = Tree.new()
	rtpc_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtpc_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtpc_tree.clip_contents = true
	rtpc_tree.columns = 3
	rtpc_tree.set_column_title(0, "Parameter")
	rtpc_tree.set_column_title(1, "Range")
	rtpc_tree.set_column_title(2, "Default Value")
	rtpc_tree.set_column_expand(0, true)
	rtpc_tree.set_column_expand(1, true)
	rtpc_tree.set_column_expand(2, true)
	rtpc_tree.set_column_custom_minimum_width(0, 75)
	rtpc_tree.set_column_custom_minimum_width(1, 75)
	rtpc_tree.set_column_custom_minimum_width(2, 60)
	rtpc_tree.column_titles_visible = true
	rtpc_tree.item_activated.connect(_on_rtpc_activated)
	rtpc_box.add_child(rtpc_tree)
	
	var btn_add_rtpc = Button.new()
	btn_add_rtpc.text = "➕ Add RTPC"
	btn_add_rtpc.custom_minimum_size = Vector2(0, 24)
	btn_add_rtpc.pressed.connect(_on_add_rtpc_pressed)
	rtpc_box.add_child(btn_add_rtpc)
	tab_container.add_child(rtpc_box)
	
	# Tab 2: States
	var state_box = VBoxContainer.new()
	state_box.name = "🏷️ States"
	state_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_box.add_theme_constant_override("separation", 4)
	
	state_tree = Tree.new()
	state_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_tree.clip_contents = true
	state_tree.set_column_title(0, "Group / State")
	state_tree.column_titles_visible = true
	state_box.add_child(state_tree)
	
	var btn_add_state = Button.new()
	btn_add_state.text = "➕ Add State Group"
	btn_add_state.custom_minimum_size = Vector2(0, 24)
	btn_add_state.pressed.connect(_on_add_state_pressed)
	state_box.add_child(btn_add_state)
	tab_container.add_child(state_box)
	
	# Tab 3: Switches
	var switch_box = VBoxContainer.new()
	switch_box.name = "🔀 Switches"
	switch_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	switch_box.add_theme_constant_override("separation", 4)
	
	switch_tree = Tree.new()
	switch_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	switch_tree.clip_contents = true
	switch_tree.set_column_title(0, "Group / Switch")
	switch_tree.column_titles_visible = true
	switch_box.add_child(switch_tree)
	
	var btn_add_switch = Button.new()
	btn_add_switch.text = "➕ Add Switch Group"
	btn_add_switch.custom_minimum_size = Vector2(0, 24)
	btn_add_switch.pressed.connect(_on_add_switch_pressed)
	switch_box.add_child(btn_add_switch)
	tab_container.add_child(switch_box)
	
	# Tab 4: Synth Presets Builder
	var synth_box = VBoxContainer.new()
	synth_box.name = "⚡ Presets"
	synth_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	synth_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	synth_box.add_theme_constant_override("separation", 4)
	
	var synth_split = HSplitContainer.new()
	synth_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	synth_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	synth_box.add_child(synth_split)
	
	# Left: Preset Library Tree & Actions
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	left_panel.size_flags_horizontal = Control.SIZE_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 4)
	synth_split.add_child(left_panel)
	
	var lib_lbl = Label.new()
	lib_lbl.text = "📚 Preset Library"
	lib_lbl.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(lib_lbl)
	
	preset_tree = Tree.new()
	preset_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preset_tree.clip_contents = true
	preset_tree.set_column_title(0, "Preset Name")
	preset_tree.column_titles_visible = true
	preset_tree.item_selected.connect(_on_preset_selected)
	preset_tree.item_activated.connect(_on_preset_selected)
	left_panel.add_child(preset_tree)
	
	var preset_actions = HBoxContainer.new()
	preset_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(preset_actions)
	
	btn_add_preset = Button.new()
	btn_add_preset.text = "➕ New"
	btn_add_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add_preset.pressed.connect(_on_add_preset_pressed)
	preset_actions.add_child(btn_add_preset)
	
	btn_delete_preset = Button.new()
	btn_delete_preset.text = "🗑️ Delete"
	btn_delete_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_delete_preset.pressed.connect(_on_delete_preset_pressed)
	preset_actions.add_child(btn_delete_preset)
	
	# Right: Modular Rack in ScrollContainer
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	synth_split.add_child(right_scroll)
	
	var rack_vbox = VBoxContainer.new()
	rack_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rack_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(rack_vbox)
	
	# 1. Top Toolbar (Name, Type, Loop, Duration, Gain)
	var toolbar_panel = PanelContainer.new()
	toolbar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var toolbar_box = HBoxContainer.new()
	toolbar_box.add_theme_constant_override("separation", 6)
	toolbar_panel.add_child(toolbar_box)
	rack_vbox.add_child(toolbar_panel)
	
	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	toolbar_box.add_child(name_lbl)
	
	preset_name_edit = LineEdit.new()
	preset_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_name_edit.text_submitted.connect(_on_preset_name_submitted)
	toolbar_box.add_child(preset_name_edit)
	
	var type_lbl = Label.new()
	type_lbl.text = "Type:"
	toolbar_box.add_child(type_lbl)
	
	preset_type_opt = OptionButton.new()
	preset_type_opt.add_item("Single_Generator")
	preset_type_opt.add_item("Layer_Container")
	preset_type_opt.item_selected.connect(func(_i): _on_rack_control_changed())
	toolbar_box.add_child(preset_type_opt)
	
	preset_loop_chk = CheckBox.new()
	preset_loop_chk.text = "Loop"
	preset_loop_chk.toggled.connect(func(_t): _on_rack_control_changed())
	toolbar_box.add_child(preset_loop_chk)
	
	var dur_lbl = Label.new()
	dur_lbl.text = "Dur(s):"
	toolbar_box.add_child(dur_lbl)
	
	preset_duration_spin = SpinBox.new()
	preset_duration_spin.min_value = 0.01
	preset_duration_spin.max_value = 30.0
	preset_duration_spin.step = 0.05
	preset_duration_spin.value = 1.0
	preset_duration_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	toolbar_box.add_child(preset_duration_spin)
	
	var gain_lbl = Label.new()
	gain_lbl.text = "Gain(dB):"
	toolbar_box.add_child(gain_lbl)
	
	preset_gain_spin = SpinBox.new()
	preset_gain_spin.min_value = -48.0
	preset_gain_spin.max_value = 12.0
	preset_gain_spin.step = 0.5
	preset_gain_spin.value = 0.0
	preset_gain_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	toolbar_box.add_child(preset_gain_spin)
	
	# 2. Generator & Tuning Section
	var gen_sec = _create_rack_section(rack_vbox, "🎛️ Generator & Tuning")
	var gen_row = HBoxContainer.new()
	gen_row.add_theme_constant_override("separation", 6)
	gen_sec.add_child(gen_row)
	
	var g_lbl = Label.new()
	g_lbl.text = "Type:"
	gen_row.add_child(g_lbl)
	
	gen_type_opt = OptionButton.new()
	gen_type_opt.add_item("Filtered_Noise")
	gen_type_opt.add_item("FM_Chirp")
	gen_type_opt.add_item("Karplus_Strong")
	gen_type_opt.add_item("Wavetable_PM")
	gen_type_opt.add_item("Harmonic_Buzz")
	gen_type_opt.add_item("Sub_Rumble")
	gen_type_opt.add_item("Resonant_Formant")
	gen_type_opt.add_item("Impulse_Ping")
	gen_type_opt.add_item("Basic_Wave")
	gen_type_opt.item_selected.connect(func(_i): _on_rack_control_changed())
	gen_row.add_child(gen_type_opt)
	
	var f_lbl = Label.new()
	f_lbl.text = "Base Freq (Hz):"
	gen_row.add_child(f_lbl)
	
	base_freq_spin = SpinBox.new()
	base_freq_spin.min_value = 10.0
	base_freq_spin.max_value = 20000.0
	base_freq_spin.step = 1.0
	base_freq_spin.value = 440.0
	base_freq_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	gen_row.add_child(base_freq_spin)
	
	var fv_lbl = Label.new()
	fv_lbl.text = "Freq Var (±%):"
	gen_row.add_child(fv_lbl)
	
	base_freq_var_spin = SpinBox.new()
	base_freq_var_spin.min_value = 0.0
	base_freq_var_spin.max_value = 1.0
	base_freq_var_spin.step = 0.01
	base_freq_var_spin.value = 0.0
	base_freq_var_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	gen_row.add_child(base_freq_var_spin)
	
	# 3. Pitch Envelope Section
	var pitch_sec = _create_rack_section(rack_vbox, "📈 Pitch Envelope")
	var pitch_row = HBoxContainer.new()
	pitch_row.add_theme_constant_override("separation", 6)
	pitch_sec.add_child(pitch_row)
	
	var pd_lbl = Label.new()
	pd_lbl.text = "Decay (s):"
	pitch_row.add_child(pd_lbl)
	
	pitch_decay_spin = SpinBox.new()
	pitch_decay_spin.min_value = 0.0
	pitch_decay_spin.max_value = 5.0
	pitch_decay_spin.step = 0.01
	pitch_decay_spin.value = 0.1
	pitch_decay_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	pitch_row.add_child(pitch_decay_spin)
	
	var pa_lbl = Label.new()
	pa_lbl.text = "Amount (st):"
	pitch_row.add_child(pa_lbl)
	
	pitch_amount_spin = SpinBox.new()
	pitch_amount_spin.min_value = -48.0
	pitch_amount_spin.max_value = 48.0
	pitch_amount_spin.step = 0.5
	pitch_amount_spin.value = 0.0
	pitch_amount_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	pitch_row.add_child(pitch_amount_spin)
	
	# 4. Amplitude Envelope (ADSR) Section
	var env_sec = _create_rack_section(rack_vbox, "📊 Amplitude Envelope (ADSR)")
	var env_row = HBoxContainer.new()
	env_row.add_theme_constant_override("separation", 6)
	env_sec.add_child(env_row)
	
	var a_lbl = Label.new()
	a_lbl.text = "Attack (s):"
	env_row.add_child(a_lbl)
	env_attack_spin = SpinBox.new()
	env_attack_spin.min_value = 0.0
	env_attack_spin.max_value = 5.0
	env_attack_spin.step = 0.005
	env_attack_spin.value = 0.01
	env_attack_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	env_row.add_child(env_attack_spin)
	
	var d_lbl = Label.new()
	d_lbl.text = "Decay (s):"
	env_row.add_child(d_lbl)
	env_decay_spin = SpinBox.new()
	env_decay_spin.min_value = 0.0
	env_decay_spin.max_value = 10.0
	env_decay_spin.step = 0.01
	env_decay_spin.value = 0.1
	env_decay_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	env_row.add_child(env_decay_spin)
	
	var s_lbl = Label.new()
	s_lbl.text = "Sustain:"
	env_row.add_child(s_lbl)
	env_sustain_spin = SpinBox.new()
	env_sustain_spin.min_value = 0.0
	env_sustain_spin.max_value = 1.0
	env_sustain_spin.step = 0.05
	env_sustain_spin.value = 1.0
	env_sustain_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	env_row.add_child(env_sustain_spin)
	
	var r_lbl = Label.new()
	r_lbl.text = "Release (s):"
	env_row.add_child(r_lbl)
	env_release_spin = SpinBox.new()
	env_release_spin.min_value = 0.0
	env_release_spin.max_value = 10.0
	env_release_spin.step = 0.01
	env_release_spin.value = 0.1
	env_release_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	env_row.add_child(env_release_spin)
	
	# 5. LFO Modulation Section
	var lfo_sec = _create_rack_section(rack_vbox, "〰️ LFO Modulation")
	var lfo_row = HBoxContainer.new()
	lfo_row.add_theme_constant_override("separation", 6)
	lfo_sec.add_child(lfo_row)
	
	var lw_lbl = Label.new()
	lw_lbl.text = "Wave:"
	lfo_row.add_child(lw_lbl)
	lfo_wave_opt = OptionButton.new()
	lfo_wave_opt.add_item("Sine")
	lfo_wave_opt.add_item("Triangle")
	lfo_wave_opt.add_item("Sawtooth")
	lfo_wave_opt.add_item("Square")
	lfo_wave_opt.item_selected.connect(func(_i): _on_rack_control_changed())
	lfo_row.add_child(lfo_wave_opt)
	
	var lr_lbl = Label.new()
	lr_lbl.text = "Rate (Hz):"
	lfo_row.add_child(lr_lbl)
	lfo_rate_spin = SpinBox.new()
	lfo_rate_spin.min_value = 0.1
	lfo_rate_spin.max_value = 200.0
	lfo_rate_spin.step = 0.1
	lfo_rate_spin.value = 5.0
	lfo_rate_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	lfo_row.add_child(lfo_rate_spin)
	
	var ld_lbl = Label.new()
	ld_lbl.text = "Depth:"
	lfo_row.add_child(ld_lbl)
	lfo_depth_spin = SpinBox.new()
	lfo_depth_spin.min_value = 0.0
	lfo_depth_spin.max_value = 1.0
	lfo_depth_spin.step = 0.01
	lfo_depth_spin.value = 0.0
	lfo_depth_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	lfo_row.add_child(lfo_depth_spin)
	
	var lt_lbl = Label.new()
	lt_lbl.text = "Target:"
	lfo_row.add_child(lt_lbl)
	lfo_target_opt = OptionButton.new()
	lfo_target_opt.add_item("Amplitude")
	lfo_target_opt.add_item("Pitch")
	lfo_target_opt.add_item("Filter_Cutoff")
	lfo_target_opt.item_selected.connect(func(_i): _on_rack_control_changed())
	lfo_row.add_child(lfo_target_opt)
	
	# 6. Filter & Saturation Section
	var flt_sec = _create_rack_section(rack_vbox, "🎚️ Filter & Saturation")
	var flt_row = HBoxContainer.new()
	flt_row.add_theme_constant_override("separation", 6)
	flt_sec.add_child(flt_row)
	
	var ft_lbl = Label.new()
	ft_lbl.text = "Filter:"
	flt_row.add_child(ft_lbl)
	filter_type_opt = OptionButton.new()
	filter_type_opt.add_item("LowPass")
	filter_type_opt.add_item("HighPass")
	filter_type_opt.add_item("BandPass")
	filter_type_opt.add_item("Notch")
	filter_type_opt.item_selected.connect(func(_i): _on_rack_control_changed())
	flt_row.add_child(filter_type_opt)
	
	var fc_lbl = Label.new()
	fc_lbl.text = "Cutoff (Hz):"
	flt_row.add_child(fc_lbl)
	filter_cutoff_spin = SpinBox.new()
	filter_cutoff_spin.min_value = 20.0
	filter_cutoff_spin.max_value = 20000.0
	filter_cutoff_spin.step = 10.0
	filter_cutoff_spin.value = 4000.0
	filter_cutoff_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	flt_row.add_child(filter_cutoff_spin)
	
	var fq_lbl = Label.new()
	fq_lbl.text = "Q:"
	flt_row.add_child(fq_lbl)
	filter_q_spin = SpinBox.new()
	filter_q_spin.min_value = 0.1
	filter_q_spin.max_value = 20.0
	filter_q_spin.step = 0.1
	filter_q_spin.value = 1.0
	filter_q_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	flt_row.add_child(filter_q_spin)
	
	var drv_row = HBoxContainer.new()
	drv_row.add_theme_constant_override("separation", 6)
	flt_sec.add_child(drv_row)
	
	var dt_lbl = Label.new()
	dt_lbl.text = "Drive Type:"
	drv_row.add_child(dt_lbl)
	drive_type_opt = OptionButton.new()
	drive_type_opt.add_item("None")
	drive_type_opt.add_item("Soft_Clip")
	drive_type_opt.add_item("Hard_Clip")
	drive_type_opt.add_item("Foldback")
	drive_type_opt.item_selected.connect(func(_i): _on_rack_control_changed())
	drv_row.add_child(drive_type_opt)
	
	var da_lbl = Label.new()
	da_lbl.text = "Drive Amount:"
	drv_row.add_child(da_lbl)
	drive_amount_spin = SpinBox.new()
	drive_amount_spin.min_value = 0.1
	drive_amount_spin.max_value = 10.0
	drive_amount_spin.step = 0.1
	drive_amount_spin.value = 1.0
	drive_amount_spin.value_changed.connect(func(_v): _on_rack_control_changed())
	drv_row.add_child(drive_amount_spin)
	
	# 7. Waveform Visualizer
	var vis_sec = _create_rack_section(rack_vbox, "🌊 Waveform & Envelope Visualizer")
	waveform_visualizer = WaveformVisualizerControl.new()
	vis_sec.add_child(waveform_visualizer)
	
	# 8. Transport & Save Bar
	var transport_box = HBoxContainer.new()
	transport_box.add_theme_constant_override("separation", 8)
	rack_vbox.add_child(transport_box)
	
	btn_audition_play = Button.new()
	btn_audition_play.text = "▶ Audition"
	btn_audition_play.custom_minimum_size = Vector2(90, 28)
	btn_audition_play.pressed.connect(_on_audition_play_pressed)
	transport_box.add_child(btn_audition_play)
	
	btn_audition_stop = Button.new()
	btn_audition_stop.text = "⏹ Stop"
	btn_audition_stop.custom_minimum_size = Vector2(75, 28)
	btn_audition_stop.pressed.connect(_on_audition_stop_pressed)
	transport_box.add_child(btn_audition_stop)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport_box.add_child(spacer)
	
	btn_save_presets = Button.new()
	btn_save_presets.text = "💾 Save All Presets"
	btn_save_presets.custom_minimum_size = Vector2(130, 28)
	btn_save_presets.pressed.connect(_on_save_presets_pressed)
	transport_box.add_child(btn_save_presets)
	
	tab_container.add_child(synth_box)
	
	# Internal AudioStreamPlayer for auditioning
	audition_player = AudioStreamPlayer.new()
	add_child(audition_player)
	
	_refresh_trees()
	_refresh_preset_tree()

func _create_rack_section(parent: Node, section_title: String) -> VBoxContainer:
	var sec_panel = PanelContainer.new()
	sec_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sec_vbox = VBoxContainer.new()
	sec_vbox.add_theme_constant_override("separation", 4)
	sec_panel.add_child(sec_vbox)
	
	var lbl = Label.new()
	lbl.text = section_title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.85, 0.9, 1.0, 0.9)
	sec_vbox.add_child(lbl)
	
	parent.add_child(sec_panel)
	return sec_vbox

## Loads persistent game syncs registry from project disk file.
func load_syncs_from_disk() -> void:
	# Si el override del proyecto no existe, se cae al default del addon.
	var read_path: String = syncs_file_path
	if not FileAccess.file_exists(read_path):
		read_path = DataPathsClass.resolve(DataPathsClass.GAME_SYNCS)
	if not read_path.is_empty() and FileAccess.file_exists(read_path):
		var file = FileAccess.open(read_path, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_str)
			if parsed is Dictionary:
				_deserialize_syncs(parsed)
				return
				
	# Default Initial Preset if no file exists
	rtpcs = {
		&"RPM": { "min": 0.0, "max": 8000.0, "default": 1000.0 },
		&"Health": { "min": 0.0, "max": 100.0, "default": 100.0 },
		&"Distance": { "min": 0.0, "max": 100.0, "default": 0.0 },
		&"Speed": { "min": 0.0, "max": 50.0, "default": 0.0 }
	}
	states = {
		&"GameState": ["Exploration", "Combat", "Stealth", "Defeat"],
		&"Environment": ["Outdoor", "Cave", "Underwater", "Space"]
	}
	switches = {
		&"SurfaceType": ["Asphalt", "Mud", "Metal", "Stone", "Wood", "Water"],
		&"WeaponType": ["Pistol", "Rifle", "Shotgun", "RocketLauncher"]
	}
	save_syncs_to_disk()

## Saves current game syncs registry permanently to project disk file.
func save_syncs_to_disk() -> void:
	var file = FileAccess.open(syncs_file_path, FileAccess.WRITE)
	if file:
		var data = _serialize_syncs()
		file.store_string(JSON.stringify(data, "\t"))
		file.flush()
		file.close()

func _serialize_syncs() -> Dictionary:
	var rtpcs_data: Dictionary = {}
	for k in rtpcs.keys():
		rtpcs_data[str(k)] = rtpcs[k]
		
	var states_data: Dictionary = {}
	for k in states.keys():
		states_data[str(k)] = states[k]
		
	var switches_data: Dictionary = {}
	for k in switches.keys():
		switches_data[str(k)] = switches[k]
		
	return {
		"rtpcs": rtpcs_data,
		"states": states_data,
		"switches": switches_data
	}

func _deserialize_syncs(data: Dictionary) -> void:
	rtpcs.clear()
	var r_data = data.get("rtpcs", {})
	for k in r_data.keys():
		rtpcs[StringName(k)] = {
			"min": float(r_data[k].get("min", 0.0)),
			"max": float(r_data[k].get("max", 100.0)),
			"default": float(r_data[k].get("default", 0.0))
		}
		
	states.clear()
	var s_data = data.get("states", {})
	for k in s_data.keys():
		var arr: Array = []
		for item in s_data[k]: arr.append(str(item))
		states[StringName(k)] = arr
		
	switches.clear()
	var sw_data = data.get("switches", {})
	for k in sw_data.keys():
		var arr: Array = []
		for item in sw_data[k]: arr.append(str(item))
		switches[StringName(k)] = arr

func _refresh_trees() -> void:
	if not rtpc_tree or not state_tree or not switch_tree:
		return
		
	# 1. RTPC Tree
	rtpc_tree.clear()
	var rtpc_root = rtpc_tree.create_item()
	for param in rtpcs.keys():
		var data = rtpcs[param]
		var item = rtpc_tree.create_item(rtpc_root)
		item.set_text(0, str(param))
		item.set_text(1, "%.0f - %.0f" % [data["min"], data["max"]])
		item.set_text(2, "%.1f" % data["default"])
		item.set_metadata(0, param)
		
	# 2. State Tree
	state_tree.clear()
	var state_root = state_tree.create_item()
	for grp in states.keys():
		var grp_item = state_tree.create_item(state_root)
		grp_item.set_text(0, "📁 %s" % str(grp))
		for st in states[grp]:
			var st_item = state_tree.create_item(grp_item)
			st_item.set_text(0, "  ▫️ %s" % str(st))
			
	# 3. Switch Tree
	switch_tree.clear()
	var switch_root = switch_tree.create_item()
	for grp in switches.keys():
		var grp_item = switch_tree.create_item(switch_root)
		grp_item.set_text(0, "📁 %s" % str(grp))
		for sw in switches[grp]:
			var sw_item = switch_tree.create_item(grp_item)
			sw_item.set_text(0, "  🔲 %s" % str(sw))

func _on_rtpc_activated() -> void:
	var item = rtpc_tree.get_selected()
	if item:
		var p_name = StringName(item.get_text(0))
		if rtpcs.has(p_name):
			var d = rtpcs[p_name]
			rtpc_selected.emit(p_name, d["min"], d["max"], d["default"])

func _on_add_rtpc_pressed() -> void:
	var new_id = "RTPC_%d" % (rtpcs.size() + 1)
	rtpcs[StringName(new_id)] = { "min": 0.0, "max": 100.0, "default": 50.0 }
	save_syncs_to_disk()
	_refresh_trees()
	syncs_updated.emit()

func _on_add_state_pressed() -> void:
	var new_grp = "StateGroup_%d" % (states.size() + 1)
	states[StringName(new_grp)] = ["State_A", "State_B"]
	save_syncs_to_disk()
	_refresh_trees()
	syncs_updated.emit()

func _on_add_switch_pressed() -> void:
	var new_grp = "SwitchGroup_%d" % (switches.size() + 1)
	switches[StringName(new_grp)] = ["Switch_1", "Switch_2"]
	save_syncs_to_disk()
	_refresh_trees()
	syncs_updated.emit()

func simulate_rtpc_override(rtpc_name: StringName, value: float) -> void:
	if rtpcs.has(rtpc_name):
		rtpcs[rtpc_name]["default"] = value
		rtpc_value_changed.emit(rtpc_name, value)

func get_all_rtpc_names() -> Array[StringName]:
	var res: Array[StringName] = []
	for k in rtpcs.keys():
		res.append(k)
	return res

# -----------------------------------------------------------------------------
# Synth Presets Studio Logic & Connections
# -----------------------------------------------------------------------------

## Refreshes preset tree list from SynthPresetRegistry
func _refresh_preset_tree() -> void:
	if not preset_tree:
		return
	preset_tree.clear()
	var root = preset_tree.create_item()
	var registry = SynthPresetRegistry.get_singleton()
	var names = registry.get_preset_names()
	var target_item: TreeItem = null
	
	for p_name in names:
		var item = preset_tree.create_item(root)
		item.set_text(0, str(p_name))
		item.set_metadata(0, p_name)
		if p_name == active_preset_name:
			target_item = item
			
	if target_item:
		preset_tree.set_selected(target_item, 0)
	elif root.get_child_count() > 0:
		var first = root.get_first_child()
		preset_tree.set_selected(first, 0)
		active_preset_name = StringName(first.get_text(0))
		_populate_rack_from_preset(active_preset_name)

func _on_preset_selected() -> void:
	if not preset_tree:
		return
	var item = preset_tree.get_selected()
	if not item:
		return
	var p_name = StringName(item.get_text(0))
	active_preset_name = p_name
	_populate_rack_from_preset(p_name)

func _populate_rack_from_preset(preset_name: StringName) -> void:
	var registry = SynthPresetRegistry.get_singleton()
	var p_dict = registry.get_preset(preset_name)
	if p_dict.is_empty():
		return
		
	_is_updating_ui = true
	
	if preset_name_edit:
		preset_name_edit.text = str(preset_name)
		
	var p_type = p_dict.get("type", "Single_Generator")
	if preset_type_opt:
		if p_type == "Layer_Container":
			preset_type_opt.selected = 1
		else:
			preset_type_opt.selected = 0
			
	if preset_loop_chk:
		preset_loop_chk.button_pressed = bool(p_dict.get("loop_mode", false))
		
	if preset_duration_spin:
		preset_duration_spin.value = float(p_dict.get("duration", 1.0))
		
	if preset_gain_spin:
		preset_gain_spin.value = float(p_dict.get("gain_db", 0.0))
		
	var target_dict = p_dict
	if p_type == "Layer_Container" and p_dict.has("layers") and p_dict["layers"] is Array and not p_dict["layers"].is_empty():
		target_dict = p_dict["layers"][0]
		
	var gen_type = target_dict.get("generator_type", "Basic_Wave")
	if gen_type_opt:
		for i in range(gen_type_opt.get_item_count()):
			if gen_type_opt.get_item_text(i) == gen_type:
				gen_type_opt.selected = i
				break
				
	if base_freq_spin:
		base_freq_spin.value = float(target_dict.get("base_freq", 440.0))
	if base_freq_var_spin:
		base_freq_var_spin.value = float(target_dict.get("base_freq_var", 0.0))
		
	# Pitch Envelope
	var pitch_env = target_dict.get("pitch_envelope", {})
	if pitch_decay_spin:
		pitch_decay_spin.value = float(pitch_env.get("decay", target_dict.get("pitch_decay", 0.1)))
	if pitch_amount_spin:
		pitch_amount_spin.value = float(pitch_env.get("amount_st", target_dict.get("pitch_mult", 0.0)))
		
	# Amplitude Envelope
	var env = target_dict.get("envelope", {})
	if env_attack_spin:
		env_attack_spin.value = float(env.get("attack", 0.01))
	if env_decay_spin:
		env_decay_spin.value = float(env.get("decay", 0.1))
	if env_sustain_spin:
		env_sustain_spin.value = float(env.get("sustain", 1.0))
	if env_release_spin:
		env_release_spin.value = float(env.get("release", 0.1))
		
	# LFO
	var lfo = target_dict.get("lfo", {})
	var lfo_wave = lfo.get("wave", "Sine")
	if lfo_wave_opt:
		for i in range(lfo_wave_opt.get_item_count()):
			if lfo_wave_opt.get_item_text(i) == lfo_wave:
				lfo_wave_opt.selected = i
				break
	if lfo_rate_spin:
		lfo_rate_spin.value = float(lfo.get("rate_hz", target_dict.get("flutter_rate", 5.0)))
	if lfo_depth_spin:
		lfo_depth_spin.value = float(lfo.get("depth", target_dict.get("flutter_depth", 0.0)))
	var lfo_target = lfo.get("target", "Amplitude")
	if lfo_target_opt:
		for i in range(lfo_target_opt.get_item_count()):
			if lfo_target_opt.get_item_text(i) == lfo_target:
				lfo_target_opt.selected = i
				break
				
	# Filter
	var flt = target_dict.get("filter", {})
	var flt_type = flt.get("type", "LowPass")
	if filter_type_opt:
		for i in range(filter_type_opt.get_item_count()):
			if filter_type_opt.get_item_text(i) == flt_type:
				filter_type_opt.selected = i
				break
	if filter_cutoff_spin:
		filter_cutoff_spin.value = float(flt.get("cutoff_hz", 4000.0))
	if filter_q_spin:
		filter_q_spin.value = float(flt.get("resonance_q", 1.0))
		
	# Drive
	var drv = target_dict.get("drive", {})
	var drv_type = drv.get("type", "None")
	if drive_type_opt:
		for i in range(drive_type_opt.get_item_count()):
			if drive_type_opt.get_item_text(i) == drv_type:
				drive_type_opt.selected = i
				break
	if drive_amount_spin:
		drive_amount_spin.value = float(drv.get("amount", 1.0))
		
	_is_updating_ui = false
	
	# Update waveform preview
	var stream = registry.get_preset_stream(preset_name, 42)
	_update_waveform_preview(stream)

func _on_rack_control_changed() -> void:
	if _is_updating_ui or active_preset_name.is_empty():
		return
		
	var registry = SynthPresetRegistry.get_singleton()
	var current_p = registry.get_preset(active_preset_name)
	if current_p.is_empty():
		current_p = {}
		
	var p_type = "Single_Generator"
	if preset_type_opt and preset_type_opt.selected == 1:
		p_type = "Layer_Container"
	current_p["type"] = p_type
	
	if preset_loop_chk:
		current_p["loop_mode"] = preset_loop_chk.button_pressed
	if preset_duration_spin:
		current_p["duration"] = preset_duration_spin.value
	if preset_gain_spin:
		current_p["gain_db"] = preset_gain_spin.value
		
	var gen_type = gen_type_opt.get_item_text(gen_type_opt.selected) if gen_type_opt else "Basic_Wave"
	
	if p_type == "Layer_Container":
		if not current_p.has("layers") or not (current_p["layers"] is Array) or current_p["layers"].is_empty():
			current_p["layers"] = [{}]
		var l0 = current_p["layers"][0]
		l0["generator_type"] = gen_type
		if base_freq_spin: l0["base_freq"] = base_freq_spin.value
		if base_freq_var_spin: l0["base_freq_var"] = base_freq_var_spin.value
		l0["pitch_envelope"] = {
			"decay": pitch_decay_spin.value if pitch_decay_spin else 0.1,
			"amount_st": pitch_amount_spin.value if pitch_amount_spin else 0.0
		}
		l0["envelope"] = {
			"attack": env_attack_spin.value if env_attack_spin else 0.01,
			"decay": env_decay_spin.value if env_decay_spin else 0.1,
			"sustain": env_sustain_spin.value if env_sustain_spin else 1.0,
			"release": env_release_spin.value if env_release_spin else 0.1
		}
		if drive_type_opt:
			var d_t = drive_type_opt.get_item_text(drive_type_opt.selected)
			if d_t != "None":
				l0["drive"] = {
					"type": d_t,
					"amount": drive_amount_spin.value if drive_amount_spin else 1.0
				}
			else:
				l0.erase("drive")
		if filter_type_opt:
			l0["filter"] = {
				"type": filter_type_opt.get_item_text(filter_type_opt.selected),
				"cutoff_hz": filter_cutoff_spin.value if filter_cutoff_spin else 4000.0,
				"resonance_q": filter_q_spin.value if filter_q_spin else 1.0
			}
	else:
		current_p["generator_type"] = gen_type
		if base_freq_spin: current_p["base_freq"] = base_freq_spin.value
		if base_freq_var_spin: current_p["base_freq_var"] = base_freq_var_spin.value
		current_p["pitch_envelope"] = {
			"decay": pitch_decay_spin.value if pitch_decay_spin else 0.1,
			"amount_st": pitch_amount_spin.value if pitch_amount_spin else 0.0
		}
		current_p["envelope"] = {
			"attack": env_attack_spin.value if env_attack_spin else 0.01,
			"decay": env_decay_spin.value if env_decay_spin else 0.1,
			"sustain": env_sustain_spin.value if env_sustain_spin else 1.0,
			"release": env_release_spin.value if env_release_spin else 0.1
		}
		if lfo_wave_opt and lfo_rate_spin and lfo_depth_spin and lfo_target_opt:
			current_p["lfo"] = {
				"wave": lfo_wave_opt.get_item_text(lfo_wave_opt.selected),
				"rate_hz": lfo_rate_spin.value,
				"depth": lfo_depth_spin.value,
				"target": lfo_target_opt.get_item_text(lfo_target_opt.selected)
			}
		if filter_type_opt and filter_cutoff_spin and filter_q_spin:
			current_p["filter"] = {
				"type": filter_type_opt.get_item_text(filter_type_opt.selected),
				"cutoff_hz": filter_cutoff_spin.value,
				"resonance_q": filter_q_spin.value
			}
		if drive_type_opt and drive_amount_spin:
			var d_t = drive_type_opt.get_item_text(drive_type_opt.selected)
			if d_t != "None":
				current_p["drive"] = {
					"type": d_t,
					"amount": drive_amount_spin.value
				}
			else:
				current_p.erase("drive")
				
	registry.set_preset(active_preset_name, current_p)
	var stream = registry.get_preset_stream(active_preset_name, 42)
	_update_waveform_preview(stream)

func _update_waveform_preview(stream: AudioStreamWAV) -> void:
	current_waveform_samples.clear()
	if stream == null or stream.data.is_empty():
		if waveform_visualizer is WaveformVisualizerControl:
			(waveform_visualizer as WaveformVisualizerControl).samples = current_waveform_samples
			waveform_visualizer.queue_redraw()
		return
		
	var byte_data = stream.data
	var num_samples = byte_data.size() / 2 # 16-bit PCM
	var step = maxi(1, num_samples / 512)
	var arr = PackedFloat32Array()
	for i in range(0, num_samples, step):
		var byte_idx = i * 2
		if byte_idx + 1 < byte_data.size():
			var val = byte_data.decode_s16(byte_idx)
			arr.append(float(val) / 32768.0)
	current_waveform_samples = arr
	if waveform_visualizer is WaveformVisualizerControl:
		(waveform_visualizer as WaveformVisualizerControl).samples = current_waveform_samples
		waveform_visualizer.queue_redraw()

func _on_preset_name_submitted(new_name_str: String) -> void:
	var trimmed = new_name_str.strip_edges()
	if trimmed.is_empty() or trimmed == str(active_preset_name):
		return
	var new_name = StringName(trimmed)
	var registry = SynthPresetRegistry.get_singleton()
	var current_p = registry.get_preset(active_preset_name)
	registry.delete_preset(active_preset_name)
	registry.set_preset(new_name, current_p)
	active_preset_name = new_name
	_refresh_preset_tree()

func _on_add_preset_pressed() -> void:
	var registry = SynthPresetRegistry.get_singleton()
	var names = registry.get_preset_names()
	var base_idx = names.size() + 1
	var new_name = StringName("Synth_Preset_%d" % base_idx)
	while not registry.get_preset(new_name).is_empty():
		base_idx += 1
		new_name = StringName("Synth_Preset_%d" % base_idx)
	var new_dict: Dictionary = {
		"type": "Single_Generator",
		"generator_type": "Basic_Wave",
		"wave_type": "Sine",
		"base_freq": 440.0,
		"base_freq_var": 0.0,
		"duration": 0.5,
		"gain_db": -6.0,
		"loop_mode": false,
		"envelope": { "attack": 0.01, "decay": 0.1, "sustain": 0.8, "release": 0.1 },
		"filter": { "type": "LowPass", "cutoff_hz": 4000.0, "resonance_q": 1.0 },
		"drive": { "type": "None", "amount": 1.0 }
	}
	registry.set_preset(new_name, new_dict)
	active_preset_name = new_name
	_refresh_preset_tree()

func _on_delete_preset_pressed() -> void:
	if active_preset_name.is_empty():
		return
	var registry = SynthPresetRegistry.get_singleton()
	registry.delete_preset(active_preset_name)
	active_preset_name = &""
	_refresh_preset_tree()

func _on_save_presets_pressed() -> void:
	SynthPresetRegistry.get_singleton().save_presets(presets_file_path)

func _on_audition_play_pressed() -> void:
	if active_preset_name.is_empty():
		return
	var stream = SynthPresetRegistry.get_singleton().get_preset_stream(active_preset_name, 0)
	if stream:
		audition_player.stream = stream
		audition_player.play()
		_update_waveform_preview(stream)

func _on_audition_stop_pressed() -> void:
	if audition_player.playing:
		audition_player.stop()

