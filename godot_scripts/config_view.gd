class_name ConfigView
extends RefCounted

var screen_w: int
var screen_h: int
var system_dpi: int
var override_diag_inches: float
var config: ConfigManager.GameConfigData
var config_save_path: String
var host_control: Control = null

var checkboxes: Array[UIWidgets.UICheckbox] = []
var btn_back: UIWidgets.UIIconButton = null
var profile_bar: ProfileBar = null
var rename_dialog: ProfileRenameDialog = null
var btn_lang_toggle: UIWidgets.UISegmentedToggle = null
var btn_mode_toggle: UIWidgets.UISegmentedToggle = null
var grid_metrics: ResponsiveLayout.ConfigGridMetrics = null
var scroll_ctrl: ConfigScrollController = ConfigScrollController.new()
var header_bottom: int = 100
var error_y: int = 0
var error_message: String = ""
var error_remaining_time: float = 0.0


func _init(
	p_screen_w: int,
	p_screen_h: int,
	p_system_dpi: int,
	p_override_diag_inches: float,
	p_config: ConfigManager.GameConfigData,
	p_config_save_path: String,
	p_host_control: Control = null
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w") or not FailFast.require_positive_int(p_screen_h, "p_screen_h"):
		return
	if not FailFast.require_positive_int(p_system_dpi, "p_system_dpi") or not FailFast.require_not_null(p_config, "p_config"):
		return
	if not FailFast.require_non_empty_str(p_config_save_path, "p_config_save_path"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	self.config = p_config
	self.config_save_path = p_config_save_path
	self.host_control = p_host_control
	_rebuild_layout()


func resize(p_screen_w: int, p_screen_h: int, p_system_dpi: int, p_override_diag_inches: float) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w") or not FailFast.require_positive_int(p_screen_h, "p_screen_h"):
		return
	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	_rebuild_layout()


func _rebuild_layout() -> void:
	var header: ResponsiveLayout.HeaderMetrics = ResponsiveLayout.compute_header_metrics(
		self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches
	)
	var b_rect: Rect2i = header.back_btn_rect
	var is_desktop_large: bool = (self.screen_w >= 1600 and self.screen_h >= 900)
	if is_desktop_large:
		var desk_back_sz: int = clampi(int(round(float(b_rect.size.x) * 1.6)), 80, 96)
		b_rect = Rect2i(b_rect.position.x, b_rect.position.y, desk_back_sz, desk_back_sz)

	self.header_bottom = b_rect.end.y + 12
	self.btn_back = UIWidgets.UIIconButton.new(
		b_rect, "ARROW_LEFT", Color.WHITE, Color8(240, 240, 245), Color8(20, 20, 25),
		maxi(12, int(round(float(b_rect.size.x) * 0.22))), Color8(20, 20, 25), 2
	)
	self.profile_bar = ProfileBar.new(self.screen_w, self.screen_h, b_rect, self.config)

	self.grid_metrics = ResponsiveLayout.compute_config_grid_metrics(
		self.screen_w, self.screen_h, self.system_dpi, self.override_diag_inches
	)
	self.checkboxes.clear()

	var active_prof: ConfigManager.UserProfile = self.config.get_active_profile()
	var selected_set: Dictionary = {}
	for sym: String in active_prof.selected_symbols:
		selected_set[sym] = true

	var start_upper_y: int = maxi(self.header_bottom + 16, self.grid_metrics.upper_y)
	var diff_y: int = start_upper_y - self.grid_metrics.upper_y
	_add_symbol_group(ConfigManager.get_all_uppercase(), start_upper_y, selected_set)
	_add_symbol_group(ConfigManager.get_all_lowercase(), self.grid_metrics.lower_y + diff_y, selected_set)
	_add_symbol_group(ConfigManager.get_all_numbers(), self.grid_metrics.numbers_y + diff_y, selected_set)

	var mw: int = self.grid_metrics.mode_btn_width
	var mh: int = self.grid_metrics.mode_btn_height
	var lw: int = self.grid_metrics.lang_btn_width
	var lang_y: int = self.grid_metrics.lang_y + diff_y
	var mode_y: int = self.grid_metrics.mode_y + diff_y

	var lang_rect: Rect2i
	var mode_rect: Rect2i
	if self.grid_metrics.is_stacked:
		lang_rect = Rect2i((self.screen_w - lw) / 2, lang_y, lw, mh)
		mode_rect = Rect2i((self.screen_w - mw) / 2, mode_y, mw, mh)
	else:
		var total_w: int = lw + self.grid_metrics.mode_spacing + mw
		var start_x: int = (self.screen_w - total_w) / 2
		lang_rect = Rect2i(start_x, lang_y, lw, mh)
		mode_rect = Rect2i(start_x + lw + self.grid_metrics.mode_spacing, mode_y, mw, mh)

	var is_fr: bool = ConfigManager.is_system_french()
	var mode_left: String = "Nom des lettres" if is_fr else "Letter names"
	var mode_right: String = "Son des lettres" if is_fr else "Letter sounds"
	self.btn_lang_toggle = UIWidgets.UISegmentedToggle.new(lang_rect, "Français", "English", active_prof.lang_french, active_prof.lang_english)
	self.btn_mode_toggle = UIWidgets.UISegmentedToggle.new(mode_rect, mode_left, mode_right, active_prof.ask_letter_names, active_prof.ask_letter_sounds)

	self.error_y = self.grid_metrics.error_y + diff_y
	var content_bottom: int = maxi(mode_rect.end.y + 36, self.error_y + 40)
	self.scroll_ctrl.update_content_bounds(content_bottom, self.screen_h)


func _sync_ui_with_active_profile() -> void:
	var prof: ConfigManager.UserProfile = self.config.get_active_profile()
	var selected_set: Dictionary = {}
	for sym: String in prof.selected_symbols:
		selected_set[sym] = true
	for box: UIWidgets.UICheckbox in self.checkboxes:
		box.checked = selected_set.has(box.label)
	if self.btn_lang_toggle != null:
		self.btn_lang_toggle.checked_left = prof.lang_french
		self.btn_lang_toggle.checked_right = prof.lang_english
	if self.btn_mode_toggle != null:
		self.btn_mode_toggle.checked_left = prof.ask_letter_names
		self.btn_mode_toggle.checked_right = prof.ask_letter_sounds
	if self.profile_bar != null:
		self.profile_bar.set_active_index(self.config.active_profile_index)


func _start_rename_profile(idx: int) -> void:
	if self.host_control == null:
		return
	if self.rename_dialog == null:
		self.rename_dialog = ProfileRenameDialog.new()
		self.host_control.add_child(self.rename_dialog)
	var current_name: String = self.config.profiles[idx].name if idx < self.config.profiles.size() else ""
	self.rename_dialog.open(current_name, func(new_name: String) -> void:
		self.config.rename_profile(idx, new_name)
		ConfigManager.save_config(self.config, self.config_save_path)
		if self.profile_bar != null:
			self.profile_bar.update_profiles(self.config)
	)


func _add_symbol_group(symbols: Array[String], start_y: int, selected_set: Dictionary) -> void:
	var max_cols: int = self.grid_metrics.columns_per_row
	var box_sz: int = self.grid_metrics.box_size
	var pad: int = self.grid_metrics.pad
	var total_count: int = symbols.size()
	var cols_in_group: int = 10 if (total_count == 20 and max_cols < 20) else max_cols

	var idx: int = 0
	var row: int = 0
	while idx < total_count:
		var count_this_row: int = mini(cols_in_group, total_count - idx)
		var row_w: int = count_this_row * box_sz + (count_this_row - 1) * pad
		var start_x: int = (self.screen_w - row_w) / 2
		var y: int = start_y + row * (box_sz + pad)
		for c: int in range(count_this_row):
			var sym: String = symbols[idx + c]
			var r: Rect2i = Rect2i(start_x + c * (box_sz + pad), y, box_sz, box_sz)
			self.checkboxes.append(UIWidgets.UICheckbox.new(r, sym, selected_set.has(sym)))
		idx += count_this_row
		row += 1


func show_error(message: String, duration: float) -> void:
	if not FailFast.require_non_empty_str(message, "message") or not FailFast.require_positive_float(duration, "duration"):
		return
	self.error_message = message
	self.error_remaining_time = duration


func update(dt: float) -> void:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return
	if self.error_remaining_time > 0.0:
		self.error_remaining_time = maxf(0.0, self.error_remaining_time - dt)
	self.scroll_ctrl.update(dt, self.screen_w, self.screen_h)


func handle_drag(relative: Vector2, mouse_pos: Vector2i) -> bool:
	if mouse_pos.y <= self.header_bottom and self.profile_bar != null:
		return self.profile_bar.on_drag(relative)
	return self.scroll_ctrl.on_drag(relative)


func handle_drag_end() -> bool:
	var p_drag: bool = self.profile_bar.on_drag_end() if self.profile_bar != null else false
	var c_drag: bool = self.scroll_ctrl.on_drag_end()
	return p_drag or c_drag


func handle_wheel(direction: int, mouse_pos: Vector2i) -> void:
	if mouse_pos.y <= self.header_bottom and self.profile_bar != null:
		self.profile_bar.on_wheel(direction)
	else:
		self.scroll_ctrl.on_wheel(direction)


func handle_click(pos: Vector2i) -> String:
	if self.rename_dialog != null and self.rename_dialog.is_open():
		return ""

	if pos.y <= self.header_bottom:
		if self.btn_back != null and self.btn_back.is_clicked(pos):
			return "MENU"
		if self.profile_bar != null:
			var p_act: Dictionary = self.profile_bar.handle_click(pos)
			var act_type: String = str(p_act.get("action", "NONE"))
			if act_type == "SELECT":
				var idx: int = int(p_act.get("index", 0))
				if idx != self.config.active_profile_index:
					self.config.set_active_profile_index(idx)
					ConfigManager.save_config(self.config, self.config_save_path)
					_sync_ui_with_active_profile()
				return ""
			elif act_type == "RENAME":
				_start_rename_profile(int(p_act.get("index", 0)))
				return ""
		return ""

	if self.scroll_ctrl.handle_indicator_click(pos):
		return ""

	var is_fr: bool = ConfigManager.is_system_french()
	var err_lang: String = "Choisis au moins une langue !" if is_fr else "Select at least one language!"
	var err_mode: String = "Choisis au moins un mode de jeu !" if is_fr else "Select at least one game mode!"
	var err_sym: String = ("Choisis au moins %d lettres ou chiffres !" if is_fr else "Select at least %d letters or numbers!") % ConfigManager.MIN_SELECTED_SYMBOLS

	var c_pos: Vector2i = self.scroll_ctrl.screen_to_content(pos)
	if self.btn_lang_toggle != null:
		if self.btn_lang_toggle.is_left_clicked(c_pos):
			if self.btn_lang_toggle.checked_left and not self.btn_lang_toggle.checked_right:
				show_error(err_lang, 2.5)
				return ""
			self.btn_lang_toggle.checked_left = not self.btn_lang_toggle.checked_left
			self.config.lang_french = self.btn_lang_toggle.checked_left
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""
		if self.btn_lang_toggle.is_right_clicked(c_pos):
			if self.btn_lang_toggle.checked_right and not self.btn_lang_toggle.checked_left:
				show_error(err_lang, 2.5)
				return ""
			self.btn_lang_toggle.checked_right = not self.btn_lang_toggle.checked_right
			self.config.lang_english = self.btn_lang_toggle.checked_right
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""

	if self.btn_mode_toggle != null:
		if self.btn_mode_toggle.is_left_clicked(c_pos):
			if self.btn_mode_toggle.checked_left and not self.btn_mode_toggle.checked_right:
				show_error(err_mode, 2.5)
				return ""
			self.btn_mode_toggle.checked_left = not self.btn_mode_toggle.checked_left
			self.config.ask_letter_names = self.btn_mode_toggle.checked_left
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""
		if self.btn_mode_toggle.is_right_clicked(c_pos):
			if self.btn_mode_toggle.checked_right and not self.btn_mode_toggle.checked_left:
				show_error(err_mode, 2.5)
				return ""
			self.btn_mode_toggle.checked_right = not self.btn_mode_toggle.checked_right
			self.config.ask_letter_sounds = self.btn_mode_toggle.checked_right
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""

	for box: UIWidgets.UICheckbox in self.checkboxes:
		if box.is_clicked(c_pos):
			if box.checked:
				var remaining_distinct: Dictionary = {}
				for b: UIWidgets.UICheckbox in self.checkboxes:
					if b.checked and b != box:
						remaining_distinct[b.label.to_upper()] = true
				if remaining_distinct.size() < ConfigManager.MIN_SELECTED_SYMBOLS:
					show_error(err_sym, 2.5)
					return ""

			box.toggle()
			var updated_symbols: Array[String] = []
			for b: UIWidgets.UICheckbox in self.checkboxes:
				if b.checked:
					updated_symbols.append(b.label)
			self.config.selected_symbols = updated_symbols
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""

	return ""


func render(canvas: CanvasItem, fm: FontManager, mouse_pos: Vector2i, is_mouse_down: bool) -> void:
	if not FailFast.require_not_null(canvas, "canvas") or not FailFast.require_not_null(fm, "fm"):
		return

	canvas.draw_rect(Rect2(0.0, 0.0, float(self.screen_w), float(self.screen_h)), Color.WHITE, true)
	var bold_font: Font = fm.get_ui_font(true)

	# 1. Render vertically scrollable configuration content
	canvas.draw_set_transform(Vector2(0.0, -self.scroll_ctrl.scroll_y))
	var c_mouse: Vector2i = self.scroll_ctrl.screen_to_content(mouse_pos)
	for box: UIWidgets.UICheckbox in self.checkboxes:
		box.render(canvas, bold_font, self.grid_metrics.box_font_size, c_mouse)

	if self.btn_lang_toggle != null:
		self.btn_lang_toggle.render(canvas, bold_font, self.grid_metrics.mode_font_size, c_mouse)
	if self.btn_mode_toggle != null:
		self.btn_mode_toggle.render(canvas, bold_font, self.grid_metrics.mode_font_size, c_mouse)

	if self.error_remaining_time > 0.0 and not self.error_message.is_empty():
		var alpha: float = minf(1.0, self.error_remaining_time / 0.4) if self.error_remaining_time < 0.4 else 1.0
		var err_fsize: int = self.grid_metrics.mode_font_size
		var err_sz: Vector2 = bold_font.get_string_size(self.error_message, HORIZONTAL_ALIGNMENT_LEFT, -1, err_fsize)
		var err_pos: Vector2 = Vector2(float(self.screen_w) * 0.5 - err_sz.x * 0.5, float(self.error_y))
		var err_col: Color = Color(215.0 / 255.0, 45.0 / 255.0, 45.0 / 255.0, alpha)
		canvas.draw_string(bold_font, err_pos, self.error_message, HORIZONTAL_ALIGNMENT_LEFT, -1, err_fsize, err_col)

	# 2. Reset transform and render top navigation header bar (opaque mask + profiles + margin masks + back button)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_rect(Rect2(0.0, 0.0, float(self.screen_w), float(self.header_bottom)), Color.WHITE, true)

	if self.profile_bar != null:
		self.profile_bar.render(canvas, bold_font, mouse_pos, is_mouse_down)

	# Mask left margin so scrolling profiles slide cleanly under the back button
	var left_mask_w: float = float(self.btn_back.rect.end.x + 8) if self.btn_back != null else float(self.header_bottom)
	canvas.draw_rect(Rect2(0.0, 0.0, left_mask_w, float(self.header_bottom)), Color.WHITE, true)

	# Mask right margin
	if self.profile_bar != null:
		var right_mask_x: float = float(self.profile_bar.bar_rect.end.x)
		if right_mask_x < float(self.screen_w):
			canvas.draw_rect(Rect2(right_mask_x, 0.0, float(self.screen_w) - right_mask_x, float(self.header_bottom)), Color.WHITE, true)

	self.btn_back.render(canvas, mouse_pos, is_mouse_down, 1.0)
	canvas.draw_line(Vector2(0.0, float(self.header_bottom)), Vector2(float(self.screen_w), float(self.header_bottom)), Color8(230, 230, 235), 1.5)

	# 3. Bottom gradient peek mask and bouncing chevron pill
	self.scroll_ctrl.render_indicator(canvas, self.screen_w, self.screen_h, mouse_pos)
