extends CharacterBody3D

@export var thrust_acceleration: float = 32.0
@export var boost_multiplier: float = 3.0
@export var max_speed: float = 220.0
@export var mouse_sensitivity: float = 0.0025
@export var drag: float = 0.985

const MAX_PITCH: float = deg_to_rad(80.0)

@onready var speed_label: Label3D = $SpeedLabel

var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_speed_label()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -MAX_PITCH, MAX_PITCH)
		rotation = Vector3(_pitch, _yaw, 0.0)

func _physics_process(delta: float) -> void:
	var local_input := Vector3(
		Input.get_axis("fly_left", "fly_right"),
		Input.get_axis("fly_down", "fly_up"),
		-Input.get_axis("fly_back", "fly_forward")
	)

	if local_input.length_squared() > 0.0:
		var multiplier := boost_multiplier if Input.is_action_pressed("boost") else 1.0
		var thrust := transform.basis * local_input.normalized()
		velocity += thrust * thrust_acceleration * multiplier * delta

	var speed_limit := max_speed * (boost_multiplier if Input.is_action_pressed("boost") else 1.0)
	if velocity.length() > speed_limit:
		velocity = velocity.normalized() * speed_limit

	velocity *= drag
	move_and_slide()
	_update_speed_label()

func _update_speed_label() -> void:
	if speed_label:
		speed_label.text = "SPD: %03d" % roundi(velocity.length())
