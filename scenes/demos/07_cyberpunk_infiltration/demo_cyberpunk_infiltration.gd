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

const OpenDouRadarViewClass = preload("res://addons/opendou/editor/opendou_radar_view.gd")

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
var room_biosphere: AudioRoom
var server_portal: AudioPortal
var biosphere_portal: AudioPortal

# Runtime State
var is_airlock_open: bool = true
var combat_intensity: float = 0.0
var turret_occlusion: float = 0.0
var active_sector_idx: int = 1
var active_room_name: StringName = &"Rooftop_Exterior"
var bombardment_instances: Array[EventInstance] = []
var orbit_angle: float = 0.0

# Teleportation Sector Positions
const SECTOR_POSITIONS: Dictionary = {
	1: Vector3(-25.0, 1.0, 0.0), # Sector 1: Rooftop
	2: Vector3(0.0, 1.0, 0.0), # Sector 2: Server Room
	3: Vector3(25.0, 1.0, 0.0), # Sector 3: Flooded Drainage
	4: Vector3(50.0, 1.0, 0.0), # Sector 4: Extraction Arena
	5: Vector3(80.0, 1.5, 0.0) # Sector 5: Biosphere Sanctuary
}

# Scene Node References
@onready var player: Node = get_node_or_null("Player")
@onready var server_airlock_mesh: CSGBox3D = get_node_or_null("LevelGeometry/Sector2_ServerRoom/ServerAirlockGate")
@onready var orbiting_bee_emitter: Node3D = get_node_or_null("LevelGeometry/Sector5_Biosphere/OrbitingBeeEmitter")

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
@onready var music_audio: AudioStreamPlayer = get_node_or_null("Player/MusicAudio")
@onready var music_player: Node = get_node_or_null("Player/MusicPlayer")

# Declarative Environment Nodes
@onready var portal_3d: Node3D = get_node_or_null("LevelGeometry/Sector2_ServerRoom/ServerAirlockPortal")
@onready var room_rooftop_node: Area3D = get_node_or_null("LevelGeometry/Sector1_Rooftop/RooftopRoom")
@onready var room_server_node: Area3D = get_node_or_null("LevelGeometry/Sector2_ServerRoom/ServerRoomArea")
@onready var room_drainage_node: Area3D = get_node_or_null("LevelGeometry/Sector3_FloodedDrainage/DrainageRoom")
@onready var room_extraction_node: Area3D = get_node_or_null("LevelGeometry/Sector4_ExtractionArena/ExtractionArenaRoom")

# Music Suite & Stems
var active_music_suite: StringName = &"Exploration_Ambient_Theme.tres"
var stem_players: Array[AudioStreamPlayer] = []
var stem_track_data: Array[Dictionary] = []

# UI References
@onready var btn_sector1: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
@onready var btn_sector2: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
@onready var btn_sector3: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
@onready var btn_sector4: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
@onready var btn_sector_5: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnSector5") if get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnSector5") else get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector5")
@onready var btn_sector5: Button = btn_sector_5
@onready var btn_back: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")
@onready var opt_suite: OptionButton = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/OptSuite")

@onready var btn_toggle_airlock: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAirlock")
@onready var btn_bombardment: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnBombardment")
@onready var btn_radio: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnRadio")
@onready var btn_toggle_monitor: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleMonitor")
@onready var slider_intensity: HSlider = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/SliderIntensity")
@onready var btn_lang_en: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangEN")
@onready var btn_lang_es: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangES")
@onready var btn_lang_ja: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangJA")
@onready var btn_lang_zh: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnLangZH")

@onready var audible_monitor: Node = get_node_or_null("AudibleMonitor")

@onready var lbl_sector: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSector")
@onready var lbl_surface: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSurface")
@onready var lbl_acoustics: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblAcoustics")
@onready var lbl_airlock: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblAirlock")
@onready var lbl_occlusion: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblOcclusion")
@onready var lbl_snapshot: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSnapshot")
@onready var lbl_voices: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblVoices")
@onready var lbl_ducking: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblDucking")
@onready var lbl_music: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblMusic")
@onready var lbl_dsp: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblDSP")
@onready var lbl_subtitles: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSubtitles")
@onready var radar_view: Control = get_node_or_null("TacticalHUD/RadarContainer/Margin/RadarVBox/RadarView")

func _init() -> void:
	_setup_runtime_systems()
	_start_music_audio()

func _ready() -> void:
	if not voice_pool:
		_setup_runtime_systems()
	if audible_monitor and audible_monitor.has_method("set_ducking_matrix"):
		audible_monitor.set_ducking_matrix(ducking_matrix)
	_connect_ui()
	_update_hud()

func _setup_runtime_systems() -> void:
	# 1. Voice Pool Manager
	voice_pool = VoicePoolManagerClass.new(16)
	
	# 2. Spatial Acoustics Manager with 4 Rooms & Airlock Portal
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	
	room_rooftop = AudioRoomClass.new(&"Rooftop_Exterior", 0.4, 0.1)
	room_rooftop.floor_surface = &"Metal"
	room_rooftop.set_bounds(AABB(Vector3(-38.0, 0.0, -15.0), Vector3(26.0, 10.0, 30.0)))
	
	room_server = AudioRoomClass.new(&"Server_Room", 0.2, 0.3)
	room_server.floor_surface = &"Tile"
	room_server.set_bounds(AABB(Vector3(-12.0, 0.0, -15.0), Vector3(24.0, 10.0, 30.0)))
	
	room_drainage = AudioRoomClass.new(&"Flooded_Drainage", 1.2, 0.05)
	room_drainage.floor_surface = &"Water"
	room_drainage.set_bounds(AABB(Vector3(12.0, 0.0, -15.0), Vector3(25.0, 10.0, 30.0)))
	
	room_extraction = AudioRoomClass.new(&"Extraction_Arena", 0.8, 0.15)
	room_extraction.floor_surface = &"Concrete"
	room_extraction.set_bounds(AABB(Vector3(37.0, 0.0, -25.0), Vector3(28.0, 12.0, 50.0)))
	
	room_biosphere = AudioRoomClass.new(&"Biosphere_Sanctuary", 0.38, 0.60)
	room_biosphere.floor_surface = &"Foliage"
	room_biosphere.set_bounds(AABB(Vector3(65.0, 0.0, -25.0), Vector3(35.0, 12.0, 50.0)))
	
	spatial_acoustics.register_room(room_rooftop)
	spatial_acoustics.register_room(room_server)
	spatial_acoustics.register_room(room_drainage)
	spatial_acoustics.register_room(room_extraction)
	spatial_acoustics.register_room(room_biosphere)
	
	server_portal = AudioPortalClass.new(&"Server_Airlock", &"Rooftop_Exterior", &"Server_Room", Vector3(-12.0, 1.5, 0.0), 1.0)
	spatial_acoustics.register_portal(server_portal)
	
	biosphere_portal = AudioPortalClass.new(&"Arena_To_Biosphere_Portal", &"Extraction_Arena", &"Biosphere_Sanctuary", Vector3(65.0, 1.5, 0.0), 1.0)
	spatial_acoustics.register_portal(biosphere_portal)
	
	# 3. Multi-Bus Ducking Matrix
	ducking_matrix = AudioDuckingMatrixClass.new()
	ducking_matrix.add_ducking_rule(&"Voice", &"Music", -14.0, 0.05, 0.40)
	ducking_matrix.add_ducking_rule(&"SFX", &"Music", -8.0, 0.02, 0.30)
	
	# 4. Localized Dialogue Manager & Table
	dialogue_table = AudioDialogueTableClass.new()
	var line_stream = AudioSynthesizerClass.create_tone(440.0, 1.2)
	dialogue_table.add_entry(&"sec_clear_01", "en", line_stream)
	dialogue_table.add_entry(&"sec_clear_01", "es", line_stream)
	dialogue_table.add_entry(&"sec_clear_01", "ja", line_stream)
	dialogue_table.add_entry(&"sec_clear_01", "zh", line_stream)
	dialogue_table.add_entry(&"tactical_alert", "en", line_stream)
	dialogue_table.add_entry(&"tactical_alert", "es", line_stream)
	dialogue_table.add_entry(&"tactical_alert", "ja", line_stream)
	dialogue_table.add_entry(&"tactical_alert", "zh", line_stream)
	dialogue_manager = AudioDialogueManagerClass.new("en", dialogue_table)
	
	# 5. Interactive Music Playlist Director
	music_director = MusicPlaylistManagerClass.new()
	music_director.add_item(&"Intro_Theme", 1, 1)
	music_director.add_item(&"Stealth_Loop", 2, 4)
	music_director.add_item(&"Combat_Alert", 2, 4)
	music_director.add_item(&"Extraction_Outro", 1, 1)
	music_director.start_playlist()
	
	# 6. Live Update TCP Server
	live_update_server = LiveUpdateServerClass.new()
	live_update_server.start_server(8999)

func _start_ambient_audio() -> void:
	# Ambient audio emitters (OpenDouEventPlayer3D) manage their own streams and playback via synth presets and .tscn parameters
	pass

func _start_music_audio() -> void:
	load_music_suite(&"Exploration_Ambient_Theme.tres")

## Loads and initializes multi-stem music suite from opendou_music_suites.json
func load_music_suite(suite_name: StringName) -> void:
	active_music_suite = suite_name
	
	# Clean up previous stem players
	for p in stem_players:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	stem_players.clear()
	stem_track_data.clear()
	
	var tracks_to_create: Array[Dictionary] = []
	const SUITES_PATH = "res://opendou_music_suites.json"
	if FileAccess.file_exists(SUITES_PATH):
		var file = FileAccess.open(SUITES_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and parsed.has(str(suite_name)):
				var s_data = parsed[str(suite_name)]
				if s_data.has("tracks") and s_data["tracks"] is Array:
					for td in s_data["tracks"]:
						if td is Dictionary:
							tracks_to_create.append(td)
	
	if tracks_to_create.is_empty():
		pass
		if str(suite_name).contains("Exploration"):
			tracks_to_create = [
				{"name": "Layer 1: Ambient_Pads", "min_intensity": 0.0, "max_intensity": 0.7, "bus_name": "Music"},
				{"name": "Layer 2: Nature_Foley", "min_intensity": 0.2, "max_intensity": 1.0, "bus_name": "Music"}
			]
		else:
			tracks_to_create = [
				{"name": "Layer 1: Ambient_Pads", "min_intensity": 0.0, "max_intensity": 0.5, "bus_name": "Music"},
				{"name": "Layer 2: Stealth_Bass", "min_intensity": 0.2, "max_intensity": 0.7, "bus_name": "Music"},
				{"name": "Layer 3: Combat_Drums", "min_intensity": 0.5, "max_intensity": 1.0, "bus_name": "Music"}
			]
			
	var music_parent = player if (player and player.is_inside_tree()) else self
	
	for idx in range(tracks_to_create.size()):
		var t_info = tracks_to_create[idx]
		var t_name = str(t_info.get("name", "Stem_%d" % idx))
		var min_i = float(t_info.get("min_intensity", 0.0))
		var max_i = float(t_info.get("max_intensity", 1.0))
		var vol = float(t_info.get("volume_db", 0.0))
		
		var p = AudioStreamPlayer.new()
		p.name = "StemPlayer_%d" % idx
		p.bus = StringName(str(t_info.get("bus_name", "Music")))
		
		if t_name.contains("Pad") or t_name.contains("Ambient"):
			p.stream = AudioSynthesizerClass.create_music_pad_loop(2.0)
		elif t_name.contains("Foley") or t_name.contains("Nature"):
			p.stream = AudioSynthesizerClass.create_nature_foley_loop(2.0)
		elif t_name.contains("Bass") or t_name.contains("Stealth"):
			p.stream = AudioSynthesizerClass.create_music_bass_loop(2.0)
		elif t_name.contains("Drum") or t_name.contains("War"):
			p.stream = AudioSynthesizerClass.create_music_drums_loop(2.0)
		elif t_name.contains("Brass") or t_name.contains("Lead") or t_name.contains("Choir"):
			p.stream = AudioSynthesizerClass.create_music_brass_loop(2.0)
		else:
			p.stream = AudioSynthesizerClass.create_chord_loop(2.0)
			
		music_parent.add_child(p)
		if p.is_inside_tree():
			p.play()
		stem_players.append(p)
		stem_track_data.append({
			"name": t_name,
			"min_intensity": min_i,
			"max_intensity": max_i,
			"volume_db": vol
		})
		
	_update_stem_levels()
	_update_hud()

func _update_stem_levels() -> void:
	var duck_gr = ducking_matrix.get_gain_reduction_db(&"Voice", &"Music") if ducking_matrix else 0.0
	for i in range(stem_players.size()):
		var p = stem_players[i]
		if not is_instance_valid(p):
			continue
		var data = stem_track_data[i]
		var min_i: float = data.get("min_intensity", 0.0)
		var max_i: float = data.get("max_intensity", 1.0)
		var base_vol: float = data.get("volume_db", 0.0)
		
		var is_active = combat_intensity >= (min_i - 0.05) and combat_intensity <= (max_i + 0.05)
		if is_active:
			p.volume_db = base_vol + duck_gr
		else:
			p.volume_db = -60.0

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
	if btn_sector_5:
		btn_sector_5.pressed.connect(func(): teleport_to_sector(5))
	var top_btn_sec5 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector5")
	if top_btn_sec5 and top_btn_sec5 != btn_sector_5:
		top_btn_sec5.pressed.connect(func(): teleport_to_sector(5))
	if btn_toggle_airlock:
		btn_toggle_airlock.pressed.connect(toggle_server_airlock)
	if btn_bombardment:
		btn_bombardment.pressed.connect(trigger_siege_bombardment)
	if btn_radio:
		btn_radio.pressed.connect(func():
			var cur_lang = dialogue_manager.current_language if dialogue_manager else "en"
			play_tactical_radio_line(&"sec_clear_01", cur_lang)
		)
	if btn_toggle_monitor:
		btn_toggle_monitor.pressed.connect(func():
			if audible_monitor:
				if audible_monitor.has_method("toggle_overlay"):
					audible_monitor.toggle_overlay()
				elif "is_overlay_visible" in audible_monitor:
					audible_monitor.is_overlay_visible = not audible_monitor.is_overlay_visible
				elif "visible" in audible_monitor:
					audible_monitor.visible = not audible_monitor.visible
		)
	if slider_intensity:
		slider_intensity.value_changed.connect(func(v: float): set_combat_intensity(v))
		
	if opt_suite:
		opt_suite.item_selected.connect(func(idx: int):
			var s_names = [
				&"Exploration_Ambient_Theme.tres",
				&"Dynamic_Combat_Suite.tres",
				&"Boss_Phase_Orchestral.tres"
			]
			if idx >= 0 and idx < s_names.size():
				pass
				load_music_suite(s_names[idx])
		)
		
	if btn_lang_en:
		btn_lang_en.pressed.connect(func(): play_tactical_radio_line(&"sec_clear_01", "en"))
	if btn_lang_es:
		btn_lang_es.pressed.connect(func(): play_tactical_radio_line(&"sec_clear_01", "es"))
	if btn_lang_ja:
		btn_lang_ja.pressed.connect(func(): play_tactical_radio_line(&"sec_clear_01", "ja"))
	if btn_lang_zh:
		btn_lang_zh.pressed.connect(func(): play_tactical_radio_line(&"sec_clear_01", "zh"))

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

func _process(delta: float) -> void:
	if not orbiting_bee_emitter:
		orbiting_bee_emitter = get_node_or_null("LevelGeometry/Sector5_Biosphere/OrbitingBeeEmitter")
	if orbiting_bee_emitter:
		orbit_angle += delta * 1.2
		orbiting_bee_emitter.position = Vector3(
			80.0 + cos(orbit_angle) * 5.0,
			1.8 + sin(orbit_angle * 2.0) * 0.4,
			sin(orbit_angle) * 5.0
		)

func _physics_process(delta: float) -> void:
	# 1. Update Live Update TCP Server
	if live_update_server and live_update_server.is_server_running:
		live_update_server.poll()
		
	# 2. Update Ducking Matrix & Dialogue
	if ducking_matrix:
		ducking_matrix.update(delta)
	if dialogue_manager:
		dialogue_manager.update(delta, ducking_matrix)
		
	# 3. Apply ducking & intensity to music stems
	_update_stem_levels()
		
	var listener_pos: Vector3 = Vector3.ZERO
	if player:
		listener_pos = player.global_position if player.is_inside_tree() else player.position
	elif SECTOR_POSITIONS.has(active_sector_idx):
		listener_pos = SECTOR_POSITIONS[active_sector_idx]
	
	# 4. Update Bombardment Event Instances & Voice Pool Stealing Resolution
	if not bombardment_instances.is_empty():
		for inst in bombardment_instances:
			if inst:
				inst.update_parameters(delta)
		if voice_pool:
			voice_pool.resolve_voice_stealing(bombardment_instances, listener_pos, delta)
		
	# 5. Dynamic Pillar Raycast Occlusion in Sector 4
	_update_pillar_occlusion(listener_pos)
	
	# 6. Update room acoustics based on player position
	_update_room_acoustics(listener_pos)
	
	# 7. Update 2D Spatial Acoustic Radar Telemetry
	_update_radar_telemetry(listener_pos)
	
	# 8. Refresh HUD telemetry labels
	_update_hud()

func _update_radar_telemetry(listener_pos: Vector3) -> void:
	if not radar_view:
		radar_view = get_node_or_null("TacticalHUD/RadarContainer/Margin/RadarVBox/RadarView")
	if not radar_view:
		return
		
	var emitter_data: Array = []
	if rain_audio and rain_audio.playing:
		emitter_data.append({
			"event_name": "Rain_Ambience",
			"world_position": rain_audio.global_position if rain_audio.is_inside_tree() else rain_audio.position,
			"is_virtual": false,
			"volume_db": rain_audio.volume_db
		})
	if server_audio and server_audio.playing:
		emitter_data.append({
			"event_name": "Server_Racks",
			"world_position": server_audio.global_position if server_audio.is_inside_tree() else server_audio.position,
			"is_virtual": false,
			"volume_db": server_audio.volume_db
		})
	if water_audio and water_audio.playing:
		emitter_data.append({
			"event_name": "Flooded_Water",
			"world_position": water_audio.global_position if water_audio.is_inside_tree() else water_audio.position,
			"is_virtual": false,
			"volume_db": water_audio.volume_db
		})
	if turret_audio and turret_audio.playing:
		emitter_data.append({
			"event_name": "Turret_Scan",
			"world_position": turret_audio.global_position if turret_audio.is_inside_tree() else turret_audio.position,
			"is_virtual": false,
			"volume_db": turret_audio.volume_db
		})
	if radio_beacon_audio and radio_beacon_audio.playing:
		emitter_data.append({
			"event_name": "Radio_Beacon",
			"world_position": radio_beacon_audio.global_position if radio_beacon_audio.is_inside_tree() else radio_beacon_audio.position,
			"is_virtual": false,
			"volume_db": radio_beacon_audio.volume_db
		})
	if orbiting_bee_emitter and orbiting_bee_emitter is AudioStreamPlayer3D and orbiting_bee_emitter.playing:
		emitter_data.append({
			"event_name": "Cyber_Hornet",
			"world_position": orbiting_bee_emitter.global_position if orbiting_bee_emitter.is_inside_tree() else orbiting_bee_emitter.position,
			"is_virtual": false,
			"volume_db": orbiting_bee_emitter.volume_db
		})
	for inst in bombardment_instances:
		if inst and inst.is_playing():
			emitter_data.append({
				"event_name": "Siege_Explosion",
				"world_position": inst.emitter_position,
				"is_virtual": inst.voice_state == EventInstanceClass.VoiceState.STATE_VIRTUAL,
				"volume_db": inst.calculated_volume_db
			})
			
	if radar_view.has_method("update_radar_data"):
		radar_view.update_radar_data(emitter_data, listener_pos)
		
	if radar_view.has_method("update_telemetry_metrics") and voice_pool:
		var phys = voice_pool.get_active_physical_count()
		var virt = voice_pool.get_active_virtual_count(bombardment_instances)
		radar_view.update_telemetry_metrics(phys, virt, 0.12, 1420)

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
			elif pos.x >= 65.0:
				active_room_name = &"Biosphere_Sanctuary"
			else:
				active_room_name = &"Extraction_Arena"

## Detects the physical ground surface material type for dynamic footstep audio synthesis.
## Delegates to the 3-tier SpatialAcousticsManager hierarchy when available.
func detect_footstep_surface(pos: Vector3) -> StringName:
	if spatial_acoustics:
		var w3d: World3D = get_world_3d() if is_inside_tree() else null
		return spatial_acoustics.detect_surface_at(pos, w3d)
	# Fallback: positional if/elif chain (used only when spatial_acoustics is null)
	if pos.x < -12.0:
		return &"Metal"
	elif pos.x < 12.0:
		return &"Tile"
	elif pos.x < 37.0:
		return &"Water"
	elif pos.x >= 65.0:
		return &"Foliage"
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

## Teleports player to the specified sector index (1 to 5).
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
	_update_room_acoustics(target_pos)
	_update_hud()

## Toggles the server airlock door open / closed with acoustic portal diffraction.
func toggle_server_airlock() -> void:
	is_airlock_open = not is_airlock_open
	if server_portal:
		server_portal.open_factor = 1.0 if is_airlock_open else 0.05
	if portal_3d and "open_factor" in portal_3d:
		portal_3d.open_factor = 1.0 if is_airlock_open else 0.05
	if server_airlock_mesh:
		server_airlock_mesh.scale.y = 0.1 if is_airlock_open else 1.0
		server_airlock_mesh.position.y = 3.6 if is_airlock_open else 1.8
	_update_hud()

## Modifies combat intensity RTPC for dynamic music layering.
func set_combat_intensity(val: float) -> void:
	combat_intensity = clampf(val, 0.0, 1.0)
	if slider_intensity and not is_equal_approx(slider_intensity.value, combat_intensity):
		slider_intensity.value = combat_intensity
	if music_director:
		if combat_intensity < 0.35:
			music_director.current_index = 1 # Stealth_Loop
		elif combat_intensity < 0.70:
			music_director.current_index = 2 # Combat_Alert
		else:
			music_director.current_index = 3 # Extraction_Outro
	if music_player and music_player.has_method("set_combat_intensity"):
		music_player.set_combat_intensity(combat_intensity)
	_update_stem_levels()
	_update_hud()

## Changes active voice localization locale.
func set_voice_locale(loc: String) -> void:
	if dialogue_manager:
		dialogue_manager.set_language(loc)
	_update_hud()

## Plays a localized radio dialogue line, triggers priority ducking, and displays HUD subtitles.
func play_tactical_radio_line(dialogue_key: StringName, loc: String = "en") -> void:
	set_voice_locale(loc)
	
	if not radio_audio:
		radio_audio = get_node_or_null("Player/RadioAudio")
	if not radio_audio:
		radio_audio = AudioStreamPlayer.new()
		radio_audio.name = "RadioAudio"
		add_child(radio_audio)
		
	if dialogue_manager:
		dialogue_manager.play_dialogue(dialogue_key, radio_audio, ducking_matrix)
		
	if music_audio and ducking_matrix:
		var gr_db = ducking_matrix.get_gain_reduction_db(&"Voice", &"Music")
		music_audio.volume_db = gr_db
		
	var subtitles: Dictionary = {
		&"sec_clear_01": {
			"en": "[HQ Radio]: Sector 1 rooftop perimeter is secure. Proceed to server vault.",
			"es": "[Radio HQ]: Perímetro del tejado en Sector 1 despejado. Proceda a la bóveda de servidores.",
			"ja": "[HQ無線]: セクター1屋上の安全を確認。サーバー保管室へ侵入せよ。",
			"zh": "[总部电台]: 1区屋顶周围已清除威胁。请前往服务器机房。"
		},
		&"tactical_alert": {
			"en": "[HQ Radio]: Warning! Extraction arena perimeter breached! Heavy siege underway.",
			"es": "[Radio HQ]: ¡Alerta! ¡Perímetro del helipuerto violado! Bombardeo pesado en curso.",
			"ja": "[HQ無線]: 警告！脱出エリア境界が突破された！重爆撃開始。",
			"zh": "[总部电台]: 警告！撤离点防线已被突破！重炮轰炸中。"
		}
	}
	var sub_text = subtitles.get(dialogue_key, {}).get(loc, "[HQ Radio]: Tactical communication transmission.")
	if lbl_subtitles:
		lbl_subtitles.text = sub_text
		
	_update_hud()

func _update_hud() -> void:
	if not player:
		player = get_node_or_null("Player")
		
	var l_pos = (player.global_position if player.is_inside_tree() else player.position) if player else Vector3.ZERO
	var surf = detect_footstep_surface(l_pos)
		
	if lbl_sector:
		var sector_names = {
			1: "Sector 1 (Rooftop)",
			2: "Sector 2 (Server Room)",
			3: "Sector 3 (Flooded Drainage)",
			4: "Sector 4 (Extraction Arena)",
			5: "Sector 5 (Biosphere Sanctuary)"
		}
		lbl_sector.text = "Active Sector: %s" % sector_names.get(active_sector_idx, "Sector 1")
		
	if lbl_surface:
		lbl_surface.text = "Surface: %s" % str(surf)
		
	if lbl_airlock:
		var lpf_val = int(server_portal.get_current_lpf()) if server_portal else 20000
		lbl_airlock.text = "Server Airlock: %s (Diffraction: %d Hz)" % ["Open" if is_airlock_open else "Closed", lpf_val]
		
	if lbl_acoustics:
		var rt60: float = 0.2
		var room = spatial_acoustics.rooms.get(active_room_name) if spatial_acoustics else null
		if room:
			rt60 = room.reverb_decay_time
		lbl_acoustics.text = "Room: %s (RT60: %.1fs)" % [str(active_room_name), rt60]
		
	if lbl_occlusion:
		var occl_pct = int(turret_occlusion * 100.0)
		lbl_occlusion.text = "Portal / Turret Occlusion: %d%%" % occl_pct
		
	if lbl_snapshot:
		var snap_name = "Underwater_Muffle" if active_room_name == &"Flooded_Drainage" else "Default_Environment"
		lbl_snapshot.text = "Snapshot: %s" % snap_name
		
	if lbl_ducking and ducking_matrix:
		var duck_db = ducking_matrix.get_gain_reduction_db(&"Voice", &"Music")
		lbl_ducking.text = "Ducking GR: %.1f dB" % duck_db
		
	if lbl_music:
		var seg = music_director.get_current_segment_name() if music_director else &"Stealth"
		lbl_music.text = "Music Stem: %s (Intensity: %.2f)" % [str(seg), combat_intensity]
		
	if lbl_voices and voice_pool:
		var phys = voice_pool.get_active_physical_count()
		var virt = voice_pool.get_active_virtual_count(bombardment_instances)
		lbl_voices.text = "Voices: %d Phys / %d Virt" % [phys, virt]
