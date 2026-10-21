class_name CardItem
extends RefCounted

var symbol: String
var index: int
var target_rect: Rect2i
var screen_width: int
var entry_delay: float

var current_x: float
var current_y: float
var width: int
var height: int

var state: String = "FLYING_IN"
var is_wrong: bool = false
var is_correct: bool = false
var state_time: float = 0.0
var correct_anim_time: float = 0.0
var hover_progress: float = 0.0

var fly_in_duration: float = 0.5
var fly_out_duration: float = 0.5
var rainbow_duration: float = 0.8
var red_flash_duration: float = 0.4


func _init(
	p_symbol: String,
	p_index: int,
	p_target_rect: Rect2i,
	p_screen_width: int,
	p_entry_delay_step: float
) -> void:
	if not FailFast.require_non_empty_str(p_symbol, "p_symbol"):
		return
	if not FailFast.require_non_negative_int(p_index, "p_index"):
		return
	if p_target_rect.size.x <= 0 or p_target_rect.size.y <= 0:
		FailFast.fail("CRITICAL: p_target_rect dimensions must be positive.")
		return
	if not FailFast.require_positive_int(p_screen_width, "p_screen_width"):
		return
	if not FailFast.require_non_negative_float(p_entry_delay_step, "p_entry_delay_step"):
		return

	self.symbol = p_symbol
	self.index = p_index
	self.target_rect = p_target_rect
	self.screen_width = p_screen_width
	self.entry_delay = float(p_index) * p_entry_delay_step

	self.width = p_target_rect.size.x
	self.height = p_target_rect.size.y
	self.current_x = float(-self.width - 20)
	self.current_y = float(p_target_rect.position.y)


func update_layout_target(new_target: Rect2i, new_screen_width: int) -> void:
	if new_target.size.x <= 0 or new_target.size.y <= 0:
		FailFast.fail("CRITICAL: new_target dimensions must be positive.")
		return
	if not FailFast.require_positive_int(new_screen_width, "new_screen_width"):
		return
	self.target_rect = new_target
	self.screen_width = new_screen_width
	self.width = new_target.size.x
	self.height = new_target.size.y
	self.current_y = float(new_target.position.y)
	if self.state != "FLYING_IN" and self.state != "FLYING_OUT":
		self.current_x = float(new_target.position.x)


func update(dt: float) -> void:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return
	self.state_time += dt
	if self.is_correct:
		self.correct_anim_time += dt
		self.hover_progress = 0.0
	elif self.is_wrong:
		self.hover_progress = 0.0

	if self.state == "FLYING_IN":
		if self.state_time >= self.entry_delay:
			var progress: float = (self.state_time - self.entry_delay) / self.fly_in_duration
			if progress >= 1.0:
				self.current_x = float(self.target_rect.position.x)
				self.state = "IDLE"
				self.state_time = 0.0
			else:
				var t: float = RainbowMath.ease_out_cubic(progress)
				var start_x: float = float(-self.width - 20)
				self.current_x = start_x + (float(self.target_rect.position.x) - start_x) * t

	elif self.state == "FLYING_OUT":
		var delay: float = float(self.index) * 0.08
		if self.state_time >= delay:
			var progress: float = (self.state_time - delay) / self.fly_out_duration
			if progress >= 1.0:
				self.current_x = float(self.screen_width + self.width + 20)
			else:
				var t: float = RainbowMath.ease_out_cubic(progress)
				var end_x: float = float(self.screen_width + self.width + 20)
				self.current_x = float(self.target_rect.position.x) + (end_x - float(self.target_rect.position.x)) * t

	elif self.state == "RAINBOW_FLASH":
		if self.state_time >= self.rainbow_duration:
			self.state = "IDLE"
			self.state_time = 0.0

	elif self.state == "RED_FLASH":
		if self.state_time >= self.red_flash_duration:
			self.state = "IDLE"
			self.state_time = 0.0


func trigger_rainbow() -> void:
	self.is_correct = true
	self.state = "RAINBOW_FLASH"
	self.state_time = 0.0
	self.correct_anim_time = 0.0
	self.hover_progress = 0.0


func trigger_red_flash() -> void:
	self.is_wrong = true
	self.state = "RED_FLASH"
	self.state_time = 0.0
	self.hover_progress = 0.0


func trigger_fly_out() -> void:
	self.state = "FLYING_OUT"
	self.state_time = 0.0


func get_current_rect() -> Rect2i:
	return Rect2i(int(round(self.current_x)), int(round(self.current_y)), self.width, self.height)


func is_clicked(pos: Vector2i) -> bool:
	if self.is_wrong or (self.state != "IDLE" and self.state != "RED_FLASH"):
		return false
	var rect: Rect2i = get_current_rect()
	var raise_amount: int = clampi(self.height / 26, 5, 10)
	var hit_rect: Rect2i = Rect2i(
		rect.position.x,
		rect.position.y - raise_amount,
		rect.size.x,
		rect.size.y + raise_amount
	)
	return hit_rect.has_point(pos)


func render(
	canvas: CanvasItem,
	font: Font,
	base_font_size: int,
	cap_baseline_offset: float,
	mouse_pos: Vector2i,
	enable_hover: bool
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if not FailFast.require_not_null(font, "font"):
		return
	if not FailFast.require_positive_int(base_font_size, "base_font_size"):
		return

	var rect: Rect2i = get_current_rect()
	var raise_amount: int = clampi(self.height / 26, 5, 10)
	var hit_rect: Rect2i = Rect2i(
		rect.position.x,
		rect.position.y - raise_amount,
		rect.size.x,
		rect.size.y + raise_amount
	)
	var is_hovered: bool = enable_hover and hit_rect.has_point(mouse_pos)
	var can_hover: bool = (self.state == "IDLE" and not self.is_wrong and not self.is_correct)

	var target_hover: float = 1.0 if (is_hovered and can_hover) else 0.0
	self.hover_progress += (target_hover - self.hover_progress) * 0.35
	if absf(self.hover_progress - target_hover) < 0.01:
		self.hover_progress = target_hover

	var scale: float = 1.0 + 0.02 * self.hover_progress
	if self.is_correct:
		if self.state == "RAINBOW_FLASH":
			var t: float = minf(1.0, self.state_time / 0.15)
			var inv: float = 1.0 - t
			scale = 1.0 + 0.10 * (1.0 - inv * inv * inv)
		elif self.state == "IDLE":
			scale = 1.06 + 0.02 * sin(self.correct_anim_time * 4.0)
		elif self.state == "FLYING_OUT":
			scale = 1.10

	var shake_x: int = 0
	if self.state == "RED_FLASH":
		shake_x = RainbowMath.compute_shake_offset(self.state_time, self.red_flash_duration)
	var elev_y: int = -int(round(float(raise_amount) * self.hover_progress))
	var moved_pos: Vector2 = Vector2(float(rect.position.x + shake_x), float(rect.position.y + elev_y))

	var extra_w: float = float(rect.size.x) * (scale - 1.0)
	var extra_h: float = float(rect.size.y) * (scale - 1.0)
	var draw_rect: Rect2 = Rect2(
		moved_pos.x - extra_w * 0.5,
		moved_pos.y - extra_h * 0.5,
		float(rect.size.x) + extra_w,
		float(rect.size.y) + extra_h
	)

	var radius: int = mini(28, int(draw_rect.size.x) / 6)
	var shadow_off_y: float = 6.0 if self.is_correct else (4.0 + float(raise_amount + 1) * self.hover_progress)

	var scaled_font_size: int = maxi(16, int(round(float(base_font_size) * scale)))
	var str_sz: Vector2 = font.get_string_size(self.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size)
	var center: Vector2 = draw_rect.get_center()
	var text_pos: Vector2 = Vector2(
		center.x - str_sz.x * 0.5,
		center.y + cap_baseline_offset * scale
	)

	if self.state == "RAINBOW_FLASH" or self.is_correct:
		_render_rainbow_card(canvas, draw_rect, radius, shadow_off_y, font, scaled_font_size, text_pos)
		return

	var bg_col: Color
	var border_col: Color
	var border_w: int
	var text_col: Color = Color8(34, 34, 34)

	if self.is_wrong and self.state != "RED_FLASH":
		bg_col = Color8(235, 235, 238)
		border_col = Color8(205, 205, 212)
		border_w = 3
		text_col = Color8(170, 170, 175)
	elif is_hovered and can_hover:
		bg_col = Color8(255, 252, 220)
		border_col = Color8(220, 210, 160)
		border_w = 4
	elif self.state == "RED_FLASH":
		var factor: float = clampf(1.0 - (self.state_time / self.red_flash_duration), 0.0, 1.0)
		bg_col = Color8(235, 235, 238).lerp(Color8(255, 77, 77), factor)
		border_col = Color8(205, 205, 212).lerp(Color8(255, 77, 77), factor)
		text_col = Color8(170, 170, 175).lerp(Color8(34, 34, 34), factor)
		border_w = 4
	else:
		bg_col = Color.WHITE
		border_col = Color8(200, 200, 210)
		border_w = 4

	UIWidgets.draw_rounded_box(canvas, draw_rect, radius, bg_col, border_col, border_w, shadow_off_y)
	canvas.draw_string(font, text_pos, self.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size, text_col)


func _render_rainbow_card(
	canvas: CanvasItem,
	draw_rect: Rect2,
	radius: int,
	shadow_off_y: float,
	font: Font,
	font_size: int,
	text_pos: Vector2
) -> void:
	var flash_dur: float = self.rainbow_duration
	var t_anim: float = self.correct_anim_time
	var tone: float = 0.0
	var phase_offset: float = 0.0
	if t_anim <= flash_dur:
		tone = 0.0
		phase_offset = (t_anim / flash_dur) * 12.0
	else:
		var extra_t: float = t_anim - flash_dur
		tone = minf(1.0, extra_t / 0.25)
		phase_offset = 12.0 + extra_t * 4.0

	var sat: float = 0.90 - (0.90 - 0.58) * tone
	var val: float = 0.95 - (0.95 - 0.86) * tone
	var bg_opacity: float = 0.12 - (0.12 - 0.07) * tone
	var border_w: int = int(round(7.0 - (7.0 - 5.0) * tone))

	var primary_rb: Color = RainbowMath.sample_rainbow_band_color(2.0 - phase_offset, sat, val, 0.35)
	var secondary_rb: Color = RainbowMath.sample_rainbow_band_color(4.5 - phase_offset, sat, val, 0.35)
	var base_bg: Color = Color.WHITE.lerp(primary_rb, bg_opacity * 0.5)

	# 1. Base card box with drop shadow and border
	UIWidgets.draw_rounded_box(canvas, draw_rect, radius, base_bg, primary_rb, border_w, shadow_off_y)

	# 2. Diagonal rainbow stripes flying across the card
	var band_span_px: float = maxf(1.0, draw_rect.size.y * 0.30)
	var step_px: float = 6.0
	var total_span: float = draw_rect.size.x + draw_rect.size.y
	var u: float = 0.0
	while u <= total_span:
		var band_pos: float = (u / band_span_px) - phase_offset
		var stripe_col: Color = RainbowMath.sample_rainbow_band_color(band_pos, sat, val, 0.35)
		stripe_col.a = bg_opacity * 1.5

		# Diagonal slice endpoints clipped to card rect
		var p1: Vector2 = Vector2(draw_rect.position.x + u, draw_rect.position.y)
		var p2: Vector2 = Vector2(draw_rect.position.x, draw_rect.position.y + u)
		if p1.x > draw_rect.end.x:
			p1 = Vector2(draw_rect.end.x, draw_rect.position.y + (p1.x - draw_rect.end.x))
		if p2.y > draw_rect.end.y:
			p2 = Vector2(draw_rect.position.x + (p2.y - draw_rect.end.y), draw_rect.end.y)

		if p1.x >= draw_rect.position.x and p1.y <= draw_rect.end.y and p2.x <= draw_rect.end.x and p2.y >= draw_rect.position.y:
			canvas.draw_line(p1, p2, stripe_col, step_px)
		u += step_px

	# 3. Outer border re-applied crisply on top of diagonal stripes
	var border_box: StyleBoxFlat = StyleBoxFlat.new()
	border_box.draw_center = false
	border_box.border_color = primary_rb
	border_box.set_corner_radius_all(radius)
	border_box.set_border_width_all(border_w)
	border_box.anti_aliasing = true
	canvas.draw_style_box(border_box, draw_rect)

	# 4. Animated rainbow text
	canvas.draw_string(font, text_pos, self.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, secondary_rb)
