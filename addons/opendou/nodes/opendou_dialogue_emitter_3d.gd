@tool
class_name OpenDouDialogueEmitter3D
extends Node3D

## Emisor de dialogo (Fase 11): una linea por idioma desde una AudioDialogueTable, subtitulo,
## ducking absoluto sobre un bus, boca por la envolvente del WAV y visemas AUTORADOS por
## marcadores (nombre "viseme:X"). Godot no trae fonemas: aqui no hay visemas automaticos.

signal line_started(key: StringName)
signal line_finished(key: StringName)
signal subtitle_changed(text: String)
signal viseme_changed(viseme: StringName)

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")
const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")

@export var dialogue_table: AudioDialogueTable = null
## Idioma de la linea. Vacio = "en".
@export var language: String = "en"
@export var fallback_language: String = "en"
## key -> {lang -> texto}. La tabla de dialogo solo guarda streams.
@export var subtitles: Dictionary = {}
@export var bus_category: StringName = &"Voice"
@export_group("Ducking")
@export var duck_bus: StringName = &"Music"
@export_range(-60.0, 0.0, 0.5) var duck_db: float = -12.0
@export_range(0.0, 2.0, 0.01) var duck_attack_sec: float = 0.05
@export_range(0.0, 5.0, 0.01) var duck_release_sec: float = 0.4
@export_group("Boca y visemas")
@export_range(2, 100, 1) var mouth_window_ms: int = 10
## Visemas autorados: marcadores con nombre "viseme:<nombre>".
@export var markers: Array[AudioMarker] = []

## Boca abierta, 0..1, desde la envolvente del WAV en el reloj logico de la voz.
var mouth_amplitude: float = 0.0
var current_viseme: StringName = &""

var _manager: Node = null
var _instance = null
var _key: StringName = &""
var _envelope: PackedFloat32Array = PackedFloat32Array()
var _warned_no_wav: bool = false

func set_event_manager(manager: Node) -> void:
	_manager = manager

func _find_manager():
	if _manager != null and is_instance_valid(_manager):
		return _manager
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func is_speaking() -> bool:
	return _instance != null and _instance.is_playing()

## Envolvente RMS por ventana, normalizada al pico. Vacia si el stream no es un WAV.
static func envelope_of(stream: AudioStream, window_ms: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not (stream is AudioStreamWAV):
		return out
	var samples: PackedFloat32Array = WavDecoderClass.to_mono_floats(stream)
	var win: int = maxi(1, int(float(stream.mix_rate) * float(window_ms) / 1000.0))
	var peak: float = 0.0
	var i: int = 0
	while i < samples.size():
		var acc: float = 0.0
		var n: int = mini(win, samples.size() - i)
		for k in range(n):
			acc += samples[i + k] * samples[i + k]
		var rms: float = sqrt(acc / float(n))
		out.append(rms)
		peak = maxf(peak, rms)
		i += win
	if peak > 0.0:
		for k in range(out.size()):
			out[k] /= peak
	return out

func speak(key: StringName) -> EventInstance:
	var manager = _find_manager()
	if manager == null or dialogue_table == null:
		return null
	var lang: String = language if not language.is_empty() else "en"
	var stream = dialogue_table.get_stream(key, lang, fallback_language)
	if not (stream is AudioStream):
		push_warning("[OpenDou] %s: la clave %s no tiene stream en %s" % [name, key, lang])
		return null
	stop_speaking(0.0)
	_key = key
	var def = AudioEventDefClass.new(StringName("Dialogue_%s" % key), stream)
	def.target_bus = bus_category
	def.is_looping = false
	def.stream_length = float(stream.get_length())
	for mk in markers:
		def.markers.append(mk)
	_envelope = envelope_of(stream, mouth_window_ms)
	if _envelope.is_empty() and not _warned_no_wav:
		_warned_no_wav = true
		push_warning("[OpenDou] %s: el stream no es un WAV, la boca queda en 0" % name)
	_instance = manager.post_event(def, self)
	if _instance == null:
		return null
	_instance.set_position(global_position if is_inside_tree() else position)
	_instance.marker_reached.connect(_on_marker)
	_apply_ducking(manager, true)
	current_viseme = &""
	line_started.emit(key)
	var text: String = ""
	if subtitles.has(key):
		var by_lang: Dictionary = subtitles[key]
		text = str(by_lang.get(lang, by_lang.get(fallback_language, "")))
	subtitle_changed.emit(text)
	return _instance

func stop_speaking(fade_sec: float = 0.05) -> void:
	if _instance != null:
		if _instance.is_playing():
			_instance.stop(fade_sec)
		_finish()

func _on_marker(marker_name: StringName) -> void:
	var s: String = String(marker_name)
	if s.begins_with("viseme:"):
		current_viseme = StringName(s.substr(7))
		viseme_changed.emit(current_viseme)

## Ducking absoluto: la linea fija cuanto baja el bus. Una regla por par, actualizada.
func _apply_ducking(manager, on: bool) -> void:
	if manager == null or manager.mix == null or manager.mix.ducking == null or duck_bus.is_empty():
		return
	var d = manager.mix.ducking
	if on:
		var found: bool = false
		for r in d.rules:
			if r.source_bus == bus_category and r.target_bus == duck_bus:
				r.attenuation_db = duck_db
				r.attack_time_sec = duck_attack_sec
				r.release_time_sec = duck_release_sec
				found = true
		if not found:
			d.add_rule(bus_category, duck_bus, duck_db, duck_attack_sec, duck_release_sec)
	d.set_bus_active(bus_category, on)

func _finish() -> void:
	_apply_ducking(_find_manager(), false)
	if _instance != null and _instance.marker_reached.is_connected(_on_marker):
		_instance.marker_reached.disconnect(_on_marker)
	_instance = null
	mouth_amplitude = 0.0
	current_viseme = &""
	line_finished.emit(_key)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _instance == null:
		return
	if not _instance.is_playing():
		_finish()
		return
	if is_inside_tree():
		_instance.set_position(global_position)
	if _envelope.is_empty():
		mouth_amplitude = 0.0
		return
	var idx: int = int(_instance.logical_playback_position * 1000.0 / float(mouth_window_ms))
	mouth_amplitude = _envelope[clampi(idx, 0, _envelope.size() - 1)]

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		stop_speaking(0.0)
