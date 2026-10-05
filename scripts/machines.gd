class_name Machines
extends RefCounted
## Машины: покупаются за монеты, стоят над столом и работают сами (docs/MACHINES.md). Здесь только данные;
## логика уровней, цен и эффектов — в ClickerState, показ — в MachineStrip.

## id, название, значок, описание, открытие (уровень «Камнепада»), база цены (умножается на масштаб планеты),
## рост цены за уровень, предельный уровень, прирост потока на уровень (доля от потока «Камнепада»).
const LIST := [
	{"id": "crusher", "name": "Дробилка", "icon": "crusher", "text": "Сама сбрасывает на стол свои глыбы.",
			"unlock_rain": 5, "base_cost": 3000.0, "growth": 1.5, "max_level": 20, "step": 0.035},
]


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
