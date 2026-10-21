class_name AnimalManager
extends RefCounted

const SCORE_ANIMAL_MAP: Dictionary = {
	0: "score_0_ant.png",
	1: "score_1_fly.png",
	2: "score_2_frog.png",
	3: "score_3_duck.png",
	4: "score_4_bunny.png",
	5: "score_5_cat.png",
	6: "score_6_dog.png",
	7: "score_7_fox.png",
	8: "score_8_sheep.png",
	9: "score_9_lion.png",
	10: "score_10_bear.png",
}

const SCORE_MOTIVATION_FRENCH: Dictionary = {
	0: "Courage, réessaie !",
	1: "Continue, tu peux le faire !",
	2: "C'est un bon début !",
	3: "Tu apprends vite !",
	4: "Continue comme ça !",
	5: "C'est super !",
	6: "Tu y es presque !",
	7: "Bien joué, petit malin !",
	8: "Formidable !",
	9: "Très bien !",
	10: "Parfait !",
}

const SCORE_MOTIVATION_ENGLISH: Dictionary = {
	0: "Don't give up, try again!",
	1: "Keep going, you can do it!",
	2: "That's a good start!",
	3: "You're learning fast!",
	4: "Keep it up, you're doing great!",
	5: "That's wonderful!",
	6: "You're getting there!",
	7: "Well played, clever one!",
	8: "Fantastic work!",
	9: "Very good!",
	10: "Perfect!",
}

var animals_dir: String = "res://assets/images/animals"
var videos_dir: String = "res://assets/videos/animals"
var _texture_cache: Dictionary = {}


func _init(
	custom_animals_dir: String = "res://assets/images/animals",
	custom_videos_dir: String = "res://assets/videos/animals"
) -> void:
	if not FailFast.require_non_empty_str(custom_animals_dir, "custom_animals_dir"):
		return
	if not FailFast.require_non_empty_str(custom_videos_dir, "custom_videos_dir"):
		return
	self.animals_dir = custom_animals_dir.trim_suffix("/")
	self.videos_dir = custom_videos_dir.trim_suffix("/")


static func get_score_subtitle(score: int) -> String:
	if not FailFast.require_in_range_int(score, 0, 10, "score"):
		return ""
	var fr: String = str(SCORE_MOTIVATION_FRENCH[score])
	var en: String = str(SCORE_MOTIVATION_ENGLISH[score])
	return "%s - %s" % [fr, en]


func get_video_path(score: int) -> String:
	if not FailFast.require_in_range_int(score, 0, 10, "score"):
		return ""
	var img_name: String = str(SCORE_ANIMAL_MAP[score])
	var stem: String = img_name.get_basename()
	var ogv_path: String = "%s/%s.ogv" % [self.videos_dir, stem]
	if FileAccess.file_exists(ogv_path) or ResourceLoader.exists(ogv_path):
		return ogv_path
	return ""


func has_video(score: int) -> bool:
	if not FailFast.require_in_range_int(score, 0, 10, "score"):
		return false
	return not get_video_path(score).is_empty()


func load_video_stream(score: int) -> VideoStream:
	if not FailFast.require_in_range_int(score, 0, 10, "score"):
		return null
	var vpath: String = get_video_path(score)
	if vpath.is_empty():
		return null

	if ResourceLoader.exists(vpath):
		var res: Resource = ResourceLoader.load(vpath)
		if res is VideoStream:
			return res

	var theora: VideoStreamTheora = VideoStreamTheora.new()
	theora.file = vpath
	return theora


func get_animal_texture(score: int) -> Texture2D:
	if not FailFast.require_in_range_int(score, 0, 10, "score"):
		return null

	if _texture_cache.has(score):
		var cached: Variant = _texture_cache[score]
		if cached is Texture2D:
			return cached

	var filename: String = str(SCORE_ANIMAL_MAP[score])
	var path: String = "%s/%s" % [self.animals_dir, filename]

	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			_texture_cache[score] = res
			return res

	if FileAccess.file_exists(path):
		var img: Image = Image.new()
		var err: Error = img.load(path)
		if err == OK:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			_texture_cache[score] = tex
			return tex

	FailFast.fail("CRITICAL: Animal image not found at %s" % path)
	return null
