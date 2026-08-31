class_name OpenDouTacticalInfiltrationDemo
extends Node3D

## Master Controller for Demo 09: Tactical Infiltration Showcase
## Demonstrates all 13 OpenDou spatial audio nodes, geometry baking, parameter areas,
## multi-position emission, animation sync, and volumetric sound fields in an interactive level.

const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const OpenDouPortal3DClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")
const OpenDouParameterArea3DClass = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
const OpenDouMultiPositionEmitter3DClass = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")
const OpenDouAcousticGeometryBakeClass = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")
const OpenDouAnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")

# Runtime State
var active_sector_idx: int = 1
var is_blast_door_open: bool = true
var is_debugger_active: bool = false
var debugger_mode: int = 0
var toxic_tension_value: float = 0.0
var active_surface: StringName = &"Stone"

# Sector Positions
const SECTOR_POSITIONS: Dictionary = {
	1: Vector3(0.0, 1.0, 0.0),    # Sector 1: Outer Cavern & Spline River
	2: Vector3(30.0, 1.0, 0.0),   # Sector 2: Toxic Spore Corridor
	3: Vector3(60.0, 1.0, 0.0),   # Sector 3: Bunker Complex & Generator
	4: Vector3(90.0, 1.0, 0.0)    # Sector 4: Elite Enemy Overlook
}

# ─── SCENE REFERENCES ─────────────────────────────────────────────────────────

var player: CharacterBody3D = null
var player_anim_sync: OpenDouAnimationSync = null
var enemy_rig: CharacterBody3D = null
var enemy_anim_sync: OpenDouAnimationSync = null

var acoustic_bake: OpenDouAcousticGeometryBake = null
var room_cavern: OpenDouRoom3D = null
var room_bunker: OpenDouRoom3D = null
var access_portal: OpenDouPortal3D = null
var blast_door_mesh: Node3D = null

var toxic_area: OpenDouParameterArea3D = null
var river_spline: AudioStreamPlayer3D = null
var spore_granular: AudioStreamPlayer3D = null
var generator_multi: OpenDouMultiPositionEmitter3D = null
var cavern_reflector: Node3D = null

var music_player: Node = null
var acoustic_debugger: Node = null
var audible_monitor: Node = null

# ─── UI REFERENCES ─────────────────────────────────────────────────────────────

var btn_sector1: Button = null
var btn_sector2: Button = null
var btn_sector3: Button = null
var btn_sector4: Button = null
var btn_back: Button = null

var btn_toggle_door: Button = null
var btn_bake: Button = null
var btn_alert_enemy: Button = null
var btn_toggle_acoustics: Button = null
var btn_toggle_monitor: Button = null

var lbl_sector: Label = null
var lbl_surface: Label = null
var lbl_tension: Label = null
var lbl_generator: Label = null
var lbl_bake_stats: Label = null
var lbl_voices: Label = null

# ─── INITIALIZATION ───────────────────────────────────────────────────────────

func _ready() -> void:
	_init_scene_references()
	_connect_ui()
	if acoustic_bake:
		acoustic_bake.bake_geometry()
	teleport_to_sector(1)

func _init_scene_references() -> void:
	if player == null: player = get_node_or_null("Player_Rig")
	if player_anim_sync == null: player_anim_sync = get_node_or_null("Player_Rig/AnimationSync")
	if enemy_rig == null: enemy_rig = get_node_or_null("Characters/Elite_Enemy")
	if enemy_anim_sync == null: enemy_anim_sync = get_node_or_null("Characters/Elite_Enemy/EnemyAnimationSync")

	if acoustic_bake == null: acoustic_bake = get_node_or_null("Acoustic_Processor")
	if room_cavern == null: room_cavern = get_node_or_null("Environment/Outer_Cavern")
	if room_bunker == null: room_bunker = get_node_or_null("Environment/Bunker_Complex/Generator_Room")
	if access_portal == null: access_portal = get_node_or_null("Environment/Bunker_Complex/Access_Portal")
	if blast_door_mesh == null: blast_door_mesh = get_node_or_null("Environment/Bunker_Complex/Access_Portal/Blast_Door")

	if toxic_area == null: toxic_area = get_node_or_null("Environment/Toxic_Zone")
	if river_spline == null: river_spline = get_node_or_null("Environment/Outer_Cavern/Underground_River")
	if spore_granular == null: spore_granular = get_node_or_null("Environment/Toxic_Zone/Toxic_Spores")
	if generator_multi == null: generator_multi = get_node_or_null("Environment/Bunker_Complex/Generator_Room/Main_Generator")
	if cavern_reflector == null: cavern_reflector = get_node_or_null("Environment/Outer_Cavern/Cavern_Reflector")

	if music_player == null: music_player = get_node_or_null("Systems/Dynamic_Soundtrack")
	if acoustic_debugger == null: acoustic_debugger = get_node_or_null("Systems/Acoustic_Debugger")
	if audible_monitor == null: audible_monitor = get_node_or_null("TacticalHUD/AudibleMonitor")

	if btn_sector1 == null: btn_sector1 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
	if btn_sector2 == null: btn_sector2 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
	if btn_sector3 == null: btn_sector3 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
	if btn_sector4 == null: btn_sector4 = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
	if btn_back == null: btn_back = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")

	if btn_toggle_door == null: btn_toggle_door = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleDoor")
	if btn_bake == null: btn_bake = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnBake")
	if btn_alert_enemy == null: btn_alert_enemy = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnAlertEnemy")
	if btn_toggle_acoustics == null: btn_toggle_acoustics = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAcoustics")
	if btn_toggle_monitor == null: btn_toggle_monitor = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleMonitor")

	if lbl_sector == null: lbl_sector = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSector")
	if lbl_surface == null: lbl_surface = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSurface")
	if lbl_tension == null: lbl_tension = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblTension")
	if lbl_generator == null: lbl_generator = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblGenerator")
	if lbl_bake_stats == null: lbl_bake_stats = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblBakeStats")
	if lbl_voices == null: lbl_voices = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblVoices")

func _connect_ui() -> void:
	if btn_sector1:
		btn_sector1.pressed.connect(func(): teleport_to_sector(1))
	if btn_sector2:
		btn_sector2.pressed.connect(func(): teleport_to_sector(2))
	if btn_sector3:
		btn_sector3.pressed.connect(func(): teleport_to_sector(3))
	if btn_sector4:
		btn_sector4.pressed.connect(func(): teleport_to_sector(4))
	if btn_back:
		btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn"))

	if btn_toggle_door:
		btn_toggle_door.pressed.connect(toggle_blast_door)
	if btn_bake:
		btn_bake.pressed.connect(_on_bake_pressed)
	if btn_alert_enemy:
		btn_alert_enemy.pressed.connect(trigger_enemy_alert)
	if btn_toggle_acoustics:
		btn_toggle_acoustics.pressed.connect(_on_toggle_acoustics_pressed)
	if btn_toggle_monitor:
		btn_toggle_monitor.pressed.connect(_on_toggle_monitor_pressed)

# ─── RUNTIME PROCESS ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	_update_player_locomotion()
	_update_telemetry()

func _update_player_locomotion() -> void:
	if player == null:
		return

	var p_pos = player.global_position if player.is_inside_tree() else player.position
	
	# Determine acoustic surface by room or position
	if p_pos.x >= 50.0:
		active_surface = &"Metal" # Inside Bunker
	else:
		active_surface = &"Stone" # In Cavern

	# Update Toxic Corridor Tension (Sector 2: x in [20, 40])
	if p_pos.x >= 20.0 and p_pos.x <= 40.0:
		toxic_tension_value = clampf((p_pos.x - 20.0) / 20.0, 0.0, 1.0)
	else:
		toxic_tension_value = 0.0

func _update_telemetry() -> void:
	var p_pos = player.global_position if (player and player.is_inside_tree()) else Vector3.ZERO
	if lbl_sector:
		lbl_sector.text = "Sector: %d / 4 (%s)" % [active_sector_idx, _get_sector_name(active_sector_idx)]
	if lbl_surface:
		lbl_surface.text = "Floor Surface: %s (Auto-Detected)" % str(active_surface)
	if lbl_tension:
		lbl_tension.text = "Toxic Tension RTPC: %.2f (%s)" % [
			toxic_tension_value,
			"Snapshot Active" if toxic_tension_value > 0.5 else "Normal"
		]
	if lbl_generator and generator_multi:
		var nearest = generator_multi.get_closest_point_to(p_pos)
		lbl_generator.text = "Generator Active Vertex: %s (Dist: %.1fm)" % [
			str(nearest),
			p_pos.distance_to(nearest)
		]
	if lbl_bake_stats and acoustic_bake:
		lbl_bake_stats.text = "Baked Triangles: %d | AABBs: %d" % [
			acoustic_bake.get_baked_triangle_count(),
			acoustic_bake.get_baked_aabbs().size()
		]
	if lbl_voices:
		var enc = "Exterior Cavern (Stone RT60: 9.6s)"
		if p_pos.x >= 50.0:
			enc = "Bunker Generator Core (Metal RT60: 7.1s)"
		elif p_pos.x >= 20.0:
			enc = "Toxic Tunnel (Concrete RT60: 4.5s | Spores Active)"
		lbl_voices.text = "Acoustic Enclosure: %s" % enc

func _get_sector_name(idx: int) -> String:
	match idx:
		1: return "Outer Cavern & Spline River"
		2: return "Toxic Spore Corridor"
		3: return "Bunker Complex & Main Generator"
		4: return "Elite Enemy Overlook"
		_: return "Unknown"

# ─── INTERACTIVE ACTIONS ──────────────────────────────────────────────────────

func teleport_to_sector(idx: int) -> void:
	if SECTOR_POSITIONS.has(idx):
		active_sector_idx = idx
		if player:
			if player.is_inside_tree():
				player.global_position = SECTOR_POSITIONS[idx]
			else:
				player.position = SECTOR_POSITIONS[idx]

func toggle_blast_door() -> void:
	is_blast_door_open = not is_blast_door_open
	if blast_door_mesh:
		blast_door_mesh.visible = not is_blast_door_open
	if access_portal:
		access_portal.set_open_factor(1.0 if is_blast_door_open else 0.0)
	if btn_toggle_door:
		btn_toggle_door.text = "🚪 Door: OPEN (Diffracting)" if is_blast_door_open else "🚪 Door: CLOSED (Isolated 300Hz)"

func trigger_enemy_alert() -> void:
	if enemy_anim_sync:
		enemy_anim_sync.play_audio_event(&"Enemy_Alert_Shout")
	if enemy_rig and enemy_rig.has_node("VoiceEmitter"):
		var emitter = enemy_rig.get_node("VoiceEmitter")
		if emitter.has_method("play_event"):
			emitter.call("play_event", &"Enemy_Alert_Shout")

func _on_bake_pressed() -> void:
	if acoustic_bake:
		acoustic_bake.bake_geometry()

func _on_toggle_acoustics_pressed() -> void:
	if acoustic_debugger:
		debugger_mode = (debugger_mode + 1) % 3
		is_debugger_active = (debugger_mode > 0)
		acoustic_debugger.set("visible", is_debugger_active)
		acoustic_debugger.set("display_mode", debugger_mode)
		if btn_toggle_acoustics:
			match debugger_mode:
				0: btn_toggle_acoustics.text = "Acoustics: OFF"
				1: btn_toggle_acoustics.text = "Acoustics: RAYS"
				2: btn_toggle_acoustics.text = "Acoustics: BUBBLES"

func _on_toggle_monitor_pressed() -> void:
	if audible_monitor:
		var cur_vis = bool(audible_monitor.get("visible"))
		audible_monitor.set("visible", not cur_vis)
