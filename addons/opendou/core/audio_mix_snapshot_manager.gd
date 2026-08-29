@tool
class_name AudioMixSnapshotManager
extends RefCounted

## Manages global mixing snapshots with smooth multi-bus interpolation, weighted stacking, and AudioServer synchronization.

signal snapshot_changed(snapshot_name: StringName)

var current_snapshot: AudioMixSnapshot = null
var target_snapshot: AudioMixSnapshot = null

var is_transitioning: bool = false
var transition_time: float = 1.0
var transition_progress: float = 1.0

# Interpolated state cache per bus:
# { &"Master": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false } }
var current_interpolated_state: Dictionary = {}
var registered_snapshots: Dictionary = {}

func _init() -> void:
	_setup_default_snapshots()

func _setup_default_snapshots() -> void:
	# 1. Default Neutral Snapshot
	var default_snap = AudioMixSnapshot.new(&"Default", {
		&"Master": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false },
		&"Music": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false },
		&"SFX": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false },
		&"Voice": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false }
	}, 1.0)
	register_snapshot(default_snap)
	
	# 2. Tinnitus / Explosion Deafen Snapshot
	var tinnitus_snap = AudioMixSnapshot.new(&"Tinnitus_Explosion", {
		&"Master": { "volume_db": -2.0, "lpf_hz": 600.0, "hpf_hz": 200.0, "mute": false },
		&"Music": { "volume_db": -18.0, "lpf_hz": 400.0, "hpf_hz": 20.0, "mute": false },
		&"SFX": { "volume_db": -12.0, "lpf_hz": 500.0, "hpf_hz": 20.0, "mute": false },
		&"Voice": { "volume_db": -4.0, "lpf_hz": 800.0, "hpf_hz": 20.0, "mute": false }
	}, 0.3)
	register_snapshot(tinnitus_snap)
	
	# 3. Pause Menu Snapshot
	var pause_snap = AudioMixSnapshot.new(&"Pause_Menu", {
		&"Master": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false },
		&"Music": { "volume_db": -4.0, "lpf_hz": 1200.0, "hpf_hz": 20.0, "mute": false },
		&"SFX": { "volume_db": -24.0, "lpf_hz": 400.0, "hpf_hz": 20.0, "mute": false },
		&"Voice": { "volume_db": -60.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": true }
	}, 0.5)
	register_snapshot(pause_snap)
	
	# 4. Underwater Snapshot
	var underwater_snap = AudioMixSnapshot.new(&"Underwater", {
		&"Master": { "volume_db": -1.5, "lpf_hz": 450.0, "hpf_hz": 80.0, "mute": false },
		&"Music": { "volume_db": -6.0, "lpf_hz": 350.0, "hpf_hz": 20.0, "mute": false },
		&"SFX": { "volume_db": -4.0, "lpf_hz": 400.0, "hpf_hz": 20.0, "mute": false },
		&"Voice": { "volume_db": -10.0, "lpf_hz": 500.0, "hpf_hz": 20.0, "mute": false }
	}, 0.8)
	register_snapshot(underwater_snap)
	
	apply_snapshot_instant(&"Default")

func register_snapshot(snapshot: AudioMixSnapshot) -> void:
	registered_snapshots[snapshot.snapshot_name] = snapshot

func apply_snapshot_instant(snapshot_name: StringName) -> void:
	if not registered_snapshots.has(snapshot_name):
		return
	current_snapshot = registered_snapshots[snapshot_name]
	target_snapshot = current_snapshot
	is_transitioning = false
	transition_progress = 1.0
	current_interpolated_state.clear()
	
	for bus in current_snapshot.bus_settings.keys():
		current_interpolated_state[bus] = current_snapshot.bus_settings[bus].duplicate()
		
	snapshot_changed.emit(snapshot_name)

func transition_to(snapshot_name: StringName, custom_blend_time: float = -1.0) -> void:
	if not registered_snapshots.has(snapshot_name):
		return
	var new_target: AudioMixSnapshot = registered_snapshots[snapshot_name]
	if new_target == current_snapshot and not is_transitioning:
		return
		
	target_snapshot = new_target
	transition_time = custom_blend_time if custom_blend_time >= 0.0 else target_snapshot.default_blend_time
	if transition_time <= 0.001:
		apply_snapshot_instant(snapshot_name)
		return
		
	transition_progress = 0.0
	is_transitioning = true

func update(delta: float) -> void:
	if not is_transitioning:
		return
		
	transition_progress += delta / transition_time
	var t = clampf(transition_progress, 0.0, 1.0)
	# S-curve smoothstep easing
	var smooth_t = t * t * (3.0 - 2.0 * t)
	
	var from_settings = current_snapshot.bus_settings if current_snapshot else {}
	var to_settings = target_snapshot.bus_settings if target_snapshot else {}
	
	var all_buses: Array = []
	for b in from_settings.keys(): if not all_buses.has(b): all_buses.append(b)
	for b in to_settings.keys(): if not all_buses.has(b): all_buses.append(b)
	
	for bus in all_buses:
		var from_val = from_settings.get(bus, { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false })
		var to_val = to_settings.get(bus, { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false })
		
		var vol = lerpf(from_val.get("volume_db", 0.0), to_val.get("volume_db", 0.0), smooth_t)
		var lpf = lerpf(from_val.get("lpf_hz", 20000.0), to_val.get("lpf_hz", 20000.0), smooth_t)
		var hpf = lerpf(from_val.get("hpf_hz", 20.0), to_val.get("hpf_hz", 20.0), smooth_t)
		var mute = to_val.get("mute", false) if smooth_t >= 0.5 else from_val.get("mute", false)
		
		current_interpolated_state[bus] = {
			"volume_db": vol,
			"lpf_hz": lpf,
			"hpf_hz": hpf,
			"mute": mute
		}
		
	if transition_progress >= 1.0:
		is_transitioning = false
		current_snapshot = target_snapshot
		snapshot_changed.emit(current_snapshot.snapshot_name)

## Retrieves current interpolated parameters for a specific bus.
func get_bus_state(bus_name: StringName) -> Dictionary:
	if current_interpolated_state.has(bus_name):
		return current_interpolated_state[bus_name]
	return { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false }
