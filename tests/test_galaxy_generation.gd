extends RefCounted

const StarFieldScript: Script = preload("res://scripts/star_field.gd")

var _failures: Array[String] = []

func test_galaxy_generation() -> void:
	_report_failures(run())

func run() -> Array[String]:
	_failures.clear()
	var star_field = StarFieldScript.new()
	star_field.field_radius = 1400.0
	star_field.core_radius = 135.0
	star_field.disk_thickness = 70.0

	var core_positions: int = 0
	for _i in 300:
		var position: Vector3 = star_field._galaxy_position()
		var radial_distance: float = Vector2(position.x, position.z).length()
		_assert_true(radial_distance <= star_field.field_radius + 0.01, "_galaxy_position stays inside field_radius")
		_assert_true(absf(position.y) < star_field.field_radius, "_galaxy_position y remains in galaxy bounds")
		if radial_distance <= star_field.core_radius:
			core_positions += 1
	_assert_true(core_positions > 0, "_galaxy_position includes core-radius stars")

	for edge in [[0.0, 0.0], [0.17, 0.5], [1.0, 1.0], [2.0, -1.0]]:
		var color: Color = star_field._background_star_color(float(edge[0]), float(edge[1]))
		_assert_color_valid(color, "_background_star_color handles edge input %s" % str(edge))

	return _failures

func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _assert_color_valid(color: Color, message: String) -> void:
	_assert_true(
		is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
		and color.r >= 0.0 and color.r <= 1.0
		and color.g >= 0.0 and color.g <= 1.0
		and color.b >= 0.0 and color.b <= 1.0
		and color.a >= 0.0 and color.a <= 1.0,
		message
	)

func _report_failures(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	assert(failures.is_empty(), "test_galaxy_generation failed")
