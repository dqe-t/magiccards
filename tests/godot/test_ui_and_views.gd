class_name TestUIAndViews
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


func assert_eq_str(actual: String, expected: String, msg: String) -> void:
	assert_true(actual == expected, "%s (expected '%s', got '%s')" % [msg, expected, actual])


func run_all(host_control: Control) -> void:
	FailFast.test_capture_mode = true
	_test_font_manager()
	_test_star_renderer()
	_test_ui_widgets()
	_test_card_node()
	_test_views(host_control)


func _test_font_manager() -> void:
	# Happy path
	FailFast.clear_last_error()
	var empty_pool: Array[String] = []
	var fm: FontManager = FontManager.new(empty_pool)
	var f_round: Font = fm.get_round_font(1)
	assert_true(f_round != null, "FontManager loads round 1 font")
	var offset: float = fm.get_cap_baseline_offset(f_round, 100)
	assert_true(offset > 10.0, "Cap baseline offset is positive")
	assert_false(FailFast.has_error(), "FontManager happy path has no errors")

	# Failure path 1: empty font name
	FailFast.clear_last_error()
	fm.get_font("", true)
	assert_true(FailFast.has_error(), "FontManager rejects empty font_name")

	# Failure path 2: non-positive round index or font_size
	FailFast.clear_last_error()
	fm.get_round_font(0)
	assert_true(FailFast.has_error(), "FontManager rejects round_index 0")

	FailFast.clear_last_error()
	fm.get_cap_baseline_offset(f_round, 0)
	assert_true(FailFast.has_error(), "FontManager rejects font_size 0")


func _test_star_renderer() -> void:
	# Happy path
	FailFast.clear_last_error()
	var tex_filled: Texture2D = StarRenderer.get_star_texture(16, "FILLED")
	var tex_wrong: Texture2D = StarRenderer.get_star_texture(16, "WRONG")
	var tex_unplayed: Texture2D = StarRenderer.get_star_texture(16, "UNPLAYED")
	assert_true(tex_filled != null and tex_wrong != null and tex_unplayed != null, "All 3 star SVG states rasterize")
	var pts: PackedVector2Array = StarRenderer.compute_star_points(Vector2(50.0, 50.0), 20.0, 10.0)
	assert_true(pts.size() == 10, "Star polygon has 10 vertices")
	assert_false(FailFast.has_error(), "StarRenderer happy path has no errors")

	# Failure path 1: unknown star state
	FailFast.clear_last_error()
	StarRenderer.get_star_texture(16, "INVALID_STATE")
	assert_true(FailFast.has_error(), "StarRenderer rejects unknown state")

	# Failure path 2: inner_radius >= outer_radius or non-positive radius
	FailFast.clear_last_error()
	StarRenderer.compute_star_points(Vector2.ZERO, 10.0, 15.0)
	assert_true(FailFast.has_error(), "StarRenderer rejects inner_radius >= outer_radius")

	FailFast.clear_last_error()
	StarRenderer.get_star_texture(0, "FILLED")
	assert_true(FailFast.has_error(), "StarRenderer rejects radius 0")


func _test_ui_widgets() -> void:
	# Happy path
	FailFast.clear_last_error()
	var play_tex: Texture2D = UIWidgets.get_icon_texture("PLAY", 48)
	var gear_tex: Texture2D = UIWidgets.get_icon_texture("GEAR", 48)
	assert_true(play_tex != null and gear_tex != null, "UIWidgets loads PLAY and GEAR SVG icons")

	var btn: UIWidgets.UIIconButton = UIWidgets.UIIconButton.new(
		Rect2i(100, 100, 80, 80),
		"PLAY",
		Color.BLACK,
		Color.GRAY,
		Color.WHITE,
		16,
		Color.BLACK,
		0
	)
	assert_true(btn.is_clicked(Vector2i(140, 140)), "UIIconButton hit test inside rect")
	assert_false(btn.is_clicked(Vector2i(10, 10)), "UIIconButton hit test outside rect")

	var cb: UIWidgets.UICheckbox = UIWidgets.UICheckbox.new(Rect2i(50, 50, 40, 40), "A", false)
	assert_true(cb.toggle(), "UICheckbox toggles to true")

	var seg: UIWidgets.UISegmentedToggle = UIWidgets.UISegmentedToggle.new(
		Rect2i(200, 200, 200, 50),
		"Français",
		"English",
		true,
		false
	)
	assert_true(seg.is_left_clicked(Vector2i(250, 225)), "Segmented toggle left hit test")
	assert_true(seg.is_right_clicked(Vector2i(350, 225)), "Segmented toggle right hit test")
	assert_false(seg.is_left_clicked(Vector2i(100, 100)), "Segmented toggle outside hit test")

	# Failure path 1: unknown icon type
	FailFast.clear_last_error()
	UIWidgets.get_icon_texture("NON_EXISTENT", 32)
	assert_true(FailFast.has_error(), "UIWidgets rejects unknown icon type")

	# Failure path 2: invalid button rect dimensions or hover_scale <= 0
	FailFast.clear_last_error()
	UIWidgets.compute_button_rect(Rect2i(0, 0, 0, 50), 1.0, false)
	assert_true(FailFast.has_error(), "UIWidgets rejects zero-width button rect")

	FailFast.clear_last_error()
	UIWidgets.compute_button_rect(Rect2i(0, 0, 50, 50), 0.0, false)
	assert_true(FailFast.has_error(), "UIWidgets rejects non-positive hover_scale")


func _test_card_node() -> void:
	# Happy path: fly in -> idle -> wrong flash -> rainbow flash -> fly out
	FailFast.clear_last_error()
	var card: CardItem = CardItem.new("A", 0, Rect2i(200, 300, 210, 290), 1920, 0.08)
	assert_eq_str(card.state, "FLYING_IN", "Card starts in FLYING_IN")
	card.update(0.6)
	assert_eq_str(card.state, "IDLE", "Card transitions to IDLE after fly-in")
	assert_true(card.is_clicked(Vector2i(250, 350)), "Card is clickable when IDLE")

	card.trigger_red_flash()
	assert_eq_str(card.state, "RED_FLASH", "Card enters RED_FLASH on wrong click")
	assert_false(card.is_clicked(Vector2i(250, 350)), "Wrong card cannot be clicked again")

	var card2: CardItem = CardItem.new("B", 1, Rect2i(450, 300, 210, 290), 1920, 0.08)
	card2.update(0.7)
	card2.trigger_rainbow()
	assert_eq_str(card2.state, "RAINBOW_FLASH", "Correct card enters RAINBOW_FLASH")
	card2.trigger_fly_out()
	card2.update(0.7)
	assert_true(card2.current_x > 1920.0, "Card flies off right edge of screen")

	# Failure path 1: empty symbol or invalid rect
	FailFast.clear_last_error()
	CardItem.new("", 0, Rect2i(0, 0, 100, 100), 1920, 0.08)
	assert_true(FailFast.has_error(), "CardItem rejects empty symbol")

	# Failure path 2: negative dt or zero-width target rect on resize
	FailFast.clear_last_error()
	card2.update(-0.1)
	assert_true(FailFast.has_error(), "CardItem rejects negative dt")

	FailFast.clear_last_error()
	card2.update_layout_target(Rect2i(0, 0, 0, 100), 1920)
	assert_true(FailFast.has_error(), "CardItem rejects zero-width layout target")


func _test_views(host_control: Control) -> void:
	# Happy path: MainMenuView, ConfigView, GameView, ScoreView
	FailFast.clear_last_error()
	var menu: MainMenuView = MainMenuView.new(1920, 1080, 96, 27.0)
	menu.update(0.1)
	var play_center: Vector2i = menu.btn_play.rect.get_center()
	assert_eq_str(menu.handle_click(play_center), "PLAY", "MainMenuView Play button triggers PLAY")
	assert_eq_str(menu.handle_click(menu.btn_config.rect.get_center()), "CONFIG", "MainMenuView Config button triggers CONFIG")
	assert_eq_str(menu.handle_click(menu.btn_quit.rect.get_center()), "QUIT", "MainMenuView Quit button triggers QUIT")
	assert_true(menu.metrics.title_center.y < 1080 / 2 - 200, "MainMenuView title is positioned higher on screen")
	assert_true(menu.btn_play.rect.position.y < 1080 / 2 - 50, "MainMenuView play button is positioned higher on screen")

	var test_cfg_path: String = "user://test_view_config.json"
	var cfg: ConfigManager.GameConfigData = ConfigManager.create_default_config()
	var cfg_view: ConfigView = ConfigView.new(1920, 1200, 224, 10.1, cfg, test_cfg_path)
	assert_eq_str(
		cfg_view.handle_click(cfg_view.btn_back.rect.get_center()),
		"MENU",
		"ConfigView Back button returns MENU"
	)

	# Test segmented language button toggle and fail-fast validation
	var lang_l_center: Vector2i = cfg_view.btn_lang_toggle.get_left_rect().get_center()
	var lang_r_center: Vector2i = cfg_view.btn_lang_toggle.get_right_rect().get_center()
	cfg_view.handle_click(lang_l_center)
	assert_true(cfg_view.error_remaining_time > 0.0, "Unchecking the only selected language triggers error banner")
	cfg_view.handle_click(lang_r_center)
	assert_true(cfg_view.config.lang_english, "Clicking English segment enables English")
	assert_true(cfg_view.config.lang_french, "Français remains enabled (bilingual mode)")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg_path))

	var am: AudioManager = AudioManager.new("res://assets/audio")
	host_control.add_child(am)
	var session: GameSession = GameSession.new(cfg.selected_symbols, true, false)
	var g_view: GameView = GameView.new(1920, 1080, 96, 27.0, session, am)
	g_view.update(0.7)
	assert_eq_str(g_view.phase, "WAITING_GUESS", "GameView enters WAITING_GUESS after fly-in")
	g_view.resize(1920, 1200, 224, 10.1)
	assert_true(g_view.card_metrics.card_width > 300, "GameView dynamically enlarges cards when resized to 10-inch tablet")

	var animal_mgr: AnimalManager = AnimalManager.new("res://assets/images/animals", "res://assets/videos/animals")
	var r_results: Array[bool] = [true, true, true, true, true, true, true, true, true, true]
	var s_view: ScoreView = ScoreView.new(1920, 1080, 96, 27.0, 10, r_results, animal_mgr, am, host_control)
	s_view.update(0.5)
	assert_eq_str(
		s_view.handle_click(s_view.btn_replay.rect.get_center()),
		"PLAY",
		"ScoreView Replay button returns PLAY"
	)
	var v_rect: Rect2i = s_view.get_video_rect()
	var v_aspect: float = float(v_rect.size.x) / float(v_rect.size.y)
	assert_true(absf(v_aspect - (1280.0 / 720.0)) < 0.05, "ScoreView video rect maintains 16:9 aspect ratio")
	assert_true(s_view.is_animal_clicked(v_rect.get_center()), "ScoreView video rect hit test succeeds")
	s_view.close()
	am.stop_all()
	am.free()
	assert_false(FailFast.has_error(), "All 4 views happy path completed without errors")

	# Failure path 1: invalid dimensions passed to MainMenuView / ConfigView
	FailFast.clear_last_error()
	MainMenuView.new(0, 1080, 96, 27.0)
	assert_true(FailFast.has_error(), "MainMenuView rejects screen_w=0")

	FailFast.clear_last_error()
	ConfigView.new(1920, -10, 96, 27.0, cfg, test_cfg_path)
	assert_true(FailFast.has_error(), "ConfigView rejects negative screen_h")

	# Failure path 2: null dependencies passed to GameView / ScoreView
	FailFast.clear_last_error()
	GameView.new(1920, 1080, 96, 27.0, null, null)
	assert_true(FailFast.has_error(), "GameView rejects null session/audio_mgr")

	FailFast.clear_last_error()
	ScoreView.new(1920, 1080, 96, 27.0, 10, r_results, null, null, null)
	assert_true(FailFast.has_error(), "ScoreView rejects null animal_mgr")
