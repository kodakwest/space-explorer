extends CharacterBody3D

@export var camera_path: NodePath
@export var thrust_acceleration: float = 32.0
@export var boost_multiplier: float = 3.0
@export var hyperdrive_multiplier: float = 6.0
@export var hyperdrive_cooldown: float = 3.0
@export var hyperdrive_emergency_radius: float = 20.0
@export var max_speed: float = 220.0
@export var mouse_sensitivity: float = 0.0025
@export var keyboard_orbit_speed: float = 1.4
@export var ship_turn_speed: float = 6.5
@export var drag: float = 0.985
@export var hud_idle_seconds: float = 5.0
@export var hud_fade_speed: float = 2.6
@export var camera_follow_offset: Vector3 = Vector3(0.0, 4.5, 18.0)
@export var camera_look_offset: Vector3 = Vector3(0.0, 1.0, -24.0)

const MAX_PITCH: float = deg_to_rad(80.0)
const HUD_COLOR: Color = Color("#5ce1e6")
const CORE_GLOW: Color = Color("#ffdd80")
const REST_FOV: float = 64.0
const HYPERDRIVE_FOV: float = 85.0

@onready var speed_label: Label3D = $VisualPivot/SpeedLabel
@onready var _visual_pivot: Node3D = $VisualPivot
@onready var _engine_glow: MeshInstance3D = $VisualPivot/EngineGlow
@onready var _engine_light: OmniLight3D = $VisualPivot/EngineLight

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
var _star_prompt_label: Label
var _hyperdrive_label: Label
var _toast_label: Label
var _compass_label: Label
var _thrust_back: ColorRect
var _thrust_fill: ColorRect
var _hyperdrive_overlay: ColorRect
var _camera_rest_position: Vector3 = Vector3.ZERO
var _last_travel_direction: Vector3 = Vector3.FORWARD
var _hyperdrive_active: bool = false
var _hyperdrive_cooldown_remaining: float = 0.0
var _hyperdrive_effect: float = 0.0
var _current_thrust: float = 0.0
var _toast_time_remaining: float = 0.0
var _engine_hum: AudioStreamPlayer3D
var _hyperdrive_audio: AudioStreamPlayer3D
var _speed_particles: GPUParticles3D
var _connected_constellation_system: Node
var _connected_star_system: Node

func _ready() -> void:
	add_to_group("player_ship")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_ensure_input_actions()
	_yaw = rotation.y
	_resolve_camera()
	_camera_rest_position = camera_follow_offset
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if speed_label:
		speed_label.visible = false
	_create_engine_audio()
	_create_speed_particles()
	_create_screen_hud.call_deferred()
	_update_camera_orbit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hyperdrive"):
		_toggle_hyperdrive()
		_mark_active()
		return

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
		Input.get_axis("look_left", "look_right"),
		Input.get_axis("look_up", "look_down")
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
	_current_thrust = clampf(local_input.length(), 0.0, 1.0)

	var view_basis: Basis = get_camera_view_basis()
	if local_input.length_squared() > 0.0:
		_mark_active()
	velocity = calculate_velocity_after_input(velocity, local_input, Input.is_action_pressed("boost"), delta)

	move_and_slide()
	_update_hyperdrive(delta)
	_update_ship_visuals(delta, view_basis)
	_update_engine_feedback(delta)
	_update_compass_marker()
	_update_hud_fade(delta)
	_update_hud_text()

func get_camera_view_basis() -> Basis:
	return Basis.from_euler(Vector3(_pitch, _yaw, 0.0)).orthonormalized()

func calculate_velocity_after_input(start_velocity: Vector3, local_input: Vector3, boost_active: bool, delta: float) -> Vector3:
	var next_velocity: Vector3 = start_velocity
	if local_input.length_squared() > 0.0:
		var thrust: Vector3 = get_thrust_direction(local_input)
		var multiplier: float = boost_multiplier if boost_active else 1.0
		if _hyperdrive_active:
			multiplier *= hyperdrive_multiplier
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
	var limit: float = max_speed * (boost_multiplier if boost_active else 1.0)
	if _hyperdrive_active:
		limit = max_speed * hyperdrive_multiplier
	return limit

func _drag_factor(delta: float) -> float:
	return pow(clampf(drag, 0.0, 1.0), maxf(delta, 0.0) * 60.0)

func _create_screen_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "FlightHUD"
	_hud_layer.layer = 64
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(_hud_layer)
	else:
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

	_thrust_back = ColorRect.new()
	_thrust_back.name = "ThrustBack"
	_thrust_back.anchor_left = 0.0
	_thrust_back.anchor_top = 0.0
	_thrust_back.anchor_right = 0.0
	_thrust_back.anchor_bottom = 0.0
	_thrust_back.offset_left = 24.0
	_thrust_back.offset_top = 58.0
	_thrust_back.offset_right = 156.0
	_thrust_back.offset_bottom = 63.0
	_thrust_back.color = Color(HUD_COLOR.r, HUD_COLOR.g, HUD_COLOR.b, 0.14)
	_hud_layer.add_child(_thrust_back)

	_thrust_fill = ColorRect.new()
	_thrust_fill.name = "ThrustFill"
	_thrust_fill.anchor_left = 0.0
	_thrust_fill.anchor_top = 0.0
	_thrust_fill.anchor_right = 0.0
	_thrust_fill.anchor_bottom = 0.0
	_thrust_fill.offset_left = 24.0
	_thrust_fill.offset_top = 58.0
	_thrust_fill.offset_right = 24.0
	_thrust_fill.offset_bottom = 63.0
	_thrust_fill.color = Color(HUD_COLOR.r, HUD_COLOR.g, HUD_COLOR.b, 0.7)
	_hud_layer.add_child(_thrust_fill)

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

	_star_prompt_label = _make_hud_label("StarPromptHUD", HORIZONTAL_ALIGNMENT_CENTER)
	_star_prompt_label.anchor_left = 0.5
	_star_prompt_label.anchor_top = 0.64
	_star_prompt_label.anchor_right = 0.5
	_star_prompt_label.anchor_bottom = 0.64
	_star_prompt_label.offset_left = -260.0
	_star_prompt_label.offset_top = -22.0
	_star_prompt_label.offset_right = 260.0
	_star_prompt_label.offset_bottom = 22.0
	_hud_layer.add_child(_star_prompt_label)

	_hyperdrive_label = _make_hud_label("HyperdriveHUD", HORIZONTAL_ALIGNMENT_CENTER)
	_hyperdrive_label.anchor_left = 0.5
	_hyperdrive_label.anchor_top = 0.0
	_hyperdrive_label.anchor_right = 0.5
	_hyperdrive_label.anchor_bottom = 0.0
	_hyperdrive_label.offset_left = -180.0
	_hyperdrive_label.offset_top = 18.0
	_hyperdrive_label.offset_right = 180.0
	_hyperdrive_label.offset_bottom = 58.0
	_hyperdrive_label.add_theme_font_size_override("font_size", 22)
	_hud_layer.add_child(_hyperdrive_label)

	_toast_label = _make_hud_label("DiscoveryToastHUD", HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_right = 0.5
	_toast_label.anchor_bottom = 1.0
	_toast_label.offset_left = -360.0
	_toast_label.offset_top = -138.0
	_toast_label.offset_right = 360.0
	_toast_label.offset_bottom = -98.0
	_hud_layer.add_child(_toast_label)

	_compass_label = _make_hud_label("ConstellationCompassHUD", HORIZONTAL_ALIGNMENT_CENTER)
	_compass_label.text = "^"
	_compass_label.pivot_offset = Vector2(12.0, 12.0)
	_compass_label.size = Vector2(24.0, 24.0)
	_compass_label.add_theme_font_size_override("font_size", 24)
	_hud_layer.add_child(_compass_label)

	_hyperdrive_overlay = ColorRect.new()
	_hyperdrive_overlay.name = "HyperdriveOverlay"
	_hyperdrive_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hyperdrive_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hyperdrive_overlay.color = Color(0.08, 0.65, 0.88, 0.0)
	_hud_layer.add_child(_hyperdrive_overlay)
	_hud_layer.move_child(_hyperdrive_overlay, 0)

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
		_connect_constellation_system()
	if not is_instance_valid(_star_system):
		_star_system = get_tree().get_first_node_in_group("star_system")
		_connect_star_system()

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
	if _star_prompt_label and is_instance_valid(_star_system):
		_star_prompt_label.text = str(_star_system.get("nearest_star_prompt"))
	if _hyperdrive_label:
		if _hyperdrive_active:
			var pulse: float = 0.55 + sin(Time.get_ticks_msec() * 0.014) * 0.35
			_hyperdrive_label.text = "HYPERDRIVE"
			_hyperdrive_label.add_theme_color_override("font_color", _with_alpha(HUD_COLOR, pulse))
		elif _hyperdrive_cooldown_remaining > 0.0:
			_hyperdrive_label.text = "HYPERDRIVE %.1f" % _hyperdrive_cooldown_remaining
		else:
			_hyperdrive_label.text = ""
	if _toast_label:
		_toast_label.visible = _toast_time_remaining > 0.0
	if _thrust_fill:
		_thrust_fill.offset_right = 24.0 + 132.0 * _current_thrust

func _mark_active() -> void:
	_idle_time = 0.0

func _toggle_hyperdrive() -> void:
	if _hyperdrive_active:
		_disengage_hyperdrive("HYPERDRIVE OFFLINE")
		return
	if _hyperdrive_cooldown_remaining > 0.0:
		_show_toast("HYPERDRIVE COOLING %.1f" % _hyperdrive_cooldown_remaining)
		return
	_hyperdrive_active = true
	_show_toast("HYPERDRIVE ONLINE")

func _disengage_hyperdrive(message: String) -> void:
	if not _hyperdrive_active:
		return
	_hyperdrive_active = false
	_hyperdrive_cooldown_remaining = hyperdrive_cooldown
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	_show_toast(message)

func _update_hyperdrive(delta: float) -> void:
	if _hyperdrive_cooldown_remaining > 0.0 and not _hyperdrive_active:
		_hyperdrive_cooldown_remaining = maxf(0.0, _hyperdrive_cooldown_remaining - delta)
	if _hyperdrive_active and _near_emergency_brake_target():
		_disengage_hyperdrive("EMERGENCY BRAKE")

	_hyperdrive_effect = move_toward(_hyperdrive_effect, 1.0 if _hyperdrive_active else 0.0, delta * 2.0)
	if is_instance_valid(_camera):
		_camera.fov = lerpf(REST_FOV, HYPERDRIVE_FOV, _hyperdrive_effect)
	if is_instance_valid(_star_system) and _star_system.has_method("set_hyperdrive_strength"):
		_star_system.call("set_hyperdrive_strength", _hyperdrive_effect)
	if _hyperdrive_overlay:
		_hyperdrive_overlay.color = Color(0.08, 0.65, 0.88, 0.11 * _hyperdrive_effect)
	if _toast_time_remaining > 0.0:
		_toast_time_remaining = maxf(0.0, _toast_time_remaining - delta)

func _near_emergency_brake_target() -> bool:
	if is_instance_valid(_star_system):
		var star_distance: float = float(_star_system.get("nearest_star_distance"))
		if star_distance <= hyperdrive_emergency_radius:
			return true
	if is_instance_valid(_constellation_system) and _constellation_system.has_method("get_nearest_constellation_distance"):
		var constellation_distance: float = float(_constellation_system.call("get_nearest_constellation_distance", global_position))
		if constellation_distance <= hyperdrive_emergency_radius:
			return true
	return false

func _show_toast(text: String) -> void:
	_toast_time_remaining = 3.0
	if _toast_label:
		_toast_label.text = text
		_toast_label.visible = true

func _connect_constellation_system() -> void:
	if not is_instance_valid(_constellation_system) or _connected_constellation_system == _constellation_system:
		return
	_connected_constellation_system = _constellation_system
	if _constellation_system.has_signal("constellation_discovered"):
		_constellation_system.connect("constellation_discovered", Callable(self, "_on_constellation_discovered"))

func _connect_star_system() -> void:
	if not is_instance_valid(_star_system) or _connected_star_system == _star_system:
		return
	_connected_star_system = _star_system
	if _star_system.has_signal("toast_requested"):
		_star_system.connect("toast_requested", Callable(self, "_show_toast"))

func _on_constellation_discovered(constellation_name: String) -> void:
	_show_toast("✦ CONSTELLATION DISCOVERED: %s" % constellation_name.to_upper())

func _update_compass_marker() -> void:
	if not _compass_label:
		return
	_compass_label.visible = false
	if not is_instance_valid(_constellation_system) or not _constellation_system.has_method("get_nearest_undiscovered"):
		return
	if not is_instance_valid(_camera):
		return

	var target: Dictionary = _constellation_system.call("get_nearest_undiscovered", global_position)
	if target.is_empty():
		return

	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var target_position: Vector3 = target["center"] as Vector3
	var direction: Vector2
	if _camera.is_position_behind(target_position):
		var world_direction: Vector3 = (target_position - _camera.global_position).normalized()
		var camera_forward: Vector3 = -_camera.global_basis.z
		direction = Vector2(camera_forward.cross(world_direction).y, 1.0).normalized()
	else:
		direction = (_camera.unproject_position(target_position) - center).normalized()

	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	_compass_label.position = center + direction * 92.0 - Vector2(12.0, 12.0)
	_compass_label.rotation = direction.angle() + PI * 0.5
	_compass_label.visible = true

func _create_engine_audio() -> void:
	_engine_hum = AudioStreamPlayer3D.new()
	_engine_hum.name = "EngineHum"
	_engine_hum.stream = AudioStreamGenerator.new()
	_engine_hum.volume_db = -28.0
	_engine_hum.pitch_scale = 0.3
	add_child(_engine_hum)
	_engine_hum.play()

	_hyperdrive_audio = AudioStreamPlayer3D.new()
	_hyperdrive_audio.name = "HyperdrivePlaceholder"
	_hyperdrive_audio.stream = AudioStreamGenerator.new()
	_hyperdrive_audio.volume_db = -24.0
	_hyperdrive_audio.pitch_scale = 1.0
	add_child(_hyperdrive_audio)
	_hyperdrive_audio.play()

func _create_speed_particles() -> void:
	_speed_particles = GPUParticles3D.new()
	_speed_particles.name = "SpeedLines"
	_speed_particles.amount = 96
	_speed_particles.lifetime = 0.45
	_speed_particles.preprocess = 0.15
	_speed_particles.emitting = false
	_speed_particles.draw_pass_1 = _make_speed_line_mesh()

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 0.0, 1.0)
	process_material.spread = 8.0
	process_material.initial_velocity_min = 16.0
	process_material.initial_velocity_max = 42.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.35
	process_material.scale_max = 1.25
	process_material.color = Color(HUD_COLOR.r, HUD_COLOR.g, HUD_COLOR.b, 0.32)
	_speed_particles.process_material = process_material
	_speed_particles.position = Vector3(0.0, 0.0, 5.0)
	_visual_pivot.add_child(_speed_particles)

func _make_speed_line_mesh() -> Mesh:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3(0.0, 0.0, -0.9))
	mesh.surface_add_vertex(Vector3(0.0, 0.0, 0.9))
	mesh.surface_end()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(HUD_COLOR.r, HUD_COLOR.g, HUD_COLOR.b, 0.32)
	material.emission_enabled = true
	material.emission = HUD_COLOR
	material.emission_energy_multiplier = 0.7
	mesh.surface_set_material(0, material)
	return mesh

func _update_engine_feedback(delta: float) -> void:
	var speed_ratio: float = clampf(velocity.length() / max_speed, 0.0, hyperdrive_multiplier)
	var normalized_speed: float = clampf(speed_ratio / hyperdrive_multiplier, 0.0, 1.0)
	var hyper_boost: float = _hyperdrive_effect
	if is_instance_valid(_engine_light):
		_engine_light.light_energy = lerpf(1.6, 7.5, maxf(normalized_speed, hyper_boost))
		_engine_light.omni_range = lerpf(18.0, 46.0, hyper_boost)
	if is_instance_valid(_engine_glow):
		var material: StandardMaterial3D = _engine_glow.get_active_material(0) as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = lerpf(2.2, 8.5, maxf(normalized_speed, hyper_boost))
	if is_instance_valid(_engine_hum):
		_engine_hum.pitch_scale = lerpf(0.3, 2.5, clampf(velocity.length() / max_speed, 0.0, 1.0))
	if is_instance_valid(_hyperdrive_audio):
		_hyperdrive_audio.pitch_scale = lerpf(0.8, 2.2, hyper_boost)
		_hyperdrive_audio.volume_db = lerpf(-36.0, -18.0, hyper_boost)
	if is_instance_valid(_speed_particles):
		var speed: float = velocity.length()
		_speed_particles.emitting = speed > 50.0
		_speed_particles.amount_ratio = clampf((speed - 50.0) / (max_speed * hyperdrive_multiplier - 50.0), 0.15, 1.0)
		_speed_particles.speed_scale = lerpf(0.7, 2.6, clampf(speed / (max_speed * hyperdrive_multiplier), 0.0, 1.0))

func _ensure_input_actions() -> void:
	_add_key_action("fly_forward", [KEY_W])
	_add_key_action("fly_back", [KEY_S])
	_add_key_action("fly_left", [KEY_A])
	_add_key_action("fly_right", [KEY_D])
	_add_key_action("fly_up", [KEY_SPACE])
	_add_key_action("fly_down", [KEY_Q])
	_add_key_action("boost", [KEY_SHIFT])
	_add_key_action("look_left", [KEY_LEFT])
	_add_key_action("look_right", [KEY_RIGHT])
	_add_key_action("look_up", [KEY_UP])
	_add_key_action("look_down", [KEY_DOWN])
	_add_key_action("hyperdrive", [KEY_H, KEY_TAB])
	_add_key_action("bookmark", [KEY_B])

func _add_key_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keycodes:
		var already_bound: bool = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.keycode == keycode:
				already_bound = true
				break
		if already_bound:
			continue
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = keycode
		InputMap.action_add_event(action_name, key_event)

func _update_camera_orbit() -> void:
	if not is_instance_valid(_camera):
		_resolve_camera()
	if not _camera:
		return
	var view_basis: Basis = get_camera_view_basis()
	_camera.global_position = global_position + view_basis * _camera_rest_position
	var look_target: Vector3 = global_position + view_basis * camera_look_offset
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
	for label in [_speed_hud_label, _bookmark_hud_label, _constellation_hud_label, _star_prompt_label, _toast_label, _compass_label]:
		if label != null:
			label.add_theme_color_override("font_color", _with_alpha(HUD_COLOR, _hud_alpha))
	if _hyperdrive_label != null and not _hyperdrive_active:
		_hyperdrive_label.add_theme_color_override("font_color", _with_alpha(HUD_COLOR, _hud_alpha))
	if _thrust_back:
		_thrust_back.color = Color(HUD_COLOR.r, HUD_COLOR.g, HUD_COLOR.b, 0.14 * _hud_alpha)
	if _thrust_fill:
		_thrust_fill.color = Color(HUD_COLOR.r, HUD_COLOR.g, HUD_COLOR.b, 0.7 * _hud_alpha)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _make_monospace_font() -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])
	return font
