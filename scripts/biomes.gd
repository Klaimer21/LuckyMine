class_name Biomes
extends RefCounted
## Зоны шахты. Глубина растёт вместе с заработанным за всё время (не траты): граница зоны — порог по
## сумме; пороги подобраны симуляцией идеального игрока без касаний (с престижем, коллекцией, алмазами и навыком «Бур»): 10 мин, 45 мин, 3 ч, 10 ч, 2 дня, 7 дней.
## Заработанное за всё время не сбрасывается при «Новой шахте», поэтому зона и глубина остаются.
## Внутри зоны глубина идёт по логарифму суммы. Зона меняет цвет пола, света и пород, набор руды и добавляет
## множитель к добыче. Последняя зона — «Ядро»: дальше бесконечный спуск.

const CORE := 6
## name — русский ключ перевода; from — порог заработанного; depth — метры в начале зоны;
## max_ore — самая редкая руда зоны по ценности (1 медь … 3 золото; алмаз выпадает только алмазной жилой); factor — множитель добычи; floor — четыре цвета пола;
## tint — оттенок пород; sun — цвет света.
const LIST := [
	{"name": "Каменоломня", "from": 0.0, "depth": 0, "max_ore": 1, "factor": 1.0,
		"floor": [Color(0.10, 0.12, 0.12), Color(0.17, 0.19, 0.19), Color(0.24, 0.25, 0.23), Color(0.30, 0.29, 0.25)],
		"tint": Color(1.0, 1.0, 1.0), "sun": Color(1.0, 0.96, 0.88)},
	{"name": "Медные пещеры", "from": 2.75e6, "depth": 100, "max_ore": 2, "factor": 1.1,
		"floor": [Color(0.12, 0.09, 0.07), Color(0.20, 0.14, 0.10), Color(0.28, 0.19, 0.12), Color(0.35, 0.24, 0.15)],
		"tint": Color(1.1, 0.92, 0.8), "sun": Color(1.0, 0.93, 0.82)},
	{"name": "Железные жилы", "from": 1.38e8, "depth": 300, "max_ore": 3, "factor": 1.2,
		"floor": [Color(0.09, 0.11, 0.14), Color(0.15, 0.18, 0.22), Color(0.22, 0.25, 0.30), Color(0.28, 0.32, 0.38)],
		"tint": Color(0.85, 0.92, 1.05), "sun": Color(0.92, 0.96, 1.0)},
	{"name": "Золотые залежи", "from": 1.35e11, "depth": 600, "max_ore": 3, "factor": 1.35,
		"floor": [Color(0.13, 0.11, 0.07), Color(0.22, 0.18, 0.10), Color(0.32, 0.26, 0.13), Color(0.40, 0.32, 0.15)],
		"tint": Color(1.08, 1.0, 0.8), "sun": Color(1.0, 0.95, 0.78)},
	{"name": "Кристальная пещера", "from": 3.71e14, "depth": 1000, "max_ore": 3, "factor": 1.5,
		"floor": [Color(0.06, 0.11, 0.13), Color(0.09, 0.18, 0.21), Color(0.13, 0.26, 0.30), Color(0.18, 0.34, 0.38)],
		"tint": Color(0.8, 1.0, 1.05), "sun": Color(0.85, 0.97, 1.0)},
	{"name": "Магма", "from": 7.78e18, "depth": 1600, "max_ore": 3, "factor": 1.7,
		"floor": [Color(0.10, 0.06, 0.06), Color(0.18, 0.08, 0.07), Color(0.28, 0.11, 0.08), Color(0.40, 0.15, 0.09)],
		"tint": Color(1.15, 0.8, 0.7), "sun": Color(1.0, 0.82, 0.7)},
	{"name": "Ядро", "from": 1.51e22, "depth": 2400, "max_ore": 3, "factor": 2.0,
		"floor": [Color(0.07, 0.06, 0.07), Color(0.14, 0.09, 0.08), Color(0.30, 0.15, 0.08), Color(0.55, 0.28, 0.10)],
		"tint": Color(1.2, 0.9, 0.7), "sun": Color(1.0, 0.85, 0.6)},
]


## Акцентный цвет зоны (пыль в воздухе, подсветки): совпадает с tools/backgrounds.html.
const ACCENTS := [Color("c9a45c"), Color("c77a4d"), Color("8aa0bf"), Color("e0b64a"), Color("7fdbe6"), Color("ff7a3d"),
		Color("ffb347")]


## Планеты («Новая планета» — второй престиж): оттенок мира и его название; дальше циклом с номером.
## Пороги зон на планете N выше в SCALE^N раз (см. tools/economy_sim.py).
const PLANET_SCALE := 100.0
const PLANETS := [
	{"name": "Земля", "tint": Color(1.0, 1.0, 1.0), "mod": "", "text": "обычная планета без особенностей"},
	{"name": "Марс", "tint": Color(1.25, 0.82, 0.68), "mod": "diamonds", "text": "+25% алмазов"},
	{"name": "Луна", "tint": Color(0.88, 0.95, 1.08), "mod": "golden", "text": "золотая глыба появляется на 30% чаще"},
	{"name": "Титан", "tint": Color(0.72, 1.0, 1.18), "mod": "dynamite", "text": "динамит выдаётся на 50% чаще"},
	{"name": "Венера", "tint": Color(1.22, 1.1, 0.7), "mod": "boss", "text": "хранители зон слабее на 30%, а награда вдвое больше"},
]


## Свои названия зон на планете (кроме Земли); нет записи — названия Земли.
const PLANET_ZONE_NAMES := {
	1: ["Рыжая пустошь", "Окисные пещеры", "Базальтовые жилы", "Серные залежи", "Ледяные пещеры", "Магма Олимпа", "Ядро Марса"],
}


static func zone_name(index: int, planet: int) -> String:
	var names: Array = PLANET_ZONE_NAMES.get(planet % PLANETS.size(), [])
	return str(names[index]) if index < names.size() else str(LIST[index]["name"])


static func planet_name(planet: int) -> String:
	return str(PLANETS[planet]["name"]) if planet < PLANETS.size() else "Экзопланета %d" % (planet - PLANETS.size() + 1)


## Особенность планеты (строка-ключ) и её описание; на экзопланетах циклом повторяются.
static func planet_mod(planet: int) -> String:
	return str(PLANETS[planet % PLANETS.size()]["mod"])


static func planet_mod_text(planet: int) -> String:
	return str(PLANETS[planet % PLANETS.size()]["text"])


static func planet_tint(planet: int) -> Color:
	return PLANETS[planet % PLANETS.size()]["tint"]


static func scale_for(planet: int) -> float:
	return pow(PLANET_SCALE, planet)


static func index_for(total: float, scale := 1.0) -> int:
	var index := 0
	for i in LIST.size():
		if total >= float(LIST[i]["from"]) * scale:
			index = i
	return index


static func factor(total: float, scale := 1.0) -> float:
	return LIST[index_for(total, scale)]["factor"]


## Доля пути до следующей зоны (0…1); в последней зоне всегда 1.
static func progress(total: float, scale := 1.0) -> float:
	var i := index_for(total, scale)
	if i >= LIST.size() - 1:
		return 1.0
	var start := maxf(float(LIST[i]["from"]) * scale, 1.0)
	var end := float(LIST[i + 1]["from"]) * scale
	return clampf((log(maxf(total, 1.0)) - log(start)) / (log(end) - log(start)), 0.0, 1.0)


## Глубина в метрах: линейно по логарифму суммы внутри зоны; после «Ядра» — ещё 40 м на каждый порядок.
static func depth_m(total: float, scale := 1.0) -> int:
	var i := index_for(total, scale)
	var start_depth := float(LIST[i]["depth"])
	if i >= LIST.size() - 1:
		var beyond := maxf(0.0, log(maxf(total, 1.0) / (float(LIST[i]["from"]) * scale)) / log(10.0))
		return int(start_depth + 40.0 * beyond)
	var span := float(LIST[i + 1]["depth"]) - start_depth
	return int(start_depth + span * progress(total, scale))
