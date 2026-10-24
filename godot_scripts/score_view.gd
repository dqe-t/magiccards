class_name ScoreView
extends RefCounted

const VIDEO_ASPECT_RATIO: float = 1280.0 / 720.0  # 16:9 native aspect ratio of reward videos

const WHITE_CLAMP_SHADER_CODE: String = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Only clamp near-white background noise (luminance > 0.94) smoothly to pure white,
	// leaving line art and anti-aliasing perfectly sharp and intact.
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (lum >= 0.94) {
		float t = clamp((lum - 0.94) / 0.05, 0.0, 1.0);
		COLOR = vec4(mix(c.rgb, vec3(1.0), t), c.a * COLOR.a);
	} else {
		COLOR = vec4(c.rgb, c.a * COLOR.a);
	}
}
"""

var screen_w: int
var screen_h: int
var system_dpi: int
var override_diag_inches: float
var score: int
var round_results: Array[bool]
var max_score: int = 10
var animal_mgr: AnimalManager
var audio_mgr: AudioManager

var anim_time: float = 0.0
var fade_duration: float = 0.45
var bounce_anim_time: float = 1.0
var bounce_duration: float = 0.45

var metrics: ResponsiveLayout.ScoreMetrics = null
var btn_replay: UIWidgets.UIIconButton = null
var video_player: VideoStreamPlayer = null
var overlay_ctrl: ScoreOverlay = null
var video_finished: bool = false
var animal_aspect: float = 1.0


class ScoreOverlay extends Control:
	var score_view: ScoreView = null
	var font_manager: FontManager = null
	var mouse_pos: Vector2i = Vector2i.ZERO
	var is_mouse_down: bool = false

	func _draw() -> void:
		if score_view != null and font_manager != null:
			score_view._draw_foreground(self, font_manager, mouse_pos, is_mouse_down)


func _init(
	p_screen_w: int,
	p_screen_h: int,
	p_system_dpi: int,
	p_override_diag_inches: float,
	p_score: int,
	p_round_results: Array[bool],
	p_animal_mgr: AnimalManager,
	p_audio_mgr: AudioManager,
	p_host_node: Control
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w") or not FailFast.require_positive_int(p_screen_h, "p_screen_h") or not FailFast.require_positive_int(p_system_dpi, "p_system_dpi"):
		return
	if not FailFast.require_not_null(p_animal_mgr, "p_animal_mgr"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	self.score = clampi(p_score, 0, self.max_score)
	self.round_results = p_round_results.duplicate()
	self.animal_mgr = p_animal_mgr
	self.audio_mgr = p_audio_mgr

	var tex: Texture2D = self.animal_mgr.get_animal_texture(self.score)
	if tex != null and tex.get_height() > 0:
		self.animal_aspect = float(tex.get_width()) / float(tex.get_height())

	_rebuild_layout()

	if self.audio_mgr != null:
		self.audio_mgr.play_animal_sound(self.score)

	if p_host_node != null:
		if self.animal_mgr.has_video(self.score):
			_setup_video_player(p_host_node)
		self.overlay_ctrl = ScoreOverlay.new()
		self.overlay_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		self.overlay_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
		self.overlay_ctrl.score_view = self
		p_host_node.add_child(self.overlay_ctrl)


func _setup_video_player(host_node: Control) -> void:
	var stream: VideoStream = self.animal_mgr.load_video_stream(self.score)
	if stream == null:
		return
	self.video_player = VideoStreamPlayer.new()
	self.video_player.stream = stream
	self.video_player.volume_db = -80.0
	self.video_player.expand = true
	self.video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader: Shader = Shader.new()
	shader.code = WHITE_CLAMP_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	self.video_player.material = mat

	self.video_player.finished.connect(_on_video_finished)
	host_node.add_child(self.video_player)
	if self.video_player.is_inside_tree():
		self.video_player.play()
	_update_video_player_transform()


func _on_video_finished() -> void:
	self.video_finished = true
	if self.video_player != null:
		self.video_player.visible = false


func resize(
	p_screen_w: int,
	p_screen_h: int,
	p_system_dpi: int,
	p_override_diag_inches: float
) -> void:
	if not FailFast.require_positive_int(p_screen_w, "p_screen_w") or not FailFast.require_positive_int(p_screen_h, "p_screen_h") or not FailFast.require_positive_int(p_system_dpi, "p_system_dpi"):
		return

	self.screen_w = p_screen_w
	self.screen_h = p_screen_h
	self.system_dpi = p_system_dpi
	self.override_diag_inches = p_override_diag_inches
	_rebuild_layout()
	_update_video_player_transform()


func _rebuild_layout() -> void:
	self.metrics = ResponsiveLayout.compute_score_metrics(
		self.screen_w,
		self.screen_h,
		self.system_dpi,
		self.override_diag_inches
	)
	var r_rect: Rect2i = self.metrics.replay_rect
	self.btn_replay = UIWidgets.UIIconButton.new(
		r_rect,
		"PLAY",
		Color8(20, 20, 25),
		Color8(50, 50, 60),
		Color.WHITE,
		maxi(16, int(round(float(r_rect.size.x) * 0.22))),
		Color8(20, 20, 25),
		0
	)


func get_animal_rect() -> Rect2i:
	var h: int = self.metrics.animal_size
	var w: int = maxi(1, int(round(float(h) * self.animal_aspect)))
	var c: Vector2i = self.metrics.animal_center
	return Rect2i(c.x - w / 2, c.y - h / 2, w, h)


func get_video_rect() -> Rect2i:
	var h: int = self.metrics.animal_size
	var w: int = maxi(1, int(round(float(h) * VIDEO_ASPECT_RATIO)))
	var c: Vector2i = self.metrics.animal_center
	return Rect2i(c.x - w / 2, c.y - h / 2, w, h)


func is_animal_clicked(pos: Vector2i) -> bool:
	if self.video_player != null and not self.video_finished:
		return get_video_rect().has_point(pos)
	return get_animal_rect().has_point(pos)


func is_animal_animation_finished() -> bool:
	if self.anim_time < self.fade_duration:
		return false
	if self.video_player != null and not self.video_finished:
		return false
	return self.bounce_anim_time >= self.bounce_duration


func replay_animal_animation() -> void:
	if not is_animal_animation_finished():
		return
	if self.video_player != null:
		self.video_finished = false
		self.video_player.visible = true
		self.video_player.stop()
		self.video_player.play()
	else:
		self.bounce_anim_time = 0.0
	if self.audio_mgr != null:
		self.audio_mgr.play_animal_sound(self.score)


func _compute_current_animal_scale() -> float:
	var total_scale: float = RainbowMath.compute_animal_entrance_scale(self.anim_time, self.fade_duration)
	if self.bounce_anim_time < self.bounce_duration:
		var p: float = self.bounce_anim_time / self.bounce_duration
		total_scale *= 1.0 + 0.12 * sin(p * PI)
	return total_scale


func _update_video_player_transform() -> void:
	if self.video_player == null:
		return
	var fade_t: float = clampf(self.anim_time / self.fade_duration, 0.0, 1.0)
	var total_scale: float = _compute_current_animal_scale()
	var base_rect: Rect2i = get_video_rect()
	var sw: float = float(base_rect.size.x) * total_scale
	var sh: float = float(base_rect.size.y) * total_scale
	var c: Vector2 = Vector2(float(self.metrics.animal_center.x), float(self.metrics.animal_center.y))
	self.video_player.position = Vector2(c.x - sw * 0.5, c.y - sh * 0.5)
	self.video_player.size = Vector2(sw, sh)
	self.video_player.modulate = Color(1.0, 1.0, 1.0, fade_t)


func update(dt: float) -> void:
	if not FailFast.require_non_negative_float(dt, "dt"):
		return
	self.anim_time += dt
	if self.bounce_anim_time < self.bounce_duration:
		self.bounce_anim_time += dt
	_update_video_player_transform()


func handle_click(pos: Vector2i) -> String:
	if self.btn_replay != null and self.btn_replay.is_clicked(pos):
		return "PLAY"
	if is_animal_clicked(pos) and is_animal_animation_finished():
		replay_animal_animation()
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

	var fade_t: float = clampf(self.anim_time / self.fade_duration, 0.0, 1.0)
	var tex: Texture2D = self.animal_mgr.get_animal_texture(self.score)
	if tex != null and (self.video_player == null or self.video_finished):
		var total_scale: float = _compute_current_animal_scale()
		var base_rect: Rect2i = get_animal_rect()
		var sw: float = float(base_rect.size.x) * total_scale
		var sh: float = float(base_rect.size.y) * total_scale
		var c: Vector2 = Vector2(float(self.metrics.animal_center.x), float(self.metrics.animal_center.y))
		var dest: Rect2 = Rect2(c.x - sw * 0.5, c.y - sh * 0.5, sw, sh)
		canvas.draw_texture_rect(tex, dest, false, Color(1.0, 1.0, 1.0, fade_t))

	if self.overlay_ctrl != null:
		self.overlay_ctrl.font_manager = fm
		self.overlay_ctrl.mouse_pos = mouse_pos
		self.overlay_ctrl.is_mouse_down = is_mouse_down
		self.overlay_ctrl.queue_redraw()
	else:
		_draw_foreground(canvas, fm, mouse_pos, is_mouse_down)


func _draw_foreground(
	target_canvas: CanvasItem,
	fm: FontManager,
	mouse_pos: Vector2i,
	is_mouse_down: bool
) -> void:
	if not FailFast.require_not_null(target_canvas, "target_canvas"):
		return
	if not FailFast.require_not_null(fm, "fm"):
		return

	var star_offsets: Array[int] = []
	var star_scales: Array[float] = []
	var star_rainbows: Array[float] = []
	for i: int in range(self.max_score):
		var drop: RainbowMath.StarDropState = RainbowMath.compute_star_drop_state(
			self.anim_time,
			i,
			float(self.metrics.stars_start_y),
			float(self.metrics.stars_center_y)
		)
		star_offsets.append(drop.offset_y)
		star_scales.append(drop.scale)
		var earned: bool = i < self.round_results.size() and self.round_results[i]
		star_rainbows.append(RainbowMath.compute_star_rainbow_wave(self.anim_time, i, earned))

	StarRenderer.draw_progress_stars(
		target_canvas,
		Vector2i(self.screen_w / 2, self.metrics.stars_center_y),
		self.round_results,
		self.max_score,
		self.metrics.star_radius,
		self.metrics.star_spacing,
		self.anim_time,
		-1,
		-1.0,
		-1.0,
		star_offsets,
		star_scales,
		star_rainbows
	)

	var btn_alpha: float = clampf(self.anim_time / 0.4, 0.0, 1.0)
	self.btn_replay.render(target_canvas, mouse_pos, is_mouse_down, btn_alpha)

	var fade_t: float = clampf(self.anim_time / self.fade_duration, 0.0, 1.0)
	var msg_text: String = AnimalManager.get_score_subtitle(self.score)
	var ui_font: Font = fm.get_ui_font(false)
	var fsize: int = self.metrics.subtitle_font_size
	var msg_sz: Vector2 = ui_font.get_string_size(msg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var msg_pos: Vector2 = Vector2(
		float(self.metrics.subtitle_center.x) - msg_sz.x * 0.5,
		float(self.metrics.subtitle_center.y)
	)
	var sub_col: Color = Color(190.0 / 255.0, 190.0 / 255.0, 200.0 / 255.0, fade_t)
	target_canvas.draw_string(ui_font, msg_pos, msg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, sub_col)


func close() -> void:
	if self.video_player != null:
		self.video_player.stop()
		self.video_player.queue_free()
		self.video_player = null
	if self.overlay_ctrl != null:
		self.overlay_ctrl.queue_free()
		self.overlay_ctrl = null
