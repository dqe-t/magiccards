class_name RainbowMath
extends RefCounted

const RAINBOW_12_HUES: Array[float] = [
	0.00, 0.05, 0.09, 0.14, 0.22, 0.33, 0.45, 0.53, 0.60, 0.68, 0.78, 0.90
]


class StarDropState extends RefCounted:
	var offset_y: int = 0
	var scale: float = 1.0


static func ease_out_cubic(t: float) -> float:
	if is_nan(t) or is_inf(t):
		FailFast.fail("CRITICAL: t must be a valid number.")
		return 0.0
	var clamped: float = clampf(t, 0.0, 1.0)
	var inv: float = 1.0 - clamped
	return 1.0 - (inv * inv * inv)


static func compute_shake_offset(state_time: float, duration: float) -> int:
	if not FailFast.require_positive_float(duration, "duration"):
		return 0
	if not FailFast.require_non_negative_float(state_time, "state_time"):
		return 0
	if state_time >= duration:
		return 0
	var decay: float = 1.0 - (state_time / duration)
	return int(round(10.0 * decay * sin(state_time * 45.0)))


static func sample_rainbow_band_color(
	band_pos: float,
	saturation: float,
	value: float,
	feather: float
) -> Color:
	if is_nan(band_pos) or is_inf(band_pos):
		FailFast.fail("CRITICAL: band_pos must be a valid number.")
		return Color.WHITE
	if not FailFast.require_in_range_float(saturation, 0.0, 1.0, "saturation"):
		return Color.WHITE
	if not FailFast.require_in_range_float(value, 0.0, 1.0, "value"):
		return Color.WHITE
	if is_nan(feather) or feather < 0.0 or feather >= 1.0:
		FailFast.fail("CRITICAL: feather must be in [0.0, 1.0).")
		return Color.WHITE

	var n: int = RAINBOW_12_HUES.size()
	var floored: float = floor(band_pos)
	var idx: int = posmod(int(floored), n)
	var frac: float = band_pos - floored

	var col1: Color = Color.from_hsv(RAINBOW_12_HUES[idx], saturation, value, 1.0)
	if feather > 0.0 and frac > 1.0 - feather:
		var t: float = (frac - (1.0 - feather)) / feather
		t = t * t * (3.0 - 2.0 * t)
		var next_idx: int = (idx + 1) % n
		var col2: Color = Color.from_hsv(RAINBOW_12_HUES[next_idx], saturation, value, 1.0)
		return col1.lerp(col2, t)
	return col1


static func compute_star_drop_state(
	anim_time: float,
	star_index: int,
	start_y: float,
	target_y: float
) -> StarDropState:
	var res: StarDropState = StarDropState.new()
	if is_nan(anim_time) or is_inf(anim_time):
		FailFast.fail("CRITICAL: anim_time must be a valid number.")
		return res
	if not FailFast.require_non_negative_int(star_index, "star_index"):
		return res

	var stagger: float = float(star_index) * 0.025
	var drop_dur: float = 0.42
	var star_t: float = clampf((anim_time - stagger) / drop_dur, 0.0, 1.0)

	var u: float = star_t - 1.0
	var overshoot: float = 1.45
	var eased_fall: float = 1.0 + u * u * ((overshoot + 1.0) * u + overshoot)
	var current_y: float = start_y + (target_y - start_y) * eased_fall
	res.offset_y = int(round(current_y - target_y))

	if star_t >= 0.65 and star_t < 1.0:
		var land_p: float = (star_t - 0.65) / 0.35
		res.scale = 1.0 + 0.18 * sin(land_p * PI)
	else:
		res.scale = 1.0
	return res


static func compute_star_rainbow_wave(
	anim_time: float,
	star_index: int,
	is_earned: bool
) -> float:
	if is_nan(anim_time) or is_inf(anim_time):
		FailFast.fail("CRITICAL: anim_time must be a valid number.")
		return -1.0
	if not FailFast.require_non_negative_int(star_index, "star_index"):
		return -1.0
	if not is_earned:
		return -1.0

	var wave_start: float = float(star_index) * 0.05
	var wave_dur: float = 0.95
	if anim_time < 0.0:
		return 0.0
	var progress: float = maxf(0.0, (anim_time - wave_start) / wave_dur)
	if progress >= 1.0:
		return -1.0
	return progress


static func compute_star_pop_scale(pop_progress: float) -> float:
	if not FailFast.require_in_range_float(pop_progress, 0.0, 1.0, "pop_progress"):
		return 1.0
	return 1.0 + 0.42 * sin(pop_progress * PI)


static func compute_animal_entrance_scale(anim_time: float, fade_duration: float) -> float:
	if is_nan(anim_time) or is_inf(anim_time):
		FailFast.fail("CRITICAL: anim_time must be a valid number.")
		return 1.0
	if not FailFast.require_positive_float(fade_duration, "fade_duration"):
		return 1.0
	if anim_time <= 0.0:
		return 0.86
	if anim_time >= fade_duration:
		return 1.0

	var t: float = anim_time / fade_duration
	var u: float = t - 1.0
	var overshoot: float = 2.2
	var eased: float = 1.0 + u * u * ((overshoot + 1.0) * u + overshoot)
	return 0.86 + 0.14 * eased
