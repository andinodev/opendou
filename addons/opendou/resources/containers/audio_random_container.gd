@tool
class_name AudioRandomContainer
extends AudioLogicNode

## Selects child logic nodes randomly or via shuffle, applying stochastic volume/pitch jitter.

@export var children: Array[AudioLogicNode] = []
@export var use_shuffle: bool = true
@export var no_repeat_count: int = 1
@export var pitch_jitter_range: Vector2 = Vector2(0.0, 0.0) # min/max pitch multiplier delta (e.g. -0.05, +0.05)
@export var volume_jitter_db_range: Vector2 = Vector2(0.0, 0.0) # min/max volume delta in dB (e.g. -2.0, 0.0)

var is_shuffle: bool:
	get: return use_shuffle
	set(val): use_shuffle = val

var pitch_jitter: float:
	get: return pitch_jitter_range.y
	set(val): pitch_jitter_range = Vector2(-absf(val), absf(val))

var volume_jitter_db: float:
	get: return volume_jitter_db_range.y
	set(val): volume_jitter_db_range = Vector2(-absf(val), 0.0)

var play_history: Array[int] = []

func _init(p_children: Array[AudioLogicNode] = []) -> void:
	children = p_children
	play_history = []

## Adds a child node to the container.
func add_child_node(child: AudioLogicNode) -> void:
	if child:
		children.append(child)

## Picks a random index taking shuffle and no-repeat rules into account.
func pick_random_index() -> int:
	var total: int = children.size()
	if total == 0:
		return -1
	if total == 1:
		return 0
		
	var candidates: Array[int] = []
	for i in range(total):
		if not use_shuffle or not play_history.has(i):
			candidates.append(i)
			
	# If all items are in history, reset history and use all indices
	if candidates.is_empty():
		play_history.clear()
		for i in range(total):
			candidates.append(i)
			
	var chosen_index: int = candidates[randi() % candidates.size()]
	
	if use_shuffle:
		play_history.append(chosen_index)
		# Keep history capped to no_repeat_count (or total - 1)
		var max_history: int = clampi(no_repeat_count, 1, total - 1)
		while play_history.size() > max_history:
			play_history.pop_front()
			
	return chosen_index

func resolve(context: AudioPlaybackContext, out_voices: Array[ResolvedVoice]) -> bool:
	if children.is_empty():
		return false
		
	var selected_idx: int = pick_random_index()
	if selected_idx < 0 or selected_idx >= children.size():
		return false
		
	var selected_child: AudioLogicNode = children[selected_idx]
	if not selected_child:
		return false
		
	# Calculate random pitch and volume offsets
	var rand_pitch_delta: float = randf_range(pitch_jitter_range.x, pitch_jitter_range.y) if pitch_jitter_range != Vector2.ZERO else 0.0
	var rand_vol_delta: float = randf_range(volume_jitter_db_range.x, volume_jitter_db_range.y) if volume_jitter_db_range != Vector2.ZERO else 0.0
	
	var temp_voices: Array[ResolvedVoice] = []
	if selected_child.resolve(context, temp_voices):
		for voice in temp_voices:
			voice.pitch_modifier *= (1.0 + rand_pitch_delta)
			voice.volume_offset_db += rand_vol_delta
			out_voices.append(voice)
		return true
		
	return false

func is_deterministic() -> bool:
	return false
