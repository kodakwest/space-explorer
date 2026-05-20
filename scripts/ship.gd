extends CharacterBody3D

@export var camera_path: NodePath
@export var thrust_acceleration: float = 32.0
@export var boost_multiplier: float = 3.0
@export var max_speed: float = 220.0
@export var mouse_sensitivity: float = 0.0025
@export var keyboard_orbit_speed: float = 1.4
@export var ship_turn_speed: float = 6.5
@export var drag: float = 0.985
@export var hud_idle_seconds: float = 5.0
@export var hud_fade_speed: float = 2.6

const MAX_PITCH: float = deg_to_rad(80.0)
const HUD_COLOR: Color = Color("#5ce1e6")
const DEFAULT_CAMERA_REST_POSITION: Vector3 = Vector3(0.0, 2.5, 9.0)

@onready var speed_label: Label3D = $VisualPivot/SpeedLabel
@onready var _visual_pivot: Node3D = $VisualPivot

var _camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-10.0)
var _idle_time: float = 0.0
var _hud_alpha: float = 0.82
var _constellation_system: Node
var _star_system: Node
var _hud_layer: CanvasLayer
var _speed_hud_label: Label
var _bookmark_hud_label: Label
var _constellation_hud_label: Label
var _camera_rest_position: Vector3 = Vector3.ZERO
var _last_travel_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	add_to_group("player_ship")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_yaw = rotation.y
	_resolve_camera()
	if _camera:
		_camera_rest_position = _camera.global_position - global_position
	else:
		_camera_rest_position = DEFAULT_CAMERA_REST_POSITION
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if speed_label:
		speed_label.visible = false
	_create_screen_hud()
	_update_camera_orbit()
	_update_hud_text()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_mark_active()
		return

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mark_active()
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -MAX_PITCH, MAX_PITCH)
		_update_camera_orbit()
		_mark_active()

func _physics_process(delta: float) -> void:
	var orbit_input: Vector2 = Vector2(
		Input.get_axis("fly_left", "fly_right"),
		Input.get_axis("fly_forward", "fly_back")
	)
	if orbit_input.length_squared() > 0.0:
		_yaw -= orbit_input.x * keyboard_orbit_speed * delta
		_pitch = clamp(_pitch + orbit_input.y * keyboard_orbit_speed * delta, -MAX_PITCH, MAX_PITCH)
		_mark_active()
	_update_camera_orbit()

	var local_input: Vector3 = Vector3(
		Input.get_axis("fly_left", "fly_right"),
		Input.get_axis("fly_down", "fly_up"),
		-Input.get_axis("fly_back", "fly_forward")
	)

	var view_basis: Basis = get_camera_view_basis()
	if local_input.length_squared() > 0.0:
		_mark_active()
	velocity = calculate_velocity_after_input(velocity, local_input, Input.is_action_pressed("boost"), delta)

	move_and_slide()
	_update_ship_visuals(delta, view_basis)
	_update_hud_fade(delta)
	_update_hud_text()

func get_camera_view_basis() -> Basis:
	return Basis.from_euler(Vector3(_pitch, _yaw, 0.0)).orthonormalized()

func calculate_velocity_after_input(start_velocity: Vector3, local_input: Vector3, boost_active: bool, delta: float) -> Vector3:
	var next_velocity: Vector3 = start_velocity
	if local_input.length_squared() > 0.0:
		var thrust: Vector3 = get_thrust_direction(local_input)
		var multiplier: float = boost_multiplier if boost_active else 1.0
		next_velocity += thrust * thrust_acceleration * multiplier * delta
		_last_travel_direction = thrust

	var speed_limit: float = get_speed_limit(boost_active)
	if next_velocity.length() > speed_limit:
		next_velocity = next_velocity.normalized() * speed_limit

	next_velocity *= _drag_factor(delta)
	if next_velocity.length() > speed_limit:
		next_velocity = next_velocity.normalized() * speed_limit
	return next_velocity

func get_thrust_direction(local_input: Vector3) -> Vector3:
	if local_input.length_squared() <= 0.0:
		return Vector3.ZERO
	return (get_camera_view_basis() * local_input.normalized()).normalized()

func get_speed_limit(boost_active: bool) -> float:
	return max_speed * (boost_multiplier if boost_active else 1.0)

func _drag_factor(delta: float) -> float:
	return pow(clampf(drag, 0.0, 1.0), maxf(delta, 0.0) * 60.0)

func _create_screen_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "FlightHUD"
	_hud_layer.layer = 64
	add_child(_hud_layer)

	_speed_hud_label = _make_hud_label("SpeedHUD", HORIZONTAL_ALIGNMENT_LEFT)
	_speed_hud_label.anchor_left = 0.0
	_speed_hud_label.anchor_top = 0.0
	_speed_hud_label.anchor_right = 0.0
	_speed_hud_label.anchor_bottom = 0.0
	_speed_hud_label.offset_left = 24.0
	_speed_hud_label.offset_top = 18.0
	_speed_hud_label.offset_right = 260.0
	_speed_hud_label.offset_bottom = 58.0
	_hud_layer.add_child(_speed_hud_label)

	_bookmark_hud_label = _make_hud_label("BookmarkHUD", HORIZONTAL_ALIGNMENT_RIGHT)
	_bookmark_hud_label.anchor_left = 1.0
	_bookmark_hud_label.anchor_top = 0.0
	_bookmark_hud_label.anchor_right = 1.0
	_bookmark_hud_label.anchor_bottom = 0.0
	_bookmark_hud_label.offset_left = -180.0
	_bookmark_hud_label.offset_top = 18.0
	_bookmark_hud_label.offset_right = -24.0
	_bookmark_hud_label.offset_bottom = 58.0
	_hud_layer.add_child(_bookmark_hud_label)

	_constellation_hud_label = _make_hud_label("ConstellationHUD", HORIZONTAL_ALIGNMENT_CENTER)
	_constellation_hud_label.anchor_left = 0.5
	_constellation_hud_label.anchor_top = 1.0
	_constellation_hud_label.anchor_right = 0.5
	_constellation_hud_label.anchor_bottom = 1.0
	_constellation_hud_label.offset_left = -220.0
	_constellation_hud_label.offset_top = -78.0
	_constellation_hud_label.offset_right = 220.0
	_constellation_hud_label.offset_bottom = -34.0
	_hud_layer.add_child(_constellation_hud_label)

func _make_hud_label(label_name: String, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _make_monospace_font())
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", _with_alpha(HUD_COLOR, _hud_alpha))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("outline_size", 4)
	return label

func _update_hud_text() -> void:
	if not is_instance_valid(_constellation_system):
		_constellation_system = get_tree().get_first_node_in_group("constellation_system")
	if not is_instance_valid(_star_system):
		_star_system = get_tree().get_first_node_in_group("star_system")

	var nearby_constellation: String = "--"
	if is_instance_valid(_constellation_system):
		nearby_constellation = str(_constellation_system.get("current_constellation_name"))
		if nearby_constellation.is_empty():
			nearby_constellation = "--"

	var bookmarks: int = 0
	if is_instance_valid(_star_system):
		bookmarks = int(_star_system.get("bookmark_count"))

	if _speed_hud_label:
		_speed_hud_label.text = "SPD %03d" % roundi(velocity.length())
	if _bookmark_hud_label:
		_bookmark_hud_label.text = "✦ %d" % bookmarks
	if _constellation_hud_label:
		_constellation_hud_label.text = nearby_constellation.to_upper() if nearby_constellation != "--" else ""

func _mark_active() -> void:
	_idle_time = 0.0

func _update_camera_orbit() -> void:
	if not is_instance_valid(_camera):
		_resolve_camera()
	if not _camera:
		return
	var view_basis: Basis = get_camera_view_basis()
	_camera.global_position = global_position + view_basis * _camera_rest_position
	var look_target: Vector3 = global_position + view_basis * Vector3(0.0, 0.0, -10.0)
	_camera.look_at(look_target, Vector3.UP)
	_camera.current = true

func _resolve_camera() -> void:
	if camera_path != NodePath(""):
		_camera = get_node_or_null(camera_path) as Camera3D
	if not is_instance_valid(_camera):
		_camera = get_tree().get_first_node_in_group("flight_camera") as Camera3D

func _update_ship_visuals(delta: float, view_basis: Basis) -> void:
	if not _visual_pivot:
		return

	var travel_direction: Vector3 = _last_travel_direction
	if velocity.length_squared() > 0.25:
		travel_direction = velocity.normalized()
	elif travel_direction.length_squared() <= 0.0:
		travel_direction = -(view_basis.z)

	var up: Vector3 = Vector3.UP
	if absf(travel_direction.dot(up)) > 0.96:
		up = Vector3.FORWARD
	var target_basis: Basis = Basis.looking_at(travel_direction, up)
	_visual_pivot.basis = _visual_pivot.basis.slerp(target_basis, clampf(delta * ship_turn_speed, 0.0, 1.0))

func _update_hud_fade(delta: float) -> void:
	_idle_time += delta
	var target_alpha: float = 0.82 if _idle_time < hud_idle_seconds else 0.22
	_hud_alpha = move_toward(_hud_alpha, target_alpha, delta * hud_fade_speed)
	for label in [_speed_hud_label, _bookmark_hud_label, _constellation_hud_label]:
		if label != null:
			label.add_theme_color_override("font_color", _with_alpha(HUD_COLOR, _hud_alpha))

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _make_monospace_font() -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])
	return font
