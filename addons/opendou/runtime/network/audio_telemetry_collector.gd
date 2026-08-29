class_name AudioTelemetryCollector
extends RefCounted

## Collects runtime telemetry snapshots of active voices, spatial positions, and RAM usage for the profiler.

class VoiceTelemetryData:
	var event_name: StringName = &""
	var volume_db: float = 0.0
	var world_position: Vector3 = Vector3.ZERO
	var is_virtual: bool = false
	var dynamic_weight: float = 0.0

	func _init(p_name: StringName = &"", p_vol: float = 0.0, p_pos: Vector3 = Vector3.ZERO, p_virt: bool = false, p_weight: float = 0.0) -> void:
		event_name = p_name
		volume_db = p_vol
		world_position = p_pos
		is_virtual = p_virt
		dynamic_weight = p_weight

class AudioTelemetrySnapshot:
	var physical_voices: int = 0
	var virtual_voices: int = 0
	var total_dsp_cpu_time_ms: float = 0.0
	var prefetch_ram_kb: int = 0
	var voices: Array[VoiceTelemetryData] = []

## Gathers a complete runtime telemetry snapshot from the audio engine managers.
static func collect_snapshot(voice_pool: RefCounted, active_instances: Array, bank_manager: RefCounted = null, dsp_cpu_time_ms: float = 0.0) -> AudioTelemetrySnapshot:
	var snap = AudioTelemetrySnapshot.new()
	snap.total_dsp_cpu_time_ms = dsp_cpu_time_ms
	
	if voice_pool and voice_pool.has_method("get_active_physical_count"):
		snap.physical_voices = voice_pool.call("get_active_physical_count")
	if voice_pool and voice_pool.has_method("get_active_virtual_count"):
		snap.virtual_voices = voice_pool.call("get_active_virtual_count", active_instances)
		
	# Calculate total SoundBank prefetch memory
	if bank_manager and "loaded_banks" in bank_manager:
		var total_bytes: int = 0
		var banks_dict = bank_manager.get("loaded_banks")
		for b_name in banks_dict:
			var bank = banks_dict[b_name]
			if "prefetch_block_size" in bank:
				total_bytes += bank.get("prefetch_block_size")
		snap.prefetch_ram_kb = int(total_bytes / 1024)
		
	# Extract voice metrics (top active instances)
	for inst in active_instances:
		if not inst or not inst.has_method("is_playing") or not inst.call("is_playing"):
			continue
			
		var ev_name: StringName = inst.definition.event_name if "definition" in inst and inst.definition else &"Unknown"
		var vol: float = inst.calculated_volume_db if "calculated_volume_db" in inst else 0.0
		var pos: Vector3 = inst.emitter_position if "emitter_position" in inst else Vector3.ZERO
		var is_virt: bool = (inst.voice_state == 2) if "voice_state" in inst else false # 2 = STATE_VIRTUAL
		var weight: float = inst.current_weight if "current_weight" in inst else 0.0
		
		snap.voices.append(VoiceTelemetryData.new(ev_name, vol, pos, is_virt, weight))
		
	return snap
