@tool
class_name MusicStingerQueue
extends RefCounted

## Manages quantized musical stingers (victory jingles, danger brass stabs) with automatic ducking of background music.

enum StingerSync {
	IMMEDIATE,
	NEXT_BEAT,
	NEXT_BAR
}

signal stinger_played(stream: AudioStream, duck_db: float)

class PendingStinger:
	var stream: AudioStream
	var sync_mode: StingerSync
	var duck_music_db: float
	var duck_duration_sec: float
	
	func _init(p_stream: AudioStream, p_sync: StingerSync, p_duck: float, p_dur: float) -> void:
		stream = p_stream
		sync_mode = p_sync
		duck_music_db = p_duck
		duck_duration_sec = p_dur

var queue: Array[PendingStinger] = []
var is_ducking: bool = false
var ducking_timer: float = 0.0
var current_duck_db: float = 0.0
var active_duck_target_db: float = 0.0

func trigger_stinger(stream: AudioStream, sync: StingerSync = StingerSync.NEXT_BEAT, duck_db: float = -8.0, duck_dur: float = 2.0) -> void:
	var item = PendingStinger.new(stream, sync, duck_db, duck_dur)
	if sync == StingerSync.IMMEDIATE:
		_execute_stinger(item)
	else:
		queue.append(item)

func notify_beat() -> void:
	var pending = queue.filter(func(s): return s.sync_mode == StingerSync.NEXT_BEAT)
	for p in pending:
		queue.erase(p)
		_execute_stinger(p)

func notify_bar() -> void:
	var pending = queue.filter(func(s): return s.sync_mode == StingerSync.NEXT_BAR)
	for p in pending:
		queue.erase(p)
		_execute_stinger(p)

func _execute_stinger(stinger: PendingStinger) -> void:
	is_ducking = true
	ducking_timer = stinger.duck_duration_sec
	active_duck_target_db = stinger.duck_music_db
	stinger_played.emit(stinger.stream, stinger.duck_music_db)

func update(delta: float) -> void:
	if is_ducking:
		ducking_timer -= delta
		current_duck_db = move_toward(current_duck_db, active_duck_target_db, 60.0 * delta)
		if ducking_timer <= 0.0:
			is_ducking = false
	else:
		current_duck_db = move_toward(current_duck_db, 0.0, 20.0 * delta)

func get_music_ducking_db() -> float:
	return current_duck_db
