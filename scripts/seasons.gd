class_name Seasons
extends RefCounted
## Сезоны: чисто косметические наборы (оттенок мира, частицы, музыка). Наград и бонусов у них нет, поэтому перевод часов
## устройства ничего не даёт. Включаются вручную в настройках или «Авто» (по дате устройства).

const NONE := "none"
const AUTO := "auto"
## id, название, оттенок мира (умножается на цвета пола, пород, света и фона), музыка, окно дат (месяц, день) включительно.
const LIST := [
	{"id": "winter", "name": "Зима", "tint": Color(0.80, 0.93, 1.2), "music": "res://assets/audio/music_winter.wav",
			"from": [12, 1], "to": [2, 29]},
	{"id": "halloween", "name": "Хэллоуин", "tint": Color(1.22, 0.78, 1.1), "music": "res://assets/audio/music_halloween.wav",
			"from": [10, 20], "to": [11, 3]},
]
## Значения настройки в порядке выбора: «Обычный», «Авто», затем сезоны.
const CHOICES := ["none", "auto", "winter", "halloween"]
const CHOICE_NAMES := ["Обычный", "Авто (по дате)", "Зима", "Хэллоуин"]


static func data(id: String) -> Dictionary:
	for entry in LIST:
		if str(entry["id"]) == id:
			return entry
	return {}


## Сезон, на который выпадает дата (окно может переходить через конец года).
static func for_date(month: int, day: int) -> String:
	var value := month * 100 + day
	for entry in LIST:
		var from: Array = entry["from"]
		var to: Array = entry["to"]
		var start := int(from[0]) * 100 + int(from[1])
		var end := int(to[0]) * 100 + int(to[1])
		var inside := (value >= start and value <= end) if start <= end else (value >= start or value <= end)
		if inside:
			return str(entry["id"])
	return NONE


## Какой сезон действует при данной настройке; неизвестное значение — «Обычный».
static func active(setting: String, month: int, day: int) -> String:
	if setting == AUTO:
		return for_date(month, day)
	return setting if not data(setting).is_empty() else NONE


static func tint(id: String) -> Color:
	var entry := data(id)
	return entry["tint"] if not entry.is_empty() else Color.WHITE


static func music_path(id: String) -> String:
	var entry := data(id)
	return str(entry["music"]) if not entry.is_empty() else ""
