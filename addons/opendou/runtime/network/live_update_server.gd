class_name LiveUpdateServer
extends RefCounted

## TCP Server managing live editor connection, hot-reloading parameters in RAM, and sending telemetry.

const LiveUpdateProtocolClass = preload("res://addons/opendou/runtime/network/live_update_protocol.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

var tcp_server: TCPServer = null
var active_client: StreamPeerTCP = null
var is_server_running: bool = false
var server_port: int = 3016

# Incoming parsed commands queue
var command_queue: Array[Dictionary] = []

# Receive buffer for streaming TCP assembly
var receive_buffer: PackedByteArray = PackedByteArray()

## Starts the TCP Live Update server.
func start_server(port: int = 3016) -> bool:
	stop_server()
	server_port = port
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(server_port)
	if err != OK:
		push_error("[LiveUpdateServer] Failed to listen on port %d, error: %d" % [server_port, err])
		return false
		
	is_server_running = true
	return true

## Stops the server and disconnects active clients.
func stop_server() -> void:
	if active_client:
		active_client.disconnect_from_host()
		active_client = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	is_server_running = false
	receive_buffer.clear()
	command_queue.clear()

## Polls for incoming connections and parses TLV packets. Called every frame in _process.
func poll() -> void:
	if not is_server_running or not tcp_server:
		return
		
	# 1. Accept new client connection
	if not active_client and tcp_server.is_connection_available():
		active_client = tcp_server.take_connection()
		
	# 2. Read incoming data from client
	if active_client and active_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var avail: int = active_client.get_available_bytes()
		if avail > 0:
			var chunk = active_client.get_data(avail)
			if chunk[0] == OK:
				receive_buffer.append_array(chunk[1])
				_process_receive_buffer()
	elif active_client and active_client.get_status() != StreamPeerTCP.STATUS_CONNECTING:
		active_client = null

## Internal parser for TLV packet stream.
func _process_receive_buffer() -> void:
	while receive_buffer.size() >= LiveUpdateProtocolClass.HEADER_SIZE:
		var decoded = LiveUpdateProtocolClass.decode_packet(receive_buffer)
		if decoded.get("valid", false):
			command_queue.append({
				"type": decoded["type"],
				"payload": decoded["payload"]
			})
			var consumed: int = decoded["bytes_consumed"]
			receive_buffer = receive_buffer.slice(consumed)
		else:
			# Not enough bytes or invalid header
			break

## Dispatches queued commands and applies modifications directly in RAM.
func dispatch_commands(event_registry: Dictionary, sync_manager: RefCounted = null) -> void:
	while not command_queue.is_empty():
		var cmd = command_queue.pop_front()
		var m_type = cmd["type"]
		var payload: PackedByteArray = cmd["payload"]
		
		match m_type:
			LiveUpdateProtocolClass.MessageType.MSG_UPDATE_VOLUME:
				var data = LiveUpdateProtocolClass.decode_volume_update(payload)
				var ev_name = data.get("event_name", &"")
				if event_registry.has(ev_name):
					var def: AudioEventDef = event_registry[ev_name]
					def.base_volume_db = data.get("volume_db", 0.0)
					
			LiveUpdateProtocolClass.MessageType.MSG_SET_RTPC:
				if sync_manager and sync_manager.has_method("set_rtpc"):
					var sp = StreamPeerBuffer.new()
					sp.data_array = payload
					var name_len = sp.get_u16()
					var name_str = sp.get_utf8_string(name_len)
					var val = sp.get_float()
					sync_manager.call("set_rtpc", StringName(name_str), val, true)

## Sends performance telemetry data to connected editor client.
func send_telemetry(physical_voices: int, virtual_voices: int, instance_count: int) -> void:
	if active_client and active_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var packet = LiveUpdateProtocolClass.encode_telemetry(physical_voices, virtual_voices, instance_count)
		active_client.put_data(packet)
