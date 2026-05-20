extends Node3D

signal bookmark_count_changed(count: int)

@export_range(1200, 3000, 1) var star_count: int = 1800
@export var field_radius: float = 1400.0
@export var core_radius: float = 135.0
@export var arm_spread: float = 34.0
@export var disk_thickness: float = 70.0
@export var min_star_size: float = 0.035
@export var max_star_size: float = 0.22
@export var catalog_star_scale: float = 1.0
@export var label_radius: float = 30.0
@export var interact_radius: float = 30.0
@export var max_visible_labels: int = 3

const ARM_COUNT: int = 3
const STAR_WARM: Color = Color("#ebc884")
const STAR_COOL: Color = Color("#82aad9")
const STAR_BASE: Color = Color("#d9dce6")
const CORE_GLOW: Color = Color("#ffdd80")
const UI_ACCENT: Color = Color("#5ce1e6")
const INFO_PANEL_SCENE: PackedScene = preload("res://scenes/star_info_panel.tscn")

var nearest_star_name: String = ""
var nearest_star_distance: float = INF
var bookmark_count: int = 0

var _catalog: StarCatalog = StarCatalog.new()
var _catalog_stars: Array[Dictionary] = []
var _star_positions: Array[Vector3] = []
var _labels: Array[Label3D] = []
var _label_alphas: Array[float] = []
var _ship: Node3D
var _info_panel: CanvasLayer

func _ready() -> void:
	add_to_group("star_system")
	_generate_background_galaxy()
	_create_catalog_stars()
	# Info panel added as sibling at root level, not child of 3D node
	call_deferred(&"_add_info_panel_to_root")

func _add_info_panel_to_root() -> void:
	var root = get_tree().current_scene
	if root:
		_info_panel = INFO_PANEL_SCENE.instantiate()
		root.add_child(_info_panel)
		if _info_panel.has_signal("bookmark_count_changed"):
			_info_panel.connect("bookmark_count_changed", Callable(self, "_on_bookmark_count_changed"))
		if _info_panel.has_method("get_bookmark_count"):
			bookmark_count = int(_info_panel.call("get_bookmark_count"))
			bookmark_count_changed.emit(bookmark_count)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_show_nearest_star()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_clicked_star(event.position)

func _process(delta: float) -> void:
	if not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("player_ship") as Node3D

	var visible_indices: Array[int] = _nearest_star_indices(label_radius, max_visible_labels)
	nearest_star_name = ""
	nearest_star_distance = INF
	if visible_indices.size() > 0:
		var nearest_index: int = visible_indices[0]
		nearest_star_name = str(_catalog_stars[nearest_index].get("name", ""))
		nearest_star_distance = _distance_to_ship(nearest_index)

	for i in _labels.size():
		var target_alpha: float = 0.0
		if i in visible_indices:
			target_alpha = 0.92
		_label_alphas[i] = move_toward(_label_alphas[i], target_alpha, delta * 2.8)
		_labels[i].modulate = _with_alpha(UI_ACCENT, _label_alphas[i])

func _generate_background_galaxy() -> void:
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
		var star_pos: Vector3 = _galaxy_position()
		var distance_ratio: float = clampf(Vector2(star_pos.x, star_pos.z).length() / field_radius, 0.0, 1.0)
		var magnitude: float = pow(randf(), 2.35)
		var size: float = lerpf(min_star_size, max_star_size, magnitude)
		if distance_ratio < 0.16:
			size *= randf_range(1.15, 1.75)

		var star_basis: Basis = Basis().scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i, Transform3D(star_basis, star_pos))
		multimesh.set_instance_color(i, _background_star_color(distance_ratio, magnitude))
		multimesh.set_instance_custom_data(i, Color(randf() * TAU, randf_range(0.35, 1.25), randf_range(0.045, 0.14), magnitude))

	var stars: MultiMeshInstance3D = MultiMeshInstance3D.new()
	stars.name = "BackgroundGalaxyStars"
	stars.multimesh = multimesh
	stars.material_override = shader_material
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

func _create_catalog_stars() -> void:
	_catalog_stars = _catalog.get_all_stars()

	var star_mesh: SphereMesh = SphereMesh.new()
	star_mesh.radius = 1.0
	star_mesh.height = 2.0
	star_mesh.radial_segments = 16
	star_mesh.rings = 8

	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = _create_twinkle_shader()

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = star_mesh
	multimesh.instance_count = _catalog_stars.size()

	for i in _catalog_stars.size():
		var star: Dictionary = _catalog_stars[i]
		var star_pos: Vector3 = Vector3(
			float(star.get("x", 0.0)),
			float(star.get("z", 0.0)),
			-float(star.get("y", 0.0))
		) * catalog_star_scale
		_star_positions.append(star_pos)

		var mag: float = float(star.get("mag", 6.0))
		var size: float = clampf(_catalog.star_size_from_magnitude(mag, 0.62), 0.18, 2.2)
		var star_basis: Basis = Basis().scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i, Transform3D(star_basis, star_pos))

		var color: Color = _catalog.star_to_color(float(star.get("ci", 0.0)))
		multimesh.set_instance_color(i, Color(color.r, color.g, color.b, 0.98))
		multimesh.set_instance_custom_data(i, Color(randf() * TAU, randf_range(0.55, 1.35), randf_range(0.035, 0.12), clampf(1.0 - ((mag + 1.5) / 7.5), 0.2, 1.0)))
		_create_star_label(i, star, star_pos, color)

	var stars: MultiMeshInstance3D = MultiMeshInstance3D.new()
	stars.name = "HygBrightStars"
	stars.multimesh = multimesh
	stars.material_override = shader_material
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

func _create_star_label(index: int, star: Dictionary, position: Vector3, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.name = "%sLabel" % str(star.get("name", "Star")).replace(" ", "")
	label.text = "%s\nmag %.1f  %.1f ly" % [
		str(star.get("name", "Unknown")),
		float(star.get("mag", 0.0)),
		float(star.get("dist_ly", 0.0))
	]
	label.position = position + Vector3(0.0, clampf(_catalog.star_size_from_magnitude(float(star.get("mag", 6.0)), 1.0), 0.8, 3.0), 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = _with_alpha(UI_ACCENT, 0.0)
	label.outline_modulate = Color(0, 0, 0, 0.72)
	label.font_size = 18
	label.outline_size = 5
	add_child(label)
	_labels.append(label)
	_label_alphas.append(0.0)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "%sGlow" % label.name.trim_suffix("Label")
	glow.position = position
	glow.light_color = color
	glow.light_energy = 0.18
	glow.omni_range = 5.0
	add_child(glow)

func _show_nearest_star() -> void:
	var indices: Array[int] = _nearest_star_indices(interact_radius, 1)
	if indices.is_empty() or not is_instance_valid(_info_panel):
		return
	_info_panel.call("show_star_data", _catalog_stars[indices[0]])

func _select_clicked_star(screen_position: Vector2) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(_info_panel):
		return

	var best_index: int = -1
	var best_distance: float = 18.0
	for i in _star_positions.size():
		var screen_star: Vector2 = camera.unproject_position(_star_positions[i])
		var distance: float = screen_position.distance_to(screen_star)
		if distance < best_distance:
			best_distance = distance
			best_index = i

	if best_index >= 0:
		_info_panel.call("show_star_data", _catalog_stars[best_index])

func _nearest_star_indices(radius: float, limit: int) -> Array[int]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(_ship):
		var empty_result: Array[int] = []
		return empty_result

	for i in _star_positions.size():
		var distance: float = _distance_to_ship(i)
		if distance <= radius:
			result.append({"index": i, "distance": distance})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)

	var indices: Array[int] = []
	for entry in result.slice(0, limit):
		indices.append(int(entry["index"]))
	return indices

func _distance_to_ship(index: int) -> float:
	if not is_instance_valid(_ship):
		return INF
	return _ship.global_position.distance_to(_star_positions[index])

func _on_bookmark_count_changed(count: int) -> void:
	bookmark_count = count
	bookmark_count_changed.emit(bookmark_count)

func _galaxy_position() -> Vector3:
	if randf() < 0.22:
		var core_rad: float = pow(randf(), 2.4) * core_radius
		var angle: float = randf() * TAU
		return Vector3(cos(angle) * core_rad, randfn(0.0, disk_thickness * 0.25), sin(angle) * core_rad)

	var spiral_radius: float = lerpf(core_radius * 0.45, field_radius, pow(randf(), 0.72))
	var arm_index: int = randi() % ARM_COUNT
	var arm_offset: float = TAU * float(arm_index) / float(ARM_COUNT)
	var spiral_twist: float = spiral_radius * 0.0105
	var angle: float = arm_offset + spiral_twist + randfn(0.0, arm_spread / maxf(spiral_radius, 1.0))
	var scatter: float = randfn(0.0, arm_spread * lerpf(0.45, 1.85, spiral_radius / field_radius))
	var disk_y: float = randfn(0.0, disk_thickness * lerpf(0.2, 1.0, spiral_radius / field_radius))
	var final_radius: float = clampf(spiral_radius + scatter, core_radius * 0.25, field_radius)

	return Vector3(cos(angle) * final_radius, disk_y, sin(angle) * final_radius)

func _background_star_color(distance_ratio: float, magnitude: float) -> Color:
	var clamped_distance_ratio: float = clampf(distance_ratio, 0.0, 1.0)
	var clamped_magnitude: float = clampf(magnitude, 0.0, 1.0)
	var base: Color
	if clamped_distance_ratio < 0.17:
		base = STAR_WARM.lerp(CORE_GLOW, randf_range(0.25, 0.85))
	elif randf() < lerpf(0.55, 0.82, clamped_distance_ratio):
		base = STAR_COOL.lerp(STAR_BASE, randf_range(0.15, 0.65))
	else:
		base = STAR_WARM.lerp(STAR_BASE, randf_range(0.1, 0.42))

	var alpha: float = lerpf(0.28, 0.58, clamped_magnitude)
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
	EMISSION = COLOR.rgb * (0.75 + star_magnitude * 1.9) * twinkle;
	ALPHA = COLOR.a * (0.82 + sin(TIME * star_speed + star_phase) * star_amount);
}
"""
	return shader

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
