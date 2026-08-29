@tool
class_name OpenDouAudioFileGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a physical audio asset sample with high-definition waveform preview and instant audible playback.

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

class MiniWaveformCanvas extends Control:
	var playhead_norm: float = -1.0
	
	func _init() -> void:
		custom_minimum_size = Vector2(210, 68)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Dark Slate Background
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.11, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.3, 0.6), false, 1.0)
		
		# Center Zero-Crossing Line
		var mid_y = size.y * 0.5
		draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(0.25, 0.32, 0.38, 0.5), 1.0)
		
		# Amplitude Grid Lines (-6dB and -12dB)
		var db6_y = size.y * 0.25
		var db12_y = size.y * 0.75
		draw_line(Vector2(0, db6_y), Vector2(size.x, db6_y), Color(0.18, 0.22, 0.26, 0.4), 1.0)
		draw_line(Vector2(0, db12_y), Vector2(size.x, db12_y), Color(0.18, 0.22, 0.26, 0.4), 1.0)
		
		# High-Definition Waveform Envelope (Peaks & Transients)
		var steps = 48
		var points_top = PackedVector2Array()
		var points_bottom = PackedVector2Array()
		
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var px = t * size.x
			var transient = exp(-t * 2.5) * (sin(t * PI * 10.0) * 0.65 + sin(t * PI * 22.0) * 0.35)
			var amp = abs(transient) * (size.y * 0.44)
			points_top.append(Vector2(px, mid_y - amp))
			points_bottom.append(Vector2(px, mid_y + amp))
			
		for i in range(points_top.size() - 1):
			draw_line(points_top[i], points_bottom[i], Color(0.18, 0.83, 0.55, 0.85), 2.0)
			
		# Playhead
		if playhead_norm >= 0.0 and playhead_norm <= 1.0:
			var head_x = playhead_norm * size.x
			draw_line(Vector2(head_x, 0), Vector2(head_x, size.y), Color(1.0, 1.0, 1.0, 0.95), 2.0)

var audio_path: String = "gunfire_var1.wav"
var duration_sec: float = 1.2
var is_preview_playing: bool = false
var playback_timer: float = 0.0

var path_label: Label
var waveform_canvas: MiniWaveformCanvas
var duration_label: Label
var play_button: Button
var audio_player: AudioStreamPlayer

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_AUDIO_FILE
	title = "🎵 WAV (Audio Sample)"
	custom_minimum_size = Vector2(250, 165)
	_build_ui()

func _build_ui() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	
	# Audio File Name Header
	path_label = Label.new()
	path_label.text = audio_path
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(path_label)
	
	# Mini Waveform Preview Canvas
	waveform_canvas = MiniWaveformCanvas.new()
	vbox.add_child(waveform_canvas)
	
	# Bottom controls (Play button & duration label)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	play_button = Button.new()
	play_button.text = "▶ Play"
	play_button.custom_minimum_size = Vector2(70, 26)
	play_button.pressed.connect(_on_play_pressed)
	
	duration_label = Label.new()
	duration_label.text = "Duration: %.2fs" % duration_sec
	duration_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	hbox.add_child(play_button)
	hbox.add_child(duration_label)
	vbox.add_child(hbox)
	
	# Enable left input and right output
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)

func _process(delta: float) -> void:
	if is_preview_playing:
		playback_timer += delta
		var norm = playback_timer / duration_sec
		if waveform_canvas:
			waveform_canvas.playhead_norm = norm
			waveform_canvas.queue_redraw()
		if playback_timer >= duration_sec:
			_stop_preview()

func _on_play_pressed() -> void:
	if is_preview_playing:
		_stop_preview()
	else:
		_start_preview()

func _start_preview() -> void:
	is_preview_playing = true
	playback_timer = 0.0
	play_button.text = "⏹ Stop"
	set_active_highlight(true)
	
	if audio_player:
		audio_player.stream = _create_matching_stream()
		audio_player.play()

func _stop_preview() -> void:
	is_preview_playing = false
	playback_timer = 0.0
	play_button.text = "▶ Play"
	if waveform_canvas:
		waveform_canvas.playhead_norm = -1.0
		waveform_canvas.queue_redraw()
	set_active_highlight(false)
	
	if audio_player:
		audio_player.stop()

func _create_matching_stream() -> AudioStream:
	var path_low = audio_path.to_lower()
	if "gunfire" in path_low or "shot" in path_low:
		return AudioSynthesizerClass.create_gunshot()
	elif "concrete" in path_low:
		return AudioSynthesizerClass.create_footstep(&"Concrete", 1)
	elif "wood" in path_low:
		return AudioSynthesizerClass.create_footstep(&"Wood", 1)
	elif "metal" in path_low or "step_metal" in path_low:
		return AudioSynthesizerClass.create_footstep(&"Metal", 1)
	elif "mud" in path_low or "water" in path_low:
		return AudioSynthesizerClass.create_footstep(&"Water", 1)
	elif "idle" in path_low:
		return AudioSynthesizerClass.create_engine_loop(45.0, duration_sec)
	elif "mid" in path_low:
		return AudioSynthesizerClass.create_engine_loop(85.0, duration_sec)
	elif "high" in path_low or "redline" in path_low:
		return AudioSynthesizerClass.create_engine_loop(140.0, duration_sec)
	else:
		return AudioSynthesizerClass.create_tone(440.0, duration_sec)

## Sets the audio asset file path and updates preview.
func set_audio_asset(path: String, duration: float = 1.2) -> void:
	audio_path = path
	duration_sec = duration
	if path_label:
		path_label.text = path.get_file() if path.contains("/") or path.contains("\\") else path
	if duration_label:
		duration_label.text = "Duration: %.2fs" % duration_sec
