class_name Relics
extends RefCounted
## Диковинки из экспедиций: названия и значки (assets/pixel/finds). Сколько найдено, хранит ClickerState.relics.

const NAMES := {
	"map": "Обрывок старой карты",
	"coin": "Старинная монета с кайлом",
	"bone": "Кость древнего зверя",
	"crystal": "Светящийся осколок кристалла",
}


static func name_of(id: String) -> String:
	return str(NAMES.get(id, id))


static func icon(id: String) -> String:
	return "find_" + id
