class_name OpenDouCyberpunkInfiltrationDemo
extends Node3D

## Master Coordinator & Logic Controller for Cyberpunk Infiltration AAA Showcase Demo (Sector 7)

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")
const AudioDialogueTableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const AudioDialogueManagerClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_manager.gd")
const MusicPlaylistManagerClass = preload("res://addons/opendou/core/music/music_playlist_manager.gd")
const LiveUpdateServerClass = preload("res://addons/opendou/runtime/network/live_update_server.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

# Core Audio Managers
var voice_pool: VoicePoolManager
var spatial_acoustics: SpatialAcousticsManager
var ducking_matrix: AudioDuckingMatrix
var dialogue_table: AudioDialogueTable
var dialogue_manager: AudioDialogueManager
var music_director: MusicPlaylistManager
var live_update_server: LiveUpdateServer

# Acoustic Rooms & Portals
var room_rooftop: AudioRoom
var room_server: AudioRoom
var room_drainage: AudioRoom
var room_extraction: AudioRoom
var server_portal: AudioPortal

# Runtime State
var is_airlock_open: bool = true
var combat_intensity: float = 0.0
var turret_occlusion: float = 0.0
var active_sector_idx: int = 1
var active_room_name: StringName = &"Rooftop_Exterior"
var bombardment_instances: Array[EventInstance] = []

# Teleportation Sector Positions
const SECTOR_POSITIONS: Dictionary = {
	1: Vector3(-25.0, 1.0, 0.0), # Sector 1: Rooftop
	2: Vector3(0.0, 1.0, 0.0),    # Sector 2: Server Room
	3: Vector3(25.0, 1.0, 0.0),   # Sector 3: Flooded Drainage
	4: Vector3(50.0, 1.0, 0.0)    # Sector 4: Extraction Arena
}

# Scene Node References
@onready var player: Node = get_node_or_null("Player")
@onready var server_airlock_mesh: CSGBox3D = get_node_or_null("LevelGeometry/Sector2_ServerRoom/ServerAirlockGate")

# Emitter Players
@onready var rain_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector1_Rooftop/RainEmitter")
@onready var server_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector2_ServerRoom/ServerEmitter")
@onready var water_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector3_FloodedDrainage/WaterEmitter")
@onready var turret_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector4_ExtractionArena/TurretEmitter")
@onready var radio_beacon_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector4_ExtractionArena/RadioBeaconEmitter")

# Player Audio
@onready var footstep_audio: AudioStreamPlayer = get_node_or_null("Player/FootstepAudio")
@onready var weapon_audio: AudioStreamPlayer = get_node_or_null("Player/WeaponAudio")
@onready var radio_audio: AudioStreamPlayer = get_node_or_null("Player/RadioAudio")

# UI References
@onready var btn_sector1: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
@onready var btn_sector2: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
@onready var btn_sector3: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
@onready var btn_sector4: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
@onready var btn_back: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")

@onready var btn_toggle_airlock: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAirlock")
@onready var btn_bombardment: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnBombardment")
@onready var btn_lang_en: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangEN")
@onready var btn_lang_es: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangES")
@onready var btn_lang_ja: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangJA")
@onready var btn_lang_zh: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangZH")

@onready var lbl_sector: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSector")
@onready var lbl_surface: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSurface")
@onready var lbl_acoustics: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblAcoustics")
@onready var lbl_airlock: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblAirlock")
@onready var lbl_voices: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblVoices")
@onready var lbl_ducking: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblDucking")
@onready var lbl_music: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblMusic")
@onready var lbl_dsp: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblDSP")

func _init() -> void:
	_setup_runtime_systems()

func _ready() -> void:
	if not voice_pool:
		_setup_runtime_systems()
	_start_ambient_audio()
	_connect_ui()
	_update_hud()

func _setup_runtime_systems() -> void:
	# 1. Voice Pool Manager (16 physical voice cap)
	voice_pool = VoicePoolManagerClass.new(16)
	
	# 2. Spatial Acoustics Manager & Enclosures
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	
	room_rooftop = AudioRoomClass.new(&"Rooftop_Exterior", 0.2, 0.1)
	room_rooftop.set_bounds(AABB(Vector3(-40.0, -2.0, -16.0), Vector3(30.0, 12.0, 32.0)))
	
	room_server = AudioRoomClass.new(&"Server_Room", 0.7, 0.3)
	room_server.set_bounds(AABB(Vector3(-12.0, -2.0, -10.0), Vector3(24.0, 10.0, 20.0)))
	
	room_drainage = AudioRoomClass.new(&"Flooded_Drainage", 3.5, 0.05)
	room_drainage.set_bounds(AABB(Vector3(13.0, -2.0, -8.0), Vector3(24.0, 10.0, 16.0)))
	
	room_extraction = AudioRoomClass.new(&"Extraction_Arena", 0.4, 0.2)
	room_extraction.set_bounds(AABB(Vector3(35.0, -2.0, -16.0), Vector3(30.0, 12.0, 32.0)))
	
	spatial_acoustics.register_room(room_rooftop)
	spatial_acoustics.register_room(room_server)
	spatial_acoustics.register_room(room_drainage)
	spatial_acoustics.register_room(room_extraction)
	
	# 3. Spatial Acoustic Portals
	server_portal = AudioPortalClass.new(&"Server_Airlock", &"Rooftop_Exterior", &"Server_Room", Vector3(-10.0, 2.0, 0.0), 1.0)
	spatial_acoustics.register_portal(server_portal)
	
	# 4. Sidechain Priority Ducking Matrix
	ducking_matrix = AudioDuckingMatrixClass.new()
	ducking_matrix.add_ducking_rule(&"Voice", &"Music", -16.0, 0.1, 0.4)
	ducking_matrix.add_ducking_rule(&"SFX", &"Music", -6.0, 0.05, 0.2)
	
	# 5. Localized Dialogue Manager & Table
	dialogue_table = AudioDialogueTableClass.new()
	_populate_dialogue_table()
	dialogue_manager = AudioDialogueManagerClass.new("en", dialogue_table)
	
	# 6. Interactive Music Playlist Manager
	music_director = MusicPlaylistManagerClass.new()
	music_director.add_item(&"Infiltration_Intro", 1, 1)
	music_director.add_item(&"Stealth_Loop", 2, 4)
	music_director.add_item(&"Combat_Alert", 2, 4)
	music_director.add_item(&"Extraction_Outro", 1, 1)
	music_director.start_playlist()
	
	# 7. Live Update TCP Server
	live_update_server = LiveUpdateServerClass.new()
	var ok = live_update_server.start_server(3019)
	if not ok:
		live_update_server.start_server(3020)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if live_update_server:
			live_update_server.stop_server()
		for inst in bombardment_instances:
			if inst:
				inst.stop()
		bombardment_instances.clear()

func _populate_dialogue_table() -> void:
	# Tactical radio sample voice lines across 4 languages
	var stream_clear_en = AudioSynthesizerClass.create_tone(440.0, 1.2, 0.4, false)
	var stream_clear_es = AudioSynthesizerClass.create_tone(480.0, 1.2, 0.4, false)
	var stream_clear_ja = AudioSynthesizerClass.create_tone(520.0, 1.2, 0.4, false)
	var stream_clear_zh = AudioSynthesizerClass.create_tone(560.0, 1.2, 0.4, false)
	
	dialogue_table.add_entry(&"sec_clear_01", "en", stream_clear_en)
	dialogue_table.add_entry(&"sec_clear_01", "es", stream_clear_es)
	dialogue_table.add_entry(&"sec_clear_01", "ja", stream_clear_ja)
	dialogue_table.add_entry(&"sec_clear_01", "zh", stream_clear_zh)
	
	var stream_alert_en = AudioSynthesizerClass.create_tone(880.0, 1.5, 0.5, false)
	var stream_alert_es = AudioSynthesizerClass.create_tone(920.0, 1.5, 0.5, false)
	var stream_alert_ja = AudioSynthesizerClass.create_tone(960.0, 1.5, 0.5, false)
	var stream_alert_zh = AudioSynthesizerClass.create_tone(1000.0, 1.5, 0.5, false)
	
	dialogue_table.add_entry(&"tactical_alert", "en", stream_alert_en)
	dialogue_table.add_entry(&"tactical_alert", "es", stream_alert_es)
	dialogue_table.add_entry(&"tactical_alert", "ja", stream_alert_ja)
	dialogue_table.add_entry(&"tactical_alert", "zh", stream_alert_zh)

func _start_ambient_audio() -> void:
	if rain_audio:
		rain_audio.stream = AudioSynthesizerClass.create_tone(220.0, 3.0, 0.25, true)
		rain_audio.unit_size = 30.0
		rain_audio.max_distance = 60.0
		rain_audio.play()
		
	if server_audio:
		server_audio.stream = AudioSynthesizerClass.create_engine_loop(120.0)
		server_audio.unit_size = 18.0
		server_audio.max_distance = 45.0
		server_audio.play()
		
	if water_audio:
		water_audio.stream = AudioSynthesizerClass.create_tone(330.0, 2.5, 0.3, true)
		water_audio.unit_size = 20.0
		water_audio.max_distance = 50.0
		water_audio.play()
		
	if turret_audio:
		turret_audio.stream = AudioSynthesizerClass.create_tone(660.0, 1.0, 0.35, false)
		turret_audio.unit_size = 25.0
		turret_audio.max_distance = 60.0
		turret_audio.play()
		
	if radio_beacon_audio:
		radio_beacon_audio.stream = AudioSynthesizerClass.create_chord_loop(1.8)
		radio_beacon_audio.unit_size = 15.0
		radio_beacon_audio.max_distance = 50.0
		radio_beacon_audio.play()

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_sector1:
		btn_sector1.pressed.connect(func(): teleport_to_sector(1))
	if btn_sector2:
		btn_sector2.pressed.connect(func(): teleport_to_sector(2))
	if btn_sector3:
		btn_sector3.pressed.connect(func(): teleport_to_sector(3))
	if btn_sector4:
		btn_sector4.pressed.connect(func(): teleport_to_sector(4))
	if btn_toggle_airlock:
		btn_toggle_airlock.pressed.connect(toggle_server_airlock)
	if btn_bombardment:
		btn_bombardment.pressed.connect(trigger_siege_bombardment)
		
	if btn_lang_en:
		btn_lang_en.pressed.connect(func(): set_voice_locale("en"))
	if btn_lang_es:
		btn_lang_es.pressed.connect(func(): set_voice_locale("es"))
	if btn_lang_ja:
		btn_lang_ja.pressed.connect(func(): set_voice_locale("ja"))
	if btn_lang_zh:
		btn_lang_zh.pressed.connect(func(): set_voice_locale("zh"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.keycode == KEY_TAB:
			toggle_server_airlock()
		elif event.keycode == KEY_B:
			trigger_siege_bombardment()

func _on_back_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if live_update_server:
		live_update_server.stop_server()
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

func _physics_process(delta: float) -> void:
	# 1. Update Live Update TCP Server
	if live_update_server and live_update_server.is_server_running:
		live_update_server.poll()
		
	# 2. Update Ducking Matrix & Dialogue
	if ducking_matrix:
		ducking_matrix.update(delta)
	if dialogue_manager:
		dialogue_manager.update(delta, ducking_matrix)
		
	var listener_pos = (player.global_position if player.is_inside_tree() else player.position) if player else Vector3.ZERO
	
	# 3. Update Bombardment Event Instances & Voice Pool Stealing Resolution
	if not bombardment_instances.is_empty():
		for inst in bombardment_instances:
			if inst:
				inst.update_parameters(delta)
		if voice_pool:
			voice_pool.resolve_voice_stealing(bombardment_instances, listener_pos, delta)
		
	# 4. Dynamic Pillar Raycast Occlusion in Sector 4
	_update_pillar_occlusion(listener_pos)
	
	# 5. Update room acoustics based on player position
	_update_room_acoustics(listener_pos)
	
	# 6. Refresh HUD telemetry
	_update_hud()

func _update_pillar_occlusion(listener_pos: Vector3) -> void:
	if not player or listener_pos.x < 35.0:
		turret_occlusion = 0.0
	else:
		# Turret position in Sector 4: (60, 2.5, 0)
		var t_pos = Vector3(60.0, 2.5, 0.0)
		# Extraction Arena Pillars at (44, 3, -6), (56, 3, -6), (44, 3, 6), (56, 3, 6)
		var p_center = Vector3(50.0, 1.5, 0.0)
		var dist_to_los = _point_to_segment_distance(p_center, listener_pos, t_pos)
		turret_occlusion = clampf(1.0 - (dist_to_los / 3.5), 0.0, 1.0)
		
	if turret_audio:
		turret_audio.volume_db = lerpf(0.0, -18.0, turret_occlusion)
		turret_audio.pitch_scale = lerpf(1.0, 0.55, turret_occlusion)

func _point_to_segment_distance(pt: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	var ap = pt - a
	var denom = ab.length_squared()
	if denom <= 0.0001:
		return pt.distance_to(a)
	var t = clampf(ap.dot(ab) / denom, 0.0, 1.0)
	var proj = a + ab * t
	return pt.distance_to(proj)

func _update_room_acoustics(pos: Vector3) -> void:
	if spatial_acoustics:
		var current_room = spatial_acoustics.get_room_at_position(pos)
		if current_room:
			active_room_name = current_room.room_name
		else:
			if pos.x < -12.0:
				active_room_name = &"Rooftop_Exterior"
			elif pos.x < 12.0:
				active_room_name = &"Server_Room"
			elif pos.x < 37.0:
				active_room_name = &"Flooded_Drainage"
			else:
				active_room_name = &"Extraction_Arena"

## Detects the physical ground surface material type for dynamic footstep audio synthesis.
func detect_footstep_surface(pos: Vector3) -> StringName:
	if pos.x < -12.0:
		return &"Metal"
	elif pos.x < 12.0:
		return &"Tile"
	elif pos.x < 37.0:
		return &"Water"
	else:
		return &"Concrete"

## Triggers the 250-voice siege bombardment in Sector 4 Extraction Arena, stressing voice pooling and virtualization.
func trigger_siege_bombardment() -> void:
	# Stop and clear any previous bombardment instances
	for inst in bombardment_instances:
		if inst:
			inst.stop()
	bombardment_instances.clear()
	
	# Clear previous chaos emitter markers if present
	var chaos_parent = get_node_or_null("LevelGeometry/ChaosEmittersParent")
	if chaos_parent:
		for child in chaos_parent.get_children():
			child.queue_free()
			
	var explosion_stream = AudioSynthesizerClass.create_gunshot()
	
	for i in range(250):
		var event_def = AudioEventDefClass.new(&"Cyber_Artillery_Explosion", explosion_stream)
		event_def.is_looping = true
		event_def.stream_length = 0.35
		event_def.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
		event_def.base_volume_db = randf_range(-4.0, 2.0)
		event_def.base_priority = randf_range(30.0, 70.0)
		event_def.target_bus = &"SFX"
		
		var inst = EventInstanceClass.new(event_def)
		var spawn_pos = Vector3(
			randf_range(35.0, 65.0),
			randf_range(0.2, 2.5),
			randf_range(-20.0, 20.0)
		)
		inst.set_position(spawn_pos)
		inst.play()
		bombardment_instances.append(inst)
		
		if chaos_parent:
			var marker = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = 0.25
			sphere.height = 0.5
			marker.mesh = sphere
			marker.position = spawn_pos
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.2, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.4, 0.1)
			mat.emission_energy_multiplier = 2.0
			marker.material_override = mat
			chaos_parent.add_child(marker)

## Teleports player to the specified sector index (1 to 4).
func teleport_to_sector(idx: int) -> void:
	if not SECTOR_POSITIONS.has(idx):
		return
	active_sector_idx = idx
	var target_pos: Vector3 = SECTOR_POSITIONS[idx]
	if not player:
		player = get_node_or_null("Player")
	if player:
		if player.is_inside_tree():
			player.global_position = target_pos
		else:
			player.position = target_pos
	_update_hud()

## Toggles the server airlock door open / closed with acoustic portal diffraction.
func toggle_server_airlock() -> void:
	is_airlock_open = not is_airlock_open
	if server_portal:
		server_portal.open_factor = 1.0 if is_airlock_open else 0.05
	if server_airlock_mesh:
		server_airlock_mesh.scale.y = 0.1 if is_airlock_open else 1.0
		server_airlock_mesh.position.y = 3.6 if is_airlock_open else 1.8
	_update_hud()

## Modifies combat intensity RTPC for dynamic music layering.
func set_combat_intensity(val: float) -> void:
	combat_intensity = clampf(val, 0.0, 1.0)
	_update_hud()

## Changes active voice localization locale.
func set_voice_locale(loc: String) -> void:
	if dialogue_manager:
		dialogue_manager.set_language(loc)
	_update_hud()

## Plays a localized radio dialogue line and triggers sidechain priority ducking.
func play_tactical_radio_line(dialogue_key: StringName, lang_override: String = "") -> void:
	if not lang_override.is_empty():
		set_voice_locale(lang_override)
	if radio_audio and dialogue_manager:
		dialogue_manager.play_dialogue(dialogue_key, radio_audio, ducking_matrix)

func _update_hud() -> void:
	if not player:
		player = get_node_or_null("Player")
		
	if lbl_sector:
		var sector_names = {
			1: "Sector 1 (Rooftop)",
			2: "Sector 2 (Server Room)",
			3: "Sector 3 (Flooded Drainage)",
			4: "Sector 4 (Extraction Arena)"
		}
		lbl_sector.text = "Active Sector: %s" % sector_names.get(active_sector_idx, "Sector 1")
		
	if lbl_surface:
		var l_pos = (player.global_position if player.is_inside_tree() else player.position) if player else Vector3.ZERO
		var surf = detect_footstep_surface(l_pos)
		lbl_surface.text = "Footstep Surface: %s" % str(surf)
		
	if lbl_airlock:
		var lpf_val = int(server_portal.get_current_lpf()) if server_portal else 20000
		lbl_airlock.text = "Server Airlock: %s (Diffraction: %d Hz)" % ["Open" if is_airlock_open else "Closed", lpf_val]
		
	if lbl_acoustics:
		var rt60: float = 0.2
		var room = spatial_acoustics.rooms.get(active_room_name) if spatial_acoustics else null
		if room:
			rt60 = room.reverb_decay_time
		lbl_acoustics.text = "Acoustics: %s (RT60: %.1fs)" % [str(active_room_name), rt60]
		
	if lbl_ducking and ducking_matrix:
		var duck_db = ducking_matrix.get_gain_reduction_db(&"Voice", &"Music")
		lbl_ducking.text = "Sidechain Ducking: %.1f dB (Music -> Voice)" % duck_db
		
	if lbl_music:
		var seg = music_director.get_current_segment_name() if music_director else &"Stealth"
		lbl_music.text = "Music Stem: %s (Intensity: %.1f)" % [str(seg), combat_intensity]
		
	if lbl_voices and voice_pool:
		var phys = voice_pool.get_active_physical_count()
		var virt = voice_pool.get_active_virtual_count(bombardment_instances)
		lbl_voices.text = "Voice Pool: %d Physical / %d Virtual (Cap: 16)" % [phys, virt]
