@tool
class_name OpenDouTrackLaneData
extends RefCounted

## Model and UI references for a single interactive stem layer in OpenDouMusicTimeline.

var name: String = "Track"
var min_intensity: float = 0.0
var max_intensity: float = 1.0
var color: Color = Color.WHITE
var is_muted: bool = false
var is_solo: bool = false
var volume_db: float = 0.0
var current_gain: float = 0.0
var audio_file_path: String = ""
var left_trim_ratio: float = 0.0 # 0.0 to 1.0
var right_trim_ratio: float = 1.0 # 0.0 to 1.0
var sub_tracks: Array[Dictionary] = [] # [{"name": "Var 1", "audio_path": "...", "weight": 1.0}]
var active_sub_index: int = 0
var is_random_mode: bool = true

# Bus Routing & Automation Curves (TASK-032)
var bus_name: StringName = &"Master"
var automation_enabled: bool = false
var automation_parameter: int = 0 # 0 = Volume, 1 = LPF Cutoff, 2 = RTPC: CombatIntensity
var automation_points: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.5, 0.6), Vector2(1.0, 1.0)]
var selected_point_index: int = -1

var row_container: HBoxContainer
var header_panel: PanelContainer
var mute_btn: Button
var solo_btn: Button
var vol_slider: HSlider
var auto_btn: Button
var bus_opt: OptionButton
var file_btn: Button
var var_btn: Button
var delete_btn: Button
var file_label: Label
var meter_rect: Control
var waveform_canvas: Control

# Collapsible Automation Sub-Row
var auto_row: HBoxContainer
var auto_param_opt: OptionButton
var auto_canvas: Control

func evaluate_automation_value(ratio: float) -> float:
	if automation_points.is_empty():
		return 1.0
	if ratio <= automation_points[0].x:
		return automation_points[0].y
	if ratio >= automation_points[automation_points.size() - 1].x:
		return automation_points[automation_points.size() - 1].y
	for i in range(automation_points.size() - 1):
		var p0 = automation_points[i]
		var p1 = automation_points[i + 1]
		if ratio >= p0.x and ratio <= p1.x:
			var span = p1.x - p0.x
			if span <= 0.0001:
				return p0.y
			var t = (ratio - p0.x) / span
			return lerpf(p0.y, p1.y, t)
	return 1.0
