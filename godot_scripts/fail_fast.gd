class_name FailFast
extends RefCounted

static var test_capture_mode: bool = false
static var last_error_message: String = ""


static func clear_last_error() -> void:
	last_error_message = ""


static func has_error() -> bool:
	return last_error_message != ""


static func fail(message: String) -> void:
	var full_msg: String = message if message.begins_with("CRITICAL:") else "CRITICAL: " + message
	last_error_message = full_msg
	if test_capture_mode:
		return
	push_error(full_msg)
	assert(false, full_msg)


static func require_true(condition: bool, message: String) -> bool:
	if not condition:
		fail(message)
		return false
	return true


static func require_positive_int(val: int, name: String) -> bool:
	if val <= 0:
		fail("CRITICAL: %s must be positive, got %d." % [name, val])
		return false
	return true


static func require_non_negative_int(val: int, name: String) -> bool:
	if val < 0:
		fail("CRITICAL: %s must be non-negative, got %d." % [name, val])
		return false
	return true


static func require_in_range_int(val: int, min_val: int, max_val: int, name: String) -> bool:
	if val < min_val or val > max_val:
		fail("CRITICAL: %s must be in [%d, %d], got %d." % [name, min_val, max_val, val])
		return false
	return true


static func require_positive_float(val: float, name: String) -> bool:
	if is_nan(val) or is_inf(val) or val <= 0.0:
		fail("CRITICAL: %s must be a positive number, got %s." % [name, str(val)])
		return false
	return true


static func require_non_negative_float(val: float, name: String) -> bool:
	if is_nan(val) or is_inf(val) or val < 0.0:
		fail("CRITICAL: %s must be a non-negative number, got %s." % [name, str(val)])
		return false
	return true


static func require_in_range_float(val: float, min_val: float, max_val: float, name: String) -> bool:
	if is_nan(val) or is_inf(val) or val < min_val or val > max_val:
		fail("CRITICAL: %s must be in [%f, %f], got %s." % [name, min_val, max_val, str(val)])
		return false
	return true


static func require_non_empty_str(val: String, name: String) -> bool:
	if val.strip_edges().is_empty():
		fail("CRITICAL: %s must not be empty." % name)
		return false
	return true


static func require_not_null(val: Object, name: String) -> bool:
	if val == null:
		fail("CRITICAL: %s must not be null." % name)
		return false
	return true
