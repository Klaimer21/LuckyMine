class_name Machines
extends RefCounted
## Машины: покупаются за монеты, стоят над столом и работают сами (docs/MACHINES.md). Здесь только данные;
## логика уровней, цен и эффектов — в ClickerState, показ — в MachineStrip.

## id, название, значок, описание; открытие: unlock_rain — уровень «Камнепада» (0 — не нужно),
## unlock_zone — зона шахты (-1 — не нужно), достаточно любого из условий; base_cost — цена первого уровня
## (умножается на масштаб планеты), growth — рост цены за уровень, max_level — предел, step — прирост эффекта на уровень
## (у Дробилки доля потока «Камнепада», у Конвейера сдвиг порога руды, у Подрывника секунды периода, у Лебёдки доля времени похода).
const LIST := [
	{"id": "crusher", "name": "Дробилка", "icon": "crusher", "text": "Сама сбрасывает на стол свои глыбы.",
			"unlock_rain": 5, "unlock_zone": -1, "base_cost": 1500.0, "growth": 1.4, "max_level": 20, "step": 0.03},
	{"id": "conveyor", "name": "Конвейер", "icon": "conveyor", "text": "Везёт на стол руду: в глыбах чаще попадаются самородки.",
			"unlock_rain": 0, "unlock_zone": 1, "base_cost": 1.5e4, "growth": 1.25, "max_level": 15, "step": 0.01},
	{"id": "lab", "name": "Лаборатория", "icon": "lab", "text": "Из найденной породы варит алмазы: капля за каплей, даже пока вы заняты другим.",
			"unlock_rain": 0, "unlock_zone": 1, "base_cost": 8.0e3, "growth": 1.15, "max_level": 20, "step": 25.0},
	{"id": "blaster", "name": "Подрывник", "icon": "blaster", "text": "Сам взрывает малый заряд: монеты за взрыв, чем выше уровень, тем чаще.",
			"unlock_rain": 0, "unlock_zone": 2, "base_cost": 1.4e6, "growth": 1.12, "max_level": 20, "step": 1.9},
	{"id": "winch", "name": "Лебёдка", "icon": "winch", "text": "Тянет шахтёров быстрее: походы короче, офлайн-доход копится дольше.",
			"unlock_rain": 0, "unlock_zone": 3, "base_cost": 1.35e9, "growth": 1.25, "max_level": 12, "step": 0.04},
	{"id": "cart", "name": "Вагонетка", "icon": "cart", "text": "Возит золото: «Золотой запал» длится дольше и включается чаще.",
			"unlock_rain": 0, "unlock_zone": 4, "base_cost": 3.7e12, "growth": 1.25, "max_level": 15, "step": 0.4},
]

const BLASTER_BASE_PERIOD := 60.0        # секунд между взрывами на первом уровне (минус step за каждый следующий)
const BLASTER_MIN_PERIOD := 20.0
const BLASTER_SECONDS := 4.0             # награда взрыва: столько секунд дохода от глыб
const WINCH_OFFLINE_STEP := 1800.0       # секунд офлайн-лимита за уровень Лебёдки
const LAB_BASE_PERIOD := 600.0           # секунд на один алмаз на первом уровне Лаборатории (минус step за каждый следующий)
const LAB_MIN_PERIOD := 100.0
const LAB_OFFLINE_CAP := 24              # алмазов от Лаборатории за одно отсутствие (офлайн)
const CART_SECONDS_STEP := 0.1           # секунд к «Золотому запалу» за уровень Вагонетки (пауза сокращается на step)
const AD_BOOST_SECONDS := 300.0          # реклама «Машины ×2»
const AD_BOOST_FACTOR := 2.0


## Облики машины по уровню: 0 — дерево, 1 — железо (латунные заклёпки), 2 — сталь (золотой ободок).
## Границы пропорциональны пределу уровня машины (у разных машин он разный): с 40% и с 80% от предела.
const TIER_NAMES := ["Дерево", "Железо", "Сталь"]
const TIER_COLORS := [Color(0.80, 0.60, 0.38), Color(0.68, 0.76, 0.78), Color(0.90, 0.95, 0.93)]


static func tier_for(level: int, max_level: int) -> int:
	if max_level <= 0 or level <= 0:
		return 0
	var share := float(level) / float(max_level)
	if share >= 0.8:
		return 2
	return 1 if share >= 0.4 else 0


static func ids() -> Array:
	var out: Array = []
	for entry in LIST:
		out.append(str(entry["id"]))
	return out


static func data(id: String) -> Dictionary:
	for entry in LIST:
		if str(entry["id"]) == id:
			return entry
	return {}
