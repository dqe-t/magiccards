class_name GameSession
extends RefCounted

const TOTAL_ROUNDS: int = 10
const SILENT_OR_AMBIGUOUS_LETTERS: Array[String] = ["H", "W", "X", "h", "w", "x"]
const K_SOUND_LETTERS: Array[String] = ["C", "K", "Q", "c", "k", "q"]


class RoundData extends RefCounted:
	var round_index: int
	var target_symbol: String
	var displayed_symbols: Array[String]
	var voice_type: String
	var prompt_mode: String
	var language: String = "FR"
	var first_attempt_success: bool = true
	var is_solved: bool = false
	var attempts: int = 0

	func _init(
		p_round_index: int,
		p_target_symbol: String,
		p_displayed_symbols: Array[String],
		p_voice_type: String,
		p_prompt_mode: String,
		p_language: String = "FR"
	) -> void:
		self.round_index = p_round_index
		self.target_symbol = p_target_symbol
		self.displayed_symbols = p_displayed_symbols.duplicate()
		self.voice_type = p_voice_type
		self.prompt_mode = p_prompt_mode
		self.language = p_language


var symbol_pool: Array[String] = []
var ask_letter_names: bool = true
var ask_letter_sounds: bool = false
var lang_french: bool = true
var lang_english: bool = false
var current_round_num: int = 1
var score: int = 0
var round_results: Array[bool] = []
var current_round: RoundData = null
var is_game_over: bool = false


static func get_symbol_count_for_round(round_number: int) -> int:
	if not FailFast.require_in_range_int(round_number, 1, TOTAL_ROUNDS, "round_number"):
		return 3
	if round_number <= 4:
		return 3
	if round_number <= 7:
		return 4
	return 5


static func is_digit_symbol(sym: String) -> bool:
	if sym.is_empty():
		return false
	return sym.is_valid_int()


func _init(
	p_symbol_pool: Array[String],
	p_ask_letter_names: bool,
	p_ask_letter_sounds: bool,
	p_lang_french: bool = true,
	p_lang_english: bool = false
) -> void:
	if not p_ask_letter_names and not p_ask_letter_sounds:
		FailFast.fail("CRITICAL: At least one prompt mode (names or sounds) must be enabled.")
		return
	if not p_lang_french and not p_lang_english:
		FailFast.fail("CRITICAL: At least one language must be enabled.")
		return
	if p_symbol_pool.size() < 5:
		FailFast.fail(
			"CRITICAL: symbol_pool must have at least 5 symbols, got %d." % p_symbol_pool.size()
		)
		return

	self.symbol_pool = p_symbol_pool.duplicate()
	self.ask_letter_names = p_ask_letter_names
	self.ask_letter_sounds = p_ask_letter_sounds
	self.lang_french = p_lang_french
	self.lang_english = p_lang_english
	self.current_round_num = 1
	self.score = 0
	self.round_results = []
	self.is_game_over = false
	self.current_round = _init_round(1, "")


func _init_round(round_num: int, previous_target: String) -> RoundData:
	var available_langs: Array[String] = []
	if self.lang_french:
		available_langs.append("FR")
	if self.lang_english:
		available_langs.append("EN")
	var chosen_lang: String = available_langs[randi() % available_langs.size()]

	if not FailFast.require_in_range_int(round_num, 1, TOTAL_ROUNDS, "round_num"):
		return RoundData.new(1, "A", ["A", "B", "C"], "FEMALE", "NAME", chosen_lang)

	var count: int = get_symbol_count_for_round(round_num)
	var prev_upper: String = previous_target.to_upper() if not previous_target.is_empty() else ""

	var available_targets: Array[String] = []
	for s: String in self.symbol_pool:
		if prev_upper.is_empty() or s.to_upper() != prev_upper:
			available_targets.append(s)

	if available_targets.is_empty():
		FailFast.fail("CRITICAL: No available targets after excluding previous target.")
		return RoundData.new(round_num, "A", ["A", "B", "C"], "FEMALE", "NAME", chosen_lang)

	var target: String = available_targets[randi() % available_targets.size()]
	var prompt_mode: String = "NAME"
	var is_silent: bool = (target.to_upper() == "X") if chosen_lang == "EN" else SILENT_OR_AMBIGUOUS_LETTERS.has(target)
	var is_num: bool = is_digit_symbol(target)

	if self.ask_letter_sounds and not self.ask_letter_names:
		if is_num or is_silent:
			prompt_mode = "NAME"
		else:
			prompt_mode = "PHONETIC"
	elif self.ask_letter_sounds and self.ask_letter_names:
		if not is_num and not is_silent:
			prompt_mode = "NAME" if (randi() % 2 == 0) else "PHONETIC"
		else:
			prompt_mode = "NAME"
	else:
		prompt_mode = "NAME"

	var by_upper: Dictionary = {}
	var target_upper: String = target.to_upper()
	for s: String in self.symbol_pool:
		var u: String = s.to_upper()
		if u != target_upper:
			if not by_upper.has(u):
				var bucket: Array[String] = []
				by_upper[u] = bucket
			var group_arr: Array[String] = by_upper[u]
			group_arr.append(s)

	if prompt_mode == "PHONETIC" and K_SOUND_LETTERS.has(target):
		var non_k_groups: Dictionary = {}
		for k_var: Variant in by_upper.keys():
			var k_str: String = str(k_var)
			if not K_SOUND_LETTERS.has(k_str):
				non_k_groups[k_str] = by_upper[k_str]
		if non_k_groups.size() >= count - 1:
			by_upper = non_k_groups
		elif by_upper.size() >= count - 1 and non_k_groups.size() > 0:
			prompt_mode = "NAME"
		else:
			by_upper = non_k_groups

	if by_upper.size() < count - 1:
		FailFast.fail("CRITICAL: Not enough distractors in pool satisfying phonetic constraints.")
		return RoundData.new(round_num, target, [target], "FEMALE", prompt_mode)

	var all_keys: Array[String] = []
	for k_var: Variant in by_upper.keys():
		all_keys.append(str(k_var))
	all_keys.shuffle()

	var symbols: Array[String] = []
	for i: int in range(count - 1):
		var key: String = all_keys[i]
		var candidates: Array[String] = by_upper[key]
		symbols.append(candidates[randi() % candidates.size()])
	symbols.append(target)
	symbols.shuffle()

	var voice: String = "FEMALE" if (randi() % 2 == 0) else "MALE"
	return RoundData.new(round_num, target, symbols, voice, prompt_mode, chosen_lang)


func process_guess(symbol: String) -> bool:
	if not FailFast.require_non_empty_str(symbol, "symbol"):
		return false
	if self.is_game_over:
		FailFast.fail("CRITICAL: Cannot guess in a finished game session.")
		return false
	if self.current_round == null or self.current_round.is_solved:
		FailFast.fail("CRITICAL: Current round is already solved.")
		return false

	var is_correct: bool = (symbol == self.current_round.target_symbol)
	if is_correct:
		self.current_round.is_solved = true
		if self.current_round.attempts == 0 and self.current_round.first_attempt_success:
			self.score += 1
		if self.round_results.size() < self.current_round_num:
			self.round_results.append(self.current_round.first_attempt_success)
		return true

	self.current_round.attempts += 1
	self.current_round.first_attempt_success = false
	return false


func advance_to_next_round() -> bool:
	if self.current_round == null or not self.current_round.is_solved:
		FailFast.fail("CRITICAL: Cannot advance round before target is solved.")
		return false

	if self.round_results.size() < self.current_round_num:
		self.round_results.append(self.current_round.first_attempt_success)

	if self.current_round_num >= TOTAL_ROUNDS:
		self.is_game_over = true
		return false

	self.current_round_num += 1
	self.current_round = _init_round(self.current_round_num, self.current_round.target_symbol)
	return true


func get_star_rating() -> int:
	if self.score >= 8:
		return 3
	if self.score >= 5:
		return 2
	if self.score >= 1:
		return 1
	return 0
