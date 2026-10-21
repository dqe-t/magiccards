class_name GameView
extends RefCounted

var screen_w: int
var screen_h: int
var system_dpi: int
var override_diag_inches: float
var session: GameSession
var audio_mgr: AudioManager

var cards: Array[CardItem] = []
var phase: String = "FLYING_IN"
var phase_time: float = 0.0
var total_elapsed: float = 0.0
var has_played_question: bool = false

var header_metrics: ResponsiveLayout.HeaderMetrics = null
var card_metrics: ResponsiveLayout.CardMetrics = null
var btn_menu: UIWidgets.UIIconButton = null


func _init(
	p_screen_w: int,
	p_screen_h: int,
	p_system_dpi: int,
	p_override_diag_inches: float,
	p_session: GameSession,
	p_audio_mgr: AudioManager
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w"):
		return
	if not FailFast.require_positive_int(p_screen_h, "p_screen_h"):
		return
	if not FailFast.require_positive_int(p_system_dpi, "p_system_dpi"):
		return
	if not FailFast.require_not_null(p_session, "p_session"):
		return
	if not FailFast.require_not_null(p_audio_mgr, "p_audio_mgr"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	self.session = p_session
	self.audio_mgr = p_audio_mgr
	_rebuild_header()
	_setup_round()


func _rebuild_header() -> void:
	self.header_metrics = ResponsiveLayout.compute_header_metrics(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		self.override_diag_inches
	)
	var b_rect: Rect2i = self.header_metrics.back_btn_rect
	self.btn_menu = UIWidgets.UIIconButton.new(
		b_rect,
		"ARROW_LEFT",
		Color.WHITE,
		Color8(240, 240, 245),
		Color8(20, 20, 25),
		maxi(12, int(round(float(b_rect.size.x) * 0.22))),
		Color8(20, 20, 25),
		2
	)


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
	_rebuild_header()

	if self.cards.size() > 0:
		self.card_metrics = ResponsiveLayout.compute_card_metrics(
			self.screen_w,
			self.screen_h,
			self.system_dpi,
			self.cards.size(),
			self.override_diag_inches
		)
		for i: int in range(self.cards.size()):
			var r: Rect2i = Rect2i(
				self.card_metrics.start_x + i * (self.card_metrics.card_width + self.card_metrics.spacing),
				self.card_metrics.card_y,
				self.card_metrics.card_width,
				self.card_metrics.card_height
			)
			self.cards[i].update_layout_target(r, self.screen_w)


func _setup_round() -> void:
	self.cards.clear()
	self.phase = "FLYING_IN"
	self.phase_time = 0.0
	self.has_played_question = false

	var round_data: GameSession.RoundData = self.session.current_round
	self.audio_mgr.set_language(round_data.language)
	self.audio_mgr.set_voice(round_data.voice_type)

	var symbols: Array[String] = round_data.displayed_symbols
	var n: int = symbols.size()
	self.card_metrics = ResponsiveLayout.compute_card_metrics(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		n,
		self.override_diag_inches
	)

	for i: int in range(n):
		var r: Rect2i = Rect2i(
			self.card_metrics.start_x + i * (self.card_metrics.card_width + self.card_metrics.spacing),
			self.card_metrics.card_y,
			self.card_metrics.card_width,
			self.card_metrics.card_height
		)
		self.cards.append(CardItem.new(symbols[i], i, r, self.screen_w, 0.08))


func handle_click(pos: Vector2i) -> String:
	if self.btn_menu != null and self.btn_menu.is_clicked(pos):
		self.audio_mgr.stop_all()
		return "MENU"

	if self.phase == "WAITING_GUESS":
		for card: CardItem in self.cards:
			if card.is_clicked(pos):
				_handle_card_click(card)
				break
	return ""


func _handle_card_click(card: CardItem) -> void:
	if card.is_wrong:
		return
	var is_correct: bool = self.session.process_guess(card.symbol)
	if is_correct:
		self.audio_mgr.play_sfx_correct()
		card.trigger_rainbow()
		self.audio_mgr.play_voice(card.symbol, "ans_pos", self.session.current_round.prompt_mode)
		self.phase = "SOLVED_FEEDBACK"
		self.phase_time = 0.0
	else:
		self.audio_mgr.play_sfx_wrong()
		card.trigger_red_flash()
		self.audio_mgr.play_voice(card.symbol, "ans_neg", self.session.current_round.prompt_mode)


func update(dt: float) -> String:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return ""
	self.phase_time += dt
	self.total_elapsed += dt

	for card: CardItem in self.cards:
		card.update(dt)

	if self.phase == "FLYING_IN":
		if not self.has_played_question and self.phase_time >= 0.2:
			self.audio_mgr.play_voice(
				self.session.current_round.target_symbol,
				"question",
				self.session.current_round.prompt_mode
			)
			self.has_played_question = true

		var all_idle: bool = true
		for c: CardItem in self.cards:
			if c.state != "IDLE":
				all_idle = false
				break
		if all_idle and self.phase_time >= 0.6:
			self.phase = "WAITING_GUESS"
			self.phase_time = 0.0

	elif self.phase == "SOLVED_FEEDBACK":
		if not self.audio_mgr.is_voice_busy() and self.phase_time >= 0.9:
			for c: CardItem in self.cards:
				c.trigger_fly_out()
			self.phase = "FLYING_OUT"
			self.phase_time = 0.0

	elif self.phase == "FLYING_OUT":
		if self.phase_time >= 0.8:
			if self.session.advance_to_next_round():
				_setup_round()
			else:
				return "SCORE"

	return ""


func render(
	canvas: CanvasItem,
	fm: FontManager,
	mouse_pos: Vector2i,
	is_mouse_down: bool,
	enable_hover: bool
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if not FailFast.require_not_null(fm, "fm"):
		return

	canvas.draw_rect(Rect2(0.0, 0.0, float(self.screen_w), float(self.screen_h)), Color.WHITE, true)
	self.btn_menu.render(canvas, mouse_pos, is_mouse_down, 1.0)

	var active_idx: int = self.session.current_round_num - 1
	var pop_prog: float = minf(1.0, self.phase_time / 0.35) if self.phase == "SOLVED_FEEDBACK" else -1.0
	var rb_prog: float = minf(1.0, self.phase_time / 0.80) if self.phase == "SOLVED_FEEDBACK" else -1.0
	var empty_offsets: Array[int] = []
	var empty_scales: Array[float] = []
	var empty_rbs: Array[float] = []

	StarRenderer.draw_progress_stars(
		canvas,
		self.header_metrics.stars_center,
		self.session.round_results,
		10,
		self.header_metrics.star_radius,
		self.header_metrics.star_spacing,
		self.total_elapsed,
		active_idx,
		pop_prog,
		rb_prog,
		empty_offsets,
		empty_scales,
		empty_rbs
	)

	var round_font: Font = fm.get_round_font(self.session.current_round_num)
	var font_sz: int = self.card_metrics.font_size
	var cap_offset: float = fm.get_cap_baseline_offset(round_font, font_sz)

	# Draw normal cards first, hovered card second, and correct card on top
	for pass_idx: int in range(3):
		for card: CardItem in self.cards:
			var layer: int = 0
			if card.is_correct:
				layer = 2
			elif enable_hover and card.is_clicked(mouse_pos):
				layer = 1
			if layer == pass_idx:
				card.render(canvas, round_font, font_sz, cap_offset, mouse_pos, enable_hover)
