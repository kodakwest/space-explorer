extends RefCounted

const StarCatalogScript: Script = preload("res://scripts/star_catalog.gd")

var _failures: Array[String] = []

func test_star_catalog() -> void:
	_report_failures(run())

func run() -> Array[String]:
	_failures.clear()
	var catalog: StarCatalog = StarCatalogScript.new()

	_assert_equal(catalog.get_star_count(), 126, "bright_stars.json loads expected star count")

	var sirius: Dictionary = catalog.get_star("Sirius")
	_assert_true(not sirius.is_empty(), "get_star(\"Sirius\") returns a star")
	for field in ["name", "bayer", "mag", "dist_ly", "spectral", "ci", "x", "y", "z"]:
		_assert_true(sirius.has(field), "Sirius has field %s" % field)

	var brightest: Array[Dictionary] = catalog.get_brightest(5)
	_assert_equal(brightest.size(), 5, "get_brightest(5) returns exactly 5 entries")
	for i in range(1, brightest.size()):
		var previous_mag: float = float(brightest[i - 1].get("mag", 99.0))
		var current_mag: float = float(brightest[i].get("mag", 99.0))
		_assert_true(previous_mag <= current_mag, "brightest stars are sorted by magnitude")

	var orion_matches: Array[Dictionary] = catalog.search_stars("Orion")
	_assert_true(orion_matches.size() > 0, "search_stars(\"Orion\") returns constellation matches")

	for ci in [-0.3, 0.0, 0.65, 1.5, 4.0]:
		_assert_color_valid(catalog.star_to_color(ci), "star_to_color(%s) returns a valid color" % ci)

	return _failures

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])

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
	assert(failures.is_empty(), "test_star_catalog failed")
