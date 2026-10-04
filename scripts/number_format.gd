class_name NumberFormat
extends RefCounted
## Короткая запись больших чисел: 1234 -> "1.23K", 1.5e9 -> "1.50B", дальше "1.00e39".

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func short(n: float) -> String:
	if n < 1000.0:
		return str(int(n))
	var tier := int(floor(log(n) / log(1000.0)))
	while n / pow(1000.0, tier) >= 1000.0:
		tier += 1
	if tier >= SUFFIXES.size():
		var power := int(floor(log(n) / log(10.0)))
		return "%.2fe%d" % [n / pow(10.0, power), power]
	return "%.2f%s" % [n / pow(1000.0, tier), SUFFIXES[tier]]
