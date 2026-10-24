class_name MainController
extends Control

var current_state: String = "MENU"
var fm: FontManager = null
var am: AudioManager = null
var animal_mgr: AnimalManager = null
var config: ConfigManager.GameConfigData = null

var menu_view: MainMenuView = null
var config_view: ConfigView = null
var game_view: GameView = null
var score_view: ScoreView = null

var screen_w: int = 1920
var screen_h: int = 1080
var system_dpi: int = 96
var override_diag_inches: float = 0.0
var mouse_pos: Vector2i = Vector2i.ZERO
var is_mouse_down: bool = false
var is_touch_device: bool = false


func _ready() -> void:
	randomize()
	_parse_cli_args()
	_update_viewport_metrics()

	var empty_pool: Array[String] = []
	self.fm = FontManager.new(empty_pool)
	self.am = AudioManager.new("res://assets/audio")
	add_child(self.am)
	self.animal_mgr = AnimalManager.new("res://assets/images/animals", "res://assets/videos/animals")
	self.config = ConfigManager.load_config(ConfigManager.DEFAULT_USER_CONFIG_PATH)

	var os_name: String = OS.get_name()
	self.is_touch_device = (os_name == "Android" or os_name == "iOS")
	if not self.is_touch_device:
		_init_hand_cursor()

	self.menu_view = MainMenuView.new(self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches)
	var active_p: ConfigManager.UserProfile = self.config.get_active_profile()
	self.menu_view.set_custom_title(MainMenuView.get_title_for_profile_or_system(active_p))
	self.config_view = ConfigView.new(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		self.override_diag_inches,
		self.config,
		ConfigManager.DEFAULT_USER_CONFIG_PATH,
		self
	)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _parse_cli_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var all_args: Array[String] = []
	for a: String in args:
		all_args.append(a)
	for a: String in user_args:
		all_args.append(a)

	var use_windowed: bool = false
	var req_w: int = 0
	var req_h: int = 0

	var i: int = 0
	while i < all_args.size():
		var arg: String = all_args[i]
		if arg == "--windowed" or arg == "-w":
			use_windowed = true
		elif arg == "--resolution" and i + 1 < all_args.size():
			var parts: PackedStringArray = all_args[i + 1].split("x")
			if parts.size() == 2:
				req_w = int(parts[0])
				req_h = int(parts[1])
				use_windowed = true
			i += 1
		elif arg == "--width" and i + 1 < all_args.size():
			req_w = int(all_args[i + 1])
			i += 1
		elif arg == "--height" and i + 1 < all_args.size():
			req_h = int(all_args[i + 1])
			i += 1
		elif arg == "--screen-inches" and i + 1 < all_args.size():
			self.override_diag_inches = float(all_args[i + 1])
			i += 1
		i += 1

	if use_windowed or (req_w > 0 and req_h > 0):
		var win: Window = get_window()
		if win != null:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			if req_w > 0 and req_h > 0:
				win.size = Vector2i(req_w, req_h)
				var scr_sz: Vector2i = DisplayServer.screen_get_size()
				win.position = Vector2i(maxi(0, (scr_sz.x - req_w) / 2), maxi(0, (scr_sz.y - req_h) / 2))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		if req_w > 0 and req_h > 0:
			DisplayServer.window_set_size(Vector2i(req_w, req_h))
			self.screen_w = req_w
			self.screen_h = req_h


func _init_hand_cursor() -> void:
	var cursor_path: String = "res://assets/images/icons/hand_cursor.svg"
	if not FileAccess.file_exists(cursor_path):
		return
	var svg_str: String = FileAccess.get_file_as_string(cursor_path)
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_string(svg_str, 56.0 / 128.0)
	if err == OK:
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		DisplayServer.cursor_set_custom_image(tex, DisplayServer.CURSOR_ARROW, Vector2(8.0, 4.0))


func _update_viewport_metrics() -> void:
	var vp_size: Vector2i = Vector2i(get_viewport_rect().size)
	self.screen_w = maxi(320, vp_size.x)
	self.screen_h = maxi(240, vp_size.y)
	var dpi: int = DisplayServer.screen_get_dpi()
	self.system_dpi = maxi(72, dpi)


func _on_viewport_size_changed() -> void:
	_update_viewport_metrics()
	if self.menu_view != null:
		self.menu_view.resize(self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches)
	if self.config_view != null:
		self.config_view.resize(self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches)
	if self.game_view != null:
		self.game_view.resize(self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches)
	if self.score_view != null:
		self.score_view.resize(self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_or_escape()


func _handle_back_or_escape() -> void:
	if self.current_state == "MENU":
		get_tree().quit()
		return
	if self.score_view != null:
		self.score_view.close()
		self.score_view = null
	if self.am != null:
		self.am.stop_all()
	self.current_state = "MENU"
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev: InputEventKey = event
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_ESCAPE:
			_handle_back_or_escape()
			return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		self.mouse_pos = Vector2i(mm.position)
		if self.is_mouse_down and self.current_state == "CONFIG" and self.config_view != null:
			self.config_view.handle_drag(mm.relative, self.mouse_pos)

	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		self.is_touch_device = true
		self.mouse_pos = Vector2i(sd.position)
		if self.current_state == "CONFIG" and self.config_view != null:
			self.config_view.handle_drag(sd.relative, self.mouse_pos)

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			self.mouse_pos = Vector2i(mb.position)
			self.is_mouse_down = mb.pressed
			if mb.pressed:
				if self.current_state != "CONFIG":
					_dispatch_click(self.mouse_pos)
			else:
				if self.current_state == "CONFIG" and self.config_view != null:
					var was_dragging: bool = self.config_view.handle_drag_end()
					if not was_dragging:
						_dispatch_click(self.mouse_pos)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if self.current_state == "CONFIG" and self.config_view != null:
				self.config_view.handle_wheel(-1, self.mouse_pos)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if self.current_state == "CONFIG" and self.config_view != null:
				self.config_view.handle_wheel(1, self.mouse_pos)

	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		self.is_touch_device = true
		self.mouse_pos = Vector2i(st.position)
		self.is_mouse_down = st.pressed
		if not Input.is_emulating_mouse_from_touch():
			if st.pressed:
				if self.current_state != "CONFIG":
					_dispatch_click(self.mouse_pos)
			else:
				if self.current_state == "CONFIG" and self.config_view != null:
					var was_dragging: bool = self.config_view.handle_drag_end()
					if not was_dragging:
						_dispatch_click(self.mouse_pos)


func _dispatch_click(pos: Vector2i) -> void:
	var action: String = ""
	if self.current_state == "MENU" and self.menu_view != null:
		action = self.menu_view.handle_click(pos)
	elif self.current_state == "CONFIG" and self.config_view != null:
		action = self.config_view.handle_click(pos)
	elif self.current_state == "PLAY" and self.game_view != null:
		action = self.game_view.handle_click(pos)
	elif self.current_state == "SCORE" and self.score_view != null:
		action = self.score_view.handle_click(pos)

	if not action.is_empty():
		_transition_to(action)


func _transition_to(action: String) -> void:
	if action == "QUIT":
		if self.score_view != null:
			self.score_view.close()
		if self.am != null:
			self.am.stop_all()
		get_tree().quit()
	elif action == "MENU":
		if self.score_view != null:
			self.score_view.close()
			self.score_view = null
		if self.am != null:
			self.am.stop_all()
		if self.menu_view != null and self.config != null:
			var act_p: ConfigManager.UserProfile = self.config.get_active_profile()
			self.menu_view.set_custom_title(MainMenuView.get_title_for_profile_or_system(act_p))
		self.current_state = "MENU"
	elif action == "CONFIG":
		if self.score_view != null:
			self.score_view.close()
			self.score_view = null
		self.config_view = ConfigView.new(
			self.screen_w,
			self.screen_h,
			self.system_dpi,
			self.override_diag_inches,
			self.config,
			ConfigManager.DEFAULT_USER_CONFIG_PATH,
			self
		)
		self.current_state = "CONFIG"
	elif action == "PLAY":
		if self.score_view != null:
			self.score_view.close()
			self.score_view = null
		if self.am != null:
			self.am.stop_all()
		var session_langs: Array[String] = []
		if self.config.lang_french:
			session_langs.append("FR")
		if self.config.lang_english:
			session_langs.append("EN")
		if self.am != null:
			self.am.set_available_languages(session_langs)

		var session: GameSession = GameSession.new(
			self.config.selected_symbols,
			self.config.ask_letter_names,
			self.config.ask_letter_sounds,
			self.config.lang_french,
			self.config.lang_english
		)
		self.game_view = GameView.new(
			self.screen_w,
			self.screen_h,
			self.system_dpi,
			self.override_diag_inches,
			session,
			self.am
		)
		self.current_state = "PLAY"
	elif action == "SCORE" and self.game_view != null:
		if self.score_view != null:
			self.score_view.close()
		self.score_view = ScoreView.new(
			self.screen_w,
			self.screen_h,
			self.system_dpi,
			self.override_diag_inches,
			self.game_view.session.score,
			self.game_view.session.round_results,
			self.animal_mgr,
			self.am,
			self
		)
		self.current_state = "SCORE"


func _process(delta: float) -> void:
	if self.current_state == "MENU" and self.menu_view != null:
		self.menu_view.update(delta)
	elif self.current_state == "CONFIG" and self.config_view != null:
		self.config_view.update(delta)
	elif self.current_state == "PLAY" and self.game_view != null:
		var res: String = self.game_view.update(delta)
		if res == "SCORE":
			_transition_to("SCORE")
	elif self.current_state == "SCORE" and self.score_view != null:
		self.score_view.update(delta)

	queue_redraw()


func _draw() -> void:
	var hover_enabled: bool = not self.is_touch_device
	if self.current_state == "MENU" and self.menu_view != null:
		self.menu_view.render(self, self.fm, self.mouse_pos, self.is_mouse_down)
	elif self.current_state == "CONFIG" and self.config_view != null:
		self.config_view.render(self, self.fm, self.mouse_pos, self.is_mouse_down)
	elif self.current_state == "PLAY" and self.game_view != null:
		self.game_view.render(self, self.fm, self.mouse_pos, self.is_mouse_down, hover_enabled)
	elif self.current_state == "SCORE" and self.score_view != null:
		self.score_view.render(self, self.fm, self.mouse_pos, self.is_mouse_down)
