class_name Companion
extends RefCounted
## Компаньон: бригадир Борк. Картинка assets/ui/companion.png (без фона); без файла игра обходится без портрета.

const TEXTURE_PATH := "res://assets/ui/companion.png"


static func texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D if ResourceLoader.exists(TEXTURE_PATH) else null


## Портрет заданной высоты или null, если картинки нет.
static func portrait(height: float) -> TextureRect:
	var tex := texture()
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(height * float(tex.get_width()) / float(tex.get_height()), height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
