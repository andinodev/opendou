class_name LiveUpdateProtocol
extends RefCounted

## Type-Length-Value (TLV) binary network protocol serializer for OpenDou Live Update.

const AudioTelemetryCollectorClass = preload("res://addons/opendou/runtime/network/audio_telemetry_collector.gd")

enum MessageType {
	MSG_HANDSHAKE = 0,
	MSG_UPDATE_VOLUME = 1,
	MSG_UPDATE_RTPC_CURVE = 2,
	MSG_TRIGGER_EVENT = 3,
	MSG_SET_RTPC = 4,
	MSG_SET_STATE = 5,
	MSG_TELEMETRY = 6
}

const MAGIC: String = "OD" # 2 bytes
const HEADER_SIZE: int = 8

## Encodes a message type and raw payload into a standard 8-byte header TLV packet.
static func encode_packet(msg_type: int, payload: PackedByteArray) -> PackedByteArray:
	var packet = PackedByteArray()
	packet.resize(HEADER_SIZE + payload.size())
	
	# Magic (2 bytes)
	var magic_bytes = MAGIC.to_ascii_buffer()
	packet[0] = magic_bytes[0]
	packet[1] = magic_bytes[1]
	
	# Message Type (2 bytes uint16 little-endian)
	packet[2] = msg_type & 0xFF
	packet[3] = (msg_type >> 8) & 0xFF
	
	# Payload Length (4 bytes uint32 little-endian)
	var p_len = payload.size()
	packet[4] = p_len & 0xFF
	packet[5] = (p_len >> 8) & 0xFF
	packet[6] = (p_len >> 16) & 0xFF
	packet[7] = (p_len >> 24) & 0xFF
	
	# Payload bytes
	for i in range(p_len):
		packet[HEADER_SIZE + i] = payload[i]
		
	return packet

## Decodes a TLV packet from a buffer. Returns dictionary with result details.
static func decode_packet(buffer: PackedByteArray) -> Dictionary:
	if buffer.size() < HEADER_SIZE:
		return {"valid": false, "error": "Buffer smaller than header size"}
		
	# Verify Magic
	if buffer[0] != 79 or buffer[1] != 68: # 'O', 'D'
		return {"valid": false, "error": "Invalid protocol magic signature"}
		
	var msg_type: int = buffer[2] | (buffer[3] << 8)
	var payload_len: int = buffer[4] | (buffer[5] << 8) | (buffer[6] << 16) | (buffer[7] << 24)
	
	if buffer.size() < HEADER_SIZE + payload_len:
		return {"valid": false, "error": "Incomplete packet payload"}
		
	var payload = buffer.slice(HEADER_SIZE, HEADER_SIZE + payload_len)
	return {
		"valid": true,
		"type": msg_type,
		"payload": payload,
		"bytes_consumed": HEADER_SIZE + payload_len
	}

# ==============================================================================
# SPECIALIZED MESSAGE SERIALIZERS & PARSERS
# ==============================================================================

## Encodes a volume update message (Event Name + Volume dB).
static func encode_volume_update(event_name: StringName, volume_db: float) -> PackedByteArray:
	var name_buf = String(event_name).to_utf8_buffer()
	var payload = PackedByteArray()
	var n_len = name_buf.size()
	payload.append(n_len & 0xFF)
	payload.append((n_len >> 8) & 0xFF)
	payload.append_array(name_buf)
	
	var sp = StreamPeerBuffer.new()
	sp.put_float(volume_db)
	payload.append_array(sp.data_array)
	
	return encode_packet(MessageType.MSG_UPDATE_VOLUME, payload)

## Decodes a volume update message.
static func decode_volume_update(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 6:
		return {}
	var n_len: int = payload[0] | (payload[1] << 8)
	if payload.size() < 2 + n_len + 4:
		return {}
	var name_str = payload.slice(2, 2 + n_len).get_string_from_utf8()
	var float_bytes = payload.slice(2 + n_len, 2 + n_len + 4)
	var sp = StreamPeerBuffer.new()
	sp.data_array = float_bytes
	var vol_db = sp.get_float()
	return {"event_name": StringName(name_str), "volume_db": vol_db}

## Encodes a detailed telemetry snapshot including 3D positions of all active voices.
static func encode_detailed_telemetry(snapshot: RefCounted) -> PackedByteArray:
	var sp = StreamPeerBuffer.new()
	
	var phys: int = snapshot.get("physical_voices") if "physical_voices" in snapshot else 0
	var virt: int = snapshot.get("virtual_voices") if "virtual_voices" in snapshot else 0
	var dsp: float = snapshot.get("total_dsp_cpu_time_ms") if "total_dsp_cpu_time_ms" in snapshot else 0.0
	var ram: int = snapshot.get("prefetch_ram_kb") if "prefetch_ram_kb" in snapshot else 0
	var voices: Array = snapshot.get("voices") if "voices" in snapshot else []
	
	sp.put_u32(phys)
	sp.put_u32(virt)
	sp.put_float(dsp)
	sp.put_u32(ram)
	sp.put_u32(voices.size())
	
	for v in voices:
		var name_str = String(v.event_name)
		var name_buf = name_str.to_utf8_buffer()
		sp.put_u16(name_buf.size())
		sp.put_data(name_buf)
		sp.put_float(v.volume_db)
		sp.put_float(v.world_position.x)
		sp.put_float(v.world_position.y)
		sp.put_float(v.world_position.z)
		sp.put_u8(1 if v.is_virtual else 0)
		sp.put_float(v.dynamic_weight)
		
	return encode_packet(MessageType.MSG_TELEMETRY, sp.data_array)

## Decodes a detailed telemetry snapshot packet.
static func decode_detailed_telemetry(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 20:
		return {}
		
	var sp = StreamPeerBuffer.new()
	sp.data_array = payload
	
	var phys = sp.get_u32()
	var virt = sp.get_u32()
	var dsp = sp.get_float()
	var ram = sp.get_u32()
	var num_v = sp.get_u32()
	
	var voices: Array = []
	for i in range(num_v):
		var n_len = sp.get_u16()
		var n_str = sp.get_utf8_string(n_len)
		var vol = sp.get_float()
		var px = sp.get_float()
		var py = sp.get_float()
		var pz = sp.get_float()
		var is_virt = (sp.get_u8() == 1)
		var weight = sp.get_float()
		
		voices.append({
			"event_name": StringName(n_str),
			"volume_db": vol,
			"world_position": Vector3(px, py, pz),
			"is_virtual": is_virt,
			"dynamic_weight": weight
		})
		
	return {
		"physical_voices": phys,
		"virtual_voices": virt,
		"total_dsp_cpu_time_ms": dsp,
		"prefetch_ram_kb": ram,
		"voices": voices
	}

## Encodes basic performance metrics.
static func encode_telemetry(phys: int, virt: int, instances: int) -> PackedByteArray:
	var sp = StreamPeerBuffer.new()
	sp.put_u32(phys)
	sp.put_u32(virt)
	sp.put_u32(instances)
	return encode_packet(MessageType.MSG_TELEMETRY, sp.data_array)

## Decodes basic performance metrics.
static func decode_telemetry(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 12:
		return {}
	var sp = StreamPeerBuffer.new()
	sp.data_array = payload
	return {
		"physical_voices": sp.get_u32(),
		"virtual_voices": sp.get_u32(),
		"instance_count": sp.get_u32()
	}

