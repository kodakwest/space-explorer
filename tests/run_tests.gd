extends SceneTree

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_star_catalog.gd",
	"res://tests/test_ship_physics.gd",
	"res://tests/test_galaxy_generation.gd",
]

func _initialize() -> void:
	var total_failures: int = 0
	for script_path in TEST_SCRIPTS:
		var test_script: Script = load(script_path) as Script
		var test: RefCounted = test_script.new() as RefCounted
		var failures: Array = test.call("run")
		if failures.is_empty():
			print("%s: PASS" % script_path)
		else:
			total_failures += failures.size()
			push_error("%s: FAIL" % script_path)
			for failure in failures:
				push_error("  %s" % failure)

	if total_failures == 0:
		print("All tests passed.")
		quit(0)
	else:
		push_error("%d test failure(s)." % total_failures)
		quit(1)
