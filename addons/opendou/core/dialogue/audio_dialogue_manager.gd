@tool
class_name AudioDialogueManager
extends RefCounted

## Manages global voice localization, hot-swapping languages, and automatic ducking of competing sound categories.

signal language_changed(new_language: String)
signal dialogue_started(key: StringName, lang: String)
signal dialogue_finished(key: StringName)

var current_language: String = "en"
var fallback_language: String = "en"
var main_table: AudioDialogueTable = null

var is_speaking: bool = false
var speech_timer: float = 0.0

func _init(initial_lang: String = "en", table: AudioDialogueTable = null) -> void:
	current_language = initial_lang
	main_table = table if table != null else AudioDialogueTable.new()

## Changes active language in runtime with zero event rebuilding.
func set_language(lang_code: String) -> void:
	if current_language == lang_code.to_lower():
		return
	current_language = lang_code.to_lower()
	language_changed.emit(current_language)

## Resolves the localized audio stream for a key in the current language.
func get_localized_stream(dialogue_key: StringName) -> Variant:
	if main_table == null:
		return null
	return main_table.get_stream(dialogue_key, current_language, fallback_language)

## Plays dialogue on a designated AudioStreamPlayer and triggers sidechain ducking on the Voice bus.
func play_dialogue(dialogue_key: StringName, player: AudioStreamPlayer, ducking_matrix = null) -> bool:
	var stream = get_localized_stream(dialogue_key)
	if stream == null:
		return false
		
	if player != null and stream is AudioStream:
		player.stream = stream
		player.bus = &"Voice"
		player.play()
		
		var dur = stream.get_length() if stream.has_method("get_length") else 1.5
		is_speaking = true
		speech_timer = dur
		
		if ducking_matrix != null and ducking_matrix.has_method("set_bus_active"):
			ducking_matrix.set_bus_active(&"Voice", true)
			
		dialogue_started.emit(dialogue_key, current_language)
		return true
		
	return false

func update(delta: float, ducking_matrix = null) -> void:
	if is_speaking:
		speech_timer -= delta
		if speech_timer <= 0.0:
			is_speaking = false
			if ducking_matrix != null and ducking_matrix.has_method("set_bus_active"):
				ducking_matrix.set_bus_active(&"Voice", false)
			dialogue_finished.emit(&"")
