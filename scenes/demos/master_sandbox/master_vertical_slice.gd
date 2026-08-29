class_name OpenDouMasterVerticalSlice
extends Node3D

## Master Vertical Slice Coordinator (Tactical Siege • Dark Crypt • Calibration Lab)

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const LiveUpdateServerClass = preload("res://addons/opendou/runtime/network/live_update_server.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

var voice_pool: VoicePoolManager
var spatial_acoustics: SpatialAcousticsManager
var live_update_server: LiveUpdateServer

var chaos_instances: Array[EventInstance] = []
var gunshot_sample: AudioStreamWAV

# Sector 2 Acoustics & Occlusion
var room_outdoor: AudioRoom
var room_crypt: AudioRoom
var room_lab: AudioRoom
var crypt_portal: AudioPortal
var is_crypt_gate_open: bool = true

var monster_pos: Vector3 = Vector3(54, 2, 0)
var monster_occlusion: float = 0.0

# Scene References
@onready var player: OpenDouPlayerController = get_node_or_null("Player")
@onready var chaos_emitters_parent: Node3D = get_node_or_null("LevelGeometry/Sector1_TacticalSiege/ChaosEmittersParent")
@onready var crypt_gate_mesh: CSGBox3D = get_node_or_null("LevelGeometry/Sector2_DarkCrypt/CryptGate")

# Emitter Players
@onready var monster_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector2_DarkCrypt/MonsterEmitter/MonsterAudio")
@onready var torch_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector2_DarkCrypt/TorchEmitter/TorchAudio")
@onready var generator_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector3_CalibrationRoom/GeneratorEmitter/GeneratorAudio")
@onready var alarm_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector3_CalibrationRoom/AlarmEmitter/AlarmAudio")

# UI References
@onready var btn_teleport1: Button = get_node_or_null("UI/TopBar/Margin/HBox/BtnTeleport1")
@onready var btn_teleport2: Button = get_node_or_null("UI/TopBar/Margin/HBox/BtnTeleport2")
@onready var btn_teleport3: Button = get_node_or_null("UI/TopBar/Margin/HBox/BtnTeleport3")
@onready var btn_back: Button = get_node_or_null("UI/TopBar/Margin/HBox/BtnBack")

@onready var lbl_voices: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblVoices")
@onready var lbl_surface: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblSurface")
@onready var lbl_acoustics: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblAcoustics")
@onready var lbl_occlusion: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblOcclusion")
@onready var lbl_tcp: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblTCP")

@onready var btn_bombardment: Button = get_node_or_null("UI/BottomBar/Margin/HBox/BtnChaosBombardment")
@onready var btn_toggle_gate: Button = get_node_or_null("UI/BottomBar/Margin/HBox/BtnToggleGate")

func _init() -> void:
	_init_systems()

func _ready() -> void:
	if not voice_pool:
		_init_systems()
	_start_ambient_audio()
	_connect_ui()
	_update_hud()

func _init_systems() -> void:
	voice_pool = VoicePoolManagerClass.new(16)
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	live_update_server = LiveUpdateServerClass.new()
	live_update_server.start_server(3016)
	
	gunshot_sample = AudioSynthesizerClass.create_gunshot()
	
	# Acoustics Setup
	room_outdoor = AudioRoomClass.new(&"Outpost_Exterior", 0.3, 0.1)
	room_crypt = AudioRoomClass.new(&"Dark_Crypt", 3.8, 0.8)
	room_lab = AudioRoomClass.new(&"Glass_Lab", 1.2, 0.2)
	
	crypt_portal = AudioPortalClass.new(&"Crypt_Gate", &"Outpost_Exterior", &"Dark_Crypt", Vector3(21.0, 2.0, 0.0), 1.0)
	
	spatial_acoustics.register_room(room_outdoor)
	spatial_acoustics.register_room(room_crypt)
	spatial_acoustics.register_room(room_lab)
	spatial_acoustics.register_portal(crypt_portal)

func _start_ambient_audio() -> void:
	# Sector 2: Monster growl (55Hz drone with rumble)
	if monster_audio:
		monster_audio.stream = AudioSynthesizerClass.create_engine_loop(40.0)
		monster_audio.unit_size = 25.0
		monster_audio.max_distance = 60.0
		monster_audio.play()
		
	# Sector 2: Torch hum
	if torch_audio:
		torch_audio.stream = AudioSynthesizerClass.create_tone(180.0, 2.0, 0.2, false)
		torch_audio.unit_size = 8.0
		torch_audio.play()
		
	# Sector 3: Generator and Alarm
	if generator_audio:
		generator_audio.stream = AudioSynthesizerClass.create_engine_loop(60.0)
		generator_audio.unit_size = 15.0
		generator_audio.play()
		
	if alarm_audio:
		alarm_audio.stream = AudioSynthesizerClass.create_tone(880.0, 1.0, 0.3, false)
		alarm_audio.unit_size = 15.0
		alarm_audio.play()

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_teleport1:
		btn_teleport1.pressed.connect(func(): teleport_player(Vector3(-15, 1, 0)))
	if btn_teleport2:
		btn_teleport2.pressed.connect(func(): teleport_player(Vector3(35, 1, 0)))
	if btn_teleport3:
		btn_teleport3.pressed.connect(func(): teleport_player(Vector3(0, 1, 35)))
	if btn_bombardment:
		btn_bombardment.pressed.connect(trigger_chaos_bombardment)
	if btn_toggle_gate:
		btn_toggle_gate.pressed.connect(toggle_crypt_gate)
		
	if player:
		player.surface_changed.connect(func(surf): if lbl_surface: lbl_surface.text = "Active Surface: %s" % str(surf))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_back_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if live_update_server:
		live_update_server.stop_server()
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

func _physics_process(delta: float) -> void:
	# 1. Update Live Update TCP
	if live_update_server and live_update_server.is_server_running:
		live_update_server.poll()
		
	# 2. Update player position & voice pool voice stealing
	var listener_p = player.global_position if player else Vector3.ZERO
	for inst in chaos_instances:
		inst.update_parameters(delta)
	if voice_pool:
		voice_pool.resolve_voice_stealing(chaos_instances, listener_p, delta)
		
	# 3. Dynamic Pillar Raycast Occlusion in Crypt
	_update_pillar_occlusion(listener_p)
	_update_hud()

func _update_pillar_occlusion(listener_p: Vector3) -> void:
	if not player or player.position.x <= 20.0:
		monster_occlusion = 0.0
	else:
		# Check occlusion between player and monster_pos
		var p_pos = player.global_position
		# Pillar 1 (5, 3.5, -6), Pillar 2 (5, 3.5, 6), Pillar 3 (18, 3.5, 0) relative to Sector 2 at (30,0,0) -> global (48, 3.5, 0)
		var p3_global = Vector3(48, 1.5, 0)
		var dist_to_line = _point_to_segment_distance(p3_global, p_pos, monster_pos)
		monster_occlusion = clampf(1.0 - (dist_to_line / 3.0), 0.0, 1.0)
		
	if monster_audio:
		monster_audio.volume_db = lerpf(0.0, -14.0, monster_occlusion)
		monster_audio.pitch_scale = lerpf(1.0, 0.6, monster_occlusion)

func _point_to_segment_distance(pt: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	var ap = pt - a
	var t = clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	var proj = a + ab * t
	return pt.distance_to(proj)

func teleport_player(target_pos: Vector3) -> void:
	if player:
		player.global_position = target_pos

func toggle_crypt_gate() -> void:
	is_crypt_gate_open = not is_crypt_gate_open
	if crypt_portal:
		crypt_portal.open_factor = 1.0 if is_crypt_gate_open else 0.05
	if crypt_gate_mesh:
		crypt_gate_mesh.scale.y = 0.1 if is_crypt_gate_open else 1.0

## Spawns 250 physical/virtual bullet impact emitters across Sector 1 to stress VoicePoolManager.
func trigger_chaos_bombardment() -> void:
	chaos_instances.clear()
	if chaos_emitters_parent:
		for c in chaos_emitters_parent.get_children():
			c.queue_free()
			
	var def = AudioEventDefClass.new(&"Siege_Explosion")
	def.base_priority = 50.0
	def.stream_length = 3.0
	def.is_looping = true
	def.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
	def.base_stream = gunshot_sample
	
	for i in range(250):
		var pos = Vector3(randf_range(-38, 8), 0.5, randf_range(-22, 22))
		var inst = EventInstanceClass.new(def)
		inst.set_position(pos)
		inst.play()
		chaos_instances.append(inst)
		
		if chaos_emitters_parent:
			var dot = CSGSphere3D.new()
			dot.radius = 0.25
			dot.position = pos
			chaos_emitters_parent.add_child(dot)

func _update_hud() -> void:
	var phys = voice_pool.get_active_physical_count() if voice_pool else 0
	var virt = voice_pool.get_active_virtual_count(chaos_instances) if voice_pool else 0
	
	if lbl_voices:
		lbl_voices.text = "Voices: %d Physical / %d Virtual" % [phys, virt]
		
	if lbl_acoustics and player:
		var cur_room = "Outpost (Exterior)" if player.position.x < 20.0 else ("Dark Crypt" if player.position.z < 25.0 else "Calibration Lab")
		var lpf_val = 20000 if is_crypt_gate_open else 350
		lbl_acoustics.text = "Acoustics: %s (%s Hz)" % [cur_room, str(lpf_val)]
		
	if lbl_occlusion:
		lbl_occlusion.text = "Pillar Occlusion: %d%% (%s)" % [int(monster_occlusion * 100), "Blocked" if monster_occlusion > 0.5 else "Direct LOS"]
