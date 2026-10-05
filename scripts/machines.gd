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
			"unlock_rain": 5, "unlock_zone": -1, "base_cost": 3000.0, "growth": 1.4, "max_level": 20, "step": 0.03},
	{"id": "conveyor", "name": "Конвейер", "icon": "conveyor", "text": "Везёт на стол руду: в глыбах чаще попадаются самородки.",
			"unlock_rain": 0, "unlock_zone": 1, "base_cost": 3.0e4, "growth": 1.25, "max_level": 15, "step": 0.01},
	{"id": "blaster", "name": "Подрывник", "icon": "blaster", "text": "Сам взрывает малый заряд: монеты за взрыв, чем выше уровень, тем чаще.",
			"unlock_rain": 0, "unlock_zone": 2, "base_cost": 2.8e6, "growth": 1.12, "max_level": 20, "step": 1.9},
	{"id": "winch", "name": "Лебёдка", "icon": "winch", "text": "Тянет шахтёров быстрее: походы короче, офлайн-доход копится дольше.",
			"unlock_rain": 0, "unlock_zone": 3, "base_cost": 1.35e9, "growth": 1.25, "max_level": 12, "step": 0.04},
]

const BLASTER_BASE_PERIOD := 60.0        # секунд между взрывами на первом уровне (минус step за каждый следующий)
const BLASTER_MIN_PERIOD := 20.0
const BLASTER_SECONDS := 4.0             # награда взрыва: столько секунд дохода от глыб
const WINCH_OFFLINE_STEP := 1800.0       # секунд офлайн-лимита за уровень Лебёдки


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
