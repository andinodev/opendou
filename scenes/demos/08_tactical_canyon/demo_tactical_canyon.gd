class_name OpenDouTacticalCanyonDemo
extends Node3D

## Master Coordinator & Logic Controller for Tactical Canyon AAA Showcase Demo (Sector 8)

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")
const OpenDouSplineEmitter3DClass = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")

# Core Audio Managers
var voice_pool: VoicePoolManager
var spatial_acoustics: SpatialAcousticsManager

# Acoustic Rooms & Portals
var room_canyon: AudioRoom
var room_bunker: AudioRoom
var room_matlab: AudioRoom
var bunker_portal: AudioPortal

# Runtime State
var active_sector_idx: int = 1
var is_bunker_door_open: bool = true
var active_test_material: StringName = &"Concrete"
var drone_orbit_angle: float = 0.0
var drone_speed: float = 25.0 # m/s
var is_debugger_active: bool = false
var debugger_mode: int = 0

# Sector Coordinates
const SECTOR_POSITIONS: Dictionary = {
	1: Vector3(0.0, 1.0, 0.0),    # Sector 1: River Gorge (Spline Emitter)
	2: Vector3(30.0, 1.0, 0.0),   # Sector 2: Bunker & Coupled Portal
	3: Vector3(60.0, 1.0, 0.0),   # Sector 3: Material Mass-Law Lab
	4: Vector3(90.0, 1.0, 0.0),   # Sector 4: Combat Drone (Doppler & LOD)
	5: Vector3(120.0, 1.0, 0.0)   # Sector 5: HDR Firing Range
}

# Scene Node References
@onready var player: Node3D = get_node_or_null("Player")
@onready var river_spline_emitter: Node3D = get_node_or_null("LevelGeometry/Sector1_RiverGorge/RiverSplineEmitter")
@onready var bunker_door_mesh: CSGBox3D = get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerDoor")
@onready var drone_emitter: Node3D = get_node_or_null("LevelGeometry/Sector4_DroneRange/DroneEmitter")
@onready var acoustic_debugger: Node = get_node_or_null("LevelGeometry/AcousticDebugger")
@onready var audible_monitor: Node = get_node_or_null("AudibleMonitor")

# UI References
@onready var btn_sector1: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
@onready var btn_sector2: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
@onready var btn_sector3: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
@onready var btn_sector4: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
@onready var btn_sector5: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector5")
@onready var btn_back: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")

@onready var btn_toggle_door: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleDoor")
@onready var opt_material: OptionButton = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/OptMaterial")
@onready var btn_detonate: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnDetonate")
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

func _init() -> void:
	_setup_runtime_systems()

func _ready() -> void:
	_bind_nodes()
	if not voice_pool:
		_setup_runtime_systems()
	_connect_ui()
	_update_hud()

func _bind_nodes() -> void:
	if not player: player = get_node_or_null("Player")
	if not river_spline_emitter: river_spline_emitter = get_node_or_null("LevelGeometry/Sector1_RiverGorge/RiverSplineEmitter")
	if not bunker_door_mesh: bunker_door_mesh = get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerDoor")
	if not drone_emitter: drone_emitter = get_node_or_null("LevelGeometry/Sector4_DroneRange/DroneEmitter")
	if not acoustic_debugger: acoustic_debugger = get_node_or_null("LevelGeometry/AcousticDebugger")
	if not audible_monitor: audible_monitor = get_node_or_null("AudibleMonitor")
	
	if not btn_sector1: btn_sector1 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
	if not btn_sector2: btn_sector2 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
	if not btn_sector3: btn_sector3 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
	if not btn_sector4: btn_sector4 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
	if not btn_sector5: btn_sector5 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector5")
	if not btn_back: btn_back = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")
	
	if not btn_toggle_door: btn_toggle_door = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleDoor")
	if not opt_material: opt_material = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/OptMaterial")
	if not btn_detonate: btn_detonate = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnDetonate")
	if not btn_toggle_acoustics: btn_toggle_acoustics = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAcoustics")
	if not btn_toggle_monitor: btn_toggle_monitor = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleMonitor")
	
	if not lbl_sector: lbl_sector = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSector")
	if not lbl_surface: lbl_surface = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSurface")
	if not lbl_acoustics: lbl_acoustics = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblAcoustics")
	if not lbl_portal_spread: lbl_portal_spread = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblPortalSpread")
	if not lbl_material_tl: lbl_material_tl = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblMaterialTL")
	if not lbl_drone_doppler: lbl_drone_doppler = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblDroneDoppler")
	if not lbl_hdr_window: lbl_hdr_window = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblHDRWindow")
	if not lbl_active_voices: lbl_active_voices = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblActiveVoices")

func _setup_runtime_systems() -> void:
	voice_pool = VoicePoolManagerClass.new(16)
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	
	# Create Physical Rooms
	room_canyon = AudioRoomClass.new(&"Canyon_Exterior", 2.2, 0.15, &"Stone")
	room_bunker = AudioRoomClass.new(&"Bunker_Interior", 0.8, 0.85, &"Concrete")
	room_matlab = AudioRoomClass.new(&"Material_Lab", 1.1, 0.60, &"Metal")
	
	spatial_acoustics.register_room(room_canyon)
	spatial_acoustics.register_room(room_bunker)
	spatial_acoustics.register_room(room_matlab)
	
	# Create Portal between Canyon and Bunker
	bunker_portal = AudioPortalClass.new(&"Bunker_Portal", &"Canyon_Exterior", &"Bunker_Interior", Vector3(30.0, 1.0, 0.0), 1.0)
	spatial_acoustics.register_portal(bunker_portal)

func _connect_ui() -> void:
	if btn_sector1: btn_sector1.pressed.connect(func(): teleport_to_sector(1))
	if btn_sector2: btn_sector2.pressed.connect(func(): teleport_to_sector(2))
	if btn_sector3: btn_sector3.pressed.connect(func(): teleport_to_sector(3))
	if btn_sector4: btn_sector4.pressed.connect(func(): teleport_to_sector(4))
	if btn_sector5: btn_sector5.pressed.connect(func(): teleport_to_sector(5))
	
	if btn_back:
		btn_back.pressed.connect(func():
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
		
	if btn_toggle_acoustics:
		btn_toggle_acoustics.pressed.connect(_on_toggle_acoustics_pressed)
		
	if btn_toggle_monitor:
		btn_toggle_monitor.pressed.connect(_on_toggle_monitor_pressed)

func teleport_to_sector(sector_idx: int) -> void:
	_bind_nodes()
	if SECTOR_POSITIONS.has(sector_idx):
		active_sector_idx = sector_idx
		if player:
			if player.is_inside_tree():
				player.global_position = SECTOR_POSITIONS[sector_idx]
			else:
				player.position = SECTOR_POSITIONS[sector_idx]
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

func _on_material_selected(idx: int) -> void:
	match idx:
		0: set_test_material(&"Concrete")
		1: set_test_material(&"Metal")
		2: set_test_material(&"Wood")
		3: set_test_material(&"Foliage")

func set_test_material(mat_name: StringName) -> void:
	active_test_material = mat_name
	_update_hud()

func trigger_hdr_explosion() -> void:
	if spatial_acoustics and spatial_acoustics.hdr_manager:
		# Register loud transient (+3 dB FS)
		spatial_acoustics.hdr_manager.register_loudness_event(3.0)
	_update_hud()

func _on_toggle_acoustics_pressed() -> void:
	if acoustic_debugger:
		debugger_mode = (debugger_mode + 1) % 3
		acoustic_debugger.set("display_mode", debugger_mode)
		acoustic_debugger.set("show_in_editor", debugger_mode > 0)
		if btn_toggle_acoustics:
			match debugger_mode:
				0: btn_toggle_acoustics.text = "🔊 Acoustics: OFF"
				1: btn_toggle_acoustics.text = "🔊 Acoustics: RAYS"
				2: btn_toggle_acoustics.text = "🔊 Acoustics: ISO-BUBBLE"
	_update_hud()

func _on_toggle_monitor_pressed() -> void:
	if audible_monitor:
		audible_monitor.visible = not audible_monitor.visible
		if btn_toggle_monitor:
			btn_toggle_monitor.text = "📊 Monitor: " + ("ON" if audible_monitor.visible else "OFF")

func detect_footstep_surface() -> StringName:
	var pos = (player.global_position if player.is_inside_tree() else player.position) if player else Vector3.ZERO
	if spatial_acoustics:
		return spatial_acoustics.detect_surface_at(pos)
	return &"Stone"

func _process(delta: float) -> void:
	# 1. Drone Orbit Motion & Doppler Simulation
	if drone_emitter:
		drone_orbit_angle += delta * 1.5
		var orbit_radius: float = 12.0
		var drone_center = SECTOR_POSITIONS[4]
		var new_pos = drone_center + Vector3(cos(drone_orbit_angle) * orbit_radius, 3.0, sin(drone_orbit_angle) * orbit_radius)
		var prev_pos = drone_emitter.global_position
		drone_emitter.global_position = new_pos
		var drone_vel = (new_pos - prev_pos) / maxf(0.001, delta)
		
		if player and spatial_acoustics:
			var listener_pos = player.global_position
			var rel_pos = listener_pos - new_pos
			var pitch = spatial_acoustics.calculate_doppler_pitch(drone_vel, Vector3.ZERO, rel_pos)
			var lod = spatial_acoustics.lod_controller.evaluate_emitter_lod(new_pos, listener_pos)
			if lbl_drone_doppler:
				lbl_drone_doppler.text = "🚁 Drone Doppler: x%.2f (LOD %d)" % [pitch, lod["lod_level"]]
	
	# 2. HDR Loudness Window Decay
	if spatial_acoustics and spatial_acoustics.hdr_manager:
		spatial_acoustics.hdr_manager.process_decay(delta)
		if lbl_hdr_window:
			var top_db = spatial_acoustics.hdr_manager.current_window_top_db
			var floor_db = spatial_acoustics.hdr_manager.current_floor_db
			lbl_hdr_window.text = "🎚️ HDR Window: Top %.1f dB | Floor %.1f dB" % [top_db, floor_db]
			
	# 3. Update Real-time River Spline Projection
	if river_spline_emitter and player and river_spline_emitter.has_method("update_virtual_position"):
		river_spline_emitter.update_virtual_position(player.global_position)

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
