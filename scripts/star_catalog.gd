extends Resource
class_name StarCatalog

## Bright Star Catalog — loads real star data from HYG Database
## Provides lookup by name, constellation, magnitude range

const CONSTELLATION_ALIASES: Dictionary = {
	"andromeda": "And",
	"aquila": "Aql",
	"bootes": "Boo",
	"canis major": "CMa",
	"canis minor": "CMi",
	"cassiopeia": "Cas",
	"centaurus": "Cen",
	"cygnus": "Cyg",
	"leo": "Leo",
	"lyra": "Lyr",
	"orion": "Ori",
	"scorpius": "Sco",
	"taurus": "Tau",
	"ursa major": "UMa",
	"ursa minor": "UMi",
	"virgo": "Vir",
}

var _stars: Array[Dictionary] = []
var _stars_by_name: Dictionary = {}

func _init() -> void:
	_load_catalog()

func _load_catalog() -> void:
	var file: FileAccess = FileAccess.open("res://data/bright_stars.json", FileAccess.READ)
	if file == null:
		push_error("Star catalog not found: res://data/bright_stars.json")
		return
	
	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var parse: Error = json.parse(text)
	if parse != OK:
		push_error("Failed to parse star catalog: %s" % error_string(parse))
		return
	
	var parsed_data: Variant = json.data
	if not parsed_data is Array:
		push_error("Star catalog root must be an array: res://data/bright_stars.json")
		return
	var parsed_array: Array = parsed_data as Array

	_stars.clear()
	_stars_by_name.clear()
	for entry: Variant in parsed_array:
		if entry is Dictionary:
			_stars.append(entry as Dictionary)

	for star in _stars:
		var star_name: String = star.get("name", "")
		if not star_name.is_empty():
			_stars_by_name[star_name.to_lower()] = star

func get_star_count() -> int:
	return _stars.size()

func get_star(name: String) -> Dictionary:
	return _stars_by_name.get(name.to_lower().strip_edges(), {})

func get_all_stars() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_stars)
	return result

func get_brightest(count: int = 20) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	sorted.assign(_stars)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("mag", 99.0)) < float(b.get("mag", 99.0))
	)
	var result: Array[Dictionary] = []
	result.assign(sorted.slice(0, count))
	return result

func get_stars_by_magnitude(max_mag: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for star in _stars:
		if float(star.get("mag", 99.0)) <= max_mag:
			result.append(star)
	return result

func search_stars(query: String) -> Array[Dictionary]:
	var q: String = query.to_lower().strip_edges()
	var result: Array[Dictionary] = []
	for star in _stars:
		var star_name: String = star.get("name", "")
		var bayer: String = star.get("bayer", "")
		if q in star_name.to_lower() or q in bayer.to_lower() or _bayer_matches_constellation_query(bayer, q):
			result.append(star)
	return result

func _bayer_matches_constellation_query(bayer: String, query: String) -> bool:
	if query.is_empty():
		return false
	var abbreviation: String = str(CONSTELLATION_ALIASES.get(query, ""))
	if abbreviation.is_empty():
		return false
	var parts: PackedStringArray = bayer.split(" ", false)
	return parts.size() > 0 and parts[-1].to_lower() == abbreviation.to_lower()

func star_to_color(ci: float) -> Color:
	# B-V color index to RGB color
	# -0.3 = blue-white (Spica), 0.0 = white (Vega), 0.6 = yellow (Sun), 1.5 = red (Betelgeuse)
	var t: float = (ci + 0.3) / 1.8  # normalize -0.3..1.5 to 0..1
	t = clampf(t, 0.0, 1.0)
	
	# Blue-white (left) to yellow (middle) to red (right)
	var blue: Color = Color("#82aad9")   # cool star
	var white: Color = Color("#d9dce6")  # base star
	var yellow: Color = Color("#ebc884") # warm star
	var red: Color = Color("#cc6633")    # very red star
	
	if t < 0.33:
		return blue.lerp(white, t / 0.33)
	elif t < 0.66:
		return white.lerp(yellow, (t - 0.33) / 0.33)
	else:
		return yellow.lerp(red, (t - 0.66) / 0.34)

func star_size_from_magnitude(mag: float, base_size: float = 1.0) -> float:
	# Brighter stars (lower mag) are larger
	var size_factor: float = clampf(5.0 - mag, 0.5, 5.0) / 5.0
	return base_size * (0.5 + size_factor * 1.5)

func constellation_for_star(star_name: String) -> String:
	# Uses Bayer designation (e.g. "α Orionis" -> Orion)
	var bayer: String = str(get_star(star_name).get("bayer", ""))
	if bayer.is_empty():
		return ""
	var parts: PackedStringArray = bayer.split(" ", true)
	return parts[-1] if parts.size() > 1 else ""
