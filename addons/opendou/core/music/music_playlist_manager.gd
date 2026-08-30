@tool
class_name MusicPlaylistManager
extends RefCounted

## Manages non-linear interactive music playlists and state hierarchies (e.g. Intro -> Loop A (2-4x) -> Bridge -> Loop B (Loop) -> Outro).

signal segment_advanced(from_segment: StringName, to_segment: StringName)
signal playlist_finished()

class PlaylistItem:
	var segment_name: StringName = &"Segment"
	var loop_count_min: int = 1
	var loop_count_max: int = 1
	var target_loops: int = 1
	var current_loops: int = 0
	
	func _init(p_name: StringName = &"Segment", p_min: int = 1, p_max: int = 1) -> void:
		segment_name = p_name
		loop_count_min = p_min
		loop_count_max = p_max
		roll_target_loops()
		
	func roll_target_loops() -> void:
		if loop_count_min == loop_count_max:
			target_loops = loop_count_min
		else:
			target_loops = randi_range(loop_count_min, loop_count_max)
		current_loops = 0

var items: Array[PlaylistItem] = []
var current_index: int = 0
var is_active: bool = false
var is_looping_playlist: bool = true

func add_item(segment_name: StringName, min_loops: int = 1, max_loops: int = 1) -> PlaylistItem:
	var it = PlaylistItem.new(segment_name, min_loops, max_loops)
	items.append(it)
	return it

func remove_item_at(idx: int) -> void:
	if idx >= 0 and idx < items.size():
		items.remove_at(idx)
		if current_index >= items.size() and not items.is_empty():
			current_index = items.size() - 1

func move_item_up(idx: int) -> void:
	if idx > 0 and idx < items.size():
		var temp = items[idx]
		items[idx] = items[idx - 1]
		items[idx - 1] = temp

func move_item_down(idx: int) -> void:
	if idx >= 0 and idx < items.size() - 1:
		var temp = items[idx]
		items[idx] = items[idx + 1]
		items[idx + 1] = temp

func get_current_segment_name() -> StringName:
	if items.is_empty() or current_index >= items.size():
		return &""
	return items[current_index].segment_name

func start_playlist() -> StringName:
	if items.is_empty():
		return &""
	current_index = 0
	is_active = true
	items[0].roll_target_loops()
	return items[0].segment_name

func stop_playlist() -> void:
	is_active = false
	current_index = 0
	for it in items:
		it.current_loops = 0

## Advances a loop count for the current playlist segment. If target loop count is reached, advances to the next segment in hierarchy.
func advance_loop() -> StringName:
	if not is_active or items.is_empty():
		return &""
		
	var cur_item = items[current_index]
	cur_item.current_loops += 1
	
	if cur_item.current_loops >= cur_item.target_loops:
		var old_seg = cur_item.segment_name
		if current_index < items.size() - 1:
			current_index += 1
			items[current_index].roll_target_loops()
			var new_seg = items[current_index].segment_name
			segment_advanced.emit(old_seg, new_seg)
			return new_seg
		elif is_looping_playlist:
			current_index = 0
			items[0].roll_target_loops()
			var new_seg = items[0].segment_name
			segment_advanced.emit(old_seg, new_seg)
			return new_seg
		else:
			is_active = false
			playlist_finished.emit()
			return &""
			
	return cur_item.segment_name

func serialize() -> Array:
	var arr = []
	for it in items:
		arr.append({
			"segment_name": str(it.segment_name),
			"min_loops": it.loop_count_min,
			"max_loops": it.loop_count_max
		})
	return arr

func deserialize(arr: Array) -> void:
	items.clear()
	for d in arr:
		if d is Dictionary:
			var s_name = StringName(str(d.get("segment_name", "Segment")))
			var min_l = int(d.get("min_loops", 1))
			var max_l = int(d.get("max_loops", 1))
			add_item(s_name, min_l, max_l)
