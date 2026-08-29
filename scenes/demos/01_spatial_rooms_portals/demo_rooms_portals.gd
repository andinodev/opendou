class_name DemoRoomsPortals
extends Node3D

## Demo 01: Macro-Acoustics & Acoustic Pathfinding (Rooms, Portals & Diffraction)

const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var acoustics: SpatialAcousticsManager
var room_a: AudioRoom
var room_b: AudioRoom
var portal: AudioPortal

var emitter_pos: Vector3 = Vector3(0.0, 0.0, 0.0)
var listener_pos: Vector3 = Vector3(20.0, 0.0, 0.0)
var door_open_factor: float = 1.0
var calculated_path = null

# Scene Node References
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("Environment3D/EmitterMarker/AudioStreamPlayer3D")
@onready var btn_audio_toggle: Button = get_node_or_null("UI/HeaderPanel/Margin/HBox/BtnAudioToggle")

@onready var door_slider: HSlider = get_node_or_null("UI/ControlsPanel/Margin/HBox/DoorSlider")
@onready var door_val_lbl: Label = get_node_or_null("UI/ControlsPanel/Margin/HBox/DoorValueLabel")
@onready var btn_close: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnCloseDoor")
@onready var btn_open: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnOpenDoor")
@onready var btn_back: Button = get_node_or_null("UI/HeaderPanel/Margin/HBox/BtnBack")

@onready var lbl_dist: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblDistance")
@onready var lbl_origin: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblOrigin")
@onready var lbl_lpf: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblLPF")
@onready var door_mesh: CSGBox3D = get_node_or_null("Environment3D/DoorMesh")

func _init() -> void:
	setup_acoustics()

func _ready() -> void:
	if not acoustics:
		setup_acoustics()
	_start_audio_playback()
	_connect_ui()
	_update_ui()

func setup_acoustics() -> void:
	acoustics = SpatialAcousticsManagerClass.new()
	room_a = AudioRoomClass.new(&"Machine_Room", 0.8, 0.3)
	room_b = AudioRoomClass.new(&"Echo_Hall", 3.2, 0.7)
	portal = AudioPortalClass.new(&"Heavy_Door", &"Machine_Room", &"Echo_Hall", Vector3(10.0, 0.0, 0.0), door_open_factor)
	
	acoustics.register_room(room_a)
	acoustics.register_room(room_b)
	acoustics.register_portal(portal)
	update_path()

func _start_audio_playback() -> void:
	if audio_player:
		audio_player.stream = AudioSynthesizerClass.create_chord_loop(2.0)
		audio_player.unit_size = 20.0
		audio_player.max_distance = 60.0
		audio_player.play()

func _connect_ui() -> void:
	if door_slider:
		door_slider.value_changed.connect(_on_slider_changed)
	if btn_close:
		btn_close.pressed.connect(func(): set_door_open_factor(0.0))
	if btn_open:
		btn_open.pressed.connect(func(): set_door_open_factor(1.0))
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_audio_toggle:
		btn_audio_toggle.pressed.connect(_on_audio_toggle)

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

func _on_slider_changed(val: float) -> void:
	set_door_open_factor(val)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

func set_door_open_factor(factor: float) -> void:
	door_open_factor = clampf(factor, 0.0, 1.0)
	if portal:
		portal.open_factor = door_open_factor
	if door_slider and not is_equal_approx(door_slider.value, door_open_factor):
		door_slider.value = door_open_factor
	if door_mesh:
		door_mesh.scale.y = max(0.05, 1.0 - door_open_factor)
		
	# Audible acoustic modulation
	if audio_player:
		audio_player.volume_db = lerpf(-15.0, 0.0, door_open_factor)
		audio_player.pitch_scale = lerpf(0.65, 1.0, door_open_factor)
		
	update_path()
	_update_ui()

func set_listener_pos(pos: Vector3) -> void:
	listener_pos = pos
	update_path()
	_update_ui()

func update_path() -> void:
	if acoustics:
		calculated_path = acoustics.calculate_acoustic_path(emitter_pos, listener_pos, &"Machine_Room", &"Echo_Hall")

func _update_ui() -> void:
	if door_val_lbl:
		door_val_lbl.text = "%d%%" % int(door_open_factor * 100)
	if calculated_path:
		if lbl_dist:
			lbl_dist.text = "Diffraction Distance: %.1f m" % calculated_path.virtual_distance
		if lbl_origin:
			lbl_origin.text = "Apparent Origin: (%.1f, %.1f, %.1f)" % [calculated_path.apparent_origin.x, calculated_path.apparent_origin.y, calculated_path.apparent_origin.z]
		if lbl_lpf:
			lbl_lpf.text = "Accumulated LPF: %s Hz" % str(int(calculated_path.accumulated_lpf))
