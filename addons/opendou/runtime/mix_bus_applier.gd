class_name OpenDouMixBusApplier
extends RefCounted

## Escribe cada frame en el AudioServer el resultado de la mezcla dinamica:
##
##     volumen(bus) = base(bus) + delta_instantanea(bus) + ducking(bus)
##
## La base es el volumen que el proyecto o el jugador dejaron en el bus (el menu de pausa la
## edita). Hasta la Fase 8, las instantaneas y el ducking se calculaban y NADIE los aplicaba.
## Solo toca los buses GESTIONADOS: los que nombra alguna instantanea registrada o alguna
## regla de ducking. Asi dos managers (el autoload y uno de test) no se pisan.

const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")
const MARK_LPF: String = "OpenDou_Mix_LPF"
const MARK_HPF: String = "OpenDou_Mix_HPF"

var snapshots: AudioMixSnapshotManager = null
var ducking: AudioDuckingMatrix = null
var writes_last_frame: int = 0

var _base_db: Dictionary = {}     # StringName -> float
var _base_mute: Dictionary = {}   # StringName -> bool
var _warned: Dictionary = {}

func _init() -> void:
	snapshots = AudioMixSnapshotManagerClass.new()
	ducking = AudioDuckingMatrixClass.new()

## Buses que este aplicador gobierna y que existen en el servidor.
func managed_buses() -> Array[StringName]:
	var names: Dictionary = {}
	for snap_name in snapshots.registered_snapshots:
		for bus in snapshots.registered_snapshots[snap_name].bus_settings:
			names[StringName(bus)] = true
	for rule in ducking.rules:
		names[rule.target_bus] = true
	var out: Array[StringName] = []
	for bus in names:
		if AudioServer.get_bus_index(String(bus)) >= 0:
			out.append(bus)
		elif not _warned.has(bus):
			_warned[bus] = true
			push_warning("[OpenDou] la mezcla nombra el bus '%s', que no existe en el AudioServer: se ignora" % String(bus))
	return out

func set_bus_base_volume_db(bus: StringName, db: float) -> void:
	_base_db[bus] = db

func get_bus_base_volume_db(bus: StringName) -> float:
	_ensure_base(bus)
	return float(_base_db[bus])

func set_bus_base_mute(bus: StringName, muted: bool) -> void:
	_base_mute[bus] = muted

## Volumen que el aplicador quiere para el bus ahora mismo.
func effective_volume_db(bus: StringName) -> float:
	_ensure_base(bus)
	var state: Dictionary = snapshots.get_bus_state(bus)
	return float(_base_db[bus]) + float(state.get("volume_db", 0.0)) + ducking.get_ducking_attenuation_db(bus)

func apply(delta: float) -> void:
	snapshots.update(delta)
	ducking.update(delta)
	writes_last_frame = 0
	for bus in managed_buses():
		var idx: int = AudioServer.get_bus_index(String(bus))
		var state: Dictionary = snapshots.get_bus_state(bus)
		var target: float = effective_volume_db(bus)
		if absf(AudioServer.get_bus_volume_db(idx) - target) > 0.01:
			AudioServer.set_bus_volume_db(idx, target)
			writes_last_frame += 1
		var muted: bool = bool(_base_mute.get(bus, false)) or bool(state.get("mute", false))
		if AudioServer.is_bus_mute(idx) != muted:
			AudioServer.set_bus_mute(idx, muted)
			writes_last_frame += 1
		_apply_filter(idx, MARK_LPF, float(state.get("lpf_hz", 20000.0)), 20000.0, true)
		_apply_filter(idx, MARK_HPF, float(state.get("hpf_hz", 20.0)), 20.0, false)

func _ensure_base(bus: StringName) -> void:
	if not _base_db.has(bus):
		var idx: int = AudioServer.get_bus_index(String(bus))
		_base_db[bus] = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
		_base_mute[bus] = AudioServer.is_bus_mute(idx) if idx >= 0 else false

## Filtro marcado bajo demanda: se crea la primera vez que hace falta, se deshabilita (no se
## quita) cuando el corte vuelve al neutro, y solo se escribe si cambio.
func _apply_filter(bus_idx: int, mark: String, hz: float, neutral_hz: float, lowpass: bool) -> void:
	var neutral: bool = absf(hz - neutral_hz) < 1.0
	var pos: int = -1
	for e in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx := AudioServer.get_bus_effect(bus_idx, e)
		if fx != null and fx.resource_name == mark:
			pos = e
	if pos < 0:
		if neutral:
			return
		var created: AudioEffectFilter = AudioEffectLowPassFilter.new() if lowpass else AudioEffectHighPassFilter.new()
		created.resource_name = mark
		created.cutoff_hz = hz
		AudioServer.add_bus_effect(bus_idx, created)
		writes_last_frame += 1
		return
	var existing: AudioEffectFilter = AudioServer.get_bus_effect(bus_idx, pos)
	if AudioServer.is_bus_effect_enabled(bus_idx, pos) == neutral:
		AudioServer.set_bus_effect_enabled(bus_idx, pos, not neutral)
		writes_last_frame += 1
	if not neutral and absf(existing.cutoff_hz - hz) > 1.0:
		existing.cutoff_hz = hz
		writes_last_frame += 1
