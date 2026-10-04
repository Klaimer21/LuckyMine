class_name Retention
extends RefCounted
## Данные удержания: ежедневные награды, экспедиции, достижения. Логика и сохранение — в ClickerState.

## Ежедневная награда по дню серии (7 дней по кругу). coins — секунд текущего дохода (не меньше 100 монет).
const DAILY := [
	{"coins": 900.0}, {"diamonds": 1, "dynamite": 2}, {"coins": 2700.0}, {"diamonds": 2},
	{"coins": 7200.0, "dynamite": 3}, {"diamonds": 3}, {"diamonds": 5, "points": 1, "dynamite": 3},
]

## Экспедиции: сколько часов, доля дохода монетами, алмазы, число находок в журнал.
const EXPEDITIONS := [
	{"name": "Разведка", "hours": 1.0, "coins": 0.25, "diamonds": 0, "dynamite": 1, "finds": 4},
	{"name": "Спуск", "hours": 4.0, "coins": 0.25, "diamonds": 1, "dynamite": 2, "finds": 14},
	{"name": "Глубокий поход", "hours": 8.0, "coins": 0.25, "diamonds": 3, "dynamite": 4, "finds": 30},
]
const FIND_WEIGHTS := [50, 30, 15, 5]       # медь, железо, золото, алмаз в добыче экспедиции

## Достижения: kind — что считаем, goal — порог, reward — diamonds / points / style (индекс породы).
const ACHIEVEMENTS := [
	{"id": "zone1", "name": "Сто метров", "text": "Дойти до Медных пещер", "kind": "zone", "goal": 1, "reward": {"diamonds": 1}},
	{"id": "zone2", "name": "Железная хватка", "text": "Дойти до Железных жил", "kind": "zone", "goal": 2, "reward": {"points": 1, "style": 1}},
	{"id": "zone3", "name": "Золотая лихорадка", "text": "Дойти до Золотых залежей", "kind": "zone", "goal": 3, "reward": {"diamonds": 2, "style": 2}},
	{"id": "zone4", "name": "Кристальный взгляд", "text": "Дойти до Кристальной пещеры", "kind": "zone", "goal": 4, "reward": {"diamonds": 3}},
	{"id": "zone5", "name": "Жар земли", "text": "Дойти до Магмы", "kind": "zone", "goal": 5, "reward": {"diamonds": 5, "style": 3}},
	{"id": "zone6", "name": "Сердце земли", "text": "Дойти до Ядра", "kind": "zone", "goal": 6, "reward": {"points": 2, "style": 4}},
	{"id": "prestige1", "name": "Всё заново", "text": "Сделать «Новую шахту»", "kind": "prestige", "goal": 1, "reward": {"points": 1}},
	{"id": "prestige5", "name": "Старатель", "text": "Сделать «Новую шахту» 5 раз", "kind": "prestige", "goal": 5, "reward": {"points": 2}},
	{"id": "gold100", "name": "Золотой запас", "text": "Найти 100 золотых самородков", "kind": "gold", "goal": 100, "reward": {"diamonds": 2}},
	{"id": "diamond10", "name": "Огранка", "text": "Найти 10 алмазов", "kind": "diamond", "goal": 10, "reward": {"diamonds": 3}},
	{"id": "golden5", "name": "Золотая рука", "text": "Поймать 5 золотых глыб", "kind": "golden", "goal": 5, "reward": {"diamonds": 2}},
	{"id": "dynamite25", "name": "Подрывник", "text": "Взорвать динамит 25 раз", "kind": "dynamite", "goal": 25, "reward": {"diamonds": 2, "dynamite": 3}},
	{"id": "boss3", "name": "Хранитель покоя", "text": "Победить 3 хранителей зон", "kind": "boss", "goal": 3, "reward": {"diamonds": 3}},
	{"id": "planet1", "name": "Новый мир", "text": "Долететь до второй планеты", "kind": "planet", "goal": 1, "reward": {"diamonds": 5, "points": 2, "style": 5}},
	{"id": "planet3", "name": "Колонист", "text": "Долететь до четвёртой планеты", "kind": "planet", "goal": 3, "reward": {"diamonds": 15, "points": 5, "style": 6}},
	{"id": "rocks1k", "name": "Тысяча обвалов", "text": "Разбить 1000 камней", "kind": "rocks", "goal": 1000, "reward": {"diamonds": 3}},
	{"id": "rocks100k", "name": "Горный комбайн", "text": "Разбить 100 000 камней", "kind": "rocks", "goal": 100000, "reward": {"diamonds": 10, "points": 3}},
	{"id": "meta5", "name": "Старый колонист", "text": "Купить 5 уровней мета-улучшений", "kind": "meta", "goal": 5, "reward": {"diamonds": 10, "points": 2}},
	{"id": "set1", "name": "Полный набор", "text": "Довести все руды до уровня 1", "kind": "set", "goal": 1, "reward": {"diamonds": 3}},
]
