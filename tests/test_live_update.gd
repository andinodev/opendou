class_name TestLiveUpdate
extends RefCounted

const LiveUpdateProtocolClass = preload("res://addons/opendou/runtime/network/live_update_protocol.gd")
const LiveUpdateServerClass = preload("res://addons/opendou/runtime/network/live_update_server.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const GameSyncManagerClass = preload("res://addons/opendou/runtime/game_sync_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: TLV Packet Encoding & Decoding
	var payload = PackedByteArray([10, 20, 30, 40, 50])
	var packet = LiveUpdateProtocolClass.encode_packet(LiveUpdateProtocolClass.MessageType.MSG_HANDSHAKE, payload)
	
	if packet.size() != LiveUpdateProtocolClass.HEADER_SIZE + 5:
		failures.append("Test 1a Failed: Encoded packet size mismatch, expected 13, got %d" % packet.size())
		
	var decoded = LiveUpdateProtocolClass.decode_packet(packet)
	if not decoded.get("valid", false):
		failures.append("Test 1b Failed: Packet decoding reported invalid: %s" % decoded.get("error", ""))
	elif decoded["type"] != LiveUpdateProtocolClass.MessageType.MSG_HANDSHAKE:
		failures.append("Test 1c Failed: Message type mismatch, expected MSG_HANDSHAKE")
	elif decoded["payload"] != payload:
		failures.append("Test 1d Failed: Payload mismatch")
		
	# Test 2: Volume Update Message Serialization
	var vol_packet = LiveUpdateProtocolClass.encode_volume_update(&"Rifle_Shot", -4.5)
	var decoded_vol_packet = LiveUpdateProtocolClass.decode_packet(vol_packet)
	var vol_data = LiveUpdateProtocolClass.decode_volume_update(decoded_vol_packet["payload"])
	
	if vol_data.get("event_name", &"") != &"Rifle_Shot":
		failures.append("Test 2a Failed: Volume update event name mismatch, got '%s'" % str(vol_data.get("event_name", &"")))
	if not is_equal_approx(vol_data.get("volume_db", 0.0), -4.5):
		failures.append("Test 2b Failed: Volume update dB mismatch, expected -4.5, got %f" % vol_data.get("volume_db", 0.0))
		
	# Test 3: Telemetry Serialization
	var tel_packet = LiveUpdateProtocolClass.encode_telemetry(16, 48, 64)
	var decoded_tel_packet = LiveUpdateProtocolClass.decode_packet(tel_packet)
	var tel_data = LiveUpdateProtocolClass.decode_telemetry(decoded_tel_packet["payload"])
	
	if tel_data.get("physical_voices", 0) != 16 or tel_data.get("virtual_voices", 0) != 48 or tel_data.get("instance_count", 0) != 64:
		failures.append("Test 3 Failed: Telemetry metrics mismatch")
		
	# Test 4: Live Server Command Dispatching in RAM
	var server = LiveUpdateServerClass.new()
	var def = AudioEventDefClass.new(&"Explosion")
	def.base_volume_db = 0.0
	
	var registry: Dictionary = {&"Explosion": def}
	var sync_mgr = GameSyncManagerClass.new()
	
	# Simulate queued volume command
	server.command_queue.append({
		"type": LiveUpdateProtocolClass.MessageType.MSG_UPDATE_VOLUME,
		"payload": decoded_vol_packet["payload"] # Has -4.5 dB for Rifle_Shot, let's encode for Explosion
	})
	
	var exp_vol_packet = LiveUpdateProtocolClass.encode_volume_update(&"Explosion", -9.0)
	var dec_exp = LiveUpdateProtocolClass.decode_packet(exp_vol_packet)
	server.command_queue.append({
		"type": LiveUpdateProtocolClass.MessageType.MSG_UPDATE_VOLUME,
		"payload": dec_exp["payload"]
	})
	
	server.dispatch_commands(registry, sync_mgr)
	
	if not is_equal_approx(def.base_volume_db, -9.0):
		failures.append("Test 4 Failed: Live dispatch did not update base_volume_db in RAM, expected -9.0, got %f" % def.base_volume_db)
		
	return failures
