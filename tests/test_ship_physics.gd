extends RefCounted

const ShipScene: PackedScene = preload("res://scenes/ship.tscn")

var _failures: Array[String] = []

func test_ship_physics() -> void:
	_report_failures(run())

func run() -> Array[String]:
	_failures.clear()
	var ship = ShipScene.instantiate()
	var delta: float = 1.0 / 60.0

	ship.velocity = Vector3(10.0, 0.0, 0.0)
	var dragged_velocity: Vector3 = ship.calculate_velocity_after_input(ship.velocity, Vector3.ZERO, false, delta)
	_assert_true(dragged_velocity.length() < ship.velocity.length(), "zero input velocity decays via drag")

	var forward_velocity: Vector3 = ship.calculate_velocity_after_input(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), false, delta)
	_assert_true(forward_velocity.z < 0.0, "forward input accelerates along negative Z")

	var right_velocity: Vector3 = ship.calculate_velocity_after_input(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), false, delta)
	_assert_true(right_velocity.x > 0.0, "right input accelerates along positive X")

	var normal_speed: float = forward_velocity.length()
	var boost_speed: float = ship.calculate_velocity_after_input(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), true, delta).length()
	_assert_true(boost_speed > normal_speed, "boost multiplier increases acceleration")

	var capped_normal: Vector3 = ship.calculate_velocity_after_input(Vector3(9999.0, 0.0, 0.0), Vector3.ZERO, false, delta)
	_assert_true(capped_normal.length() <= ship.max_speed + 0.01, "speed is capped at max_speed")

	var boost_limit: float = ship.get_speed_limit(true)
	var capped_boost: Vector3 = ship.calculate_velocity_after_input(Vector3(9999.0, 0.0, 0.0), Vector3.ZERO, true, delta)
	_assert_true(capped_boost.length() <= boost_limit + 0.01, "boost speed is capped at boost_max_speed")

	ship.free()
	return _failures

func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _report_failures(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	assert(failures.is_empty(), "test_ship_physics failed")
