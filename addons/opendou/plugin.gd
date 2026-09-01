@tool
extends EditorPlugin

## OpenDou Audio Middleware Editor Plugin for Godot 4.7+
## Provides a bottom-panel Studio with a detachable window, 3D gizmos for the spatial
## nodes, an inspector tool for acoustic geometry baking, and the runtime autoload.

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")
const AUTOLOAD_NAME = "OpenDou"
const AUTOLOAD_PATH = "res://addons/opendou/runtime/audio_event_manager.gd"

const OpenDouAcousticGeometryBakeInspectorPluginClass = preload("res://addons/opendou/editor/opendou_acoustic_geometry_bake_inspector.gd")
const OpenDouGizmoPlugin3DClass = preload("res://addons/opendou/editor/gizmos/opendou_gizmo_plugin_3d.gd")
const OpenDouAnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")


var studio_instance: Control
var dock_button: Button
var gizmo_plugin_instance: OpenDouGizmoPlugin3D
var bake_inspector_instance: OpenDouAcousticGeometryBakeInspectorPlugin

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

	# Los nodos declarativos NO se registran con add_custom_type: cada uno ya tiene
	# class_name y @icon, y ProjectSettings.get_global_class_list() los devuelve con
	# su icono resuelto, asi que el dialogo "Crear nodo" los muestra igual.
	#
	# Registrarlos por las dos vias duplicaba sus entradas en ese dialogo, y los
	# nodos anadidos por add_custom_type pierden su tipo al guardar la escena: se
	# serializan como tipo base mas script.

	# 5. Register Spatial 3D Gizmos & Inspector Tools
	gizmo_plugin_instance = OpenDouGizmoPlugin3DClass.new()
	add_node_3d_gizmo_plugin(gizmo_plugin_instance)

	bake_inspector_instance = OpenDouAcousticGeometryBakeInspectorPluginClass.new()
	add_inspector_plugin(bake_inspector_instance)

func _on_dock_button_pressed() -> void:
	if studio_instance:
		studio_instance.detach_and_maximize()
		hide_bottom_panel()

func _exit_tree() -> void:
	# Remove Spatial 3D Gizmos & Inspector Tools
	if gizmo_plugin_instance:
		remove_node_3d_gizmo_plugin(gizmo_plugin_instance)
		gizmo_plugin_instance = null
	if bake_inspector_instance:
		remove_inspector_plugin(bake_inspector_instance)
		bake_inspector_instance = null


	# Remove bottom panel dock
	if studio_instance:
		remove_control_from_bottom_panel(studio_instance)
		studio_instance.queue_free()
		studio_instance = null
		
	# Remove Autoload Singleton
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

## El Studio vive en el panel inferior con su ventana desacoplable, no en el
## contenedor de main screen.
##
## Devolvia true sin anadir nada a ese contenedor, asi que pulsar la pestana
## "OpenDou" del editor dejaba la pantalla vacia y abria la ventana flotante.
func _has_main_screen() -> bool:
	return false

func _make_visible(visible: bool) -> void:
	if visible and studio_instance:
		studio_instance.detach_and_maximize()
		hide_bottom_panel()

func _get_plugin_name() -> String:
	return "OpenDou"

func _get_plugin_icon() -> Texture2D:
	# EditorInterface es un singleton desde Godot 4.2; el accesor del EditorPlugin
	# esta deprecado desde entonces.
	return EditorInterface.get_base_control().get_theme_icon("AudioStreamPlayer", "EditorIcons")
