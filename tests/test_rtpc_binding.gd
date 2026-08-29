class_name TestRTPCBinding
extends RefCounted

const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Binding without curve passes raw input
	var binding_raw = RTPCBindingClass.new(&"Volume", &"volume_db", null, RTPCBindingClass.Operation.ADD)
	if not is_equal_approx(binding_raw.evaluate(5.0), 5.0):
		failures.append("Test 1 Failed: Raw binding expected 5.0, got %f" % binding_raw.evaluate(5.0))
		
	# Test 2: Binding with Linear Curve
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, -80.0))
	curve.add_point(Vector2(100.0, 0.0))
	curve.bake()
	
	var binding_curve = RTPCBindingClass.new(&"Health", &"volume_db", curve, RTPCBindingClass.Operation.ADD)
	var out_mid = binding_curve.evaluate(50.0) # Mid point should be approximately -40.0
	if not is_equal_approx(out_mid, -40.0):
		failures.append("Test 2 Failed: Curve mid evaluation expected -40.0, got %f" % out_mid)
		
	# Test 3: Math Operations (ADD, MULTIPLY, OVERRIDE)
	var add_res = binding_raw.apply_to(10.0, 5.0)
	if not is_equal_approx(add_res, 15.0):
		failures.append("Test 3a Failed: Operation.ADD expected 15.0, got %f" % add_res)
		
	var mult_binding = RTPCBindingClass.new(&"Pitch", &"pitch_scale", null, RTPCBindingClass.Operation.MULTIPLY)
	var mult_res = mult_binding.apply_to(2.0, 1.5)
	if not is_equal_approx(mult_res, 3.0):
		failures.append("Test 3b Failed: Operation.MULTIPLY expected 3.0, got %f" % mult_res)
		
	var override_binding = RTPCBindingClass.new(&"State", &"volume_db", null, RTPCBindingClass.Operation.OVERRIDE)
	var override_res = override_binding.apply_to(-10.0, 0.0)
	if not is_equal_approx(override_res, 0.0):
		failures.append("Test 3c Failed: Operation.OVERRIDE expected 0.0, got %f" % override_res)
		
	return failures
