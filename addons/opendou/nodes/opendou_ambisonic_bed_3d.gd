@tool
class_name OpenDouAmbisonicBed3D
extends AudioStreamPlayer

## Cama ambisonica (Fase 13): el ambiente que rodea. No tiene posicion; rota con la cabeza del
## oyente y se decodifica al HRTF activo. Sin extension nativa reproduce el canal W en mono y lo
## dice una vez.

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")

@export var audio: OpenDouAmbisonicAudio = null
@export var autoplay_bed: bool = true

var _manager: Node = null
var _native: bool = false
var _warned: bool = false

func set_event_manager(manager: Node) -> void:
	_manager = manager

func is_native() -> bool:
	return _native

func _find_manager():
	if _manager != null and is_instance_valid(_manager):
		return _manager
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	rebuild_stream()
	var m = _find_manager()
	if m != null:
		m.register_ambisonic_bed(self)
	if autoplay_bed and stream != null:
		play()

func rebuild_stream() -> void:
	if audio == null or not audio.is_valid():
		stream = null
		return
	if ClassDB.class_exists("OpenDouAmbisonicStream") and ClassDB.class_exists("OpenDouSpatialStream") and bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available")):
		var s = ClassDB.instantiate("OpenDouAmbisonicStream")
		s.audio = audio
		stream = s
		_native = true
	else:
		if not _warned:
			_warned = true
			push_warning("[OpenDou] %s: sin extension nativa la cama ambisonica suena en mono (canal W)" % name)
		stream = audio.w_as_wav()
		_native = false

## La orientacion del oyente, cada cuadro, desde el manager.
func set_listener_basis(b: Basis) -> void:
	if _native and stream != null:
		stream.listener_basis = b

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = _find_manager()
	if m != null:
		m.unregister_ambisonic_bed(self)
