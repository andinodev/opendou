class_name TestRTPCValue
extends RefCounted

const RTPCValueClass = preload("res://addons/opendou/runtime/rtpc_value.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Initial state
	var rtpc = RTPCValueClass.new(10.0, 10.0, 10.0)
	if rtpc.current_value != 10.0 or rtpc.target_value != 10.0:
		failures.append("Test 1 Failed: Initial value not set correctly")
	
	# Test 2: Attack interpolation
	rtpc.target_value = 20.0
	rtpc.attack_speed = 5.0 # 5 units per sec
	rtpc.interpolate(1.0) # 1 sec delta
	if not is_equal_approx(rtpc.current_value, 15.0):
		failures.append("Test 2 Failed: Attack interpolation expected 15.0, got %f" % rtpc.current_value)
		
	# Test 3: Clamping at target during attack
	rtpc.interpolate(2.0) # 2 more seconds -> should reach 20.0 (not 25.0)
	if not is_equal_approx(rtpc.current_value, 20.0):
		failures.append("Test 3 Failed: Attack clamp expected 20.0, got %f" % rtpc.current_value)
		
	# Test 4: Release interpolation
	rtpc.target_value = 0.0
	rtpc.release_speed = 10.0 # 10 units per sec
	rtpc.interpolate(1.0) # 1 sec delta -> from 20 to 10
	if not is_equal_approx(rtpc.current_value, 10.0):
		failures.append("Test 4 Failed: Release interpolation expected 10.0, got %f" % rtpc.current_value)
		
	# Test 5: Immediate set
	rtpc.set_value_immediate(50.0)
	if rtpc.current_value != 50.0 or rtpc.target_value != 50.0:
		failures.append("Test 5 Failed: Immediate set value failed")
		
	return failures
