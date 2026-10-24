class_name ProfileBar
extends RefCounted

const PROFILE_COUNT: int = 6
const PENCIL_SVG: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="64" height="64" fill="none" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
	+ '<g transform="translate(12, 12) rotate(-22) scale(0.85) translate(-12, -12)">'
	+ '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"/>'
	+ '<path d="m15 5 4 4"/>'
	+ '</g>'
	+ '</svg>'
)

static var _pencil_tex_cache: Dictionary = {}

var screen_w: int = 1920
var screen_h: int = 1080
var active_index: int = 0
var profile_names: Array[String] = []
var button_rects: Array[Rect2i] = []
var pencil_rect: Rect2i = Rect2i()
var font_size: int = 15
var scroll_x: float = 0.0
var max_scroll_x: float = 0.0
var bar_rect: Rect2i = Rect2i()
var drag_accum: Vector2 = Vector2.ZERO
var is_dragging: bool = false


static func get_pencil_texture(size: int) -> Texture2D:
	if not FailFast.require_positive_int(size, "size"):
		return null
	var key: String = "pencil_%d" % size
	if _pencil_tex_cache.has(key):
		var cached: Variant = _pencil_tex_cache[key]
		if cached is Texture2D:
			return cached
	var target_px: int = maxi(16, size * 2)
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_string(PENCIL_SVG, 2.0)
	if err != OK:
		FailFast.fail("CRITICAL: Failed to rasterize pencil SVG.")
		return null
	img.resize(target_px, target_px, Image.INTERPOLATE_LANCZOS)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_pencil_tex_cache[key] = tex
	return tex


func _init(
	p_screen_w: int,
	p_screen_h: int,
	p_back_btn_rect: Rect2i,
	p_config: ConfigManager.GameConfigData
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w"):
		return
	if not FailFast.require_positive_int(p_screen_h, "p_screen_h"):
		return
	if not FailFast.require_not_null(p_config, "p_config"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.active_index = clampi(p_config.active_profile_index, 0, PROFILE_COUNT - 1)
	self.profile_names.clear()
	for p: ConfigManager.UserProfile in p_config.profiles:
		self.profile_names.append(p.name)
	var prefix: String = "Profil %d" if ConfigManager.is_system_french() else "Profile %d"
	while self.profile_names.size() < PROFILE_COUNT:
		self.profile_names.append(prefix % (self.profile_names.size() + 1))

	rebuild_layout(p_back_btn_rect)


func rebuild_layout(p_back_btn_rect: Rect2i) -> void:
	self.button_rects.clear()
	var is_desktop_large: bool = (self.screen_w >= 1600 and self.screen_h >= 900)
	var max_w: int = 250 if is_desktop_large else 160
	var min_w: int = 140 if is_desktop_large else 130

	var side_clearance: int = p_back_btn_rect.end.x + 20
	var available_span: int = maxi(200, self.screen_w - side_clearance - 16)

	var gap: int = clampi(int(round(float(self.screen_w) * 0.008)), 8, 16) if is_desktop_large else clampi(int(round(float(self.screen_w) * 0.006)), 6, 12)
	var total_gap: int = gap * (PROFILE_COUNT - 1)
	var target_btn_w: int = (available_span - total_gap) / PROFILE_COUNT
	var btn_w: int = clampi(target_btn_w, min_w, max_w)
	var total_w: int = PROFILE_COUNT * btn_w + total_gap

	var btn_h: int = clampi(int(round(float(p_back_btn_rect.size.y) * 0.95)), 72, 88) if is_desktop_large else clampi(p_back_btn_rect.size.y - 6, 36, 50)
	var top_y: int = p_back_btn_rect.position.y + (p_back_btn_rect.size.y - btn_h) / 2
	self.font_size = clampi(int(round(float(btn_h) * 0.36)), 24, 30) if is_desktop_large else clampi(int(round(float(btn_h) * 0.38)), 11, 17)

	var start_x: int
	if total_w <= available_span:
		self.max_scroll_x = 0.0
		start_x = side_clearance + (available_span - total_w) / 2
	else:
		self.max_scroll_x = float(total_w - available_span)
		start_x = side_clearance
	self.scroll_x = clampf(self.scroll_x, 0.0, self.max_scroll_x)
	self.bar_rect = Rect2i(side_clearance, top_y - 4, available_span, btn_h + 8)

	for i: int in range(PROFILE_COUNT):
		var r: Rect2i = Rect2i(start_x + i * (btn_w + gap), top_y, btn_w, btn_h)
		self.button_rects.append(r)

	_update_pencil_rect()


func on_drag(relative: Vector2) -> bool:
	self.drag_accum += relative
	if self.drag_accum.length() > 8.0:
		self.is_dragging = true
		self.scroll_x = clampf(self.scroll_x - relative.x, 0.0, self.max_scroll_x)
		return true
	return false


func on_drag_end() -> bool:
	var was: bool = self.is_dragging
	self.drag_accum = Vector2.ZERO
	self.is_dragging = false
	return was


func on_wheel(direction: int) -> void:
	self.scroll_x = clampf(self.scroll_x + float(direction * 40), 0.0, self.max_scroll_x)


func _update_pencil_rect() -> void:
	if self.active_index < 0 or self.active_index >= self.button_rects.size():
		self.pencil_rect = Rect2i()
		return
	var active_rect: Rect2i = self.button_rects[self.active_index]
	var pencil_sz: int = clampi(int(round(float(active_rect.size.y) * 0.44)), 16, 32)
	var pad_right: int = clampi(int(round(float(active_rect.size.y) * 0.16)), 8, 16)
	self.pencil_rect = Rect2i(
		active_rect.end.x - pencil_sz - pad_right,
		active_rect.position.y + (active_rect.size.y - pencil_sz) / 2,
		pencil_sz,
		pencil_sz
	)


func set_active_index(idx: int) -> void:
	if not FailFast.require_non_negative_int(idx, "idx"):
		return
	self.active_index = clampi(idx, 0, PROFILE_COUNT - 1)
	_update_pencil_rect()


func update_profiles(p_config: ConfigManager.GameConfigData) -> void:
	if not FailFast.require_not_null(p_config, "p_config"):
		return
	self.active_index = clampi(p_config.active_profile_index, 0, PROFILE_COUNT - 1)
	self.profile_names.clear()
	for p: ConfigManager.UserProfile in p_config.profiles:
		self.profile_names.append(p.name)
	var prefix: String = "Profil %d" if ConfigManager.is_system_french() else "Profile %d"
	while self.profile_names.size() < PROFILE_COUNT:
		self.profile_names.append(prefix % (self.profile_names.size() + 1))
	_update_pencil_rect()


func update_profile_name(idx: int, new_name: String) -> void:
	if idx >= 0 and idx < self.profile_names.size() and not new_name.strip_edges().is_empty():
		self.profile_names[idx] = new_name.strip_edges()


func handle_click(pos: Vector2i) -> Dictionary:
	if not self.bar_rect.has_point(pos):
		return {"action": "NONE"}
	var shifted_pos: Vector2i = Vector2i(int(round(float(pos.x) + self.scroll_x)), pos.y)
	if self.pencil_rect.size.x > 0 and self.pencil_rect.has_point(shifted_pos):
		return {"action": "RENAME", "index": self.active_index}

	for i: int in range(self.button_rects.size()):
		if self.button_rects[i].has_point(shifted_pos):
			return {"action": "SELECT", "index": i}

	return {"action": "NONE"}


func render(
	canvas: CanvasItem,
	font: Font,
	mouse_pos: Vector2i,
	is_mouse_down: bool
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if not FailFast.require_not_null(font, "font"):
		return

	var sx: int = int(round(self.scroll_x))
	for i: int in range(self.button_rects.size()):
		var base_rect: Rect2i = self.button_rects[i]
		var rect: Rect2i = Rect2i(base_rect.position.x - sx, base_rect.position.y, base_rect.size.x, base_rect.size.y)
		if rect.end.x < self.bar_rect.position.x or rect.position.x > self.bar_rect.end.x:
			continue

		var is_active: bool = (i == self.active_index)
		var is_hover: bool = rect.has_point(mouse_pos)
		var is_pressed: bool = is_hover and is_mouse_down

		var bg: Color
		var border: Color
		var text_col: Color

		if is_active:
			bg = Color8(20, 20, 25)
			border = Color8(20, 20, 25)
			text_col = Color.WHITE
		else:
			bg = Color8(240, 240, 245) if is_hover else Color.WHITE
			border = Color8(140, 140, 150)
			text_col = Color8(20, 20, 25)

		var draw_r: Rect2 = UIWidgets.compute_button_rect(rect, 1.02 if is_hover else 1.0, is_pressed)
		UIWidgets.draw_rounded_box(canvas, draw_r, 8, bg, border, 2, 2.0 if is_pressed else 3.0)

		var name_str: String = self.profile_names[i] if i < self.profile_names.size() else "Profile"
		var max_text_w: float = float(rect.size.x) - (float(self.pencil_rect.size.x) + 16.0 if is_active else 12.0)
		var str_sz: Vector2 = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, self.font_size)

		var display_str: String = name_str
		if str_sz.x > max_text_w and name_str.length() > 4:
			display_str = name_str.substr(0, 5) + "…"
			str_sz = font.get_string_size(display_str, HORIZONTAL_ALIGNMENT_LEFT, -1, self.font_size)

		var ascent: float = font.get_ascent(self.font_size)
		var baseline_y: float = float(draw_r.position.y) + float(draw_r.size.y) * 0.5 + ascent * 0.35
		var tx: float = float(draw_r.position.x) + (float(draw_r.size.x) - str_sz.x) * 0.5
		canvas.draw_string(font, Vector2(tx, baseline_y), display_str, HORIZONTAL_ALIGNMENT_LEFT, -1, self.font_size, text_col)

		if is_active and self.pencil_rect.size.x > 0:
			var p_rect: Rect2i = Rect2i(self.pencil_rect.position.x - sx, self.pencil_rect.position.y, self.pencil_rect.size.x, self.pencil_rect.size.y)
			var p_hover: bool = p_rect.has_point(mouse_pos)
			var p_pressed: bool = p_hover and is_mouse_down

			var pen_scale: float = 1.0
			var pen_col: Color = Color8(230, 230, 240)
			if p_pressed:
				pen_scale = 1.05
				pen_col = Color8(255, 185, 45)
			elif p_hover:
				pen_scale = 1.18
				pen_col = Color8(255, 218, 65)

			var base_sz: float = float(p_rect.size.x)
			var icon_sz: float = base_sz * pen_scale
			var tex: Texture2D = get_pencil_texture(int(round(icon_sz)))
			if tex != null:
				var ic_x: float = float(p_rect.position.x) + (float(p_rect.size.x) - icon_sz) * 0.5
				var ic_y: float = float(p_rect.position.y) + (float(p_rect.size.y) - icon_sz) * 0.5
				canvas.draw_texture_rect(tex, Rect2(ic_x, ic_y, icon_sz, icon_sz), false, pen_col)
