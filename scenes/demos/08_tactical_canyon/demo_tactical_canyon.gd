class_name OpenDouTacticalCanyonDemo
extends Node3D

## Master Coordinator & Logic Controller for Tactical Canyon AAA Showcase Demo (Sector 8)
##
## Todos los emisores de audio son nodos OpenDou declarativos configurados en la escena .tscn.
## Este script solo gestiona la lógica de coordenadas, el HUD táctico, y las lecturas de
## telemetría acústica. No crea ni arranca streams de audio manualmente.

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")
const SoundBankManagerClass = preload("res://addons/opendou/runtime/soundbank_manager.gd")
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")

# Core Audio Managers (instanciados en código; los nodos de escena se integran automáticamente)
var voice_pool: VoicePoolManager
var spatial_acoustics: SpatialAcousticsManager
var soundbank_manager: SoundBankManager

# Acoustic Rooms & Portals (creados en código para el motor de acoplamiento de sala)
var room_canyon: AudioRoom
var room_bunker: AudioRoom
var room_matlab: AudioRoom
var bunker_portal: AudioPortal

# Runtime State
var active_sector_idx: int = 1
var is_bunker_door_open: bool = true
var active_test_material: StringName = &"Concrete"
var drone_orbit_angle: float = 0.0
var is_debugger_active: bool = false
var debugger_mode: int = 0
var granular_mode: int = 0 # 0 = Gravel Slide, 1 = Wind Turbulence
var is_convolution_active: bool = true

# Sector Coordinates
const SECTOR_POSITIONS: Dictionary = {
	1: Vector3(0.0, 1.0, 0.0),    # Sector 1: River Gorge
	2: Vector3(30.0, 1.0, 0.0),   # Sector 2: Bunker & Portal
	3: Vector3(60.0, 1.0, 0.0),   # Sector 3: Material Lab
	4: Vector3(90.0, 1.0, 0.0),   # Sector 4: Drone Range
	5: Vector3(120.0, 1.0, 0.0)   # Sector 5: HDR Firing Range
}

# ─── SCENE NODE REFERENCES ────────────────────────────────────────────────────
# Solo se referencian los nodos que requieren interacción activa del script.
# Los emisores con auto_play_event = true se gestionan solos vía OpenDouEventPlayer.

@onready var player: Node3D = get_node_or_null("Player")
@onready var bunker_door_mesh: CSGBox3D = get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerDoor")
@onready var bunker_room_node: OpenDouRoom3D = get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerRoomArea")
@onready var drone_emitter: Node3D = get_node_or_null("LevelGeometry/Sector4_DroneRange/DroneEmitter")

# DroneAudio: único emisor que el script manipula activamente (pitch_scale por Doppler)
@onready var drone_audio: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector4_DroneRange/DroneEmitter/DroneAudio")

# Granular Audio: emisor granular 3D en el desfiladero
@onready var granular_emitter: AudioStreamPlayer3D = get_node_or_null("LevelGeometry/Sector1_RiverGorge/CliffsideGranularEmitter")

# ExplosionAudio: one-shot disparado manualmente por botón o teclado E
@onready var explosion_audio: Node = get_node_or_null("LevelGeometry/Sector5_HDRFiringRange/ExplosionAudio")

@onready var acoustic_debugger: Node = get_node_or_null("LevelGeometry/AcousticDebugger")
@onready var audible_monitor: Node = get_node_or_null("AudibleMonitor")

# River spline: el script llama a update_virtual_position() cada frame
@onready var river_spline_emitter: Node = get_node_or_null("LevelGeometry/Sector1_RiverGorge/RiverSplineEmitter")

# ─── UI REFERENCES ─────────────────────────────────────────────────────────────

@onready var btn_sector1: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
@onready var btn_sector2: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
@onready var btn_sector3: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
@onready var btn_sector4: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
@onready var btn_sector5: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector5")
@onready var btn_back: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")
@onready var btn_toggle_door: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleDoor")
@onready var opt_material: OptionButton = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/OptMaterial")
@onready var btn_detonate: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnDetonate")
@onready var btn_toggle_reverb: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleReverb")
@onready var btn_toggle_granular: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleGranular")
@onready var btn_toggle_acoustics: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAcoustics")
@onready var btn_toggle_monitor: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleMonitor")

@onready var lbl_sector: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSector")
@onready var lbl_surface: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSurface")
@onready var lbl_acoustics: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblAcoustics")
@onready var lbl_portal_spread: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblPortalSpread")
@onready var lbl_material_tl: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblMaterialTL")
@onready var lbl_drone_doppler: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblDroneDoppler")
@onready var lbl_hdr_window: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblHDRWindow")
@onready var lbl_active_voices: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblActiveVoices")

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────

func _init() -> void:
	_setup_runtime_systems()

func _ready() -> void:
	_connect_ui()
	_connect_player()
	_assign_river_stream()
	_update_hud()

func _assign_river_stream() -> void:
	if river_spline_emitter == null:
		return
	var reg_script = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	if reg_script == null:
		return
	var reg = reg_script.get_singleton()
	if reg == null:
		return
	var stream = reg.get_preset_stream("Waterfall_Stream")
	if stream != null:
		river_spline_emitter.stream = stream
		if not river_spline_emitter.playing:
			river_spline_emitter.play()

# ─── RUNTIME SYSTEM SETUP ─────────────────────────────────────────────────────

func _setup_runtime_systems() -> void:
	voice_pool = VoicePoolManagerClass.new(16)
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	soundbank_manager = SoundBankManagerClass.new()

	# Registrar salas físicas en el motor acústico
	room_canyon = AudioRoomClass.new(&"Canyon_Exterior", 2.2, 0.15, &"Stone")
	room_bunker = AudioRoomClass.new(&"Bunker_Interior", 0.8, 0.85, &"Concrete")
	room_bunker.reverb_mode = 1 # CONVOLUTION_IR por defecto
	room_matlab = AudioRoomClass.new(&"Material_Lab", 1.1, 0.60, &"Metal")

	spatial_acoustics.register_room(room_canyon)
	spatial_acoustics.register_room(room_bunker)
	spatial_acoustics.register_room(room_matlab)

	# Portal de acoplamiento de sala entre el cañón y el búnker
	bunker_portal = AudioPortalClass.new(&"Bunker_Portal", &"Canyon_Exterior", &"Bunker_Interior", Vector3(30.0, 1.0, 0.0), 1.0)
	spatial_acoustics.register_portal(bunker_portal)

	# Empaquetar y cargar SoundBank binario monolítico (tactical_canyon.bnk)
	var bank_path = "user://tactical_canyon.bnk"
	if not FileAccess.file_exists(bank_path):
		var bnk_entries: Dictionary = {
			101: {
				"name": &"Gunshot_Rifle",
				"is_prefetch": true,
				"sample_rate": 44100,
				"channels": 1,
				"samples": PackedFloat32Array([0.0, 0.9, -0.7, 0.5, -0.3, 0.1, 0.0])
			},
			102: {
				"name": &"Radio_Chatter_Tactical",
				"is_prefetch": false,
				"sample_rate": 44100,
				"channels": 1,
				"samples": PackedFloat32Array([0.1, 0.2, 0.3, 0.2, 0.1, 0.0])
			}
		}
		SoundBankBuilderClass.build_bank(bank_path, bnk_entries)
	soundbank_manager.load_bank(bank_path, &"tactical_canyon")

func _exit_tree() -> void:
	if soundbank_manager:
		soundbank_manager.unload_bank(&"tactical_canyon")

# ─── UI & PLAYER CONNECTIONS ──────────────────────────────────────────────────

func _connect_player() -> void:
	if player and player.has_signal("weapon_fired"):
		if not player.weapon_fired.is_connected(_on_player_weapon_fired):
			player.weapon_fired.connect(_on_player_weapon_fired)

func _on_player_weapon_fired(_bullet_pos: Vector3) -> void:
	# Disparar en el Sector 5 activa el target explosivo HDR
	if active_sector_idx == 5:
		trigger_hdr_explosion()

func _connect_ui() -> void:
	if btn_sector1: btn_sector1.pressed.connect(func(): teleport_to_sector(1))
	if btn_sector2: btn_sector2.pressed.connect(func(): teleport_to_sector(2))
	if btn_sector3: btn_sector3.pressed.connect(func(): teleport_to_sector(3))
	if btn_sector4: btn_sector4.pressed.connect(func(): teleport_to_sector(4))
	if btn_sector5: btn_sector5.pressed.connect(func(): teleport_to_sector(5))

	if btn_back:
		btn_back.pressed.connect(func():
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if soundbank_manager:
				soundbank_manager.unload_bank(&"tactical_canyon")
			if get_tree():
				get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")
		)

	if btn_toggle_door:
		btn_toggle_door.pressed.connect(toggle_bunker_door)

	if opt_material:
		opt_material.clear()
		opt_material.add_item("Concrete (2400 kg/m³)")
		opt_material.add_item("Metal (7800 kg/m³)")
		opt_material.add_item("Wood (700 kg/m³)")
		opt_material.add_item("Foliage (150 kg/m³)")
		opt_material.item_selected.connect(_on_material_selected)

	if btn_detonate:
		btn_detonate.pressed.connect(trigger_hdr_explosion)

	if btn_toggle_reverb:
		btn_toggle_reverb.pressed.connect(toggle_reverb_convolution)

	if btn_toggle_granular:
		btn_toggle_granular.pressed.connect(toggle_granular_preset)

	if btn_toggle_acoustics:
		btn_toggle_acoustics.pressed.connect(_on_toggle_acoustics_pressed)

	if btn_toggle_monitor:
		btn_toggle_monitor.pressed.connect(_on_toggle_monitor_pressed)

# ─── KEYBOARD SHORTCUTS ───────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			KEY_TAB:    toggle_bunker_door()
			KEY_C:      toggle_reverb_convolution()
			KEY_V:      toggle_granular_preset()
			KEY_B:      inspect_soundbank()
			KEY_G:      _on_toggle_acoustics_pressed()
			KEY_M, KEY_F8: _on_toggle_monitor_pressed()
			KEY_E:      trigger_hdr_explosion()
			KEY_1:      teleport_to_sector(1)
			KEY_2:      teleport_to_sector(2)
			KEY_3:      teleport_to_sector(3)
			KEY_4:      teleport_to_sector(4)
			KEY_5:      teleport_to_sector(5)

# ─── PUBLIC DEMO ACTIONS ──────────────────────────────────────────────────────

func toggle_reverb_convolution() -> void:
	is_convolution_active = not is_convolution_active
	var target_mode = OpenDouRoom3DClass.ReverbMode.CONVOLUTION_IR if is_convolution_active else OpenDouRoom3DClass.ReverbMode.ALGORITHMIC
	var b_room = bunker_room_node if bunker_room_node != null else get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerRoomArea")
	if b_room:
		b_room.reverb_mode = target_mode
	if room_bunker:
		room_bunker.reverb_mode = 1 if is_convolution_active else 0
	if btn_toggle_reverb:
		btn_toggle_reverb.text = "🏛️ Reverb: CONV (C)" if is_convolution_active else "🏛️ Reverb: ALGO (C)"
	_update_hud()

func toggle_granular_preset() -> void:
	granular_mode = (granular_mode + 1) % 2
	var g = granular_emitter if granular_emitter != null else get_node_or_null("LevelGeometry/Sector1_RiverGorge/CliffsideGranularEmitter")
	if g and g.has_method("set_grain_parameters"):
		if granular_mode == 0:
			g.set_grain_parameters(40.0, 45.0, 15.0, 2.0)
		else:
			g.set_grain_parameters(80.0, 90.0, 25.0, 5.0)
	if btn_toggle_granular:
		btn_toggle_granular.text = "🌾 Granular: GRAVEL (V)" if granular_mode == 0 else "🌾 Granular: WIND (V)"
	_update_hud()

func inspect_soundbank() -> Dictionary:
	if soundbank_manager:
		var telem = soundbank_manager.get_bank_telemetry(&"tactical_canyon")
		_update_hud()
		return telem
	return {}

# ─── PUBLIC DEMO ACTIONS ──────────────────────────────────────────────────────

func teleport_to_sector(sector_idx: int) -> void:
	if SECTOR_POSITIONS.has(sector_idx):
		active_sector_idx = sector_idx
		var p = player if player != null else get_node_or_null("Player")
		if p:
			var pos = SECTOR_POSITIONS[sector_idx]
			if p.is_inside_tree():
				p.global_position = pos
			else:
				p.position = pos
		_update_hud()

func toggle_bunker_door() -> void:
	is_bunker_door_open = not is_bunker_door_open
	if bunker_portal:
		bunker_portal.open_factor = 1.0 if is_bunker_door_open else 0.0
	if bunker_door_mesh:
		bunker_door_mesh.position.y = 3.5 if is_bunker_door_open else 1.0
	if btn_toggle_door:
		btn_toggle_door.text = "🚪 Door: OPEN" if is_bunker_door_open else "🚪 Door: CLOSED"
	_update_hud()

func trigger_hdr_explosion() -> void:
	# El nodo OpenDouEventPlayer3D dispara su synth_preset en play_event()
	if explosion_audio and explosion_audio.has_method("play_event"):
		explosion_audio.call("play_event")

	# Registrar el transitorio masivo (+3 dB FS) en el gestor HDR
	if spatial_acoustics and spatial_acoustics.hdr_manager:
		spatial_acoustics.hdr_manager.register_loudness_event(3.0)
	_update_hud()

func set_test_material(mat_name: StringName) -> void:
	active_test_material = mat_name
	_update_hud()

func detect_footstep_surface() -> StringName:
	var pos = Vector3.ZERO
	if player:
		pos = player.global_position if player.is_inside_tree() else player.position
	if spatial_acoustics:
		return spatial_acoustics.detect_surface_at(pos)
	return &"Stone"

# ─── UI CALLBACKS ─────────────────────────────────────────────────────────────

func _on_material_selected(idx: int) -> void:
	match idx:
		0: set_test_material(&"Concrete")
		1: set_test_material(&"Metal")
		2: set_test_material(&"Wood")
		3: set_test_material(&"Foliage")

func _on_toggle_acoustics_pressed() -> void:
	if acoustic_debugger:
		debugger_mode = (debugger_mode + 1) % 3
		acoustic_debugger.set("display_mode", debugger_mode)
		acoustic_debugger.set("show_in_editor", debugger_mode > 0)
		if btn_toggle_acoustics:
			match debugger_mode:
				0: btn_toggle_acoustics.text = "🔊 Acoustics: OFF (G)"
				1: btn_toggle_acoustics.text = "🔊 Acoustics: RAYS (G)"
				2: btn_toggle_acoustics.text = "🔊 Acoustics: ISO-BUBBLE (G)"
	_update_hud()

func _on_toggle_monitor_pressed() -> void:
	if audible_monitor:
		if audible_monitor.has_method("toggle_overlay"):
			audible_monitor.toggle_overlay()
		else:
			audible_monitor.visible = not audible_monitor.visible
		if btn_toggle_monitor:
			var is_vis = audible_monitor.get("is_overlay_visible") if ("is_overlay_visible" in audible_monitor) else audible_monitor.visible
			btn_toggle_monitor.text = "📊 Monitor: " + ("ON (M)" if is_vis else "OFF (M)")

# ─── PHYSICS PROCESS ──────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	# Sincronizar la superficie de pasos del jugador con el terreno acústico físico
	if player and spatial_acoustics and "current_surface" in player:
		var pos = player.global_position if player.is_inside_tree() else player.position
		var detected = spatial_acoustics.detect_surface_at(pos)
		if player.current_surface != detected:
			player.current_surface = detected

# ─── PROCESS ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# 1. Orbitar el dron y actualizar Doppler + pitch_scale del OpenDouEventPlayer3D
	if drone_emitter:
		drone_orbit_angle += delta * 1.5
		var orbit_radius: float = 12.0
		var drone_center = SECTOR_POSITIONS[4]
		var new_pos = drone_center + Vector3(cos(drone_orbit_angle) * orbit_radius, 3.0, sin(drone_orbit_angle) * orbit_radius)
		var prev_pos = drone_emitter.global_position
		drone_emitter.global_position = new_pos
		var drone_vel = (new_pos - prev_pos) / maxf(0.001, delta)

		if player and spatial_acoustics:
			var listener_pos = player.global_position if player.is_inside_tree() else player.position
			var rel_pos = listener_pos - new_pos
			var pitch = spatial_acoustics.calculate_doppler_pitch(drone_vel, Vector3.ZERO, rel_pos)

			# Aplicar Doppler al AudioStreamPlayer3D subyacente del nodo OpenDouEventPlayer3D
			if drone_audio:
				drone_audio.pitch_scale = pitch

			var lod = spatial_acoustics.lod_controller.evaluate_emitter_lod(new_pos, listener_pos)
			if lbl_drone_doppler:
				lbl_drone_doppler.text = "🚁 Drone Doppler: x%.2f (LOD %d)" % [pitch, lod["lod_level"]]

	# 2. Decaimiento del pico HDR
	if spatial_acoustics and spatial_acoustics.hdr_manager:
		spatial_acoustics.hdr_manager.process_decay(delta)
		if lbl_hdr_window:
			var top_db = spatial_acoustics.hdr_manager.current_window_top_db
			var floor_db = spatial_acoustics.hdr_manager.current_floor_db
			lbl_hdr_window.text = "🎚️ HDR Window: Top %.1f dB | Floor %.1f dB" % [top_db, floor_db]

	# 3. Proyección continua del spline del río al punto más cercano al oyente
	if river_spline_emitter and player and river_spline_emitter.has_method("update_spline_acoustics"):
		var p_pos = player.global_position if player.is_inside_tree() else player.position
		river_spline_emitter.update_spline_acoustics(p_pos, Vector3.ZERO, delta)

	# 4. Actualizar contador de voces activas en HUD
	if lbl_active_voices and audible_monitor and audible_monitor.has_method("get_displayed_voices_count"):
		lbl_active_voices.text = "🎙️ Voices: %d Active" % audible_monitor.get_displayed_voices_count()


# ─── HUD UPDATE ───────────────────────────────────────────────────────────────

func _update_hud() -> void:
	if lbl_sector:
		var sector_names = {
			1: "Sector 1: River Gorge (Spline Emitter)",
			2: "Sector 2: Bunker & Portal Airlock",
			3: "Sector 3: Material Mass-Law Lab",
			4: "Sector 4: Drone Range (Doppler & LOD)",
			5: "Sector 5: HDR Firing Range"
		}
		lbl_sector.text = "📍 Location: %s" % sector_names.get(active_sector_idx, "Unknown")

	if lbl_surface:
		lbl_surface.text = "👟 Floor Surface: %s" % detect_footstep_surface()

	if lbl_portal_spread and bunker_portal and player and spatial_acoustics:
		var pos = player.global_position if player.is_inside_tree() else player.position
		var coupling = spatial_acoustics.coupling_engine.evaluate_room_coupling(room_canyon, bunker_portal, pos)
		lbl_portal_spread.text = "🚪 Portal Spread: %.1f° | RT60 Coupled: %.2fs" % [
			coupling["sound_spread_degrees"], coupling["coupled_rt60"]
		]

	if lbl_material_tl and spatial_acoustics and spatial_acoustics.material_registry:
		var tl = spatial_acoustics.material_registry.calculate_transmission_loss(active_test_material, 0.3, 1000.0)
		var att_db = tl.get("attenuation_db", 0.0)
		var cutoff = tl.get("cutoff_lpf", 20000.0)
		lbl_material_tl.text = "🧱 Material: %s | TL: -%.1f dB | LPF: %.0f Hz" % [
			active_test_material, att_db, cutoff
		]

	if lbl_acoustics:
		var rev_str = "CONV IR" if is_convolution_active else "ALGO"
		var gran_str = "GRAVEL" if granular_mode == 0 else "WIND"
		var bnk_info = ""
		if soundbank_manager:
			var telem = soundbank_manager.get_bank_telemetry(&"tactical_canyon")
			if telem.has("prefetch_ram_bytes"):
				bnk_info = " | BNK RAM: %d B" % telem["prefetch_ram_bytes"]
		lbl_acoustics.text = "🔊 Reverb: %s | Granular: %s%s" % [rev_str, gran_str, bnk_info]

	if lbl_active_voices:
		var count: int = 0
		if audible_monitor and audible_monitor.has_method("get_displayed_voices_count"):
			count = audible_monitor.get_displayed_voices_count()
		lbl_active_voices.text = "🎙️ Voices: %d Active" % count

