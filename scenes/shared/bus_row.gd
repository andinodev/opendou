class_name BusRow
extends HBoxContainer

## Una fila de la pantalla de sonido: un bus del AudioServer con su medidor, su volumen
## y su silencio. La ESTRUCTURA vive en bus_row.tscn; aqui solo el enlace con el servidor.

@export var bus_name: String = "Master"

@onready var _name: Label = $Name
@onready var _meter: ProgressBar = $Meter
@onready var _volume: HSlider = $Volume
@onready var _db: Label = $Db
@onready var _mute: CheckBox = $Mute

var _bus_index: int = -1

func _ready() -> void:
	_bus_index = AudioServer.get_bus_index(bus_name)
	_name.text = bus_name
	if _bus_index < 0:
		_volume.editable = false
		_mute.disabled = true
		_db.text = "—"
		return
	# Con manager, el deslizador edita la BASE del bus: la instantanea activa y el ducking se
	# suman encima y no pelean con el jugador (Fase 8).
	var m: Node = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("get_bus_base_volume_db"):
		_volume.set_value_no_signal(m.get_bus_base_volume_db(StringName(bus_name)))
	else:
		_volume.set_value_no_signal(AudioServer.get_bus_volume_db(_bus_index))
	_mute.set_pressed_no_signal(AudioServer.is_bus_mute(_bus_index))
	_db.text = "%+.1f dB" % _volume.value
	_volume.value_changed.connect(_on_volume_changed)
	_mute.toggled.connect(_on_mute_toggled)

## El medidor sigue al pico real del bus, sin efectos de captura: lo da el servidor.
func _process(_delta: float) -> void:
	if _bus_index < 0 or _bus_index >= AudioServer.bus_count:
		return
	var peak: float = maxf(
		AudioServer.get_bus_peak_volume_left_db(_bus_index, 0),
		AudioServer.get_bus_peak_volume_right_db(_bus_index, 0))
	# Caida suave para que el medidor no parpadee: sube al instante, baja despacio.
	_meter.value = maxf(peak, _meter.value - 40.0 * _delta_or(0.016))

func _delta_or(fallback: float) -> float:
	var d: float = get_process_delta_time()
	return d if d > 0.0 else fallback

func _on_volume_changed(value: float) -> void:
	var m: Node = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("set_bus_base_volume_db"):
		m.set_bus_base_volume_db(StringName(bus_name), value)
	# Se escribe tambien en el servidor: un bus que ninguna instantanea nombra no lo toca el
	# aplicador, y si lo gestiona, lo reescribira al mismo valor.
	if _bus_index >= 0:
		AudioServer.set_bus_volume_db(_bus_index, value)
	_db.text = "%+.1f dB" % value

func _on_mute_toggled(pressed: bool) -> void:
	var m: Node = get_node_or_null("/root/OpenDou")
	if m != null and "mix" in m and m.mix != null:
		m.mix.set_bus_base_mute(StringName(bus_name), pressed)
	if _bus_index >= 0:
		AudioServer.set_bus_mute(_bus_index, pressed)
