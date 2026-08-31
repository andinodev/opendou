class_name TestParameterArea3DClass
extends RefCounted

## Unit and Integration Tests for OpenDouParameterArea3D (TASK-055 - Task 1)

const OpenDouParameterArea3DClass = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Instantiation and default properties
	var area = OpenDouParameterArea3DClass.new()
	if area == null:
		failures.append("Test 1 Failed: OpenDouParameterArea3D instantiation failed")
		return failures
	if area.parameter_name != &"" or area.interpolation_mode != 0 or area.rtpc_priority != 0:
		failures.append("Test 1 Failed: Default property values mismatch")

	# Test 2: Radial Center Penetration (0.0 at edge, 1.0 at center)
	area.parameter_name = &"Radiation_Level"
	area.interpolation_mode = 0 # CENTER_RADIAL
	area.min_value = 0.0
	area.max_value = 100.0
	var calc_center = area.calculate_penetration_at(Vector3.ZERO, Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_center, 1.0):
		failures.append("Test 2 Failed: Radial penetration at center should be 1.0, got %.3f" % calc_center)
	var calc_edge = area.calculate_penetration_at(Vector3(10, 0, 0), Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_edge, 0.0):
		failures.append("Test 2 Failed: Radial penetration at edge should be 0.0, got %.3f" % calc_edge)

	# Test 3: Cylindrical Ignore-Y Calculation
	area.ignore_y_axis = true
	var calc_y_offset = area.calculate_penetration_at(Vector3(0, 50, 0), Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_y_offset, 1.0):
		failures.append("Test 3 Failed: Radial ignore_y_axis should be 1.0 despite high Y, got %.3f" % calc_y_offset)

	# Test 4: Axis Gradient Penetration (0.0 to 1.0 along gradient_axis)
	area.interpolation_mode = 1 # AXIS_GRADIENT
	area.gradient_axis = Vector3.UP
	var calc_bottom = area.calculate_penetration_at(Vector3(0, -5, 0), Vector3.ZERO, Vector3(5, 5, 5))
	if not is_equal_approx(calc_bottom, 0.0):
		failures.append("Test 4 Failed: Axis gradient at bottom should be 0.0, got %.3f" % calc_bottom)
	var calc_top = area.calculate_penetration_at(Vector3(0, 5, 0), Vector3.ZERO, Vector3(5, 5, 5))
	if not is_equal_approx(calc_top, 1.0):
		failures.append("Test 4 Failed: Axis gradient at top should be 1.0, got %.3f" % calc_top)

	# Test 5: Conflict Resolution: MAX blend operation
	var val_max = OpenDouParameterArea3DClass.resolve_conflict([40.0, 75.0, 20.0], 0) # 0: MAX
	if val_max != 75.0:
		failures.append("Test 5 Failed: MAX blend operation should yield 75.0, got %.1f" % val_max)

	# Test 6: Conflict Resolution: ADD blend operation clamped to min/max
	var val_add = OpenDouParameterArea3DClass.resolve_conflict([30.0, 40.0], 1, 0.0, 100.0) # 1: ADD
	if val_add != 70.0:
		failures.append("Test 6 Failed: ADD blend operation should yield 70.0, got %.1f" % val_add)

	# Test 7: Conflict Resolution: REPLACE blend operation by Priority
	var val_rep = OpenDouParameterArea3DClass.resolve_priority_values([
		{"val": 30.0, "prio": 1},
		{"val": 90.0, "prio": 5},
		{"val": 10.0, "prio": 2}
	])
	if val_rep != 90.0:
		failures.append("Test 7 Failed: REPLACE priority resolution should yield 90.0, got %.1f" % val_rep)

	# Test 8: Target Snapshot Registration
	area.target_snapshot = &"Underwater_Mix"
	if area.target_snapshot != &"Underwater_Mix":
		failures.append("Test 8 Failed: target_snapshot property failed")

	# Test 9: Despawn & tree_exited Safety Handler
	var dummy_target = Node3D.new()
	area.register_target_entered(dummy_target)
	if not area.has_active_target(dummy_target):
		failures.append("Test 9 Failed: dummy_target should be registered")
	dummy_target.free()
	area.cleanup_invalid_targets()
	if area.get_active_targets_count() != 0:
		failures.append("Test 9 Failed: Freed target should be safely removed")

	# Test 10: Boundary Hysteresis Debouncing
	area.edge_hysteresis_ms = 150.0
	var is_debounced = area.evaluate_hysteresis_debounce(0.01, 50.0) # 50 ms elapsed is < 150 ms
	if not is_debounced:
		failures.append("Test 10 Failed: 50ms is below 150ms hysteresis threshold and should be debounced (return true)")

	area.free()
	return failures
