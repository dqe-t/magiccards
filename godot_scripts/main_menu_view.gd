class_name MainMenuView
extends RefCounted

var screen_w: int
var screen_h: int
var system_dpi: int
var override_diag_inches: float

var btn_play: UIWidgets.UIIconButton = null
var btn_config: UIWidgets.UIIconButton = null
var btn_quit: UIWidgets.UIIconButton = null
var metrics: ResponsiveLayout.MenuMetrics = null
var anim_time: float = 0.0
var custom_title: String = ""


func _init(
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
	self.metrics = ResponsiveLayout.compute_menu_metrics(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		self.override_diag_inches
	)
	var play_r: Rect2i = self.metrics.play_rect
	var cfg_r: Rect2i = self.metrics.config_rect
	var quit_r: Rect2i = self.metrics.quit_rect

	self.btn_play = UIWidgets.UIIconButton.new(
		play_r,
		"PLAY",
		Color8(20, 20, 25),
		Color8(50, 50, 60),
		Color.WHITE,
		maxi(18, int(round(float(play_r.size.x) * 0.22))),
		Color8(20, 20, 25),
		0
	)
	self.btn_config = UIWidgets.UIIconButton.new(
		cfg_r,
		"GEAR",
		Color.WHITE,
		Color8(240, 240, 245),
		Color8(20, 20, 25),
		maxi(12, int(round(float(cfg_r.size.x) * 0.22))),
		Color8(20, 20, 25),
		3
	)
	self.btn_quit = UIWidgets.UIIconButton.new(
		quit_r,
		"EXIT",
		Color.WHITE,
		Color8(240, 240, 245),
		Color8(20, 20, 25),
		maxi(12, int(round(float(quit_r.size.x) * 0.22))),
		Color8(20, 20, 25),
		3
	)


func update(dt: float) -> void:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return
	self.anim_time += dt


func handle_click(pos: Vector2i) -> String:
	if self.btn_play != null and self.btn_play.is_clicked(pos):
		return "PLAY"
	if self.btn_config != null and self.btn_config.is_clicked(pos):
		return "CONFIG"
	if self.btn_quit != null and self.btn_quit.is_clicked(pos):
		return "QUIT"
	return ""


static func compute_title_char_color(
	char_x: float,
	total_w: float,
	anim_t: float
) -> Color:
	if is_nan(anim_t) or is_inf(anim_t):
		FailFast.fail("CRITICAL: anim_t must be a valid number.")
		return Color8(20, 20, 25)
	if total_w <= 0.0:
		FailFast.fail("CRITICAL: total_w must be positive.")
		return Color8(20, 20, 25)

	var base_col: Color = Color8(20, 20, 25)
	var cycle: float = 4.5
	var prog: float = fposmod(anim_t, cycle) / cycle
	var sweep_span: float = total_w + 320.0
	var center_u: float = prog * (sweep_span + 280.0) - 140.0
	var dist: float = absf(char_x - center_u) / 160.0
	if dist < 1.0:
		var blend: float = 0.5 * (1.0 + cos(dist * PI))
		var rb: Color = RainbowMath.sample_rainbow_band_color((char_x / 42.0) - anim_t * 2.5, 0.85, 0.92, 0.35)
		return base_col.lerp(rb, blend)
	return base_col


static func get_default_title() -> String:
	return "LES CARTES MAGIQUES" if ConfigManager.is_system_french() else "MAGIC CARDS"


static func get_title_for_profile_or_system(profile: ConfigManager.UserProfile) -> String:
	if profile != null:
		if profile.lang_french and not profile.lang_english:
			return "LES CARTES MAGIQUES"
		if profile.lang_english and not profile.lang_french:
			return "MAGIC CARDS"
	return get_default_title()


func set_custom_title(p_title: String) -> void:
	self.custom_title = p_title


func get_title_text() -> String:
	if not self.custom_title.is_empty():
		return self.custom_title
	return get_default_title()


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

	var title_text: String = get_title_text()
	var title_font: Font = fm.get_title_font()
	var fsize: int = self.metrics.title_font_size
	var full_sz: Vector2 = title_font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var ascent: float = title_font.get_ascent(fsize)
	var start_x: float = float(self.metrics.title_center.x) - full_sz.x * 0.5
	var baseline_y: float = float(self.metrics.title_center.y) + ascent * 0.36

	var cursor_x: float = start_x
	for i: int in range(title_text.length()):
		var ch: String = title_text.substr(i, 1)
		var ch_w: float = title_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var col: Color = compute_title_char_color(cursor_x - start_x + ch_w * 0.5, maxf(1.0, full_sz.x), self.anim_time)
		canvas.draw_string(title_font, Vector2(cursor_x, baseline_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		cursor_x += ch_w

	self.btn_play.render(canvas, mouse_pos, is_mouse_down, 1.0)
	self.btn_config.render(canvas, mouse_pos, is_mouse_down, 1.0)
	self.btn_quit.render(canvas, mouse_pos, is_mouse_down, 1.0)
