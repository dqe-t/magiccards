class_name AudioManager
extends Node

const SCORE_ANIMAL_AUDIO_MAP: Dictionary = {
	0: "score_0_ant.mp3",
	1: "score_1_fly.mp3",
	2: "score_2_frog.mp3",
	3: "score_3_duck.mp3",
	4: "score_4_bunny.mp3",
	5: "score_5_cat.mp3",
	6: "score_6_dog.mp3",
	7: "score_7_fox.mp3",
	8: "score_8_sheep.mp3",
	9: "score_9_lion.mp3",
	10: "score_10_bear.mp3",
}

var assets_dir: String = "res://assets/audio"
var sfx_dir: String = "res://assets/audio/sfx"
var female_voice_dir: String = "res://assets/audio/voice_female"
var male_voice_dir: String = "res://assets/audio/voice_male"
var animals_dir: String = "res://assets/audio/animals"

var current_voice: String = "FEMALE"
var current_language: String = "FR"
var available_languages: Array[String] = ["FR"]
var sfx_player: AudioStreamPlayer = null
var voice_player: AudioStreamPlayer = null

var _sfx_correct: AudioStream = null
var _sfx_wrong: AudioStream = null
var _stream_cache: Dictionary = {}


func _init(custom_assets_dir: String = "res://assets/audio") -> void:
	if not FailFast.require_non_empty_str(custom_assets_dir, "custom_assets_dir"):
		return
	self.assets_dir = custom_assets_dir.trim_suffix("/")
	self.sfx_dir = self.assets_dir + "/sfx"
	self.female_voice_dir = self.assets_dir + "/voice_female"
	self.male_voice_dir = self.assets_dir + "/voice_male"
	self.animals_dir = self.assets_dir + "/animals"

	self.sfx_player = AudioStreamPlayer.new()
	self.voice_player = AudioStreamPlayer.new()
	add_child(self.sfx_player)
	add_child(self.voice_player)
	_load_sfx()


func _load_sfx() -> void:
	var correct_path: String = self.sfx_dir + "/correct.mp3"
	var wrong_path: String = self.sfx_dir + "/wrong.wav"
	if _audio_file_exists(correct_path):
		self._sfx_correct = _load_stream(correct_path)
	if _audio_file_exists(wrong_path):
		self._sfx_wrong = _load_stream(wrong_path)


static func _audio_file_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		var cached: Variant = _stream_cache[path]
		if cached is AudioStream:
			return cached

	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is AudioStream:
			_stream_cache[path] = res
			return res

	if path.ends_with(".mp3") and FileAccess.file_exists(path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var mp3: AudioStreamMP3 = AudioStreamMP3.new()
			mp3.data = bytes
			_stream_cache[path] = mp3
			return mp3

	if path.ends_with(".wav") and FileAccess.file_exists(path):
		var wav_stream: AudioStreamWAV = _parse_wav_file(path)
		if wav_stream != null:
			_stream_cache[path] = wav_stream
			return wav_stream

	FailFast.fail("CRITICAL: Failed to load audio stream at %s." % path)
	return null


static func _parse_wav_file(path: String) -> AudioStreamWAV:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return null
	var channels: int = bytes.decode_u16(22)
	var sample_rate: int = bytes.decode_u32(24)
	var bits_per_sample: int = bytes.decode_u16(34)

	var pos: int = 12
	var data_offset: int = 44
	var data_size: int = bytes.size() - 44
	while pos + 8 <= bytes.size():
		var chunk_id: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_len: int = bytes.decode_u32(pos + 4)
		if chunk_id == "data":
			data_offset = pos + 8
			data_size = mini(chunk_len, bytes.size() - data_offset)
			break
		pos += 8 + chunk_len

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.mix_rate = sample_rate
	wav.stereo = (channels == 2)
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.data = bytes.slice(data_offset, data_offset + data_size)
	return wav


func set_voice(voice: String) -> void:
	if voice != "FEMALE" and voice != "MALE":
		FailFast.fail("CRITICAL: Unknown voice '%s'. Must be 'FEMALE' or 'MALE'." % voice)
		return
	self.current_voice = voice


func set_language(lang: String) -> void:
	if lang != "FR" and lang != "EN":
		FailFast.fail("CRITICAL: Unknown language '%s'. Must be 'FR' or 'EN'." % lang)
		return
	self.current_language = lang


func set_available_languages(langs: Array[String]) -> void:
	if langs.is_empty():
		FailFast.fail("CRITICAL: available_languages cannot be empty.")
		return
	self.available_languages = langs.duplicate()


func pick_random_voice() -> String:
	var chosen: String = "FEMALE" if (randi() % 2 == 0) else "MALE"
	set_voice(chosen)
	return chosen


func get_active_voice_dir() -> String:
	if self.current_language == "EN":
		var en_dir: String = self.assets_dir + "/en"
		return en_dir + "/voice_female" if self.current_voice == "FEMALE" else en_dir + "/voice_male"
	return self.female_voice_dir if self.current_voice == "FEMALE" else self.male_voice_dir


func resolve_audio_path(
	symbol: String,
	utterance_type: String,
	prompt_mode: String
) -> String:
	if not FailFast.require_non_empty_str(symbol, "symbol"):
		return ""
	if prompt_mode != "NAME" and prompt_mode != "PHONETIC":
		FailFast.fail("CRITICAL: Unknown prompt_mode '%s'." % prompt_mode)
		return ""

	var clean_sym: String = symbol.strip_edges()
	var is_digit: bool = clean_sym.is_valid_int()
	var cat: String = ""
	if prompt_mode == "PHONETIC" and not is_digit:
		cat = "phonetic"
	else:
		cat = "number" if is_digit else "letter"

	var normalized_sym: String = clean_sym if is_digit else clean_sym.to_upper()
	var prefix: String = ""
	if utterance_type == "question":
		prefix = "q"
	elif utterance_type == "ans_pos":
		prefix = "ans_pos"
	elif utterance_type == "ans_neg":
		prefix = "ans_neg"
	else:
		FailFast.fail("CRITICAL: Unknown utterance type '%s'." % utterance_type)
		return ""

	var filename: String = "%s_%s_%s.mp3" % [prefix, cat, normalized_sym]
	return get_active_voice_dir() + "/" + filename


func play_sfx_correct() -> void:
	if self._sfx_correct != null and self.sfx_player != null:
		self.sfx_player.stream = self._sfx_correct
		if self.sfx_player.is_inside_tree():
			self.sfx_player.play()


func play_sfx_wrong() -> void:
	if self._sfx_wrong != null and self.sfx_player != null:
		self.sfx_player.stream = self._sfx_wrong
		if self.sfx_player.is_inside_tree():
			self.sfx_player.play()


func play_voice(
	symbol: String,
	utterance_type: String,
	prompt_mode: String
) -> bool:
	var path: String = resolve_audio_path(symbol, utterance_type, prompt_mode)
	if path.is_empty():
		return false

	if not _audio_file_exists(path):
		if prompt_mode == "PHONETIC":
			var fallback_path: String = resolve_audio_path(symbol, utterance_type, "NAME")
			if _audio_file_exists(fallback_path):
				var fb_stream: AudioStream = _load_stream(fallback_path)
				if fb_stream != null and self.voice_player != null:
					self.voice_player.stream = fb_stream
					if self.voice_player.is_inside_tree():
						self.voice_player.play()
					return true
		FailFast.fail("CRITICAL: Voice file not found at %s" % path)
		return false

	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return false
	if self.voice_player != null:
		self.voice_player.stream = stream
		if self.voice_player.is_inside_tree():
			self.voice_player.play()
	return true


func is_voice_busy() -> bool:
	if self.voice_player == null or not self.voice_player.is_inside_tree():
		return false
	return self.voice_player.playing


func play_animal_sound(score: int, language: String = "") -> bool:
	if not FailFast.require_in_range_int(score, 0, 10, "score"):
		return false
	var filename: String = str(SCORE_ANIMAL_AUDIO_MAP[score])

	var chosen_lang: String = language
	if chosen_lang.is_empty():
		if self.available_languages.size() > 1:
			chosen_lang = self.available_languages[randi() % self.available_languages.size()]
		else:
			chosen_lang = self.current_language

	var sub_dir: String = "fr" if chosen_lang == "FR" else "en"
	var path: String = self.animals_dir + "/" + sub_dir + "/" + filename

	if not _audio_file_exists(path):
		var fallback_path: String = self.animals_dir + "/" + filename
		if _audio_file_exists(fallback_path):
			path = fallback_path
		else:
			FailFast.fail("CRITICAL: Animal sound file not found at %s" % path)
			return false

	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return false
	if self.voice_player != null:
		self.voice_player.stream = stream
		if self.voice_player.is_inside_tree():
			self.voice_player.play()
	return true


func stop_all() -> void:
	if self.sfx_player != null and self.sfx_player.is_inside_tree():
		self.sfx_player.stop()
	if self.voice_player != null and self.voice_player.is_inside_tree():
		self.voice_player.stop()
