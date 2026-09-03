@tool
class_name OpenDouAmbisonicAudio
extends Resource

## Cama ambisonica (Fase 13): canales ACN/SN3D de orden 1 (4) o 2 (9) como PackedFloat32Array.
## Se carga de un WAV multicanal con el lector propio o se codifica desde un mono con el
## codificador de Steam Audio (encode_point), para que codificar y decodificar compartan
## convencion.

const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

@export_range(1, 2, 1) var order: int = 1
## Canales ACN, cada uno un PackedFloat32Array de la misma longitud.
@export var channels: Array = []
@export var mix_rate: int = 44100
@export var loop: bool = true

func channel_count() -> int:
	return (order + 1) * (order + 1)

func is_valid() -> bool:
	return channels.size() >= channel_count() and channels[0].size() > 0

func length_sec() -> float:
	return float(channels[0].size()) / float(maxi(mix_rate, 1)) if is_valid() else 0.0

## Canal W como AudioStreamWAV mono de 16 bits: el fallback sin extension.
func w_as_wav() -> AudioStreamWAV:
	if not is_valid():
		return null
	var w: PackedFloat32Array = channels[0]
	var bytes := PackedByteArray()
	bytes.resize(w.size() * 2)
	for i in range(w.size()):
		bytes.encode_s16(i * 2, int(clampf(w[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = w.size() - 1
	return wav

static func from_wav_file(path: String) -> OpenDouAmbisonicAudio:
	var d: Dictionary = WavDecoderClass.read_multichannel(path)
	var chans: Array = d.get("channels", [])
	if chans.size() != 4 and chans.size() != 9:
		return null
	var a := OpenDouAmbisonicAudio.new()
	a.order = 1 if chans.size() == 4 else 2
	a.channels = chans
	a.mix_rate = int(d.get("mix_rate", 44100))
	return a

## Una fuente puntual codificada en la direccion dada (vector oyente -> fuente, en el mundo).
## Usa el codificador nativo; sin extension devuelve null.
static func encode_point(mono: PackedFloat32Array, direction: Vector3, p_mix_rate: int, p_order: int = 1) -> OpenDouAmbisonicAudio:
	if not ClassDB.class_exists("OpenDouAmbisonicStream"):
		return null
	var chans: Array = ClassDB.class_call_static("OpenDouAmbisonicStream", "encode_mono", mono, direction.normalized(), p_order)
	if chans.is_empty():
		return null
	var a := OpenDouAmbisonicAudio.new()
	a.order = p_order
	a.channels = chans
	a.mix_rate = p_mix_rate
	return a
