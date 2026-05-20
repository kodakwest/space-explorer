extends Control

## Star Info Panel — displays star information in drift aesthetic

@onready var _panel := $Panel
@onready var _name_label := $Panel/NameLabel
@onready var _bayer_label := $Panel/BayerLabel
@onready var _mag_label := $Panel/MagLabel
@onready var _dist_label := $Panel/DistLabel
@onready var _spectral_label := $Panel/SpectralLabel
@onready var _color_rect := $Panel/ColorRect
@onready var _close_button := $Panel/CloseButton
@onready var _bookmark_button := $Panel/BookmarkButton

var _current_star: Dictionary = {}
var _catalog: Resource

func _ready() -> void:
	_catalog = preload("res://scripts/star_catalog.gd").new()
	visible = false
	_close_button.pressed.connect(_hide)
	_bookmark_button.pressed.connect(_toggle_bookmark)

func show_star(star_name: String) -> void:
	var star := _catalog.get_star(star_name)
	if star.is_empty():
		return
	_current_star = star
	_display_star(star)
	visible = true

func _display_star(star: Dictionary) -> void:
	_name_label.text = star.get("name", "Unknown")
	
	var bayer: String = star.get("bayer", "")
	var constellation: String = ""
	if not bayer.is_empty():
		var parts := bayer.split(" ", true)
		if parts.size() > 1:
			constellation = parts[-1]
			bayer = parts[0] + " " + constellation
	
	_bayer_label.text = bayer if not bayer.is_empty() else ""
	
	var mag: float = star.get("mag", 0)
	_mag_label.text = "Magnitude: %.1f" % mag
	
	var dist: float = star.get("dist_ly", 0)
	if dist > 0:
		_dist_label.text = "Distance: %.1f ly" % dist
	else:
		_dist_label.text = "Distance: —"
	
	_spectral_label.text = "Type: %s" % star.get("spectral", "—")
	
	# Show star color swatch
	var ci: float = star.get("ci", 0.0)
	_color_rect.color = _catalog.star_to_color(ci)
	
	# Hover/glow effect
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#08070a")
	style.border_color = Color("#5ce1e6").lerp(Color.WHITE, 0.3)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

func _hide() -> void:
	visible = false

func _toggle_bookmark() -> void:
	var name := _current_star.get("name", "")
	if name.is_empty():
		return
	var bookmarks: Array = get_meta("bookmarks", [])
	if name in bookmarks:
		bookmarks.erase(name)
		_bookmark_button.text = "✦ Bookmark"
	else:
		bookmarks.append(name)
		_bookmark_button.text = "✦ Bookmarked"
	set_meta("bookmarks", bookmarks)

func get_bookmarks() -> Array:
	return get_meta("bookmarks", [])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if visible:
			_hide()
