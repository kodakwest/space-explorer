extends CharacterBody3D

@export var thrust_acceleration: float = 32.0
@export var boost_multiplier: float = 3.0
@export var max_speed: float = 220.0
@export var mouse_sensitivity: float = 0.0025
@export var drag: float = 0.985
@export var hud_idle_seconds: float = 5.0
@export var hud_fade_speed: float = 2.6

const MAX_PITCH: float = deg_to_rad(80.0)
const HUD_COLOR: Color = Color("#5ce1e6")

@onready var speed_label: Label3D = $SpeedLabel

var _yaw: float = 0.0
var _pitch: float = 0.0
var _idle_time: float = 0.0
var _hud_alpha: float = 0.82
var _constellation_system: Node
var _star_system: Node
var _hud_layer: CanvasLayer
var _speed_hud_label: Label
var _bookmark_hud_label: Label
var _constellation_hud_label: Label

func _ready() -> void:
	add_to_group("player_ship")
	_yaw = rotation.y
	_pitch = rotation.x
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if speed_label:
		speed_label.visible = false
	_create_screen_hud()
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
		rotation = Vector3(_pitch, _yaw, 0.0)
		_mark_active()

func _physics_process(delta: float) -> void:
	var local_input: Vector3 = Vector3(
		Input.get_axis("fly_left", "fly_right"),
		Input.get_axis("fly_down", "fly_up"),
		-Input.get_axis("fly_back", "fly_forward")
	)

	if local_input.length_squared() > 0.0:
		_mark_active()
		var multiplier: float = boost_multiplier if Input.is_action_pressed("boost") else 1.0
		var thrust: Vector3 = transform.basis * local_input.normalized()
		velocity += thrust * thrust_acceleration * multiplier * delta

	var speed_limit: float = max_speed * (boost_multiplier if Input.is_action_pressed("boost") else 1.0)
	if velocity.length() > speed_limit:
		velocity = velocity.normalized() * speed_limit

	velocity *= drag
	move_and_slide()
	_update_hud_fade(delta)
	_update_hud_text()

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

func _make_hud_label(label_name: String, alignment: int) -> Label:
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
