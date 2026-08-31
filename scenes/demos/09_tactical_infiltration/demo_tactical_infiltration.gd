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

@onready var player: CharacterBody3D = get_node_or_null("Player_Rig")
@onready var player_anim_sync: OpenDouAnimationSync = get_node_or_null("Player_Rig/AnimationSync")
@onready var enemy_rig: CharacterBody3D = get_node_or_null("Characters/Elite_Enemy")
@onready var enemy_anim_sync: OpenDouAnimationSync = get_node_or_null("Characters/Elite_Enemy/EnemyAnimationSync")

@onready var acoustic_bake: OpenDouAcousticGeometryBake = get_node_or_null("Acoustic_Processor")
@onready var room_cavern: OpenDouRoom3D = get_node_or_null("Environment/Outer_Cavern")
@onready var room_bunker: OpenDouRoom3D = get_node_or_null("Environment/Bunker_Complex/Generator_Room")
@onready var access_portal: OpenDouPortal3D = get_node_or_null("Environment/Bunker_Complex/Access_Portal")
@onready var blast_door_mesh: Node3D = get_node_or_null("Environment/Bunker_Complex/Access_Portal/Blast_Door")

@onready var toxic_area: OpenDouParameterArea3D = get_node_or_null("Environment/Toxic_Zone")
@onready var river_spline: AudioStreamPlayer3D = get_node_or_null("Environment/Outer_Cavern/Underground_River")
@onready var spore_granular: AudioStreamPlayer3D = get_node_or_null("Environment/Toxic_Zone/Toxic_Spores")
@onready var generator_multi: OpenDouMultiPositionEmitter3D = get_node_or_null("Environment/Bunker_Complex/Generator_Room/Main_Generator")
@onready var cavern_reflector: Node3D = get_node_or_null("Environment/Outer_Cavern/Cavern_Reflector")

@onready var music_player: Node = get_node_or_null("Systems/Dynamic_Soundtrack")
@onready var acoustic_debugger: Node = get_node_or_null("Systems/Acoustic_Debugger")
@onready var audible_monitor: Node = get_node_or_null("TacticalHUD/AudibleMonitor")

# ─── UI REFERENCES ─────────────────────────────────────────────────────────────

@onready var btn_sector1: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector1")
@onready var btn_sector2: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector2")
@onready var btn_sector3: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector3")
@onready var btn_sector4: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnSector4")
@onready var btn_back: Button = get_node_or_null("TacticalHUD/TopBar/Margin/HBox/BtnBack")

@onready var btn_toggle_door: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleDoor")
@onready var btn_bake: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnBake")
@onready var btn_alert_enemy: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnAlertEnemy")
@onready var btn_toggle_acoustics: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAcoustics")
@onready var btn_toggle_monitor: Button = get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleMonitor")

@onready var lbl_sector: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSector")
@onready var lbl_surface: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSurface")
@onready var lbl_tension: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblTension")
@onready var lbl_generator: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblGenerator")
@onready var lbl_bake_stats: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblBakeStats")
@onready var lbl_voices: Label = get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblVoices")

# ─── INITIALIZATION ───────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_ui()
	if acoustic_bake:
		acoustic_bake.bake_geometry()
	teleport_to_sector(1)

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
		var p_pos = player.global_position if (player and player.is_inside_tree()) else Vector3.ZERO
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
		lbl_voices.text = "FPS: %d | Spatial Pipeline: Active" % int(Engine.get_frames_per_second())

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
		btn_toggle_door.text = "Door: OPEN" if is_blast_door_open else "Door: CLOSED"

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
