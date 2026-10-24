class_name ConfigScrollController
extends RefCounted

var scroll_y: float = 0.0
var max_scroll_y: float = 0.0
var drag_accum: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var chevron_anim_time: float = 0.0
var chevron_rect: Rect2i = Rect2i()
const DRAG_THRESHOLD: float = 8.0


func _init() -> void:
	reset()


func reset() -> void:
	self.scroll_y = 0.0
	self.max_scroll_y = 0.0
	self.drag_accum = Vector2.ZERO
	self.is_dragging = false


func update_content_bounds(content_bottom: int, screen_h: int) -> void:
	if screen_h <= 0:
		FailFast.fail("CRITICAL: screen_h must be positive in ConfigScrollController.")
		return
	self.max_scroll_y = maxf(0.0, float(content_bottom - screen_h + 30))
	self.scroll_y = clampf(self.scroll_y, 0.0, self.max_scroll_y)


func on_drag_start() -> void:
	self.drag_accum = Vector2.ZERO
	self.is_dragging = false


func on_drag(relative: Vector2) -> bool:
	self.drag_accum += relative
	if self.drag_accum.length() > DRAG_THRESHOLD:
		self.is_dragging = true
		self.scroll_y = clampf(self.scroll_y - relative.y, 0.0, self.max_scroll_y)
		return true
	return false


func on_drag_end() -> bool:
	var was_dragging: bool = self.is_dragging
	self.drag_accum = Vector2.ZERO
	self.is_dragging = false
	return was_dragging


func on_wheel(direction: int) -> void:
	self.scroll_y = clampf(self.scroll_y + float(direction * 50), 0.0, self.max_scroll_y)


func screen_to_content(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x, int(round(float(pos.y) + self.scroll_y)))


func update(dt: float, screen_w: int, screen_h: int) -> void:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return
	if not FailFast.require_positive_int(screen_w, "screen_w") or not FailFast.require_positive_int(screen_h, "screen_h"):
		return
	self.chevron_anim_time += dt
	if self.max_scroll_y > 0.0 and (self.max_scroll_y - self.scroll_y) > 8.0:
		var bounce_y: float = sin(self.chevron_anim_time * 4.5) * 3.5
		var pill_w: int = 54
		var pill_h: int = 30
		var pill_x: int = (screen_w - pill_w) / 2
		var pill_y: int = int(round(float(screen_h) - float(pill_h) - 10.0 + bounce_y))
		self.chevron_rect = Rect2i(pill_x, pill_y, pill_w, pill_h)
	else:
		self.chevron_rect = Rect2i()


func handle_indicator_click(pos: Vector2i) -> bool:
	if self.max_scroll_y > 0.0 and self.chevron_rect.size.x > 0 and self.chevron_rect.has_point(pos):
		self.scroll_y = minf(self.max_scroll_y, self.scroll_y + 140.0)
		return true
	return false


func render_indicator(canvas: CanvasItem, screen_w: int, screen_h: int, mouse_pos: Vector2i) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if not FailFast.require_positive_int(screen_w, "screen_w") or not FailFast.require_positive_int(screen_h, "screen_h"):
		return
	if self.chevron_rect.size.x <= 0:
		return

	var remaining_scroll: float = self.max_scroll_y - self.scroll_y
	var fade_alpha: float = clampf(remaining_scroll / 24.0, 0.0, 1.0)
	var grad_h: float = 46.0
	var top_y: float = float(screen_h) - grad_h
	var poly_pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, top_y),
		Vector2(float(screen_w), top_y),
		Vector2(float(screen_w), float(screen_h)),
		Vector2(0.0, float(screen_h))
	])
	var poly_cols: PackedColorArray = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.95 * fade_alpha),
		Color(1.0, 1.0, 1.0, 0.95 * fade_alpha)
	])
	canvas.draw_polygon(poly_pts, poly_cols)

	var pill_r: Rect2 = Rect2(self.chevron_rect)
	var is_chev_hover: bool = self.chevron_rect.has_point(mouse_pos)
	var bg_col: Color = Color(1.0, 1.0, 1.0, 0.95 * fade_alpha)
	var border_col: Color = Color8(170, 170, 180, int(round(255.0 * fade_alpha)))
	UIWidgets.draw_rounded_box(canvas, pill_r, 14, bg_col, border_col, 1.5, 2.0 if is_chev_hover else 3.0)

	var chev_cx: float = float(self.chevron_rect.position.x) + float(self.chevron_rect.size.x) * 0.5
	var chev_cy: float = float(self.chevron_rect.position.y) + float(self.chevron_rect.size.y) * 0.5 - 1.0
	var chev_col: Color = Color8(40, 40, 50, int(round(255.0 * fade_alpha)))
	canvas.draw_line(Vector2(chev_cx - 7.0, chev_cy - 3.0), Vector2(chev_cx, chev_cy + 3.5), chev_col, 2.2, true)
	canvas.draw_line(Vector2(chev_cx, chev_cy + 3.5), Vector2(chev_cx + 7.0, chev_cy - 3.0), chev_col, 2.2, true)
