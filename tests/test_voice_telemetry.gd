class_name TestVoiceTelemetry
extends RefCounted

const AudioTelemetryCollectorClass = preload("res://addons/opendou/runtime/network/audio_telemetry_collector.gd")
const LiveUpdateProtocolClass = preload("res://addons/opendou/runtime/network/live_update_protocol.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Collector Gathers Telemetry Snapshot
	var pool = VoicePoolManagerClass.new(4)
	var def1 = AudioEventDefClass.new(&"Footstep")
	def1.base_volume_db = -3.0
	var def2 = AudioEventDefClass.new(&"Explosion")
	def2.base_volume_db = 0.0
	
	var inst1 = EventInstanceClass.new(def1)
	inst1.set_position(Vector3(1.0, 2.0, 3.0))
	inst1.play()
	
	var inst2 = EventInstanceClass.new(def2)
	inst2.set_position(Vector3(10.0, 0.0, 5.0))
	inst2.play()
	
	pool.resolve_voice_stealing([inst1, inst2], Vector3.ZERO, 0.1)
	
	var snapshot = AudioTelemetryCollectorClass.collect_snapshot(pool, [inst1, inst2], null, 0.42)
	
	if snapshot.physical_voices != 2:
		failures.append("Test 1a Failed: Expected 2 physical voices, got %d" % snapshot.physical_voices)
	if not is_equal_approx(snapshot.total_dsp_cpu_time_ms, 0.42):
		failures.append("Test 1b Failed: Expected 0.42 ms DSP time, got %f" % snapshot.total_dsp_cpu_time_ms)
	if snapshot.voices.size() != 2:
		failures.append("Test 1c Failed: Expected 2 voice entries, got %d" % snapshot.voices.size())
		
	# Test 2: Binary Serialization of Detailed Telemetry
	var packet = LiveUpdateProtocolClass.encode_detailed_telemetry(snapshot)
	var decoded_packet = LiveUpdateProtocolClass.decode_packet(packet)
	
	if not decoded_packet.get("valid", false):
		failures.append("Test 2a Failed: Detailed telemetry packet decoding failed: %s" % decoded_packet.get("error", ""))
		return failures
		
	var tel_dict = LiveUpdateProtocolClass.decode_detailed_telemetry(decoded_packet["payload"])
	if tel_dict.get("physical_voices", 0) != 2:
		failures.append("Test 2b Failed: Decoded physical voices mismatch")
	if not is_equal_approx(tel_dict.get("total_dsp_cpu_time_ms", 0.0), 0.42):
		failures.append("Test 2c Failed: Decoded DSP time mismatch")
		
	var v_list: Array = tel_dict.get("voices", [])
	if v_list.size() != 2:
		failures.append("Test 2d Failed: Decoded voices array size mismatch, expected 2, got %d" % v_list.size())
	else:
		var v0 = v_list[0]
		if v0["event_name"] != &"Footstep" or v0["world_position"] != Vector3(1.0, 2.0, 3.0):
			failures.append("Test 2e Failed: Voice 0 decoded properties mismatch")
			
	return failures
