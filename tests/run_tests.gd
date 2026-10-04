extends SceneTree
## Тесты логики без графики. Запуск: godot --headless --path . --script res://tests/run_tests.gd
## Код выхода 0, если всё прошло.

var _failed := 0
var _passed := 0


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _init() -> void:
	_test_economy()
	_test_prestige()
	_test_planet_and_meta()
	_test_skills()
	_test_collection()
	_test_achievements()
	_test_biomes()
	_test_plurals()
	_test_save_load()
	print("passed %d, failed %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_economy() -> void:
	var state := ClickerState.new()
	_check(state.coins == 0.0, "new state has no coins")
	_check(state.rain_rate() > 0.0, "rain rate positive")
	var price := state.cost("rain")
	state.add_coins(price)
	_check(state.buy("rain"), "can buy rain with enough coins")
	_check(state.levels["rain"] == 1, "rain level 1")
	_check(not state.buy("mult"), "cannot buy mult without coins")
	_check(state.cost("rain") > price, "cost grows")
	_check(state.lifetime_earned >= price, "lifetime earned tracked")
	_test_bulk()
	_test_autobuy()
	_test_ads()
	_test_rush()
	_test_dynamite_stock()
	_test_diamond_shop()


func _test_rush() -> void:
	var state := ClickerState.new()
	state.start_rush(ClickerState.RUSH_LONG_SECONDS)
	_check(is_equal_approx(state.boost_time, 300.0), "long rush lasts 5 minutes")
	state.start_rush(ClickerState.RUSH_LONG_SECONDS)
	state.start_rush(ClickerState.RUSH_LONG_SECONDS)
	_check(state.boost_time <= ClickerState.RUSH_CAP_SECONDS, "rush capped")
	var golden := ClickerState.new()
	golden.start_rush()
	_check(is_equal_approx(golden.boost_time, 15.0), "golden rock rush lasts 15 seconds")
	golden.start_rush(ClickerState.BOOST_SECONDS, false)
	_check(is_equal_approx(golden.boost_time, 15.0), "second golden rock does not stack")
	golden.collect_find(3)
	_check(golden.boost_time <= 15.0, "gold finds do not extend the rush")
	_check(state.rush_remaining() == 0.0, "rush purchasable at start")
	_check(state.shop_cost("dynamite") < state.shop_cost("rush"), "dynamite reset is cheap")
	_check(state.dynamite_seconds() == 30.0, "dynamite pays 30 seconds at start")
	_check(state.dynamite_finds() >= 3, "dynamite knocks out ore")


func _test_diamond_shop() -> void:
	var state := ClickerState.new()
	var first := state.shop_cost("skill_point")
	state.skill_points_bought = 1
	_check(state.shop_cost("skill_point") > first, "skill point price grows")
	_check(not state.shop_available("expedition_skip"), "expedition skip needs an active expedition")
	_check(not state.shop_available("boss"), "boss summon needs zone 1")
	_check(not state.style_unlocked(7), "diamond style locked at start")
	state.styles_bought.append(7)
	_check(state.style_unlocked(7) and not state.shop_available("style_7"), "diamond style owned after purchase")
	for index in ClickerState.STYLE_PRICES:
		_check(index < Settings.STYLE_NAMES.size(), "style price has a name")


func _test_dynamite_stock() -> void:
	var state := ClickerState.new()
	_check(state.dynamite_stock == ClickerState.START_DYNAMITE, "start dynamite")
	_check(state.use_dynamite() and state.dynamite_stock == 2 and state.dynamite_used == 1, "use dynamite")
	_check(state.add_dynamite(2) == 2 and state.dynamite_stock == 4, "add dynamite")
	_check(state.add_dynamite(100) == state.dynamite_max() - 4 and state.dynamite_stock == state.dynamite_max(), "dynamite store is capped")
	state.dynamite_stock = 0
	_check(not state.use_dynamite(), "cannot use empty dynamite")
	state.skills["dynamite"] = 1
	_check(state.dynamite_max() == 20, "skill raises dynamite capacity")
	var titan := ClickerState.new()
	titan.planet = 3
	titan.dynamite_stock = 0
	_check(titan.add_dynamite(2) == 3, "Titan hands out 50% more dynamite")


func _test_ads() -> void:
	var state := ClickerState.new()
	_check(state.ad_remaining("rush") == 0.0, "ad available at start")
	state.ad_mark("rush")
	_check(state.ad_remaining("rush") > 0.0, "ad on cooldown after mark")
	state.ad_mark("offline")
	_check(state.ad_remaining("offline") <= 0.0, "offline ad has no cooldown")
	_check(state.ad_diamonds() >= 3, "ad diamonds at least 3")


func _test_autobuy() -> void:
	var state := ClickerState.new()
	_check(state.autobuy_interval() == 0.0, "autobuy locked by default")
	state.meta["autobuy"] = 2
	_check(state.autobuy_interval() == 3.0, "autobuy level 2 interval")
	_check(state.autobuy_step() == "", "autobuy does nothing without coins")
	state.add_coins(20.0)
	_check(state.autobuy_step() == "rain", "autobuy buys the cheapest affordable upgrade")
	_check(state.levels["rain"] == 1, "autobuy raised rain level")


func _test_bulk() -> void:
	var state := ClickerState.new()
	state.add_coins(1.0e6)
	var one := state.cost("tap")
	_check(is_equal_approx(state.cost_for("tap", 1), one), "cost_for 1 equals cost")
	var sum := 0.0
	for i in 10:
		sum += one * pow(1.45, i)
	_check(absf(state.cost_for("tap", 10) - sum) < 0.001 * sum, "cost_for 10 equals manual sum")
	var n := state.max_affordable("tap")
	_check(n > 0 and state.cost_for("tap", n) <= state.coins and state.cost_for("tap", n + 1) > state.coins, "max_affordable is tight")
	var before := state.coins
	_check(state.buy_n("tap", 5) == 5 and state.levels["tap"] == 5, "buy_n 5")
	_check(state.coins < before, "coins spent")
	var poor := ClickerState.new()
	_check(poor.buy_n("rain", 5) == 0 and poor.levels["rain"] == 0, "buy_n is all-or-nothing")
	_check(poor.max_affordable("rain") == 0, "max_affordable 0 when poor")


func _test_prestige() -> void:
	var state := ClickerState.new()
	_check(state.prestige() == 0, "no prestige without veins")
	state.add_coins(1.0e9)
	var expected := state.pending_veins()
	_check(expected > 0, "pending veins appear at 1e9")
	var points := state.skill_points
	_check(state.prestige() == expected, "prestige returns gained veins")
	_check(state.veins == expected, "veins stored")
	_check(state.coins == 0.0, "coins reset")
	_check(state.skill_points > points, "prestige grants skill points")
	_check(state.vein_multiplier() > 1.0, "veins boost income")
	_check(state.total_earned >= 1.0e9, "depth survives prestige")


func _test_planet_and_meta() -> void:
	var state := ClickerState.new()
	_check(not state.planet_ready(), "planet not ready at start")
	_check(state.new_planet() == 0, "new_planet refused before core")
	state.add_coins(1.0e30)
	_check(state.planet_ready(), "planet ready at huge total")
	var gain := state.planet_gain()
	_check(state.new_planet() == gain, "new_planet returns stardust")
	_check(state.planet == 1 and state.stardust == gain, "planet advanced")
	_check(state.total_earned == 0.0, "depth reset on planet")
	_check(state.planet_scale() > 1.0, "planet scale grows")
	state.stardust = 1000
	for entry in ClickerState.META:
		var id: String = entry["id"]
		var costs: Array = entry["costs"]
		for level in costs.size():
			_check(state.buy_meta(id), "buy meta %s level %d" % [id, level + 1])
		_check(not state.buy_meta(id), "meta %s capped" % id)
		_check(state.meta_level(id) == costs.size(), "meta %s level" % id)
	var poor := ClickerState.new()
	_check(not poor.buy_meta("income"), "meta needs stardust")


func _test_skills() -> void:
	var state := ClickerState.new()
	var before := state.multiplier()
	state.skill_points = 100000
	for branch in Skills.BRANCHES:
		var id: String = branch["id"]
		_check(state.buy_skill(id), "buy first %s skill" % id)
	_check(state.multiplier() > before, "yield skill raises multiplier")
	var spent := state.skill_points
	state.respec()
	_check(state.skill_points > spent, "respec refunds points")
	_check(state.skill_level("yield") == 0, "respec clears levels")


func _test_collection() -> void:
	var state := ClickerState.new()
	var base := state.collection_multiplier()
	for i in ClickerState.MILESTONES[0]:
		state.collect_find(1)
	_check(state.find_level(1) == 1, "first milestone reached")
	_check(state.collection_multiplier() > base, "collection boosts income")


func _test_achievements() -> void:
	var ids := {}
	for achievement in Retention.ACHIEVEMENTS:
		var id := str(achievement["id"])
		_check(not ids.has(id), "unique achievement id %s" % id)
		ids[id] = true
	var state := ClickerState.new()
	state.rocks_broken = 1000
	for achievement in Retention.ACHIEVEMENTS:
		if str(achievement["id"]) == "rocks1k":
			_check(state.achievement_done(achievement), "rocks1k done at 1000 rocks")
			_check(state.achievement_claimable(achievement), "rocks1k claimable")


func _test_biomes() -> void:
	_check(Biomes.index_for(0.0, 1.0) == 0, "start in zone 0")
	var last := -1
	for total in [0.0, 1.0e7, 1.0e9, 1.0e12, 1.0e16, 1.0e20, 1.0e25]:
		var index := Biomes.index_for(total, 1.0)
		_check(index >= last, "zone index monotonic")
		last = index
	_check(Biomes.index_for(1.0e7, 100.0) < Biomes.index_for(1.0e7, 1.0) or Biomes.index_for(1.0e7, 1.0) == 0, "scale delays zones")
	for planet in 8:
		_check(Biomes.planet_name(planet) != "", "planet name %d" % planet)
		_check(Biomes.planet_mod_text(planet) != "", "planet text %d" % planet)


func _test_plurals() -> void:
	var saved := Tr.language
	Tr.set_language("ru")
	var cases := {1: "алмаз", 2: "алмаза", 5: "алмазов", 11: "алмазов", 12: "алмазов", 21: "алмаз", 22: "алмаза", 25: "алмазов", 101: "алмаз", 0: "алмазов"}
	for n in cases:
		_check(Tr.fmt("+%d алмазов", [n]) == "+%d %s" % [n, cases[n]], "ru plural %d" % n)
	_check(Tr.fmt("%d → %d глыб за обвал", [1, 3]) == "1 → 3 глыбы за обвал", "ru plural second arg")
	_check(Tr.fmt("≈%s монет · %d алмазов · %d находок", ["5K", 1, 14]) == "≈5K монет · 1 алмаз · 14 находок", "ru plural mixed args")
	Tr.set_language("en")
	_check(Tr.fmt("+%d алмазов", [3]) == "+3 diamonds", "en keeps template")
	Tr.set_language(saved)


func _test_save_load() -> void:
	# настоящее сохранение игрока прячем и возвращаем после теста
	var backup := ""
	var had_save := FileAccess.file_exists(ClickerState.SAVE_PATH)
	if had_save:
		backup = FileAccess.get_file_as_string(ClickerState.SAVE_PATH)
	var had_backup := FileAccess.file_exists(ClickerState.BACKUP_PATH)
	var backup_copy := FileAccess.get_file_as_string(ClickerState.BACKUP_PATH) if had_backup else ""
	var state := ClickerState.new()
	state.add_coins(5.0e6)
	state.stardust = 7
	state.rocks_broken = 42
	state.play_seconds = 123.0
	state.levels["rain"] = 3
	state.save()
	var loaded := ClickerState.new()
	loaded.load_save()
	_check(is_equal_approx(loaded.total_earned, 5.0e6), "total_earned persisted")
	_check(loaded.stardust == 7, "stardust persisted")
	_check(loaded.rocks_broken == 42, "rocks_broken persisted")
	_check(is_equal_approx(loaded.play_seconds, 123.0), "play_seconds persisted")
	_check(loaded.levels["rain"] == 3, "levels persisted")
	_check(not loaded.tampered, "fresh save is signed")
	var raw := FileAccess.get_file_as_string(ClickerState.SAVE_PATH)
	var edited := FileAccess.open(ClickerState.SAVE_PATH, FileAccess.WRITE)
	edited.store_string(raw.replace("5000000", "9000000"))
	edited.close()
	var cheat := ClickerState.new()
	cheat.load_save()
	_check(cheat.tampered, "edited save is flagged")
	state.save()
	var code := state.export_code()
	_check(ClickerState.import_code(code), "export code imports")
	_check(not ClickerState.import_code("LM1:" + code.substr(4, 40) + "!!" + code.substr(46)), "damaged code rejected")
	_check(not ClickerState.import_code("garbage"), "garbage code rejected")
	var imported := ClickerState.new()
	imported.load_save()
	_check(is_equal_approx(imported.total_earned, 5.0e6) and not imported.tampered, "imported save loads signed")
	# второе сохранение делает первое запасной копией; испорченный основной файл заменяется ею
	state.stardust = 9
	state.save()
	var corrupt := FileAccess.open(ClickerState.SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{broken json")
	corrupt.close()
	var recovered := ClickerState.new()
	recovered.load_save()
	_check(recovered.stardust == 7, "backup used when save is corrupt")
	# враждебные типы и значения не роняют загрузку
	var hostile := FileAccess.open(ClickerState.SAVE_PATH, FileAccess.WRITE)
	hostile.store_string('{"coins": -5, "meta": [1], "skills": 3, "finds": "x", "levels": null, "expedition_type": 99, "dynamite_stock": -4, "diamonds": 1e30, "planet": 1e9}')
	hostile.close()
	var odd := ClickerState.new()
	odd.load_save()
	_check(odd.coins >= 0.0 and odd.expedition_type == -1, "hostile save sanitised")
	_check(odd.dynamite_stock >= 0 and odd.planet <= 100, "hostile save clamped")
	# после сброса сохранение отключено
	ClickerState.delete_save()
	state.saving_enabled = false
	state.save()
	_check(not FileAccess.file_exists(ClickerState.SAVE_PATH), "no save when disabled")
	ClickerState.delete_save()
	if had_save:
		var restore := FileAccess.open(ClickerState.SAVE_PATH, FileAccess.WRITE)
		restore.store_string(backup)
	if had_backup:
		var restore_backup := FileAccess.open(ClickerState.BACKUP_PATH, FileAccess.WRITE)
		restore_backup.store_string(backup_copy)
