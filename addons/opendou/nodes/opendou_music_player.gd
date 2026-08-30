@icon("res://addons/opendou/icons/icon_music_player.svg")
@tool
class_name OpenDouMusicPlayer
extends Node

## Declarative Multi-Stem Interactive Music Player for OpenDou.
## Automatically manages synchronized multi-track audio playback, dynamic intensity crossfading,
## sidechain ducking attenuation, and quantized or immediate stinger playback.

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("Music Suite Configuration")
@export var suite_name: StringName = &"Exploration_Ambient_Theme.tres"
@export var auto_play: bool = true
@export var auto_loop: bool = true

@export_group("Adaptive Playback & Mixing")
@export_range(0.0, 1.0, 0.01) var combat_intensity: float = 0.0
@export var master_bus: StringName = &"Music"
@export var enable_ducking: bool = true

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var stem_players: Array[AudioStreamPlayer] = []
var stem_track_data: Array[Dictionary] = []
var is_playing_suite: bool = false
var is_paused_suite: bool = false
var ducking_matrix: AudioDuckingMatrix = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if not Engine.is_editor_hint() and auto_play:
		load_suite(suite_name)
		play()

func _process(delta: float) -> void:
	if enable_ducking and ducking_matrix != null:
		ducking_matrix.update(delta)
		_update_stem_levels()

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Sets an explicit AudioDuckingMatrix instance for sidechain attenuation.
func set_ducking_matrix(matrix: AudioDuckingMatrix) -> void:
	ducking_matrix = matrix

## Loads a multi-stem music suite configuration from disk or JSON and creates synchronized stem players.
func load_suite(s_name: StringName = &"") -> void:
	if not s_name.is_empty():
		suite_name = s_name
		
	# Clean up previous stem players
	for p in stem_players:
		if is_instance_valid(p):
			if p.is_inside_tree():
				p.stop()
			p.queue_free()
	stem_players.clear()
	stem_track_data.clear()
	
	var tracks_to_create: Array[Dictionary] = []
	const SUITES_PATH = "res://opendou_music_suites.json"
	if FileAccess.file_exists(SUITES_PATH):
		var file = FileAccess.open(SUITES_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and parsed.has(str(suite_name)):
				var s_data = parsed[str(suite_name)]
				if s_data.has("tracks") and s_data["tracks"] is Array:
					for td in s_data["tracks"]:
						if td is Dictionary:
							tracks_to_create.append(td)
	
	# Fallback synthetic tracks if JSON suite is not found or empty
	if tracks_to_create.is_empty():
		if str(suite_name).contains("Exploration"):
			tracks_to_create = [
				{"name": "Layer 1: Ambient_Pads", "min_intensity": 0.0, "max_intensity": 0.7, "bus_name": master_bus, "volume_db": 0.0},
				{"name": "Layer 2: Nature_Foley", "min_intensity": 0.2, "max_intensity": 0.8, "bus_name": master_bus, "volume_db": 0.0}
			]
		else:
			tracks_to_create = [
				{"name": "Layer 1: Ambient_Pads", "min_intensity": 0.0, "max_intensity": 0.5, "bus_name": master_bus, "volume_db": 0.0},
				{"name": "Layer 2: Stealth_Bass", "min_intensity": 0.2, "max_intensity": 0.7, "bus_name": master_bus, "volume_db": 0.0},
				{"name": "Layer 3: Combat_Drums", "min_intensity": 0.5, "max_intensity": 1.0, "bus_name": master_bus, "volume_db": 0.0},
				{"name": "Layer 4: Brass_Climax", "min_intensity": 0.8, "max_intensity": 1.0, "bus_name": master_bus, "volume_db": 0.0}
			]
			
	for idx in range(tracks_to_create.size()):
		var t_info = tracks_to_create[idx]
		var t_name = str(t_info.get("name", "Stem_%d" % idx))
		var min_i = float(t_info.get("min_intensity", 0.0))
		var max_i = float(t_info.get("max_intensity", 1.0))
		var vol = float(t_info.get("volume_db", 0.0))
		var bus = StringName(str(t_info.get("bus_name", master_bus)))
		if bus.is_empty():
			bus = master_bus
			
		var p = AudioStreamPlayer.new()
		p.name = "StemPlayer_%d" % idx
		p.bus = bus
		
		var file_path = str(t_info.get("audio_file_path", ""))
		if not file_path.is_empty() and ResourceLoader.exists(file_path):
			p.stream = load(file_path)
		else:
			if t_name.contains("Pad") or t_name.contains("Ambient"):
				p.stream = AudioSynthesizerClass.create_music_pad_loop(2.0)
			elif t_name.contains("Foley") or t_name.contains("Nature"):
				p.stream = AudioSynthesizerClass.create_nature_foley_loop(2.0)
			elif t_name.contains("Bass") or t_name.contains("Stealth"):
				p.stream = AudioSynthesizerClass.create_music_bass_loop(2.0)
			elif t_name.contains("Drum") or t_name.contains("War") or t_name.contains("Percussion"):
				p.stream = AudioSynthesizerClass.create_music_drums_loop(2.0)
			elif t_name.contains("Brass") or t_name.contains("Lead") or t_name.contains("Choir") or t_name.contains("Climax"):
				p.stream = AudioSynthesizerClass.create_music_brass_loop(2.0)
			else:
				p.stream = AudioSynthesizerClass.create_chord_loop(2.0)
				
		add_child(p)
		stem_players.append(p)
		stem_track_data.append({
			"name": t_name,
			"min_intensity": min_i,
			"max_intensity": max_i,
			"volume_db": vol,
			"bus_name": bus
		})
		
	_update_stem_levels()
	
	if is_playing_suite:
		for p in stem_players:
			if is_instance_valid(p) and p.is_inside_tree():
				p.play()

## Starts or resumes synchronized playback of all stems.
func play() -> void:
	if stem_players.is_empty() and not suite_name.is_empty():
		load_suite(suite_name)
		
	for p in stem_players:
		if is_instance_valid(p) and p.is_inside_tree():
			if p.stream_paused:
				p.stream_paused = false
			else:
				p.play()
				
	is_playing_suite = true
	is_paused_suite = false
	_update_stem_levels()

## Stops playback of all stems.
func stop() -> void:
	for p in stem_players:
		if is_instance_valid(p) and p.is_inside_tree():
			p.stop()
			
	is_playing_suite = false
	is_paused_suite = false

## Pauses playback of all stems.
func pause() -> void:
	for p in stem_players:
		if is_instance_valid(p) and p.is_inside_tree():
			p.stream_paused = true
			
	is_paused_suite = true

## Returns true if the music suite is actively playing.
func is_playing() -> bool:
	return is_playing_suite

## Returns true if the music suite is currently paused.
func is_paused() -> bool:
	return is_paused_suite

## Dynamically sets the combat intensity (0.0 to 1.0) and updates stem volume envelopes.
func set_combat_intensity(val: float) -> void:
	combat_intensity = clampf(val, 0.0, 1.0)
	_update_stem_levels()

## Returns the number of stems loaded in the active suite.
func get_stem_count() -> int:
	return stem_players.size()

## Triggers an immediate one-shot musical stinger over the suite playback.
func trigger_stinger(stinger_name: StringName) -> void:
	var stinger_player = AudioStreamPlayer.new()
	stinger_player.name = "Stinger_" + str(stinger_name)
	stinger_player.bus = master_bus
	
	var s_str = str(stinger_name)
	if s_str.contains("Fanfare") or s_str.contains("Victory"):
		stinger_player.stream = AudioSynthesizerClass.create_stinger_fanfare(1.5)
	elif s_str.contains("Impact") or s_str.contains("Danger") or s_str.contains("Hit"):
		stinger_player.stream = AudioSynthesizerClass.create_stinger_impact(1.2)
	else:
		stinger_player.stream = AudioSynthesizerClass.create_tone(880.0, 0.8, 0.6)
		
	add_child(stinger_player)
	if stinger_player.is_inside_tree():
		stinger_player.play()
		stinger_player.finished.connect(stinger_player.queue_free)

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

func _update_stem_levels() -> void:
	var duck_gr: float = 0.0
	if enable_ducking and ducking_matrix != null:
		duck_gr = ducking_matrix.get_gain_reduction_db(&"Voice", master_bus)
		
	for i in range(stem_players.size()):
		if i >= stem_track_data.size():
			continue
		var p = stem_players[i]
		if not is_instance_valid(p):
			continue
		var data = stem_track_data[i]
		var min_i: float = float(data.get("min_intensity", 0.0))
		var max_i: float = float(data.get("max_intensity", 1.0))
		var base_vol: float = float(data.get("volume_db", 0.0))
		
		var is_active = combat_intensity >= (min_i - 0.05) and combat_intensity <= (max_i + 0.05)
		if is_active:
			p.volume_db = base_vol + duck_gr
		else:
			p.volume_db = -60.0
