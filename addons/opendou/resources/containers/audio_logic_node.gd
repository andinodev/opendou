@tool
class_name AudioLogicNode
extends Resource

## Abstract base class for all logical audio containers and physical leaf nodes (Composite Pattern).

const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")

## Resolves the logic node against the current playback context, populating out_voices.
## Returns true if at least one voice was resolved, false otherwise.
func resolve(_context: AudioPlaybackContext, _out_voices: Array[ResolvedVoice]) -> bool:
	return false

## Helper method to resolve and return array of resolved voices.
func resolve_voices(context: AudioPlaybackContext = null) -> Array[ResolvedVoice]:
	var out: Array[ResolvedVoice] = []
	var ctx = context if context else AudioPlaybackContextClass.new()
	resolve(ctx, out)
	return out

## True si resolver el arbol dos veces con el mismo contexto da lo mismo. Un contenedor
## aleatorio o una secuencia no lo son: sus capas se fijan al arrancar la voz. Uno
## determinista (blend, switch, hoja) se re-resuelve cada cuadro para cruzar capas en vivo.
func is_deterministic() -> bool:
	return true
