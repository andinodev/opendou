class_name DemoSoundBankStreaming
extends Control

## Demo 06: Monolithic SoundBank Prefetch & Lock-Free Ring-Buffer Disk Streaming

const SoundBankCompilerClass = preload("res://addons/opendou/tools/soundbank_compiler.gd")
const SoundBankClass = preload("res://addons/opendou/runtime/soundbank.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var test_bank_path: String = "user://demo_stream.bank"
var preloaded_stream: AudioStreamWAV = null
var is_stream_ready: bool = false
var total_streamed_frames: int = 0
var audible_stream: AudioStreamWAV

# Scene Node References
@onready var audio_player: AudioStreamPlayer = get_node_or_null("AudioPlayer")
@onready var btn_back: Button = get_node_or_null("HeaderPanel/Margin/HBox/BtnBack")
@onready var btn_play: Button = get_node_or_null("MainLayout/Phase1Card/Margin/VBox/PlaybackControls/BtnPlay")
@onready var btn_stop: Button = get_node_or_null("MainLayout/Phase1Card/Margin/VBox/PlaybackControls/BtnStop")

@onready var lbl_chunks: Label = get_node_or_null("MainLayout/Phase2Card/Margin/VBox/LblChunks")
@onready var bar_ring: ProgressBar = get_node_or_null("MainLayout/Phase2Card/Margin/VBox/BarRing")

func _init() -> void:
	audible_stream = AudioSynthesizerClass.create_chord_loop(2.0)
	setup_streaming_demo()

func _ready() -> void:
	if not is_stream_ready:
		setup_streaming_demo()
	_connect_ui()
	_update_ui()

func setup_streaming_demo(bank_path: String = "user://demo_stream.bank") -> void:
	test_bank_path = bank_path
	
	# Synthesize sample audio for the stream demo (1 second @ 44100Hz = 88200 bytes)
	var pcm_data = PackedByteArray()
	pcm_data.resize(44100 * 2)
	for i in range(44100):
		var sample_val = int(sin(float(i) / 44100.0 * 440.0 * TAU) * 30000.0)
		pcm_data.encode_s16(i * 2, sample_val)
		
	var stream_inputs: Array[Dictionary] = [
		{
			"id": 1,
			"name": &"ambient_music_stream",
			"data": pcm_data,
			"channels": 2,
			"sample_rate": 44100,
			"codec": 0,
			"prefetch_size": 65536
		}
	]
	
	SoundBankCompilerClass.compile_bank(test_bank_path, stream_inputs)
	
	# El banco se precarga como AudioStreamWAV en lugar de reproducirse por
	# streaming: GDScript no puede sostener un mezclador en el hilo de audio.
	var bank = SoundBankClass.new(test_bank_path)
	bank.load_from_file(test_bank_path)
	preloaded_stream = bank.build_stream(1)
	is_stream_ready = (preloaded_stream != null)
	total_streamed_frames = 0

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
	if btn_stop:
		btn_stop.pressed.connect(_on_stop_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

func _on_play_pressed() -> void:
	# Mix a chunk of audio and play audibly
	mix_audio_chunk(4096)
	if audio_player and audible_stream:
		audio_player.stream = audible_stream
		audio_player.play()
	_update_ui()

func _on_stop_pressed() -> void:
	total_streamed_frames = 0
	if audio_player:
		audio_player.stop()
	_update_ui()

## Devuelve un trozo de los bytes PCM del stream precargado del banco.
##
## Antes esto mezclaba desde un BankStreamPlayback que no llegaba a ninguna salida
## de audio. Ahora el banco se precarga entero y esto solo asoma sus bytes para el
## indicador en pantalla.
func mix_audio_chunk(bytes_to_mix: int = 512) -> PackedByteArray:
	if preloaded_stream == null:
		return PackedByteArray()

	var data: PackedByteArray = preloaded_stream.data
	var start: int = mini(total_streamed_frames, data.size())
	var count: int = mini(bytes_to_mix, data.size() - start)
	if count <= 0:
		return PackedByteArray()
	total_streamed_frames += count
	return data.slice(start, start + count)

func _update_ui() -> void:
	if lbl_chunks:
		lbl_chunks.text = "Precargado: %d / %d bytes PCM del banco" % [total_streamed_frames, preloaded_stream.data.size() if preloaded_stream != null else 0]
