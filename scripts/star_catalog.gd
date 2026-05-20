extends Resource

## Bright Star Catalog — loads real star data from HYG Database
## Provides lookup by name, constellation, magnitude range

var _stars: Array[Dictionary] = []
var _stars_by_name: Dictionary = {}
var _stars_by_constellation: Dictionary = {}

func _init() -> void:
	_load_catalog()

func _load_catalog() -> void:
	var file := FileAccess.open("res://data/bright_stars.json", FileAccess.READ)
	if file == null:
		push_error("Star catalog not found: res://data/bright_stars.json")
		return
	
	var text := file.get_as_text()
	var json := JSON.new()
	var parse := json.parse(text)
	if parse != OK:
		push_error("Failed to parse star catalog: ", parse)
		return
	
	_stars = json.data as Array
	
	for star in _stars:
		var name: String = star.get("name", "")
		if name:
			_stars_by_name[name.to_lower()] = star

func get_star_count() -> int:
	return _stars.size()

func get_star(name: String) -> Dictionary:
	return _stars_by_name.get(name.to_lower().strip_edges(), {})

func get_all_stars() -> Array[Dictionary]:
	return _stars.duplicate()

func get_brightest(count: int = 20) -> Array[Dictionary]:
	var sorted = _stars.duplicate()
	sorted.sort_custom(func(a, b): return a.get("mag", 99) < b.get("mag", 99))
	return sorted.slice(0, count)

func get_stars_by_magnitude(max_mag: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for star in _stars:
		if star.get("mag", 99) <= max_mag:
			result.append(star)
	return result

func search_stars(query: String) -> Array[Dictionary]:
	var q = query.to_lower().strip_edges()
	var result: Array[Dictionary] = []
	for star in _stars:
		var name: String = star.get("name", "")
		var bayer: String = star.get("bayer", "")
		if q in name.to_lower() or q in bayer.to_lower():
			result.append(star)
	return result

func star_to_color(ci: float) -> Color:
	# B-V color index to RGB color
	# -0.3 = blue-white (Spica), 0.0 = white (Vega), 0.6 = yellow (Sun), 1.5 = red (Betelgeuse)
	var t := (ci + 0.3) / 1.8  # normalize -0.3..1.5 to 0..1
	t = clamp(t, 0.0, 1.0)
	
	# Blue-white (left) to yellow (middle) to red (right)
	var blue := Color("#82aad9")   # cool star
	var white := Color("#d9dce6")  # base star
	var yellow := Color("#ebc884") # warm star 
	var red := Color("#cc6633")    # very red star
	
	if t < 0.33:
		return blue.lerp(white, t / 0.33)
	elif t < 0.66:
		return white.lerp(yellow, (t - 0.33) / 0.33)
	else:
		return yellow.lerp(red, (t - 0.66) / 0.34)

func star_size_from_magnitude(mag: float, base_size: float = 1.0) -> float:
	# Brighter stars (lower mag) are larger
	var size_factor := clamp(5.0 - mag, 0.5, 5.0) / 5.0
	return base_size * (0.5 + size_factor * 1.5)

func constellation_for_star(star_name: String) -> String:
	# Uses Bayer designation (e.g. "α Orionis" -> Orion)
	var bayer: String = get_star(star_name).get("bayer", "")
	if bayer.is_empty():
		return ""
	var parts := bayer.split(" ", true)
	return parts[-1] if parts.size() > 1 else ""
