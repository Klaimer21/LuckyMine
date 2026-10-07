class_name Companion
extends RefCounted
## Компаньон: бригадир Борк. Пиксельная картинка assets/pixel/bork/idle.png (без фона), показывается без сглаживания; без неё берётся assets/ui/companion.png.

const TEXTURE_PATH := "res://assets/pixel/bork/idle.png"
const TEXTURE_FALLBACK := "res://assets/ui/companion.png"


## Позы Борка (assets/pixel/bork/<поза>.png, 96x128): радуется, бьёт киркой, устал, спит, показывает, удивлён.
const POSES := ["cheer", "strike", "tired", "sleep", "point", "surprised"]


static func texture(pose := "") -> Texture2D:
	if pose in POSES:
		var pose_path := "res://assets/pixel/bork/%s.png" % pose
		if ResourceLoader.exists(pose_path):
			return load(pose_path) as Texture2D
	for path in [TEXTURE_PATH, TEXTURE_FALLBACK]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Логотип игры (assets/pixel/logo.png) заданной ширины или null, если файла нет.
static func logo(width: float) -> TextureRect:
	var path := "res://assets/pixel/logo.png"
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(width, width * float(tex.get_height()) / float(tex.get_width()))
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Портрет заданной высоты или null, если картинки нет.
static func portrait(height: float, pose := "") -> TextureRect:
	var tex := texture(pose)
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if tex.resource_path.begins_with("res://assets/pixel/") else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(height * float(tex.get_width()) / float(tex.get_height()), height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
