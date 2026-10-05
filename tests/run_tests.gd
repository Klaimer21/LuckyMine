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
	_test_machines()
	_test_machines_stage1()
	_test_machines_stage2()
	_test_hints()
	_test_plurals()
	_test_time()
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
	# двойной тап по рекламе: второй показ (и вторая награда в обход паузы) не запускается
	var host := Control.new()
	root.add_child(host)
	var ads := Ads.new()
	ads.setup(host, state)
	var rewards := [0]
	ads.request("rush", func() -> void: rewards[0] += 1)
	ads.request("rush", func() -> void: rewards[0] += 1)
	_check(ads.is_busy() and host.get_child_count() == 1, "second ad request ignored while busy")
	ads.request("nonexistent", func() -> void: rewards[0] += 1)
	_check(host.get_child_count() == 1 and rewards[0] == 0, "unknown ad placement ignored")
	host.get_child(0).close()
	_check(not ads.is_busy() and rewards[0] == 0, "closing the ad early frees the slot and gives nothing")
	host.queue_free()
	# NaN вместо монет ничего не покупает; чрезмерные количества не ломают цены
	var broken := ClickerState.new()
	broken.coins = NAN
	_check(broken.buy_n("rain", 1) == 0 and broken.levels["rain"] == 0, "NaN coins buy nothing")
	var rich := ClickerState.new()
	rich.coins = 1.0e300
	_check(rich.buy_n("rain", -5) == 0 and rich.buy_n("rain", 1000000) == 0, "negative and absurd bulk buys rejected")
	_check(ClickerState.import_code("LM1:" + "A".repeat(5000000)) == false, "oversized code rejected")


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
	state.skills["dynamite"] = 1
	state.dynamite_stock = state.dynamite_max()
	state.respec()
	_check(state.dynamite_stock <= state.dynamite_max(), "respec trims dynamite stock")


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


func _test_machines() -> void:
	var state := ClickerState.new()
	_check(state.update_machine_unlocks().is_empty() and not state.machine_unlocked("crusher"), "crusher locked at start")
	state.levels["rain"] = 4
	_check(state.update_machine_unlocks().is_empty(), "crusher still locked at rain level 4")
	state.levels["rain"] = 5
	_check(state.update_machine_unlocks() == ["crusher"] and state.machine_unlocked("crusher"), "crusher unlocks at rain level 5")
	_check(state.update_machine_unlocks().is_empty(), "unlock is reported once")
	# цены
	var base := float(Machines.data("crusher")["base_cost"])
	_check(is_equal_approx(state.machine_cost("crusher", 1), base), "first level costs the base price")
	_check(is_equal_approx(state.machine_cost("crusher", 2), base * (1.0 + 1.4)), "two levels cost 1 + growth")
	state.planet = 1
	_check(is_equal_approx(state.machine_cost("crusher", 1), base * Biomes.PLANET_SCALE), "price scales with the planet")
	state.planet = 0
	# покупка
	_check(state.buy_machine("crusher", 1) == 0 and state.machine_level("crusher") == 0, "cannot buy without coins")
	state.coins = 1.0e12
	var income_before := state.income_per_second()
	_check(state.buy_machine("crusher", 3) == 3 and state.machine_level("crusher") == 3, "buy 3 levels")
	_check(state.crusher_rate() > 0.0 and state.income_per_second() > income_before, "crusher adds income")
	_check(state.buy_machine("crusher", 1000) == 17 and state.machine_level("crusher") == 20, "purchase stops at the max level")
	_check(state.buy_machine("crusher", 1) == 0, "no purchase above the max level")
	var fresh := ClickerState.new()
	fresh.coins = 1.0e12
	_check(fresh.buy_machine("crusher", 1) == 0, "cannot buy a locked machine")
	fresh.coins = NAN
	fresh.machines_unlocked["crusher"] = true
	_check(fresh.buy_machine("crusher", 1) == 0, "NaN coins buy nothing")
	# сохранение и сброс
	var text := state.serialize()
	var loaded := ClickerState.new()
	loaded.load_from_text(text)
	_check(loaded.machine_level("crusher") == 20 and loaded.machine_unlocked("crusher"), "machines persist")
	var hostile := ClickerState.new()
	hostile.load_from_text('{"machines": {"crusher": 99999}, "machines_unlocked": ["crusher", "nonsense", 5], "levels": {"rain": 7}}')
	_check(hostile.machine_level("crusher") <= 20 and hostile.machines_unlocked.size() == 1, "hostile machine data clamped")
	var old_save := ClickerState.new()
	old_save.load_from_text('{"levels": {"rain": 9}}')
	_check(old_save.machine_unlocked("crusher") and old_save.machine_level("crusher") == 0, "old saves unlock by rain level")
	state.total_earned = 1.0e12
	state.prestige()
	_check(state.machine_level("crusher") == 0 and state.machine_unlocked("crusher"), "New Mine resets levels, keeps the unlock")
	# офлайн-доход учитывает машину
	var away := ClickerState.new()
	away.levels["rain"] = 5
	away.update_machine_unlocks()
	var plain := away.income_per_second()
	away.machines["crusher"] = 10
	_check(away.income_per_second() > plain * 1.25, "income with the crusher is higher")


func _test_machines_stage1() -> void:
	# открытие по зонам
	var state := ClickerState.new()
	state.update_machine_unlocks()
	_check(not state.machine_unlocked("conveyor") and not state.machine_unlocked("blaster") and not state.machine_unlocked("winch"), "zone machines locked in zone 0")
	state.total_earned = 3.0e6
	_check(state.update_machine_unlocks() == ["conveyor", "lab"], "Conveyor and Laboratory unlock in zone 1")
	state.total_earned = 2.0e8
	_check(state.update_machine_unlocks() == ["blaster"], "Blaster unlocks in zone 2")
	state.total_earned = 2.0e11
	_check(state.update_machine_unlocks() == ["winch"], "Winch unlocks in zone 3")
	# Конвейер
	state.machines["conveyor"] = 10
	_check(is_equal_approx(state.ore_shift(), 0.10), "Conveyor lowers the ore threshold by 1% per level")
	# Подрывник
	_check(state.blaster_interval() == 0.0 and state.blaster_share() == 0.0, "Blaster idle at level 0")
	state.machines["blaster"] = 1
	_check(is_equal_approx(state.blaster_interval(), 58.1), "Blaster period at level 1")
	state.machines["blaster"] = 20
	_check(is_equal_approx(state.blaster_interval(), 22.0), "Blaster period at level 20")
	var base := state.base_income_per_second()
	_check(is_equal_approx(state.income_per_second(), base * (1.0 + 4.0 / 22.0)), "income includes the Blaster share")
	# Лебёдка
	state.machines["winch"] = 0
	var cap := state.offline_cap_seconds()
	state.machines["winch"] = 12
	_check(is_equal_approx(state.expedition_time_factor(), 0.52), "Winch cuts expeditions by 4% per level")
	_check(is_equal_approx(state.offline_cap_seconds(), cap + 12.0 * 1800.0), "Winch adds 30 minutes of offline cap per level")
	_check(is_equal_approx(state.expedition_total_seconds(0), 3600.0 * 0.52), "expedition length with the Winch")
	var winch_state := ClickerState.new()
	winch_state.machines["winch"] = 5
	winch_state.start_expedition(1)
	_check(absf(winch_state.expedition_remaining() - 4.0 * 3600.0 * 0.8) < 5.0, "expedition started with the Winch is shorter")
	# сохранение, сброс, планета
	var saved := ClickerState.new()
	saved.total_earned = 2.0e11
	saved.update_machine_unlocks()
	saved.machines["conveyor"] = 7
	saved.machines["blaster"] = 9
	saved.machines["winch"] = 3
	var loaded := ClickerState.new()
	loaded.load_from_text(saved.serialize())
	_check(loaded.machine_level("conveyor") == 7 and loaded.machine_level("blaster") == 9 and loaded.machine_level("winch") == 3, "all machine levels persist")
	_check(loaded.machine_unlocked("blaster") and loaded.machine_unlocked("winch"), "zone unlocks persist")
	var hostile := ClickerState.new()
	hostile.load_from_text('{"machines": {"conveyor": -5, "blaster": 9999, "winch": "x"}}')
	_check(hostile.machine_level("conveyor") == 0 and hostile.machine_level("blaster") <= 20 and hostile.machine_level("winch") == 0, "hostile levels clamped")
	saved.coins = 1.0e15
	saved.prestige()
	_check(saved.machine_level("blaster") == 0 and saved.machine_unlocked("winch"), "New Mine resets levels, keeps unlocks")
	# цены растут и масштабируются
	_check(state.machine_cost("conveyor", 1) < state.machine_cost("blaster", 1) and state.machine_cost("blaster", 1) < state.machine_cost("winch", 1), "later machines cost more")


func _test_machines_stage2() -> void:
	var state := ClickerState.new()
	# Лаборатория
	_check(state.lab_interval() == 0.0 and state.tick_machines(1000.0) == 0, "Laboratory idle at level 0")
	state.machines["lab"] = 1
	_check(is_equal_approx(state.lab_interval(), 575.0), "Laboratory period at level 1")
	state.machines["lab"] = 20
	_check(is_equal_approx(state.lab_interval(), 100.0), "Laboratory period at level 20")
	var before := state.diamonds
	var gained := 0
	for i in 250:
		gained += state.tick_machines(1.0)
	_check(gained == 2 and state.diamonds == before + 2, "Laboratory drips a diamond every 100 s")
	_check(state.tick_machines(100000.0) <= 5, "one tick never floods diamonds")
	# офлайн-алмазы Лаборатории
	var away := ClickerState.new()
	away.machines["lab"] = 20
	var snapshot := away.serialize()
	ClickerState.clock_offset += 1000.0
	var back := ClickerState.new()
	back.load_from_text(snapshot)
	_check(back.offline_lab_diamonds == 10 and back.diamonds == 10, "Laboratory brews diamonds while away")
	ClickerState.clock_offset += 100.0 * 3600.0
	var long_away := ClickerState.new()
	long_away.load_from_text(snapshot)
	_check(long_away.offline_lab_diamonds == Machines.LAB_OFFLINE_CAP, "offline Laboratory diamonds are capped")
	ClickerState.clock_offset = 0.0
	# Вагонетка
	var cart := ClickerState.new()
	var spark := cart.mini_seconds()
	_check(is_equal_approx(cart.mini_cooldown_seconds(), 8.0), "Spark pause without the Cart")
	cart.machines["cart"] = 15
	_check(is_equal_approx(cart.mini_cooldown_seconds(), 2.0) and is_equal_approx(cart.mini_seconds(), spark + 1.5), "Cart shortens the pause and lengthens the Spark")
	cart.start_mini(1.0)
	cart.tick_boost(2.0)
	_check(is_equal_approx(cart.mini_cooldown, 2.0), "Spark pause uses the Cart value")
	# реклама «Машины ×2»
	var boosted := ClickerState.new()
	boosted.levels["rain"] = 5
	boosted.machines["crusher"] = 10
	boosted.machines["blaster"] = 5
	var rate := boosted.crusher_rate()
	var interval := boosted.blaster_interval()
	boosted.machine_boost_time = 10.0
	_check(is_equal_approx(boosted.crusher_rate(), rate * 2.0) and is_equal_approx(boosted.blaster_interval(), interval * 0.5), "ad boost doubles Crusher and Blaster")
	boosted.tick_machines(11.0)
	_check(is_equal_approx(boosted.crusher_rate(), rate), "ad boost expires")
	_check(Ads.PLACEMENTS.has("machines"), "machine boost is an ad placement")
	# сохранение
	var saved := ClickerState.new()
	saved.machines["lab"] = 4
	saved.machines["cart"] = 2
	saved.total_earned = 1.0e15
	saved.update_machine_unlocks()
	saved.lab_progress = 123.0
	var loaded := ClickerState.new()
	loaded.load_from_text(saved.serialize())
	_check(loaded.machine_level("lab") == 4 and loaded.machine_level("cart") == 2 and is_equal_approx(loaded.lab_progress, 123.0), "Laboratory and Cart persist")
	_check(loaded.machine_unlocked("cart"), "Cart unlocks in zone 4")


func _test_hints() -> void:
	_check(Hints.TEXTS.size() >= 18, "hints registry has the game hints")
	_check(Hints.text("first_ore") != "" and Hints.text("no_such_hint") == "", "hint lookup")
	_check(Hints.seconds_for("") == 5.0 and Hints.seconds_for("x".repeat(1000)) == 14.0, "hint time clamped to 5..14 s")
	_check(Hints.seconds_for("x".repeat(100)) > Hints.seconds_for("x".repeat(40)), "longer hint stays longer")
	for id in Hints.TEXTS:
		_check(str(Hints.TEXTS[id]).length() > 10, "hint %s has text" % id)


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


## Время подменяется через ClickerState.clock_offset: ждать по-настоящему не нужно.
func _set_noon() -> void:
	ClickerState.clock_offset = 0.0
	ClickerState.clock_offset = 43200.0 - fmod(Time.get_unix_time_from_system(), 86400.0)   # полдень текущих суток


func _test_time() -> void:
	_set_noon()
	var hour := 3600.0
	var day := 86400.0

	# --- экспедиция ---
	var state := ClickerState.new()
	_check(state.start_expedition(0), "expedition starts")
	_check(not state.start_expedition(1), "second expedition refused while one runs")
	_check(is_equal_approx(state.expedition_remaining(), hour), "1h expedition remaining")
	ClickerState.clock_offset += hour - 60.0
	_check(not state.expedition_ready() and state.claim_expedition().is_empty(), "expedition not ready 1 min early, claim refused")
	ClickerState.clock_offset += 120.0
	_check(state.expedition_ready(), "expedition ready after its time")
	var loot := state.claim_expedition()
	_check(not loot.is_empty() and float(loot["coins"]) >= 100.0, "expedition pays coins")
	_check(not state.expedition_active() and state.claim_expedition().is_empty(), "expedition cannot be claimed twice")

	# часы откатили назад: поход не растягивается дольше своей длительности
	_set_noon()
	var rolled := ClickerState.new()
	rolled.start_expedition(1)
	ClickerState.clock_offset -= 3.0 * day
	_check(rolled.expedition_remaining() <= 4.0 * hour, "clock rollback cannot stretch an expedition")
	# часы убежали на десять лет вперёд: поход готов, числа конечные
	ClickerState.clock_offset += 3650.0 * day
	_check(rolled.expedition_ready(), "far-future clock completes the expedition")
	var far := rolled.claim_expedition()
	_check(is_finite(float(far["coins"])) and is_finite(rolled.coins), "far-future claim stays finite")

	# поход переживает сохранение и загрузку (игра закрыта 2 часа из 4)
	_set_noon()
	var saver := ClickerState.new()
	saver.start_expedition(1)
	var text := saver.serialize()
	ClickerState.clock_offset += 2.0 * hour
	var loaded := ClickerState.new()
	loaded.load_from_text(text)
	_check(loaded.expedition_active() and absf(loaded.expedition_remaining() - 2.0 * hour) < 5.0, "expedition keeps its timer across a save")
	ClickerState.clock_offset += 2.0 * hour + 10.0
	_check(loaded.expedition_ready(), "loaded expedition finishes on time")

	# --- офлайн-доход ---
	_set_noon()
	var away := ClickerState.new()
	away.add_coins(1000.0)
	var snapshot := away.serialize()
	var rate := away.income_per_second()
	ClickerState.clock_offset += 3.0 * hour
	var back := ClickerState.new()
	var earned := back.load_from_text(snapshot)
	_check(absf(earned - rate * 3.0 * hour) < rate * 5.0, "offline income = rate x time away")
	_check(not back.offline_capped, "3h away is under the cap")
	ClickerState.clock_offset += 100.0 * hour
	var long_away := ClickerState.new()
	var capped := long_away.load_from_text(snapshot)
	_check(long_away.offline_capped and absf(capped - rate * ClickerState.OFFLINE_CAP_SECONDS) < rate * 5.0, "offline income capped at 8h")
	_set_noon()
	ClickerState.clock_offset -= 5.0 * hour
	var rolled_back := ClickerState.new()
	_check(rolled_back.load_from_text(snapshot) == 0.0 and rolled_back.offline_away == 0.0, "clock rolled back before launch gives no offline income")
	ClickerState.clock_offset += 1.0e9
	var absurd := ClickerState.new()
	var absurd_earned := absurd.load_from_text(snapshot)
	_check(is_finite(absurd_earned) and absurd.offline_capped, "absurd clock jump is capped and finite")
	_set_noon()
	var perk := ClickerState.new()
	perk.meta["offline"] = 2
	var perk_snapshot := perk.serialize()
	ClickerState.clock_offset += 1000.0 * hour
	var perk_loaded := ClickerState.new()
	perk_loaded.load_from_text(perk_snapshot)
	_check(is_equal_approx(perk_loaded.offline_away, ClickerState.OFFLINE_CAP_SECONDS + 8.0 * hour), "meta offline perk raises the cap by 4h per level")

	# --- ежедневная награда ---
	_set_noon()
	var daily := ClickerState.new()
	_check(daily.daily_available(), "daily available on a new profile")
	var first := daily.claim_daily()
	_check(int(first["slot"]) == 0 and not daily.daily_available() and daily.claim_daily().is_empty(), "daily claimed once per day")
	ClickerState.clock_offset -= day
	_check(not daily.daily_available(), "rolling the clock back does not allow a second claim")
	ClickerState.clock_offset += day
	ClickerState.clock_offset += day
	_check(daily.daily_available() and daily.daily_next_slot() == 1, "next day continues the streak")
	for expected in range(1, Retention.DAILY.size()):
		_check(int(daily.claim_daily()["slot"]) == expected, "daily streak day %d" % (expected + 1))
		ClickerState.clock_offset += day
	_check(daily.daily_next_slot() == 0 and int(daily.claim_daily()["slot"]) == 0, "daily streak wraps after 7 days")
	ClickerState.clock_offset += 3.0 * day
	_check(daily.daily_next_slot() == 0, "a skipped day resets the streak")

	# --- реклама и лихорадка: паузы идут по часам ---
	_set_noon()
	var timers := ClickerState.new()
	timers.ad_mark("rush")
	_check(absf(timers.ad_remaining("rush") - 3600.0) < 5.0, "rush ad cooldown is 1h")
	ClickerState.clock_offset += 3601.0
	_check(timers.ad_remaining("rush") == 0.0, "ad cooldown ends with time")
	timers.rush_ready_at = ClickerState.now() + 100.0
	_check(timers.rush_remaining() > 0.0 and timers.shop_available("rush") == false, "diamond rush on cooldown")
	ClickerState.clock_offset += 101.0
	_check(timers.rush_remaining() == 0.0, "diamond rush cooldown ends")
	ClickerState.clock_offset = 0.0


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
