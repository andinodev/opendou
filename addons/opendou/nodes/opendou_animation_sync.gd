@icon("res://addons/opendou/icons/icon_animation_sync.svg")
@tool
class_name OpenDouAnimationSync
extends Node

## Declarative Animation-Audio Synchronization Bridge for OpenDou.
## Binds AnimationPlayer / AnimationTree method tracks, timeline markers,
## surface-aware footstep dispatches, and continuous BlendSpace RTPC modulations.

const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")

# ==============================================================================
# EXPORTED CONFIGURATION
# ==============================================================================

@export_group("Target Connections")
@export_node_path("AnimationPlayer") var animation_player_path: NodePath
@export_node_path("AnimationTree") var animation_tree_path: NodePath
@export_node_path("Node") var target_emitter_path: NodePath

@export_group("Footsteps & Surface Detection")
@export var auto_detect_surface: bool = true
@export var default_footstep_event: StringName = &"Footstep"

@export_group("Declarative Timeline Bindings")
## Dictionary mapping AnimationName -> Array[Dictionary] (e.g. {"Run": [{"time": 0.25, "event": &"Footstep_Run"}]})
@export var event_bindings: Dictionary = {}

@export_group("BlendSpace RTPC Synchronization")
@export var blend_space_sync_enabled: bool = true
## Dictionary mapping AnimationTree property path -> RTPC Name (e.g. {"parameters/Locomotion/blend_position": &"Locomotion_Speed"})
@export var blend_space_rtpc_map: Dictionary = {}

# ==============================================================================
# RUNTIME REFERENCES
# ==============================================================================

var animation_player: AnimationPlayer = null
var animation_tree: AnimationTree = null
var target_emitter: Node = null
var _event_manager: AudioEventManager = null
var _last_animation_name: StringName = &""
var _triggered_timeline_indices: Array[int] = []

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if not Engine.is_editor_hint():
		_event_manager = _resolve_event_manager()
		_resolve_node_paths()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_process_timeline_events()
	if blend_space_sync_enabled:
		process_blend_space_rtpcs()

## El manager autoload, o null si el proyecto no lo tiene.
##
## Antes esto era AudioEventManagerClass.new(): un manager huerfano, fuera del arbol,
## con el registro vacio y cuyo _process no corre nunca. set_switch() iba ahi, asi que
## el switch container de las pisadas no veia la superficie, y spatial_acoustics no
## tenia ninguna sala registrada.
##
## Devuelve null y no una copia privada a proposito: sin manager las llamadas se quedan
## calladas -todas comprueban _event_manager != null-, que es honesto. Una copia privada
## finge estar conectada y ademas nunca se libera.
func _resolve_event_manager() -> AudioEventManager:
	if is_inside_tree():
		var root := get_tree().root
		if root != null and root.has_node("OpenDou"):
			var found = root.get_node("OpenDou")
			if found is AudioEventManager:
				return found
	return null


## Fija el manager explicitamente. Para tests y para proyectos sin el autoload.
func set_event_manager(manager: AudioEventManager) -> void:
	_event_manager = manager


## El manager con el que esta hablando ahora mismo.
func get_event_manager() -> AudioEventManager:
	return _event_manager


func _resolve_node_paths() -> void:
	if not animation_player_path.is_empty() and has_node(animation_player_path):
		var p = get_node(animation_player_path)
		if p is AnimationPlayer:
			bind_animation_player(p)

	if not animation_tree_path.is_empty() and has_node(animation_tree_path):
		var t = get_node(animation_tree_path)
		if t is AnimationTree:
			bind_animation_tree(t)

	if not target_emitter_path.is_empty() and has_node(target_emitter_path):
		bind_target_emitter(get_node(target_emitter_path))

# ==============================================================================
# NODE BINDING API
# ==============================================================================

func bind_animation_player(player: AnimationPlayer) -> void:
	animation_player = player
	if animation_player != null and not animation_player.animation_changed.is_connected(_on_animation_changed):
		animation_player.animation_changed.connect(_on_animation_changed)

func bind_animation_tree(tree: AnimationTree) -> void:
	animation_tree = tree

func bind_target_emitter(emitter: Node) -> void:
	target_emitter = emitter

func _on_animation_changed(old_anim: StringName, new_anim: StringName) -> void:
	_triggered_timeline_indices.clear()
	_last_animation_name = new_anim

# ==============================================================================
# METHOD TRACK RECEIVERS (DIRECT SLOTS FOR ANIMATIONPLAYER)
# ==============================================================================

## Direct method callback for AnimationPlayer method tracks.
func play_audio_event(event_name: StringName) -> void:
	trigger_audio_event(event_name)

## Triggers an OpenDou audio event on the target emitter or globally.
func trigger_audio_event(event_name: StringName) -> void:
	if event_name.is_empty():
		return
		
	if target_emitter != null and is_instance_valid(target_emitter):
		if target_emitter.has_method("play_event"):
			target_emitter.call("play_event", event_name)
			return
		elif target_emitter.has_method("play"):
			target_emitter.call("play")
			return

	if _event_manager != null and _event_manager.has_method("post_event"):
		# post_event(event, caller: Node): aqui se le pasaba un Vector3 como caller, lo
		# que abortaba la llamada con un error de tipo y dejaba el camino sin emisor
		# completamente mudo. La posicion va en la instancia, que es donde el motor la
		# lee.
		var instance = _event_manager.post_event(event_name, self)
		if instance != null:
			instance.set_position(_get_emitter_global_position())

## Direct method callback for footstep synchronization in animations.
func footstep(foot_index: int = 0, surface_override: StringName = &"") -> void:
	trigger_footstep(foot_index, surface_override)

## Dispatches a contextual footstep event with automated surface detection.
func trigger_footstep(foot_index: int = 0, surface_override: StringName = &"") -> void:
	var surface = surface_override
	if surface.is_empty() and auto_detect_surface:
		var pos = _get_emitter_global_position()
		if _event_manager != null and _event_manager.spatial_acoustics != null:
			# El World3D es obligatorio: la prioridad 1 de detect_surface_at es un
			# raycast hacia abajo que solo se ejecuta si se le pasa. Sin el, caia al
			# floor_surface de la sala y tres parches de material distinto en la misma
			# sala daban tres pisadas identicas.
			surface = _event_manager.spatial_acoustics.detect_surface_at(pos, _get_world_3d())
		else:
			surface = &"Concrete"

	# Set GameSync switch
	if not surface.is_empty() and _event_manager != null:
		_event_manager.set_switch(&"SurfaceType", surface)

	# Trigger footstep event
	var evt_to_play = default_footstep_event
	if not surface.is_empty():
		var contextual_evt = StringName("Footstep_%s" % str(surface))
		if _event_manager != null and _event_manager.event_registry.has(contextual_evt):
			evt_to_play = contextual_evt

	trigger_audio_event(evt_to_play)

## Direct method callback for modifying RTPCs from animation method tracks.
func set_rtpc(param_name: StringName, val: float) -> void:
	set_rtpc_from_animation(param_name, val)

func set_rtpc_from_animation(param_name: StringName, val: float) -> void:
	if param_name.is_empty():
		return
	if _event_manager != null:
		_event_manager.set_rtpc_value(param_name, val)

# ==============================================================================
# DECLARATIVE TIMELINE EVENT PROCESSOR
# ==============================================================================

func _process_timeline_events() -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		return
	if not animation_player.is_playing():
		return

	var curr_anim = StringName(animation_player.current_animation)
	if curr_anim.is_empty():
		return

	if curr_anim != _last_animation_name:
		_last_animation_name = curr_anim
		_triggered_timeline_indices.clear()

	var curr_pos = animation_player.current_animation_position
	var list = event_bindings.get(curr_anim, [])
	if list is Array:
		for i in range(list.size()):
			if _triggered_timeline_indices.has(i):
				continue
			var entry = list[i]
			if entry is Dictionary:
				var t = float(entry.get("time", 0.0))
				if curr_pos >= t:
					_triggered_timeline_indices.append(i)
					var evt = StringName(str(entry.get("event", &"")))
					trigger_audio_event(evt)

# ==============================================================================
# BLENDSPACE RTPC SYNCHRONIZATION
# ==============================================================================

## Queries AnimationTree properties and maps them to OpenDou RTPC parameters.
func process_blend_space_rtpcs() -> void:
	if animation_tree == null or not is_instance_valid(animation_tree):
		return

	for prop_path in blend_space_rtpc_map.keys():
		var rtpc_name = StringName(str(blend_space_rtpc_map[prop_path]))
		if rtpc_name.is_empty():
			continue

		var raw_val = animation_tree.get(prop_path)
		if raw_val != null:
			var float_val: float = 0.0
			if raw_val is float or raw_val is int:
				float_val = float(raw_val)
			elif raw_val is Vector2:
				float_val = (raw_val as Vector2).length()
			elif raw_val is Vector3:
				float_val = (raw_val as Vector3).length()

			set_rtpc_from_animation(rtpc_name, float_val)

# ==============================================================================
# HELPER METHODS
# ==============================================================================

## World3D del emisor, o del propio nodo si no hay emisor asignado.
func _get_world_3d() -> World3D:
	if target_emitter != null and is_instance_valid(target_emitter) and target_emitter is Node3D:
		if (target_emitter as Node3D).is_inside_tree():
			return (target_emitter as Node3D).get_world_3d()
	var parent_node = get_parent()
	if parent_node is Node3D and parent_node.is_inside_tree():
		return (parent_node as Node3D).get_world_3d()
	if is_inside_tree() and get_viewport() != null:
		return get_viewport().find_world_3d()
	return null


func _get_emitter_global_position() -> Vector3:
	if target_emitter != null and is_instance_valid(target_emitter) and target_emitter is Node3D:
		return (target_emitter as Node3D).global_position if (target_emitter as Node3D).is_inside_tree() else (target_emitter as Node3D).position
	var parent_node = get_parent()
	if parent_node is Node3D:
		return parent_node.global_position if parent_node.is_inside_tree() else parent_node.position
	return Vector3.ZERO
