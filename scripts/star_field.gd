extends Node3D

@export_range(2000, 3000, 1) var star_count: int = 2600
@export var field_radius: float = 1400.0
@export var core_radius: float = 135.0
@export var arm_spread: float = 34.0
@export var disk_thickness: float = 70.0
@export var min_star_size: float = 0.035
@export var max_star_size: float = 0.34

const ARM_COUNT: int = 3
const STAR_WARM: Color = Color("#ebc884")
const STAR_COOL: Color = Color("#82aad9")
const STAR_BASE: Color = Color("#d9dce6")
const CORE_GLOW: Color = Color("#ffdd80")

func _ready() -> void:
	_generate_galaxy()

func _generate_galaxy() -> void:
	var star_mesh: SphereMesh = SphereMesh.new()
	star_mesh.radius = 1.0
	star_mesh.height = 2.0
	star_mesh.radial_segments = 8
	star_mesh.rings = 4

	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = _create_twinkle_shader()

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = star_mesh
	multimesh.instance_count = star_count

	for i in star_count:
		var position: Vector3 = _galaxy_position()
		var distance_ratio: float = clampf(Vector2(position.x, position.z).length() / field_radius, 0.0, 1.0)
		var magnitude: float = pow(randf(), 2.35)
		var size: float = lerpf(min_star_size, max_star_size, magnitude)
		if distance_ratio < 0.16:
			size *= randf_range(1.15, 1.75)

		var basis: Basis = Basis().scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i, Transform3D(basis, position))
		multimesh.set_instance_color(i, _star_color(distance_ratio, magnitude))

		var phase: float = randf() * TAU
		var speed: float = randf_range(0.35, 1.25)
		var amplitude: float = randf_range(0.045, 0.14)
		multimesh.set_instance_custom_data(i, Color(phase, speed, amplitude, magnitude))

	var stars: MultiMeshInstance3D = MultiMeshInstance3D.new()
	stars.name = "GalaxyStars"
	stars.multimesh = multimesh
	stars.material_override = shader_material
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

func _galaxy_position() -> Vector3:
	if randf() < 0.22:
		var radius: float = pow(randf(), 2.4) * core_radius
		var angle: float = randf() * TAU
		return Vector3(
			cos(angle) * radius,
			randfn(0.0, disk_thickness * 0.25),
			sin(angle) * radius
		)

	var radius: float = lerpf(core_radius * 0.45, field_radius, pow(randf(), 0.72))
	var arm_index: int = randi() % ARM_COUNT
	var arm_offset: float = TAU * float(arm_index) / float(ARM_COUNT)
	var spiral_twist: float = radius * 0.0105
	var angle: float = arm_offset + spiral_twist + randfn(0.0, arm_spread / maxf(radius, 1.0))
	var scatter: float = randfn(0.0, arm_spread * lerpf(0.45, 1.85, radius / field_radius))
	var disk_y: float = randfn(0.0, disk_thickness * lerpf(0.2, 1.0, radius / field_radius))
	var final_radius: float = clampf(radius + scatter, core_radius * 0.25, field_radius)

	return Vector3(
		cos(angle) * final_radius,
		disk_y,
		sin(angle) * final_radius
	)

func _star_color(distance_ratio: float, magnitude: float) -> Color:
	var base: Color
	if distance_ratio < 0.17:
		base = STAR_WARM.lerp(CORE_GLOW, randf_range(0.25, 0.85))
	elif randf() < lerpf(0.55, 0.82, distance_ratio):
		base = STAR_COOL.lerp(STAR_BASE, randf_range(0.15, 0.65))
	else:
		base = STAR_WARM.lerp(STAR_BASE, randf_range(0.1, 0.42))

	var alpha: float = lerpf(0.62, 1.0, magnitude)
	return Color(base.r, base.g, base.b, alpha)

func _create_twinkle_shader() -> Shader:
	var shader: Shader = Shader.new()
shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

varying float star_phase;
varying float star_speed;
varying float star_amount;
varying float star_magnitude;

void vertex() {
	star_phase = INSTANCE_CUSTOM.x;
	star_speed = INSTANCE_CUSTOM.y;
	star_amount = INSTANCE_CUSTOM.z;
	star_magnitude = INSTANCE_CUSTOM.w;
}

void fragment() {
	float twinkle = 1.0 + sin(TIME * star_speed + star_phase) * star_amount;
	ALBEDO = COLOR.rgb * twinkle;
	EMISSION = COLOR.rgb * (0.55 + star_magnitude * 1.65) * twinkle;
	ALPHA = COLOR.a * (0.82 + sin(TIME * star_speed + star_phase) * star_amount);
}
"""
	return shader
