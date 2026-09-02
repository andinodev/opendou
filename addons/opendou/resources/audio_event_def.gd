@tool
class_name AudioEventDef
extends Resource

## Immutable definition of an audio event, including base stream or logic container tree, RTPC rules, modulators, bus routing, and virtualization settings.

const AudioLogicNodeClass = preload("res://addons/opendou/resources/containers/audio_logic_node.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
const AudioModulatorClass = preload("res://addons/opendou/resources/modulators/audio_modulator.gd")

enum VoiceStealingBehavior {
	LOWEST_PRIORITY, ## Steals voice with lowest calculated dynamic priority
	FURTHEST,        ## Steals voice furthest from the active listener
	QUIETEST,        ## Steals voice with lowest volume level
	OLDEST,          ## Steals oldest playing voice instance
	FAIL_TO_PLAY     ## Rejects new playback if voice limit is reached
}

enum VirtualizationMode {
	VIRTUAL_ELAPSED_TIME,    ## Resumes and seeks to current logical elapsed time
	VIRTUAL_PLAY_FROM_START, ## Restarts playback from beginning (0.0s)
	VIRTUAL_RESUME,          ## Pauses when virtual, unpauses where it left off
	VIRTUAL_KILL_VOICE       ## Immediately destroys the instance if virtualized
}

@export var event_name: StringName = &""

## Target mixing bus in Godot AudioServer (e.g. Master, SFX, Music, Dialogue, Ambience).
@export var target_bus: StringName = &"Master"

## Root logic container (Random, Switch, Blend, Sequence). If set, takes precedence over base_stream.
@export var root_container: AudioLogicNode

## Base single audio stream fallback if no root_container is specified.
@export var base_stream: AudioStream

## Metadata duration of the stream in seconds (extracted from bank/WAV header).
@export var stream_length: float = 0.0

## Whether this audio event loops continuously.
@export var is_looping: bool = false

## Sonoridad de diseno del evento en dB HDR: cuanto suena esta cosa EN EL MUNDO,
## no en la mezcla. Explosion +18, disparo +6, pisada -20.
##
## Es la entrada del motor HDR, que la compara con la ventana de sonoridad activa
## para decidir cuanto se atenua esta voz. No confundir con base_volume_db, que es
## nivel de mezcla: son magnitudes distintas.
##
## El valor por defecto de 0.0 hace que la contribucion del HDR sea exactamente
## 0 dB, asi que activarlo no altera ninguna mezcla existente.
@export var hdr_loudness_db: float = 0.0

@export var base_volume_db: float = 0.0
@export var base_pitch_scale: float = 1.0
@export var base_priority: float = 50.0 # 0 (lowest) to 100 (highest)
@export var max_instances: int = 5

@export var stealing_behavior: VoiceStealingBehavior = VoiceStealingBehavior.LOWEST_PRIORITY
@export var virtualization_mode: VirtualizationMode = VirtualizationMode.VIRTUAL_ELAPSED_TIME

@export var rtpc_bindings: Array[RTPCBinding] = []
@export var modulators: Array[AudioModulator] = []

func _init(p_event_name: StringName = &"", p_stream: AudioStream = null) -> void:
	event_name = p_event_name
	base_stream = p_stream
	target_bus = &"Master"
	rtpc_bindings = []
	modulators = []
	is_looping = false
	stream_length = 0.0

## Adds an RTPC binding rule to this event definition.
func add_rtpc_binding(binding: RTPCBinding) -> void:
	if binding and not rtpc_bindings.has(binding):
		rtpc_bindings.append(binding)

## Adds an automatic modulator (AHDSR or LFO) to this event definition.
func add_modulator(modulator: AudioModulator) -> void:
	if modulator and not modulators.has(modulator):
		modulators.append(modulator)

## Resolves the event into concrete physical voices given a playback context.
func resolve_voices(context: AudioPlaybackContext = null) -> Array[ResolvedVoice]:
	var out_voices: Array[ResolvedVoice] = []
	
	if root_container:
		var ctx = context if context else AudioPlaybackContextClass.new()
		root_container.resolve(ctx, out_voices)
	elif base_stream:
		out_voices.append(ResolvedVoiceClass.new(base_stream, 0.0, 1.0))
		
	return out_voices
