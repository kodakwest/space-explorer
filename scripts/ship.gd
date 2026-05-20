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

func _ready() -> void:
	add_to_group("player_ship")
	_yaw = rotation.y
	_pitch = rotation.x
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	speed_label.modulate = _with_alpha(HUD_COLOR, _hud_alpha)
	_update_speed_label()

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
	_update_speed_label()

func _update_speed_label() -> void:
	if speed_label:
		if not is_instance_valid(_constellation_system):
			_constellation_system = get_tree().get_first_node_in_group("constellation_system")

		var nearby: String = "--"
		var discovered: int = 0
		if is_instance_valid(_constellation_system):
			nearby = str(_constellation_system.get("current_constellation_name"))
			if nearby.is_empty():
				nearby = "--"
			discovered = int(_constellation_system.get("discovered_count"))

		speed_label.text = "SPD %03d\nNEAR %s\nDISC %02d/08" % [roundi(velocity.length()), nearby.to_upper(), discovered]

func _mark_active() -> void:
	_idle_time = 0.0

func _update_hud_fade(delta: float) -> void:
	_idle_time += delta
	var target_alpha: float = 0.82 if _idle_time < hud_idle_seconds else 0.22
	_hud_alpha = move_toward(_hud_alpha, target_alpha, delta * hud_fade_speed)
	if speed_label:
		speed_label.modulate = _with_alpha(HUD_COLOR, _hud_alpha)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
