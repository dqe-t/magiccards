class_name ConfigManager
extends RefCounted

const DEFAULT_LETTERS: Array[String] = ["A", "O", "U", "I", "E"]
const DEFAULT_NUMBERS: Array[String] = ["1", "2", "3", "4", "5", "6"]
const MIN_SELECTED_SYMBOLS: int = 5
const DEFAULT_USER_CONFIG_PATH: String = "user://config.json"
const LEGACY_RES_CONFIG_PATH: String = "res://config.json"
const PROFILE_COUNT: int = 6

static var _test_locale_override: String = ""


static func set_test_locale_override(locale: String) -> void:
	_test_locale_override = locale


static func clear_test_locale_override() -> void:
	_test_locale_override = ""


static func is_system_french() -> bool:
	if not _test_locale_override.is_empty():
		return _test_locale_override.to_lower().begins_with("fr")
	var lang: String = OS.get_locale_language().to_lower()
	return lang.begins_with("fr")


class UserProfile extends RefCounted:
	var name: String = "Profile"
	var selected_symbols: Array[String] = []
	var ask_letter_names: bool = true
	var ask_letter_sounds: bool = false
	var lang_french: bool = true
	var lang_english: bool = false

	func _init(
		p_name: String,
		symbols: Array[String],
		ask_names: bool,
		ask_sounds: bool,
		p_lang_french: bool = true,
		p_lang_english: bool = false
	) -> void:
		self.name = p_name.strip_edges()
		self.selected_symbols = symbols.duplicate()
		self.ask_letter_names = ask_names
		self.ask_letter_sounds = ask_sounds
		self.lang_french = p_lang_french
		self.lang_english = p_lang_english

	func validate() -> bool:
		if self.name.is_empty():
			FailFast.fail("CRITICAL: Profile name cannot be empty.")
			return false
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

	func duplicate_profile() -> UserProfile:
		return UserProfile.new(
			self.name,
			self.selected_symbols,
			self.ask_letter_names,
			self.ask_letter_sounds,
			self.lang_french,
			self.lang_english
		)

	func to_dict() -> Dictionary:
		return {
			"name": self.name,
			"selected_symbols": self.selected_symbols,
			"ask_letter_names": self.ask_letter_names,
			"ask_letter_sounds": self.ask_letter_sounds,
			"lang_french": self.lang_french,
			"lang_english": self.lang_english,
		}

	static func from_dict(data: Dictionary, fallback_name: String) -> UserProfile:
		var p_name: String = str(data.get("name", fallback_name)).strip_edges()
		if p_name.is_empty():
			p_name = fallback_name

		var raw_list_variant: Variant = data.get("selected_symbols", ConfigManager.get_default_symbols())
		var raw_list: Array = raw_list_variant if (raw_list_variant is Array) else []
		var typed_symbols: Array[String] = []
		for item: Variant in raw_list:
			typed_symbols.append(str(item))

		var ask_names: bool = bool(data.get("ask_letter_names", true))
		var ask_sounds: bool = bool(data.get("ask_letter_sounds", false))
		var is_fr: bool = ConfigManager.is_system_french()
		var lang_fr: bool = bool(data.get("lang_french", is_fr))
		var lang_en: bool = bool(data.get("lang_english", not is_fr))

		return UserProfile.new(p_name, typed_symbols, ask_names, ask_sounds, lang_fr, lang_en)


class GameConfigData extends RefCounted:
	var active_profile_index: int = 0
	var profiles: Array[UserProfile] = []

	func _init(p_profiles: Array[UserProfile], p_active_index: int = 0) -> void:
		self.profiles = p_profiles
		self.active_profile_index = p_active_index

	func get_active_profile() -> UserProfile:
		if self.active_profile_index < 0 or self.active_profile_index >= self.profiles.size():
			FailFast.fail("CRITICAL: active_profile_index %d out of bounds." % self.active_profile_index)
			return self.profiles[0]
		return self.profiles[self.active_profile_index]

	func set_active_profile_index(idx: int) -> bool:
		if idx < 0 or idx >= self.profiles.size():
			FailFast.fail("CRITICAL: Cannot set active_profile_index %d, size is %d." % [idx, self.profiles.size()])
			return false
		self.active_profile_index = idx
		return true

	func rename_profile(idx: int, new_name: String) -> bool:
		var trimmed: String = new_name.strip_edges()
		if trimmed.is_empty():
			FailFast.fail("CRITICAL: New profile name cannot be empty.")
			return false
		if idx < 0 or idx >= self.profiles.size():
			FailFast.fail("CRITICAL: Profile index %d out of bounds for rename." % idx)
			return false
		self.profiles[idx].name = trimmed
		return true

	var selected_symbols: Array[String]:
		get:
			return get_active_profile().selected_symbols
		set(val):
			get_active_profile().selected_symbols = val

	var ask_letter_names: bool:
		get:
			return get_active_profile().ask_letter_names
		set(val):
			get_active_profile().ask_letter_names = val

	var ask_letter_sounds: bool:
		get:
			return get_active_profile().ask_letter_sounds
		set(val):
			get_active_profile().ask_letter_sounds = val

	var lang_french: bool:
		get:
			return get_active_profile().lang_french
		set(val):
			get_active_profile().lang_french = val

	var lang_english: bool:
		get:
			return get_active_profile().lang_english
		set(val):
			get_active_profile().lang_english = val

	func validate() -> bool:
		if self.profiles.size() != PROFILE_COUNT:
			FailFast.fail("CRITICAL: Expected %d profiles, got %d." % [PROFILE_COUNT, self.profiles.size()])
			return false
		if self.active_profile_index < 0 or self.active_profile_index >= PROFILE_COUNT:
			FailFast.fail("CRITICAL: active_profile_index %d out of bounds [0, %d)." % [self.active_profile_index, PROFILE_COUNT])
			return false
		for p: UserProfile in self.profiles:
			if not p.validate():
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


static func create_default_profile(index: int) -> UserProfile:
	var is_fr: bool = is_system_french()
	var prefix: String = "Profil %d" if is_fr else "Profile %d"
	var safe_idx: int = index if index > 0 else 1
	if not FailFast.require_positive_int(index, "index"):
		return UserProfile.new(prefix % safe_idx, get_default_symbols(), true, false, is_fr, not is_fr)
	return UserProfile.new(prefix % index, get_default_symbols(), true, false, is_fr, not is_fr)


static func create_default_config() -> GameConfigData:
	var profs: Array[UserProfile] = []
	for i: int in range(1, PROFILE_COUNT + 1):
		profs.append(create_default_profile(i))
	return GameConfigData.new(profs, 0)


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

	var loaded_profiles: Array[UserProfile] = []
	var active_idx: int = 0

	if data.has("profiles") and (data["profiles"] is Array):
		var raw_profiles: Array = data["profiles"]
		for i: int in range(raw_profiles.size()):
			var p_item: Variant = raw_profiles[i]
			if p_item is Dictionary:
				loaded_profiles.append(UserProfile.from_dict(p_item, "Profile %d" % (i + 1)))
		active_idx = clampi(int(data.get("active_profile_index", 0)), 0, PROFILE_COUNT - 1)
	elif data.has("selected_symbols"):
		var p1: UserProfile = UserProfile.from_dict(data, "Profile 1")
		loaded_profiles.append(p1)
		active_idx = 0

	while loaded_profiles.size() < PROFILE_COUNT:
		loaded_profiles.append(create_default_profile(loaded_profiles.size() + 1))

	if loaded_profiles.size() > PROFILE_COUNT:
		loaded_profiles = loaded_profiles.slice(0, PROFILE_COUNT)

	var cfg: GameConfigData = GameConfigData.new(loaded_profiles, active_idx)
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

	var profiles_data: Array[Dictionary] = []
	for p: UserProfile in cfg.profiles:
		profiles_data.append(p.to_dict())

	var payload: Dictionary = {
		"active_profile_index": cfg.active_profile_index,
		"profiles": profiles_data,
	}
	var json_str: String = JSON.stringify(payload, "  ")
	var file: FileAccess = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		FailFast.fail("CRITICAL: Unable to open %s for writing." % config_path)
		return false
	file.store_string(json_str)
	file.close()
	return true
