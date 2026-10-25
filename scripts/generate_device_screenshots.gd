extends SceneTree

const DrawHelper = preload("res://scripts/generate_store_assets.gd").DrawHelper

class DeviceSpec extends RefCounted:
	var id: String
	var name: String
	var width: int
	var height: int
	var dpi: int
	var diag_inches: float

	func _init(p_id: String, p_name: String, p_w: int, p_h: int, p_dpi: int, p_diag: float) -> void:
		id = p_id
		name = p_name
		width = p_w
		height = p_h
		dpi = p_dpi
		diag_inches = p_diag


func _init() -> void:
	var win: Window = root.get_window()
	if win != null:
		win.mode = Window.MODE_MINIMIZED

	# Ensure complete silence during automated screenshot runs
	var master_bus_idx: int = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, true)
		AudioServer.set_bus_volume_db(master_bus_idx, -80.0)

	var output_dir: String = ProjectSettings.globalize_path("res://output/screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)

	var devices: Array[DeviceSpec] = [
		DeviceSpec.new("desktop_27in", "27-inch Desktop Monitor (16:9)", 1920, 1080, 82, 27.0),
		DeviceSpec.new("tablet_10in", "10.1-inch Android Tablet (16:10)", 1920, 1200, 224, 10.1),
		DeviceSpec.new("phone_6in", "6.0-inch Modern Smartphone (19.5:9)", 2340, 1080, 430, 6.0),
		DeviceSpec.new("phone_7in", "7.0-inch Phablet / Large Phone (20:9)", 2400, 1080, 375, 7.0),
		DeviceSpec.new("tablet_ipad_11in", "11.0-inch iPad / Tablet (4:3)", 2048, 1536, 264, 11.0),
		DeviceSpec.new("laptop_15in", "15.6-inch Laptop (16:9)", 1920, 1080, 141, 15.6),
		DeviceSpec.new("ultrawide_34in", "34.0-inch Ultra-Wide Monitor (21:9)", 2560, 1080, 82, 34.0),
		DeviceSpec.new("phone_compact_5in", "5.0-inch Compact Phone (16:9)", 1280, 720, 294, 5.0)
	]

	var empty_pool: Array[String] = []
	var fm: FontManager = FontManager.new(empty_pool)
	var am: AudioManager = AudioManager.new("res://assets/audio")
	root.add_child(am)
	var animal_mgr: AnimalManager = AnimalManager.new("res://assets/images/animals", "res://assets/videos/animals")

	ConfigManager.set_test_locale_override("fr_FR")
	var cfg: ConfigManager.GameConfigData = ConfigManager.create_default_config()
	var child_names: Array[String] = ["Léo", "Emma", "Lucas", "Chloé", "Hugo", "Léa"]
	for i: int in range(mini(child_names.size(), cfg.profiles.size())):
		cfg.profiles[i].name = child_names[i]
	var active_p: ConfigManager.UserProfile = cfg.get_active_profile()
	active_p.selected_symbols = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "a", "b", "c", "d", "e", "1", "2", "3", "4", "5"]

	for dev: DeviceSpec in devices:
		print("Rendering device profile: ", dev.id, " (", dev.width, "x", dev.height, " @ ", dev.diag_inches, "in)")
		var dev_dir: String = output_dir.path_join(dev.id)
		DirAccess.make_dir_recursive_absolute(dev_dir)

		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(dev.width, dev.height)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)

		# Screen 1: Main Menu
		var menu_view: MainMenuView = MainMenuView.new(dev.width, dev.height, dev.dpi, dev.diag_inches)
		menu_view.update(1.2)
		var ctrl_menu: Control = _create_draw_control(menu_view, fm, dev.width, dev.height)
		vp.add_child(ctrl_menu)
		await process_frames(3)
		_save_viewport_image(vp, dev_dir.path_join("01_main_menu.png"))
		vp.remove_child(ctrl_menu)
		ctrl_menu.free()

		# Screen 2: Configuration View
		var cfg_view: ConfigView = ConfigView.new(dev.width, dev.height, dev.dpi, dev.diag_inches, cfg, "user://temp_shot_config.json")
		cfg_view.update(0.1)
		var ctrl_cfg: Control = _create_draw_control(cfg_view, fm, dev.width, dev.height)
		vp.add_child(ctrl_cfg)
		await process_frames(3)
		_save_viewport_image(vp, dev_dir.path_join("02_config_screen.png"))
		vp.remove_child(ctrl_cfg)
		ctrl_cfg.free()

		# Screen 3: Gameplay (3 Cards Active Question)
		var base_pool: Array[String] = ["A", "B", "C", "D", "E", "F", "1", "2", "3", "4", "5"]
		var sess3: GameSession = GameSession.new(base_pool, true, false, true, false)
		sess3.round_results.clear()
		sess3.round_results.append_array([true, true, true, false, true])
		sess3.current_round_num = 6
		var game_view3: GameView = GameView.new(dev.width, dev.height, dev.dpi, dev.diag_inches, sess3, am)
		game_view3.update(0.8)
		var ctrl_game3: Control = _create_draw_control(game_view3, fm, dev.width, dev.height)
		vp.add_child(ctrl_game3)
		await process_frames(3)
		_save_viewport_image(vp, dev_dir.path_join("03_gameplay_3cards.png"))
		vp.remove_child(ctrl_game3)
		ctrl_game3.free()

		# Screen 4: Gameplay (5 Cards Active Question - Maximum Density)
		var sess5: GameSession = GameSession.new(base_pool, true, false, true, false)
		sess5.current_round_num = 8
		sess5.current_round = sess5._init_round(8, "")
		sess5.round_results.clear()
		sess5.round_results.append_array([true, true, true, true, true, true, true])
		var game_view5: GameView = GameView.new(dev.width, dev.height, dev.dpi, dev.diag_inches, sess5, am)
		game_view5.update(0.8)
		var ctrl_game5: Control = _create_draw_control(game_view5, fm, dev.width, dev.height)
		vp.add_child(ctrl_game5)
		await process_frames(3)
		_save_viewport_image(vp, dev_dir.path_join("04_gameplay_5cards.png"))
		vp.remove_child(ctrl_game5)
		ctrl_game5.free()

		# Screen 5: Gameplay (Solved Card Celebration)
		var sess_solv: GameSession = GameSession.new(base_pool, true, false, true, false)
		sess_solv.round_results.clear()
		sess_solv.round_results.append_array([true, true, true, true])
		sess_solv.current_round_num = 5
		var game_view_solv: GameView = GameView.new(dev.width, dev.height, dev.dpi, dev.diag_inches, sess_solv, am)
		game_view_solv.update(0.8)
		if game_view_solv.cards.size() >= 2:
			game_view_solv.cards[1].trigger_rainbow()
			game_view_solv.cards[1].update(0.3)
		game_view_solv.phase = "SOLVED_FEEDBACK"
		game_view_solv.phase_time = 0.3
		var ctrl_solv: Control = _create_draw_control(game_view_solv, fm, dev.width, dev.height)
		vp.add_child(ctrl_solv)
		await process_frames(3)
		_save_viewport_image(vp, dev_dir.path_join("05_gameplay_solved.png"))
		vp.remove_child(ctrl_solv)
		ctrl_solv.free()

		# Screen 6: Score / Animal Screen
		var r_results: Array[bool] = [true, true, true, true, true, true, true, true, true, true]
		var score_view: ScoreView = ScoreView.new(dev.width, dev.height, dev.dpi, dev.diag_inches, 9, r_results, animal_mgr, null, null)
		score_view.update(2.5)
		var ctrl_score: Control = _create_draw_control(score_view, fm, dev.width, dev.height)
		vp.add_child(ctrl_score)
		await process_frames(3)
		_save_viewport_image(vp, dev_dir.path_join("06_score_screen.png"))
		vp.remove_child(ctrl_score)
		ctrl_score.free()

		root.remove_child(vp)
		vp.free()

	ConfigManager.clear_test_locale_override()
	am.stop_all()
	am.free()
	if FileAccess.file_exists("user://temp_shot_config.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://temp_shot_config.json"))

	print("ALL_DEVICE_SCREENSHOTS_COMPLETED")
	quit(0)


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


func _save_viewport_image(vp: SubViewport, abs_path: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(abs_path)
		print("Saved screenshot: ", abs_path)
	else:
		push_error("Failed to capture image for: " + abs_path)
