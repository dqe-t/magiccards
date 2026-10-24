class_name UIWidgets
extends RefCounted

const BUILTIN_SVGS: Dictionary = {
	"PLAY": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="128" height="128">'
		+ '<path d="M7.5 4.8C7.5 3.8 8.6 3.2 9.5 3.8L20.2 11.0C21.0 11.5 21.0 12.5 20.2 13.0L9.5 20.2C8.6 20.8 7.5 20.2 7.5 19.2Z" '
		+ 'fill="#ffffff" stroke="#ffffff" stroke-width="1.5" stroke-linejoin="round"/>'
		+ '</svg>'
	),
	"ARROW_LEFT": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="128" height="128">'
		+ '<path d="M19 12H5M12 19L5 12L12 5" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
		+ '</svg>'
	),
	"EXIT": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="128" height="128">'
		+ '<path d="M18 6L6 18M6 6L18 18" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
		+ '</svg>'
	),
	"CHECK": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="128" height="128">'
		+ '<path d="M20 6L9 17L4 12" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
		+ '</svg>'
	),
	"GEAR": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="128" height="128" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
		+ '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/>'
		+ '<circle cx="12" cy="12" r="3"/>'
		+ '</svg>'
	),
}

static var _icon_cache: Dictionary = {}


static func get_icon_texture(icon_type: String, size: int) -> Texture2D:
	if not FailFast.require_non_empty_str(icon_type, "icon_type"):
		return null
	if not FailFast.require_positive_int(size, "size"):
		return null

	var key: String = "%s_%d" % [icon_type, size]
	if _icon_cache.has(key):
		var cached: Variant = _icon_cache[key]
		if cached is Texture2D:
			return cached

	var svg_content: String = ""
	if BUILTIN_SVGS.has(icon_type):
		svg_content = str(BUILTIN_SVGS[icon_type])
	else:
		FailFast.fail("CRITICAL: Unknown icon_type '%s'." % icon_type)
		return null

	var img: Image = Image.new()
	var scale_factor: float = float(size) / 128.0
	var err: Error = img.load_svg_from_string(svg_content, scale_factor)
	if err != OK:
		FailFast.fail("CRITICAL: Failed to rasterize SVG icon '%s'." % icon_type)
		return null

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


static func draw_rounded_box(
	canvas: CanvasItem,
	rect: Rect2,
	radius: int,
	bg_color: Color,
	border_color: Color,
	border_width: int,
	shadow_offset_y: float
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		FailFast.fail("CRITICAL: Rect dimensions must be positive.")
		return

	if shadow_offset_y > 0.0:
		var sh_box: StyleBoxFlat = StyleBoxFlat.new()
		sh_box.bg_color = Color(0.0, 0.0, 0.0, 0.12)
		sh_box.set_corner_radius_all(radius + 2)
		sh_box.shadow_color = Color(0.0, 0.0, 0.0, 0.14)
		sh_box.shadow_size = 6
		sh_box.shadow_offset = Vector2(0.0, shadow_offset_y)
		canvas.draw_style_box(sh_box, rect)

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg_color
	box.set_corner_radius_all(radius)
	if border_width > 0:
		box.border_color = border_color
		box.set_border_width_all(border_width)
	box.anti_aliasing = true
	box.anti_aliasing_size = 1.25
	canvas.draw_style_box(box, rect)


static func compute_button_rect(rect: Rect2i, hover_scale: float, is_pressed: bool) -> Rect2:
	if rect.size.x <= 0 or rect.size.y <= 0:
		FailFast.fail("CRITICAL: Button rect dimensions must be positive.")
		return Rect2()
	if not FailFast.require_positive_float(hover_scale, "hover_scale"):
		return Rect2()

	var extra_w: float = float(rect.size.x) * (hover_scale - 1.0)
	var extra_h: float = float(rect.size.y) * (hover_scale - 1.0)
	var out: Rect2 = Rect2(
		float(rect.position.x) - extra_w * 0.5,
		float(rect.position.y) - extra_h * 0.5,
		float(rect.size.x) + extra_w,
		float(rect.size.y) + extra_h
	)
	if is_pressed:
		out.position.y += 2.0
	return out


class UIIconButton extends RefCounted:
	var rect: Rect2i
	var icon_type: String
	var bg_color: Color
	var hover_color: Color
	var icon_color: Color
	var border_radius: int
	var border_color: Color
	var border_width: int
	var hover_scale: float = 1.0

	func _init(
		p_rect: Rect2i,
		p_icon_type: String,
		p_bg_color: Color,
		p_hover_color: Color,
		p_icon_color: Color,
		p_border_radius: int,
		p_border_color: Color,
		p_border_width: int
	) -> void:
		self.rect = p_rect
		self.icon_type = p_icon_type
		self.bg_color = p_bg_color
		self.hover_color = p_hover_color
		self.icon_color = p_icon_color
		self.border_radius = p_border_radius
		self.border_color = p_border_color
		self.border_width = p_border_width

	func is_hovered(pos: Vector2i) -> bool:
		return self.rect.has_point(pos)

	func is_clicked(pos: Vector2i) -> bool:
		return self.rect.has_point(pos)

	func render(
		canvas: CanvasItem,
		mouse_pos: Vector2i,
		is_mouse_down: bool,
		alpha: float
	) -> void:
		if not FailFast.require_not_null(canvas, "canvas"):
			return
		var hover: bool = is_hovered(mouse_pos)
		var target_scale: float = 1.05 if hover else 1.0
		self.hover_scale += (target_scale - self.hover_scale) * 0.35
		if absf(self.hover_scale - target_scale) < 0.002:
			self.hover_scale = target_scale

		var pressed: bool = hover and is_mouse_down
		var draw_rect: Rect2 = UIWidgets.compute_button_rect(self.rect, self.hover_scale, pressed)
		var col: Color = self.hover_color if hover else self.bg_color
		col.a = alpha
		var b_col: Color = self.border_color
		b_col.a = alpha

		UIWidgets.draw_rounded_box(
			canvas,
			draw_rect,
			self.border_radius,
			col,
			b_col,
			self.border_width,
			2.0 if pressed else 3.0
		)

		var base_sz: int = mini(int(draw_rect.size.x), int(draw_rect.size.y)) / 2
		var icon_sz: int = maxi(16, int(round(float(base_sz) * 1.3)))
		var tex: Texture2D = UIWidgets.get_icon_texture(self.icon_type, icon_sz)
		if tex != null:
			var center: Vector2 = draw_rect.get_center()
			# Optical offset for play triangle to achieve visual center of mass
			var ox: float = -float(icon_sz) * 0.045 if self.icon_type == "PLAY" else 0.0
			var icon_rect: Rect2 = Rect2(
				center.x - float(icon_sz) * 0.5 + ox,
				center.y - float(icon_sz) * 0.5,
				float(icon_sz),
				float(icon_sz)
			)
			var ic: Color = self.icon_color
			ic.a = alpha
			canvas.draw_texture_rect(tex, icon_rect, false, ic)


class UICheckbox extends RefCounted:
	var rect: Rect2i
	var label: String
	var checked: bool

	func _init(p_rect: Rect2i, p_label: String, p_checked: bool) -> void:
		self.rect = p_rect
		self.label = p_label
		self.checked = p_checked

	func toggle() -> bool:
		self.checked = not self.checked
		return self.checked

	func is_clicked(pos: Vector2i) -> bool:
		return self.rect.has_point(pos)

	func render(
		canvas: CanvasItem,
		font: Font,
		font_size: int,
		mouse_pos: Vector2i
	) -> void:
		if not FailFast.require_not_null(canvas, "canvas"):
			return
		if not FailFast.require_not_null(font, "font"):
			return
		if not FailFast.require_positive_int(font_size, "font_size"):
			return

		var radius: int = maxi(6, mini(14, self.rect.size.y / 4))
		var offset_y: float = 2.0 if self.rect.size.x < 60 else 3.0
		var hover: bool = self.rect.has_point(mouse_pos)

		var bg: Color
		var border: Color
		var text_col: Color
		if self.checked:
			bg = Color8(20, 20, 25)
			border = Color8(20, 20, 25)
			text_col = Color.WHITE
		else:
			bg = Color8(240, 240, 245) if hover else Color.WHITE
			border = Color8(140, 140, 150)
			text_col = Color8(20, 20, 25)

		UIWidgets.draw_rounded_box(
			canvas,
			Rect2(self.rect),
			radius,
			bg,
			border,
			2,
			offset_y
		)

		var str_sz: Vector2 = font.get_string_size(self.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var ascent: float = font.get_ascent(font_size)
		var baseline_y: float = float(self.rect.position.y) + float(self.rect.size.y) * 0.5 + ascent * 0.35

		if self.checked and self.rect.size.x >= 100:
			var icon_sz: int = maxi(14, int(round(float(self.rect.size.y) * 0.42)))
			var spacing: float = 8.0
			var total_w: float = float(icon_sz) + spacing + str_sz.x
			var start_x: float = float(self.rect.position.x) + (float(self.rect.size.x) - total_w) * 0.5
			var check_tex: Texture2D = UIWidgets.get_icon_texture("CHECK", icon_sz)
			if check_tex != null:
				var cy: float = float(self.rect.position.y) + (float(self.rect.size.y) - float(icon_sz)) * 0.5
				canvas.draw_texture_rect(
					check_tex,
					Rect2(start_x, cy, float(icon_sz), float(icon_sz)),
					false,
					text_col
				)
			canvas.draw_string(
				font,
				Vector2(start_x + float(icon_sz) + spacing, baseline_y),
				self.label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				text_col
			)
		else:
			var tx: float = float(self.rect.position.x) + (float(self.rect.size.x) - str_sz.x) * 0.5
			canvas.draw_string(
				font,
				Vector2(tx, baseline_y),
				self.label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				text_col
			)


class UISegmentedToggle extends RefCounted:
	var rect: Rect2i
	var label_left: String
	var label_right: String
	var checked_left: bool
	var checked_right: bool

	func _init(
		p_rect: Rect2i,
		p_label_left: String,
		p_label_right: String,
		p_checked_left: bool,
		p_checked_right: bool
	) -> void:
		self.rect = p_rect
		self.label_left = p_label_left
		self.label_right = p_label_right
		self.checked_left = p_checked_left
		self.checked_right = p_checked_right

	func get_left_rect() -> Rect2i:
		return Rect2i(self.rect.position.x, self.rect.position.y, self.rect.size.x / 2, self.rect.size.y)

	func get_right_rect() -> Rect2i:
		var half_w: int = self.rect.size.x / 2
		return Rect2i(self.rect.position.x + half_w, self.rect.position.y, self.rect.size.x - half_w, self.rect.size.y)

	func is_left_clicked(pos: Vector2i) -> bool:
		return get_left_rect().has_point(pos)

	func is_right_clicked(pos: Vector2i) -> bool:
		return get_right_rect().has_point(pos)

	func render(canvas: CanvasItem, font: Font, font_size: int, mouse_pos: Vector2i) -> void:
		if not FailFast.require_not_null(canvas, "canvas") or not FailFast.require_not_null(font, "font") or not FailFast.require_positive_int(font_size, "font_size"):
			return
		var radius: int = maxi(6, mini(14, self.rect.size.y / 4))
		UIWidgets.draw_rounded_box(canvas, Rect2(self.rect), radius, Color.WHITE, Color8(140, 140, 150), 2, 3.0)

		var l_rect: Rect2i = get_left_rect()
		var r_rect: Rect2i = get_right_rect()
		_render_half(canvas, font, font_size, l_rect, self.label_left, self.checked_left, l_rect.has_point(mouse_pos), true, radius)
		_render_half(canvas, font, font_size, r_rect, self.label_right, self.checked_right, r_rect.has_point(mouse_pos), false, radius)

		var mid_x: float = float(l_rect.position.x + l_rect.size.x)
		canvas.draw_line(Vector2(mid_x, float(self.rect.position.y) + 4.0), Vector2(mid_x, float(self.rect.position.y + self.rect.size.y) - 4.0), Color8(160, 160, 170), 1.5)

	func _render_half(canvas: CanvasItem, font: Font, font_size: int, h_rect: Rect2i, text: String, checked: bool, hover: bool, is_left: bool, radius: int) -> void:
		if checked:
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = Color8(20, 20, 25)
			if is_left:
				box.corner_radius_top_left = radius
				box.corner_radius_bottom_left = radius
			else:
				box.corner_radius_top_right = radius
				box.corner_radius_bottom_right = radius
			box.anti_aliasing = true
			canvas.draw_style_box(box, Rect2(h_rect))
		elif hover:
			var h_box: StyleBoxFlat = StyleBoxFlat.new()
			h_box.bg_color = Color8(240, 240, 245)
			if is_left:
				h_box.corner_radius_top_left = radius
				h_box.corner_radius_bottom_left = radius
			else:
				h_box.corner_radius_top_right = radius
				h_box.corner_radius_bottom_right = radius
			canvas.draw_style_box(h_box, Rect2(h_rect))

		var text_col: Color = Color.WHITE if checked else Color8(20, 20, 25)
		var str_sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline_y: float = float(h_rect.position.y) + float(h_rect.size.y) * 0.5 + font.get_ascent(font_size) * 0.35

		if checked:
			var icon_sz: int = maxi(14, int(round(float(h_rect.size.y) * 0.38)))
			var spacing: float = 6.0
			var total_w: float = float(icon_sz) + spacing + str_sz.x
			var sx: float = float(h_rect.position.x) + (float(h_rect.size.x) - total_w) * 0.5
			var check_tex: Texture2D = UIWidgets.get_icon_texture("CHECK", icon_sz)
			if check_tex != null:
				var cy: float = float(h_rect.position.y) + (float(h_rect.size.y) - float(icon_sz)) * 0.5
				canvas.draw_texture_rect(check_tex, Rect2(sx, cy, float(icon_sz), float(icon_sz)), false, text_col)
			canvas.draw_string(font, Vector2(sx + float(icon_sz) + spacing, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
		else:
			var tx: float = float(h_rect.position.x) + (float(h_rect.size.x) - str_sz.x) * 0.5
			canvas.draw_string(font, Vector2(tx, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

