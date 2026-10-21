class_name FontManager
extends RefCounted

const BUNDLED_FONT_FILES: Dictionary = {
	"Segoe UI": "res://assets/fonts/segoeuib.ttf",
	"Segoe UI Regular": "res://assets/fonts/segoeui.ttf",
	"Comic Sans MS": "res://assets/fonts/comicbd.ttf",
	"Calibri": "res://assets/fonts/calibrib.ttf",
	"Verdana": "res://assets/fonts/verdanab.ttf",
	"Trebuchet MS": "res://assets/fonts/trebucbd.ttf",
}

const DEFAULT_FONT_POOL: Array[String] = [
	"Segoe UI",
	"Comic Sans MS",
	"Calibri",
	"Verdana",
	"Trebuchet MS",
]

var font_pool: Array[String] = []
var _font_cache: Dictionary = {}


func _init(custom_pool: Array[String]) -> void:
	if custom_pool.is_empty():
		self.font_pool = DEFAULT_FONT_POOL.duplicate()
	else:
		self.font_pool = custom_pool.duplicate()


func get_font(font_name: String, bold: bool) -> Font:
	if not FailFast.require_non_empty_str(font_name, "font_name"):
		return ThemeDB.fallback_font

	var lookup_key: String = font_name
	if font_name == "Segoe UI" and not bold:
		lookup_key = "Segoe UI Regular"

	if _font_cache.has(lookup_key):
		var cached_variant: Variant = _font_cache[lookup_key]
		if cached_variant is Font:
			return cached_variant

	var path: String = str(BUNDLED_FONT_FILES.get(lookup_key, BUNDLED_FONT_FILES["Segoe UI"]))
	var loaded_font: Font = _load_font_resource(path)
	_font_cache[lookup_key] = loaded_font
	return loaded_font


static func _load_font_resource(path: String) -> Font:
	if not FailFast.require_non_empty_str(path, "path"):
		return ThemeDB.fallback_font

	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		FailFast.fail("CRITICAL: Font file not found at %s." % path)
		return ThemeDB.fallback_font

	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Font:
			return res

	var font_file: FontFile = FontFile.new()
	var err: Error = font_file.load_dynamic_font(path)
	if err == OK:
		return font_file

	FailFast.fail("CRITICAL: Failed to load font resource at %s." % path)
	return ThemeDB.fallback_font


func get_ui_font(bold: bool) -> Font:
	return get_font("Segoe UI", bold)


func get_title_font() -> Font:
	return get_font("Trebuchet MS", true)


func get_card_font(card_index: int) -> Font:
	if not FailFast.require_non_negative_int(card_index, "card_index"):
		return get_font("Segoe UI", true)
	var font_name: String = self.font_pool[card_index % self.font_pool.size()]
	return get_font(font_name, true)


func get_round_font(round_index: int) -> Font:
	if not FailFast.require_positive_int(round_index, "round_index"):
		return get_font("Segoe UI", true)
	var idx: int = maxi(0, round_index - 1)
	var font_name: String = self.font_pool[idx % self.font_pool.size()]
	return get_font(font_name, true)


func get_cap_baseline_offset(font: Font, font_size: int) -> float:
	if not FailFast.require_not_null(font, "font"):
		return 0.0
	if not FailFast.require_positive_int(font_size, "font_size"):
		return 0.0
	# In TrueType typography, capital letter height ('H') is ~72% of ascent above baseline.
	# Placing baseline at center_y + 0.36 * ascent optically centers uppercase letters and digits.
	var ascent: float = font.get_ascent(font_size)
	return ascent * 0.36
