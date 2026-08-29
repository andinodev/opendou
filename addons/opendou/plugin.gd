@tool
extends EditorPlugin

## OpenDou Audio Middleware Editor Plugin for Godot 4.7+
## Provides Main Screen workspace, bottom dock, and real-time audio logic authoring.

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")
const AUTOLOAD_NAME = "OpenDou"
const AUTOLOAD_PATH = "res://addons/opendou/runtime/audio_event_manager.gd"

var studio_instance: Control

func _enter_tree() -> void:
	# 1. Register Runtime Autoload Singleton
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		
	# 2. Instantiate Studio Main Workspace
	studio_instance = OpenDouStudioMainClass.new()
	
	# 3. Add to bottom panel dock
	add_control_to_bottom_panel(studio_instance, "Audio Logic")

func _exit_tree() -> void:
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
	if studio_instance:
		studio_instance.visible = visible

func _get_plugin_name() -> String:
	return "OpenDou"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("AudioStreamPlayer", "EditorIcons")
