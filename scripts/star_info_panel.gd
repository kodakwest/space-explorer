extends CanvasLayer

signal bookmark_count_changed(count: int)

const BOOKMARK_PATH: String = "user://star_bookmarks.json"
const ABYSS: Color = Color("#08070a")
const UI_ACCENT: Color = Color("#5ce1e6")
const STAR_BASE: Color = Color("#d9dce6")

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/NameLabel
@onready var _bayer_label: Label = $Panel/BayerLabel
@onready var _mag_label: Label = $Panel/MagLabel
@onready var _dist_label: Label = $Panel/DistLabel
@onready var _spectral_label: Label = $Panel/SpectralLabel
@onready var _color_rect: ColorRect = $Panel/ColorRect
@onready var _close_button: Button = $Panel/CloseButton
@onready var _bookmark_button: Button = $Panel/BookmarkButton

var _current_star: Dictionary = {}
var _catalog: Resource = preload("res://scripts/star_catalog.gd").new()
var _bookmarks: Array[String] = []

func _ready() -> void:
	visible = false
	_load_bookmarks()
	_style_panel()
	_close_button.pressed.connect(_hide)
	_bookmark_button.pressed.connect(_toggle_bookmark)
	bookmark_count_changed.emit(_bookmarks.size())

func show_star(star_name: String) -> void:
	var star: Dictionary = _catalog.get_star(star_name)
	if star.is_empty():
		return
	show_star_data(star)

func show_star_data(star: Dictionary) -> void:
	_current_star = star
	_display_star(star)
	visible = true

func get_bookmarks() -> Array[String]:
	return _bookmarks.duplicate()

func get_bookmark_count() -> int:
	return _bookmarks.size()

func _display_star(star: Dictionary) -> void:
	var name: String = str(star.get("name", "Unknown"))
	_name_label.text = name
	_bayer_label.text = _format_bayer(str(star.get("bayer", "")))
	_mag_label.text = "Magnitude: %.2f" % float(star.get("mag", 0.0))
	_dist_label.text = "Distance: %.1f ly" % float(star.get("dist_ly", 0.0))
	_spectral_label.text = "Type: %s" % str(star.get("spectral", "-"))
	_color_rect.color = _catalog.star_to_color(float(star.get("ci", 0.0)))
	_update_bookmark_button()

func _format_bayer(raw_bayer: String) -> String:
	if raw_bayer.is_empty():
		return "Designation: -"
	return "Designation: %s" % raw_bayer

func _toggle_bookmark() -> void:
	var name: String = str(_current_star.get("name", ""))
	if name.is_empty():
		return

	if name in _bookmarks:
		_bookmarks.erase(name)
	else:
		_bookmarks.append(name)

	_bookmarks.sort()
	_save_bookmarks()
	_update_bookmark_button()
	bookmark_count_changed.emit(_bookmarks.size())

func _update_bookmark_button() -> void:
	var name: String = str(_current_star.get("name", ""))
	_bookmark_button.text = "✦ Bookmarked" if name in _bookmarks else "✦ Bookmark"

func _hide() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and visible:
		_hide()
		get_viewport().set_input_as_handled()

func _load_bookmarks() -> void:
	_bookmarks.clear()
	if not FileAccess.file_exists(BOOKMARK_PATH):
		return

	var file: FileAccess = FileAccess.open(BOOKMARK_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for item in parsed:
			var name: String = str(item)
			if not name.is_empty() and not (name in _bookmarks):
				_bookmarks.append(name)

func _save_bookmarks() -> void:
	var file: FileAccess = FileAccess.open(BOOKMARK_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save star bookmarks to %s" % BOOKMARK_PATH)
		return
	file.store_string(JSON.stringify(_bookmarks, "\t"))

func _style_panel() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(ABYSS.r, ABYSS.g, ABYSS.b, 0.88)
	style.border_color = Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)

	var mono_font: SystemFont = _make_monospace_font()
	for label in [_name_label, _bayer_label, _mag_label, _dist_label, _spectral_label]:
		label.add_theme_font_override("font", mono_font)

	_name_label.add_theme_color_override("font_color", STAR_BASE)
	_bayer_label.add_theme_color_override("font_color", _with_alpha(UI_ACCENT, 0.66))
	_mag_label.add_theme_color_override("font_color", _with_alpha(STAR_BASE, 0.82))
	_dist_label.add_theme_color_override("font_color", _with_alpha(STAR_BASE, 0.82))
	_spectral_label.add_theme_color_override("font_color", _with_alpha(STAR_BASE, 0.82))
	_close_button.add_theme_color_override("font_color", _with_alpha(UI_ACCENT, 0.86))
	_bookmark_button.add_theme_color_override("font_color", _with_alpha(UI_ACCENT, 0.86))
	_close_button.add_theme_font_override("font", mono_font)
	_bookmark_button.add_theme_font_override("font", mono_font)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _make_monospace_font() -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])
	return font
