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
	_test_profile_ui(host_control)
	_test_config_scrolling(host_control)
	_test_views(host_control)
	_test_dynamic_bilingual_titles_and_localization(host_control)


func _test_config_scrolling(host_control: Control) -> void:
	# Happy path 1: ConfigScrollController vertical scrolling, clamping, and coordinate mapping
	FailFast.clear_last_error()
	var s_ctrl: ConfigScrollController = ConfigScrollController.new()
	s_ctrl.update_content_bounds(800, 400)
	assert_true(s_ctrl.max_scroll_y > 400.0, "Vertical scrollable bounds computed when content exceeds height")

	s_ctrl.on_drag_start()
	assert_false(s_ctrl.on_drag(Vector2(0, -5)), "Small drag movement under threshold does not engage drag")
	assert_false(s_ctrl.is_dragging, "Not dragging yet")

	assert_true(s_ctrl.on_drag(Vector2(0, -25)), "Movement past threshold engages dragging")
	assert_true(s_ctrl.is_dragging, "Dragging state active")
	assert_true(s_ctrl.scroll_y >= 25.0, "scroll_y increases as content is dragged upwards")
	var mapped_pos: Vector2i = s_ctrl.screen_to_content(Vector2i(100, 200))
	assert_true(mapped_pos.y > 200, "screen_to_content shifts Y by scroll_y")
	assert_true(s_ctrl.on_drag_end(), "on_drag_end returns true indicating dragging completed")
	assert_false(s_ctrl.is_dragging, "Dragging state reset after drag end")

	# Happy path 2: ProfileBar horizontal dragging on narrow 6-inch phone screen
	var cfg: ConfigManager.GameConfigData = ConfigManager.create_default_config()
	var back_phone: Rect2i = Rect2i(16, 12, 44, 44)
	var pbar_phone: ProfileBar = ProfileBar.new(800, 400, back_phone, cfg)
	assert_true(pbar_phone.max_scroll_x > 0.0, "6-inch phone enables horizontal scroll for 6 profiles")

	pbar_phone.on_wheel(1)
	assert_true(pbar_phone.scroll_x > 0.0, "Wheel scroll advances horizontal profile scroll")
	pbar_phone.on_drag(Vector2(-30, 0))
	assert_true(pbar_phone.is_dragging, "Dragging horizontally scrolls profile bar")
	assert_true(pbar_phone.on_drag_end(), "ProfileBar drag end returns true")
	assert_true(pbar_phone.button_rects[0].position.x >= back_phone.end.x + 16, "Profile 1 never starts to left of back button clearance")
	var click_back_area: Dictionary = pbar_phone.handle_click(back_phone.get_center())
	assert_eq_str(str(click_back_area.get("action")), "NONE", "Clicks on back button area are ignored by ProfileBar")

	# Happy path 3: Config grid sequential layout & Main menu 6-inch phone vertical balance
	var cg_phone: ResponsiveLayout.ConfigGridMetrics = ResponsiveLayout.compute_config_grid_metrics(800, 400, 96, 6.0)
	var num_rows: int = 2
	var num_block_bottom: int = cg_phone.numbers_y + num_rows * cg_phone.box_size + (num_rows - 1) * cg_phone.pad
	assert_true(cg_phone.lang_y > num_block_bottom, "Language toggle sits strictly below numbers block on phone")
	assert_true(cg_phone.mode_y >= cg_phone.lang_y, "Mode toggle sits below or alongside language toggle")

	var menu_phone: ResponsiveLayout.MenuMetrics = ResponsiveLayout.compute_menu_metrics(800, 400, 96, 6.0)
	assert_true(menu_phone.quit_rect.end.y <= 400 - 30, "Quit button is not cut off at bottom on 800x400 phone screen")
	assert_true(menu_phone.title_center.y >= 40, "Title has clean top breathing room on 800x400 phone screen")

	# Failure path 1: ConfigScrollController rejects non-positive screen_h
	FailFast.clear_last_error()
	s_ctrl.update_content_bounds(800, 0)
	assert_true(FailFast.has_error(), "ConfigScrollController rejects screen_h=0")

	# Failure path 2: Clamping bounds: cannot scroll negative or past max_scroll_y
	s_ctrl.update_content_bounds(600, 400)
	s_ctrl.on_wheel(-999)
	assert_true(s_ctrl.scroll_y == 0.0, "scroll_y clamped at minimum 0.0")
	s_ctrl.on_wheel(999)
	assert_true(s_ctrl.scroll_y == s_ctrl.max_scroll_y, "scroll_y clamped at max_scroll_y")


func _test_profile_ui(host_control: Control) -> void:
	# Happy path: ProfileBar layout, profile selection, pencil rename click, and rename dialog
	FailFast.clear_last_error()
	var cfg: ConfigManager.GameConfigData = ConfigManager.create_default_config()
	var back_r: Rect2i = Rect2i(36, 24, 56, 56)
	var pbar: ProfileBar = ProfileBar.new(1920, 1080, back_r, cfg)

	assert_eq_str(str(pbar.button_rects.size()), "6", "ProfileBar creates 6 button rects")
	assert_true(pbar.button_rects[0].size.x >= 220, "27-inch desktop profile button width is twice as big (>= 220px)")
	assert_true(pbar.button_rects[0].size.y >= 70, "27-inch desktop profile button height is twice as big (>= 70px)")
	assert_true(pbar.font_size >= 24, "27-inch desktop profile button font size is enlarged (>= 24px)")
	assert_true(pbar.pencil_rect.size.x > 0, "Active profile has valid pencil button rect")
	assert_true(pbar.pencil_rect.end.x <= pbar.button_rects[0].end.x - 8, "Pen rect stays comfortably within button bounds")

	var click_p3: Dictionary = pbar.handle_click(pbar.button_rects[3].get_center())
	assert_eq_str(str(click_p3.get("action")), "SELECT", "Clicking profile button 3 triggers SELECT")
	assert_eq_str(str(click_p3.get("index")), "3", "Profile 3 index is 3")

	pbar.set_active_index(3)
	assert_eq_str(str(pbar.active_index), "3", "ProfileBar active index updated to 3")
	var click_pencil: Dictionary = pbar.handle_click(pbar.pencil_rect.get_center())
	assert_eq_str(str(click_pencil.get("action")), "RENAME", "Clicking pencil rect triggers RENAME")
	assert_eq_str(str(click_pencil.get("index")), "3", "Rename index matches active profile 3")

	var rename_dlg: ProfileRenameDialog = ProfileRenameDialog.new()
	host_control.add_child(rename_dlg)
	var renamed_val: Array[String] = [""]
	rename_dlg.open("Profile 3", func(new_name: String) -> void:
		renamed_val[0] = new_name
	)
	assert_true(rename_dlg.is_open(), "Rename dialog is open")
	assert_eq_str(rename_dlg.line_edit.text, "Profile 3", "Rename dialog initialized with current name")
	assert_true(rename_dlg.btn_ok.icon != null, "Rename dialog OK button uses CHECK icon")
	assert_true(rename_dlg.btn_cancel.icon != null, "Rename dialog cancel button uses EXIT icon")
	assert_eq_str(rename_dlg.btn_ok.text, "", "Rename dialog OK button has no text")
	assert_eq_str(rename_dlg.btn_cancel.text, "", "Rename dialog cancel button has no text")

	var p_tex: Texture2D = ProfileBar.get_pencil_texture(16)
	assert_true(p_tex != null and p_tex.get_width() >= 32, "Pencil texture generates supersampled texture for smooth rasterization")

	rename_dlg.line_edit.text = "Luka"
	rename_dlg._on_ok_pressed()
	assert_false(rename_dlg.is_open(), "Rename dialog closes on confirm")
	assert_eq_str(renamed_val[0], "Luka", "Rename callback received updated name")
	rename_dlg.queue_free()

	# Failure path 1: ProfileBar rejects invalid screen dimensions & out of bounds clicks
	FailFast.clear_last_error()
	ProfileBar.new(0, 1080, back_r, cfg)
	assert_true(FailFast.has_error(), "ProfileBar rejects screen_w=0")

	var outside_res: Dictionary = pbar.handle_click(Vector2i(0, 0))
	assert_eq_str(str(outside_res.get("action")), "NONE", "Clicking outside returns action NONE")

	# Failure path 2: Rename dialog rejects empty text & null callback
	FailFast.clear_last_error()
	var fail_dlg: ProfileRenameDialog = ProfileRenameDialog.new()
	host_control.add_child(fail_dlg)
	fail_dlg.open("", Callable())
	assert_true(FailFast.has_error(), "ProfileRenameDialog rejects null callback")

	fail_dlg.open("Test", func(_n: String) -> void: pass)
	fail_dlg.line_edit.text = "   "
	fail_dlg._on_ok_pressed()
	assert_true(fail_dlg.is_open(), "Dialog remains open when user confirms empty name")
	assert_true(fail_dlg.err_label.visible, "Error message displayed on blank name")
	fail_dlg.close()
	fail_dlg.queue_free()



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
	var cfg_view: ConfigView = ConfigView.new(1920, 1200, 224, 10.1, cfg, test_cfg_path, host_control)
	assert_eq_str(
		cfg_view.handle_click(cfg_view.btn_back.rect.get_center()),
		"MENU",
		"ConfigView Back button returns MENU"
	)

	# Test profile switching in ConfigView
	var p2_center: Vector2i = cfg_view.profile_bar.button_rects[1].get_center()
	cfg_view.handle_click(p2_center)
	assert_eq_str(str(cfg_view.config.active_profile_index), "1", "Clicking profile 2 button selects profile 1 (0-indexed)")

	# Test segmented language button toggle and fail-fast validation
	cfg_view.btn_lang_toggle.checked_left = true
	cfg_view.btn_lang_toggle.checked_right = false
	cfg_view.config.lang_french = true
	cfg_view.config.lang_english = false
	var lang_l_center: Vector2i = cfg_view.btn_lang_toggle.get_left_rect().get_center()
	var lang_r_center: Vector2i = cfg_view.btn_lang_toggle.get_right_rect().get_center()
	cfg_view.handle_click(lang_l_center)
	assert_true(cfg_view.error_remaining_time > 0.0, "Unchecking the only selected language triggers error banner")
	cfg_view.handle_click(lang_r_center)
	assert_true(cfg_view.config.lang_english, "Clicking English segment enables English")
	assert_true(cfg_view.config.lang_french, "Français remains enabled (bilingual mode)")

	# Test phone scroll indicator and chevron click in ConfigView
	var cfg_phone: ConfigView = ConfigView.new(800, 400, 96, 6.0, cfg, test_cfg_path, host_control)
	assert_true(cfg_phone.scroll_ctrl.max_scroll_y > 0.0, "800x400 config screen is vertically scrollable")
	cfg_phone.update(0.1)
	assert_true(cfg_phone.scroll_ctrl.chevron_anim_time > 0.0, "Chevron animation timer updates")
	assert_true(cfg_phone.scroll_ctrl.chevron_rect.size.x > 0, "Chevron rect is active when remaining scroll > 8px")
	var prev_scroll: float = cfg_phone.scroll_ctrl.scroll_y
	cfg_phone.handle_click(cfg_phone.scroll_ctrl.chevron_rect.get_center())
	assert_true(cfg_phone.scroll_ctrl.scroll_y > prev_scroll, "Clicking chevron pill scrolls down")
	cfg_phone.scroll_ctrl.scroll_y = cfg_phone.scroll_ctrl.max_scroll_y
	cfg_phone.update(0.1)
	assert_true(cfg_phone.scroll_ctrl.chevron_rect.size.x == 0, "Chevron pill vanishes at bottom of scrollable content")

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
	assert_true(s_view.overlay_ctrl != null, "ScoreView creates foreground overlay control on host")
	if s_view.video_player != null:
		assert_true(
			s_view.overlay_ctrl.get_index() > s_view.video_player.get_index(),
			"ScoreOverlay is placed after VideoStreamPlayer in child order (renders in front)"
		)
	s_view.update(0.5)
	var fm: FontManager = FontManager.new([])
	assert_true(s_view.overlay_ctrl.score_view == s_view, "overlay_ctrl holds reference to score_view")
	assert_eq_str(
		s_view.handle_click(s_view.btn_replay.rect.get_center()),
		"PLAY",
		"ScoreView Replay button returns PLAY"
	)
	var v_rect: Rect2i = s_view.get_video_rect()
	var v_aspect: float = float(v_rect.size.x) / float(v_rect.size.y)
	assert_true(absf(v_aspect - (1280.0 / 720.0)) < 0.05, "ScoreView video rect maintains 16:9 aspect ratio")
	assert_true(s_view.is_animal_clicked(v_rect.get_center()), "ScoreView video rect hit test succeeds")

	# Failure paths for _draw_foreground
	FailFast.clear_last_error()
	s_view._draw_foreground(null, fm, Vector2i.ZERO, false)
	assert_true(FailFast.has_error(), "ScoreView._draw_foreground rejects null target canvas")

	FailFast.clear_last_error()
	var dummy_ctrl: Control = Control.new()
	s_view._draw_foreground(dummy_ctrl, null, Vector2i.ZERO, false)
	assert_true(FailFast.has_error(), "ScoreView._draw_foreground rejects null FontManager")
	dummy_ctrl.free()

	s_view.close()
	assert_true(s_view.overlay_ctrl == null, "ScoreView.close frees and nulls overlay_ctrl")
	am.stop_all()
	am.free()
	FailFast.clear_last_error()
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


func _test_dynamic_bilingual_titles_and_localization(host_control: Control) -> void:
	# 1. Happy path: Language detection and title strings in French and English
	FailFast.clear_last_error()
	ConfigManager.set_test_locale_override("fr_FR")
	assert_true(ConfigManager.is_system_french(), "is_system_french is true for fr_FR")
	assert_eq_str(MainMenuView.get_default_title(), "LES CARTES MAGIQUES", "Default title is French for fr_FR")

	var default_prof_fr: ConfigManager.UserProfile = ConfigManager.create_default_profile(1)
	assert_true(default_prof_fr.name.begins_with("Profil 1"), "Default profile name starts with Profil 1 in French")
	assert_true(default_prof_fr.lang_french, "Default profile has French enabled in French locale")
	assert_false(default_prof_fr.lang_english, "Default profile has English disabled in French locale")

	var menu_fr: MainMenuView = MainMenuView.new(1920, 1080, 96, 27.0)
	assert_eq_str(menu_fr.get_title_text(), "LES CARTES MAGIQUES", "MainMenuView uses French title")

	ConfigManager.set_test_locale_override("en_US")
	assert_false(ConfigManager.is_system_french(), "is_system_french is false for en_US")
	assert_eq_str(MainMenuView.get_default_title(), "MAGIC CARDS", "Default title is English for en_US")

	var default_prof_en: ConfigManager.UserProfile = ConfigManager.create_default_profile(2)
	assert_true(default_prof_en.name.begins_with("Profile 2"), "Default profile name starts with Profile 2 in English")
	assert_false(default_prof_en.lang_french, "Default profile has French disabled in English locale")
	assert_true(default_prof_en.lang_english, "Default profile has English enabled in English locale")

	var menu_en: MainMenuView = MainMenuView.new(1920, 1080, 96, 27.0)
	assert_eq_str(menu_en.get_title_text(), "MAGIC CARDS", "MainMenuView uses English title")

	# Profile-driven title resolution
	var p_fr_only: ConfigManager.UserProfile = ConfigManager.UserProfile.new("Alice", ["A", "B", "C", "D", "E"], true, false, true, false)
	var p_en_only: ConfigManager.UserProfile = ConfigManager.UserProfile.new("Bob", ["A", "B", "C", "D", "E"], true, false, false, true)
	assert_eq_str(MainMenuView.get_title_for_profile_or_system(p_fr_only), "LES CARTES MAGIQUES", "Title for French-only profile is LES CARTES MAGIQUES")
	assert_eq_str(MainMenuView.get_title_for_profile_or_system(p_en_only), "MAGIC CARDS", "Title for English-only profile is MAGIC CARDS")

	# ConfigView mode toggle text in English vs French
	var test_cfg_path: String = "user://test_localization_config.json"
	var test_cfg: ConfigManager.GameConfigData = ConfigManager.create_default_config()

	ConfigManager.set_test_locale_override("en_US")
	var cv_en: ConfigView = ConfigView.new(1920, 1080, 96, 27.0, test_cfg, test_cfg_path, host_control)
	assert_eq_str(cv_en.btn_mode_toggle.label_left, "Letter names", "ConfigView left mode label in English")
	assert_eq_str(cv_en.btn_mode_toggle.label_right, "Letter sounds", "ConfigView right mode label in English")

	ConfigManager.set_test_locale_override("fr_FR")
	var cv_fr: ConfigView = ConfigView.new(1920, 1080, 96, 27.0, test_cfg, test_cfg_path, host_control)
	assert_eq_str(cv_fr.btn_mode_toggle.label_left, "Nom des lettres", "ConfigView left mode label in French")
	assert_eq_str(cv_fr.btn_mode_toggle.label_right, "Son des lettres", "ConfigView right mode label in French")

	# ProfileRenameDialog title and placeholder
	var dlg: ProfileRenameDialog = ProfileRenameDialog.new()
	if host_control != null:
		host_control.add_child(dlg)
	ConfigManager.set_test_locale_override("fr_FR")
	dlg.open("Test", func(_n: String) -> void: pass)
	assert_eq_str(dlg.title_label.text, "Renommer le profil", "Dialog title in French")
	assert_eq_str(dlg.line_edit.placeholder_text, "Nom du profil", "Dialog placeholder in French")

	ConfigManager.set_test_locale_override("en_US")
	dlg.open("Test", func(_n: String) -> void: pass)
	assert_eq_str(dlg.title_label.text, "Rename profile", "Dialog title in English")
	assert_eq_str(dlg.line_edit.placeholder_text, "Profile name", "Dialog placeholder in English")

	# 2. Failure path 1: ProfileRenameDialog empty name validation in French vs English
	ConfigManager.set_test_locale_override("fr_FR")
	dlg.line_edit.text = "   "
	dlg._on_ok_pressed()
	assert_true(dlg.err_label.visible, "Rename dialog error visible on empty input in FR")
	assert_eq_str(dlg.err_label.text, "Le nom ne peut pas être vide !", "Rename dialog empty name error in FR")

	ConfigManager.set_test_locale_override("en_US")
	dlg.line_edit.text = ""
	dlg._on_ok_pressed()
	assert_true(dlg.err_label.visible, "Rename dialog error visible on empty input in EN")
	assert_eq_str(dlg.err_label.text, "Name cannot be empty!", "Rename dialog empty name error in EN")
	dlg.close()
	if host_control != null:
		dlg.queue_free()

	# 3. Failure path 2: Localized error banners in ConfigView for language/mode toggles
	ConfigManager.set_test_locale_override("fr_FR")
	cv_fr.btn_lang_toggle.checked_left = true
	cv_fr.btn_lang_toggle.checked_right = false
	cv_fr.handle_click(cv_fr.btn_lang_toggle.get_left_rect().get_center())
	assert_eq_str(cv_fr.error_message, "Choisis au moins une langue !", "ConfigView uncheck last language error in FR")

	ConfigManager.set_test_locale_override("en_US")
	cv_en.btn_lang_toggle.checked_left = false
	cv_en.btn_lang_toggle.checked_right = true
	cv_en.handle_click(cv_en.btn_lang_toggle.get_right_rect().get_center())
	assert_eq_str(cv_en.error_message, "Select at least one language!", "ConfigView uncheck last language error in EN")

	# Scroll controller failure path validation
	FailFast.clear_last_error()
	var s_ctrl: ConfigScrollController = ConfigScrollController.new()
	s_ctrl.update(-1.0, 1920, 1080)
	assert_true(FailFast.has_error(), "ConfigScrollController rejects negative dt")

	FailFast.clear_last_error()
	s_ctrl.render_indicator(null, 1920, 1080, Vector2i.ZERO)
	assert_true(FailFast.has_error(), "ConfigScrollController rejects null canvas")

	ConfigManager.clear_test_locale_override()
	if FileAccess.file_exists(test_cfg_path):
		DirAccess.remove_absolute(test_cfg_path)
