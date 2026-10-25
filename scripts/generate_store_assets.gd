extends SceneTree

func _init() -> void:
	var tablet_w: int = 1920
	var tablet_h: int = 1200
	var tablet_dpi: int = 224
	var tablet_diag: float = 10.1

	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(tablet_w, tablet_h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var empty_pool: Array[String] = []
	var fm: FontManager = FontManager.new(empty_pool)

	# Create output folder
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://play_store_assets"))

	# 1. Main Menu (French) - 10-inch Tablet
	ConfigManager.set_test_locale_override("fr_FR")
	var menu_view_fr: MainMenuView = MainMenuView.new(tablet_w, tablet_h, tablet_dpi, tablet_diag)
	menu_view_fr.update(1.78)
	var ctrl_menu_fr: Control = _create_draw_control(menu_view_fr, fm, tablet_w, tablet_h)
	vp.add_child(ctrl_menu_fr)
	await process_frames(4)
	_save_viewport_image(vp, "res://play_store_assets/screenshot_01_menu_fr.png")
	vp.remove_child(ctrl_menu_fr)
	ctrl_menu_fr.free()

	# 2. Main Menu (English) - 10-inch Tablet
	ConfigManager.set_test_locale_override("en_US")
	var menu_view_en: MainMenuView = MainMenuView.new(tablet_w, tablet_h, tablet_dpi, tablet_diag)
	menu_view_en.update(1.62)
	var ctrl_menu_en: Control = _create_draw_control(menu_view_en, fm, tablet_w, tablet_h)
	vp.add_child(ctrl_menu_en)
	await process_frames(4)
	_save_viewport_image(vp, "res://play_store_assets/screenshot_05_menu_en.png")
	vp.remove_child(ctrl_menu_en)
	ctrl_menu_en.free()

	# 3. Configuration Screen - 10-inch Tablet (13 columns, named child profiles, clean toggles)
	ConfigManager.set_test_locale_override("fr_FR")
	var cfg: ConfigManager.GameConfigData = ConfigManager.create_default_config()
	var child_names: Array[String] = ["Léo", "Emma", "Lucas", "Chloé", "Hugo", "Léa"]
	for i: int in range(mini(child_names.size(), cfg.profiles.size())):
		cfg.profiles[i].name = child_names[i]
	var active_p: ConfigManager.UserProfile = cfg.get_active_profile()
	var demo_syms: Array[String] = ["A", "E", "I", "O", "U", "L", "M", "R", "S", "a", "e", "i", "o", "u", "1", "2", "3", "4", "5", "6"]
	active_p.selected_symbols = demo_syms
	active_p.lang_french = true
	active_p.lang_english = true
	active_p.ask_letter_names = true
	active_p.ask_letter_sounds = true

	var cfg_view: ConfigView = ConfigView.new(tablet_w, tablet_h, tablet_dpi, tablet_diag, cfg, "user://temp_config.json")
	cfg_view.update(0.1)
	var ctrl_cfg: Control = _create_draw_control(cfg_view, fm, tablet_w, tablet_h)
	vp.add_child(ctrl_cfg)
	await process_frames(4)
	_save_viewport_image(vp, "res://play_store_assets/screenshot_03_config.png")
	vp.remove_child(ctrl_cfg)
	ctrl_cfg.free()

	# 4. Gameplay Screen - 10-inch Tablet (Earned stars + rainbow card celebration)
	var am: AudioManager = AudioManager.new("res://assets/audio")
	root.add_child(am)
	var session: GameSession = GameSession.new(["M", "A", "7", "E", "O"], true, false, true, false)
	var g_view: GameView = GameView.new(tablet_w, tablet_h, tablet_dpi, tablet_diag, session, am)
	g_view.update(0.8) # Fly in complete
	session.round_results.clear()
	var demo_results: Array[bool] = [true, true, true, true, true, true]
	session.round_results.append_array(demo_results)
	session.current_round_num = 6
	if g_view.cards.size() >= 3:
		g_view.cards[0].symbol = "M"
		g_view.cards[1].symbol = "A"
		g_view.cards[2].symbol = "7"
		g_view.cards[1].trigger_rainbow()
		g_view.cards[1].update(0.22)
	g_view.phase = "SOLVED_FEEDBACK"
	g_view.phase_time = 0.22
	g_view.total_elapsed = 2.4

	var ctrl_game: Control = _create_draw_control(g_view, fm, tablet_w, tablet_h)
	vp.add_child(ctrl_game)
	await process_frames(4)
	_save_viewport_image(vp, "res://play_store_assets/screenshot_02_gameplay.png")
	vp.remove_child(ctrl_game)
	ctrl_game.free()
	am.stop_all()
	am.free()

	# 5. Score / Animal Screen - 10-inch Tablet (Lion reward + 10 golden sparkling stars)
	var animal_mgr: AnimalManager = AnimalManager.new("res://assets/images/animals", "res://assets/videos/animals")
	var r_results: Array[bool] = [true, true, true, true, true, true, true, true, true, true]
	var s_view: ScoreView = ScoreView.new(tablet_w, tablet_h, tablet_dpi, tablet_diag, 9, r_results, animal_mgr, null, null)
	s_view.update(2.2) # Stars fully settled in bright golden yellow with sparkles
	var ctrl_score: Control = _create_draw_control(s_view, fm, tablet_w, tablet_h)
	vp.add_child(ctrl_score)
	await process_frames(4)
	_save_viewport_image(vp, "res://play_store_assets/screenshot_04_score.png")
	vp.remove_child(ctrl_score)
	ctrl_score.free()

	ConfigManager.clear_test_locale_override()
	if FileAccess.file_exists("user://temp_config.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://temp_config.json"))
	print("STORE_SCREENSHOTS_DONE")
	quit()


func process_frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _create_draw_control(view: Variant, fm: FontManager, w: int, h: int) -> Control:
	var c: DrawHelper = DrawHelper.new()
	c.view = view
	c.fm = fm
	c.screen_w = w
	c.screen_h = h
	c.custom_minimum_size = Vector2(float(w), float(h))
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _save_viewport_image(vp: SubViewport, res_path: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		img.save_png(abs_path)
		print("Saved screenshot: ", abs_path)
	else:
		print("Warning: viewport image empty for ", res_path)


class DrawHelper extends Control:
	var view: Variant = null
	var fm: FontManager = null
	var screen_w: int = 1920
	var screen_h: int = 1200

	func _draw() -> void:
		if view != null and fm != null:
			var offscreen_mouse: Vector2i = Vector2i(-100, -100)
			if view is GameView:
				view.render(self, fm, offscreen_mouse, false, false)
			else:
				view.render(self, fm, offscreen_mouse, false)
