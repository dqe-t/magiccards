class_name TestCoreLogic
extends RefCounted

var passed_count: int = 0
var failed_count: int = 0
var failure_messages: Array[String] = []


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		passed_count += 1
	else:
		failed_count += 1
		failure_messages.append("FAIL: " + msg)


func assert_false(cond: bool, msg: String) -> void:
	assert_true(not cond, msg)


func assert_eq_int(actual: int, expected: int, msg: String) -> void:
	assert_true(actual == expected, "%s (expected %d, got %d)" % [msg, expected, actual])


func assert_eq_str(actual: String, expected: String, msg: String) -> void:
	assert_true(actual == expected, "%s (expected '%s', got '%s')" % [msg, expected, actual])


func run_all() -> void:
	FailFast.test_capture_mode = true
	_test_fail_fast()
	_test_responsive_layout()
	_test_config_manager()
	_test_game_session()
	_test_rainbow_math()
	_test_audio_manager()
	_test_animal_manager()


func _test_fail_fast() -> void:
	# Happy path
	FailFast.clear_last_error()
	assert_true(FailFast.require_positive_int(10, "val"), "FailFast positive int happy path")
	assert_true(FailFast.require_positive_float(1.5, "val"), "FailFast positive float happy path")
	assert_true(FailFast.require_non_empty_str("abc", "val"), "FailFast non-empty str happy path")
	assert_false(FailFast.has_error(), "No error triggered on valid inputs")

	# Failure path 1: non-positive int
	FailFast.clear_last_error()
	assert_false(FailFast.require_positive_int(0, "count"), "FailFast rejects 0")
	assert_true(FailFast.has_error(), "Error recorded for 0")

	# Failure path 2: NaN float & empty string
	FailFast.clear_last_error()
	assert_false(FailFast.require_positive_float(NAN, "duration"), "FailFast rejects NaN")
	assert_true(FailFast.has_error(), "Error recorded for NaN")
	FailFast.clear_last_error()
	assert_false(FailFast.require_non_empty_str("   ", "symbol"), "FailFast rejects whitespace string")
	assert_true(FailFast.has_error(), "Error recorded for whitespace string")


func _test_responsive_layout() -> void:
	# Happy path 1: 27-inch monitor (1920x1080, 96 DPI -> 81.59 effective PPI)
	# Cards are capped at exact playing-card size (210x290) and identical for 3, 4, and 5 cards
	FailFast.clear_last_error()
	var m27_3: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(1920, 1080, 96, 3, 27.0)
	var m27_4: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(1920, 1080, 96, 4, 27.0)
	var m27_5: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(1920, 1080, 96, 5, 27.0)
	assert_eq_int(m27_3.card_width, 210, "27-inch monitor 3 cards width is 210")
	assert_eq_int(m27_3.card_height, 290, "27-inch monitor 3 cards height is 290")
	assert_eq_int(m27_4.card_width, m27_5.card_width, "27-inch monitor 4 and 5 cards have identical width")
	assert_eq_int(m27_3.card_width, m27_5.card_width, "27-inch monitor 3 and 5 cards have identical width")

	# Happy path 2: 10-inch tablet (1920x1200, 224 DPI / 10.1 inches)
	# Card size for 3, 4, and 5 cards is identical and defined by the 5-card fit
	var m10_3: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(1920, 1200, 224, 3, 10.1)
	var m10_4: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(1920, 1200, 224, 4, 10.1)
	var m10_5: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(1920, 1200, 224, 5, 10.1)
	assert_eq_int(m10_3.card_width, m10_5.card_width, "10-inch tablet 3-card width equals 5-card width")
	assert_eq_int(m10_4.card_width, m10_5.card_width, "10-inch tablet 4-card width equals 5-card width")
	assert_eq_int(m10_3.card_height, m10_5.card_height, "10-inch tablet 3-card height equals 5-card height")
	assert_eq_int(m10_3.font_size, m10_5.font_size, "10-inch tablet 3-card font size equals 5-card font size")
	assert_true(m10_5.card_width > 300, "10-inch tablet 5-card width is much larger in px than 27-inch monitor")
	assert_true(
		m10_5.screen_width_ratio > m27_5.screen_width_ratio * 1.35,
		"10-inch tablet cards occupy much more relative screen width than 27-inch monitor"
	)
	assert_true(
		m10_5.physical_width_inches <= ResponsiveLayout.CARD_MAX_INCHES_W + 0.05,
		"10-inch tablet card physical width does not exceed real playing card size"
	)

	# Happy path 3: 6.2-inch phone (2400x1080, 420 DPI / 6.2 inches)
	var m6_3: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(2400, 1080, 420, 3, 6.2)
	var m6_4: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(2400, 1080, 420, 4, 6.2)
	var m6_5: ResponsiveLayout.CardMetrics = ResponsiveLayout.compute_card_metrics(2400, 1080, 420, 5, 6.2)
	assert_eq_int(m6_3.card_width, m6_5.card_width, "Phone 3-card width equals 5-card width")
	assert_eq_int(m6_4.card_width, m6_5.card_width, "Phone 4-card width equals 5-card width")
	assert_eq_int(m6_3.card_height, m6_5.card_height, "Phone 3-card height equals 5-card height")
	assert_true(m6_5.screen_width_ratio >= 0.70, "Phone 5-card layout maximizes screen usage")
	assert_true(
		m6_5.physical_width_inches <= ResponsiveLayout.CARD_MAX_INCHES_W + 0.05,
		"Phone card physical width does not exceed real playing card size"
	)

	# Happy path 4: Config grid auto-wrapping & phone touch button sizing (26 cols on 27" desktop, 13 cols on 10" tablet & S23 phone)
	var cg27: ResponsiveLayout.ConfigGridMetrics = ResponsiveLayout.compute_config_grid_metrics(1920, 1080, 96, 27.0)
	var cg10: ResponsiveLayout.ConfigGridMetrics = ResponsiveLayout.compute_config_grid_metrics(1920, 1200, 224, 10.1)
	var cg_s23: ResponsiveLayout.ConfigGridMetrics = ResponsiveLayout.compute_config_grid_metrics(2340, 1080, 480, 0.0)
	assert_eq_int(cg27.columns_per_row, 26, "27-inch desktop uses 26 columns per row")
	assert_eq_int(cg10.columns_per_row, 13, "10-inch tablet auto-wraps to 13 columns per row")
	assert_eq_int(cg_s23.columns_per_row, 13, "Samsung S23 auto-wraps to 13 columns per row")
	assert_true(cg_s23.box_size >= 115, "Samsung S23 config checkboxes are large and touch-friendly (>= 115px)")
	assert_true(cg_s23.mode_btn_height >= 90, "Samsung S23 config mode buttons are tall and touch-friendly (>= 90px)")

	# Happy path 5: Samsung S23 (2340x1080, 480 DPI) menu title top clearance & score screen non-overlapping bounds
	var menu_s23: ResponsiveLayout.MenuMetrics = ResponsiveLayout.compute_menu_metrics(2340, 1080, 480, 0.0)
	assert_true(
		menu_s23.title_center.y - menu_s23.title_font_size / 2 >= 120,
		"Samsung S23 menu title has generous top margin (>= 120px from top border)"
	)
	assert_true(
		menu_s23.play_rect.position.y >= menu_s23.title_center.y + menu_s23.title_font_size / 2 + 28,
		"Samsung S23 menu play button sits cleanly below title"
	)

	var score_s23: ResponsiveLayout.ScoreMetrics = ResponsiveLayout.compute_score_metrics(2340, 1080, 480, 0.0)
	assert_true(
		score_s23.stars_center_y - score_s23.star_radius >= 90,
		"Samsung S23 score screen stars have generous top margin (>= 90px from top border)"
	)
	var subtitle_top_y: int = score_s23.subtitle_center.y - score_s23.subtitle_font_size
	assert_true(
		score_s23.replay_rect.end.y <= subtitle_top_y - 20,
		"Samsung S23 score replay button stays well above subtitle text"
	)

	# Failure path 1: non-positive viewport dimensions across layout calculators
	FailFast.clear_last_error()
	ResponsiveLayout.compute_card_metrics(0, 1080, 96, 3, 0.0)
	assert_true(FailFast.has_error(), "ResponsiveLayout rejects viewport_w=0")

	FailFast.clear_last_error()
	ResponsiveLayout.compute_menu_metrics(2340, 0, 480, 0.0)
	assert_true(FailFast.has_error(), "compute_menu_metrics rejects viewport_h=0")

	FailFast.clear_last_error()
	ResponsiveLayout.compute_score_metrics(2340, 1080, 0, 0.0)
	assert_true(FailFast.has_error(), "compute_score_metrics rejects system_dpi=0")

	# Failure path 2: invalid card_count or negative override_diag_inches
	FailFast.clear_last_error()
	ResponsiveLayout.compute_card_metrics(1920, 1080, 96, 0, 0.0)
	assert_true(FailFast.has_error(), "ResponsiveLayout rejects card_count=0")

	FailFast.clear_last_error()
	ResponsiveLayout.compute_effective_ppi(1920, 1080, 96, -5.0)
	assert_true(FailFast.has_error(), "ResponsiveLayout rejects negative override_diag_inches")


func _test_config_manager() -> void:
	# Happy path: create, validate, save, and reload config
	FailFast.clear_last_error()
	var test_path: String = "user://test_config_unit.json"
	var symbols: Array[String] = ["A", "B", "C", "D", "E", "1", "2"]
	var cfg: ConfigManager.GameConfigData = ConfigManager.GameConfigData.new(symbols, true, true, true, true)
	assert_true(cfg.validate(), "Valid bilingual config passes validation")
	assert_true(cfg.lang_french and cfg.lang_english, "Both languages enabled in test config")
	assert_true(ConfigManager.save_config(cfg, test_path), "Config saves to user://")
	var loaded: ConfigManager.GameConfigData = ConfigManager.load_config(test_path)
	assert_eq_int(loaded.selected_symbols.size(), 7, "Loaded config preserves symbol count")
	assert_true(loaded.ask_letter_names and loaded.ask_letter_sounds, "Loaded config preserves prompt modes")
	assert_true(loaded.lang_french and loaded.lang_english, "Loaded config preserves language settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))

	# Failure path 1: fewer than 5 distinct case-insensitive symbols
	FailFast.clear_last_error()
	var bad_syms: Array[String] = ["A", "a", "B", "b", "C", "c"]
	var bad_cfg1: ConfigManager.GameConfigData = ConfigManager.GameConfigData.new(bad_syms, true, false)
	assert_false(bad_cfg1.validate(), "Rejects < 5 case-insensitive distinct symbols")
	assert_true(FailFast.has_error(), "FailFast triggered for < 5 distinct symbols")

	# Failure path 2: neither prompt mode enabled, or no languages enabled
	FailFast.clear_last_error()
	var bad_cfg2: ConfigManager.GameConfigData = ConfigManager.GameConfigData.new(symbols, false, false)
	assert_false(bad_cfg2.validate(), "Rejects config with both prompt modes false")
	assert_true(FailFast.has_error(), "FailFast triggered for no prompt modes")

	FailFast.clear_last_error()
	var bad_lang_cfg: ConfigManager.GameConfigData = ConfigManager.GameConfigData.new(symbols, true, false, false, false)
	assert_false(bad_lang_cfg.validate(), "Rejects config with neither French nor English selected")
	assert_true(FailFast.has_error(), "FailFast triggered for no languages")

	FailFast.clear_last_error()
	var invalid_pool: Array[String] = ["A", "B", "C", "D", "99"]
	var bad_cfg3: ConfigManager.GameConfigData = ConfigManager.GameConfigData.new(invalid_pool, true, false)
	assert_false(bad_cfg3.validate(), "Rejects unknown symbol '99'")
	assert_true(FailFast.has_error(), "FailFast triggered for unknown symbol")


func _test_game_session() -> void:
	# Happy path: 10 rounds progression, card counts (3, 4, 5), phonetic rules, scoring
	FailFast.clear_last_error()
	assert_eq_int(GameSession.get_symbol_count_for_round(1), 3, "Round 1 has 3 cards")
	assert_eq_int(GameSession.get_symbol_count_for_round(4), 3, "Round 4 has 3 cards")
	assert_eq_int(GameSession.get_symbol_count_for_round(5), 4, "Round 5 has 4 cards")
	assert_eq_int(GameSession.get_symbol_count_for_round(7), 4, "Round 7 has 4 cards")
	assert_eq_int(GameSession.get_symbol_count_for_round(8), 5, "Round 8 has 5 cards")
	assert_eq_int(GameSession.get_symbol_count_for_round(10), 5, "Round 10 has 5 cards")

	var pool: Array[String] = ["A", "B", "C", "K", "Q", "D", "E", "F", "1", "2"]
	var session: GameSession = GameSession.new(pool, false, true)
	assert_false(FailFast.has_error(), "GameSession initializes cleanly")
	assert_true(session.current_round.language == "FR", "Default session uses French")

	var bilingual_session: GameSession = GameSession.new(pool, true, false, true, true)
	assert_true(bilingual_session.current_round.language in ["FR", "EN"], "Bilingual session assigns valid language to round")

	for r: int in range(1, 11):
		var target: String = session.current_round.target_symbol
		assert_true(session.process_guess(target), "Guessing target solves round %d" % r)
		var has_next: bool = session.advance_to_next_round()
		if r < 10:
			assert_true(has_next, "Advances to next round after round %d" % r)
		else:
			assert_false(has_next, "Game ends after round 10")
	assert_eq_int(session.score, 10, "Perfect game scores 10")
	assert_eq_int(session.get_star_rating(), 3, "Score 10 gets 3 star rating")

	# Failure path 1: initializing with < 5 symbols or no prompt modes
	FailFast.clear_last_error()
	var tiny_pool: Array[String] = ["A", "B", "C"]
	GameSession.new(tiny_pool, true, false)
	assert_true(FailFast.has_error(), "GameSession fails fast on < 5 symbols")

	# Failure path 2: advancing before solving or guessing after game over
	FailFast.clear_last_error()
	var s2: GameSession = GameSession.new(pool, true, false)
	s2.advance_to_next_round()
	assert_true(FailFast.has_error(), "Cannot advance round before target is solved")

	FailFast.clear_last_error()
	session.process_guess("A")
	assert_true(FailFast.has_error(), "Cannot guess after game is over")


func _test_rainbow_math() -> void:
	# Happy path
	FailFast.clear_last_error()
	assert_true(absf(RainbowMath.ease_out_cubic(0.0) - 0.0) < 0.001, "ease_out_cubic(0) == 0")
	assert_true(absf(RainbowMath.ease_out_cubic(1.0) - 1.0) < 0.001, "ease_out_cubic(1) == 1")
	var col: Color = RainbowMath.sample_rainbow_band_color(1.5, 0.85, 0.92, 0.35)
	assert_true(col.a == 1.0, "Rainbow color sample returns valid opaque Color")
	var drop: RainbowMath.StarDropState = RainbowMath.compute_star_drop_state(0.5, 0, -80.0, 200.0)
	assert_eq_int(drop.offset_y, 0, "Star drop settles at target_y after duration")
	var ent_scale: float = RainbowMath.compute_animal_entrance_scale(0.5, 0.45)
	assert_true(absf(ent_scale - 1.0) < 0.001, "Animal entrance scale settles at 1.0")

	# Failure path 1: invalid saturation / feather in sample_rainbow_band_color
	FailFast.clear_last_error()
	RainbowMath.sample_rainbow_band_color(0.0, 1.5, 0.9, 0.3)
	assert_true(FailFast.has_error(), "sample_rainbow_band_color rejects saturation > 1.0")

	FailFast.clear_last_error()
	RainbowMath.sample_rainbow_band_color(0.0, 0.8, 0.9, 1.0)
	assert_true(FailFast.has_error(), "sample_rainbow_band_color rejects feather >= 1.0")

	# Failure path 2: non-positive duration in compute_shake_offset & negative star_index
	FailFast.clear_last_error()
	RainbowMath.compute_shake_offset(0.1, 0.0)
	assert_true(FailFast.has_error(), "compute_shake_offset rejects duration <= 0")

	FailFast.clear_last_error()
	RainbowMath.compute_star_drop_state(0.1, -1, -80.0, 200.0)
	assert_true(FailFast.has_error(), "compute_star_drop_state rejects negative star_index")


func _test_audio_manager() -> void:
	# Happy path
	FailFast.clear_last_error()
	var am: AudioManager = AudioManager.new("res://assets/audio")
	am.set_voice("FEMALE")
	var p1: String = am.resolve_audio_path("a", "question", "NAME")
	assert_eq_str(p1, "res://assets/audio/voice_female/q_letter_A.mp3", "Female letter question path")
	var p2: String = am.resolve_audio_path("b", "ans_pos", "PHONETIC")
	assert_eq_str(p2, "res://assets/audio/voice_female/ans_pos_phonetic_B.mp3", "Phonetic positive path")
	assert_true(am.play_animal_sound(10), "Animal sound 10 loads and plays")
	am.stop_all()
	am.free()
	assert_false(FailFast.has_error(), "AudioManager happy path has no errors")

	# Failure path 1: invalid voice name
	var am_err: AudioManager = AudioManager.new("res://assets/audio")
	FailFast.clear_last_error()
	am_err.set_voice("ROBOT")
	assert_true(FailFast.has_error(), "AudioManager rejects invalid voice name")

	# Failure path 2: empty symbol or out-of-range animal score
	FailFast.clear_last_error()
	am_err.resolve_audio_path("", "question", "NAME")
	assert_true(FailFast.has_error(), "AudioManager rejects empty symbol")

	FailFast.clear_last_error()
	am_err.play_animal_sound(11)
	assert_true(FailFast.has_error(), "AudioManager rejects score 11")
	am_err.free()


func _test_animal_manager() -> void:
	# Happy path
	FailFast.clear_last_error()
	var mgr: AnimalManager = AnimalManager.new("res://assets/images/animals", "res://assets/videos/animals")
	var sub: String = AnimalManager.get_score_subtitle(10)
	assert_eq_str(sub, "Parfait ! - Perfect!", "Score 10 subtitle matches spec")
	var tex: Texture2D = mgr.get_animal_texture(9)
	assert_true(tex != null and tex.get_width() > 0, "Animal texture 9 loads")
	assert_true(mgr.has_video(9), "Score 9 OGV video exists")
	var vstream: VideoStream = mgr.load_video_stream(9)
	assert_true(vstream != null, "Score 9 VideoStream loads")
	assert_false(FailFast.has_error(), "AnimalManager happy path has no errors")

	# Failure path 1: negative score
	FailFast.clear_last_error()
	AnimalManager.get_score_subtitle(-1)
	assert_true(FailFast.has_error(), "AnimalManager rejects score -1")

	# Failure path 2: score > 10
	FailFast.clear_last_error()
	mgr.get_animal_texture(99)
	assert_true(FailFast.has_error(), "AnimalManager rejects score 99")
