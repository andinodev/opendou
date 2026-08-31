@tool
extends EditorPlugin

## OpenDou Audio Middleware Editor Plugin for Godot 4.7+
## Provides Main Screen workspace, bottom dock, and real-time audio logic authoring.

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")
const AUTOLOAD_NAME = "OpenDou"
const AUTOLOAD_PATH = "res://addons/opendou/runtime/audio_event_manager.gd"

# Declarative Node Classes
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const OpenDouEventPlayer2DClass = preload("res://addons/opendou/nodes/opendou_event_player_2d.gd")
const OpenDouEventPlayerClass = preload("res://addons/opendou/nodes/opendou_event_player.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const OpenDouPortal3DClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")
const OpenDouReflector3DClass = preload("res://addons/opendou/nodes/opendou_reflector_3d.gd")
const OpenDouMusicPlayerClass = preload("res://addons/opendou/nodes/opendou_music_player.gd")
const OpenDouAudibleMonitorClass = preload("res://addons/opendou/nodes/opendou_audible_monitor.gd")
const OpenDouAcousticDebugger3DClass = preload("res://addons/opendou/nodes/opendou_acoustic_debugger_3d.gd")
const OpenDouSplineEmitter3DClass = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
const OpenDouGranularEmitter3DClass = preload("res://addons/opendou/nodes/opendou_granular_emitter_3d.gd")
const OpenDouParameterArea3DClass = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
const OpenDouMultiPositionEmitter3DClass = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")

# Declarative Node Icons
const IconEventPlayer3D = preload("res://addons/opendou/icons/icon_event_player_3d.svg")
const IconEventPlayer2D = preload("res://addons/opendou/icons/icon_event_player_2d.svg")
const IconEventPlayer = preload("res://addons/opendou/icons/icon_event_player.svg")
const IconRoom3D = preload("res://addons/opendou/icons/icon_room.svg")
const IconPortal3D = preload("res://addons/opendou/icons/icon_portal.svg")
const IconReflector3D = preload("res://addons/opendou/icons/icon_reflector_3d.svg")
const IconMusicPlayer = preload("res://addons/opendou/icons/icon_music_player.svg")
const IconAudibleMonitor = preload("res://addons/opendou/icons/icon_audible_monitor.svg")
const IconAcousticDebugger = preload("res://addons/opendou/icons/icon_acoustic_debugger.svg")
const IconSplineEmitter3D = preload("res://addons/opendou/icons/icon_spline_emitter_3d.svg")
const IconGranularEmitter = preload("res://addons/opendou/icons/icon_granular_emitter.svg")
const IconParameterArea3D = preload("res://addons/opendou/icons/icon_parameter_area_3d.svg")
const IconMultiPositionEmitter3D = preload("res://addons/opendou/icons/icon_multi_position_emitter_3d.svg")

var studio_instance: Control
var dock_button: Button

func _enter_tree() -> void:
	# 1. Register Runtime Autoload Singleton
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		
	# 2. Instantiate Studio Main Workspace
	studio_instance = OpenDouStudioMainClass.new()
	
	# 3. Add to bottom panel dock
	dock_button = add_control_to_bottom_panel(studio_instance, "Audio Logic")
	if dock_button:
		dock_button.pressed.connect(_on_dock_button_pressed)

	# 4. Register Declarative Audio Custom Types
	add_custom_type("OpenDouEventPlayer3D", "AudioStreamPlayer3D", OpenDouEventPlayer3DClass, IconEventPlayer3D)
	add_custom_type("OpenDouEventPlayer2D", "AudioStreamPlayer2D", OpenDouEventPlayer2DClass, IconEventPlayer2D)
	add_custom_type("OpenDouEventPlayer", "AudioStreamPlayer", OpenDouEventPlayerClass, IconEventPlayer)
	add_custom_type("OpenDouRoom3D", "Area3D", OpenDouRoom3DClass, IconRoom3D)
	add_custom_type("OpenDouPortal3D", "Node3D", OpenDouPortal3DClass, IconPortal3D)
	add_custom_type("OpenDouReflector3D", "Node3D", OpenDouReflector3DClass, IconReflector3D)
	add_custom_type("OpenDouMusicPlayer", "Node", OpenDouMusicPlayerClass, IconMusicPlayer)
	add_custom_type("OpenDouAudibleMonitor", "CanvasLayer", OpenDouAudibleMonitorClass, IconAudibleMonitor)
	add_custom_type("OpenDouAcousticDebugger3D", "Node3D", OpenDouAcousticDebugger3DClass, IconAcousticDebugger)
	add_custom_type("OpenDouSplineEmitter3D", "AudioStreamPlayer3D", OpenDouSplineEmitter3DClass, IconSplineEmitter3D)
	add_custom_type("OpenDouGranularEmitter3D", "AudioStreamPlayer3D", OpenDouGranularEmitter3DClass, IconGranularEmitter)
	add_custom_type("OpenDouParameterArea3D", "Area3D", OpenDouParameterArea3DClass, IconParameterArea3D)
	add_custom_type("OpenDouMultiPositionEmitter3D", "AudioStreamPlayer3D", OpenDouMultiPositionEmitter3DClass, IconMultiPositionEmitter3D)

func _on_dock_button_pressed() -> void:
	if studio_instance:
		studio_instance.detach_and_maximize()
		hide_bottom_panel()

func _exit_tree() -> void:
	# Remove Declarative Audio Custom Types
	remove_custom_type("OpenDouEventPlayer3D")
	remove_custom_type("OpenDouEventPlayer2D")
	remove_custom_type("OpenDouEventPlayer")
	remove_custom_type("OpenDouRoom3D")
	remove_custom_type("OpenDouPortal3D")
	remove_custom_type("OpenDouReflector3D")
	remove_custom_type("OpenDouMusicPlayer")
	remove_custom_type("OpenDouAudibleMonitor")
	remove_custom_type("OpenDouAcousticDebugger3D")
	remove_custom_type("OpenDouSplineEmitter3D")
	remove_custom_type("OpenDouGranularEmitter3D")
	remove_custom_type("OpenDouParameterArea3D")
	remove_custom_type("OpenDouMultiPositionEmitter3D")

	# Remove bottom panel dock
	if studio_instance:
		remove_control_from_bottom_panel(studio_instance)
		studio_instance.queue_free()
		studio_instance = null
		
	# Remove Autoload Singleton
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if visible and studio_instance:
		studio_instance.detach_and_maximize()
		hide_bottom_panel()

func _get_plugin_name() -> String:
	return "OpenDou"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("AudioStreamPlayer", "EditorIcons")
