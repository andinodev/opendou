class_name AudioRingBuffer
extends RefCounted

## Single-Producer Single-Consumer (SPSC) circular byte buffer for low-latency audio streaming.

var buffer: PackedByteArray = PackedByteArray()
var capacity: int = 65536 # 64 KB default
var read_cursor: int = 0
var write_cursor: int = 0
var filled_bytes: int = 0

func _init(p_capacity: int = 65536) -> void:
	capacity = max(256, p_capacity)
	buffer = PackedByteArray()
	buffer.resize(capacity)
	clear()

## Returns the number of bytes available for reading.
func available_to_read() -> int:
	return filled_bytes

## Returns the free space available for writing.
func available_to_write() -> int:
	return capacity - filled_bytes

## Pushes new byte data into the circular buffer. Returns count of bytes accepted.
func push(data: PackedByteArray) -> int:
	var bytes_to_write: int = min(data.size(), available_to_write())
	if bytes_to_write <= 0:
		return 0
		
	for i in range(bytes_to_write):
		buffer[write_cursor] = data[i]
		write_cursor = (write_cursor + 1) % capacity
		
	filled_bytes += bytes_to_write
	return bytes_to_write

## Pops and returns up to byte_count bytes from the circular buffer.
func pop(byte_count: int) -> PackedByteArray:
	var bytes_to_read: int = min(byte_count, available_to_read())
	if bytes_to_read <= 0:
		return PackedByteArray()
		
	var out = PackedByteArray()
	out.resize(bytes_to_read)
	
	for i in range(bytes_to_read):
		out[i] = buffer[read_cursor]
		read_cursor = (read_cursor + 1) % capacity
		
	filled_bytes -= bytes_to_read
	return out

## Clears all buffer contents and resets read/write cursors.
func clear() -> void:
	read_cursor = 0
	write_cursor = 0
	filled_bytes = 0
