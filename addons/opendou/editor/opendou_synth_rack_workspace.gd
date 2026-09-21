@tool
class_name OpenDouSynthRackWorkspace
extends PanelContainer

## OpenDouSynthRackWorkspace - Fullscreen VST Modular Synth Rack Workstation (Mode 3: Synth).
## Integrates a Preset Library, Dynamic Waveform + Sweeping Playhead Visualizer, Stereo VU Meter,
## Eurorack modular cards (Generator, ADSR Envelope, Filter, LFO/Mod, Drive/Sat, Voicing/Pan, Master FX),
## and an Audition Transport Bar.

const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")
const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
const OpenDouKnobClass = preload("res://addons/opendou/editor/controls/opendou_knob.gd")
const OpenDouADSREditorClass = preload("res://addons/opendou/editor/controls/opendou_adsr_editor.gd")
const OpenDouWaveformPlayheadClass = preload("res://addons/opendou/editor/controls/opendou_waveform_playhead.gd")
const OpenDouVUMeterClass = preload("res://addons/opendou/editor/controls/opendou_vu_meter.gd")
const SynthLayerOpsClass = preload("res://addons/opendou/runtime/synth/layer_ops.gd")

const GENERATOR_TYPES = [
	"Basic_Wave", "FM_Chirp", "Filtered_Noise", "Karplus_Strong",
	"Wavetable_PM", "Harmonic_Buzz", "Sub_Rumble", "Resonant_Formant", "Impulse_Ping"
]

const FILTER_TYPES = ["None", "LowPass", "HighPass", "BandPass", "Notch"]
const LFO_WAVES = ["Sine", "Triangle", "Sawtooth", "Square"]
const LFO_TARGETS = ["Amplitude", "Pitch", "Filter_Cutoff", "Pan"]
const DRIVE_TYPES = ["None", "Soft_Clip", "Hard_Clip", "Foldback"]
const VOICE_MODES = ["Mono", "Poly"]

signal preset_selected(preset_name: StringName)
signal preset_modified(preset_name: StringName, preset_dict: Dictionary)

# Layout Containers
var main_hsplit: HSplitContainer
var left_panel: VBoxContainer
var right_scroll: ScrollContainer
var vbox_rack: VBoxContainer

# Left Panel Controls
var preset_tree: Tree
var btn_add_preset: Button
var btn_clone_preset: Button
var btn_delete_preset: Button

# Visualizer Row Controls
var waveform_playhead: Control
var vu_meter: Control

# Top Parameter Toolbar Controls
var name_edit: LineEdit
var type_option: OptionButton
var chk_loop: CheckBox
var knob_duration: Control
var knob_master_gain: Control

# Layer strip (Layer_Container only)
var layer_strip: PanelContainer
var layer_list: ItemList
var knob_start_offset: Control

# Card 1: Generator Card
var opt_gen_type: OptionButton
var knob_base_freq: Control
var knob_freq_var: Control
var knob_octave: Control
var knob_detune: Control

# Card 2: ADSR Envelope Card
var adsr_editor: Control
var knob_attack: Control
var knob_decay: Control
var knob_sustain: Control
var knob_release: Control

# Card 3: Filter Card
var opt_filter_mode: OptionButton
var knob_filter_cutoff: Control
var knob_filter_q: Control

# Card 4: LFO / Mod Matrix Card
var opt_lfo_wave: OptionButton
var knob_lfo_rate: Control
var knob_lfo_depth: Control
var opt_lfo_target: OptionButton

# Card 5: Drive / Saturation Card
var opt_drive_type: OptionButton
var knob_drive_amount: Control

# Card 6: Voicing & Stereo Pan Card
var opt_voice_mode: OptionButton
var knob_glide_time: Control
var knob_pan: Control

# Card 7: Master FX Card
var chk_delay_enable: CheckBox
var knob_delay_time: Control
var knob_delay_feedback: Control
var knob_delay_mix: Control
var chk_reverb_enable: CheckBox
var knob_reverb_size: Control
var knob_reverb_mix: Control

# Audition Transport Controls
var btn_audition_play: Button
var btn_audition_loop: Button
var btn_audition_stop: Button
var btn_save_all: Button

# Audio & State
var audio_player: AudioStreamPlayer
var current_preset_name: StringName = &""
var active_preset_dict: Dictionary = {}
var _is_updating_ui: bool = false
## Which layer the Generator / ADSR / Filter / LFO / Drive cards are editing.
## Ignored for a Single_Generator, where the preset root IS the layer.
var _capa_sel: int = 0
## Scratch target for writes that happen while the UI is refreshing itself.
## See `_capa_escribir`.
var _descarte: Dictionary = {}
var _is_auditioning: bool = false
var _preview_samples: PackedFloat32Array = PackedFloat32Array()

func _init() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	_build_ui()
	load_presets_from_registry()

func _ready() -> void:
	set_process(true)

func _build_ui() -> void:
	var root_margin = MarginContainer.new()
	root_margin.anchors_preset = Control.PRESET_FULL_RECT
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 4)
	root_margin.add_theme_constant_override("margin_top", 4)
	root_margin.add_theme_constant_override("margin_right", 4)
	root_margin.add_theme_constant_override("margin_bottom", 4)
	add_child(root_margin)

	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.split_offset = 200
	root_margin.add_child(main_hsplit)

	# ----------------------------------------------------
	# Left Panel: Preset Library & Management
	# ----------------------------------------------------
	var left_container = PanelContainer.new()
	left_container.custom_minimum_size = Vector2(190, 0)
	left_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(left_container)

	left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 4)
	left_container.add_child(left_panel)

	var lib_header = Label.new()
	lib_header.text = "📦 PRESET LIBRARY"
	lib_header.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(lib_header)

	preset_tree = Tree.new()
	preset_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preset_tree.hide_root = true
	preset_tree.select_mode = Tree.SELECT_ROW
	preset_tree.item_selected.connect(_on_tree_item_selected)
	left_panel.add_child(preset_tree)

	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 3)
	left_panel.add_child(btn_box)

	btn_add_preset = Button.new()
	btn_add_preset.text = "➕ New"
	btn_add_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add_preset.pressed.connect(func(): create_new_preset())
	btn_box.add_child(btn_add_preset)

	btn_clone_preset = Button.new()
	btn_clone_preset.text = "📋 Clone"
	btn_clone_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_clone_preset.pressed.connect(clone_current_preset)
	btn_box.add_child(btn_clone_preset)

	btn_delete_preset = Button.new()
	btn_delete_preset.text = "🗑️ Delete"
	btn_delete_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_delete_preset.pressed.connect(delete_current_preset)
	btn_box.add_child(btn_delete_preset)

	# ----------------------------------------------------
	# Right Panel: Full VST Rack & Workspace
	# ----------------------------------------------------
	right_scroll = ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(0, 0)
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_hsplit.add_child(right_scroll)

	vbox_rack = VBoxContainer.new()
	vbox_rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_rack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_rack.add_theme_constant_override("separation", 6)
	right_scroll.add_child(vbox_rack)

	# 1. Visualizer Row (Waveform + Sweeping Playhead + Stereo VU Meter)
	var viz_row = HBoxContainer.new()
	viz_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viz_row.custom_minimum_size = Vector2(0, 85)
	viz_row.add_theme_constant_override("separation", 6)
	vbox_rack.add_child(viz_row)

	waveform_playhead = OpenDouWaveformPlayheadClass.new()
	waveform_playhead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waveform_playhead.size_flags_vertical = Control.SIZE_EXPAND_FILL
	waveform_playhead.custom_minimum_size = Vector2(0, 85)
	viz_row.add_child(waveform_playhead)

	vu_meter = OpenDouVUMeterClass.new()
	vu_meter.is_vertical = true
	vu_meter.custom_minimum_size = Vector2(28, 85)
	viz_row.add_child(vu_meter)

	# 2. Top Parameter Toolbar
	var toolbar_panel = _create_card_container(Color(0.15, 0.18, 0.25, 0.8))
	vbox_rack.add_child(toolbar_panel)

	var toolbar_box = HBoxContainer.new()
	toolbar_box.add_theme_constant_override("separation", 8)
	toolbar_panel.add_child(toolbar_box)

	var lbl_name = Label.new()
	lbl_name.text = "Preset:"
	toolbar_box.add_child(lbl_name)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(120, 24)
	name_edit.text_submitted.connect(_on_preset_name_submitted)
	toolbar_box.add_child(name_edit)

	var lbl_type = Label.new()
	lbl_type.text = "Type:"
	toolbar_box.add_child(lbl_type)

	type_option = OptionButton.new()
	type_option.add_item("Single_Generator", 0)
	type_option.add_item("Layer_Container", 1)
	type_option.item_selected.connect(_on_type_option_selected)
	toolbar_box.add_child(type_option)

	chk_loop = CheckBox.new()
	chk_loop.text = "🔁 Loop"
	chk_loop.toggled.connect(_on_loop_toggled)
	toolbar_box.add_child(chk_loop)

	knob_duration = OpenDouKnobClass.new()
	knob_duration.label = "Duration"
	knob_duration.min_value = 0.05
	knob_duration.max_value = 10.0
	knob_duration.step = 0.05
	knob_duration.suffix = " s"
	knob_duration.default_value = 1.0
	knob_duration.value_changed.connect(_on_duration_knob_changed)
	toolbar_box.add_child(knob_duration)

	knob_master_gain = OpenDouKnobClass.new()
	knob_master_gain.label = "Master Gain"
	knob_master_gain.min_value = -40.0
	knob_master_gain.max_value = 6.0
	knob_master_gain.step = 0.5
	knob_master_gain.suffix = " dB"
	knob_master_gain.default_value = 0.0
	knob_master_gain.value_changed.connect(_on_master_gain_knob_changed)
	toolbar_box.add_child(knob_master_gain)

	# 3. Modular Cards Flow / Grid
	var cards_container = HFlowContainer.new()
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("h_separation", 6)
	cards_container.add_theme_constant_override("v_separation", 6)
	# Layer strip: which layer the tone cards below are editing.
	# Built BEFORE the cards and added before them, because without it the cards
	# have no subject on a Layer_Container: they showed defaults and wrote into
	# the container root, where synthesize_wav reads none of them.
	vbox_rack.add_child(_build_layer_strip())

	vbox_rack.add_child(cards_container)

	# Card 1: Generator Card
	cards_container.add_child(_build_generator_card())

	# Card 2: ADSR Envelope Card
	cards_container.add_child(_build_adsr_card())

	# Card 3: Filter Card
	cards_container.add_child(_build_filter_card())

	# Card 4: LFO / Mod Matrix Card
	cards_container.add_child(_build_lfo_card())

	# Card 5: Drive / Saturation Card
	cards_container.add_child(_build_drive_card())

	# Card 6: Voicing & Stereo Pan Card
	cards_container.add_child(_build_voicing_card())

	# Card 7: Master FX Card
	cards_container.add_child(_build_fx_card())

	# 4. Audition Transport Bar
	var transport_panel = _create_card_container(Color(0.12, 0.16, 0.22, 0.9))
	vbox_rack.add_child(transport_panel)

	var transport_box = HBoxContainer.new()
	transport_box.add_theme_constant_override("separation", 8)
	transport_panel.add_child(transport_box)

	btn_audition_play = Button.new()
	btn_audition_play.text = "▶ Audition"
	btn_audition_play.custom_minimum_size = Vector2(90, 28)
	btn_audition_play.pressed.connect(_on_audition_play_pressed)
	transport_box.add_child(btn_audition_play)

	btn_audition_loop = Button.new()
	btn_audition_loop.text = "🔁 Loop"
	btn_audition_loop.toggle_mode = true
	btn_audition_loop.custom_minimum_size = Vector2(70, 28)
	transport_box.add_child(btn_audition_loop)

	btn_audition_stop = Button.new()
	btn_audition_stop.text = "⏹ Stop"
	btn_audition_stop.custom_minimum_size = Vector2(70, 28)
	btn_audition_stop.pressed.connect(_on_audition_stop_pressed)
	transport_box.add_child(btn_audition_stop)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport_box.add_child(spacer)

	btn_save_all = Button.new()
	btn_save_all.text = "💾 Save Presets"
	btn_save_all.custom_minimum_size = Vector2(110, 28)
	btn_save_all.pressed.connect(_on_save_all_pressed)
	transport_box.add_child(btn_save_all)

func _create_card_container(border_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_top = 6
	sb.content_margin_right = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	return panel

# ----------------------------------------------------------------
# Sub-Card Builders
# ----------------------------------------------------------------

## The layer strip: which layer the tone cards edit, and the layer-level timing
## that had no control at all before (`start_offset`).
##
## Hidden for a Single_Generator, where the preset root IS the layer and a list
## of one would be noise.
func _build_layer_strip() -> PanelContainer:
	layer_strip = _create_card_container(Color(0.95, 0.65, 0.2, 0.8))
	layer_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	layer_strip.add_child(vb)

	var header = Label.new()
	header.text = "LAYERS"
	header.add_theme_font_size_override("font_size", 11)
	vb.add_child(header)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)

	layer_list = ItemList.new()
	layer_list.custom_minimum_size = Vector2(220, 92)
	layer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_list.select_mode = ItemList.SELECT_SINGLE
	layer_list.item_selected.connect(_on_layer_selected)
	row.add_child(layer_list)

	var botones = VBoxContainer.new()
	botones.add_theme_constant_override("separation", 2)
	row.add_child(botones)

	var fila_a = HBoxContainer.new()
	fila_a.add_theme_constant_override("separation", 2)
	botones.add_child(fila_a)
	fila_a.add_child(_layer_button("➕", "Add a layer", func(): _on_layer_add()))
	fila_a.add_child(_layer_button("📋", "Duplicate the selected layer", func(): _on_layer_duplicate()))
	fila_a.add_child(_layer_button("🗑️", "Remove the selected layer", func(): _on_layer_remove()))

	var fila_b = HBoxContainer.new()
	fila_b.add_theme_constant_override("separation", 2)
	botones.add_child(fila_b)
	fila_b.add_child(_layer_button("▲", "Move the layer up", func(): _on_layer_move(-1)))
	fila_b.add_child(_layer_button("▼", "Move the layer down", func(): _on_layer_move(1)))

	knob_start_offset = OpenDouKnobClass.new()
	knob_start_offset.label = "Offset"
	knob_start_offset.min_value = 0.0
	knob_start_offset.max_value = 1.0
	knob_start_offset.step = 0.001
	knob_start_offset.suffix = " s"
	knob_start_offset.default_value = 0.0
	knob_start_offset.tooltip_text = "When this layer starts, in seconds from the top of the sound.\nThis is what lets a shot spread transient, body, mechanism and tail\ninstead of stacking everything on the same instant."
	knob_start_offset.value_changed.connect(_on_start_offset_changed)
	row.add_child(knob_start_offset)

	return layer_strip


func _layer_button(texto: String, pista: String, al_pulsar: Callable) -> Button:
	var b = Button.new()
	b.text = texto
	b.tooltip_text = pista
	b.custom_minimum_size = Vector2(30, 24)
	b.pressed.connect(al_pulsar)
	return b


## Repaints the list from the preset. Called on load and after every structural
## change, so the list never drifts from the data it claims to show.
func _refrescar_lista_capas() -> void:
	if layer_list == null:
		return
	var es_cont := SynthLayerOpsClass.is_container(active_preset_dict)
	if layer_strip:
		layer_strip.visible = es_cont
	layer_list.clear()
	if not es_cont:
		return
	var capas := SynthLayerOpsClass.layers(active_preset_dict)
	for i in range(capas.size()):
		var c: Dictionary = capas[i] if capas[i] is Dictionary else {}
		var off := float(c.get("start_offset", 0.0))
		var etiqueta := "%d. %s  [%s]" % [
			i + 1,
			str(c.get("name", "Layer %d" % (i + 1))),
			str(c.get("generator_type", "Basic_Wave")),
		]
		# The offset goes in the label on purpose: it is the one property you
		# need to see across ALL layers at once to understand the sound's shape,
		# and a knob only ever shows you the selected one.
		if off > 0.0:
			etiqueta += "  +%.0f ms" % (off * 1000.0)
		layer_list.add_item(etiqueta)
	if capas.size() > 0:
		_capa_sel = clampi(_capa_sel, 0, capas.size() - 1)
		layer_list.select(_capa_sel)


func _on_layer_selected(idx: int) -> void:
	_capa_sel = idx
	_update_ui_from_preset_dict()


func _on_layer_add() -> void:
	if not SynthLayerOpsClass.is_container(active_preset_dict):
		return
	_capa_sel = SynthLayerOpsClass.add(active_preset_dict)
	_tras_cambiar_capas()


func _on_layer_duplicate() -> void:
	if not SynthLayerOpsClass.is_container(active_preset_dict):
		return
	_capa_sel = SynthLayerOpsClass.duplicate_at(active_preset_dict, _capa_sel)
	_tras_cambiar_capas()


func _on_layer_remove() -> void:
	if not SynthLayerOpsClass.is_container(active_preset_dict):
		return
	_capa_sel = maxi(0, SynthLayerOpsClass.remove(active_preset_dict, _capa_sel))
	_tras_cambiar_capas()


func _on_layer_move(delta: int) -> void:
	if not SynthLayerOpsClass.is_container(active_preset_dict):
		return
	_capa_sel = SynthLayerOpsClass.move(active_preset_dict, _capa_sel, delta)
	_tras_cambiar_capas()


func _on_start_offset_changed(val: float) -> void:
	_capa_escribir()["start_offset"] = val
	_refrescar_lista_capas()
	_commit_preset_change()


## After any structural change: repaint the list, resync the cards to the newly
## selected layer, and persist. All three, always — doing two of the three is
## how an editor starts lying about what you are editing.
func _tras_cambiar_capas() -> void:
	_refrescar_lista_capas()
	_update_ui_from_preset_dict()
	_commit_preset_change()


func _build_generator_card() -> PanelContainer:
	var card = _create_card_container(Color(0.2, 0.7, 0.9, 0.7))
	card.custom_minimum_size = Vector2(250, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "1. GENERATOR"
	header.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	opt_gen_type = OptionButton.new()
	for i in range(GENERATOR_TYPES.size()):
		opt_gen_type.add_item(GENERATOR_TYPES[i], i)
	opt_gen_type.item_selected.connect(_on_gen_type_selected)
	vb.add_child(opt_gen_type)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	vb.add_child(hb)

	knob_base_freq = OpenDouKnobClass.new()
	knob_base_freq.label = "Freq"
	knob_base_freq.min_value = 20.0
	knob_base_freq.max_value = 8000.0
	knob_base_freq.step = 1.0
	knob_base_freq.suffix = " Hz"
	knob_base_freq.default_value = 440.0
	knob_base_freq.value_changed.connect(_on_base_freq_changed)
	hb.add_child(knob_base_freq)

	knob_freq_var = OpenDouKnobClass.new()
	knob_freq_var.label = "Var"
	knob_freq_var.min_value = 0.0
	knob_freq_var.max_value = 1.0
	knob_freq_var.step = 0.01
	knob_freq_var.suffix = ""
	knob_freq_var.default_value = 0.0
	knob_freq_var.value_changed.connect(_on_freq_var_changed)
	hb.add_child(knob_freq_var)

	knob_octave = OpenDouKnobClass.new()
	knob_octave.label = "Octave"
	knob_octave.min_value = -3.0
	knob_octave.max_value = 3.0
	knob_octave.step = 1.0
	knob_octave.suffix = " oct"
	knob_octave.default_value = 0.0
	knob_octave.value_changed.connect(_on_octave_changed)
	hb.add_child(knob_octave)

	knob_detune = OpenDouKnobClass.new()
	knob_detune.label = "Detune"
	knob_detune.min_value = -100.0
	knob_detune.max_value = 100.0
	knob_detune.step = 1.0
	knob_detune.suffix = " ct"
	knob_detune.default_value = 0.0
	knob_detune.value_changed.connect(_on_detune_changed)
	hb.add_child(knob_detune)

	return card

func _build_adsr_card() -> PanelContainer:
	var card = _create_card_container(Color(0.9, 0.4, 0.7, 0.7))
	card.custom_minimum_size = Vector2(280, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "2. ADSR ENVELOPE"
	header.add_theme_color_override("font_color", Color(1.0, 0.45, 0.75))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	adsr_editor = OpenDouADSREditorClass.new()
	adsr_editor.custom_minimum_size = Vector2(240, 70)
	adsr_editor.adsr_changed.connect(_on_adsr_editor_changed)
	vb.add_child(adsr_editor)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	vb.add_child(hb)

	knob_attack = OpenDouKnobClass.new()
	knob_attack.label = "Attack"
	knob_attack.min_value = 0.001
	knob_attack.max_value = 3.0
	knob_attack.step = 0.01
	knob_attack.suffix = " s"
	knob_attack.default_value = 0.05
	knob_attack.value_changed.connect(_on_attack_knob_changed)
	hb.add_child(knob_attack)

	knob_decay = OpenDouKnobClass.new()
	knob_decay.label = "Decay"
	knob_decay.min_value = 0.001
	knob_decay.max_value = 3.0
	knob_decay.step = 0.01
	knob_decay.suffix = " s"
	knob_decay.default_value = 0.1
	knob_decay.value_changed.connect(_on_decay_knob_changed)
	hb.add_child(knob_decay)

	knob_sustain = OpenDouKnobClass.new()
	knob_sustain.label = "Sustain"
	knob_sustain.min_value = 0.0
	knob_sustain.max_value = 1.0
	knob_sustain.step = 0.01
	knob_sustain.suffix = ""
	knob_sustain.default_value = 0.7
	knob_sustain.value_changed.connect(_on_sustain_knob_changed)
	hb.add_child(knob_sustain)

	knob_release = OpenDouKnobClass.new()
	knob_release.label = "Release"
	knob_release.min_value = 0.001
	knob_release.max_value = 4.0
	knob_release.step = 0.01
	knob_release.suffix = " s"
	knob_release.default_value = 0.2
	knob_release.value_changed.connect(_on_release_knob_changed)
	hb.add_child(knob_release)

	return card

func _build_filter_card() -> PanelContainer:
	var card = _create_card_container(Color(0.3, 0.85, 0.45, 0.7))
	card.custom_minimum_size = Vector2(210, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "3. BIQUAD FILTER"
	header.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	opt_filter_mode = OptionButton.new()
	for i in range(FILTER_TYPES.size()):
		opt_filter_mode.add_item(FILTER_TYPES[i], i)
	opt_filter_mode.item_selected.connect(_on_filter_mode_selected)
	vb.add_child(opt_filter_mode)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)

	knob_filter_cutoff = OpenDouKnobClass.new()
	knob_filter_cutoff.label = "Cutoff"
	knob_filter_cutoff.min_value = 20.0
	knob_filter_cutoff.max_value = 20000.0
	knob_filter_cutoff.step = 10.0
	knob_filter_cutoff.suffix = " Hz"
	knob_filter_cutoff.default_value = 2000.0
	knob_filter_cutoff.value_changed.connect(_on_filter_cutoff_changed)
	hb.add_child(knob_filter_cutoff)

	knob_filter_q = OpenDouKnobClass.new()
	knob_filter_q.label = "Resonance"
	knob_filter_q.min_value = 0.1
	knob_filter_q.max_value = 20.0
	knob_filter_q.step = 0.1
	knob_filter_q.suffix = " Q"
	knob_filter_q.default_value = 1.0
	knob_filter_q.value_changed.connect(_on_filter_q_changed)
	hb.add_child(knob_filter_q)

	return card

func _build_lfo_card() -> PanelContainer:
	var card = _create_card_container(Color(0.85, 0.65, 0.2, 0.7))
	card.custom_minimum_size = Vector2(230, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "4. LFO / MOD MATRIX"
	header.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	var top_hb = HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 4)
	vb.add_child(top_hb)

	opt_lfo_wave = OptionButton.new()
	for i in range(LFO_WAVES.size()):
		opt_lfo_wave.add_item(LFO_WAVES[i], i)
	opt_lfo_wave.item_selected.connect(_on_lfo_wave_selected)
	opt_lfo_wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(opt_lfo_wave)

	opt_lfo_target = OptionButton.new()
	for i in range(LFO_TARGETS.size()):
		opt_lfo_target.add_item(LFO_TARGETS[i], i)
	opt_lfo_target.item_selected.connect(_on_lfo_target_selected)
	opt_lfo_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(opt_lfo_target)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)

	knob_lfo_rate = OpenDouKnobClass.new()
	knob_lfo_rate.label = "Rate"
	knob_lfo_rate.min_value = 0.1
	knob_lfo_rate.max_value = 100.0
	knob_lfo_rate.step = 0.1
	knob_lfo_rate.suffix = " Hz"
	knob_lfo_rate.default_value = 2.0
	knob_lfo_rate.value_changed.connect(_on_lfo_rate_changed)
	hb.add_child(knob_lfo_rate)

	knob_lfo_depth = OpenDouKnobClass.new()
	knob_lfo_depth.label = "Depth"
	knob_lfo_depth.min_value = 0.0
	knob_lfo_depth.max_value = 1.0
	knob_lfo_depth.step = 0.01
	knob_lfo_depth.suffix = ""
	knob_lfo_depth.default_value = 0.0
	knob_lfo_depth.value_changed.connect(_on_lfo_depth_changed)
	hb.add_child(knob_lfo_depth)

	return card

func _build_drive_card() -> PanelContainer:
	var card = _create_card_container(Color(0.9, 0.25, 0.25, 0.7))
	card.custom_minimum_size = Vector2(170, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "5. DRIVE / SAT"
	header.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	opt_drive_type = OptionButton.new()
	for i in range(DRIVE_TYPES.size()):
		opt_drive_type.add_item(DRIVE_TYPES[i], i)
	opt_drive_type.item_selected.connect(_on_drive_type_selected)
	vb.add_child(opt_drive_type)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)

	knob_drive_amount = OpenDouKnobClass.new()
	knob_drive_amount.label = "Amount"
	knob_drive_amount.min_value = 0.1
	knob_drive_amount.max_value = 10.0
	knob_drive_amount.step = 0.1
	knob_drive_amount.suffix = "x"
	knob_drive_amount.default_value = 1.0
	knob_drive_amount.value_changed.connect(_on_drive_amount_changed)
	hb.add_child(knob_drive_amount)

	return card

func _build_voicing_card() -> PanelContainer:
	var card = _create_card_container(Color(0.65, 0.4, 0.9, 0.7))
	card.custom_minimum_size = Vector2(210, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "6. VOICING & PAN"
	header.add_theme_color_override("font_color", Color(0.75, 0.5, 1.0))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	opt_voice_mode = OptionButton.new()
	for i in range(VOICE_MODES.size()):
		opt_voice_mode.add_item(VOICE_MODES[i], i)
	opt_voice_mode.item_selected.connect(_on_voice_mode_selected)
	vb.add_child(opt_voice_mode)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)

	knob_glide_time = OpenDouKnobClass.new()
	knob_glide_time.label = "Glide"
	knob_glide_time.min_value = 0.0
	knob_glide_time.max_value = 1.0
	knob_glide_time.step = 0.01
	knob_glide_time.suffix = " s"
	knob_glide_time.default_value = 0.0
	knob_glide_time.value_changed.connect(_on_glide_time_changed)
	hb.add_child(knob_glide_time)

	knob_pan = OpenDouKnobClass.new()
	knob_pan.label = "Pan"
	knob_pan.min_value = -1.0
	knob_pan.max_value = 1.0
	knob_pan.step = 0.02
	knob_pan.suffix = ""
	knob_pan.default_value = 0.0
	knob_pan.value_changed.connect(_on_pan_changed)
	hb.add_child(knob_pan)

	return card

func _build_fx_card() -> PanelContainer:
	var card = _create_card_container(Color(0.2, 0.8, 0.8, 0.7))
	card.custom_minimum_size = Vector2(320, 140)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var header = Label.new()
	header.text = "7. MASTER FX (Delay & Reverb)"
	header.add_theme_color_override("font_color", Color(0.3, 0.9, 0.9))
	header.add_theme_font_size_override("font_size", 10)
	vb.add_child(header)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	vb.add_child(hb)

	# Delay Sub-box
	var delay_vb = VBoxContainer.new()
	delay_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(delay_vb)

	chk_delay_enable = CheckBox.new()
	chk_delay_enable.text = "Delay"
	chk_delay_enable.toggled.connect(_on_delay_toggled)
	delay_vb.add_child(chk_delay_enable)

	var delay_knobs = HBoxContainer.new()
	delay_knobs.add_theme_constant_override("separation", 2)
	delay_vb.add_child(delay_knobs)

	knob_delay_time = OpenDouKnobClass.new()
	knob_delay_time.label = "Time"
	knob_delay_time.min_value = 10.0
	knob_delay_time.max_value = 1000.0
	knob_delay_time.step = 5.0
	knob_delay_time.suffix = " ms"
	knob_delay_time.default_value = 180.0
	knob_delay_time.value_changed.connect(_on_delay_time_changed)
	delay_knobs.add_child(knob_delay_time)

	knob_delay_feedback = OpenDouKnobClass.new()
	knob_delay_feedback.label = "Fbk"
	knob_delay_feedback.min_value = 0.0
	knob_delay_feedback.max_value = 0.95
	knob_delay_feedback.step = 0.01
	knob_delay_feedback.suffix = ""
	knob_delay_feedback.default_value = 0.35
	knob_delay_feedback.value_changed.connect(_on_delay_feedback_changed)
	delay_knobs.add_child(knob_delay_feedback)

	knob_delay_mix = OpenDouKnobClass.new()
	knob_delay_mix.label = "Mix"
	knob_delay_mix.min_value = 0.0
	knob_delay_mix.max_value = 1.0
	knob_delay_mix.step = 0.01
	knob_delay_mix.suffix = ""
	knob_delay_mix.default_value = 0.25
	knob_delay_mix.value_changed.connect(_on_delay_mix_changed)
	delay_knobs.add_child(knob_delay_mix)

	# Reverb Sub-box
	var reverb_vb = VBoxContainer.new()
	reverb_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(reverb_vb)

	chk_reverb_enable = CheckBox.new()
	chk_reverb_enable.text = "Reverb"
	chk_reverb_enable.toggled.connect(_on_reverb_toggled)
	reverb_vb.add_child(chk_reverb_enable)

	var reverb_knobs = HBoxContainer.new()
	reverb_knobs.add_theme_constant_override("separation", 2)
	reverb_vb.add_child(reverb_knobs)

	knob_reverb_size = OpenDouKnobClass.new()
	knob_reverb_size.label = "Size"
	knob_reverb_size.min_value = 0.0
	knob_reverb_size.max_value = 1.0
	knob_reverb_size.step = 0.01
	knob_reverb_size.suffix = ""
	knob_reverb_size.default_value = 0.65
	knob_reverb_size.value_changed.connect(_on_reverb_size_changed)
	reverb_knobs.add_child(knob_reverb_size)

	knob_reverb_mix = OpenDouKnobClass.new()
	knob_reverb_mix.label = "Mix"
	knob_reverb_mix.min_value = 0.0
	knob_reverb_mix.max_value = 1.0
	knob_reverb_mix.step = 0.01
	knob_reverb_mix.suffix = ""
	knob_reverb_mix.default_value = 0.20
	knob_reverb_mix.value_changed.connect(_on_reverb_mix_changed)
	reverb_knobs.add_child(knob_reverb_mix)

	return card

# ----------------------------------------------------------------
# Preset Registry Synchronization
# ----------------------------------------------------------------

func load_presets_from_registry() -> void:
	if preset_tree == null:
		return
	preset_tree.clear()
	var root = preset_tree.create_item()

	var names = SynthPresetRegistryClass.get_singleton().get_preset_names()
	for n in names:
		var item = preset_tree.create_item(root)
		item.set_text(0, "⚡ " + str(n))
		item.set_metadata(0, n)

	if names.size() > 0:
		if current_preset_name.is_empty() or not names.has(current_preset_name):
			select_preset(names[0])
		else:
			select_preset(current_preset_name)

func select_preset(p_name: StringName) -> void:
	current_preset_name = p_name
	# New preset selected: start on its first layer, not on whatever index the
	# previous preset happened to leave behind.
	_capa_sel = 0
	active_preset_dict = SynthPresetRegistryClass.get_singleton().get_preset(p_name)
	if active_preset_dict.is_empty():
		active_preset_dict = {
			"type": "Single_Generator",
			"generator_type": "Basic_Wave",
			"wave_type": "Sine",
			"base_freq": 440.0,
			"duration": 1.0,
			"gain_db": -6.0,
			"loop_mode": false,
			"envelope": {
				"attack": 0.05,
				"decay": 0.1,
				"sustain": 0.7,
				"release": 0.2
			}
		}

	_update_ui_from_preset_dict()
	_refresh_preview(true)
	preset_selected.emit(current_preset_name)

func get_current_preset_name() -> StringName:
	return current_preset_name

func get_current_preset_dict() -> Dictionary:
	return active_preset_dict

func create_new_preset(preset_name: StringName = &"") -> void:
	if preset_name.is_empty():
		var existing = SynthPresetRegistryClass.get_singleton().get_preset_names()
		var idx: int = existing.size() + 1
		preset_name = StringName("Synth_Preset_%d" % idx)

	var new_dict: Dictionary = {
		"type": "Single_Generator",
		"generator_type": "Basic_Wave",
		"wave_type": "Sine",
		"base_freq": 440.0,
		"duration": 1.0,
		"gain_db": -6.0,
		"loop_mode": false,
		"envelope": {
			"attack": 0.05,
			"decay": 0.1,
			"sustain": 0.7,
			"release": 0.2
		}
	}
	SynthPresetRegistryClass.get_singleton().set_preset(preset_name, new_dict)
	load_presets_from_registry()
	select_preset(preset_name)

func clone_current_preset() -> void:
	if current_preset_name.is_empty():
		return
	var clone_name = StringName(str(current_preset_name) + "_Clone")
	SynthPresetRegistryClass.get_singleton().set_preset(clone_name, active_preset_dict.duplicate(true))
	load_presets_from_registry()
	select_preset(clone_name)

func delete_current_preset() -> void:
	if current_preset_name.is_empty():
		return
	SynthPresetRegistryClass.get_singleton().delete_preset(current_preset_name)
	load_presets_from_registry()

## The dictionary the tone cards READ from. May be empty — a container with no
## layers yet — and that is fine: the cards then show their defaults, which is
## honest, because there is nothing to show.
func _capa_leer() -> Dictionary:
	return SynthLayerOpsClass.target(active_preset_dict, _capa_sel)


## The dictionary the tone cards WRITE to.
##
## Differs from `_capa_leer` in one thing that matters: on a container with no
## layers it creates one instead of returning an empty dictionary. Writing into
## a temporary would swallow the edit silently — a knob that moves and does
## nothing, which is the bug this whole change is here to fix.
func _capa_escribir() -> Dictionary:
	# While the UI is being refreshed, writes go to a scratch dictionary and are
	# thrown away.
	#
	# This is not defensive padding, it is a real bug fix. Setting `.value` on a
	# knob emits `value_changed`, which calls the handler, which writes. So
	# merely DISPLAYING a preset stamped every card's default onto it:
	# base_freq 440, envelope 0.05/0.1/0.7/0.2, filter None/2000/1.0. The
	# `_is_updating_ui` flag only ever guarded `_commit_preset_change`, so the
	# write had already happened by the time anything checked.
	#
	# That is where the shipped Layer_Containers carrying dead root keys came
	# from: opening one in the workspace was enough. Without this guard the same
	# thing would now happen one level down, stamping defaults into real layers,
	# which is worse — those are not dead keys, they are the sound.
	# Deliberately NOT cleared here. Several handlers touch the target three
	# times in a row —`has("envelope")`, create it, then write into it— and
	# clearing on every access wiped the sub-dictionary between the second call
	# and the third. It is emptied once per refresh instead, in
	# `_update_ui_from_preset_dict`.
	if _is_updating_ui:
		return _descarte
	if not SynthLayerOpsClass.is_container(active_preset_dict):
		return active_preset_dict
	if SynthLayerOpsClass.count(active_preset_dict) == 0:
		_capa_sel = SynthLayerOpsClass.add(active_preset_dict)
		_refrescar_lista_capas()
	elif not SynthLayerOpsClass.valid(active_preset_dict, _capa_sel):
		_capa_sel = 0
	return SynthLayerOpsClass.at(active_preset_dict, _capa_sel)


func _update_ui_from_preset_dict() -> void:
	_is_updating_ui = true
	_descarte.clear()

	if name_edit:
		name_edit.text = str(current_preset_name)

	var p_type = active_preset_dict.get("type", "Single_Generator")
	if type_option:
		type_option.selected = 1 if p_type == "Layer_Container" else 0

	if chk_loop:
		chk_loop.button_pressed = bool(active_preset_dict.get("loop_mode", false))

	if knob_duration:
		knob_duration.value = float(active_preset_dict.get("duration", 1.0))

	if knob_master_gain:
		knob_master_gain.value = float(active_preset_dict.get("gain_db", 0.0))

	# The layer list, and the offset of whichever layer is selected. Repainting
	# here and not only on load keeps the list honest after a rename or a type
	# change.
	_refrescar_lista_capas()
	if knob_start_offset:
		knob_start_offset.value = float(_capa_leer().get("start_offset", 0.0))

	# Generator Card
	var gen_type = _capa_leer().get("generator_type", "Basic_Wave")
	if opt_gen_type:
		var g_idx = GENERATOR_TYPES.find(gen_type)
		opt_gen_type.selected = g_idx if g_idx >= 0 else 0

	if knob_base_freq:
		knob_base_freq.value = float(_capa_leer().get("base_freq", 440.0))

	if knob_freq_var:
		knob_freq_var.value = float(_capa_leer().get("base_freq_var", 0.0))

	# ADSR Card
	var env_dict = _capa_leer().get("envelope", {})
	var att = float(env_dict.get("attack", 0.05))
	var dec = float(env_dict.get("decay", 0.1))
	var sus = float(env_dict.get("sustain", 0.7))
	var rel = float(env_dict.get("release", 0.2))

	if adsr_editor:
		adsr_editor.set_adsr(att, dec, sus, rel)
	if knob_attack:
		knob_attack.value = att
	if knob_decay:
		knob_decay.value = dec
	if knob_sustain:
		knob_sustain.value = sus
	if knob_release:
		knob_release.value = rel

	# Filter Card
	var f_dict = _capa_leer().get("filter", {})
	var f_type = f_dict.get("type", "None")
	if opt_filter_mode:
		var f_idx = FILTER_TYPES.find(f_type)
		opt_filter_mode.selected = f_idx if f_idx >= 0 else 0
	if knob_filter_cutoff:
		knob_filter_cutoff.value = float(f_dict.get("cutoff_hz", 2000.0))
	if knob_filter_q:
		knob_filter_q.value = float(f_dict.get("resonance_q", 1.0))

	# LFO Card
	var lfo_dict = _capa_leer().get("lfo", {})
	var l_wave = lfo_dict.get("wave", "Sine")
	var l_target = lfo_dict.get("target", "Amplitude")
	if opt_lfo_wave:
		var lw_idx = LFO_WAVES.find(l_wave)
		opt_lfo_wave.selected = lw_idx if lw_idx >= 0 else 0
	if opt_lfo_target:
		var lt_idx = LFO_TARGETS.find(l_target)
		opt_lfo_target.selected = lt_idx if lt_idx >= 0 else 0
	if knob_lfo_rate:
		knob_lfo_rate.value = float(lfo_dict.get("rate_hz", 2.0))
	if knob_lfo_depth:
		knob_lfo_depth.value = float(lfo_dict.get("depth", 0.0))

	# Drive Card
	var d_dict = _capa_leer().get("drive", {})
	var d_type = d_dict.get("type", "None")
	if opt_drive_type:
		var dt_idx = DRIVE_TYPES.find(d_type)
		opt_drive_type.selected = dt_idx if dt_idx >= 0 else 0
	if knob_drive_amount:
		knob_drive_amount.value = float(d_dict.get("amount", 1.0))

	# Voicing Card
	var v_dict = active_preset_dict.get("voice", {})
	var v_mode = v_dict.get("mode", "Mono")
	if opt_voice_mode:
		var vm_idx = VOICE_MODES.find(v_mode)
		opt_voice_mode.selected = vm_idx if vm_idx >= 0 else 0
	if knob_glide_time:
		knob_glide_time.value = float(v_dict.get("glide_ms", 0.0)) / 1000.0
	if knob_pan:
		knob_pan.value = float(active_preset_dict.get("pan", 0.0))

	# Master FX Card
	var fx_dict = active_preset_dict.get("fx", {})
	var delay_dict = fx_dict.get("delay", {})
	if chk_delay_enable:
		chk_delay_enable.button_pressed = bool(delay_dict.get("enabled", false))
	if knob_delay_time:
		knob_delay_time.value = float(delay_dict.get("time_ms", 180.0))
	if knob_delay_feedback:
		knob_delay_feedback.value = float(delay_dict.get("feedback", 0.35))
	if knob_delay_mix:
		knob_delay_mix.value = float(delay_dict.get("mix", 0.25))

	var reverb_dict = fx_dict.get("reverb", {})
	if chk_reverb_enable:
		chk_reverb_enable.button_pressed = bool(reverb_dict.get("enabled", false))
	if knob_reverb_size:
		knob_reverb_size.value = float(reverb_dict.get("room_size", 0.65))
	if knob_reverb_mix:
		knob_reverb_mix.value = float(reverb_dict.get("mix", 0.20))

	_is_updating_ui = false

func _commit_preset_change() -> void:
	if _is_updating_ui:
		return
	if not current_preset_name.is_empty():
		SynthPresetRegistryClass.get_singleton().set_preset(current_preset_name, active_preset_dict)
		preset_modified.emit(current_preset_name, active_preset_dict)
	_refresh_preview(true)

## Samples of a rendered stream, for drawing. A container with pan, delay or
## reverb comes out stereo; the left channel is drawn, which for judging the
## shape of the envelope is the same thing and avoids a waveform twice as long.
func _decode_preview(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if stream == null:
		return out
	var step: int = 4 if stream.stereo else 2
	var n: int = stream.data.size() / step
	out.resize(n)
	for i in range(n):
		out[i] = float(stream.data.decode_s16(i * step)) / 32768.0
	return out


func _refresh_preview(re_synthesize: bool = true) -> void:
	if re_synthesize:
		var dur = float(active_preset_dict.get("duration", 1.0))
		# A Layer_Container has no generator_type of its own, so passing it to
		# generate_layer_samples fell through to the default (Basic_Wave at
		# 440 Hz): the drawn waveform had nothing to do with what you hear. Every
		# layered preset drew the same perfect sine no matter its contents.
		# synthesize_wav is what the play button uses, and drawing and sound
		# coming out of the same function is exactly the point.
		if str(active_preset_dict.get("type", "Single_Generator")) == "Layer_Container":
			_preview_samples = _decode_preview(
				ModularSynthEngineClass.synthesize_wav(active_preset_dict, 100))
		else:
			_preview_samples = ModularSynthEngineClass.generate_layer_samples(active_preset_dict, dur, 44100, 100)
		if waveform_playhead:
			waveform_playhead.set_waveform(_preview_samples)

	if waveform_playhead and not _capa_leer().get("envelope", {}).is_empty():
		var env = _capa_leer()["envelope"]
		var a = float(env.get("attack", 0.05))
		var d = float(env.get("decay", 0.1))
		var s = float(env.get("sustain", 0.7))
		var r = float(env.get("release", 0.2))
		var dur = float(active_preset_dict.get("duration", 1.0))
		waveform_playhead.set_adsr_overlay(a, d, s, r, dur)

# ----------------------------------------------------------------
# UI Event Handlers
# ----------------------------------------------------------------

func _on_tree_item_selected() -> void:
	var item = preset_tree.get_selected()
	if item:
		var p_name = item.get_metadata(0)
		if p_name != null and p_name is StringName:
			select_preset(p_name)

func _on_preset_name_submitted(new_name: String) -> void:
	new_name = new_name.strip_edges()
	if new_name.is_empty() or StringName(new_name) == current_preset_name:
		return
	var old_name = current_preset_name
	var s_name = StringName(new_name)
	SynthPresetRegistryClass.get_singleton().delete_preset(old_name)
	SynthPresetRegistryClass.get_singleton().set_preset(s_name, active_preset_dict)
	current_preset_name = s_name
	load_presets_from_registry()
	select_preset(s_name)

func _on_type_option_selected(idx: int) -> void:
	if idx == 1:
		# Not a flag flip: the sound you had built lives in fields that only mean
		# something on a layer, so they move INTO the first layer. Merely setting
		# the type left them stranded on the container root, where
		# synthesize_wav reads none of them — that is exactly where the shipped
		# presets carrying dead root keys came from.
		SynthLayerOpsClass.to_container(active_preset_dict)
		_capa_sel = 0
	else:
		active_preset_dict["type"] = "Single_Generator"
	_tras_cambiar_capas()

func _on_loop_toggled(is_loop: bool) -> void:
	active_preset_dict["loop_mode"] = is_loop
	_commit_preset_change()

func _on_duration_knob_changed(val: float) -> void:
	active_preset_dict["duration"] = val
	_commit_preset_change()

func _on_master_gain_knob_changed(val: float) -> void:
	active_preset_dict["gain_db"] = val
	_commit_preset_change()

func _on_gen_type_selected(idx: int) -> void:
	if idx >= 0 and idx < GENERATOR_TYPES.size():
		_capa_escribir()["generator_type"] = GENERATOR_TYPES[idx]
		_commit_preset_change()

func _on_base_freq_changed(val: float) -> void:
	_capa_escribir()["base_freq"] = val
	_commit_preset_change()

func _on_freq_var_changed(val: float) -> void:
	_capa_escribir()["base_freq_var"] = val
	_commit_preset_change()

func _on_octave_changed(val: float) -> void:
	_capa_escribir()["octave"] = int(roundf(val))
	_commit_preset_change()

func _on_detune_changed(val: float) -> void:
	_capa_escribir()["detune_cents"] = val
	_commit_preset_change()

func _on_adsr_editor_changed(a: float, d: float, s: float, r: float) -> void:
	# The flag is SAVED and RESTORED, not forced to false.
	#
	# This handler runs re-entrantly: refreshing the UI calls
	# `adsr_editor.set_adsr()`, which emits `adsr_changed`, which lands here. The
	# old code set the flag false on its way out, which did not just let this
	# write through — it disarmed the guard for the whole rest of the refresh, so
	# every knob assignment after the ADSR card wrote its default into the
	# preset. It was the main way presets picked up values nobody dialled in.
	var estaba := _is_updating_ui
	_is_updating_ui = true
	if knob_attack: knob_attack.value = a
	if knob_decay: knob_decay.value = d
	if knob_sustain: knob_sustain.value = s
	if knob_release: knob_release.value = r
	_is_updating_ui = estaba

	if not _capa_escribir().has("envelope"):
		_capa_escribir()["envelope"] = {}
	_capa_escribir()["envelope"]["attack"] = a
	_capa_escribir()["envelope"]["decay"] = d
	_capa_escribir()["envelope"]["sustain"] = s
	_capa_escribir()["envelope"]["release"] = r
	_commit_preset_change()

func _on_attack_knob_changed(val: float) -> void:
	if not _is_updating_ui and adsr_editor:
		adsr_editor.attack = val
	if not _capa_escribir().has("envelope"):
		_capa_escribir()["envelope"] = {}
	_capa_escribir()["envelope"]["attack"] = val
	_commit_preset_change()

func _on_decay_knob_changed(val: float) -> void:
	if not _is_updating_ui and adsr_editor:
		adsr_editor.decay = val
	if not _capa_escribir().has("envelope"):
		_capa_escribir()["envelope"] = {}
	_capa_escribir()["envelope"]["decay"] = val
	_commit_preset_change()

func _on_sustain_knob_changed(val: float) -> void:
	if not _is_updating_ui and adsr_editor:
		adsr_editor.sustain = val
	if not _capa_escribir().has("envelope"):
		_capa_escribir()["envelope"] = {}
	_capa_escribir()["envelope"]["sustain"] = val
	_commit_preset_change()

func _on_release_knob_changed(val: float) -> void:
	if not _is_updating_ui and adsr_editor:
		adsr_editor.release = val
	if not _capa_escribir().has("envelope"):
		_capa_escribir()["envelope"] = {}
	_capa_escribir()["envelope"]["release"] = val
	_commit_preset_change()

func _on_filter_mode_selected(idx: int) -> void:
	if idx >= 0 and idx < FILTER_TYPES.size():
		if not _capa_escribir().has("filter"):
			_capa_escribir()["filter"] = {}
		_capa_escribir()["filter"]["type"] = FILTER_TYPES[idx]
		_commit_preset_change()

func _on_filter_cutoff_changed(val: float) -> void:
	if not _capa_escribir().has("filter"):
		_capa_escribir()["filter"] = {}
	_capa_escribir()["filter"]["cutoff_hz"] = val
	_commit_preset_change()

func _on_filter_q_changed(val: float) -> void:
	if not _capa_escribir().has("filter"):
		_capa_escribir()["filter"] = {}
	_capa_escribir()["filter"]["resonance_q"] = val
	_commit_preset_change()

func _on_lfo_wave_selected(idx: int) -> void:
	if idx >= 0 and idx < LFO_WAVES.size():
		if not _capa_escribir().has("lfo"):
			_capa_escribir()["lfo"] = {}
		_capa_escribir()["lfo"]["wave"] = LFO_WAVES[idx]
		_commit_preset_change()

func _on_lfo_target_selected(idx: int) -> void:
	if idx >= 0 and idx < LFO_TARGETS.size():
		if not _capa_escribir().has("lfo"):
			_capa_escribir()["lfo"] = {}
		_capa_escribir()["lfo"]["target"] = LFO_TARGETS[idx]
		_commit_preset_change()

func _on_lfo_rate_changed(val: float) -> void:
	if not _capa_escribir().has("lfo"):
		_capa_escribir()["lfo"] = {}
	_capa_escribir()["lfo"]["rate_hz"] = val
	_commit_preset_change()

func _on_lfo_depth_changed(val: float) -> void:
	if not _capa_escribir().has("lfo"):
		_capa_escribir()["lfo"] = {}
	_capa_escribir()["lfo"]["depth"] = val
	_commit_preset_change()

func _on_drive_type_selected(idx: int) -> void:
	if idx >= 0 and idx < DRIVE_TYPES.size():
		if not _capa_escribir().has("drive"):
			_capa_escribir()["drive"] = {}
		_capa_escribir()["drive"]["type"] = DRIVE_TYPES[idx]
		_commit_preset_change()

func _on_drive_amount_changed(val: float) -> void:
	if not _capa_escribir().has("drive"):
		_capa_escribir()["drive"] = {}
	_capa_escribir()["drive"]["amount"] = val
	_commit_preset_change()

func _on_voice_mode_selected(idx: int) -> void:
	if idx >= 0 and idx < VOICE_MODES.size():
		if not _capa_escribir().has("voice"):
			_capa_escribir()["voice"] = {}
		_capa_escribir()["voice"]["mode"] = VOICE_MODES[idx]
		_commit_preset_change()

func _on_glide_time_changed(val: float) -> void:
	if not _capa_escribir().has("voice"):
		_capa_escribir()["voice"] = {}
	_capa_escribir()["voice"]["glide_ms"] = val * 1000.0
	_commit_preset_change()

func _on_pan_changed(val: float) -> void:
	active_preset_dict["pan"] = val
	_commit_preset_change()

func _on_delay_toggled(enabled: bool) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("delay"):
		active_preset_dict["fx"]["delay"] = {}
	active_preset_dict["fx"]["delay"]["enabled"] = enabled
	_commit_preset_change()

func _on_delay_time_changed(val: float) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("delay"):
		active_preset_dict["fx"]["delay"] = {}
	active_preset_dict["fx"]["delay"]["time_ms"] = val
	_commit_preset_change()

func _on_delay_feedback_changed(val: float) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("delay"):
		active_preset_dict["fx"]["delay"] = {}
	active_preset_dict["fx"]["delay"]["feedback"] = val
	_commit_preset_change()

func _on_delay_mix_changed(val: float) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("delay"):
		active_preset_dict["fx"]["delay"] = {}
	active_preset_dict["fx"]["delay"]["mix"] = val
	_commit_preset_change()

func _on_reverb_toggled(enabled: bool) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("reverb"):
		active_preset_dict["fx"]["reverb"] = {}
	active_preset_dict["fx"]["reverb"]["enabled"] = enabled
	_commit_preset_change()

func _on_reverb_size_changed(val: float) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("reverb"):
		active_preset_dict["fx"]["reverb"] = {}
	active_preset_dict["fx"]["reverb"]["room_size"] = val
	_commit_preset_change()

func _on_reverb_mix_changed(val: float) -> void:
	if not active_preset_dict.has("fx"):
		active_preset_dict["fx"] = {}
	if not active_preset_dict["fx"].has("reverb"):
		active_preset_dict["fx"]["reverb"] = {}
	active_preset_dict["fx"]["reverb"]["mix"] = val
	_commit_preset_change()

# ----------------------------------------------------------------
# Audition & Animation
# ----------------------------------------------------------------

func _on_audition_play_pressed() -> void:
	_refresh_preview(true)
	var stream = ModularSynthEngineClass.synthesize_wav(active_preset_dict, 0)
	if stream == null:
		return
	if btn_audition_loop and btn_audition_loop.button_pressed:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(float(active_preset_dict.get("duration", 1.0)) * stream.mix_rate)
	audio_player.stream = stream
	if is_inside_tree():
		audio_player.play()
	_is_auditioning = true
	if waveform_playhead:
		waveform_playhead.set_playhead(0.0)

func _on_audition_stop_pressed() -> void:
	if audio_player and audio_player.playing:
		audio_player.stop()
	_is_auditioning = false
	if waveform_playhead:
		waveform_playhead.set_playhead(-1.0)
	if vu_meter:
		vu_meter.set_level(-80.0, -80.0)

func _on_save_all_pressed() -> void:
	SynthPresetRegistryClass.get_singleton().save_presets()

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if audio_player and audio_player.playing:
		var pos: float = audio_player.get_playback_position()
		var length: float = 1.0
		if audio_player.stream:
			length = audio_player.stream.get_length()
		elif active_preset_dict.has("duration"):
			length = float(active_preset_dict.get("duration", 1.0))
		length = maxf(0.001, length)
		var progress: float = clampf(pos / length, 0.0, 1.0)
		if waveform_playhead:
			waveform_playhead.set_playhead(progress)

		if vu_meter:
			var s_idx: int = int(progress * float(_preview_samples.size()))
			var amp_l: float = 0.0
			var amp_r: float = 0.0
			if _preview_samples.size() > 0:
				var s_val: float = absf(_preview_samples[clampi(s_idx, 0, _preview_samples.size() - 1)])
				amp_l = s_val
				amp_r = s_val
			var m_gain_db = float(active_preset_dict.get("gain_db", 0.0))
			var db_l = linear_to_db(maxf(amp_l, 0.0001)) + m_gain_db
			var db_r = linear_to_db(maxf(amp_r, 0.0001)) + m_gain_db
			vu_meter.set_level(db_l, db_r)
	else:
		if _is_auditioning:
			_is_auditioning = false
			if waveform_playhead:
				waveform_playhead.set_playhead(-1.0)
			if vu_meter:
				vu_meter.set_level(-80.0, -80.0)
