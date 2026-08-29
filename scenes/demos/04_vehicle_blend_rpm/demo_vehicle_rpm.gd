class_name DemoVehicleRPM
extends Control

## Demo 04: Vehicle Engine RPM Multilayer Crossfading (AudioBlendContainer & O(1) LUT)

const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const BlendLayerClass = preload("res://addons/opendou/resources/containers/blend_layer.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var blend_container: AudioBlendContainer
var current_rpm: float = 1000.0

# Scene UI Node References
@onready var audio_player: AudioStreamPlayer = get_node_or_null("AudioPlayer")
@onready var btn_audio_toggle: Button = get_node_or_null("HeaderPanel/Margin/HBox/BtnAudioToggle")
@onready var btn_back: Button = get_node_or_null("HeaderPanel/Margin/HBox/BtnBack")

@onready var rpm_display: Label = get_node_or_null("MainLayout/DashboardCard/Margin/VBox/RPMDisplay")
@onready var rpm_slider: HSlider = get_node_or_null("MainLayout/DashboardCard/Margin/VBox/RPMSlider")

@onready var btn_idle: Button = get_node_or_null("MainLayout/DashboardCard/Margin/VBox/PresetsHBox/BtnIdle")
@onready var btn_mid: Button = get_node_or_null("MainLayout/DashboardCard/Margin/VBox/PresetsHBox/BtnMid")
@onready var btn_high: Button = get_node_or_null("MainLayout/DashboardCard/Margin/VBox/PresetsHBox/BtnHigh")

@onready var lbl_idle: Label = get_node_or_null("MainLayout/LayersCard/Margin/VBox/IdleLayerBox/LblIdle")
@onready var bar_idle: ProgressBar = get_node_or_null("MainLayout/LayersCard/Margin/VBox/IdleLayerBox/BarIdle")

@onready var lbl_mid: Label = get_node_or_null("MainLayout/LayersCard/Margin/VBox/MidLayerBox/LblMid")
@onready var bar_mid: ProgressBar = get_node_or_null("MainLayout/LayersCard/Margin/VBox/MidLayerBox/BarMid")

@onready var lbl_high: Label = get_node_or_null("MainLayout/LayersCard/Margin/VBox/HighLayerBox/LblHigh")
@onready var bar_high: ProgressBar = get_node_or_null("MainLayout/LayersCard/Margin/VBox/HighLayerBox/BarHigh")

func _init() -> void:
	setup_engine_blend()

func _ready() -> void:
	if not blend_container:
		setup_engine_blend()
	_start_audio_playback()
	_connect_ui()
	set_rpm(current_rpm)

func setup_engine_blend() -> void:
	blend_container = AudioBlendContainerClass.new(&"RPM", 0.0, 8000.0)
	blend_container.silence_threshold_db = -80.0
	
	# Layer 1: Idle (0 - 2000 RPM)
	var curve_idle = Curve.new()
	curve_idle.min_value = -80.0
	curve_idle.max_value = 0.0
	curve_idle.add_point(Vector2(0.0, 0.0))
	curve_idle.add_point(Vector2(0.25, -80.0))
	curve_idle.bake()
	var wav_idle = AudioSynthesizerClass.create_engine_loop(45.0)
	wav_idle.resource_name = "idle.wav"
	blend_container.add_layer(AudioPhysicalNodeClass.new(wav_idle), curve_idle)
	
	# Layer 2: Low-Mid (1500 - 5000 RPM)
	var curve_mid = Curve.new()
	curve_mid.min_value = -80.0
	curve_mid.max_value = 0.0
	curve_mid.add_point(Vector2(0.1875, -80.0))
	curve_mid.add_point(Vector2(0.4, 0.0))
	curve_mid.add_point(Vector2(0.625, -80.0))
	curve_mid.bake()
	var wav_mid = AudioSynthesizerClass.create_engine_loop(70.0)
	wav_mid.resource_name = "mid.wav"
	blend_container.add_layer(AudioPhysicalNodeClass.new(wav_mid), curve_mid)
	
	# Layer 3: High-Redline (4500 - 8000 RPM)
	var curve_high = Curve.new()
	curve_high.min_value = -80.0
	curve_high.max_value = 0.0
	curve_high.add_point(Vector2(0.5625, -80.0))
	curve_high.add_point(Vector2(1.0, 0.0))
	curve_high.bake()
	var wav_high = AudioSynthesizerClass.create_engine_loop(110.0)
	wav_high.resource_name = "high.wav"
	blend_container.add_layer(AudioPhysicalNodeClass.new(wav_high), curve_high)

func _start_audio_playback() -> void:
	if audio_player:
		audio_player.stream = AudioSynthesizerClass.create_engine_loop(55.0)
		audio_player.volume_db = -6.0
		audio_player.play()

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_audio_toggle:
		btn_audio_toggle.pressed.connect(_on_audio_toggle)
	if rpm_slider:
		rpm_slider.value_changed.connect(func(v): set_rpm(v))
	if btn_idle:
		btn_idle.pressed.connect(func(): set_rpm(800.0))
	if btn_mid:
		btn_mid.pressed.connect(func(): set_rpm(3200.0))
	if btn_high:
		btn_high.pressed.connect(func(): set_rpm(7500.0))

func _on_audio_toggle() -> void:
	if audio_player:
		if audio_player.playing:
			audio_player.stop()
			if btn_audio_toggle:
				btn_audio_toggle.text = "🔇 Sound: Muted"
		else:
			audio_player.play()
			if btn_audio_toggle:
				btn_audio_toggle.text = "🔊 Sound: Playing"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

## Sets the simulated vehicle engine RPM and returns the active resolved layers with volumes.
func set_rpm(rpm: float) -> Array:
	if not blend_container:
		setup_engine_blend()
	current_rpm = clampf(rpm, 0.0, 8000.0)
	if rpm_slider and not is_equal_approx(rpm_slider.value, current_rpm):
		rpm_slider.value = current_rpm
	if rpm_display:
		rpm_display.text = "%s RPM" % str(int(current_rpm))
		
	# Audible engine revving pitch scaling
	if audio_player:
		var norm_rpm = current_rpm / 8000.0
		audio_player.pitch_scale = lerpf(0.6, 2.8, norm_rpm)
		
	var ctx = AudioPlaybackContextClass.new()
	ctx.set_rtpc(&"RPM", current_rpm)
	
	var resolved = blend_container.resolve_voices(ctx)
	_update_layer_meters()
	return resolved

func _update_layer_meters() -> void:
	if not blend_container or blend_container.layers.size() < 3:
		return
		
	var norm_x: float = current_rpm / 8000.0
	
	var vol_idle = blend_container.layers[0].volume_curve.sample(norm_x)
	var vol_mid = blend_container.layers[1].volume_curve.sample(norm_x)
	var vol_high = blend_container.layers[2].volume_curve.sample(norm_x)
	
	if bar_idle:
		bar_idle.value = vol_idle
	if lbl_idle:
		lbl_idle.text = "Layer 1: Idle (0-2000 RPM) -> %s" % ("Culled (Silent)" if vol_idle <= -80.0 else "%.1f dB" % vol_idle)
		
	if bar_mid:
		bar_mid.value = vol_mid
	if lbl_mid:
		lbl_mid.text = "Layer 2: Low-Mid (1500-5000 RPM) -> %s" % ("Culled (Silent)" if vol_mid <= -80.0 else "%.1f dB" % vol_mid)
		
	if bar_high:
		bar_high.value = vol_high
	if lbl_high:
		lbl_high.text = "Layer 3: High (4500-8000 RPM) -> %s" % ("Culled (Silent)" if vol_high <= -80.0 else "%.1f dB" % vol_high)
