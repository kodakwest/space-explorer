extends Node3D

@export var star_count: int = 700
@export var field_radius: float = 900.0
@export var min_star_size: float = 0.05
@export var max_star_size: float = 0.22

func _ready() -> void:
	_generate_stars()

func _generate_stars() -> void:
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 1.0
	star_mesh.height = 2.0

	var colors: Array[Color] = [
		Color(1.0, 1.0, 1.0),
		Color(0.75, 0.86, 1.0),
		Color(1.0, 0.92, 0.72),
		Color(0.72, 1.0, 0.95)
	]

	for i in star_count:
		var star := MeshInstance3D.new()
		star.mesh = star_mesh
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.position = _random_position_in_shell(field_radius * 0.25, field_radius)

		var size := randf_range(min_star_size, max_star_size)
		star.scale = Vector3.ONE * size

		var material := StandardMaterial3D.new()
		var color: Color = colors.pick_random()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = randf_range(0.4, 1.3)
		star.material_override = material

		add_child(star)

func _random_position_in_shell(inner_radius: float, outer_radius: float) -> Vector3:
	var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	while direction.length_squared() < 0.001:
		direction = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

	return direction.normalized() * randf_range(inner_radius, outer_radius)
