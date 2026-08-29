class_name TestDialogueLocalization
extends RefCounted

const AudioDialogueTableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const AudioDialogueManagerClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_manager.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Dialogue Table mappings and fallback
	var table = AudioDialogueTableClass.new()
	var dummy_en = AudioStreamWAV.new()
	dummy_en.resource_name = "hero_en.wav"
	var dummy_es = AudioStreamWAV.new()
	dummy_es.resource_name = "hero_es.wav"
	
	table.add_entry(&"HERO_ATTACK", "en", dummy_en)
	table.add_entry(&"HERO_ATTACK", "es", dummy_es)
	
	var res_es = table.get_stream(&"HERO_ATTACK", "es")
	if res_es != dummy_es:
		failures.append("Test 1a Failed: Expected Spanish stream, got %s" % str(res_es))
		
	var res_ja = table.get_stream(&"HERO_ATTACK", "ja", "en") # Fallback to English
	if res_ja != dummy_en:
		failures.append("Test 1b Failed: Expected English fallback stream for unmapped Japanese, got %s" % str(res_ja))
		
	# Test 2: Dialogue Manager Language Swapping
	var mgr = AudioDialogueManagerClass.new("en", table)
	if mgr.get_localized_stream(&"HERO_ATTACK") != dummy_en:
		failures.append("Test 2a Failed: Expected English stream when active lang is en")
		
	mgr.set_language("es")
	if mgr.get_localized_stream(&"HERO_ATTACK") != dummy_es:
		failures.append("Test 2b Failed: Expected Spanish stream after hot-swap to es")
		
	# Test 3: Dialogue Playback and Voice Bus Ducking Integration
	var duck_matrix = AudioDuckingMatrixClass.new()
	var player = AudioStreamPlayer.new()
	
	var ok = mgr.play_dialogue(&"HERO_ATTACK", player, duck_matrix)
	if not ok:
		failures.append("Test 3a Failed: Failed to play dialogue")
		
	duck_matrix.update(0.1)
	var music_duck = duck_matrix.get_ducking_attenuation_db(&"Music")
	if music_duck >= 0.0:
		failures.append("Test 3b Failed: Music bus should be ducked during dialogue playback")
		
	# End speech
	mgr.update(2.0, duck_matrix)
	duck_matrix.update(1.0)
	var music_restored = duck_matrix.get_ducking_attenuation_db(&"Music")
	if not is_equal_approx(music_restored, 0.0):
		failures.append("Test 3c Failed: Music bus ducking should restore to 0dB after dialogue ends")
		
	player.free()
	return failures
