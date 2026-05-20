extends Node3D

@export var discovery_radius: float = 50.0
@export var default_alpha: float = 0.11
@export var discovered_alpha: float = 0.62
@export var glow_speed: float = 5.0

const UI_ACCENT: Color = Color("#5ce1e6")
const STAR_COOL: Color = Color("#82aad9")
const CORE_GLOW: Color = Color("#ffdd80")

var current_constellation_name: String = ""
var discovered_count: int = 0

var _constellations: Array[Dictionary] = []
var _line_meshes: Array[MeshInstance3D] = []
var _line_materials: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _reveals: Array[float] = []
var _discovered: Array[bool] = []
var _ship: Node3D

func _ready() -> void:
	add_to_group("constellation_system")
	_build_constellation_data()
	_create_rendering()
	_ship = get_tree().get_first_node_in_group("player_ship") as Node3D

func _process(delta: float) -> void:
	if not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("player_ship") as Node3D

	var nearest_name: String = ""
	var nearest_distance: float = INF
	for i in _constellations.size():
		var center: Vector3 = _constellations[i]["center"] as Vector3
		var distance: float = INF
		if is_instance_valid(_ship):
			distance = _ship.global_position.distance_to(center)
			if distance < nearest_distance and distance <= discovery_radius:
				nearest_distance = distance
				nearest_name = str(_constellations[i]["name"])

		var target: float = 1.0 if distance <= discovery_radius else 0.0
		_reveals[i] = move_toward(_reveals[i], target, delta * glow_speed)
		if target > 0.0 and not _discovered[i]:
			_discovered[i] = true
			discovered_count += 1

		_update_constellation_visual(i)

	current_constellation_name = nearest_name

func _build_constellation_data() -> void:
	_constellations.clear()
	var constellation_data: Array[Dictionary] = [
		_constellation("Orion", 0, 230.0, [Vector3(-18, 10, 0), Vector3(-8, -2, 7), Vector3(0, -6, 0), Vector3(10, -4, -6), Vector3(20, 12, 1), Vector3(-22, -24, -4), Vector3(22, -25, 5)], [[0, 1], [1, 2], [2, 3], [3, 4], [1, 5], [3, 6]]),
		_constellation("Ursa Major", 1, 360.0, [Vector3(-34, 4, 0), Vector3(-18, 10, 4), Vector3(-2, 7, -2), Vector3(12, 13, 3), Vector3(28, 18, -6), Vector3(44, 10, 4), Vector3(56, -5, -2)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6]]),
		_constellation("Cassiopeia", 2, 310.0, [Vector3(-30, 5, -3), Vector3(-16, 18, 5), Vector3(0, 3, -2), Vector3(16, 18, 4), Vector3(32, 6, 0)], [[0, 1], [1, 2], [2, 3], [3, 4]]),
		_constellation("Cygnus", 0, 520.0, [Vector3(-42, 0, 0), Vector3(-18, 0, 3), Vector3(0, 0, 0), Vector3(20, 0, -4), Vector3(44, 0, 2), Vector3(0, 26, 4), Vector3(0, -28, -3)], [[0, 1], [1, 2], [2, 3], [3, 4], [5, 2], [2, 6]]),
		_constellation("Scorpius", 1, 610.0, [Vector3(-42, 18, 4), Vector3(-25, 5, -3), Vector3(-8, -6, 2), Vector3(10, -10, -4), Vector3(28, -2, 3), Vector3(40, 14, 0), Vector3(30, 28, -5)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6]]),
		_constellation("Leo", 2, 700.0, [Vector3(-38, -12, 0), Vector3(-18, 5, 5), Vector3(0, 14, -2), Vector3(18, 8, 4), Vector3(34, -8, -3), Vector3(8, -24, 2)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 1]]),
		_constellation("Lyra", 0, 790.0, [Vector3(-18, 18, 1), Vector3(0, 28, -3), Vector3(18, 12, 4), Vector3(12, -12, -2), Vector3(-14, -16, 3), Vector3(0, 0, 0)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 0], [5, 1]]),
		_constellation("Taurus", 1, 880.0, [Vector3(-38, 8, -3), Vector3(-18, 2, 2), Vector3(0, 0, 0), Vector3(18, 4, -4), Vector3(38, 15, 5), Vector3(10, -20, 1), Vector3(-8, -18, -2)], [[0, 1], [1, 2], [2, 3], [3, 4], [2, 5], [2, 6]])
	]
	_constellations.assign(constellation_data)

func _constellation(title: String, arm_index: int, radius: float, points: Array, links: Array) -> Dictionary:
	var angle: float = TAU * float(arm_index) / 3.0 + radius * 0.0105
	var center: Vector3 = Vector3(cos(angle) * radius, randf_range(-28.0, 28.0), sin(angle) * radius)
	var rotation_basis: Basis = Basis(Vector3.UP, angle)
	var world_points: Array[Vector3] = []
	for point in points:
		world_points.append(center + rotation_basis * (point as Vector3))

	return {
		"name": title,
		"center": center,
		"points": world_points,
		"links": links,
	}

func _create_rendering() -> void:
	for constellation in _constellations:
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for link in constellation["links"]:
			var points: Array = constellation["points"]
			mesh.surface_add_vertex(points[link[0]])
			mesh.surface_add_vertex(points[link[1]])
		mesh.surface_end()

		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true
		material.albedo_color = _with_alpha(STAR_COOL, default_alpha)
		material.emission_enabled = true
		material.emission = STAR_COOL
		material.emission_energy_multiplier = 0.15

		var lines: MeshInstance3D = MeshInstance3D.new()
		lines.name = "%sLines" % constellation["name"]
		lines.mesh = mesh
		lines.material_override = material
		lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lines)
		_line_meshes.append(lines)
		_line_materials.append(material)

		var label: Label3D = Label3D.new()
		label.name = "%sLabel" % constellation["name"]
		label.text = constellation["name"]
		label.position = constellation["center"] + Vector3(0.0, 36.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = _with_alpha(UI_ACCENT, 0.0)
		label.outline_modulate = Color(0, 0, 0, 0.65)
		label.font_size = 32
		label.outline_size = 8
		add_child(label)
		_labels.append(label)

		_reveals.append(0.0)
		_discovered.append(false)

func _update_constellation_visual(index: int) -> void:
	var reveal: float = _reveals[index]
	var discovered_floor: float = 0.32 if _discovered[index] else 0.0
	var intensity: float = maxf(reveal, discovered_floor)
	var color: Color = STAR_COOL.lerp(CORE_GLOW, reveal * 0.45)
	_line_materials[index].albedo_color = _with_alpha(color, lerpf(default_alpha, discovered_alpha, intensity))
	_line_materials[index].emission = color
	_line_materials[index].emission_energy_multiplier = lerpf(0.12, 0.95, intensity)
	_labels[index].modulate = _with_alpha(UI_ACCENT, reveal)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
