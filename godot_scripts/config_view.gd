class_name ConfigView
extends RefCounted

var screen_w: int
var screen_h: int
var system_dpi: int
var override_diag_inches: float
var config: ConfigManager.GameConfigData
var config_save_path: String

var checkboxes: Array[UIWidgets.UICheckbox] = []
var btn_back: UIWidgets.UIIconButton = null
var btn_lang_toggle: UIWidgets.UISegmentedToggle = null
var btn_mode_toggle: UIWidgets.UISegmentedToggle = null
var grid_metrics: ResponsiveLayout.ConfigGridMetrics = null

var error_message: String = ""
var error_remaining_time: float = 0.0


func _init(
	p_screen_w: int,
	p_screen_h: int,
	p_system_dpi: int,
	p_override_diag_inches: float,
	p_config: ConfigManager.GameConfigData,
	p_config_save_path: String
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w"):
		return
	if not FailFast.require_positive_int(p_screen_h, "p_screen_h"):
		return
	if not FailFast.require_positive_int(p_system_dpi, "p_system_dpi"):
		return
	if not FailFast.require_not_null(p_config, "p_config"):
		return
	if not FailFast.require_non_empty_str(p_config_save_path, "p_config_save_path"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	self.config = p_config
	self.config_save_path = p_config_save_path
	_rebuild_layout()


func resize(
	p_screen_w: int,
	p_screen_h: int,
	p_system_dpi: int,
	p_override_diag_inches: float
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w"):
		return
	if not FailFast.require_positive_int(p_screen_h, "p_screen_h"):
		return
	if not FailFast.require_positive_int(p_system_dpi, "p_system_dpi"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	_rebuild_layout()


func _rebuild_layout() -> void:
	var header: ResponsiveLayout.HeaderMetrics = ResponsiveLayout.compute_header_metrics(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		self.override_diag_inches
	)
	var b_rect: Rect2i = header.back_btn_rect
	self.btn_back = UIWidgets.UIIconButton.new(
		b_rect,
		"ARROW_LEFT",
		Color.WHITE,
		Color8(240, 240, 245),
		Color8(20, 20, 25),
		maxi(12, int(round(float(b_rect.size.x) * 0.22))),
		Color8(20, 20, 25),
		2
	)

	self.grid_metrics = ResponsiveLayout.compute_config_grid_metrics(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		self.override_diag_inches
	)
	self.checkboxes.clear()

	var selected_set: Dictionary = {}
	for sym: String in self.config.selected_symbols:
		selected_set[sym] = true

	_add_symbol_group(ConfigManager.get_all_uppercase(), self.grid_metrics.upper_y, selected_set)
	_add_symbol_group(ConfigManager.get_all_lowercase(), self.grid_metrics.lower_y, selected_set)
	_add_symbol_group(ConfigManager.get_all_numbers(), self.grid_metrics.numbers_y, selected_set)

	var mw: int = self.grid_metrics.mode_btn_width
	var mh: int = self.grid_metrics.mode_btn_height
	var lw: int = self.grid_metrics.lang_btn_width

	var lang_rect: Rect2i
	var mode_rect: Rect2i
	if self.grid_metrics.is_stacked:
		var lx: int = (self.screen_w - lw) / 2
		var mx: int = (self.screen_w - mw) / 2
		lang_rect = Rect2i(lx, self.grid_metrics.lang_y, lw, mh)
		mode_rect = Rect2i(mx, self.grid_metrics.mode_y, mw, mh)
	else:
		var total_w: int = lw + self.grid_metrics.mode_spacing + mw
		var start_x: int = (self.screen_w - total_w) / 2
		lang_rect = Rect2i(start_x, self.grid_metrics.lang_y, lw, mh)
		mode_rect = Rect2i(start_x + lw + self.grid_metrics.mode_spacing, self.grid_metrics.mode_y, mw, mh)

	self.btn_lang_toggle = UIWidgets.UISegmentedToggle.new(
		lang_rect,
		"Français",
		"English",
		self.config.lang_french,
		self.config.lang_english
	)

	self.btn_mode_toggle = UIWidgets.UISegmentedToggle.new(
		mode_rect,
		"Nom des lettres",
		"Son des lettres",
		self.config.ask_letter_names,
		self.config.ask_letter_sounds
	)


func _add_symbol_group(
	symbols: Array[String],
	start_y: int,
	selected_set: Dictionary
) -> void:
	var max_cols: int = self.grid_metrics.columns_per_row
	var box_sz: int = self.grid_metrics.box_size
	var pad: int = self.grid_metrics.pad
	var total_count: int = symbols.size()

	# If wrapping numbers (20 items) when max_cols == 13, split evenly into 2 rows of 10
	var cols_in_group: int = max_cols
	if total_count == 20 and max_cols < 20:
		cols_in_group = 10

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
	if not FailFast.require_non_empty_str(message, "message"):
		return
	if not FailFast.require_positive_float(duration, "duration"):
		return
	self.error_message = message
	self.error_remaining_time = duration


func update(dt: float) -> void:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return
	if self.error_remaining_time > 0.0:
		self.error_remaining_time = maxf(0.0, self.error_remaining_time - dt)


func handle_click(pos: Vector2i) -> String:
	if self.btn_back != null and self.btn_back.is_clicked(pos):
		return "MENU"

	if self.btn_lang_toggle != null:
		if self.btn_lang_toggle.is_left_clicked(pos):
			if self.btn_lang_toggle.checked_left and not self.btn_lang_toggle.checked_right:
				show_error("Choisis au moins une langue !", 2.5)
				return ""
			self.btn_lang_toggle.checked_left = not self.btn_lang_toggle.checked_left
			self.config.lang_french = self.btn_lang_toggle.checked_left
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""
		if self.btn_lang_toggle.is_right_clicked(pos):
			if self.btn_lang_toggle.checked_right and not self.btn_lang_toggle.checked_left:
				show_error("Choisis au moins une langue !", 2.5)
				return ""
			self.btn_lang_toggle.checked_right = not self.btn_lang_toggle.checked_right
			self.config.lang_english = self.btn_lang_toggle.checked_right
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""

	if self.btn_mode_toggle != null:
		if self.btn_mode_toggle.is_left_clicked(pos):
			if self.btn_mode_toggle.checked_left and not self.btn_mode_toggle.checked_right:
				show_error("Choisis au moins un mode de jeu !", 2.5)
				return ""
			self.btn_mode_toggle.checked_left = not self.btn_mode_toggle.checked_left
			self.config.ask_letter_names = self.btn_mode_toggle.checked_left
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""
		if self.btn_mode_toggle.is_right_clicked(pos):
			if self.btn_mode_toggle.checked_right and not self.btn_mode_toggle.checked_left:
				show_error("Choisis au moins un mode de jeu !", 2.5)
				return ""
			self.btn_mode_toggle.checked_right = not self.btn_mode_toggle.checked_right
			self.config.ask_letter_sounds = self.btn_mode_toggle.checked_right
			ConfigManager.save_config(self.config, self.config_save_path)
			return ""

	for box: UIWidgets.UICheckbox in self.checkboxes:
		if box.is_clicked(pos):
			if box.checked:
				var remaining_distinct: Dictionary = {}
				for b: UIWidgets.UICheckbox in self.checkboxes:
					if b.checked and b != box:
						remaining_distinct[b.label.to_upper()] = true
				if remaining_distinct.size() < ConfigManager.MIN_SELECTED_SYMBOLS:
					show_error(
						"Choisis au moins %d lettres ou chiffres !" % ConfigManager.MIN_SELECTED_SYMBOLS,
						2.5
					)
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


func render(
	canvas: CanvasItem,
	fm: FontManager,
	mouse_pos: Vector2i,
	is_mouse_down: bool
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if not FailFast.require_not_null(fm, "fm"):
		return

	canvas.draw_rect(Rect2(0.0, 0.0, float(self.screen_w), float(self.screen_h)), Color.WHITE, true)
	self.btn_back.render(canvas, mouse_pos, is_mouse_down, 1.0)

	var bold_font: Font = fm.get_ui_font(true)
	for box: UIWidgets.UICheckbox in self.checkboxes:
		box.render(canvas, bold_font, self.grid_metrics.box_font_size, mouse_pos)

	if self.btn_lang_toggle != null:
		self.btn_lang_toggle.render(canvas, bold_font, self.grid_metrics.mode_font_size, mouse_pos)
	if self.btn_mode_toggle != null:
		self.btn_mode_toggle.render(canvas, bold_font, self.grid_metrics.mode_font_size, mouse_pos)

	if self.error_remaining_time > 0.0 and not self.error_message.is_empty():
		var alpha: float = minf(1.0, self.error_remaining_time / 0.4) if self.error_remaining_time < 0.4 else 1.0
		var err_fsize: int = self.grid_metrics.mode_font_size
		var err_sz: Vector2 = bold_font.get_string_size(self.error_message, HORIZONTAL_ALIGNMENT_LEFT, -1, err_fsize)
		var err_pos: Vector2 = Vector2(
			float(self.screen_w) * 0.5 - err_sz.x * 0.5,
			float(self.grid_metrics.error_y)
		)
		var err_col: Color = Color(215.0 / 255.0, 45.0 / 255.0, 45.0 / 255.0, alpha)
		canvas.draw_string(bold_font, err_pos, self.error_message, HORIZONTAL_ALIGNMENT_LEFT, -1, err_fsize, err_col)
