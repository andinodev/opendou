class_name OpenDouAudioFileGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a single audio asset / physical sound sample.

class MiniWaveformCanvas extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(160, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.15, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.3, 0.5), false, 1.0)
		
		# Draw stylized audio waveform envelope
		var mid_y = size.y * 0.5
		var steps = 32
		var points_top = PackedVector2Array()
		var points_bottom = PackedVector2Array()
		
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var px = t * size.x
			var amp = exp(-t * 2.5) * sin(t * PI * 8.0) * (size.y * 0.4)
			points_top.append(Vector2(px, mid_y - abs(amp)))
			points_bottom.append(Vector2(px, mid_y + abs(amp)))
			
		for i in range(points_top.size() - 1):
			draw_line(points_top[i], points_bottom[i], Color(0.95, 0.75, 0.2, 0.8), 2.0)

var audio_path: String = "shot_low_1.wav"
var duration_sec: float = 2.3
var is_preview_playing: bool = false

var path_label: Label
var waveform_canvas: MiniWaveformCanvas
var duration_label: Label
var play_button: Button

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_AUDIO_FILE
	title = "WAV (Audio File)"
	custom_minimum_size = Vector2(190, 130)
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Audio File Name
	path_label = Label.new()
	path_label.text = audio_path
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(path_label)
	
	# Mini Waveform Preview
	waveform_canvas = MiniWaveformCanvas.new()
	vbox.add_child(waveform_canvas)
	
	# Bottom controls (Play button & duration)
	var hbox = HBoxContainer.new()
	play_button = Button.new()
	play_button.text = "▶ Play"
	play_button.pressed.connect(_on_play_pressed)
	duration_label = Label.new()
	duration_label.text = "%.1fs" % duration_sec
	duration_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(play_button)
	hbox.add_child(duration_label)
	vbox.add_child(hbox)
	
	# Enable left input and right output
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)

func _on_play_pressed() -> void:
	is_preview_playing = not is_preview_playing
	play_button.text = "⏹ Stop" if is_preview_playing else "▶ Play"
	set_active_highlight(is_preview_playing)

## Sets the audio asset file path and updates preview.
func set_audio_asset(path: String, duration: float = 2.0) -> void:
	audio_path = path
	duration_sec = duration
	if path_label:
		path_label.text = path.get_file() if path.contains("/") or path.contains("\\") else path
	if duration_label:
		duration_label.text = "%.1fs" % duration_sec
