class_name ResponsiveLayout
extends RefCounted

# Reference 27-inch 16:9 monitor at 1920x1080 has diagonal 2202.9 px -> 81.59 PPI.
# Real playing card physical cap on 27" monitor: 210x290 px at 81.59 PPI = 2.574 in x 3.554 in.
# Card size on any screen is always defined by the size that fits 5 cards (MAX_ROUND_CARDS = 5).
const REF_MONITOR_DIAG_INCHES: float = 27.0
const REF_DESKTOP_PPI: float = 81.5891
const MAX_ROUND_CARDS: int = 5
const CARD_MAX_INCHES_W: float = 210.0 / REF_DESKTOP_PPI
const CARD_MAX_INCHES_H: float = 290.0 / REF_DESKTOP_PPI
const CARD_MAX_INCHES_W_4: float = CARD_MAX_INCHES_W
const CARD_MAX_INCHES_W_5: float = CARD_MAX_INCHES_W


class CardMetrics extends RefCounted:
	var card_width: int
	var card_height: int
	var spacing: int
	var start_x: int
	var card_y: int
	var font_size: int
	var corner_radius: int
	var physical_width_inches: float
	var screen_width_ratio: float


class HeaderMetrics extends RefCounted:
	var back_btn_rect: Rect2i
	var stars_center: Vector2i
	var star_radius: int
	var star_spacing: int
	var ui_scale: float


class ConfigGridMetrics extends RefCounted:
	var box_size: int
	var pad: int
	var columns_per_row: int
	var upper_y: int
	var lower_y: int
	var numbers_y: int
	var mode_btn_width: int
	var mode_btn_height: int
	var mode_spacing: int
	var mode_y: int
	var lang_btn_width: int
	var lang_y: int
	var is_stacked: bool = false
	var error_y: int
	var box_font_size: int
	var mode_font_size: int


class MenuMetrics extends RefCounted:
	var title_center: Vector2i
	var title_font_size: int
	var play_rect: Rect2i
	var config_rect: Rect2i
	var quit_rect: Rect2i


class ScoreMetrics extends RefCounted:
	var stars_center_y: int
	var stars_start_y: int
	var star_radius: int
	var star_spacing: int
	var animal_center: Vector2i
	var animal_size: int
	var replay_rect: Rect2i
	var subtitle_center: Vector2i
	var subtitle_font_size: int


static func compute_effective_ppi(viewport_w: int, viewport_h: int, system_dpi: int, override_diag_inches: float) -> float:
	if not FailFast.require_positive_int(viewport_w, "viewport_w"):
		return REF_DESKTOP_PPI
	if not FailFast.require_positive_int(viewport_h, "viewport_h"):
		return REF_DESKTOP_PPI
	if not FailFast.require_positive_int(system_dpi, "system_dpi"):
		return REF_DESKTOP_PPI
	if is_nan(override_diag_inches) or is_inf(override_diag_inches) or override_diag_inches < 0.0:
		FailFast.fail("CRITICAL: override_diag_inches must be non-negative.")
		return REF_DESKTOP_PPI

	var diag_px: float = sqrt(float(viewport_w * viewport_w + viewport_h * viewport_h))
	if override_diag_inches > 0.0:
		return diag_px / override_diag_inches

	# On desktop Windows/Linux, standard monitors often report logical 96 DPI even on a 27" 1080p panel.
	# If system_dpi <= 110 and viewport is large desktop (>= 1600 wide), treat as 27" monitor PPI.
	if system_dpi <= 110:
		if viewport_w >= 1600:
			return diag_px / REF_MONITOR_DIAG_INCHES
		return REF_DESKTOP_PPI

	return float(system_dpi)


static func compute_card_metrics(viewport_w: int, viewport_h: int, system_dpi: int, card_count: int, override_diag_inches: float) -> CardMetrics:
	var metrics: CardMetrics = CardMetrics.new()
	if not FailFast.require_positive_int(viewport_w, "viewport_w"):
		return metrics
	if not FailFast.require_positive_int(viewport_h, "viewport_h"):
		return metrics
	if not FailFast.require_positive_int(system_dpi, "system_dpi"):
		return metrics
	if not FailFast.require_in_range_int(card_count, 1, 10, "card_count"):
		return metrics

	var ppi: float = compute_effective_ppi(viewport_w, viewport_h, system_dpi, override_diag_inches)
	var aspect: float = CARD_MAX_INCHES_W / CARD_MAX_INCHES_H

	# 1. Physical playing card upper bound in pixels ("at most as big as real playing cards")
	var max_phys_w_px: float = CARD_MAX_INCHES_W * ppi

	# 2. Screen space maximization always sized for 5 cards (MAX_ROUND_CARDS) so 3, 4, and 5 card rounds have identical card size
	var layout_cards: int = maxi(card_count, MAX_ROUND_CARDS)
	var spacing_ratio: float = 0.133333
	var usable_w: float = float(viewport_w) * 0.92
	var header_reserve: float = maxf(68.0, float(viewport_h) * 0.15)
	var bottom_margin: float = maxf(20.0, float(viewport_h) * 0.05)
	var usable_h: float = maxf(100.0, float(viewport_h) - header_reserve - bottom_margin)

	var max_screen_w_by_width: float = usable_w / (float(layout_cards) + float(layout_cards - 1) * spacing_ratio)
	var max_screen_w_by_height: float = usable_h * aspect
	var max_screen_w_px: float = minf(max_screen_w_by_width, max_screen_w_by_height)

	var final_w_f: float = maxf(64.0, minf(max_phys_w_px, max_screen_w_px))
	var final_h_f: float = final_w_f / aspect
	var spacing_f: float = maxf(10.0, final_w_f * spacing_ratio)

	# Ensure 5 cards never exceed 95% of viewport width
	var max_total_f: float = float(layout_cards) * final_w_f + float(layout_cards - 1) * spacing_f
	if max_total_f > float(viewport_w) * 0.95:
		var shrink: float = (float(viewport_w) * 0.95) / max_total_f
		final_w_f *= shrink
		final_h_f *= shrink
		spacing_f *= shrink

	metrics.card_width = maxi(60, int(round(final_w_f)))
	metrics.card_height = maxi(80, int(round(final_h_f)))
	metrics.spacing = maxi(8, int(round(spacing_f)))

	var total_w: int = card_count * metrics.card_width + (card_count - 1) * metrics.spacing
	metrics.start_x = (viewport_w - total_w) / 2

	var card_scale: float = float(metrics.card_height) / 290.0
	metrics.font_size = maxi(28, int(round(110.0 * card_scale)))
	metrics.corner_radius = mini(int(round(28.0 * card_scale)), metrics.card_width / 6)

	var min_top_y: int = int(round(header_reserve))
	var centered_y: int = (viewport_h - metrics.card_height) / 2 + int(round(30.0 * (float(viewport_h) / 1080.0)))
	metrics.card_y = maxi(min_top_y, centered_y)
	if metrics.card_y + metrics.card_height > viewport_h - int(bottom_margin * 0.5):
		metrics.card_y = maxi(min_top_y, (viewport_h + min_top_y - metrics.card_height) / 2)

	metrics.physical_width_inches = float(metrics.card_width) / ppi
	var five_card_total_w: int = layout_cards * metrics.card_width + (layout_cards - 1) * metrics.spacing
	metrics.screen_width_ratio = float(five_card_total_w) / float(viewport_w)
	return metrics


static func compute_header_metrics(viewport_w: int, viewport_h: int, system_dpi: int, override_diag_inches: float) -> HeaderMetrics:
	var m: HeaderMetrics = HeaderMetrics.new()
	if not FailFast.require_positive_int(viewport_w, "viewport_w"):
		return m
	if not FailFast.require_positive_int(viewport_h, "viewport_h"):
		return m
	if not FailFast.require_positive_int(system_dpi, "system_dpi"):
		return m

	var ppi: float = compute_effective_ppi(viewport_w, viewport_h, system_dpi, override_diag_inches)
	var diag_in: float = sqrt(float(viewport_w * viewport_w + viewport_h * viewport_h)) / ppi
	var base_scale: float = minf(float(viewport_w) / 1920.0, float(viewport_h) / 1080.0)
	var ui_boost: float = clampf(18.0 / maxf(6.0, diag_in), 1.0, 1.85) if diag_in <= 12.0 else 1.0
	m.ui_scale = base_scale * ui_boost

	var btn_sz: int = clampi(int(round(64.0 * m.ui_scale)), 54, int(round(float(viewport_h) * 0.14)))
	var margin_x: int = clampi(int(round(36.0 * base_scale)), 16, 60)
	var margin_y: int = clampi(int(round(24.0 * base_scale)), 14, 50)
	m.back_btn_rect = Rect2i(margin_x, margin_y, btn_sz, btn_sz)

	var max_stars_span: int = viewport_w - (margin_x + btn_sz + 24) * 2
	var raw_spacing: int = maxi(24, int(round(46.0 * m.ui_scale)))
	m.star_spacing = mini(raw_spacing, maxi(18, max_stars_span / 9))
	m.star_radius = clampi(int(round(float(m.star_spacing) * 0.35)), 10, 32)
	m.stars_center = Vector2i(viewport_w / 2, margin_y + btn_sz / 2)
	return m


static func compute_config_grid_metrics(viewport_w: int, viewport_h: int, system_dpi: int, override_diag_inches: float) -> ConfigGridMetrics:
	var g: ConfigGridMetrics = ConfigGridMetrics.new()
	if not FailFast.require_positive_int(viewport_w, "viewport_w"):
		return g
	if not FailFast.require_positive_int(viewport_h, "viewport_h"):
		return g
	if not FailFast.require_positive_int(system_dpi, "system_dpi"):
		return g

	var ppi: float = compute_effective_ppi(viewport_w, viewport_h, system_dpi, override_diag_inches)
	var diag_in: float = sqrt(float(viewport_w * viewport_w + viewport_h * viewport_h)) / ppi
	g.columns_per_row = 13 if (diag_in <= 12.5 or viewport_w < 1440) else 26

	var rows_per_alpha: int = 1 if g.columns_per_row == 26 else 2
	var num_rows: int = 1 if g.columns_per_row >= 20 else 2
	var total_rows: int = rows_per_alpha * 2 + num_rows

	if diag_in <= 12.0:
		var hdr: HeaderMetrics = compute_header_metrics(viewport_w, viewport_h, system_dpi, override_diag_inches)
		var side_clearance: int = hdr.back_btn_rect.end.x + 16
		var sym_usable_w: int = maxi(400, viewport_w - side_clearance * 2)
		var est_pad: int = maxi(6, int(round(float(viewport_h) * 0.009)))
		var max_box_w: int = (sym_usable_w - (g.columns_per_row - 1) * est_pad) / g.columns_per_row
		var top_pad: int = maxi(20, int(round(float(viewport_h) * 0.022)))
		var bot_pad: int = maxi(26, int(round(float(viewport_h) * 0.030)))
		var avail_h: int = maxi(240, viewport_h - top_pad - bot_pad)
		var max_box_h: int = int(floor(float(avail_h - est_pad * 8) / (float(total_rows) + 0.88)))
		g.box_size = clampi(mini(max_box_w, max_box_h), 56, 144)
		g.pad = clampi(int(round(float(g.box_size) * 0.08)), 6, 14)
	else:
		var desk_scale: float = minf(float(viewport_w) / 1920.0, float(viewport_h) / 1080.0)
		g.box_size = clampi(int(round(46.0 * desk_scale)), 32, 54)
		g.pad = clampi(int(round(float(g.box_size) * 0.15)), 4, 18)

	var group_gap: int = maxi(g.pad + 6, int(round(float(g.box_size) * (0.16 if diag_in <= 12.0 else 0.35))))
	var alpha_block_h: int = rows_per_alpha * g.box_size + (rows_per_alpha - 1) * g.pad
	var num_block_h: int = num_rows * g.box_size + (num_rows - 1) * g.pad
	var total_grid_h: int = alpha_block_h * 2 + num_block_h + group_gap * 2

	var mode_scale: float = float(g.box_size) / 46.0
	g.mode_btn_height = clampi(int(round(42.0 * mode_scale if diag_in <= 12.0 else 48.0 * mode_scale)), 44, 118)
	g.lang_btn_width = clampi(int(round(240.0 * mode_scale)), 170, 320)
	g.mode_btn_width = clampi(int(round(340.0 * mode_scale)), 220, 460)
	g.mode_spacing = clampi(int(round(20.0 * mode_scale)), 12, 36)

	var total_dual_w: int = g.lang_btn_width + g.mode_spacing + g.mode_btn_width
	g.is_stacked = (total_dual_w + 40 > viewport_w)

	var mode_gap: int = maxi(12, group_gap)
	var full_content_h: int = total_grid_h + mode_gap + (g.mode_btn_height * 2 + 10 if g.is_stacked else g.mode_btn_height)
	var min_top: int = maxi(20, int(round(float(viewport_h) * 0.022))) if diag_in <= 12.0 else maxi(56, int(round(float(viewport_h) * 0.10)))
	var grid_top: int = maxi(min_top, (viewport_h - full_content_h) / 2 - int(round(float(viewport_h) * 0.01)))
	g.upper_y = grid_top
	g.lower_y = g.upper_y + alpha_block_h + group_gap
	g.numbers_y = g.lower_y + alpha_block_h + group_gap

	if g.is_stacked:
		g.lang_y = g.numbers_y + num_block_h + mode_gap
		g.mode_y = g.lang_y + g.mode_btn_height + 10
		g.error_y = mini(viewport_h - 10, g.mode_y + g.mode_btn_height + 12)
	else:
		g.mode_y = mini(viewport_h - g.mode_btn_height - 24, g.numbers_y + num_block_h + mode_gap)
		g.lang_y = g.mode_y
		g.error_y = mini(viewport_h - 10, g.mode_y + g.mode_btn_height + maxi(14, int(round(18.0 * mode_scale))))

	g.box_font_size = maxi(16, int(round(float(g.box_size) * 0.50)))
	g.mode_font_size = maxi(14, int(round(float(g.mode_btn_height) * 0.40)))
	return g


static func compute_menu_metrics(viewport_w: int, viewport_h: int, system_dpi: int, override_diag_inches: float) -> MenuMetrics:
	var m: MenuMetrics = MenuMetrics.new()
	if not FailFast.require_positive_int(viewport_w, "viewport_w"):
		return m
	if not FailFast.require_positive_int(viewport_h, "viewport_h"):
		return m
	if not FailFast.require_positive_int(system_dpi, "system_dpi"):
		return m

	var ppi: float = compute_effective_ppi(viewport_w, viewport_h, system_dpi, override_diag_inches)
	var diag_in: float = sqrt(float(viewport_w * viewport_w + viewport_h * viewport_h)) / ppi
	var base_scale: float = minf(float(viewport_w) / 1920.0, float(viewport_h) / 1080.0)
	var ui_boost: float = clampf(18.0 / maxf(6.0, diag_in), 1.0, 1.70) if diag_in <= 12.0 else 1.0
	var eff_scale: float = base_scale * ui_boost

	var cx: int = viewport_w / 2
	var cy: int = viewport_h / 2
	m.title_font_size = clampi(int(round(77.0 * eff_scale)), 36, int(round(float(viewport_h) * 0.105)))
	var min_title_y: int = maxi(m.title_font_size + 36, int(round(float(viewport_h) * 0.19)))
	m.title_center = Vector2i(cx, maxi(min_title_y, cy - int(round(250.0 * base_scale))))

	var play_sz: int = clampi(int(round(130.0 * eff_scale)), 96, int(round(float(viewport_h) * 0.21)))
	var sub_sz: int = clampi(int(round(80.0 * eff_scale)), 64, int(round(float(viewport_h) * 0.135)))
	var gap: int = maxi(18, int(round(26.0 * base_scale)))
	var sub_gap: int = maxi(14, int(round(18.0 * base_scale)))

	var min_play_y: int = m.title_center.y + m.title_font_size / 2 + maxi(28, int(round(48.0 * base_scale)))
	var play_y: int = maxi(min_play_y, cy - int(round(120.0 * base_scale)))
	var config_y: int = play_y + play_sz + gap
	var quit_y: int = config_y + sub_sz + sub_gap

	m.play_rect = Rect2i(cx - play_sz / 2, play_y, play_sz, play_sz)
	m.config_rect = Rect2i(cx - sub_sz / 2, config_y, sub_sz, sub_sz)
	m.quit_rect = Rect2i(cx - sub_sz / 2, quit_y, sub_sz, sub_sz)
	return m


static func compute_score_metrics(viewport_w: int, viewport_h: int, system_dpi: int, override_diag_inches: float) -> ScoreMetrics:
	var s: ScoreMetrics = ScoreMetrics.new()
	if not FailFast.require_positive_int(viewport_w, "viewport_w"):
		return s
	if not FailFast.require_positive_int(viewport_h, "viewport_h"):
		return s
	if not FailFast.require_positive_int(system_dpi, "system_dpi"):
		return s

	var ppi: float = compute_effective_ppi(viewport_w, viewport_h, system_dpi, override_diag_inches)
	var diag_in: float = sqrt(float(viewport_w * viewport_w + viewport_h * viewport_h)) / ppi
	var base_scale: float = minf(float(viewport_w) / 1920.0, float(viewport_h) / 1080.0)
	var ui_boost: float = clampf(18.0 / maxf(6.0, diag_in), 1.0, 1.70) if diag_in <= 12.0 else 1.0
	var eff_scale: float = base_scale * ui_boost

	var cx: int = viewport_w / 2
	var cy: int = viewport_h / 2

	var max_span: int = int(round(float(viewport_w) * 0.90))
	s.star_spacing = mini(maxi(28, int(round(52.0 * eff_scale))), max_span / 9)
	s.star_radius = clampi(int(round(float(s.star_spacing) * 0.35)), 12, 34)
	var min_stars_y: int = maxi(s.star_radius + 48, int(round(float(viewport_h) * 0.125)))
	s.stars_center_y = maxi(min_stars_y, cy - int(round(340.0 * base_scale)))
	s.stars_start_y = -int(round(80.0 * eff_scale))

	s.subtitle_font_size = clampi(int(round(20.0 * eff_scale)), 15, 32)
	s.subtitle_center = Vector2i(cx, viewport_h - maxi(24, int(round(34.0 * base_scale))))

	var play_sz: int = clampi(int(round(95.0 * eff_scale)), 76, int(round(float(viewport_h) * 0.135)))
	var subtitle_top_y: int = s.subtitle_center.y - s.subtitle_font_size
	var min_gap_above_sub: int = maxi(20, int(round(28.0 * base_scale)))
	var max_btn_y: int = subtitle_top_y - min_gap_above_sub - play_sz
	var btn_y: int = mini(max_btn_y, cy + int(round(260.0 * base_scale)))
	s.replay_rect = Rect2i(cx - play_sz / 2, btn_y, play_sz, play_sz)

	var top_band: int = s.stars_center_y + s.star_radius + maxi(18, int(round(24.0 * base_scale)))
	var bot_band: int = s.replay_rect.position.y - maxi(18, int(round(24.0 * base_scale)))
	var avail_animal_h: int = maxi(180, bot_band - top_band)
	s.animal_size = clampi(int(round(520.0 * eff_scale)), 240, avail_animal_h)
	s.animal_center = Vector2i(cx, (top_band + bot_band) / 2)
	return s

