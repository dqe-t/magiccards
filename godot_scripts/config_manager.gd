class_name ConfigManager
extends RefCounted

const DEFAULT_LETTERS: Array[String] = ["A", "O", "U", "I", "E"]
const DEFAULT_NUMBERS: Array[String] = ["1", "2", "3", "4", "5", "6"]
const MIN_SELECTED_SYMBOLS: int = 5
const DEFAULT_USER_CONFIG_PATH: String = "user://config.json"
const LEGACY_RES_CONFIG_PATH: String = "res://config.json"


class GameConfigData extends RefCounted:
	var selected_symbols: Array[String] = []
	var ask_letter_names: bool = true
	var ask_letter_sounds: bool = false
	var lang_french: bool = true
	var lang_english: bool = false

	func _init(
		symbols: Array[String],
		ask_names: bool,
		ask_sounds: bool,
		p_lang_french: bool = true,
		p_lang_english: bool = false
	) -> void:
		self.selected_symbols = symbols.duplicate()
		self.ask_letter_names = ask_names
		self.ask_letter_sounds = ask_sounds
		self.lang_french = p_lang_french
		self.lang_english = p_lang_english

	func validate() -> bool:
		if not self.ask_letter_names and not self.ask_letter_sounds:
			FailFast.fail("CRITICAL: At least one prompt mode (names or sounds) must be selected.")
			return false

		if not self.lang_french and not self.lang_english:
			FailFast.fail("CRITICAL: At least one language (French or English) must be selected.")
			return false

		var distinct_upper: Dictionary = {}
		for s: String in self.selected_symbols:
			distinct_upper[s.to_upper()] = true

		if distinct_upper.size() < MIN_SELECTED_SYMBOLS:
			FailFast.fail(
				"CRITICAL: At least %d symbols must be selected, got %d."
				% [MIN_SELECTED_SYMBOLS, distinct_upper.size()]
			)
			return false

		var valid_pool: Dictionary = ConfigManager.get_valid_symbol_set()
		for sym: String in self.selected_symbols:
			if not valid_pool.has(sym):
				FailFast.fail("CRITICAL: Unknown symbol '%s' in selected_symbols." % sym)
				return false
		return true


static func get_all_uppercase() -> Array[String]:
	var arr: Array[String] = []
	for c: int in range(65, 91):
		arr.append(char(c))
	return arr


static func get_all_lowercase() -> Array[String]:
	var arr: Array[String] = []
	for c: int in range(97, 123):
		arr.append(char(c))
	return arr


static func get_all_numbers() -> Array[String]:
	var arr: Array[String] = []
	for n: int in range(1, 21):
		arr.append(str(n))
	return arr


static func get_default_symbols() -> Array[String]:
	var arr: Array[String] = []
	arr.append_array(DEFAULT_LETTERS)
	arr.append_array(DEFAULT_NUMBERS)
	return arr


static func get_valid_symbol_set() -> Dictionary:
	var set_dict: Dictionary = {}
	for s: String in get_all_uppercase():
		set_dict[s] = true
	for s: String in get_all_lowercase():
		set_dict[s] = true
	for s: String in get_all_numbers():
		set_dict[s] = true
	return set_dict


static func create_default_config() -> GameConfigData:
	return GameConfigData.new(get_default_symbols(), true, false, true, false)


static func read_config_from_path(path: String) -> GameConfigData:
	if not FailFast.require_non_empty_str(path, "path"):
		return create_default_config()
	if not FileAccess.file_exists(path):
		FailFast.fail("CRITICAL: Config file does not exist at %s." % path)
		return create_default_config()

	var raw_text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(raw_text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		FailFast.fail("CRITICAL: Invalid JSON in configuration file at %s." % path)
		return create_default_config()

	var data_variant: Variant = json.data
	if not (data_variant is Dictionary):
		FailFast.fail("CRITICAL: Config JSON root must be a Dictionary at %s." % path)
		return create_default_config()
	var data: Dictionary = data_variant
	if not data.has("selected_symbols") or typeof(data["selected_symbols"]) != TYPE_ARRAY:
		FailFast.fail("CRITICAL: 'selected_symbols' must be a list in %s." % path)
		return create_default_config()

	var raw_list_variant: Variant = data["selected_symbols"]
	var raw_list: Array = raw_list_variant if (raw_list_variant is Array) else []
	var typed_symbols: Array[String] = []
	for item: Variant in raw_list:
		typed_symbols.append(str(item))

	var ask_names: bool = bool(data.get("ask_letter_names", true))
	var ask_sounds: bool = bool(data.get("ask_letter_sounds", false))
	var lang_fr: bool = bool(data.get("lang_french", true))
	var lang_en: bool = bool(data.get("lang_english", false))

	var cfg: GameConfigData = GameConfigData.new(typed_symbols, ask_names, ask_sounds, lang_fr, lang_en)
	cfg.validate()
	return cfg


static func load_config(config_path: String) -> GameConfigData:
	if not FailFast.require_non_empty_str(config_path, "config_path"):
		return create_default_config()

	if FileAccess.file_exists(config_path):
		return read_config_from_path(config_path)

	if config_path == DEFAULT_USER_CONFIG_PATH and FileAccess.file_exists(LEGACY_RES_CONFIG_PATH):
		var migrated: GameConfigData = read_config_from_path(LEGACY_RES_CONFIG_PATH)
		save_config(migrated, config_path)
		return migrated

	var default_cfg: GameConfigData = create_default_config()
	save_config(default_cfg, config_path)
	return default_cfg


static func save_config(cfg: GameConfigData, config_path: String) -> bool:
	if not FailFast.require_not_null(cfg, "cfg"):
		return false
	if not FailFast.require_non_empty_str(config_path, "config_path"):
		return false
	if not cfg.validate():
		return false

	var payload: Dictionary = {
		"selected_symbols": cfg.selected_symbols,
		"ask_letter_names": cfg.ask_letter_names,
		"ask_letter_sounds": cfg.ask_letter_sounds,
		"lang_french": cfg.lang_french,
		"lang_english": cfg.lang_english,
	}
	var json_str: String = JSON.stringify(payload, "  ")
	var file: FileAccess = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		FailFast.fail("CRITICAL: Unable to open %s for writing." % config_path)
		return false
	file.store_string(json_str)
	file.close()
	return true
