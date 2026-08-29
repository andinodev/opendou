class_name TestRadarView
extends RefCounted

const OpenDouRadarViewClass = preload("res://addons/opendou/editor/opendou_radar_view.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var radar = OpenDouRadarViewClass.new()
	radar.size = Vector2(300, 300)
	radar.max_view_distance_m = 50.0
	
	var center = Vector2(150, 150)
	var radius = 100.0
	
	# Test 1: Origin projection
	var p_origin = radar.world_to_radar_pixel(Vector3.ZERO, center, radius)
	if not p_origin.is_equal_approx(center):
		failures.append("Test 1 Failed: Origin (0,0,0) should project to center (150,150), got %s" % str(p_origin))
		
	# Test 2: Offset projection (25m along X -> +50px along X)
	var p_offset = radar.world_to_radar_pixel(Vector3(25.0, 0.0, 0.0), center, radius)
	var expected = Vector2(200.0, 150.0)
	if not p_offset.is_equal_approx(expected):
		failures.append("Test 2 Failed: 25m offset along X expected (200, 150), got %s" % str(p_offset))
		
	# Test 3: Telemetry metrics update
	radar.update_telemetry_metrics(12, 36, 0.45, 1024)
	if radar.physical_count != 12 or radar.virtual_count != 36 or not is_equal_approx(radar.dsp_time_ms, 0.45):
		failures.append("Test 3 Failed: Telemetry metrics update mismatch")
		
	return failures
