class_name StarRenderer
extends RefCounted

const BUILTIN_STAR_SVGS: Dictionary = {
	"FILLED": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="200" height="200">'
		+ '<defs>'
		+ '<linearGradient id="goldGrad" x1="0%" y1="0%" x2="0%" y2="100%">'
		+ '<stop offset="0%" stop-color="#FFF275" />'
		+ '<stop offset="35%" stop-color="#FFCE00" />'
		+ '<stop offset="100%" stop-color="#FF8A00" />'
		+ '</linearGradient>'
		+ '<linearGradient id="highlightGrad" x1="0%" y1="0%" x2="0%" y2="100%">'
		+ '<stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.75" />'
		+ '<stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.0" />'
		+ '</linearGradient>'
		+ '</defs>'
		+ '<polygon points="50,6 63,34 94,39 71,62 77,93 50,78 23,93 29,62 6,39 37,34" '
		+ 'fill="url(#goldGrad)" stroke="#D87800" stroke-width="5" '
		+ 'stroke-linejoin="round" stroke-linecap="round"/>'
		+ '<polygon points="50,11 61,35 88,39 68,59 50,48 32,59 12,39 39,35" '
		+ 'fill="url(#highlightGrad)"/>'
		+ '</svg>'
	),
	"WRONG": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="200" height="200">'
		+ '<polygon points="50,6 63,34 94,39 71,62 77,93 50,78 23,93 29,62 6,39 37,34" '
		+ 'fill="#EAEAEA" stroke="#2D3142" stroke-width="5.5" '
		+ 'stroke-linejoin="round" stroke-linecap="round"/>'
		+ '</svg>'
	),
	"UNPLAYED": (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="200" height="200">'
		+ '<polygon points="50,6 63,34 94,39 71,62 77,93 50,78 23,93 29,62 6,39 37,34" '
		+ 'fill="#FFFFFF" stroke="#C5C8D4" stroke-width="5" '
		+ 'stroke-linejoin="round" stroke-linecap="round"/>'
		+ '</svg>'
	),
}

static var _texture_cache: Dictionary = {}


static func get_star_svg_content(state: String) -> String:
	if not BUILTIN_STAR_SVGS.has(state):
		FailFast.fail("CRITICAL: Unknown star state '%s'." % state)
		return ""
	var svg_path: String = "res://assets/images/icons/star_%s.svg" % state.to_lower()
	if FileAccess.file_exists(svg_path):
		return FileAccess.get_file_as_string(svg_path)
	return str(BUILTIN_STAR_SVGS[state])


static func get_star_texture(radius: int, state: String) -> Texture2D:
	if not FailFast.require_positive_int(radius, "radius"):
		return null
	if not BUILTIN_STAR_SVGS.has(state):
		FailFast.fail("CRITICAL: Unknown star state '%s'." % state)
		return null

	var key: String = "%d_%s" % [radius, state]
	if _texture_cache.has(key):
		var cached: Variant = _texture_cache[key]
		if cached is Texture2D:
			return cached

	var target_sz: int = maxi(12, int(round(float(radius) * 2.3)))
	var svg_str: String = get_star_svg_content(state)
	var img: Image = Image.new()
	var svg_scale: float = float(target_sz) / 200.0
	var err: Error = img.load_svg_from_string(svg_str, svg_scale)
	if err != OK:
		FailFast.fail("CRITICAL: Failed to rasterize star SVG for state '%s'." % state)
		return null

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_texture_cache[key] = tex
	return tex


static func compute_star_points(
	center: Vector2,
	outer_radius: float,
	inner_radius: float
) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	if not FailFast.require_positive_float(outer_radius, "outer_radius"):
		return pts
	if not FailFast.require_positive_float(inner_radius, "inner_radius"):
		return pts
	if inner_radius >= outer_radius:
		FailFast.fail("CRITICAL: inner_radius must be smaller than outer_radius.")
		return pts

	var start_angle: float = -PI / 2.0
	var step: float = PI / 5.0
	for i: int in range(10):
		var angle: float = start_angle + float(i) * step
		var r: float = outer_radius if (i % 2 == 0) else inner_radius
		pts.append(Vector2(center.x + r * cos(angle), center.y + r * sin(angle)))
	return pts


static func draw_subtle_sparkle(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	progress: float
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if progress < 0.0 or progress > 1.0:
		return

	var intensity: float = sin(progress * PI)
	var alpha: float = 0.67 * intensity
	if alpha <= 0.01:
		return

	var ray_len: float = maxf(2.5, radius * (0.24 + 0.12 * intensity))
	var ray_thick: float = maxf(1.0, ray_len * 0.16)
	var col: Color = Color(1.0, 1.0, 1.0, alpha)

	var v_pts: PackedVector2Array = PackedVector2Array([
		Vector2(center.x, center.y - ray_len),
		Vector2(center.x + ray_thick, center.y),
		Vector2(center.x, center.y + ray_len),
		Vector2(center.x - ray_thick, center.y),
	])
	canvas.draw_colored_polygon(v_pts, col)

	var h_pts: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - ray_len, center.y),
		Vector2(center.x, center.y - ray_thick),
		Vector2(center.x + ray_len, center.y),
		Vector2(center.x, center.y + ray_thick),
	])
	canvas.draw_colored_polygon(h_pts, col)
	canvas.draw_circle(center, maxf(1.0, ray_len * 0.20), Color(1.0, 1.0, 1.0, minf(1.0, alpha * 1.25)))


static func draw_progress_stars(
	canvas: CanvasItem,
	center_pos: Vector2i,
	round_results: Array[bool],
	total_rounds: int,
	radius: int,
	spacing: int,
	anim_time: float,
	active_round_index: int,
	latest_pop_progress: float,
	latest_rainbow_progress: float,
	star_y_offsets: Array[int],
	star_scales: Array[float],
	star_rainbow_progresses: Array[float]
) -> void:
	if not FailFast.require_not_null(canvas, "canvas"):
		return
	if not FailFast.require_positive_int(total_rounds, "total_rounds"):
		return
	if not FailFast.require_positive_int(radius, "radius"):
		return
	if not FailFast.require_positive_int(spacing, "spacing"):
		return

	var total_w: int = (total_rounds - 1) * spacing
	var start_x: int = center_pos.x - total_w / 2
	var cycle_period: float = 4.0
	var sparkle_dur: float = 0.80

	for i: int in range(total_rounds):
		var x: float = float(start_x + i * spacing)
		var y_off: int = star_y_offsets[i] if i < star_y_offsets.size() else 0
		var y: float = float(center_pos.y + y_off)

		var state: String = "UNPLAYED"
		if i < round_results.size():
			state = "FILLED" if round_results[i] else "WRONG"

		var is_latest_filled: bool = (
			round_results.size() > 0 and i == round_results.size() - 1 and state == "FILLED"
		)
		var star_rb: float = -1.0
		if i < star_rainbow_progresses.size():
			star_rb = star_rainbow_progresses[i]
		elif is_latest_filled:
			star_rb = latest_rainbow_progress

		var star_scale: float = star_scales[i] if i < star_scales.size() else 1.0

		if active_round_index >= 0 and i == active_round_index and state == "UNPLAYED":
			var pulse: float = 0.5 + 0.5 * sin(anim_time * 4.5)
			star_scale = 1.0 + 0.10 * pulse
			var halo_r: float = maxf(4.0, float(radius) * (1.28 + 0.14 * pulse))
			var halo_alpha: float = (38.0 + 26.0 * pulse) / 255.0
			canvas.draw_circle(Vector2(x, y), halo_r, Color(1.0, 205.0 / 255.0, 40.0 / 255.0, halo_alpha))

		if is_latest_filled and latest_pop_progress >= 0.0 and latest_pop_progress <= 1.0:
			star_scale = RainbowMath.compute_star_pop_scale(latest_pop_progress)

		var tex: Texture2D = get_star_texture(radius, state)
		if tex != null:
			var draw_w: float = float(tex.get_width()) * star_scale
			var draw_h: float = float(tex.get_height()) * star_scale
			var dest_rect: Rect2 = Rect2(x - draw_w * 0.5, y - draw_h * 0.5, draw_w, draw_h)

			# Soft ambient drop shadow
			var sh_dy: float = maxf(1.5, float(radius) * 0.14)
			var sh_alpha: float = 0.22 if state == "FILLED" else 0.12
			var sh_rect: Rect2 = Rect2(dest_rect.position.x, dest_rect.position.y + sh_dy, draw_w, draw_h)
			canvas.draw_texture_rect(tex, sh_rect, false, Color(0.0, 0.0, 0.0, sh_alpha))

			var modulate_col: Color = Color.WHITE
			if state == "FILLED" and star_rb >= 0.0 and star_rb < 1.0:
				var rb_col: Color = RainbowMath.sample_rainbow_band_color(star_rb * 12.0, 0.85, 1.0, 0.35)
				var blend: float = 1.0
				if star_rb > 0.70:
					blend = 1.0 - (star_rb - 0.70) / 0.30
				modulate_col = Color.WHITE.lerp(rb_col, clampf(blend, 0.0, 1.0))

			canvas.draw_texture_rect(tex, dest_rect, false, modulate_col)

		if state == "FILLED":
			var stagger: float = fposmod(float(i) * 0.85, cycle_period)
			var local_t: float = fposmod(anim_time + stagger, cycle_period)
			if local_t < sparkle_dur:
				var sp_prog: float = local_t / sparkle_dur
				var sp_center: Vector2 = Vector2(x + float(radius) * 0.35, y - float(radius) * 0.35)
				draw_subtle_sparkle(canvas, sp_center, float(radius), sp_prog)
