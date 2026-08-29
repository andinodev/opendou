class_name DemoDynamicOcclusion
extends Node3D

## Demo 05: Dynamic Obstacle Raycast Occlusion (Multi-Ray & Slew-Rate Filter Smoothing)

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var emitter_pos: Vector3 = Vector3(-12.0, 1.5, 0.0)
var listener_pos: Vector3 = Vector3(12.0, 1.5, 0.0)

var obstacle_pos_z: float = 0.0
var obstacle_width: float = 8.0 # Obstacle extends from Z = -4.0 to +4.0 when at Z=0

var occlusion_factor: float = 0.0
var smoothed_lpf: float = 20000.0
var target_lpf: float = 20000.0
var target_vol_atten_db: float = 0.0

var auto_oscillate: bool = false
var oscillation_time: float = 0.0

# Scene Node References
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("Environment3D/EmitterMarker/AudioStreamPlayer3D")
@onready var btn_audio_toggle: Button = get_node_or_null("UI/HeaderPanel/Margin/HBox/BtnAudioToggle")

@onready var obstacle_mesh: CSGBox3D = get_node_or_null("Environment3D/ObstacleMesh")
@onready var btn_back: Button = get_node_or_null("UI/HeaderPanel/Margin/HBox/BtnBack")

@onready var lbl_factor: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblFactor")
@onready var lbl_rays: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblRays")
@onready var lbl_lpf: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblLPF")
@onready var lbl_vol: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblVol")

@onready var wall_slider: HSlider = get_node_or_null("UI/ControlsPanel/Margin/HBox/WallSlider")
@onready var btn_block: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnBlock")
@onready var btn_clear: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnClear")
@onready var chk_oscillate: CheckBox = get_node_or_null("UI/ControlsPanel/Margin/HBox/ChkOscillate")

func _init() -> void:
	setup_occlusion_demo()

func _ready() -> void:
	_start_audio_playback()
	_connect_ui()
	_update_ui()

func setup_occlusion_demo() -> void:
	obstacle_pos_z = 0.0
	update_obstacle_step(0.016, obstacle_pos_z)

func _start_audio_playback() -> void:
	if audio_player:
		audio_player.stream = AudioSynthesizerClass.create_chord_loop(1.5)
		audio_player.unit_size = 20.0
		audio_player.max_distance = 60.0
		audio_player.play()

func _process(delta: float) -> void:
	if auto_oscillate:
		oscillation_time += delta * 1.5
		var new_z = sin(oscillation_time) * 6.0
		update_obstacle_step(delta, new_z)
	else:
		# Smooth filter slew rate towards target LPF
		smoothed_lpf = lerpf(smoothed_lpf, target_lpf, delta * 10.0)
		_update_ui()

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_audio_toggle:
		btn_audio_toggle.pressed.connect(_on_audio_toggle)
	if wall_slider:
		wall_slider.value_changed.connect(func(v): update_obstacle_step(0.016, v))
	if btn_block:
		btn_block.pressed.connect(func(): update_obstacle_step(0.016, 0.0))
	if btn_clear:
		btn_clear.pressed.connect(func(): update_obstacle_step(0.016, 6.0))
	if chk_oscillate:
		chk_oscillate.toggled.connect(func(toggled): auto_oscillate = toggled)

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

## Evaluates dynamic ray casts against the obstacle and applies filter slew-rate smoothing.
func update_obstacle_step(delta: float, new_z_pos: float) -> void:
	obstacle_pos_z = new_z_pos
	if obstacle_mesh:
		obstacle_mesh.position.z = obstacle_pos_z
	if wall_slider and not is_equal_approx(wall_slider.value, obstacle_pos_z):
		wall_slider.value = obstacle_pos_z
		
	# Ray 1: Center ray (Z = 0)
	# Ray 2: Left wing ray (Z = -1.5)
	# Ray 3: Right wing ray (Z = +1.5)
	var hits: int = 0
	var min_z = obstacle_pos_z - (obstacle_width * 0.5)
	var max_z = obstacle_pos_z + (obstacle_width * 0.5)
	
	if 0.0 >= min_z and 0.0 <= max_z:
		hits += 1
	if -1.5 >= min_z and -1.5 <= max_z:
		hits += 1
	if 1.5 >= min_z and 1.5 <= max_z:
		hits += 1
		
	occlusion_factor = float(hits) / 3.0
	target_lpf = lerpf(20000.0, 350.0, occlusion_factor)
	target_vol_atten_db = lerpf(0.0, -12.0, occlusion_factor)
	
	# Audible occlusion filtering
	if audio_player:
		audio_player.volume_db = target_vol_atten_db
		audio_player.pitch_scale = lerpf(1.0, 0.6, occlusion_factor)
		
	smoothed_lpf = lerpf(smoothed_lpf, target_lpf, delta * 10.0)
	_update_ui()

func get_current_lpf() -> float:
	return target_lpf

func _update_ui() -> void:
	if lbl_factor:
		lbl_factor.text = "Occlusion Factor: %d%% (%s)" % [int(occlusion_factor * 100), "Fully Blocked" if occlusion_factor >= 1.0 else ("Partially Blocked" if occlusion_factor > 0.0 else "Clear Path")]
	if lbl_rays:
		lbl_rays.text = "Multi-Ray: %d / 3 Rays Intersecting Obstacle" % int(occlusion_factor * 3.0)
	if lbl_lpf:
		lbl_lpf.text = "Smoothed LPF: %d Hz (Target: %d Hz)" % [int(smoothed_lpf), int(target_lpf)]
	if lbl_vol:
		lbl_vol.text = "Volume Attenuation: %.1f dB" % target_vol_atten_db
